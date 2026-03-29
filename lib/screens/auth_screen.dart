import 'package:flutter/material.dart';
import 'package:gas_store_pos/data/database_service.dart';
import 'package:gas_store_pos/screens/dashboard_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = true;
  bool _isLoading = false;

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final db = DatabaseService();
    bool success = false;

    if (_isLogin) {
      final userData = await db.loginUser(_usernameController.text, _passwordController.text);
      success = userData != null;
    } else {
      success = await db.registerUser(_usernameController.text, _passwordController.text, "Operator");
    }

    setState(() => _isLoading = false);

    if (success) {
      if (!mounted) return;
      if (!_isLogin) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Account created! Please login.")));
        setState(() => _isLogin = true);
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
      }
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isLogin ? "Invalid credentials" : "Username already taken")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.oil_barrel, size: 80, color: Colors.blueAccent),
                const SizedBox(height: 20),
                Text(
                  _isLogin ? "Wholesale LPG Portal" : "Register New Account",
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text("Secure Access for Wholesale Operations", style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 40),
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) => val!.isEmpty ? 'Enter username' : null,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock),
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) => val!.length < 6 ? 'Password too short' : null,
                ),
                const SizedBox(height: 30),
                _isLoading
                    ? const CircularProgressIndicator()
                    : SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _submit,
                          child: Text(_isLogin ? "Login" : "Create Account"),
                        ),
                      ),
                TextButton(
                  onPressed: () => setState(() => _isLogin = !_isLogin),
                  child: Text(_isLogin ? "New user? Register here" : "Already have an account? Login"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}