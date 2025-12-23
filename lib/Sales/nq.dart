import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:maxbillup/Sales/saleall.dart';

class NewQuotationPage extends StatelessWidget {
  final String uid;
  final String? userEmail;

  const NewQuotationPage({
    super.key,
    required this.uid,
    this.userEmail,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Quotation', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SaleAllPage(
        uid: uid,
        userEmail: userEmail,
        isQuotationMode: true, // Flag to indicate this is for quotation
      ),
    );
  }
}
