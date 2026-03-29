import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:gas_store_pos/data/database_service.dart';
import 'package:gas_store_pos/data/mpesa_service.dart';
import 'package:gas_store_pos/providers/customer_provider.dart';
import 'package:gas_store_pos/providers/inventory_provider.dart';
import 'package:gas_store_pos/providers/cart_provider.dart';
import 'package:gas_store_pos/models/customer.dart';
import 'package:gas_store_pos/models/product.dart';
import 'package:gas_store_pos/providers/printer_provider.dart';
import 'package:gas_store_pos/utils/receipt_formatter.dart';
import 'package:gas_store_pos/screens/edit_product_screen.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  Product? _selectedProduct;
  int _quantity = 1;
  String _paymentType = 'Cash';
  Customer? _selectedCustomer;
  final TextEditingController _qtyController = TextEditingController(text: '1');
  final TextEditingController _phoneController = TextEditingController();
  double _availableBulkGas = 0.0;
  final AudioPlayer _audioPlayer = AudioPlayer();

  final List<String> _paymentMethods = ['Cash', 'M-Pesa', 'Credit (Debt)'];

  @override
  void initState() {
    super.initState();
    _qtyController.addListener(() {
      setState(() => _quantity = int.tryParse(_qtyController.text) ?? 0);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CustomerProvider>(context, listen: false).loadCustomers();
      Provider.of<InventoryProvider>(context, listen: false).loadProducts();
      _loadAvailableGas();
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableGas() async {
    final gas = await DatabaseService().getBulkGasKg();
    
    // Trigger alert if it drops below 50kg and was previously above it, 
    // or if it's found to be low on initial load.
    final bool justDroppedBelow = gas < 50 && _availableBulkGas >= 50;
    final bool isInitialLow = _availableBulkGas == 0.0 && gas < 50;

    setState(() {
      _availableBulkGas = gas;
    });

    if (justDroppedBelow || isInitialLow) {
      _triggerLowGasAlert();
    }
  }

  void _triggerLowGasAlert() {
    // Playing a standard alarm sound. Ensure the asset exists if using a local file.
    _audioPlayer.play(AssetSource('sounds/alarm.mp3')); 
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("LOW GAS ALERT: Bulk inventory is below 50 KG!"),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 4),
      ),
    );
  }

  bool _validateStock(CartProvider cart) {
    double totalRequired = 0;
    cart.items.forEach((key, item) {
      totalRequired += item.product.size * item.quantity;
    });

    if (totalRequired > _availableBulkGas) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              "Inadequate Bulk Gas! Available: ${_availableBulkGas.toStringAsFixed(1)}kg, Required: ${totalRequired.toStringAsFixed(1)}kg"),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
    return true;
  }

  void _processTransaction() async {
    final cart = Provider.of<CartProvider>(context, listen: false);
    if (cart.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Basket is empty!")));
      return;
    }

    if (!_validateStock(cart)) return;

    if (_paymentType == 'Credit (Debt)' && _selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a retailer for credit sales')),
      );
      return;
    }

    // Validate if the request to the backend actually works before proceeding
    _showCartSummaryDialog(cart);
  }

  void _finalizeCheckout(CartProvider cart) async {
    Navigator.pop(context); // Close summary dialog

    if (_paymentType == 'M-Pesa') {
      if (!RegExp(r'^254\d{9}$').hasMatch(_phoneController.text)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid Phone! Use 2547XXXXXXXX format.')),
        );
        return;
      }
      
      // Trigger the actual service
      final service = MpesaService();
      final checkoutId = await service.initiateStkPush(
        _phoneController.text, 
        cart.totalAmount, 
      );

      if (checkoutId != null) {
        _showMpesaDialog(checkoutId); 
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('M-Pesa request failed. Please check backend connection.'), backgroundColor: Colors.red),
          );
        }
      }
    } else {
      // Process the wholesale sale with multiple items
      await cart.checkout(_paymentType, customer: _selectedCustomer);
      _loadAvailableGas();
      _showPrintPrompt();
    }
  }

  Future<void> _printXReport() async {
    final printer = Provider.of<PrinterProvider>(context, listen: false);
    if (printer.selectedDevice == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No Printer Connected")));
      return;
    }

    final transactions = await DatabaseService().getTodayTransactions();
    if (transactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No transactions recorded today.")));
      return;
    }

    double totalCash = 0;
    double totalMpesa = 0;
    double totalCredit = 0;

    for (var tx in transactions) {
      final amount = (tx['total_amount'] as num).toDouble();
      final method = tx['payment_method'] as String;
      if (method == 'Cash') totalCash += amount;
      else if (method == 'M-Pesa') totalMpesa += amount;
      else totalCredit += amount;
    }

    try {
      final bytes = await ReceiptFormatter.formatXReport(
        storeName: printer.companyName,
        totalCash: totalCash,
        totalMpesa: totalMpesa,
        totalCredit: totalCredit,
        transactionCount: transactions.length,
      );
      await printer.printReceipt(bytes);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Printing X-Report...")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error printing report: $e")));
    }
  }

  Future<void> _printReceipt(BuildContext context) async {
    final printer = Provider.of<PrinterProvider>(context, listen: false);
    final cart = Provider.of<CartProvider>(context, listen: false);
    
    if (printer.selectedDevice != null) {
      final bytes = await ReceiptFormatter.formatReceipt(
        storeName: printer.companyName,
        items: cart.items,
        total: cart.totalAmount,
      );
      await printer.printReceipt(bytes);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Printing Receipt...")));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No Printer Connected")));
    }
  }

  void _showMpesaDialog(String checkoutId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Image.network('https://upload.wikimedia.org/wikipedia/commons/thumb/1/15/M-PESA_LOGO-01.svg/1200px-M-PESA_LOGO-01.svg.png', height: 30),
            const SizedBox(width: 10),
            const Text("STK Push Sent"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              height: 60,
              width: 60,
              child: CircularProgressIndicator(strokeWidth: 6, color: Colors.green),
            ),
            const SizedBox(height: 20),
            Text(
              "Sent to ${_phoneController.text}",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 10),
            const Text(
              "Please ask the customer to enter their M-Pesa PIN on their phone to complete the transaction.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ],
      ),
    );
    
    // Real-world logic: In production, you would poll your backend here 
    // to check the actual transaction status from Daraja/Safaricom.
    Future.delayed(const Duration(seconds: 5), () async {
      if (mounted) {
        Navigator.pop(context); // Close the M-Pesa waiting dialog
        
        final cart = Provider.of<CartProvider>(context, listen: false);
        // Note: For testing, we complete the checkout. 
        // In production, only call this if checkTransactionStatus returns "SUCCESS".
        await cart.checkout('M-Pesa', customer: _selectedCustomer);
        _loadAvailableGas();
        
        if (mounted) {
          _showPrintPrompt();
        }
      }
    });
  }
  void _showPrintPrompt() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Transaction Successful"),
        content: const Text("Would you like to print the receipt for this client?"),
        actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            _resetForm();
          },
          child: const Text("No, Close"),
        ),
          ElevatedButton(
            onPressed: () {
              _printReceipt(context);
              Navigator.pop(ctx);
            _resetForm();
            },
            child: const Text("Print Receipt"),
          ),
        ],
      ),
    );
  }

  void _resetForm() {
    setState(() {
      _selectedProduct = null;
      _quantity = 1;
      _qtyController.text = '1';
      _selectedCustomer = null;
    });
    Provider.of<CartProvider>(context, listen: false).clearCart();
  }

  void _showClearCartConfirmation(CartProvider cart) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Clear Basket?"),
        content: const Text("Are you sure you want to remove all items from the refill basket?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              cart.clearCart();
              Navigator.pop(ctx);
            },
            child: const Text("Clear All", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showCartSummaryDialog(CartProvider cart) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Review Refill Order"),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Refill Type", style: TextStyle(fontWeight: FontWeight.bold)),
                    const Text("Qty", style: TextStyle(fontWeight: FontWeight.bold)),
                    const Text("Subtotal", style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              ...cart.items.values.map((item) => ListTile(
                dense: true,
                title: Text("${item.product.name} (${item.product.brand})"),
                trailing: Text("x${item.quantity}"),
              )),
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Total Amount:", style: TextStyle(fontWeight: FontWeight.bold)),
                    Text("KES ${cart.totalAmount.toStringAsFixed(0)}", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Back")),
          ElevatedButton(
            onPressed: () => _finalizeCheckout(cart),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
            child: Text(_paymentType == 'M-Pesa' ? "Proceed to Payment" : "Confirm & Save"),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) => Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wholesale Refill POS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.assessment),
            tooltip: 'Print X-Report',
            onPressed: _printXReport,
          ),
          Consumer<CartProvider>(
            builder: (context, cart, _) => Badge(
              label: Text('${cart.items.length}'),
              isLabelVisible: cart.items.isNotEmpty,
              child: IconButton(
                icon: const Icon(Icons.shopping_cart_checkout),
                onPressed: () => _processTransaction(),
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bulk Gas Indicator
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _availableBulkGas < 50 ? Colors.red.shade50 : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.storage, color: _availableBulkGas < 50 ? Colors.red : Colors.blue),
                  const SizedBox(width: 10),
                  Text(
                    "Available Bulk Gas: ${_availableBulkGas.toStringAsFixed(2)} KG",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _availableBulkGas < 50 ? Colors.red : Colors.blue.shade900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildStepHeader(1, "Select Cylinder Size"),
            const SizedBox(height: 10),
            Consumer<InventoryProvider>(
              builder: (context, inv, _) {
                return Row(
                  children: [
                    Expanded(
                      child: DropdownMenu<Product>(
                        expandedInsets: EdgeInsets.zero,
                        initialSelection: _selectedProduct,
                        enableSearch: true,
                        enableFilter: true,
                        requestFocusOnTap: true,
                        label: const Text('Search & Select Cylinder'),
                        dropdownMenuEntries: inv.products.map((p) => DropdownMenuEntry<Product>(
                          value: p, 
                          label: '${p.name} | ${p.brand} - ${p.size}kg (KES ${p.priceRefill})'
                        )).toList(),
                        onSelected: (val) => setState(() => _selectedProduct = val),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.filled(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const EditProductScreen()),
                      ),
                      icon: const Icon(Icons.add),
                      tooltip: "Add New Cylinder Type",
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            
            _buildStepHeader(2, "Quantity to Refill"),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: 100, // Quick select limit
                      itemBuilder: (context, index) {
                        final val = index + 1;
                        final isSelected = _quantity == val;
                        return GestureDetector(
                          onTap: () {
                            _qtyController.text = val.toString();
                          },
                          child: Container(
                            width: 60,
                            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.blueAccent : Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: isSelected 
                                ? [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 4)] 
                                : null,
                            ),
                            alignment: Alignment.center,
                            child: Text('$val', 
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.black, 
                                fontWeight: FontWeight.bold)),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: _qtyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Manual Quantity Entry',
                prefixIcon: Icon(Icons.edit),
              ),
            ),
            const SizedBox(height: 30),
            
            // Add to Cart Button
            SValueButton(
              onPressed: _selectedProduct == null || _quantity == 0 
                ? null 
                : () {
                  Provider.of<CartProvider>(context, listen: false)
                      .addToCart(_selectedProduct!, quantity: _quantity);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Added to cart"), duration: Duration(seconds: 1)));
                },
              text: "Add to Refill Cart",
            ),
            const SizedBox(height: 30),

            // Current Cart Items (Creative UI)
            Consumer<CartProvider>(
              builder: (context, cart, child) {
                if (cart.items.isEmpty) {
                  return Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 20),
                    padding: const EdgeInsets.all(25),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.grey.shade100),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.shopping_cart_outlined, size: 40, color: Colors.grey.shade200),
                        const SizedBox(height: 10),
                        Text("Basket is empty", style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                      ],
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionTitle("Refill Basket"),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: InkWell(
                            onTap: () => _showClearCartConfirmation(cart),
                            child: const Row(
                              children: [
                                Icon(Icons.delete_sweep, color: Colors.red, size: 16),
                                SizedBox(width: 4),
                                Text("Clear Cart", style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Enhanced Creative Cart List
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: cart.items.length,
                      itemBuilder: (context, index) {
                        final entry = cart.items.entries.elementAt(index);
                      final key = entry.key;
                      final item = entry.value;
                      return Dismissible(
                        key: Key(key),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) => cart.removeItem(key),
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.delete_forever, color: Colors.white),
                        ),
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 12),
                            elevation: 0,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade200, width: 1),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 45,
                                      height: 45,
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Center(child: Icon(Icons.propane_tank_outlined, color: Colors.blueAccent, size: 24)),
                                    ),
                                    const SizedBox(width: 15),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: -0.5)),
                                          Text("${item.product.brand} • ${item.product.size}kg", style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                    Text("KES ${NumberFormat("#,###").format(item.total)}", style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.blueAccent)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(height: 1, color: Colors.grey.shade100),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        _qtyActionBtn(Icons.remove, () => cart.updateQuantity(key, item.quantity - 1)),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 15),
                                          child: Text("${item.quantity}", style: const TextStyle(fontWeight: FontWeight.bold)),
                                        ),
                                        _qtyActionBtn(Icons.add, () => cart.updateQuantity(key, item.quantity + 1)),
                                      ],
                                    ),
                                    Text(
                                      "Price: ${NumberFormat("#,###").format(item.product.priceRefill)}",
                                      style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontStyle: FontStyle.italic),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                      },
                    ),
                  ],
                );
              },
            ),
            
            _buildStepHeader(3, "Payment Method"),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              children: _paymentMethods.map((method) {
                final isSelected = _paymentType == method;
                return ChoiceChip(
                  label: Text(method),
                  selected: isSelected,
                  selectedColor: Colors.blue.withOpacity(0.2),
                  onSelected: (selected) {
                    if (selected) setState(() => _paymentType = method);
                  },
                );
              }).toList(),
            ),
            if (_paymentType == 'M-Pesa') ...[
              const SizedBox(height: 10),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                    labelText: 'Customer Phone (254...)',
                    border: OutlineInputBorder()),
                keyboardType: TextInputType.phone,
              ),
            ],

            if (_paymentType == 'Credit (Debt)') ...[
              const SizedBox(height: 20),
              _buildStepHeader(4, "Select Retailer (Customer)"),
              const SizedBox(height: 10),
              Consumer<CustomerProvider>(
                builder: (context, provider, child) {
                  return DropdownButtonFormField<Customer>(
                    value: _selectedCustomer,
                    decoration: const InputDecoration(
                        border: OutlineInputBorder(), labelText: 'Retailer'),
                    items: provider.customers
                        .map((c) => DropdownMenuItem(value: c, child: Text(c.name)))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedCustomer = val),
                  );
                },
              ),
            ],
            const SizedBox(height: 30),
            
            // Receipt-style Summary
            _buildDigitalReceipt(),
            const SizedBox(height: 20),
            SValueButton(
              onPressed: _selectedProduct == null || _quantity == 0 ? null : _processTransaction,
              text: _paymentType == 'M-Pesa' ? "Initiate M-Pesa STK Push" : "Confirm Refill Sale",
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildStepHeader(int step, String title) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
          child: Text('$step', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey)),
      ],
    );
  }

  Widget _buildDigitalReceipt() {
    return Consumer<CartProvider>(
      builder: (context, cart, _) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5))],
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Order Summary", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                const Icon(Icons.receipt_long, color: Colors.blueAccent),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(DateFormat('EEE, MMM d, yyyy').format(DateTime.now()), style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                Text(DateFormat('HH:mm').format(DateTime.now()), style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 15),
              child: Divider(thickness: 1, height: 1),
            ),
            if (cart.items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text("Basket is empty", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
              )
            else
              ...cart.items.values.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text("${item.quantity} x ${item.product.name} (${item.product.brand})", style: const TextStyle(fontSize: 14))),
                    Text("KES ${NumberFormat("#,###").format(item.total)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              )),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 15),
              child: Divider(thickness: 1, height: 1),
            ),
            _summaryRow("Payment Method", _paymentType),
            if (_paymentType == 'Credit (Debt)' && _selectedCustomer != null)
              _summaryRow("Retailer", _selectedCustomer!.name),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Grand Total", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  Text(
                    "KES ${NumberFormat("#,###").format(cart.totalAmount)}",
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Colors.blueAccent),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            Text(
              "---------------------------------------",
              style: TextStyle(color: Colors.grey.shade300, letterSpacing: 2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _qtyActionBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.blue.shade100),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20, color: Colors.blueAccent),
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class SValueButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String text;
  const SValueButton({super.key, this.onPressed, required this.text});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }
}