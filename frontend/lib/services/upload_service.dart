import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'package:csv/csv.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'api_service.dart';
import '../utils/constants.dart';

class UploadService {
  
  // Process Excel/CSV files (Web compatible)
  static Future<Map<String, dynamic>> processSpreadsheet(PlatformFile file) async {
    try {
      // Check if we have file bytes (works on all platforms)
      if (file.bytes == null) {
        return {'success': false, 'message': 'File data is not available'};
      }

      List<Map<String, dynamic>> records = [];
      
      // Read file based on extension using bytes
      if (file.extension?.toLowerCase() == 'csv') {
        records = await _processCSVFromBytes(file.bytes!);
      } else if (['xlsx', 'xls'].contains(file.extension?.toLowerCase())) {
        records = await _processExcelFromBytes(file.bytes!);
      } else {
        return {'success': false, 'message': 'Unsupported file type'};
      }

      if (records.isEmpty) {
        return {'success': false, 'message': 'No valid records found in file'};
      }

      // Upload records to backend
      int successCount = 0;
      List<String> errors = [];

      for (var record in records) {
        try {
          final result = await ApiService.addEmission(
            category: record['category'],
            amount: record['amount'],
            unit: record['unit'], 
            month: record['month'],
            year: record['year'],
          );

          if (result['success']) {
            successCount++;
          } else {
            errors.add('Row ${records.indexOf(record) + 1}: ${result['message']}');
          }
        } catch (e) {
          errors.add('Row ${records.indexOf(record) + 1}: $e');
        }
      }

      return {
        'success': true,
        'message': 'Processed $successCount/${records.length} records successfully',
        'successCount': successCount,
        'totalCount': records.length,
        'errors': errors,
      };

    } catch (e) {
      return {'success': false, 'message': 'Error processing file: $e'};
    }
  }

  // Process CSV from bytes (Web compatible)
  static Future<List<Map<String, dynamic>>> _processCSVFromBytes(Uint8List bytes) async {
    try {
      final content = String.fromCharCodes(bytes);
      List<List<dynamic>> csvData = const CsvToListConverter().convert(content);
      
      if (csvData.isEmpty) return [];
      
      List<Map<String, dynamic>> records = [];
      
      // Skip header row (row 0), start from row 1
      for (int i = 1; i < csvData.length; i++) {
        try {
          List<dynamic> row = csvData[i];
          
          if (row.length < 4) continue; // Need at least date, category, amount, unit
          
          // Parse date (YYYY-MM-DD format expected)
          String dateStr = row[0].toString().trim();
          DateTime date = DateTime.parse(dateStr);
          
          String category = row[1].toString().toLowerCase().trim();
          double amount = double.parse(row[2].toString().trim());
          String unit = row[3].toString().toLowerCase().trim();
          
          // Validate category
          if (!Constants.emissionCategories.contains(category)) {
            print('Invalid category: $category, skipping row ${i + 1}');
            continue;
          }
          
          // Validate unit matches category
          if (Constants.categoryUnits[category] != unit) {
            print('Invalid unit $unit for category $category, skipping row ${i + 1}');
            continue;
          }
          
          records.add({
            'category': category,
            'amount': amount,
            'unit': unit,
            'month': date.month,
            'year': date.year,
          });
          
        } catch (e) {
          print('Error processing CSV row ${i + 1}: $e');
          continue;
        }
      }
      
      return records;
    } catch (e) {
      print('Error parsing CSV: $e');
      return [];
    }
  }

  // Process Excel from bytes (Web compatible)
  static Future<List<Map<String, dynamic>>> _processExcelFromBytes(Uint8List bytes) async {
    try {
      final excel = Excel.decodeBytes(bytes);
      List<Map<String, dynamic>> records = [];
      
      // Get first sheet
      String? sheetName = excel.tables.keys.first;
      Sheet? sheet = excel.tables[sheetName];
      
      if (sheet == null) return [];
      
      // Skip header row, start from row 1
      for (int rowIndex = 1; rowIndex < sheet.maxRows; rowIndex++) {
        try {
          List<Data?> row = sheet.row(rowIndex);
          
          if (row.length < 4) continue; // Need at least 4 columns
          
          // Parse date from first column - Fixed nullable warnings
          String? dateValue = row[0]?.value?.toString();
          String dateStr = dateValue?.trim() ?? '';
          if (dateStr.isEmpty) continue;
          
          DateTime date = DateTime.parse(dateStr);
          
          String? categoryValue = row[1]?.value?.toString();
          String category = categoryValue?.toLowerCase().trim() ?? '';
          
          String? amountValue = row[2]?.value?.toString();
          String amountStr = amountValue?.trim() ?? '';
          
          String? unitValue = row[3]?.value?.toString();
          String unit = unitValue?.toLowerCase().trim() ?? '';
          
          if (category.isEmpty || amountStr.isEmpty || unit.isEmpty) continue;
          
          double amount = double.parse(amountStr);
          
          // Validate category and unit
          if (!Constants.emissionCategories.contains(category)) {
            print('Invalid category: $category, skipping row ${rowIndex + 1}');
            continue;
          }
          
          if (Constants.categoryUnits[category] != unit) {
            print('Invalid unit $unit for category $category, skipping row ${rowIndex + 1}');
            continue;
          }
          
          records.add({
            'category': category,
            'amount': amount,
            'unit': unit,
            'month': date.month,
            'year': date.year,
          });
          
        } catch (e) {
          print('Error processing Excel row ${rowIndex + 1}: $e');
          continue;
        }
      }
      
      return records;
    } catch (e) {
      print('Error parsing Excel: $e');
      return [];
    }
  }

  // Process PDF file (Web compatible)
  static Future<Map<String, dynamic>> processPDF(PlatformFile file) async {
    try {
      if (file.bytes == null) {
        return {'success': false, 'message': 'File data is not available'};
      }

      // Send PDF to backend for processing
      final result = await _uploadBytesToServer(file.bytes!, file.name, 'pdf');
      return result;
      
    } catch (e) {
      return {'success': false, 'message': 'Error processing PDF: $e'};
    }
  }

  // Process image for OCR (Web compatible)
  static Future<Map<String, dynamic>> processImageOCR(PlatformFile file) async {
    try {
      if (file.bytes == null) {
        return {'success': false, 'message': 'File data is not available'};
      }

      // Send image to backend for OCR processing
      final result = await _uploadBytesToServer(file.bytes!, file.name, 'image');
      return result;
      
    } catch (e) {
      return {'success': false, 'message': 'Error processing image: $e'};
    }
  }

  // Upload bytes to backend server (Web compatible)
  static Future<Map<String, dynamic>> _uploadBytesToServer(
    Uint8List bytes, 
    String fileName, 
    String type
  ) async {
    try {
      final token = await ApiService.getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${Constants.apiUrl}/upload'),
      );

      // Add headers
      request.headers['Authorization'] = 'Bearer $token';

      // Add file from bytes (works on web)
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
      ));

      // Send request
      var response = await request.send();
      var responseBody = await response.stream.bytesToString();
      var data = jsonDecode(responseBody);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'File processed successfully',
          'type': type,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Upload failed',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Generate CSV template for user download
  static String generateCSVTemplate() {
    return '''date,category,amount,unit,description
2024-01-15,electricity,500,kWh,Office electricity usage
2024-01-20,transport,150,km,Business travel  
2024-01-25,diesel,100,liter,Generator fuel
2024-02-01,natural_gas,50,cubic_meter,Heating
2024-02-05,waste,25,kg,Office waste disposal''';
  }

  // Get upload instructions
  static Map<String, dynamic> getUploadInstructions() {
    return {
      'csv_excel_format': {
        'required_columns': ['date', 'category', 'amount', 'unit', 'description'],
        'date_format': 'YYYY-MM-DD (e.g., 2024-01-15)',
        'valid_categories': Constants.emissionCategories,
        'category_units': Constants.categoryUnits,
      },
      'supported_files': {
        'spreadsheets': ['CSV', 'Excel (.xlsx, .xls)'],
        'documents': ['PDF (utility bills)'],
        'images': ['JPG, PNG (photos of bills)'],
      },
      'file_size_limit': '16MB maximum',
      'platform_note': kIsWeb 
        ? 'Running on web - using file bytes for processing'
        : 'Running on mobile/desktop - using file paths',
    };
  }
}