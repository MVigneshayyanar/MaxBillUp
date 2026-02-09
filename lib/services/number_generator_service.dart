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

  /// Get custom prefix from store settings
  static Future<String> _getCustomPrefix(String field) async {
    try {
      final storeDoc = await FirestoreService().getCurrentStoreDoc();
      if (storeDoc != null && storeDoc.exists) {
        final data = storeDoc.data() as Map<String, dynamic>?;
        if (data != null && data[field] != null) {
          return data[field].toString();
        }
      }
    } catch (e) {
      print('❌ Error getting custom prefix for $field: $e');
    }
    return '';
  }

  /// Get invoice prefix
  static Future<String> getInvoicePrefix() async {
    return await _getCustomPrefix('invoicePrefix');
  }

  /// Get quotation prefix
  static Future<String> getQuotationPrefix() async {
    return await _getCustomPrefix('quotationPrefix');
  }

  /// Get purchase prefix
  static Future<String> getPurchasePrefix() async {
    return await _getCustomPrefix('purchasePrefix');
  }

  /// Get expense prefix
  static Future<String> getExpensePrefix() async {
    return await _getCustomPrefix('expensePrefix');
  }

  /// Generate next invoice number by checking the last invoice in sales collection
  static Future<String> generateInvoiceNumber() async {
    try {
      final collection = await FirestoreService().getStoreCollection('sales');

      // Get custom starting number and prefix from settings
      final customStart = await _getCustomStartNumber('nextInvoiceNumber');
      final currentPrefix = await _getCustomPrefix('invoicePrefix');
      print('📝 Custom invoice start number from settings: $customStart, prefix: $currentPrefix');

      // Query for all invoices to find the highest number with matching prefix
      final query = await collection.get();

      int highestInRange = customStart - 1;
      for (var doc in query.docs) {
        final invoiceNum = doc['invoiceNumber']?.toString() ?? '';

        // Only consider invoices that match our current prefix
        if (currentPrefix.isNotEmpty) {
          if (!invoiceNum.toUpperCase().startsWith(currentPrefix.toUpperCase())) {
            continue; // Skip invoices with different prefix
          }
          // Extract numeric part after the prefix
          final numericPart = invoiceNum.substring(currentPrefix.length).replaceAll(RegExp(r'[^0-9]'), '');
          final numValue = int.tryParse(numericPart) ?? 0;
          if (numValue >= customStart && numValue > highestInRange) {
            highestInRange = numValue;
          }
        } else {
          // No prefix - only consider pure numeric invoice numbers
          final numericPart = invoiceNum.replaceAll(RegExp(r'[^0-9]'), '');
          if (numericPart == invoiceNum) { // Only if it was purely numeric
            final numValue = int.tryParse(numericPart) ?? 0;
            if (numValue >= customStart && numValue > highestInRange) {
              highestInRange = numValue;
            }
          }
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

      // Get custom starting number and prefix from settings
      final customStart = await _getCustomStartNumber('nextQuotationNumber');
      final currentPrefix = await _getCustomPrefix('quotationPrefix');
      print('📝 Custom quotation start number from settings: $customStart, prefix: $currentPrefix');

      // Query for all quotations to find the highest number with matching prefix
      final query = await collection.get();

      int highestInRange = customStart - 1;
      for (var doc in query.docs) {
        final quotationNum = doc['quotationNumber']?.toString() ?? '';

        // Only consider quotations that match our current prefix
        if (currentPrefix.isNotEmpty) {
          if (!quotationNum.toUpperCase().startsWith(currentPrefix.toUpperCase())) {
            continue;
          }
          final numericPart = quotationNum.substring(currentPrefix.length).replaceAll(RegExp(r'[^0-9]'), '');
          final numValue = int.tryParse(numericPart) ?? 0;
          if (numValue >= customStart && numValue > highestInRange) {
            highestInRange = numValue;
          }
        } else {
          final numericPart = quotationNum.replaceAll(RegExp(r'[^0-9]'), '');
          if (numericPart == quotationNum) {
            final numValue = int.tryParse(numericPart) ?? 0;
            if (numValue >= customStart && numValue > highestInRange) {
              highestInRange = numValue;
            }
          }
        }
      }

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

      // Get custom starting number and prefix from settings
      final customStart = await _getCustomStartNumber('nextExpenseNumber');
      final currentPrefix = await _getCustomPrefix('expensePrefix');

      final query = await collection.get();

      int highestInRange = customStart - 1;
      for (var doc in query.docs) {
        final expenseNum = doc['expenseNumber']?.toString() ?? '';

        if (currentPrefix.isNotEmpty) {
          if (!expenseNum.toUpperCase().startsWith(currentPrefix.toUpperCase())) {
            continue;
          }
          final numericPart = expenseNum.substring(currentPrefix.length).replaceAll(RegExp(r'[^0-9]'), '');
          final numValue = int.tryParse(numericPart) ?? 0;
          if (numValue >= customStart && numValue > highestInRange) {
            highestInRange = numValue;
          }
        } else {
          final numericPart = expenseNum.replaceAll(RegExp(r'[^0-9]'), '');
          if (numericPart == expenseNum) {
            final numValue = int.tryParse(numericPart) ?? 0;
            if (numValue >= customStart && numValue > highestInRange) {
              highestInRange = numValue;
            }
          }
        }
      }

      int nextNumber;
      if (highestInRange < customStart) {
        nextNumber = customStart;
      } else {
        nextNumber = highestInRange + 1;
      }

      print('📝 Custom start: $customStart, Highest in range: $highestInRange, Next expense: $nextNumber');
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

      // Get custom starting number and prefix from settings
      final customStart = await _getCustomStartNumber('nextPurchaseNumber');
      final currentPrefix = await _getCustomPrefix('purchasePrefix');

      final query = await collection.get();

      int highestInRange = customStart - 1;
      for (var doc in query.docs) {
        final purchaseNum = doc['purchaseNumber']?.toString() ?? '';

        if (currentPrefix.isNotEmpty) {
          if (!purchaseNum.toUpperCase().startsWith(currentPrefix.toUpperCase())) {
            continue;
          }
          final numericPart = purchaseNum.substring(currentPrefix.length).replaceAll(RegExp(r'[^0-9]'), '');
          final numValue = int.tryParse(numericPart) ?? 0;
          if (numValue >= customStart && numValue > highestInRange) {
            highestInRange = numValue;
          }
        } else {
          final numericPart = purchaseNum.replaceAll(RegExp(r'[^0-9]'), '');
          if (numericPart == purchaseNum) {
            final numValue = int.tryParse(numericPart) ?? 0;
            if (numValue >= customStart && numValue > highestInRange) {
              highestInRange = numValue;
            }
          }
        }
      }

      int nextNumber;
      if (highestInRange < customStart) {
        nextNumber = customStart;
      } else {
        nextNumber = highestInRange + 1;
      }

      print('📝 Custom start: $customStart, Highest in range: $highestInRange, Next purchase: $nextNumber');
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

