import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gas_store_pos/providers/customer_provider.dart';
import 'package:gas_store_pos/models/customer.dart';

class CustomerScreen extends StatefulWidget {
  const CustomerScreen({super.key});

  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CustomerProvider>(context, listen: false).loadCustomers();
    });
  }

  void _showCustomerDialog({Customer? customer}) {
    final nameController = TextEditingController(text: customer?.name ?? '');
    final phoneController = TextEditingController(text: customer?.phone ?? '');
    final idController = TextEditingController(text: customer?.nationalId ?? '');
    final debtController = TextEditingController(text: customer?.debt.toString() ?? '0');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(customer == null ? 'Add Customer' : 'Edit Customer'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone,
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: idController,
                decoration: const InputDecoration(labelText: 'National ID Number'),
                keyboardType: TextInputType.number,
              ),
              TextFormField(
                controller: debtController,
                decoration: const InputDecoration(labelText: 'Initial Debt'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final newCustomer = Customer(
                  id: customer?.id,
                  name: nameController.text,
                  phone: phoneController.text,
                  nationalId: idController.text.isNotEmpty ? idController.text : null, // Assign nationalId
                  debt: double.tryParse(debtController.text) ?? 0.0,
                );

                if (customer == null) {
                  Provider.of<CustomerProvider>(context, listen: false).addCustomer(newCustomer);
                } else {
                  Provider.of<CustomerProvider>(context, listen: false).updateCustomer(newCustomer);
                }
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customers')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCustomerDialog(),
        child: const Icon(Icons.person_add),
      ),
      body: Consumer<CustomerProvider>(
        builder: (context, provider, child) {
          if (provider.customers.isEmpty) {
            return const Center(child: Text('No customers found.'));
          }
          return ListView.builder(
            itemCount: provider.customers.length,
            itemBuilder: (context, index) {
              final customer = provider.customers[index];
              return ListTile(
                leading: CircleAvatar(child: Text(customer.name[0].toUpperCase())),
                title: Text(customer.name),
                subtitle: Text('${customer.phone} ${customer.nationalId != null ? ' | ID: ${customer.nationalId}' : ''}'), // Display nationalId
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Debt', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        Text(
                          'KES ${customer.debt.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: customer.debt > 0 ? Colors.red : Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete Customer'),
                            content: Text('Are you sure you want to delete ${customer.name}?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                              TextButton(onPressed: () {
                                Provider.of<CustomerProvider>(context, listen: false).deleteCustomer(customer.id!);
                                Navigator.pop(ctx);
                              }, child: const Text('Delete', style: TextStyle(color: Colors.red))),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
                onTap: () => _showCustomerDialog(customer: customer),
              );
            },
          );
        },
      ),
    );
  }
}
