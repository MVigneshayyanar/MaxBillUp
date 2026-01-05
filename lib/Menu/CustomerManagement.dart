import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:maxbillup/Colors.dart';
import 'package:maxbillup/Menu/AddCustomer.dart';

// =============================================================================
// MAIN PAGE: CUSTOMER DETAILS
// =============================================================================

class CustomerDetailsPage extends StatefulWidget {
  final String customerId;
  final Map<String, dynamic> customerData;

  const CustomerDetailsPage({super.key, required this.customerId, required this.customerData});

  @override
  State<CustomerDetailsPage> createState() => _CustomerDetailsPageState();
}

class _CustomerDetailsPageState extends State<CustomerDetailsPage> {

  // --- POPUPS (Professional Redesign) ---

  Future<void> _confirmDelete(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: kWhite,
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Delete Customer", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: kBlack87)),
                  GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, size: 24, color: kBlack54)),
                ],
              ),
              const SizedBox(height: 24),
              const Icon(Icons.warning_amber_rounded, color: kErrorColor, size: 48),
              const SizedBox(height: 16),
              const Text("This action cannot be undone. All customer data and credit history will be removed.",
                  textAlign: TextAlign.center, style: TextStyle(color: kBlack54, fontSize: 14, height: 1.4)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    await FirestoreService().deleteDocument('customers', widget.customerId);
                    if (mounted) { Navigator.pop(context); Navigator.pop(context); }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: kErrorColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text("DELETE PERMANENTLY", style: TextStyle(color: kWhite, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, String currentName, String? currentGst) {
    final nameController = TextEditingController(text: currentName);
    final gstController = TextEditingController(text: currentGst ?? '');

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: kWhite,
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Edit Details", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: kBlack87)),
                  GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, size: 24, color: kBlack54)),
                ],
              ),
              const SizedBox(height: 24),
              _buildPopupTextField(controller: nameController, label: "Name", icon: Icons.person_outline),
              const SizedBox(height: 16),
              _buildPopupTextField(controller: gstController, label: "GST Number", icon: Icons.description_outlined),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    await FirestoreService().updateDocument('customers', widget.customerId, {
                      'name': nameController.text.trim(),
                      'gst': gstController.text.trim().isEmpty ? null : gstController.text.trim(),
                    });
                    if (mounted) Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text("UPDATE DETAILS", style: TextStyle(color: kWhite, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddCreditModal(BuildContext context, double currentBalance, double currentTotalSales) {
    final amountController = TextEditingController();
    String selectedMethod = "Cash";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(color: kWhite, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Add Sales Credit", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: kBlack87)),
                  GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, size: 24, color: kBlack54)),
                ],
              ),
              const SizedBox(height: 24),
              _buildPopupTextField(controller: amountController, label: "Amount to Add", icon: Icons.add_moderator, keyboardType: TextInputType.number),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildPaymentToggle("Cash", Icons.payments_outlined, selectedMethod, (v) => setModalState(() => selectedMethod = v)),
                  _buildPaymentToggle("Online", Icons.qr_code_scanner_rounded, selectedMethod, (v) => setModalState(() => selectedMethod = v)),
                  _buildPaymentToggle("Waive", Icons.handshake_outlined, selectedMethod, (v) => setModalState(() => selectedMethod = v)),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity, height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () async {
                    final amount = double.tryParse(amountController.text) ?? 0.0;
                    if (amount <= 0) return;
                    await _processTransaction(amount, currentBalance, currentTotalSales, selectedMethod);
                    if (mounted) Navigator.pop(context);
                  },
                  child: const Text("CONFIRM CREDIT", style: TextStyle(color: kWhite, fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildPopupTextField({required TextEditingController controller, required String label, required IconData icon, TextInputType keyboardType = TextInputType.text, int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kBlack87),
      decoration: InputDecoration(
        labelText: label, prefixIcon: Icon(icon, color: kPrimaryColor, size: 20),
        filled: true, fillColor: kGreyBg, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kGrey300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPrimaryColor, width: 1.5)),
      ),
    );
  }

  Widget _buildPaymentToggle(String label, IconData icon, String selected, Function(String) onSelect) {
    bool isActive = selected == label;
    return GestureDetector(
      onTap: () => onSelect(label),
      child: Column(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 54, height: 54,
          decoration: BoxDecoration(
            color: isActive ? kPrimaryColor : kWhite,
            shape: BoxShape.circle,
            border: Border.all(color: isActive ? kPrimaryColor : kGrey200, width: 1.5),
          ),
          child: Icon(icon, color: isActive ? kWhite : kBlack54, size: 22),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: isActive ? FontWeight.w600 : FontWeight.w500, color: isActive ? kPrimaryColor : kBlack54)),
      ]),
    );
  }

  Widget _buildRatingSection(Map<String, dynamic> data) {
    final rating = (data['rating'] ?? 0) as num;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kGreyBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kGrey200),
      ),
      child: Row(
        children: [
          const Icon(Icons.star_rounded, color: kOrange, size: 18),
          const SizedBox(width: 8),
          const Text(
            'Customer Rating:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: kBlack87,
            ),
          ),
          const SizedBox(width: 12),
          ...List.generate(5, (i) => Icon(
            i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 18,
            color: i < rating ? kOrange : kGrey300,
          )),
        ],
      ),
    );
  }

  void _showEditRatingDialog(Map<String, dynamic> customerData) {
    int selectedRating = (customerData['rating'] ?? 0) as int;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: Colors.white,
            title: const Text(
              'Rate Customer',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: kBlack87,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Customer info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kGreyBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: kPrimaryColor.withOpacity(0.1),
                        radius: 20,
                        child: Text(
                          (customerData['name'] ?? 'C')[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: kPrimaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              customerData['name'] ?? 'Customer',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: kBlack87,
                              ),
                            ),
                            Text(
                              customerData['phone'] ?? '',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: kBlack54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 5-star rating
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return GestureDetector(
                      onTap: () {
                        setDialogState(() {
                          selectedRating = index + 1;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          index < selectedRating ? Icons.star_rounded : Icons.star_outline_rounded,
                          size: 40,
                          color: index < selectedRating ? kOrange : kGrey300,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),

                // Rating text
                Text(
                  selectedRating == 0
                      ? 'No rating'
                      : selectedRating == 1
                      ? 'Poor'
                      : selectedRating == 2
                      ? 'Fair'
                      : selectedRating == 3
                      ? 'Good'
                      : selectedRating == 4
                      ? 'Very Good'
                      : 'Excellent!',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: selectedRating > 0 ? kPrimaryColor : kBlack54,
                  ),
                ),
              ],
            ),
            actions: [
              // Remove rating button
              if (customerData['rating'] != null && (customerData['rating'] as num) > 0)
                TextButton(
                  onPressed: () {
                    _updateCustomerRating(0);
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'REMOVE',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: kErrorColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

              // Cancel button
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'CANCEL',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: kBlack54,
                    letterSpacing: 0.5,
                  ),
                ),
              ),

              // Save button
              ElevatedButton(
                onPressed: selectedRating > 0
                    ? () {
                  _updateCustomerRating(selectedRating);
                  Navigator.pop(context);
                }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  disabledBackgroundColor: kGrey200,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'SAVE',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _updateCustomerRating(int rating) async {
    try {
      final customersCollection = await FirestoreService().getStoreCollection('customers');

      if (rating > 0) {
        await customersCollection.doc(widget.customerId).update({
          'rating': rating,
          'ratedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.star_rounded, color: kOrange, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Customer rated $rating star${rating > 1 ? 's' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              backgroundColor: kGoogleGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } else {
        // Remove rating
        await customersCollection.doc(widget.customerId).update({
          'rating': FieldValue.delete(),
          'ratedAt': FieldValue.delete(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Rating removed', style: TextStyle(fontWeight: FontWeight.w600)),
              backgroundColor: kOrange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating rating: $e'),
            backgroundColor: kErrorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // --- LOGIC ---

  Future<void> _processTransaction(double amount, double oldBalance, double oldTotalSales, String method) async {
    try {
      final customersCollection = await FirestoreService().getStoreCollection('customers');
      final creditsCollection = await FirestoreService().getStoreCollection('credits');
      final customerRef = customersCollection.doc(widget.customerId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        transaction.update(customerRef, {
          'balance': oldBalance + amount,
          'totalSales': oldTotalSales + amount,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      });

      await creditsCollection.add({
        'customerId': widget.customerId,
        'customerName': widget.customerData['name'],
        'amount': amount,
        'type': 'add_credit',
        'method': method,
        'timestamp': FieldValue.serverTimestamp(),
        'date': DateTime.now().toIso8601String(),
        'note': 'Sales Credit Added via Customer Management',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Credit of ${amount.toStringAsFixed(0)} added successfully'),
            backgroundColor: kGoogleGreen,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error in _processTransaction: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding credit: ${e.toString()}'),
            backgroundColor: kErrorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use initial customerData to avoid white screen, then stream for updates
    return FutureBuilder<DocumentReference>(
      future: FirestoreService().getDocumentReference('customers', widget.customerId),
      builder: (context, docRefSnapshot) {
        // Show initial data immediately while loading reference
        if (docRefSnapshot.connectionState == ConnectionState.waiting) {
          return _buildCustomerUI(context, widget.customerData);
        }

        if (!docRefSnapshot.hasData) {
          // Fallback to initial data if reference fails
          return _buildCustomerUI(context, widget.customerData);
        }

        return StreamBuilder<DocumentSnapshot>(
          stream: docRefSnapshot.data!.snapshots(),
          initialData: null,
          builder: (context, snapshot) {
            // Use stream data if available, otherwise use initial customerData
            Map<String, dynamic> data;
            if (snapshot.hasData && snapshot.data!.exists) {
              data = snapshot.data!.data() as Map<String, dynamic>;
            } else {
              data = widget.customerData;
            }
            return _buildCustomerUI(context, data);
          },
        );
      },
    );
  }

  Widget _buildCustomerUI(BuildContext context, Map<String, dynamic> data) {
    double balance = (data['balance'] ?? 0).toDouble();
    double totalSales = (data['totalSales'] ?? 0).toDouble();

    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(
        title: Text(context.tr('customerdetails'), style: const TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: kPrimaryColor, elevation: 0, centerTitle: true,
        iconTheme: const IconThemeData(color: kWhite),
      ),
      body: Column(
        children: [
          Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 8), // Reduced gap
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                CircleAvatar(
                                  backgroundColor: kOrange.withOpacity(0.1),
                                  radius: 24,
                                  child: const Icon(Icons.person, color: kOrange, size: 24),
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: Text(data['name'] ?? 'Unknown', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: kOrange))),
                                IconButton(
                                  icon: const Icon(Icons.edit_rounded, color: kPrimaryColor, size: 24),
                                  onPressed: () => _navigateToEditCustomer(context, data)
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Customer Rating Display
                            _buildRatingSection(data),
                            const Divider(height: 32, color: kGrey100),
                            _buildInfoRow(Icons.phone_android_rounded, "Phone", data['phone'] ?? '--'),
                            const SizedBox(height: 10),
                            _buildInfoRow(Icons.description_outlined, "GST No", data['gst'] ?? data['gstin'] ?? 'Not Provided'),
                            const SizedBox(height: 10),
                            _buildInfoRow(Icons.location_on_rounded, "Address", data['address'] ?? 'Not Provided'),
                            const SizedBox(height: 10),
                            _buildInfoRow(Icons.percent_rounded, "Default Discount", "${(data['defaultDiscount'] ?? 0).toString()}%"),
                            const SizedBox(height: 10),
                            _buildInfoRow(Icons.cake_rounded, "Date of Birth", _formatDOB(data['dob'])),
                            const SizedBox(height: 24),
                            Row(children: [
                              _buildStatBox("Total Sales", totalSales, kGoogleGreen),
                              const SizedBox(width: 12),
                              _buildStatBox("Credit due", balance, kErrorColor),
                            ])
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildMenuItem(context, "View Bills", Icons.receipt_long_rounded),
                      const SizedBox(height: 10),
                      _buildMenuItem(context, "Payment History", Icons.history_rounded),
                      const SizedBox(height: 10),
                      _buildMenuItem(context, "Ledger Account", Icons.account_balance_rounded),
                      const SizedBox(height: 80), // Space for FAB
                    ],
                  ),
                ),
              ),
              _buildBottomActionArea(balance, totalSales),
            ],
          ),
        );
  }

  void _navigateToEditCustomer(BuildContext context, Map<String, dynamic> data) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => AddCustomerPage(
          uid: '',
          isEditMode: true,
          customerId: widget.customerId,
          customerData: data,
        ),
      ),
    ).then((result) {
      if (result == true) {
        setState(() {}); // Refresh
      }
    });
  }

  String _formatDOB(dynamic dob) {
    if (dob == null) return 'Not Provided';
    if (dob is Timestamp) {
      return DateFormat('dd-MM-yyyy').format(dob.toDate());
    }
    return 'Not Provided';
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(children: [
      Icon(icon, size: 16, color: kBlack54),
      const SizedBox(width: 10),
      Text("$label: ", style: const TextStyle(color: kBlack54, fontSize: 12, fontWeight: FontWeight.w500)),
      Text(value, style: const TextStyle(color: kBlack87, fontSize: 13, fontWeight: FontWeight.w700)),
    ]);
  }

  Widget _buildStatBox(String lbl, double amt, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.15))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(lbl.toUpperCase(), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
            const SizedBox(height: 6),
            Text("${amt.toStringAsFixed(2)}", style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, String title, IconData icon) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)),
      child: ListTile(
        leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: kPrimaryColor.withOpacity(0.08), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: kPrimaryColor, size: 20)),
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kBlack87)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: kGrey400),
        onTap: () {
          if (title.contains("Bills")) Navigator.push(context, CupertinoPageRoute(builder: (_) => CustomerBillsPage(phone: widget.customerId)));
          else if (title.contains("Payment")) Navigator.push(context, CupertinoPageRoute(builder: (_) => CustomerCreditsPage(customerId: widget.customerId)));
          else Navigator.push(context, CupertinoPageRoute(builder: (_) => CustomerLedgerPage(customerId: widget.customerId, customerName: widget.customerData['name'])));
        },
      ),
    );
  }

  Widget _buildBottomActionArea(double balance, double totalSales) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(color: kWhite, border: const Border(top: BorderSide(color: kGrey200))),
        child: Row(children: [
          Expanded(child: ElevatedButton(
            onPressed: () => _showAddCreditModal(context, balance, totalSales),
            style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
            child: const Text("ADD CREDIT", style: TextStyle(color: kWhite, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          )),
          const SizedBox(width: 12),
          Expanded(child: OutlinedButton(
            onPressed: () => Navigator.push(context, CupertinoPageRoute(builder: (context) => _ReceiveCreditPage(customerId: widget.customerId, customerData: widget.customerData, currentBalance: balance))),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: kPrimaryColor, width: 1.5), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text("RECEIVE PAYMENT", style: TextStyle(color: kPrimaryColor, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          )),
        ]),
      ),
    );
  }
}

// =============================================================================
// SUB-PAGE: RECEIVE CREDIT FORM
// =============================================================================

class _ReceiveCreditPage extends StatefulWidget {
  final String customerId; final Map<String, dynamic> customerData; final double currentBalance;
  const _ReceiveCreditPage({required this.customerId, required this.customerData, required this.currentBalance});
  @override State<_ReceiveCreditPage> createState() => _ReceiveCreditPageState();
}

class _ReceiveCreditPageState extends State<_ReceiveCreditPage> {
  final TextEditingController _amountController = TextEditingController();
  double _amt = 0.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(title: const Text("Receive Payment", style: TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 18)), backgroundColor: kPrimaryColor, centerTitle: true, elevation: 0, iconTheme: const IconThemeData(color: kWhite)),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.customerData['name'] ?? 'Customer', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: kOrange)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text("Credit due", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kBlack54)),
              Text("${widget.currentBalance.toStringAsFixed(2)}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: kErrorColor)),
            ]),
          ),
          const SizedBox(height: 32),
          const Text("Enter Amount Received", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: kBlack54, letterSpacing: 0.5)),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController, keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (v) => setState(() => _amt = double.tryParse(v) ?? 0.0),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: kPrimaryColor),
            decoration: InputDecoration(prefixText: "", filled: true, fillColor: kWhite, enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kGrey300)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPrimaryColor, width: 2))),
          ),
          const Spacer(),
          SizedBox(width: double.infinity, height: 60, child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              if (_amt <= 0) return;
              final cCol = await FirestoreService().getStoreCollection('customers');
              final crCol = await FirestoreService().getStoreCollection('credits');
              await cCol.doc(widget.customerId).update({'balance': widget.currentBalance - _amt});
              await crCol.add({'customerId': widget.customerId, 'customerName': widget.customerData['name'], 'amount': _amt, 'type': 'payment_received', 'method': 'Cash', 'timestamp': FieldValue.serverTimestamp()});
              if (mounted) Navigator.pop(context);
            },
            child: const Text("Save payment", style: TextStyle(color: kWhite, fontSize: 16, fontWeight: FontWeight.w900)),
          )),
        ]),
      ),
    );
  }
}

// =============================================================================
// SUB-PAGE: RECONCILED LEDGER
// =============================================================================

class LedgerEntry {
  final DateTime date; final String type; final String desc; final double debit; final double credit; double balance;
  LedgerEntry({required this.date, required this.type, required this.desc, required this.debit, required this.credit, this.balance = 0});
}

class CustomerLedgerPage extends StatefulWidget {
  final String customerId; final String customerName;
  const CustomerLedgerPage({super.key, required this.customerId, required this.customerName});
  @override State<CustomerLedgerPage> createState() => _CustomerLedgerPageState();
}

class _CustomerLedgerPageState extends State<CustomerLedgerPage> {
  List<LedgerEntry> _entries = []; bool _loading = true;

  @override
  void initState() { super.initState(); _loadLedger(); }

  Future<void> _loadLedger() async {
    final sales = await FirestoreService().getStoreCollection('sales').then((c) => c.where('customerPhone', isEqualTo: widget.customerId).get());
    final credits = await FirestoreService().getStoreCollection('credits').then((c) => c.where('customerId', isEqualTo: widget.customerId).get());
    List<LedgerEntry> entries = [];
    for (var doc in sales.docs) {
      final d = doc.data() as Map<String, dynamic>;
      final date = (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
      final total = (d['total'] ?? 0.0).toDouble();
      final mode = d['paymentMode'] ?? 'Unknown';
      entries.add(LedgerEntry(date: date, type: 'INV', desc: "Invoice #${d['invoiceNumber']}", debit: total, credit: 0));
      if (mode == 'Cash' || mode == 'Online') {
        entries.add(LedgerEntry(date: date, type: 'PAY', desc: "Immediate Payment", debit: 0, credit: total));
      } else if (mode == 'Split') {
        final paid = (d['cashReceived'] ?? 0.0).toDouble();
        if (paid > 0) entries.add(LedgerEntry(date: date, type: 'PAY', desc: "Partial Payment", debit: 0, credit: paid));
      }
    }
    for (var doc in credits.docs) {
      final d = doc.data() as Map<String, dynamic>;
      final date = (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
      final amt = (d['amount'] ?? 0.0).toDouble();
      final type = d['type'] ?? '';
      final method = d['method'] ?? '';
      if (type == 'payment_received') {
        entries.add(LedgerEntry(date: date, type: 'CR', desc: "Payment (${method.isNotEmpty ? method : 'Cash'})", debit: 0, credit: amt));
      } else if (type == 'add_credit') {
        entries.add(LedgerEntry(date: date, type: 'DR', desc: "Sales Credit Added (${method.isNotEmpty ? method : 'Manual'})", debit: amt, credit: 0));
      }
    }
    entries.sort((a, b) => a.date.compareTo(b.date));
    double running = 0;
    for (var e in entries) {
      running += (e.debit - e.credit);
      e.balance = running;
    }
    if (mounted) setState(() { _entries = entries.reversed.toList(); _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kWhite,
      appBar: AppBar(title: Text("${widget.customerName} Ledger", style: const TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 16)), backgroundColor: kPrimaryColor, centerTitle: true, elevation: 0, iconTheme: const IconThemeData(color: kWhite)),
      body: _loading ? const Center(child: CircularProgressIndicator(color: kPrimaryColor)) : Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          color: kPrimaryColor.withOpacity(0.05),
          child: const Row(children: [
            Expanded(flex: 2, child: Text("DATE", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 0.5))),
            Expanded(flex: 3, child: Text("PARTICULARS", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 0.5))),
            Expanded(flex: 2, child: Text("DEBIT", textAlign: TextAlign.right, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kErrorColor))),
            Expanded(flex: 2, child: Text("CREDIT", textAlign: TextAlign.right, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kGoogleGreen))),
            Expanded(flex: 2, child: Text("BALANCE", textAlign: TextAlign.right, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kBlack54))),
          ]),
        ),
        Expanded(child: ListView.separated(
          itemCount: _entries.length,
          separatorBuilder: (_, __) => const Divider(height: 1, color: kGrey100),
          itemBuilder: (c, i) {
            final e = _entries[i];
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              child: Row(children: [
                Expanded(flex: 2, child: Text(DateFormat('dd/MM/yy').format(e.date), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kBlack87))),
                Expanded(flex: 3, child: Text(e.desc, style: const TextStyle(fontSize: 11, color: kBlack54, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                Expanded(flex: 2, child: Text(e.debit > 0 ? e.debit.toStringAsFixed(0) : "-", textAlign: TextAlign.right, style: const TextStyle(color: kErrorColor, fontSize: 11, fontWeight: FontWeight.w900))),
                Expanded(flex: 2, child: Text(e.credit > 0 ? e.credit.toStringAsFixed(0) : "-", textAlign: TextAlign.right, style: const TextStyle(color: kGoogleGreen, fontSize: 11, fontWeight: FontWeight.w900))),
                Expanded(flex: 2, child: Text(e.balance.toStringAsFixed(0), textAlign: TextAlign.right, style: TextStyle(color: e.balance > 0 ? kErrorColor : kGoogleGreen, fontSize: 12, fontWeight: FontWeight.w900))),
              ]),
            );
          },
        )),
        _buildClosingBar(),
      ]),
    );
  }

  Widget _buildClosingBar() {
    final bal = _entries.isNotEmpty ? _entries.first.balance : 0.0;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        decoration: BoxDecoration(color: kWhite, border: const Border(top: BorderSide(color: kGrey200))),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text("Current Closing Balance:", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: kBlack54)),
          Text("${bal.toStringAsFixed(2)}", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: bal > 0 ? kErrorColor : kGoogleGreen)),
        ]),
      ),
    );
  }
}

// =============================================================================
// SUB-PAGE: LIST VIEWS
// =============================================================================

class CustomerBillsPage extends StatelessWidget {
  final String phone; const CustomerBillsPage({super.key, required this.phone});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(title: const Text("Billing History", style: TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 16)), backgroundColor: kPrimaryColor, elevation: 0, centerTitle: true, iconTheme: const IconThemeData(color: kWhite)),
      body: FutureBuilder<QuerySnapshot>(
        future: FirestoreService().getStoreCollection('sales').then((c) => c.where('customerPhone', isEqualTo: phone).get()),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text("No bills found", style: TextStyle(color: kBlack54,fontWeight: FontWeight.bold)));
          return ListView.separated(
            padding: const EdgeInsets.all(16), itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final date = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
              return Container(
                decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)),
                child: ListTile(
                  title: Text("Invoice #${data['invoiceNumber']}", style: const TextStyle(fontWeight: FontWeight.w900, color: kPrimaryColor, fontSize: 14)),
                  subtitle: Text(DateFormat('dd-MM-yyyy').format(date), style: const TextStyle(fontSize: 11, color: kBlack54, fontWeight: FontWeight.w600)),
                  trailing: Text("${data['total']}", style: const TextStyle(fontWeight: FontWeight.w900, color: kBlack87, fontSize: 15)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class CustomerCreditsPage extends StatelessWidget {
  final String customerId; const CustomerCreditsPage({super.key, required this.customerId});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(title: const Text("Payment Log", style: TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 16)), backgroundColor: kPrimaryColor, elevation: 0, centerTitle: true, iconTheme: const IconThemeData(color: kWhite)),
      body: FutureBuilder<QuerySnapshot>(
        future: _fetchCredits(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.history_rounded, size: 64, color: kGrey300), const SizedBox(height: 16), const Text("No transaction history", style: TextStyle(color: kBlack54,fontWeight: FontWeight.bold))]));
          final docs = snapshot.data!.docs;
          return ListView.separated(
            padding: const EdgeInsets.all(16), itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              bool isPayment = data['type'] == 'payment_received';
              final date = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
              return Container(
                decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)),
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: (isPayment ? kGoogleGreen : kErrorColor).withOpacity(0.1), radius: 18, child: Icon(isPayment ? Icons.arrow_downward : Icons.arrow_upward, color: isPayment ? kGoogleGreen : kErrorColor, size: 16)),
                  title: Text(isPayment ? "Payment Received" : "Credit Added", style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: kBlack87)),
                  subtitle: Text("${DateFormat('dd-MM-yy • HH:mm').format(date)} • ${data['method'] ?? 'Manual'}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: kBlack54)),
                  trailing: Text("${data['amount']}", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: isPayment ? kGoogleGreen : kErrorColor)),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<QuerySnapshot> _fetchCredits() async {
    try {
      final collection = await FirestoreService().getStoreCollection('credits');
      return await collection.where('customerId', isEqualTo: customerId).orderBy('timestamp', descending: true).get();
    } catch (e) {
      final collection = await FirestoreService().getStoreCollection('credits');
      return await collection.where('customerId', isEqualTo: customerId).get();
    }
  }
}

