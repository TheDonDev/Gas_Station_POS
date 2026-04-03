import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:gas_store_pos/data/api_config.dart';

class MpesaService {
  // Uses the central configuration to decide the URL
  String get _baseUrl => ApiConfig.baseUrl;
  
  Future<String?> initiateStkPush(String phone, double amount) async {
    // Validation: Ensure phone starts with 254 and is 12 digits long
    if (!RegExp(r'^254\d{9}$').hasMatch(phone)) {
      return null;
    }

    try {
      print("M-Pesa: Attempting STK Push to $_baseUrl/stkpush");
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
      print("STK Push Failed with Status: ${response.statusCode} - ${response.body}");
      return null;
    } catch (e) {
      if (e.toString().contains('SocketException') || e.toString().contains('host lookup')) {
        print("M-Pesa DNS Error: Host lookup failed for $_baseUrl. Ensure your ngrok tunnel is active and the URL matches exactly.");
      } else if (e.toString().contains('404')) {
        print("M-Pesa Error: The Ngrok tunnel $_baseUrl is offline or incorrect.");
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