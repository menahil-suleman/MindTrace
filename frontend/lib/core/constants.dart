/// Central place for app-wide constants.
/// Change [baseUrl] to point to your running backend.
class AppConstants {
  AppConstants._();

  // Android emulator  → 'http://10.0.2.2:8000'
  // Windows / Chrome  → 'http://localhost:8000'
  // Physical device   → 'http://<your-LAN-ip>:8000'
  //
  // To find your LAN IP: run `ipconfig` → look for IPv4 under WiFi adapter
  // Example: 'http://192.168.1.5:8000'
  static const String baseUrl = 'http://localhost:8000';

  // SharedPreferences keys
  static const String tokenKey = 'auth_token';
}
