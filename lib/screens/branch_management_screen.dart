import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:gas_store_pos/data/api_config.dart';
import 'package:gas_store_pos/providers/auth_provider.dart';
import 'package:gas_store_pos/providers/theme_provider.dart';
import 'package:gas_store_pos/widgets/animated_background.dart';

class BranchManagementScreen extends StatefulWidget {
  const BranchManagementScreen({super.key});

  @override
  State<BranchManagementScreen> createState() => _BranchManagementScreenState();
}

class _BranchManagementScreenState extends State<BranchManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _branchNameController = TextEditingController();
  final _locationController = TextEditingController();
  Future<List<Map<String, dynamic>>>? _branchesFuture;

  @override
  void initState() {
    super.initState();
    _refreshBranches();
  }

  Future<List<Map<String, dynamic>>> _fetchBranches() async {
    final auth = context.read<AuthProvider>();
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/branches'),
      headers: {'Authorization': 'Bearer ${auth.token}'},
    );
    return List<Map<String, dynamic>>.from(jsonDecode(response.body));
  }

  void _refreshBranches() {
    setState(() {
      _branchesFuture = _fetchBranches();
    });
  }

  void _showAddBranchDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Consumer<ThemeProvider>(
        builder: (context, theme, _) => AlertDialog(
          backgroundColor: theme.isDarkMode ? Colors.brown.shade900 : Colors.white,
        title: Text("Register New Branch", style: TextStyle(color: theme.isDarkMode ? Colors.white : Colors.black87)),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _branchNameController,
                style: TextStyle(color: theme.isDarkMode ? Colors.white : Colors.black87),
                decoration: InputDecoration(labelText: "Branch Name (e.g. City Gas South)", labelStyle: TextStyle(color: theme.isDarkMode ? Colors.white70 : Colors.black54)),
                validator: (val) => val!.isEmpty ? "Required" : null,
              ),
              TextFormField(
                controller: _locationController,
                style: TextStyle(color: theme.isDarkMode ? Colors.white : Colors.black87),
                decoration: InputDecoration(labelText: "City / Location", labelStyle: TextStyle(color: theme.isDarkMode ? Colors.white70 : Colors.black54)),
                validator: (val) => val!.isEmpty ? "Required" : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                try {
                  final auth = context.read<AuthProvider>();
                  final response = await http.post(
                    Uri.parse('${ApiConfig.baseUrl}/branches'),
                    headers: {
                      'Content-Type': 'application/json',
                      'Authorization': 'Bearer ${auth.token}',
                    },
                    body: jsonEncode({
                      'name': _branchNameController.text,
                      'location': _locationController.text,
                    }),
                  );
                  if (response.statusCode == 201) {
                    Navigator.pop(ctx);
                    _refreshBranches();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Branch Registered")));
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                }
              }
            },
            child: const Text("Add Branch"),
          ),
        ],
      ), // AlertDialog
    ), // Consumer builder
  ); // showDialog
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final bool isDark = themeProvider.isDarkMode;

    return AnimatedMeshBackground(
      child: Scaffold(
        backgroundColor: isDark ? Colors.black.withOpacity(0.45) : Colors.white.withOpacity(0.6),
        appBar: AppBar(
          title: const Text("Branch Management"),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Registered Branches", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 20),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: FutureBuilder<List<Map<String, dynamic>>>(
                        future: _branchesFuture,
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                          final branches = snapshot.data!;
                          if (branches.isEmpty) return const Center(child: Text("No branches found.", style: TextStyle(color: Colors.white70)));
                          
                          return ListView.builder(
                            itemCount: branches.length, 
                            itemBuilder: (context, index) {
                              final b = branches[index];
                              return ListTile(
                                leading: const CircleAvatar(backgroundColor: Colors.brown, child: Icon(Icons.business, color: Colors.white)),
                                title: Text(b['name'] ?? 'Unknown', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                subtitle: Text(b['location'] ?? 'No Location', style: const TextStyle(color: Colors.white70)),
                                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white24),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showAddBranchDialog,
          backgroundColor: Colors.brown,
          icon: const Icon(Icons.add_location_alt),
          label: const Text("Add New Branch"),
        ),
      ),
    );
  }
}