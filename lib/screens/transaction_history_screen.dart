import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:convert';
import 'package:gas_store_pos/data/database_service.dart';
import 'package:gas_store_pos/data/backup_service.dart';
import 'package:path_provider/path_provider.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;
  DateTimeRange? _selectedDateRange;
  final BackupService _backupService = BackupService();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final ds = DatabaseService();
    final data = _selectedDateRange != null 
      ? await ds.getTransactionsByRange(_selectedDateRange!.start, _selectedDateRange!.end)
      : await ds.getAllTransactions();
      
    setState(() {
      _transactions = data;
      _isLoading = false;
    });
  }

  Future<void> _pickDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2022),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
    );

    if (picked != null) {
      setState(() => _isLoading = true);
      _selectedDateRange = picked;
      _loadData();
    }
  }

  Future<void> _exportToCSV() async {
    try {
      StringBuffer sb = StringBuffer();
      // CSV Header Row
      sb.writeln("Date,Time,Items Sold,Quantity,Payment Method,Total Amount (KES)");

      for (var tx in _transactions) {
        final List items = jsonDecode(tx['items_json'] ?? '[]');
        // Use a pipe | or semicolon to separate multiple items within a single CSV cell
        final String productNames = items.map((i) => i['name']).join(" | ");
        final String qtys = items.map((i) => i['qty'].toString()).join(" | ");

        DateTime dt = DateTime.parse(tx['date']);
        String date = DateFormat('yyyy-MM-dd').format(dt);
        String time = DateFormat('hh:mm a').format(dt);

        // Wrap string fields in quotes to prevent Excel from breaking on commas or special characters
        sb.writeln("$date,$time,\"$productNames\",\"$qtys\",${tx['payment_method']},${tx['total_amount']}");
      }

      // Save to Documents folder for Windows/Desktop
      final directory = await getApplicationDocumentsDirectory();
      final fileName = "Sales_Ledger_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv";
      final path = "${directory.path}/$fileName";
      
      final file = File(path);
      await file.writeAsString(sb.toString());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Ledger exported to Documents: $fileName"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("CSV Export failed: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Ledger (Spreadsheet View)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: "Import Ledger",
            onPressed: () => _backupService.importData(
              onSuccess: (data) async {
                final db = await DatabaseService().database;
                for (var item in data) {
                  final map = Map<String, dynamic>.from(item as Map);
                  map.remove('id'); // Let the DB generate a new unique ID
                  await db.insert('transactions', map);
                }
                _loadData();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Imported ${data.length} transactions")));
              },
              onError: (err) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err), backgroundColor: Colors.red)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.file_download), 
            tooltip: "Export Ledger",
            onPressed: () => _backupService.exportData(
              fileNamePrefix: 'sales_history',
              data: _transactions,
              onSuccess: (msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg))),
              onError: (err) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err), backgroundColor: Colors.red)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.table_view),
            tooltip: "Export as CSV (Excel)",
            onPressed: _exportToCSV,
          ),
          IconButton(
            icon: Icon(Icons.filter_list, color: _selectedDateRange != null ? Colors.orange : null), 
            tooltip: "Filter by Date Range",
            onPressed: _pickDateRange,
          ),
          if (_selectedDateRange != null)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: "Clear Filter",
              onPressed: () {
                setState(() {
                  _selectedDateRange = null;
                  _isLoading = true;
                });
                _loadData();
              },
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _selectedDateRange == null 
                  ? "Daily Transaction Log" 
                  : "Transactions: ${DateFormat('yMMMd').format(_selectedDateRange!.start)} - ${DateFormat('yMMMd').format(_selectedDateRange!.end)}",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            if (!_isLoading) ...[
              const SizedBox(height: 4),
              Text(
                "Total Sales for Period: KES ${NumberFormat("#,###.00").format(_transactions.fold(0.0, (sum, tx) => sum + (tx['total_amount'] as num).toDouble()))}",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.blueGrey),
              ),
            ],
            const SizedBox(height: 15),
            _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : Expanded(
              child: Theme(
                // Professional look for the spreadsheet
                data: Theme.of(context).copyWith(dividerColor: Colors.grey[300]),
                child: DataTable2(
                  columnSpacing: 12,
                  horizontalMargin: 12,
                  minWidth: 800, // Allows horizontal scrolling on small screens
                  fixedTopRows: 1,
                  headingRowColor: MaterialStateProperty.all(Colors.blueGrey[50]),
                  headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                  columns: const [
                    DataColumn2(label: Text('Date'), size: ColumnSize.S),
                    DataColumn2(label: Text('Time'), size: ColumnSize.S),
                    DataColumn2(label: Text('Items Sold'), size: ColumnSize.L),
                    DataColumn2(label: Text('Qty'), numeric: true, size: ColumnSize.S),
                    DataColumn2(label: Text('Payment'), size: ColumnSize.M),
                    DataColumn2(label: Text('Total (KES)'), numeric: true, size: ColumnSize.M),
                    DataColumn2(label: Text('Inventory Status'), size: ColumnSize.M),
                  ],
                  empty: const Center(child: Text("No sales recorded in the ledger yet.")),
                  rows: _transactions.map((tx) {
                    // Parse the items JSON to show what was refilled
                    final List items = jsonDecode(tx['items_json'] ?? '[]');
                    final String productNames = items.map((i) => i['name']).join(", ");
                    final String qtys = items.map((i) => i['qty'].toString()).join(", ");
                    
                    // Format date and time
                    DateTime dt = DateTime.parse(tx['date']);
                    String dateOnly = DateFormat('yyyy-MM-dd').format(dt);
                    String timeOnly = DateFormat('hh:mm a').format(dt);

                    return DataRow(cells: [
                      DataCell(Text(dateOnly)),
                      DataCell(Text(timeOnly)),
                      DataCell(Text(productNames.isEmpty ? "Unknown" : productNames, overflow: TextOverflow.ellipsis)),
                      DataCell(Text(qtys.isEmpty ? "0" : qtys)),
                      DataCell(_buildTypeChip(tx['payment_method'] ?? 'Cash')),
                      DataCell(Text(NumberFormat("#,###.00").format(tx['total_amount']))),
                      DataCell(const Text("Stock Updated", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12))),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(String type) {
    Color color;
    switch (type) {
      case 'M-Pesa': color = Colors.green; break;
      case 'Credit':
      case 'Credit (Debt)': color = Colors.red; break;
      default: color = Colors.orange;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(type, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}