import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_secrets.dart';

const String _phpUrl  = AppSecrets.phpBaseUrl;
const String _jwtKey  = 'arabtili_jwt';
const String _userKey = 'arabtili_user';

/// Google accessToken yordamida Firebase idToken (JWT) oladi.
/// PHP tokeninfo bu JWT ni qabul qilishi kerak.
Future<String?> _getFirebaseIdToken(String accessToken) async {
  try {
    final url =
        'https://identitytoolkit.googleapis.com/v1/accounts:signInWithIdp'
        '?key=${AppSecrets.firebaseApiKey}';
    final body = jsonEncode({
      'requestUri': 'http://localhost',
      'postBody': 'access_token=$accessToken&providerId=google.com',
      'returnSecureToken': true,
      'returnIdpCredential': true,
    });
    final res = await http
        .post(Uri.parse(url),
            headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 10));

    debugPrint('[Auth] Firebase signInWithIdp: ${res.statusCode}');
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final firebaseToken = data['idToken'] as String?;
      debugPrint('[Auth] Firebase idToken: '
          '${firebaseToken != null ? "${firebaseToken.length}belgi" : "NULL"}');
      return firebaseToken;
    }
    debugPrint(
        '[Auth] Firebase xato: ${res.body.substring(0, 200.clamp(0, res.body.length))}');
  } catch (e) {
    debugPrint('[Auth] Firebase idToken xatosi: $e');
  }
  return null;
}

class AuthUser {
  final String id;
  final String email;
  final String? name;
  final String? avatar;

  const AuthUser({
    required this.id,
    required this.email,
    this.name,
    this.avatar,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    // PHP javob formatlari: {user_id, name, email} yoki {user: {id, name, email}}
    final root = (json['data'] as Map<String, dynamic>?) ??
        (json['user'] as Map<String, dynamic>?) ??
        json;

    return AuthUser(
      id: '${root['user_id'] ?? root['id'] ?? root['userId'] ?? ''}',
      email: '${root['email'] ?? ''}',
      name: root['name'] as String?,
      avatar: (root['avatar'] ?? root['picture'] ?? root['photo']) as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'avatar': avatar,
      };

  String get displayName =>
      (name != null && name!.isNotEmpty) ? name! : email.split('@').first;

  String get initials {
    if (name != null && name!.isNotEmpty) {
      final parts = name!.trim().split(' ');
      if (parts.length >= 2)
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      return name![0].toUpperCase();
    }
    return email[0].toUpperCase();
  }
}

String _extractToken(Map<String, dynamic> json) {
  final root = (json['data'] as Map<String, dynamic>?) ??
      (json['user'] as Map<String, dynamic>?) ??
      json;
  // PHP turli nomlar bilan qaytarishi mumkin: token, jwt, access_token, auth_token
  final t = root['token'] ??
      root['jwt'] ??
      root['access_token'] ??
      root['auth_token'] ??
      json['token'] ??
      json['jwt'] ??
      '';
  return '$t';
}

class AuthService extends ChangeNotifier {
  AuthService._();
  static final AuthService instance = AuthService._();

  AuthUser? _user;
  String? _token;
  bool _isLoading = false;

  AuthUser? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;

  // serverClientId = Web client ID (type 3, google-services.json) — idToken uchun
  final _googleSignIn = GoogleSignIn(
    serverClientId: AppSecrets.googleServerClientId,
    scopes: ['email', 'profile'],
  );

  /// App ishga tushganda saqlangan sessionni tiklaydi
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTok = prefs.getString(_jwtKey);
    final savedUsr = prefs.getString(_userKey);

    if (savedTok == null || savedUsr == null) return;

    try {
      _token = savedTok;
      // Local saqlangan user-ni yuklaymiz — bu ASOSIY manba
      _user = AuthUser.fromJson(jsonDecode(savedUsr) as Map<String, dynamic>);
      debugPrint('[Auth] Restored: name=${_user?.name}, email=${_user?.email}');
      notifyListeners();

      // PHP ?route=me mavjud bo'lsa — user ma'lumotlarini yangilaymiz
      // Mavjud bo'lmasa — local user ishlayveradi (xato bo'lsa e'tibor bermaymiz)
      try {
        final res = await http.get(
          Uri.parse('$_phpUrl?route=me'),
          headers: {'Authorization': 'Bearer $savedTok'},
        ).timeout(const Duration(seconds: 6));

        debugPrint(
            '[Auth] ?route=me → ${res.statusCode}: ${res.body.length > 100 ? res.body.substring(0, 100) : res.body}');

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;

          // PHP xatolik yoki route topilmasa — local user-ni SAQLAYMIZ
          if (data.containsKey('error') || data.containsKey('message')) {
            debugPrint('[Auth] PHP me → xatolik, local user saqlanadi');
            return;
          }

          final phpUser = AuthUser.fromJson(data);
          if (phpUser.email.isNotEmpty) {
            final current = _user!;
            _user = AuthUser(
              id: phpUser.id.isNotEmpty ? phpUser.id : current.id,
              email: phpUser.email,
              name: (phpUser.name != null && phpUser.name!.isNotEmpty)
                  ? phpUser.name
                  : current.name,
              avatar: phpUser.avatar ?? current.avatar,
            );
            await prefs.setString(_userKey, jsonEncode(_user!.toJson()));
            notifyListeners();
            debugPrint('[Auth] PHP me merge: name=${_user?.name}');
          }
        }
      } catch (_) {
        // ?route=me mavjud emas yoki timeout — local user ishlayveradi
        debugPrint('[Auth] ?route=me mavjud emas — local user ishlatiladi');
      }
    } catch (e) {
      debugPrint('[Auth] initialize error: $e');
    }
  }

  /// Google bilan kirish
  Future<void> signInWithGoogle() async {
    _isLoading = true;
    notifyListeners();

    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      // ✅ _user-ni BIRINCHI o'rnatamiz — har doim Google-dan to'g'ri keladi
      // Bu qayta kirganda ham (idToken null bo'lsa ham) ishlaydi
      _user = AuthUser(
        id: googleUser.id,
        email: googleUser.email,
        name: googleUser.displayName,
        avatar: googleUser.photoUrl,
      );
      notifyListeners(); // ← darhol UI ga ko'rsatamiz

      debugPrint(
          '[Auth] Google user: id=${googleUser.id}, name=${googleUser.displayName}, email=${googleUser.email}');

      // ── Tokenlarni olish ───────────────────────────────────────────────
      String? idToken;
      String? accessToken;
      try {
        // 1-urinish: to'g'ridan-to'g'ri
        var auth = await googleUser.authentication;
        idToken = auth.idToken;
        accessToken = auth.accessToken;
        debugPrint('[Auth] 1-urinish → idToken: '
            '${idToken != null ? "${idToken.length}b" : "NULL"}, '
            'accessToken: ${accessToken != null ? "${accessToken.length}b" : "NULL"}, '
            'serverAuthCode: ${googleUser.serverAuthCode != null ? "mavjud" : "yo\'q"}');

        // 2-urinish: cache tozalab qayta (idToken null bo'lsa)
        if (idToken == null || idToken.isEmpty || !idToken.startsWith('eyJ')) {
          debugPrint('[Auth] idToken null – cache tozalanmoqda...');
          await googleUser.clearAuthCache();
          auth = await googleUser.authentication;
          idToken = auth.idToken;
          accessToken = auth.accessToken;
          debugPrint('[Auth] 2-urinish → idToken: '
              '${idToken != null ? "${idToken.length}b" : "NULL"}');
        }

        // 3-urinish: Firebase REST API orqali accessToken → idToken
        // Google idToken null bo'lganda ham accessToken mavjud bo'ladi
        if ((idToken == null || !idToken.startsWith('eyJ')) &&
            accessToken != null &&
            accessToken.isNotEmpty) {
          debugPrint(
              '[Auth] idToken null – Firebase REST API sinab ko\'rilmoqda...');
          final firebaseToken = await _getFirebaseIdToken(accessToken);
          if (firebaseToken != null && firebaseToken.startsWith('eyJ')) {
            idToken = firebaseToken;
            debugPrint(
                '[Auth] Firebase idToken olindi: ${idToken.length}belgi');
          }
        }
      } catch (e) {
        debugPrint('[Auth] Token olishda xato: $e');
      }

      final bool hasJwt =
          idToken != null && idToken.isNotEmpty && idToken.startsWith('eyJ');
      debugPrint('[Auth] Natija: hasJwt=$hasJwt, '
          'accessToken=${accessToken != null ? "${accessToken!.length}b" : "NULL"}');

      // ── PHP ?route=google_auth ─────────────────────────────────────────
      // PHP line 5: $access_token = $body['access_token']
      // PHP line 11: tokeninfo?id_token=$access_token
      // Demak: PHP 'access_token' maydonidagi qiymatni tokeninfo ga yuboradi.
      // Yechim: id_token (JWT) ni 'access_token' maydonida ham yuboramiz!
      String token = accessToken ?? googleUser.id;
      try {
        final jsonBody = <String, dynamic>{
          // PHP line 5 o'qiydi: $body['access_token'] — shuning uchun JWT ni shu yerga
          if (hasJwt)
            'access_token': idToken, // PHP tokeninfo?id_token=eyJ... ✅
          if (hasJwt) 'id_token': idToken, // standart maydon ham
          'email': googleUser.email,
          'name': googleUser.displayName ?? '',
          'avatar': googleUser.photoUrl ?? '',
          'google_id': googleUser.id,
        };
        debugPrint('[Auth] PHP POST → '
            '${hasJwt ? "JWT=${idToken!.length}belgi access_token va id_token maydonda" : "JWT YOQ — faqat email/name"}');

        final res = await http
            .post(
              Uri.parse('$_phpUrl?route=google_auth'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(jsonBody),
            )
            .timeout(const Duration(seconds: 15));

        debugPrint('[Auth] PHP response status: ${res.statusCode}');
        debugPrint('[Auth] PHP response body: ${res.body}');

        if (res.statusCode == 200 || res.statusCode == 201) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          debugPrint('[Auth] PHP response: $data');

          if (!data.containsKey('error')) {
            // PHP muvaffaqiyatli → JWT token va PHP user_id olamiz
            final extracted = _extractToken(data);
            if (extracted.isNotEmpty) token = extracted;

            final root = (data['data'] as Map<String, dynamic>?) ??
                (data['user'] as Map<String, dynamic>?) ??
                data;

            // PHP user_id (UUID) → Google ID dan USTUN
            // Har akkaunt uchun bir xil ID saqlanadi
            final phpUserId = '${root['user_id'] ?? root['id'] ?? ''}';
            final phpName = '${root['name'] ?? ''}';
            final phpAvatar = '${root['avatar'] ?? root['picture'] ?? ''}';

            _user = AuthUser(
              id: phpUserId.isNotEmpty ? phpUserId : googleUser.id,
              email: '${root['email'] ?? googleUser.email}',
              name: phpName.isNotEmpty ? phpName : googleUser.displayName,
              avatar: phpAvatar.isNotEmpty ? phpAvatar : googleUser.photoUrl,
            );
            debugPrint(
                '[Auth] PHP user_id: ${_user!.id}, name: ${_user!.name}');
          } else {
            // PHP "invalid token" → Google ID bilan davom etamiz
            debugPrint(
                '[Auth] PHP xatolik (${data['error']}) → Google ID: ${googleUser.id}');
          }
        }
      } catch (e) {
        debugPrint(
            '[Auth] PHP google_auth error: $e — Google user ishlatiladi');
        // PHP xatolik bo'lsa — Google ma'lumotlari bilan davom etamiz
      }

      _token = token;

      // Saqlash — name va avatar null bo'lsa ham Google-dan olganlarini saqlash
      final finalUser = AuthUser(
        id: _user!.id,
        email: _user!.email,
        name: _user!.name ?? googleUser.displayName,
        avatar: _user!.avatar ?? googleUser.photoUrl,
      );
      _user = finalUser;

      debugPrint(
          '[Auth] Saving user: name=${_user?.name}, avatar=${_user?.avatar}');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_jwtKey, token);
      await prefs.setString(_userKey, jsonEncode(_user!.toJson()));
    } catch (e) {
      debugPrint('[Auth] signInWithGoogle xatosi: $e');
      // Agar _user o'rnatilmagan bo'lsa — xatolikni qayta otmaymiz
      // Chunki _user darhol set qilingan, faqat token/PHP xatosi bo'lishi mumkin
      if (_user == null) rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Chiqish
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_jwtKey);
    await prefs.remove(_userKey);
    _user = null;
    _token = null;
    notifyListeners();
  }
}
