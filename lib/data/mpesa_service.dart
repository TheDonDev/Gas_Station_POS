import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:gas_store_pos/data/api_config.dart'; // Import ApiConfig

class MpesaService {
  // Uses the central configuration to decide the URL
  // In debug mode, this will be localhost or 10.0.2.2 (for Android emulator).
  // In release mode, this will be your Render production URL.
  // The backend's /stkpush endpoint will then handle the M-Pesa API call.
  String get _baseUrl => ApiConfig.baseUrl;
  
  Future<String?> initiateStkPush(String phone, double amount) async {
    // Validation: Ensure phone starts with 254 and is 12 digits long
    if (!RegExp(r'^254\d{9}$').hasMatch(phone)) {
      return null;
    }

    try {
      print("M-Pesa: Attempting STK Push to $_baseUrl/stkpush");
      // The actual M-Pesa API call is made by the backend.
      final response = await http.post(
        Uri.parse('$_baseUrl/stkpush'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'phone': phone,
          'amount': amount,
        }),
      );

      if (response.statusCode == 200) {
        print("STK Push Initiated Successfully");
        final data = jsonDecode(response.body);
        return data['CheckoutRequestID']; // Return ID for polling
      }
      
      // Try to parse the detailed error from our backend
      try {
        final errData = jsonDecode(response.body);
        print("❌ M-Pesa Error (${response.statusCode}): ${errData['error']}");
        print("📝 Details: ${errData['details']}");
        print("🌐 Target URL: ${errData['targetUrl']}");
      } catch (_) {
        print("STK Push Failed with Status: ${response.statusCode} - ${response.body}");
      }
      return null;
    } catch (e) { // Catch any network-related errors
      if (e is http.ClientException && e.message.contains('Failed host lookup')) {
        print("M-Pesa DNS Error: Host lookup failed for $_baseUrl. Ensure your backend is running and reachable.");
      } else if (e is http.ClientException && e.message.contains('Connection refused')) {
        print("M-Pesa Connection Refused: Backend not running or not accessible at $_baseUrl.");
      } else {
        print("M-Pesa Connection Error: Ensure your backend is running at $_baseUrl. Error details: $e");
      }
      return null;
    }
  }

  /// Polls the backend to check the status of a specific transaction
  Future<bool> pollTransactionStatus(String checkoutId) async {
    int attempts = 0;
    const int maxAttempts = 12; // Poll for 60 seconds (12 * 5s)

    while (attempts < maxAttempts) {
      try {
        final response = await http.get(
          Uri.parse('$_baseUrl/status/$checkoutId'),
          headers: {'ngrok-skip-browser-warning': 'true'},
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['status'] == 'SUCCESS') return true;
          if (data['status'] == 'FAILED') return false;
        }
      } catch (e) {
        print("Polling error: $e");
      }

      attempts++;
      await Future.delayed(const Duration(seconds: 5));
    }
    
    return false; // Timeout
  }
}