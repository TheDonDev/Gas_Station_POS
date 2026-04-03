import 'package:flutter/foundation.dart';

class ApiConfig {
  // Your local development URL (Node.js running on your machine)
  static const String _devUrl = 'http://localhost:3000';

  // Your production Render URL (Replace with your actual Render service URL)
  static const String _prodUrl = 'https://gas-station-backend.onrender.com';

  // Automatically switches between Dev and Prod based on build mode
  // This returns the Prod URL if running 'flutter run --release' or 'flutter build'
  static String get baseUrl => kReleaseMode ? _prodUrl : _devUrl;
}