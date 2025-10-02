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
      if (['xlsx', 'xls'].contains(file.extension?.toLowerCase())) {
        records = await _processExcelFromBytes(file.bytes!);
      } else {
        return {'success': false, 'message': 'Unsupported file type. Only Excel files (.xlsx, .xls) are supported.'};
      }

      if (records.isEmpty) {
        return {'success': false, 'message': 'No valid records found in file'};
      }

      // Upload records to backend
      int successCount = 0;
      int failedCount = 0;
      List<String> errors = [];

      for (int i = 0; i < records.length; i++) {
        var record = records[i];
        try {
          final result = await ApiService.addEmission(
            category: record['category'],
            amount: record['amount'],
            unit: record['unit'], 
            month: record['month'],
            year: record['year'],
          );

          if (result['success'] == true) {
            successCount++;
          } else {
            failedCount++;
            errors.add('Row ${i + 2}: ${result['message'] ?? 'Unknown error'}');
          }
        } catch (e) {
          failedCount++;
          errors.add('Row ${i + 2}: $e');
        }
      }

      String resultMessage;
      if (successCount > 0 && failedCount == 0) {
        resultMessage = 'Successfully uploaded $successCount records';
      } else if (successCount > 0 && failedCount > 0) {
        resultMessage = 'Uploaded $successCount successful, $failedCount failed out of ${records.length} total records';
      } else if (successCount == 0 && failedCount > 0) {
        resultMessage = 'Upload failed: $failedCount failed out of ${records.length} total records';
      } else {
        resultMessage = 'No records processed';
      }

      return {
        'success': successCount > 0,
        'message': resultMessage,
        'successCount': successCount,
        'failedCount': failedCount,
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

  // Generate CSV template for user download - Updated for TGO categories
  static String generateCSVTemplate() {
    return '''date,category,amount,unit,description
2024-01-15,grid_electricity,500,kwh,Office electricity usage
2024-01-20,gas_diesel_oil,100,litre,Stationary generator fuel
2024-01-25,motor_gasoline_catalyst,50,litre,Vehicle fuel
2024-02-01,natural_gas_mj,1500,mj,Industrial heating
2024-02-05,lpg_kg,25,kg,Kitchen gas usage
2024-02-10,r134a,2,kg,Air conditioning refrigerant
2024-02-15,fuel_wood,300,kg,Biomass heating
2024-02-20,cng,40,kg,Compressed natural gas vehicle''';
  }

  // Generate Excel template data for user download
  static List<List<dynamic>> generateExcelTemplateData() {
    return [
      // Header row - Only 4 columns
      ['Date', 'Category', 'Amount', 'Unit'],
      
      // Scope 1 - Stationary Combustion (Fossil Fuels) examples
      ['15/01/2024', 'natural_gas_scf', 1000, 'scf'],
      ['16/01/2024', 'gas_diesel_oil', 100, 'litre'],
      ['17/01/2024', 'lpg_kg', 25, 'kg'],
      
      // Scope 1 - Stationary Combustion (Biomass) examples
      ['18/01/2024', 'fuel_wood', 200, 'kg'],
      ['19/01/2024', 'bagasse', 500, 'kg'],
      
      // Scope 1 - Mobile Combustion (On Road) examples
      ['20/01/2024', 'motor_gasoline_catalyst', 80, 'litre'],
      ['21/01/2024', 'gas_diesel_oil_mobile', 120, 'litre'],
      ['22/01/2024', 'cng', 30, 'kg'],
      
      // Scope 1 - Mobile Combustion (Off Road) examples
      ['23/01/2024', 'diesel_agriculture', 50, 'litre'],
      ['24/01/2024', 'gasoline_4s_industrial', 25, 'litre'],
      
      // Scope 1 - Fugitive Emissions (Refrigerants) examples
      ['25/01/2024', 'r22', 1.5, 'kg'],
      ['26/01/2024', 'r134a', 0.8, 'kg'],
      
      // Scope 2 - Purchased Electricity example
      ['27/01/2024', 'grid_electricity', 1500, 'kwh'],
    ];
  }

  // Generate detailed category guide
  static Map<String, List<Map<String, String>>> getCategoryGuide() {
    return {
      'Scope 1 - Stationary Combustion (Fossil Fuels)': [
        {'category': 'natural_gas_scf', 'unit': 'scf', 'description': 'Natural Gas (volumetric)'},
        {'category': 'natural_gas_mj', 'unit': 'MJ', 'description': 'Natural Gas (energy content)'},
        {'category': 'gas_diesel_oil', 'unit': 'litre', 'description': 'Gas/Diesel Oil for generators, boilers'},
        {'category': 'heavy_fuel_oil_a', 'unit': 'litre', 'description': 'Heavy Fuel Oil A (lighter grade)'},
        {'category': 'heavy_fuel_oil_c', 'unit': 'litre', 'description': 'Heavy Fuel Oil C (heavier grade)'},
        {'category': 'lpg_litre', 'unit': 'litre', 'description': 'LPG - Liquefied Petroleum Gas (volume)'},
        {'category': 'lpg_kg', 'unit': 'kg', 'description': 'LPG - Liquefied Petroleum Gas (weight)'},
        {'category': 'motor_gasoline', 'unit': 'litre', 'description': 'Motor Gasoline for stationary use'},
        {'category': 'lignite_coal', 'unit': 'kg', 'description': 'Lignite Coal'},
        {'category': 'anthracite_coal', 'unit': 'kg', 'description': 'Anthracite Coal'},
        {'category': 'sub_bituminous_coal', 'unit': 'kg', 'description': 'Sub-bituminous Coal'},
        {'category': 'jet_kerosene', 'unit': 'litre', 'description': 'Jet Kerosene'},
      ],
      'Scope 1 - Stationary Combustion (Biomass)': [
        {'category': 'fuel_wood', 'unit': 'kg', 'description': 'Fuel Wood (excludes biogenic CO₂)'},
        {'category': 'fuel_wood_co2', 'unit': 'kg', 'description': 'Fuel Wood (includes biogenic CO₂)'},
        {'category': 'bagasse', 'unit': 'kg', 'description': 'Bagasse (excludes biogenic CO₂)'},
        {'category': 'bagasse_co2', 'unit': 'kg', 'description': 'Bagasse (includes biogenic CO₂)'},
        {'category': 'palm_kernel_shell', 'unit': 'kg', 'description': 'Palm Kernel Shell (excludes biogenic CO₂)'},
        {'category': 'palm_kernel_shell_co2', 'unit': 'kg', 'description': 'Palm Kernel Shell (includes biogenic CO₂)'},
        {'category': 'corn_cob', 'unit': 'kg', 'description': 'Corn Cob (excludes biogenic CO₂)'},
        {'category': 'corn_cob_co2', 'unit': 'kg', 'description': 'Corn Cob (includes biogenic CO₂)'},
        {'category': 'biogas', 'unit': 'm³', 'description': 'Biogas (excludes biogenic CO₂)'},
        {'category': 'biogas_co2', 'unit': 'm³', 'description': 'Biogas (includes biogenic CO₂)'},
      ],
      'Scope 1 - Mobile Combustion (On Road)': [
        {'category': 'motor_gasoline_uncontrolled', 'unit': 'litre', 'description': 'Motor Gasoline - Uncontrolled vehicles'},
        {'category': 'motor_gasoline_catalyst', 'unit': 'litre', 'description': 'Motor Gasoline - Oxidation Catalyst'},
        {'category': 'motor_gasoline_low_mileage', 'unit': 'litre', 'description': 'Motor Gasoline - Low Mileage Light Duty (1995+)'},
        {'category': 'gas_diesel_oil_mobile', 'unit': 'litre', 'description': 'Gas/Diesel Oil for mobile vehicles'},
        {'category': 'cng', 'unit': 'kg', 'description': 'Compressed Natural Gas (CNG)'},
        {'category': 'lpg_mobile_litre', 'unit': 'litre', 'description': 'LPG - Mobile vehicles (volume)'},
        {'category': 'lpg_mobile_kg', 'unit': 'kg', 'description': 'LPG - Mobile vehicles (weight)'},
      ],
      'Scope 1 - Mobile Combustion (Off Road - Diesel)': [
        {'category': 'diesel_agriculture', 'unit': 'litre', 'description': 'Agriculture Equipment - Diesel'},
        {'category': 'diesel_forestry', 'unit': 'litre', 'description': 'Forestry Equipment - Diesel'},
        {'category': 'diesel_industrial', 'unit': 'litre', 'description': 'Industrial Equipment - Diesel'},
        {'category': 'diesel_household', 'unit': 'litre', 'description': 'Household Equipment - Diesel'},
      ],
      'Scope 1 - Mobile Combustion (Off Road - Gasoline 4-Stroke)': [
        {'category': 'gasoline_4s_agriculture', 'unit': 'litre', 'description': 'Agriculture Equipment - Gasoline 4-Stroke'},
        {'category': 'gasoline_4s_forestry', 'unit': 'litre', 'description': 'Forestry Equipment - Gasoline 4-Stroke'},
        {'category': 'gasoline_4s_industrial', 'unit': 'litre', 'description': 'Industrial Equipment - Gasoline 4-Stroke'},
        {'category': 'gasoline_4s_household', 'unit': 'litre', 'description': 'Household Equipment - Gasoline 4-Stroke'},
      ],
      'Scope 1 - Mobile Combustion (Off Road - Gasoline 2-Stroke)': [
        {'category': 'gasoline_2s_agriculture', 'unit': 'litre', 'description': 'Agriculture Equipment - Gasoline 2-Stroke'},
        {'category': 'gasoline_2s_forestry', 'unit': 'litre', 'description': 'Forestry Equipment - Gasoline 2-Stroke'},
        {'category': 'gasoline_2s_industrial', 'unit': 'litre', 'description': 'Industrial Equipment - Gasoline 2-Stroke'},
        {'category': 'gasoline_2s_household', 'unit': 'litre', 'description': 'Household Equipment - Gasoline 2-Stroke'},
      ],
      'Scope 1 - Fugitive Emissions (Refrigerants)': [
        {'category': 'r22', 'unit': 'kg', 'description': 'R-22 (HCFC-22) - GWP: 1,760'},
        {'category': 'r32', 'unit': 'kg', 'description': 'R-32 - GWP: 677'},
        {'category': 'r125', 'unit': 'kg', 'description': 'R-125 - GWP: 3,170'},
        {'category': 'r134', 'unit': 'kg', 'description': 'R-134 - GWP: 1,120'},
        {'category': 'r134a', 'unit': 'kg', 'description': 'R-134a - GWP: 1,300'},
        {'category': 'r143', 'unit': 'kg', 'description': 'R-143 - GWP: 328'},
        {'category': 'r143a', 'unit': 'kg', 'description': 'R-143a - GWP: 4,800'},
      ],
      'Scope 2 - Purchased Electricity': [
        {'category': 'grid_electricity', 'unit': 'kWh', 'description': 'Grid Mix Electricity (Thailand)'},
      ],
    };
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
        'spreadsheets': ['Excel (.xlsx, .xls)'],
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
