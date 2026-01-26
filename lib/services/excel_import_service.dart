import 'dart:io';
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

  /// Import Customers from Excel
  static Future<Map<String, dynamic>> importCustomers(String uid) async {
    try {
      // Pick Excel file - Show all files so user can see Excel files
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: true,
        dialogTitle: 'Select Excel File (.xlsx, .xls)',
      );

      if (result == null) {
        return {'success': false, 'message': 'No file selected'};
      }

      // Read Excel file
      final bytes = result.files.first.bytes ?? await File(result.files.first.path!).readAsBytes();
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
      for (int rowIndex = 1; rowIndex < table.rows.length; rowIndex++) {
        try {
          final row = table.rows[rowIndex];

          // Skip empty rows
          if (row.isEmpty || row.every((cell) => cell == null || cell.value == null)) {
            continue;
          }

          // Extract data (columns: Name, Phone, Email, Address, GST)
          final name = row[0]?.value?.toString().trim() ?? '';
          final phone = row[1]?.value?.toString().trim() ?? '';
          final email = row[2]?.value?.toString().trim() ?? '';
          final address = row[3]?.value?.toString().trim() ?? '';
          final gst = row[4]?.value?.toString().trim() ?? '';

          // Validate required fields
          if (name.isEmpty || phone.isEmpty) {
            errors.add('Row ${rowIndex + 1}: Name and Phone are required');
            failCount++;
            continue;
          }

          // Check if customer already exists
          final existingCustomer = await FirestoreService().getDocument('customers', phone);

          if (existingCustomer.exists) {
            errors.add('Row ${rowIndex + 1}: Customer with phone $phone already exists');
            failCount++;
            continue;
          }

          // Add customer to Firestore
          await FirestoreService().setDocument('customers', phone, {
            'name': name,
            'phone': phone,
            'email': email,
            'address': address,
            'gst': gst,
            'createdAt': FieldValue.serverTimestamp(),
            'uid': uid,
          });

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
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  /// Import Products from Excel
  static Future<Map<String, dynamic>> importProducts(String uid) async {
    try {
      // Pick Excel file - Show all files so user can see Excel files
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: true,
        dialogTitle: 'Select Excel File (.xlsx, .xls)',
      );

      if (result == null) {
        return {'success': false, 'message': 'No file selected'};
      }

      // Read Excel file
      final bytes = result.files.first.bytes ?? await File(result.files.first.path!).readAsBytes();
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
      // 0: Category, 1: Item Name*, 2: Product Code, 3: Price, 4: Initial Stock,
      // 5: Low Stock Alert, 6: Measuring Unit, 7: Total Cost Price, 8: MRP,
      // 9: Tax Type (GST/VAT), 10: Tax %, 11: Item Location, 12: Expiry Date (dd-MM-yyyy)
      // * = Required field
      for (int rowIndex = 1; rowIndex < table.rows.length; rowIndex++) {
        try {
          final row = table.rows[rowIndex];

          // Skip empty rows
          if (row.isEmpty || row.every((cell) => cell == null || cell.value == null)) {
            continue;
          }

          // Extract data based on template columns:
          // A: Category, B: Item Name, C: Product code, D: Price, E: Initial Stock,
          // F: Low Stock Alert, G: Measuring Unit, H: Total Cost Price, I: MRP,
          // J: Tax Type, K: Tax %, L: Item Location, M: Expiry Date

          final category = row.length > 0 ? row[0]?.value?.toString().trim() ?? 'General' : 'General';
          final itemName = row.length > 1 ? row[1]?.value?.toString().trim() ?? '' : '';
          final productCode = row.length > 2 ? row[2]?.value?.toString().trim() ?? '' : '';
          final priceStr = row.length > 3 ? row[3]?.value?.toString().trim() ?? '0' : '0';
          final stockStr = row.length > 4 ? row[4]?.value?.toString().trim() ?? '0' : '0';
          final lowStockStr = row.length > 5 ? row[5]?.value?.toString().trim() ?? '0' : '0';
          final unit = row.length > 6 ? row[6]?.value?.toString().trim() ?? 'Piece' : 'Piece';
          final costPriceStr = row.length > 7 ? row[7]?.value?.toString().trim() ?? '0' : '0';
          final mrpStr = row.length > 8 ? row[8]?.value?.toString().trim() ?? '0' : '0';
          final taxType = row.length > 9 ? row[9]?.value?.toString().trim() ?? 'vat' : 'vat';
          final taxPercentageStr = row.length > 10 ? row[10]?.value?.toString().trim() ?? '0' : '0';
          final location = row.length > 11 ? row[11]?.value?.toString().trim() ?? '' : '';
          final expiryDateStr = row.length > 12 ? row[12]?.value?.toString().trim() ?? '' : '';

          // Validate required fields
          if (itemName.isEmpty) {
            errors.add('Row ${rowIndex + 1}: Product name is required');
            failCount++;
            continue;
          }

          // Parse numeric values
          final price = double.tryParse(priceStr) ?? 0.0;
          final stock = double.tryParse(stockStr) ?? 0.0;
          final lowStock = double.tryParse(lowStockStr) ?? 0.0;
          final costPrice = double.tryParse(costPriceStr) ?? 0.0;
          final mrp = double.tryParse(mrpStr) ?? 0.0;
          final taxPercentage = double.tryParse(taxPercentageStr) ?? 0.0;

          // Parse expiry date - Support multiple formats: dd-MM-yyyy, dd/MM/yyyy, yyyy-MM-dd
          DateTime? expiryDate;
          if (expiryDateStr.isNotEmpty) {
            try {
              // Remove any extra spaces
              final cleanDateStr = expiryDateStr.trim();

              // Try dd-MM-yyyy or dd/MM/yyyy format first
              if (cleanDateStr.contains('-') || cleanDateStr.contains('/')) {
                final separator = cleanDateStr.contains('-') ? '-' : '/';
                final parts = cleanDateStr.split(separator);

                if (parts.length == 3) {
                  // Check if first part is likely a day (1-31) - then it's dd-MM-yyyy
                  final firstNum = int.tryParse(parts[0]);
                  if (firstNum != null && firstNum <= 31) {
                    // dd-MM-yyyy format
                    expiryDate = DateTime(
                      int.parse(parts[2]), // year
                      int.parse(parts[1]), // month
                      int.parse(parts[0]), // day
                    );
                  } else {
                    // yyyy-MM-dd format
                    expiryDate = DateTime(
                      int.parse(parts[0]), // year
                      int.parse(parts[1]), // month
                      int.parse(parts[2]), // day
                    );
                  }
                }
              } else {
                // Try parsing as a number (Excel date serial number)
                final serialNumber = int.tryParse(cleanDateStr);
                if (serialNumber != null) {
                  // Excel date: number of days since 1899-12-30
                  expiryDate = DateTime(1899, 12, 30).add(Duration(days: serialNumber));
                }
              }
            } catch (e) {
              // Add to errors but don't fail the import
              errors.add('Row ${rowIndex + 1}: Invalid date format "$expiryDateStr" - product imported without expiry date');
            }
          }

          // Add product to Firestore
          final productData = {
            'itemName': itemName,
            'category': category,
            'productCode': productCode.isNotEmpty ? productCode : '${DateTime.now().millisecondsSinceEpoch}',
            'price': price,
            'currentStock': stock,
            'lowStockAlert': lowStock,
            'stockUnit': unit,
            'costPrice': costPrice,
            'mrp': mrp,
            'location': location,
            'stockEnabled': true,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'uid': uid,
          };

          // Add tax information if provided
          if (taxPercentage > 0) {
            productData['taxType'] = taxType.toLowerCase() == 'gst' ? 'Price is without Tax' : 'Price includes Tax';
            productData['taxPercentage'] = taxPercentage;
            productData['taxName'] = taxType.toUpperCase();
          }

          // Add expiry date if provided
          if (expiryDate != null) {
            productData['expiryDate'] = expiryDate.toIso8601String();
          }

          await FirestoreService().addDocument('Products', productData);
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
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }
}

