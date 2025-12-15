import '../utils/firestore_service.dart';

/// Service to generate sequential numbers for invoices, credit notes, and quotations
class NumberGeneratorService {
  static const int _startNumber = 100001;

  /// Generate next invoice number by checking the last invoice in sales collection
  static Future<String> generateInvoiceNumber() async {
    try {
      final collection = await FirestoreService().getStoreCollection('sales');

      // Query for the highest invoice number
      final query = await collection
          .orderBy('invoiceNumber', descending: true)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        print('📝 No previous invoices found, starting from $_startNumber');
        return _startNumber.toString();
      }

      final lastInvoiceNumber = query.docs.first['invoiceNumber']?.toString() ?? '';
      final lastNumber = int.tryParse(lastInvoiceNumber) ?? (_startNumber - 1);
      final nextNumber = lastNumber + 1;

      print('📝 Last invoice: $lastInvoiceNumber, Next invoice: $nextNumber');
      return nextNumber.toString();
    } catch (e) {
      print('❌ Error generating invoice number: $e');
      // Fallback to timestamp-based number if query fails
      return _startNumber.toString();
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
        print('📝 No previous credit notes found, starting from CN$_startNumber');
        return 'CN$_startNumber';
      }

      final lastCreditNoteNumber = query.docs.first['creditNoteNumber']?.toString() ?? '';

      // Extract numeric part from credit note number (e.g., "CN100001" -> 100001)
      final numericPart = lastCreditNoteNumber.replaceAll(RegExp(r'[^0-9]'), '');
      final lastNumber = int.tryParse(numericPart) ?? (_startNumber - 1);
      final nextNumber = lastNumber + 1;

      print('📝 Last credit note: $lastCreditNoteNumber, Next credit note: CN$nextNumber');
      return 'CN$nextNumber';
    } catch (e) {
      print('❌ Error generating credit note number: $e');
      return 'CN$_startNumber';
    }
  }

  /// Generate next quotation number by checking the last quotation
  static Future<String> generateQuotationNumber() async {
    try {
      final collection = await FirestoreService().getStoreCollection('quotations');

      // Query for the highest quotation number
      final query = await collection
          .orderBy('quotationNumber', descending: true)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        print('📝 No previous quotations found, starting from $_startNumber');
        return _startNumber.toString();
      }

      final lastQuotationNumber = query.docs.first['quotationNumber']?.toString() ?? '';
      final lastNumber = int.tryParse(lastQuotationNumber) ?? (_startNumber - 1);
      final nextNumber = lastNumber + 1;

      print('📝 Last quotation: $lastQuotationNumber, Next quotation: $nextNumber');
      return nextNumber.toString();
    } catch (e) {
      print('❌ Error generating quotation number: $e');
      return _startNumber.toString();
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
        print('📝 No previous expense credit notes found, starting from ECN$_startNumber');
        return 'ECN$_startNumber';
      }

      final lastNumber = query.docs.first['creditNoteNumber']?.toString() ?? '';
      final numericPart = lastNumber.replaceAll(RegExp(r'[^0-9]'), '');
      final lastNum = int.tryParse(numericPart) ?? (_startNumber - 1);
      final nextNumber = lastNum + 1;

      print('📝 Last expense credit note: $lastNumber, Next: ECN$nextNumber');
      return 'ECN$nextNumber';
    } catch (e) {
      print('❌ Error generating expense credit note number: $e');
      return 'ECN$_startNumber';
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
        print('📝 No previous purchase credit notes found, starting from PCN$_startNumber');
        return 'PCN$_startNumber';
      }

      final lastNumber = query.docs.first['creditNoteNumber']?.toString() ?? '';
      final numericPart = lastNumber.replaceAll(RegExp(r'[^0-9]'), '');
      final lastNum = int.tryParse(numericPart) ?? (_startNumber - 1);
      final nextNumber = lastNum + 1;

      print('📝 Last purchase credit note: $lastNumber, Next: PCN$nextNumber');
      return 'PCN$nextNumber';
    } catch (e) {
      print('❌ Error generating purchase credit note number: $e');
      return 'PCN$_startNumber';
    }
  }
}

