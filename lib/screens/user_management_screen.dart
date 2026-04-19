import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:gas_store_pos/data/api_config.dart';
import 'package:gas_store_pos/providers/auth_provider.dart';
import 'package:gas_store_pos/providers/theme_provider.dart';
import 'package:gas_store_pos/data/database_service.dart';
import 'package:gas_store_pos/widgets/animated_background.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedRole = 'operator';
  bool _isLoading = false;
  String? _selectedBranchId;
  Future<List<dynamic>>? _usersFuture;

  @override
  void initState() {
    super.initState();
    _refreshUsers();
  }

  void _refreshUsers() {
    final auth = context.read<AuthProvider>();
    setState(() {
      _usersFuture = _fetchUsers(auth.token);
    });
  }

  Future<List<dynamic>> _fetchUsers(String? token) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/admin/users'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load users');
  }

  Future<void> _deleteUser(String userId) async {
    final auth = context.read<AuthProvider>();
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/admin/users/$userId'),
        headers: {'Authorization': 'Bearer ${auth.token}'},
      );
      if (response.statusCode == 200) _refreshUsers();
    } catch (_) {}
  }

  Future<void> _createUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final auth = context.read<AuthProvider>();

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/admin/register-user'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${auth.token}',
        },
        body: jsonEncode({
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
          'role': _selectedRole,
          'branchId': _selectedBranchId,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User account created successfully!')),
        );
        _emailController.clear();
        _passwordController.clear();
        _refreshUsers();
      } else {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? 'Failed to create user')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Server connection failed')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final bool isDark = themeProvider.isDarkMode;

    return AnimatedMeshBackground(
      child: Scaffold(
        backgroundColor: isDark ? Colors.black.withOpacity(0.45) : Colors.white.withOpacity(0.6),
        appBar: AppBar(
          title: const Text("User Management"),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildRegistrationForm(isDark),
              const SizedBox(height: 30),
              _buildUserList(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRegistrationForm(bool isDark) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            width: 500,
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: isDark ? Colors.black.withOpacity(0.3) : Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person_add, size: 50, color: Colors.blueAccent),
                  const SizedBox(height: 20),
                  Text("Register System User", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 25),
                  TextFormField(
                    controller: _emailController,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: "Email Address", 
                      labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                    ),
                    validator: (val) => val!.isEmpty ? "Email required" : null,
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _passwordController,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: "Temporary Password", 
                      labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                    ),
                    obscureText: true,
                    validator: (val) => val!.length < 6 ? "Minimum 6 characters" : null,
                  ),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    value: _selectedRole,
                    dropdownColor: isDark ? Colors.blueGrey.shade900 : Colors.white,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: "Assign Role", 
                      labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                    ),
                    items: ['operator', 'admin'].map((r) => DropdownMenuItem(value: r, child: Text(r.toUpperCase()))).toList(),
                    onChanged: (val) => setState(() => _selectedRole = val!),
                  ),
                  const SizedBox(height: 15),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: DatabaseService().getBranches(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox();
                      return DropdownButtonFormField<String>(
                        value: _selectedBranchId,
                        dropdownColor: isDark ? Colors.blueGrey.shade900 : Colors.white,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                        decoration: InputDecoration(
                          labelText: "Assign to Branch", 
                          labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                        ),
                        items: snapshot.data!.map((b) => DropdownMenuItem(
                          value: b['id'].toString(), // Use the local ID or synced MongoDB ID
                          child: Text(b['name'] ?? 'Unknown'),
                        )).toList(),
                        onChanged: (val) => setState(() => _selectedBranchId = val),
                      );
                    },
                  ),
                  const SizedBox(height: 35),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isLoading ? null : _createUser,
                    child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("CREATE ACCOUNT", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserList(bool isDark) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            width: 500,
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: isDark ? Colors.black.withOpacity(0.3) : Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                Text("Existing Accounts", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                FutureBuilder<List<dynamic>>(
                  future: _usersFuture,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final users = snapshot.data!;
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: users.length,
                      itemBuilder: (ctx, i) {
                        final user = users[i];
                        return ListTile(
                          title: Text(user['email'], style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                          subtitle: Text(user['role'].toString().toUpperCase(), style: const TextStyle(color: Colors.blueAccent, fontSize: 12)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            onPressed: () => _deleteUser(user['_id']),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}