import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'dart:io';
import 'package:maxbillup/Colors.dart';

// --- UI CONSTANTS ---
const Color _primaryColor = kPrimaryColor;
const Color _successColor = kGoogleGreen;
const Color _cardBorder = kGrey200;
const Color _scaffoldBg = kWhite;

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

  // ==========================================
  // LOGIC METHODS (PRESERVED BIT-BY-BIT)
  // ==========================================

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
            const SnackBar(
              content: Text('Already customer is there'),
              backgroundColor: kOrange,
              behavior: SnackBarBehavior.floating,
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
        'totalSales': lastDue,
        'dob': _selectedDOB != null ? Timestamp.fromDate(_selectedDOB!) : null,
        'createdAt': FieldValue.serverTimestamp(),
      });

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
          const SnackBar(
            content: Text('Customer added successfully'),
            backgroundColor: _successColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: kErrorColor,
            behavior: SnackBarBehavior.floating,
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
            const SnackBar(
              content: Text('Permission denied'),
              backgroundColor: kOrange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      final contacts = await FlutterContacts.getContacts(withProperties: true, withPhoto: false);
      if (mounted) _showContactsDialog(contacts);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: kErrorColor, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  void _showContactsDialog(List<Contact> contacts) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Select Contact', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.separated(
            itemCount: contacts.length,
            separatorBuilder: (c, i) => const Divider(height: 1, color: kGrey100),
            itemBuilder: (context, index) {
              final contact = contacts[index];
              final phone = contact.phones.isNotEmpty ? contact.phones.first.number : '';
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: _primaryColor.withOpacity(0.1),
                  child: Text(
                    contact.displayName.isNotEmpty ? contact.displayName[0].toUpperCase() : '?',
                    style: const TextStyle(color: _primaryColor, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(contact.displayName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(phone, style: const TextStyle(fontSize: 12, color: kBlack54)),
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Future<void> _importFromExcel() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx', 'xls']);
      if (result != null) {
        File file = File(result.files.single.path!);
        var bytes = file.readAsBytesSync();
        var excel = excel_pkg.Excel.decodeBytes(bytes);
        int imported = 0; int skipped = 0;
        for (var table in excel.tables.keys) {
          var sheet = excel.tables[table]!;
          for (var rowIndex = 1; rowIndex < sheet.maxRows; rowIndex++) {
            var row = sheet.rows[rowIndex];
            if (row.length < 2) continue;
            final name = row[0]?.value?.toString().trim() ?? '';
            final phone = row[1]?.value?.toString().trim() ?? '';
            final gstin = row.length > 2 ? row[2]?.value?.toString().trim() ?? '' : '';
            final address = row.length > 3 ? row[3]?.value?.toString().trim() ?? '' : '';
            final lastDue = row.length > 4 ? double.tryParse(row[4]?.value?.toString() ?? '0') ?? 0.0 : 0.0;
            if (name.isEmpty || phone.isEmpty) { skipped++; continue; }
            final customersCollection = await FirestoreService().getStoreCollection('customers');
            final existing = await customersCollection.doc(phone).get();
            if (existing.exists) { skipped++; continue; }
            await customersCollection.doc(phone).set({
              'name': name, 'phone': phone, 'gstin': gstin.isEmpty ? null : gstin, 'address': address.isEmpty ? null : address,
              'balance': lastDue, 'totalSales': 0.0, 'createdAt': FieldValue.serverTimestamp(),
            });
            imported++;
          }
        }
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Imported: $imported, Skipped: $skipped'), backgroundColor: _successColor, behavior: SnackBarBehavior.floating));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: kErrorColor, behavior: SnackBarBehavior.floating));
    }
  }

  // ==========================================
  // UI BUILD METHODS
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _scaffoldBg,
      appBar: AppBar(
        title: const Text(
          'Add Customer',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: _primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: kGrey200),
            ),
            onSelected: (value) {
              if (value == 'contacts') {
                _importFromContacts();
              } else if (value == 'excel') {
                _importFromExcel();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'contacts',
                child: Row(
                  children: [
                    Icon(Icons.contacts_rounded, color: _primaryColor, size: 20),
                    SizedBox(width: 12),
                    Text('Import from Contacts', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'excel',
                child: Row(
                  children: [
                    Icon(Icons.table_chart_rounded, color: _successColor, size: 20),
                    SizedBox(width: 12),
                    Text('Import from Excel', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSectionHeader("Basic Details"),
                  const SizedBox(height: 12),
                  _buildModernTextField(
                    controller: _phoneController,
                    label: 'Phone Number',
                    hint: 'Enter phone number',
                    icon: Icons.phone_android_rounded,
                    keyboardType: TextInputType.phone,
                    isRequired: true,
                  ),
                  const SizedBox(height: 16),
                  _buildModernTextField(
                    controller: _nameController,
                    label: 'Name',
                    hint: 'Enter name',
                    icon: Icons.person_rounded,
                    isRequired: true,
                  ),
                  const SizedBox(height: 24),

                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: EdgeInsets.zero,
                      title: _buildSectionHeader("Advanced Details"),
                      children: [
                        const SizedBox(height: 16),
                        _buildModernTextField(
                          controller: _gstinController,
                          label: 'GSTIN',
                          hint: 'Enter GSTIN',
                          icon: Icons.receipt_long_rounded,
                        ),
                        const SizedBox(height: 16),
                        _buildModernTextField(
                          controller: _addressController,
                          label: 'Address',
                          hint: 'Enter address',
                          icon: Icons.location_on_rounded,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),
                        _buildModernTextField(
                          controller: _lastDueController,
                          label: 'Last Due',
                          hint: '0.00',
                          icon: Icons.currency_rupee_rounded,
                          iconColor: kOrange,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                        const SizedBox(height: 16),
                        _buildSectionHeader('Date of Birth'),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => _selectDOB(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: kGreyBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: _selectedDOB != null ? _primaryColor : _cardBorder,
                                  width: _selectedDOB != null ? 1.5 : 1.0
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.cake_rounded, color: _primaryColor, size: 20),
                                const SizedBox(width: 12),
                                Text(
                                  _selectedDOB != null
                                      ? DateFormat('dd MMM yyyy').format(_selectedDOB!)
                                      : 'Select Date',
                                  style: TextStyle(
                                    color: _selectedDOB != null ? kBlack87 : kBlack54,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
            _buildBottomSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: kBlack54,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isRequired = false,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    Color? iconColor,
  }) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, child) {
        final bool isFilled = value.text.isNotEmpty;
        return TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kBlack87),
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            hintStyle: const TextStyle(color: kBlack54, fontSize: 14, fontWeight: FontWeight.normal),
            prefixIcon: Icon(icon, color: iconColor ?? _primaryColor, size: 20),
            filled: true,
            fillColor: kGreyBg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: isFilled ? _primaryColor : _cardBorder,
                  width: isFilled ? 1.5 : 1.0
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _primaryColor, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kErrorColor),
            ),
          ),
          validator: isRequired ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null : null,
        );
      },
    );
  }

  Widget _buildBottomSaveButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: kWhite,
        border: Border(top: BorderSide(color: kGrey200)),
      ),
      child: SizedBox(
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
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
          )
              : const Text(
            'SAVE CUSTOMER',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}