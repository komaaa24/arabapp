// App konfiguratsiyasi — API URL va kalitlar.
// Haqiqiy sirli qiymatlar uchun build vaqtida --dart-define ishlatiladi.
// Default qiymatlar ishlab chiqish (dev) uchun.
//
// Build buyrug'i:
//   flutter build apk --release \
//     --dart-define=PHP_BASE_URL=http://luxcontent.uz/arab.php \
//     --dart-define=FIREBASE_API_KEY=AIzaSyCM559oJDq0hd3pBP291a9zxO9Qrbrfdjw \
//     --dart-define=GOOGLE_SERVER_CLIENT_ID=450701745537-3cc3mks20uu1p1oghck0rpo9cjnnlb8j.apps.googleusercontent.com

// ignore_for_file: constant_identifier_names

class AppSecrets {
  AppSecrets._();

  /// PHP backend URL
  static const String phpBaseUrl = String.fromEnvironment(
    'PHP_BASE_URL',
    defaultValue: 'http://luxcontent.uz/arab.php',
  );

  /// Firebase Web API key (Firebase Console → Project settings → General).
  /// Loyiha `arabtili` (450701745537) bo'lsa, shu loyihadagi kalitni qo'ying.
  static const String firebaseApiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: 'AIzaSyCM559oJDq0hd3pBP291a9zxO9Qrbrfdjw',
  );

  /// **Web application** client ID — FAQAT "Web" turi (Android/iOS emas!).
  /// Flutter `GoogleSignIn(serverClientId: ...)` — `id_token` (JWT) shu bilan keladi.
  /// Cloud da faqat Android + iOS bo'lsa: **Create client → Web application** qo'shing,
  /// shu loyihada (bitta GCP project) va shu yerga Client ID ni yozing.
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue:
        '450701745537-3cc3mks20uu1p1oghck0rpo9cjnnlb8j.apps.googleusercontent.com',
  );

  /// **iOS** OAuth client ID (Cloud → Clients → tur: **iOS**, masalan "Arab Tili iOS").
  /// Android client ID shu faylga yozilmaydi — u `android/app/google-services.json` da.
  static const String googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue:
        '450701745537-ladueqi55rioo7gfo773u4ddnkc8hg21.apps.googleusercontent.com',
  );
}
