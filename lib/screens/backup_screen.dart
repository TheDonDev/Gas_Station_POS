import 'package:flutter/material.dart';
import 'package:gas_store_pos/data/backup_service.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final BackupService _backupService = BackupService();
  bool _isLoading = false;

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _handleBackup() async {
    setState(() => _isLoading = true);
    await _backupService.backupDatabase(
      onSuccess: (msg) => _showMessage(msg),
      onError: (err) => _showMessage(err, isError: true),
    );
    setState(() => _isLoading = false);
  }

  Future<void> _handleRestore() async {
    setState(() => _isLoading = true);
    await _backupService.restoreDatabase(
      onSuccess: (msg) {
        _showMessage(msg);
        // Ideally show a dialog forcing the user to restart or exit
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text("Restore Complete"),
            content: const Text("The database has been restored. Please restart the application to reload the data."),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text("OK"),
              )
            ],
          ),
        );
      },
      onError: (err) => _showMessage(err, isError: true),
    );
    setState(() => _isLoading = false);
  }

  Future<void> _handleReset() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Factory Reset"),
        content: const Text("Are you sure you want to delete ALL data? This cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete All", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      await _backupService.resetDatabase(
        onSuccess: (msg) => _showMessage(msg),
        onError: (err) => _showMessage(err, isError: true),
      );
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Backup & Restore")),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.storage, size: 80, color: Colors.blueAccent),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: 200,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _handleBackup,
                      icon: const Icon(Icons.save),
                      label: const Text("Backup Database"),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: 200,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _handleRestore,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade100,
                        foregroundColor: Colors.orange.shade900,
                      ),
                      icon: const Icon(Icons.restore),
                      label: const Text("Restore Database"),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: 200,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _handleReset,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade100,
                        foregroundColor: Colors.red.shade900,
                      ),
                      icon: const Icon(Icons.delete_forever),
                      label: const Text("Factory Reset"),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40.0),
                    child: Text(
                      "Note: Restoring will overwrite the current data. Please ensure you have a backup before restoring.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}