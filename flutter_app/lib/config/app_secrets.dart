// App konfiguratsiyasi — API URL va kalitlar.
// Haqiqiy sirli qiymatlar uchun build vaqtida --dart-define ishlatiladi.
// Default qiymatlar ishlab chiqish (dev) uchun.
//
// Build buyrug'i:
//   flutter build apk --release \
//     --dart-define=PHP_BASE_URL=http://luxcontent.uz/arab.php \
//     --dart-define=FIREBASE_API_KEY=AIzaSyCM559oJDq0hd3pBP291a9zxO9Qrbrfdjw \
//     --dart-define=GOOGLE_SERVER_CLIENT_ID=1044392240238-vv8fva4c0qhptlftp8u8760veorhcjb2.apps.googleusercontent.com

// ignore_for_file: constant_identifier_names

class AppSecrets {
  AppSecrets._();

  /// PHP backend URL
  static const String phpBaseUrl = String.fromEnvironment(
    'PHP_BASE_URL',
    defaultValue: 'http://luxcontent.uz/arab.php',
  );

  /// Firebase REST API key (google-services.json dagi current_key)
  static const String firebaseApiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: 'AIzaSyCM559oJDq0hd3pBP291a9zxO9Qrbrfdjw',
  );

  /// Google Web Client ID (serverClientId — idToken uchun)
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue:
        '1044392240238-vv8fva4c0qhptlftp8u8760veorhcjb2.apps.googleusercontent.com',
  );
}
