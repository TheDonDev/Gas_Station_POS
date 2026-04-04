import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthUser {
  final String email;
  final String role;
  final String token;

  AuthUser({required this.email, required this.role, required this.token});

  Map<String, dynamic> toMap() => {'email': email, 'role': role, 'token': token};
  factory AuthUser.fromMap(Map<String, dynamic> map) => 
      AuthUser(email: map['email'], role: map['role'], token: map['token']);
}

class AuthProvider with ChangeNotifier {
  AuthUser? _user;
  bool _isAuthenticated = false;

  AuthUser? get user => _user;
  String? get token => _user?.token;
  bool get isAuthenticated => _isAuthenticated;
  bool get isAdmin => _user?.role == 'admin';

  AuthProvider() {
    _loadSession();
  }

  Future<void> login(String email, String role, String token) async {
    _user = AuthUser(email: email, role: role, token: token);
    _isAuthenticated = true;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_session', jsonEncode(_user!.toMap()));
    
    notifyListeners();
  }

  Future<void> logout() async {
    _user = null;
    _isAuthenticated = false;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_session'); // Ensure this key is cleared
    
    notifyListeners();
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionStr = prefs.getString('user_session');
    
    if (sessionStr != null) {
      try {
        _user = AuthUser.fromMap(jsonDecode(sessionStr));
        _isAuthenticated = true;
      } catch (e) {
        await prefs.remove('user_session');
      }
    }
    notifyListeners();
  }
}