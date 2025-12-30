import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'dart:io';

// --- UI CONSTANTS ---
const Color _primaryColor = Color(0xFF2F7CF6);
const Color _successColor = Color(0xFF4CAF50);
const Color _cardBorder = Color(0xFFE3F2FD);
const Color _scaffoldBg = Colors.white;

class AddCustomerPage extends StatefulWidget {
  final String uid;
  final VoidCallback? onBack;

  const AddCustomerPage({
    super.key,
    required this.uid,
    this.onBack,
  });

  @override
  State<AddCustomerPage> createState() => _AddCustomerPageState();
}

class _AddCustomerPageState extends State<AddCustomerPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _gstinController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _lastDueController = TextEditingController();
  DateTime? _selectedDOB;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _gstinController.dispose();
    _addressController.dispose();
    _lastDueController.dispose();
    super.dispose();
  }

  Future<void> _selectDOB(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDOB ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: _primaryColor),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedDOB = picked;
      });
    }
  }

  Future<void> _saveCustomer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final phone = _phoneController.text.trim();
      final customersCollection = await FirestoreService().getStoreCollection('customers');

      // Check if customer already exists
      final existing = await customersCollection.doc(phone).get();
      if (existing.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('customer_already_exists')),
              backgroundColor: Colors.orange,
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final lastDue = double.tryParse(_lastDueController.text.trim()) ?? 0.0;

      // Create customer document
      await customersCollection.doc(phone).set({
        'name': _nameController.text.trim(),
        'phone': phone,
        'gstin': _gstinController.text.trim().isEmpty ? null : _gstinController.text.trim(),
        'address': _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        'balance': lastDue,
        'totalSales': lastDue, // Set totalSales to lastDue for opening balance
        'dob': _selectedDOB != null ? Timestamp.fromDate(_selectedDOB!) : null,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // If last due > 0, create credit entry in ledger for tracking
      if (lastDue > 0) {
        final creditsCollection = await FirestoreService().getStoreCollection('credits');
        await creditsCollection.add({
          'customerId': phone,
          'customerName': _nameController.text.trim(),
          'amount': lastDue,
          'type': 'add_credit',
          'method': 'Manual',
          'timestamp': FieldValue.serverTimestamp(),
          'date': DateTime.now().toIso8601String(),
          'note': 'Opening Balance - Last Due Added',
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('customer_added_successfully')),
            backgroundColor: _successColor,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.tr('error')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _importFromContacts() async {
    try {
      if (!await FlutterContacts.requestPermission()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('permission_denied')),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );

      if (mounted) {
        _showContactsDialog(contacts);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.tr('error')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showContactsDialog(List<Contact> contacts) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          context.tr('select_contact'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: contacts.length,
            itemBuilder: (context, index) {
              final contact = contacts[index];
              final phone = contact.phones.isNotEmpty ? contact.phones.first.number : '';

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: _primaryColor.withOpacity(0.1),
                  child: Text(
                    contact.displayName.isNotEmpty ? contact.displayName[0].toUpperCase() : '?',
                    style: const TextStyle(color: _primaryColor, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(contact.displayName),
                subtitle: Text(phone),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _nameController.text = contact.displayName;
                    _phoneController.text = phone.replaceAll(RegExp(r'[^0-9+]'), '');
                  });
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('cancel')),
          ),
        ],
      ),
    );
  }

  Future<void> _importFromExcel() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result != null) {
        File file = File(result.files.single.path!);
        var bytes = file.readAsBytesSync();
        var excel = excel_pkg.Excel.decodeBytes(bytes);

        int imported = 0;
        int skipped = 0;

        for (var table in excel.tables.keys) {
          var sheet = excel.tables[table]!;

          // Skip header row
          for (var rowIndex = 1; rowIndex < sheet.maxRows; rowIndex++) {
            var row = sheet.rows[rowIndex];

            if (row.length < 2) continue;

            final name = row[0]?.value?.toString().trim() ?? '';
            final phone = row[1]?.value?.toString().trim() ?? '';
            final gstin = row.length > 2 ? row[2]?.value?.toString().trim() ?? '' : '';
            final address = row.length > 3 ? row[3]?.value?.toString().trim() ?? '' : '';
            final lastDue = row.length > 4 ? double.tryParse(row[4]?.value?.toString() ?? '0') ?? 0.0 : 0.0;

            if (name.isEmpty || phone.isEmpty) {
              skipped++;
              continue;
            }

            final customersCollection = await FirestoreService().getStoreCollection('customers');
            final existing = await customersCollection.doc(phone).get();

            if (existing.exists) {
              skipped++;
              continue;
            }

            await customersCollection.doc(phone).set({
              'name': name,
              'phone': phone,
              'gstin': gstin.isEmpty ? null : gstin,
              'address': address.isEmpty ? null : address,
              'balance': lastDue,
              'totalSales': 0.0,
              'createdAt': FieldValue.serverTimestamp(),
            });

            imported++;
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Imported: $imported, Skipped: $skipped'),
              backgroundColor: _successColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.tr('error')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _scaffoldBg,
      appBar: AppBar(
        title: Text(
          context.tr('add_customer'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: _primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) {
              if (value == 'contacts') {
                _importFromContacts();
              } else if (value == 'excel') {
                _importFromExcel();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'contacts',
                child: Row(
                  children: [
                    const Icon(Icons.contacts, color: _primaryColor),
                    const SizedBox(width: 12),
                    Text(context.tr('import_from_contacts')),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'excel',
                child: Row(
                  children: [
                    const Icon(Icons.table_chart, color: _successColor),
                    const SizedBox(width: 12),
                    Text(context.tr('import_from_excel')),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Phone Number (with import buttons)
              Text(
                context.tr('phone_number'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: context.tr('enter_phone_number'),
                  prefixIcon: const Icon(Icons.phone, color: _primaryColor),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _primaryColor, width: 2),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return context.tr('phone_required');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Name (required)
              Text(
                '${context.tr('name')} *',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: context.tr('enter_name'),
                  prefixIcon: const Icon(Icons.person, color: _primaryColor),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _primaryColor, width: 2),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return context.tr('name_required');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // GSTIN
              Text(
                '${context.tr('gstin')} *',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _gstinController,
                decoration: InputDecoration(
                  hintText: context.tr('enter_gstin'),
                  prefixIcon: const Icon(Icons.receipt_long, color: _primaryColor),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _primaryColor, width: 2),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return context.tr('gstin_required');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Address
              Text(
                context.tr('address'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _addressController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: context.tr('enter_address'),
                  prefixIcon: const Icon(Icons.location_on, color: _primaryColor),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _primaryColor, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Last Due (Credit)
              Text(
                '${context.tr('last_due')} (${context.tr('credit')})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _lastDueController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: '0.00',
                  prefixIcon: const Icon(Icons.currency_rupee, color: Colors.orange),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _primaryColor, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Date of Birth
              Text(
                context.tr('date_of_birth'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _selectDOB(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _cardBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cake, color: _primaryColor),
                      const SizedBox(width: 12),
                      Text(
                        _selectedDOB != null
                            ? DateFormat('dd MMM yyyy').format(_selectedDOB!)
                            : context.tr('select_date'),
                        style: TextStyle(
                          color: _selectedDOB != null ? Colors.black87 : Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveCustomer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          context.tr('save_customer'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

