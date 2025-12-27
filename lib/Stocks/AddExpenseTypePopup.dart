import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maxbillup/utils/permission_helper.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:maxbillup/Colors.dart';

class AddExpenseTypePopup extends StatefulWidget {
  final String uid;
  final String? userEmail;

  const AddExpenseTypePopup({
    super.key,
    required this.uid,
    this.userEmail,
  });

  @override
  State<AddExpenseTypePopup> createState() => _AddExpenseTypePopupState();
}

class _AddExpenseTypePopupState extends State<AddExpenseTypePopup> {
  final TextEditingController _typeController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _typeController.dispose();
    super.dispose();
  }

  Future<void> _saveType() async {
    final typeName = _typeController.text.trim();
    if (typeName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('enter_expense_type'))),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final typesCollection = await FirestoreService().getStoreCollection('expenseCategories');
      final existingType = await typesCollection.where('name', isEqualTo: typeName).get();
      if (existingType.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('expense_type_exists'))),
        );
        setState(() => _isLoading = false);
        return;
      }
      await FirestoreService().addDocument('expenseCategories', {
        'name': typeName,
        'createdAt': FieldValue.serverTimestamp(),
        'ownerUid': widget.uid,
        'ownerEmail': widget.userEmail,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('expense_type_added_success'))),
      );
      Navigator.pop(context, typeName);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('error_adding_expense_type'))),
      );
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Add Expense Type',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, size: 24, color: Colors.black54),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Input Field
            _buildExpenseTypeInput(),

            const SizedBox(height: 24),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveType,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : const Text(
                  'Add',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Custom Input Field ---
  Widget _buildExpenseTypeInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _typeController,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
          decoration: InputDecoration(
            labelText: 'Expense Type Name',
            floatingLabelBehavior: FloatingLabelBehavior.auto,
            labelStyle: const TextStyle(color: Colors.black54, fontSize: 15),
            floatingLabelStyle: const TextStyle(color: kPrimaryColor, fontSize: 13, fontWeight: FontWeight.w600),
            filled: true,
            fillColor: kGreyBg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kGrey300, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kPrimaryColor, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "e.g. Salary, Rent, Electricity, Travel, etc.",
          style: TextStyle(fontSize: 13, color: Colors.grey[500]),
        ),
      ],
    );
  }
}
