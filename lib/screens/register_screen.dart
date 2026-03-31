import 'dart:ui';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:gas_store_pos/widgets/animated_background.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  
  bool _isLoading = false;
  final _emailController = TextEditingController();
  final _confirmEmailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _otpController = TextEditingController();
  
  String _selectedRole = 'operator';
  bool _otpSent = false;
  int _secondsRemaining = 0;
  Timer? _timer;

  @override
  void dispose() {
    _emailController.dispose();
    _confirmEmailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    setState(() => _secondsRemaining = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_secondsRemaining > 0) _secondsRemaining--;
        else _timer?.cancel();
      });
    });
  }

  Future<void> _sendOTP() async {
    if (_emailController.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final String baseUrl = Platform.isAndroid ? 'http://10.0.2.2:3000' : 'http://localhost:3000';
      await http.post(
        Uri.parse('$baseUrl/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': _emailController.text.trim(), 'type': 'register'}),
      );
      _startTimer();
      setState(() => _otpSent = true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Verification code sent!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to send code')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _handleRegister() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        // Automatically handle the correct IP for Android Emulators vs Desktop/iOS
        final String baseUrl = Platform.isAndroid 
            ? 'http://10.0.2.2:3000' 
            : 'http://localhost:3000';
        
        final response = await http.post(
          Uri.parse('$baseUrl/register'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'ngrok-skip-browser-warning': 'true',
          },
          body: jsonEncode({
            'email': _emailController.text.trim(),
            'password': _passwordController.text,
            'role': _selectedRole,
            'otp': _otpController.text.trim(),
          }),
        );

        if (!mounted) return;

        final bool isJson = response.headers['content-type']?.contains('application/json') ?? false;

        if (response.statusCode == 201 && isJson) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account created! Please login.')),
          );
          Navigator.pop(context);
        } else if (isJson) {
          final error = jsonDecode(response.body)['error'] ?? 'Registration failed';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
        } else {
          debugPrint("Server Error (${response.statusCode}): ${response.body}");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Server Error: Received non-JSON response (${response.statusCode})')),
          );
        }
      } catch (e) {
        debugPrint("Registration Error: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection failed: $e')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedMeshBackground(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                width: 450,
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5), // Increased contrast for white text
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Hero(
                        tag: 'brand-logo',
                        child: Icon(Icons.local_gas_station, size: 80, color: Colors.white),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "CREATE ACCOUNT",
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.5),
                      ),
                      const SizedBox(height: 40),
                      _buildTextField(
                        "Email Address",
                        Icons.email_outlined,
                        controller: _emailController,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Email is required';
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) return 'Enter a valid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                        "Confirm Email Address",
                        Icons.email_outlined,
                        controller: _confirmEmailController,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Please confirm your email';
                          if (value != _emailController.text) return 'Emails do not match';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                        "Password",
                        Icons.lock_outline,
                        isPassword: true,
                        controller: _passwordController,
                        obscured: _obscurePassword,
                        onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
                        validator: (value) => value!.length < 6 ? 'Password must be 6+ characters' : null,
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                        "Confirm Password",
                        Icons.lock_reset_outlined,
                        isPassword: true,
                        controller: _confirmPasswordController,
                        obscured: _obscureConfirmPassword,
                        onToggle: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                        validator: (value) => value != _passwordController.text ? 'Passwords do not match' : null,
                      ),
                      const SizedBox(height: 40),
                      TextButton.icon(
                        onPressed: (_isLoading || _secondsRemaining > 0) ? null : _sendOTP,
                        icon: Icon(_otpSent ? Icons.refresh : Icons.send, color: Colors.white),
                        label: Text(
                          _secondsRemaining > 0 ? "Resend in ${_secondsRemaining}s" : (_otpSent ? "Resend Code" : "Verify Email to Register"),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      if (_otpSent) ...[
                        const SizedBox(height: 10),
                        _buildTextField(
                          "Verification Code",
                          Icons.security,
                          controller: _otpController,
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Enter code sent to email';
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        value: _selectedRole,
                        dropdownColor: Colors.blueGrey.shade900,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: "Account Role",
                          labelStyle: const TextStyle(color: Colors.white70),
                          prefixIcon: const Icon(Icons.badge_outlined, color: Colors.white70),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.white.withOpacity(0.3))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.white)),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                        ),
                        // Remove 'admin' from here after initial setup for extra security
                        items: ['operator'].map((role) => DropdownMenuItem(value: role, child: Text(role.toUpperCase()))).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedRole = val);
                        },
                      ),
                      const SizedBox(height: 40),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.blue.shade900,
                          minimumSize: const Size(double.infinity, 55),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        onPressed: _isLoading ? null : _handleRegister,
                        child: _isLoading 
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text("REGISTER", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Already have an account? Login", style: TextStyle(color: Colors.white70)),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, IconData icon, {bool isPassword = false, required TextEditingController controller, VoidCallback? onToggle, bool obscured = false, String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword ? obscured : false,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white70),
        suffixIcon: isPassword ? IconButton(icon: Icon(obscured ? Icons.visibility_off : Icons.visibility, color: Colors.white70), onPressed: onToggle) : null,
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.white.withOpacity(0.3))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.white)),
        errorStyle: const TextStyle(color: Colors.orangeAccent),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
      ),
    );
  }
}