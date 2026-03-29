import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:intl/intl.dart';
import 'package:gas_store_pos/models/cart_item.dart';

class ReceiptFormatter {
  static Future<List<int>> formatReceipt({
    required String storeName,
    required Map<String, CartItem> items,
    required double total,
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    List<int> bytes = [];

    // Header
    bytes.addAll(generator.text(storeName, styles: const PosStyles(align: PosAlign.center, height: PosTextSize.size2, width: PosTextSize.size2)));
    bytes.addAll(generator.text('Sales Receipt', styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(generator.text(DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()), styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(generator.hr());

    // Items
    bytes.addAll(generator.row([
      PosColumn(text: 'Item', width: 6, styles: const PosStyles(bold: true)),
      PosColumn(text: 'Qty', width: 1, styles: const PosStyles(bold: true, align: PosAlign.center)),
      PosColumn(text: 'Price', width: 2, styles: const PosStyles(bold: true, align: PosAlign.right)),
      PosColumn(text: 'Total', width: 3, styles: const PosStyles(bold: true, align: PosAlign.right)),
    ]));

    for (var item in items.values) {
      bytes.addAll(generator.row([
        PosColumn(text: '${item.product.name} (${item.product.brand})', width: 6),
        PosColumn(text: item.quantity.toString(), width: 1, styles: const PosStyles(align: PosAlign.center)),
        PosColumn(text: item.product.priceRefill.toStringAsFixed(0), width: 2, styles: const PosStyles(align: PosAlign.right)),
        PosColumn(text: item.total.toStringAsFixed(0), width: 3, styles: const PosStyles(align: PosAlign.right)),
      ]));
    }

    bytes.addAll(generator.hr());

    // Total
    bytes.addAll(generator.row([
      PosColumn(text: 'TOTAL', width: 6, styles: const PosStyles(bold: true, height: PosTextSize.size2, width: PosTextSize.size2)),
      PosColumn(text: 'KES ${total.toStringAsFixed(0)}', width: 6, styles: const PosStyles(bold: true, align: PosAlign.right, height: PosTextSize.size2, width: PosTextSize.size2)),
    ]));

    bytes.addAll(generator.hr());
    bytes.addAll(generator.text('Thank you!', styles: const PosStyles(align: PosAlign.center, bold: true)));
    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.cut());

    return bytes;
  }

  static Future<List<int>> formatXReport({
    required String storeName,
    required double totalCash,
    required double totalMpesa,
    required double totalCredit,
    required int transactionCount,
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    List<int> bytes = [];

    // Header
    bytes.addAll(generator.text(storeName, styles: const PosStyles(align: PosAlign.center, height: PosTextSize.size2, width: PosTextSize.size2)));
    bytes.addAll(generator.text('DAILY X-REPORT', styles: const PosStyles(align: PosAlign.center, bold: true)));
    bytes.addAll(generator.text('Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}', styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(generator.hr());

    // Statistics
    bytes.addAll(generator.text('Total Transactions: $transactionCount', styles: const PosStyles(align: PosAlign.left)));
    bytes.addAll(generator.hr());

    // Breakdown Header
    bytes.addAll(generator.row([
      PosColumn(text: 'Payment Method', width: 8, styles: const PosStyles(bold: true)),
      PosColumn(text: 'Amount (KES)', width: 4, styles: const PosStyles(bold: true, align: PosAlign.right)),
    ]));

    // Cash
    bytes.addAll(generator.row([
      PosColumn(text: 'Cash Sales', width: 8),
      PosColumn(text: totalCash.toStringAsFixed(0), width: 4, styles: const PosStyles(align: PosAlign.right)),
    ]));

    // M-Pesa
    bytes.addAll(generator.row([
      PosColumn(text: 'M-Pesa Sales', width: 8),
      PosColumn(text: totalMpesa.toStringAsFixed(0), width: 4, styles: const PosStyles(align: PosAlign.right)),
    ]));

    // Credit
    bytes.addAll(generator.row([
      PosColumn(text: 'Credit/Debt Sales', width: 8),
      PosColumn(text: totalCredit.toStringAsFixed(0), width: 4, styles: const PosStyles(align: PosAlign.right)),
    ]));

    bytes.addAll(generator.hr());

    // Grand Total
    final grandTotal = totalCash + totalMpesa + totalCredit;
    bytes.addAll(generator.text('GRAND TOTAL: KES ${grandTotal.toStringAsFixed(0)}', 
      styles: const PosStyles(bold: true, align: PosAlign.right, height: PosTextSize.size2, width: PosTextSize.size2)));

    bytes.addAll(generator.hr());
    bytes.addAll(generator.text('End of Report', styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.cut());

    return bytes;
  }
}