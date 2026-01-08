import '../utils/firestore_service.dart';

/// Service to generate sequential numbers for invoices, credit notes, and quotations
class NumberGeneratorService {
  static const int _defaultStartNumber = 100001;

  /// Get custom starting number from store settings
  static Future<int> _getCustomStartNumber(String field) async {
    try {
      final storeDoc = await FirestoreService().getCurrentStoreDoc();
      if (storeDoc != null && storeDoc.exists) {
        final data = storeDoc.data() as Map<String, dynamic>?;
        print('📝 _getCustomStartNumber: field=$field, data[$field]=${data?[field]}');
        if (data != null && data[field] != null) {
          final value = int.tryParse(data[field].toString()) ?? _defaultStartNumber;
          print('📝 _getCustomStartNumber: Returning $value for $field');
          return value;
        }
      }
      print('📝 _getCustomStartNumber: No custom value found for $field, using default $_defaultStartNumber');
    } catch (e) {
      print('❌ Error getting custom start number for $field: $e');
    }
    return _defaultStartNumber;
  }

  /// Generate next invoice number by checking the last invoice in sales collection
  static Future<String> generateInvoiceNumber() async {
    try {
      final collection = await FirestoreService().getStoreCollection('sales');

      // Get custom starting number from settings (this is the "next" number to use)
      final customStart = await _getCustomStartNumber('nextInvoiceNumber');
      print('📝 Custom invoice start number from settings: $customStart');

      // Define a reasonable range - look for invoices from customStart to customStart + 10,000,000
      // This prevents old invoice numbers (from a different sequence) from affecting the count
      final rangeEnd = customStart + 10000000;

      // Query for all invoices to find if any exist in the current sequence range
      final query = await collection.get();

      int highestInRange = customStart - 1;
      for (var doc in query.docs) {
        final invoiceNum = doc['invoiceNumber']?.toString() ?? '';
        final numValue = int.tryParse(invoiceNum) ?? 0;
        // Only consider numbers within the current sequence range
        if (numValue >= customStart && numValue < rangeEnd && numValue > highestInRange) {
          highestInRange = numValue;
        }
      }

      // Next number is either customStart (if no invoices exist in range) or highest + 1
      int nextNumber;
      if (highestInRange < customStart) {
        nextNumber = customStart;
      } else {
        nextNumber = highestInRange + 1;
      }

      print('📝 Custom start: $customStart, Highest in range: $highestInRange, Next invoice: $nextNumber');
      return nextNumber.toString();
    } catch (e) {
      print('❌ Error generating invoice number: $e');
      // Fallback to default start number if query fails
      return _defaultStartNumber.toString();
    }
  }

  /// Generate next credit note number by checking the last credit note
  static Future<String> generateCreditNoteNumber() async {
    try {
      final collection = await FirestoreService().getStoreCollection('creditNotes');

      // Query for the highest credit note number (numeric only)
      final query = await collection
          .orderBy('creditNoteNumber', descending: true)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        print('📝 No previous credit notes found, starting from CN$_defaultStartNumber');
        return 'CN$_defaultStartNumber';
      }

      final lastCreditNoteNumber = query.docs.first['creditNoteNumber']?.toString() ?? '';

      // Extract numeric part from credit note number (e.g., "CN100001" -> 100001)
      final numericPart = lastCreditNoteNumber.replaceAll(RegExp(r'[^0-9]'), '');
      final lastNumber = int.tryParse(numericPart) ?? (_defaultStartNumber - 1);
      final nextNumber = lastNumber + 1;

      print('📝 Last credit note: $lastCreditNoteNumber, Next credit note: CN$nextNumber');
      return 'CN$nextNumber';
    } catch (e) {
      print('❌ Error generating credit note number: $e');
      return 'CN$_defaultStartNumber';
    }
  }

  /// Generate next quotation number by checking the last quotation
  static Future<String> generateQuotationNumber() async {
    try {
      final collection = await FirestoreService().getStoreCollection('quotations');

      // Get custom starting number from settings (this is the "next" number to use)
      final customStart = await _getCustomStartNumber('nextQuotationNumber');
      print('📝 Custom quotation start number from settings: $customStart');

      // Define a reasonable range - look for quotations from customStart to customStart + 10,000,000
      final rangeEnd = customStart + 10000000;

      // Query for all quotations to find if any exist in the current sequence range
      final query = await collection.get();

      int highestInRange = customStart - 1;
      for (var doc in query.docs) {
        final quotationNum = doc['quotationNumber']?.toString() ?? '';
        final numValue = int.tryParse(quotationNum) ?? 0;
        // Only consider numbers within the current sequence range
        if (numValue >= customStart && numValue < rangeEnd && numValue > highestInRange) {
          highestInRange = numValue;
        }
      }

      // Next number is either customStart or highest + 1
      int nextNumber;
      if (highestInRange < customStart) {
        nextNumber = customStart;
      } else {
        nextNumber = highestInRange + 1;
      }

      print('📝 Custom start: $customStart, Highest in range: $highestInRange, Next quotation: $nextNumber');
      return nextNumber.toString();
    } catch (e) {
      print('❌ Error generating quotation number: $e');
      return _defaultStartNumber.toString();
    }
  }

  /// Generate next expense number by checking the backend
  static Future<String> generateExpenseNumber() async {
    try {
      final collection = await FirestoreService().getStoreCollection('expenses');

      // Query for all expenses to find the highest number
      final query = await collection.get();

      int highestNumber = _defaultStartNumber - 1;
      for (var doc in query.docs) {
        final expenseNum = doc['expenseNumber']?.toString() ?? '';
        final numericPart = expenseNum.replaceAll(RegExp(r'[^0-9]'), '');
        final numValue = int.tryParse(numericPart) ?? 0;
        if (numValue > highestNumber) {
          highestNumber = numValue;
        }
      }

      // Next number is highest + 1 (minimum is _defaultStartNumber which is 100001)
      final nextNumber = highestNumber + 1;

      print('📝 Highest expense number: $highestNumber, Next expense: $nextNumber');
      return nextNumber.toString();
    } catch (e) {
      print('❌ Error generating expense number: $e');
      return _defaultStartNumber.toString();
    }
  }

  /// Generate next purchase number by checking the backend
  static Future<String> generatePurchaseNumber() async {
    try {
      final collection = await FirestoreService().getStoreCollection('stockPurchases');

      // Query for all purchases to find the highest number
      final query = await collection.get();

      int highestNumber = _defaultStartNumber - 1;
      for (var doc in query.docs) {
        final purchaseNum = doc['purchaseNumber']?.toString() ?? '';
        final numericPart = purchaseNum.replaceAll(RegExp(r'[^0-9]'), '');
        final numValue = int.tryParse(numericPart) ?? 0;
        if (numValue > highestNumber) {
          highestNumber = numValue;
        }
      }

      // Next number is highest + 1 (minimum is _defaultStartNumber which is 100001)
      final nextNumber = highestNumber + 1;

      print('📝 Highest purchase number: $highestNumber, Next purchase: $nextNumber');
      return nextNumber.toString();
    } catch (e) {
      print('❌ Error generating purchase number: $e');
      return _defaultStartNumber.toString();
    }
  }

  /// Generate next expense credit note number
  static Future<String> generateExpenseCreditNoteNumber() async {
    try {
      final collection = await FirestoreService().getStoreCollection('creditNotes');

      // Query for expense credit notes (starting with ECN)
      final query = await collection
          .where('creditNoteNumber', isGreaterThanOrEqualTo: 'ECN')
          .where('creditNoteNumber', isLessThan: 'ECO')
          .orderBy('creditNoteNumber', descending: true)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        print('📝 No previous expense credit notes found, starting from ECN$_defaultStartNumber');
        return 'ECN$_defaultStartNumber';
      }

      final lastNumber = query.docs.first['creditNoteNumber']?.toString() ?? '';
      final numericPart = lastNumber.replaceAll(RegExp(r'[^0-9]'), '');
      final lastNum = int.tryParse(numericPart) ?? (_defaultStartNumber - 1);
      final nextNumber = lastNum + 1;

      print('📝 Last expense credit note: $lastNumber, Next: ECN$nextNumber');
      return 'ECN$nextNumber';
    } catch (e) {
      print('❌ Error generating expense credit note number: $e');
      return 'ECN$_defaultStartNumber';
    }
  }

  /// Generate next purchase credit note number
  static Future<String> generatePurchaseCreditNoteNumber() async {
    try {
      final collection = await FirestoreService().getStoreCollection('creditNotes');

      // Query for purchase credit notes (starting with PCN)
      final query = await collection
          .where('creditNoteNumber', isGreaterThanOrEqualTo: 'PCN')
          .where('creditNoteNumber', isLessThan: 'PCO')
          .orderBy('creditNoteNumber', descending: true)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        print('📝 No previous purchase credit notes found, starting from PCN$_defaultStartNumber');
        return 'PCN$_defaultStartNumber';
      }

      final lastNumber = query.docs.first['creditNoteNumber']?.toString() ?? '';
      final numericPart = lastNumber.replaceAll(RegExp(r'[^0-9]'), '');
      final lastNum = int.tryParse(numericPart) ?? (_defaultStartNumber - 1);
      final nextNumber = lastNum + 1;

      print('📝 Last purchase credit note: $lastNumber, Next: PCN$nextNumber');
      return 'PCN$nextNumber';
    } catch (e) {
      print('❌ Error generating purchase credit note number: $e');
      return 'PCN$_defaultStartNumber';
    }
  }
}

