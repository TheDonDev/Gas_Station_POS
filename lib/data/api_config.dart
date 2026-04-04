import 'package:flutter/foundation.dart';
import 'dart:io';

// This file defines the API endpoints for your Flutter application.
// It automatically switches between development (localhost/emulator) and
// production (Render) URLs based on the Flutter build mode.
class ApiConfig {
  // Your local development URL (Node.js running on your machine)
  static const String _devUrl = 'http://localhost:3000';
  
  // Android Emulator specific local URL
  // When running on an Android emulator, 'localhost' refers to the emulator itself.
  // '10.0.2.2' is a special alias to your host machine's loopback interface.
  static const String _androidDevUrl = 'http://10.0.2.2:3000';

  // Your production Render URL (Replace with your actual Render service URL)
  static const String _prodUrl = 'https://gas-station-pos.onrender.com'; // Updated to match live Render URL

  // Automatically switches between Dev and Prod based on build mode
  // This returns the Prod URL if running 'flutter run --release' or 'flutter build'
  static String get baseUrl => kReleaseMode 
      ? _prodUrl 
      : (Platform.isAndroid ? _androidDevUrl : _devUrl);
}