import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:gas_store_pos/data/database_service.dart';

class BackupService {
  // Ensure this matches the name used in your DatabaseService
  static const String _dbName = 'gas_store.db';

  Future<void> backupDatabase({
    required Function(String) onSuccess,
    required Function(String) onError,
  }) async {
    try {
      // Use getApplicationDocumentsDirectory to match DatabaseService location
      final dbPath = (await getApplicationDocumentsDirectory()).path;
      final sourcePath = join(dbPath, _dbName);
      final sourceFile = File(sourcePath);

      if (!await sourceFile.exists()) {
        onError("Database file not found at $sourcePath");
        return;
      }

      // Open directory picker
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Backup Location',
        // The next line is for desktop, specifying initial directory
        initialDirectory: (await getApplicationDocumentsDirectory()).path, 
      );

      if (selectedDirectory != null) {
        final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        final backupName = 'gas_store_backup_$timestamp.db';
        final destinationPath = join(selectedDirectory, backupName);

        await sourceFile.copy(destinationPath);
        onSuccess("Backup saved successfully to:\n$destinationPath");
      }
    } catch (e) {
      onError("Backup failed: $e");
    }
  }

  /// Exports a list of maps to a JSON file
  Future<void> exportData({
    required String fileNamePrefix,
    required List<Map<String, dynamic>> data,
    required Function(String) onSuccess,
    required Function(String) onError,
  }) async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Export Location',
      );

      if (selectedDirectory != null) {
        final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        final fileName = '${fileNamePrefix}_$timestamp.json';
        final destinationPath = join(selectedDirectory, fileName);

        final file = File(destinationPath);
        await file.writeAsString(jsonEncode(data));
        onSuccess("Data exported successfully to:\n$fileName");
      }
    } catch (e) {
      onError("Export failed: $e");
    }
  }

  /// Imports data from a JSON file and returns a list of maps
  Future<void> importData({
    required Function(List<dynamic>) onSuccess,
    required Function(String) onError,
  }) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Select JSON Backup File',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final content = await file.readAsString();
        final List<dynamic> data = jsonDecode(content);
        onSuccess(data);
      }
    } catch (e) {
      onError("Import failed: $e");
    }
  }

  Future<void> restoreDatabase({
    required Function(String) onSuccess,
    required Function(String) onError,
  }) async {
    try {
      // Pick the backup file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Select Backup Database',
        type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        File backupFile = File(result.files.single.path!);
        
        // Delegate to DatabaseService to ensure the connection is closed and reset properly
        await DatabaseService().restoreDatabase(backupFile.path);
        
        onSuccess("Database restored successfully.\nPlease restart the application to apply changes.");
      }
    } catch (e) {
      onError("Restore failed: $e");
    }
  }

  Future<void> resetDatabase({
    required Function(String) onSuccess,
    required Function(String) onError,
  }) async {
    try {
      await DatabaseService().resetDatabase();
      onSuccess("Database reset successfully.\nPlease restart the application.");
    } catch (e) {
      onError("Reset failed: $e");
    }
  }
}