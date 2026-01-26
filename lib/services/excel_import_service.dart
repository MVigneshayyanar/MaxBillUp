import 'dart:io';

import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maxbillup/utils/firestore_service.dart';

class ExcelImportService {
  /// Download Customer Template
  static Future<String?> downloadCustomerTemplate() async {
    try {
      // Request storage permission
      if (Platform.isAndroid) {
        var status = await Permission.storage.request();
        if (!status.isGranted) {
          status = await Permission.manageExternalStorage.request();
          if (!status.isGranted) {
            return 'Error: Storage permission denied';
          }
        }
      }

      // Load template from assets
      final ByteData data = await rootBundle.load('excel/Customer Templete.xlsx');
      final List<int> bytes = data.buffer.asUint8List();

      // Get downloads directory
      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download/MAXmybill');
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
      } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        // For desktop platforms, use downloads folder
        final downloadsPath = Platform.isWindows
            ? '${Platform.environment['USERPROFILE']}\\Downloads\\MAXmybill'
            : '${Platform.environment['HOME']}/Downloads/MAXmybill';
        directory = Directory(downloadsPath);
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      // Save file
      final String fileName = 'Customer_Template_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final File file = File('${directory.path}${Platform.pathSeparator}$fileName');
      await file.writeAsBytes(bytes, flush: true);

      // Verify file was created
      if (await file.exists()) {
        return file.path;
      } else {
        return 'Error: Failed to save file';
      }
    } catch (e) {
      return 'Error: ${e.toString()}';
    }
  }

  /// Download Product Template
  static Future<String?> downloadProductTemplate() async {
    try {
      // Request storage permission
      if (Platform.isAndroid) {
        var status = await Permission.storage.request();
        if (!status.isGranted) {
          status = await Permission.manageExternalStorage.request();
          if (!status.isGranted) {
            return 'Error: Storage permission denied';
          }
        }
      }

      // Load template from assets
      final ByteData data = await rootBundle.load('excel/Product Templete.xlsx');
      final List<int> bytes = data.buffer.asUint8List();

      // Get downloads directory
      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download/MAXmybill');
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
      } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        // For desktop platforms, use downloads folder
        final downloadsPath = Platform.isWindows
            ? '${Platform.environment['USERPROFILE']}\\Downloads\\MAXmybill'
            : '${Platform.environment['HOME']}/Downloads/MAXmybill';
        directory = Directory(downloadsPath);
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      // Save file
      final String fileName = 'Product_Template_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final File file = File('${directory.path}${Platform.pathSeparator}$fileName');
      await file.writeAsBytes(bytes, flush: true);

      // Verify file was created
      if (await file.exists()) {
        return file.path;
      } else {
        return 'Error: Failed to save file';
      }
    } catch (e) {
      return 'Error: ${e.toString()}';
    }
  }

  /// Pick Excel file - returns file bytes or null if cancelled
  static Future<Uint8List?> pickExcelFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        allowedExtensions: nul,
        withData: true,
        dialogTitle: 'Select Excel File (.xlsx, .xls)',
      );

      if (result == null || result.files.isEmpty) {
        print('📂 File picker cancelled or no file selected');
        return null;
      }

      final file = result.files.first;
      print('📂 File selected: ${file.name}, Size: ${file.size} bytes');

      // Try to get bytes directly first (works on web and some platforms)
      if (file.bytes != null) {
        print('📂 Got bytes directly from file picker');
        return file.bytes;
      }

      // Fall back to reading from path (desktop platforms)
      if (file.path != null) {
        print('📂 Reading bytes from path: ${file.path}');
        final bytes = await File(file.path!).readAsBytes();
        print('📂 Read ${bytes.length} bytes from file');
        return bytes;
      }

      print('❌ No bytes or path available for file');
      return null;
    } catch (e) {
      print('❌ Error picking file: $e');
      return null;
    }
  }

  /// Process Customer Excel bytes - call this after picking the file
  static Future<Map<String, dynamic>> processCustomersExcel(Uint8List bytes, String uid) async {
    try {
      print('🔵 Starting Excel processing...');
      final excel = Excel.decodeBytes(bytes);
      print('🔵 Excel decoded successfully');

      int successCount = 0;
      int failCount = 0;
      List<String> errors = [];

      // Get the first sheet
      final sheet = excel.tables.keys.first;
      final table = excel.tables[sheet];
      print('🔵 Sheet: $sheet, Rows: ${table?.rows.length ?? 0}');

      if (table == null) {
        return {'success': false, 'message': 'Empty Excel file'};
      }

      // Skip header row, start from row 1 (index 1)
      // Template columns (0-indexed):
      // 0: Phone Number*, 1: Name*, 2: Tax No, 3: Address, 4: Default Discount %,
      // 5: Last Due, 6: Date of Birth (dd-MM-yyyy), 7: Customer Rating (out of 5)
      // * = Required field
      for (int rowIndex = 1; rowIndex < table.rows.length; rowIndex++) {
        try {
          final row = table.rows[rowIndex];

          // Skip empty rows
          if (row.isEmpty || row.every((cell) => cell == null || cell.value == null)) {
            continue;
          }

          // Extract data based on template columns:
          // A: Phone Number, B: Name, C: Tax No, D: Address, E: Default Discount %,
          // F: Last Due, G: Date of Birth, H: Customer Rating
          final phone = row.length > 0 ? row[0]?.value?.toString().trim() ?? '' : '';
          final name = row.length > 1 ? row[1]?.value?.toString().trim() ?? '' : '';
          print('🔵 Processing row ${rowIndex + 1}: $name - $phone');
          final gstin = row.length > 2 ? row[2]?.value?.toString().trim() ?? '' : '';
          final address = row.length > 3 ? row[3]?.value?.toString().trim() ?? '' : '';
          final discountStr = row.length > 4 ? row[4]?.value?.toString().trim() ?? '0' : '0';
          final lastDueStr = row.length > 5 ? row[5]?.value?.toString().trim() ?? '0' : '0';
          final dobStr = row.length > 6 ? row[6]?.value?.toString().trim() ?? '' : '';
          final ratingStr = row.length > 7 ? row[7]?.value?.toString().trim() ?? '0' : '0';

          // Validate required fields
          if (name.isEmpty || phone.isEmpty) {
            errors.add('Row ${rowIndex + 1}: Name and Phone are required');
            failCount++;
            continue;
          }

          // Parse numeric values
          final defaultDiscount = double.tryParse(discountStr) ?? 0.0;
          final lastDue = double.tryParse(lastDueStr) ?? 0.0;
          final rating = int.tryParse(ratingStr) ?? 0;

          // Parse date of birth - Support multiple formats: dd-MM-yyyy, dd/MM/yyyy, yyyy-MM-dd
          DateTime? dob;
          if (dobStr.isNotEmpty) {
            try {
              final cleanDateStr = dobStr.trim();
              if (cleanDateStr.contains('-') || cleanDateStr.contains('/')) {
                final separator = cleanDateStr.contains('-') ? '-' : '/';
                final parts = cleanDateStr.split(separator);
                if (parts.length == 3) {
                  final firstNum = int.tryParse(parts[0]);
                  if (firstNum != null && firstNum <= 31) {
                    // dd-MM-yyyy format
                    dob = DateTime(
                      int.parse(parts[2]), // year
                      int.parse(parts[1]), // month
                      int.parse(parts[0]), // day
                    );
                  } else {
                    // yyyy-MM-dd format
                    dob = DateTime(
                      int.parse(parts[0]), // year
                      int.parse(parts[1]), // month
                      int.parse(parts[2]), // day
                    );
                  }
                }
              } else {
                // Try parsing as Excel date serial number
                final serialNumber = int.tryParse(cleanDateStr);
                if (serialNumber != null) {
                  dob = DateTime(1899, 12, 30).add(Duration(days: serialNumber));
                }
              }
            } catch (e) {
              errors.add('Row ${rowIndex + 1}: Invalid date format "$dobStr" - customer imported without DOB');
            }
          }

          // Check if customer already exists
          final existingCustomer = await FirestoreService().getDocument('customers', phone);

          if (existingCustomer.exists) {
            errors.add('Row ${rowIndex + 1}: Customer with phone $phone already exists');
            failCount++;
            continue;
          }

          // Prepare customer data
          final customerData = {
            'name': name,
            'phone': phone,
            'gstin': gstin.isEmpty ? null : gstin,
            'gst': gstin.isEmpty ? null : gstin,
            'address': address.isEmpty ? null : address,
            'defaultDiscount': defaultDiscount,
            'rating': rating.clamp(0, 5), // Ensure rating is between 0-5
            'balance': lastDue,
            'totalSales': 0,
            'createdAt': FieldValue.serverTimestamp(),
            'uid': uid,
          };

          // Add DOB if provided
          if (dob != null) {
            customerData['dob'] = Timestamp.fromDate(dob);
          }

          // Add customer to Firestore
          await FirestoreService().setDocument('customers', phone, customerData);
          print('✅ Customer added: $name');

          // If there's a last due amount, create credit entry
          if (lastDue > 0) {
            final creditsCollection = await FirestoreService().getStoreCollection('credits');
            await creditsCollection.add({
              'customerName': name,
              'customerPhone': phone,
              'amount': lastDue,
              'previousDue': 0,
              'totalDue': lastDue,
              'date': FieldValue.serverTimestamp(),
              'note': 'Opening balance from Excel import',
              'uid': uid,
              'type': 'credit',
            });
            print('✅ Credit entry added for $name: $lastDue');
          }

          successCount++;
        } catch (e) {
          print('❌ Error on row ${rowIndex + 1}: $e');
          errors.add('Row ${rowIndex + 1}: ${e.toString()}');
          failCount++;
        }
      }

      print('🎉 Import complete: $successCount success, $failCount failed');
      return {
        'success': true,
        'successCount': successCount,
        'failCount': failCount,
        'errors': errors,
        'message': '$successCount customers imported successfully${failCount > 0 ? ', $failCount failed' : ''}',
      };
    } catch (e) {
      print('💥 Fatal error: $e');
      return {'success': false, 'message': 'Error processing Excel: ${e.toString()}'};
    }
  }

  /// Import Customers from Excel (legacy method - picks file and processes)
  static Future<Map<String, dynamic>> importCustomers(String uid) async {
    try {
      // Pick Excel file - Allow all file types to ensure .xlsx files are visible
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        allowedExtensions: null,
        withData: true,
        dialogTitle: 'Select Excel File (.xlsx, .xls)',
      );

      if (result == null) {
        return {'success': false, 'message': 'No file selected'};
      }

      // Read Excel file
      final bytes = result.files.first.bytes ?? await File(result.files.first.path!).readAsBytes();

      // Use the new processing method
      return await processCustomersExcel(bytes, uid);
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  /// Process Product Excel bytes - call this after picking the file
  static Future<Map<String, dynamic>> processProductsExcel(Uint8List bytes, String uid) async {
    try {
      final excel = Excel.decodeBytes(bytes);

      int successCount = 0;
      int failCount = 0;
      List<String> errors = [];

      // Get the first sheet
      final sheet = excel.tables.keys.first;
      final table = excel.tables[sheet];

      if (table == null) {
        return {'success': false, 'message': 'Empty Excel file'};
      }

      // Skip header row, start from row 1 (index 1)
      // Template columns (0-indexed):
      // 0: Product Code/Barcode*, 1: Product Name*, 2: MRP*, 3: Sale Price*, 4: Purchase Price,
      // 5: Quantity, 6: Unit*, 7: Category, 8: GST%, 9: HSN Code
      // * = Required field
      for (int rowIndex = 1; rowIndex < table.rows.length; rowIndex++) {
        try {
          final row = table.rows[rowIndex];

          // Skip empty rows
          if (row.isEmpty || row.every((cell) => cell == null || cell.value == null)) {
            continue;
          }

          // Extract data based on template columns
          final barcode = row.length > 0 ? row[0]?.value?.toString().trim() ?? '' : '';
          final name = row.length > 1 ? row[1]?.value?.toString().trim() ?? '' : '';
          final mrpStr = row.length > 2 ? row[2]?.value?.toString().trim() ?? '0' : '0';
          final salePriceStr = row.length > 3 ? row[3]?.value?.toString().trim() ?? '0' : '0';
          final purchasePriceStr = row.length > 4 ? row[4]?.value?.toString().trim() ?? '0' : '0';
          final quantityStr = row.length > 5 ? row[5]?.value?.toString().trim() ?? '0' : '0';
          final unit = row.length > 6 ? row[6]?.value?.toString().trim() ?? 'PCS' : 'PCS';
          final category = row.length > 7 ? row[7]?.value?.toString().trim() ?? '' : '';
          final gstStr = row.length > 8 ? row[8]?.value?.toString().trim() ?? '0' : '0';
          final hsnCode = row.length > 9 ? row[9]?.value?.toString().trim() ?? '' : '';

          // Validate required fields
          if (name.isEmpty || barcode.isEmpty) {
            errors.add('Row ${rowIndex + 1}: Product Name and Barcode are required');
            failCount++;
            continue;
          }

          // Parse numeric values
          final mrp = double.tryParse(mrpStr) ?? 0.0;
          final salePrice = double.tryParse(salePriceStr) ?? 0.0;
          final purchasePrice = double.tryParse(purchasePriceStr) ?? 0.0;
          final quantity = double.tryParse(quantityStr) ?? 0.0;
          final gst = double.tryParse(gstStr) ?? 0.0;

          if (mrp <= 0 || salePrice <= 0) {
            errors.add('Row ${rowIndex + 1}: MRP and Sale Price must be greater than 0');
            failCount++;
            continue;
          }

          // Check if product already exists
          final existingProduct = await FirestoreService().getDocument('products', barcode);

          if (existingProduct.exists) {
            errors.add('Row ${rowIndex + 1}: Product with barcode $barcode already exists');
            failCount++;
            continue;
          }

          // Prepare product data
          final productData = {
            'name': name,
            'barcode': barcode,
            'mrp': mrp,
            'salePrice': salePrice,
            'purchasePrice': purchasePrice,
            'quantity': quantity,
            'unit': unit.toUpperCase(),
            'category': category.isEmpty ? 'General' : category,
            'gst': gst,
            'hsnCode': hsnCode.isEmpty ? null : hsnCode,
            'createdAt': FieldValue.serverTimestamp(),
            'uid': uid,
          };

          // Add product to Firestore
          await FirestoreService().setDocument('products', barcode, productData);

          successCount++;
        } catch (e) {
          errors.add('Row ${rowIndex + 1}: ${e.toString()}');
          failCount++;
        }
      }

      return {
        'success': true,
        'successCount': successCount,
        'failCount': failCount,
        'errors': errors,
        'message': '$successCount products imported successfully${failCount > 0 ? ', $failCount failed' : ''}',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error processing Excel: ${e.toString()}'};
    }
  }

  /// Import Products from Excel (legacy method - picks file and processes)
  static Future<Map<String, dynamic>> importProducts(String uid) async {
    try {
      // Pick Excel file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        allowedExtensions: null,
        withData: true,
        dialogTitle: 'Select Excel File (.xlsx, .xls)',
      );

      if (result == null) {
        return {'success': false, 'message': 'No file selected'};
      }

      // Read Excel file
      final bytes = result.files.first.bytes ?? await File(result.files.first.path!).readAsBytes();

      // Use the new processing method
      return await processProductsExcel(bytes, uid);
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }
}

