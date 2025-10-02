import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
// import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import '../services/api_service.dart';
import '../services/upload_service.dart';
import '../services/localization_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import 'dart:html' as html;

class UploadDataScreen extends StatefulWidget {
  @override
  _UploadDataScreenState createState() => _UploadDataScreenState();
}

class _UploadDataScreenState extends State<UploadDataScreen> {
  bool _isUploading = false;
  String _uploadStatus = '';
  List<String> _uploadResults = [];
  String? _selectedFileName;
  final LocalizationService _localization = LocalizationService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_localization.uploadDataTitle),
        backgroundColor: Colors.green[700],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // File Type Support Info
            _buildSupportedFilesCard(),
            SizedBox(height: 20),

            // Single Upload Zone
            _buildUnifiedUploadZone(),
            SizedBox(height: 20),

            // Status and Results
            if (_uploadStatus.isNotEmpty) ...[
              _buildStatusCard(),
              SizedBox(height: 20),
            ],

            // Template Section
            _buildTemplateSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportedFilesCard() {
    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info, color: Colors.blue[700]),
                SizedBox(width: 8),
                Text(
                  _localization.supportedFileTypes,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            
            // File types grid
            Row(
              children: [
                Expanded(
                  child: _buildFileTypeInfo(
                    Icons.table_chart,
                    _localization.spreadsheets,
                    _localization.csvExcel,
                    _localization.bulkEmissionImport,
                    Colors.green,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildFileTypeInfo(
                    Icons.picture_as_pdf,
                    _localization.pdfDocuments,
                    _localization.utilityBills,
                    _localization.automaticExtraction,
                    Colors.red,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildFileTypeInfo(
                    Icons.camera_alt,
                    _localization.images,
                    _localization.jpgPngPhotos,
                    _localization.ocrTextRecognition,
                    Colors.purple,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      // border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.info, color: Colors.orange[700], size: 20),
                        SizedBox(height: 4),
                        Text(
                          _localization.fileSizeLimit,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.orange[700],
                          ),
                        ),
                        Text(
                          _localization.maximum16MB,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.orange[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileTypeInfo(IconData icon, String title, String formats, String description, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: color,
            ),
          ),
          Text(
            formats,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnifiedUploadZone() {
  return Container(
    height: 200,
    decoration: ShapeDecoration(
  shape: RoundedRectangleBorder(
    side: BorderSide(
      color: _isUploading ? Colors.orange : Colors.green,
      width: 2,
    ),
    borderRadius: BorderRadius.circular(12),
  ),
  color: _isUploading ? Colors.orange.shade50 : Colors.green.shade50,
),
    child: InkWell(
      onTap: _isUploading ? null : _pickAndUploadFile,
      borderRadius: BorderRadius.circular(12),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isUploading) ...[
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.orange[700]!,
                  ),
                ),
              ),
              SizedBox(height: 16),
              Text(
                _localization.processingFile,
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.orange[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_selectedFileName != null)
                Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    _selectedFileName!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ] else ...[
              Icon(
                Icons.cloud_upload,
                size: 64,
                color: Colors.green[700],
              ),
              SizedBox(height: 16),
              Text(
                _localization.uploadYourFiles,
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.green[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                _localization.csvExcelPdfImages,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.green[600],
                ),
              ),
              SizedBox(height: 4),
              Text(
                _localization.tapToSelectFiles,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

  Widget _buildStatusCard() {
    final isSuccess = !_uploadStatus.contains('Error') && !_uploadStatus.contains('Failed');
    
    return Card(
      color: isSuccess ? Colors.green[50] : Colors.red[50],
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSuccess ? Icons.check_circle : Icons.error,
                  color: isSuccess ? Colors.green : Colors.red,
                ),
                SizedBox(width: 8),
                Text(
                  isSuccess ? _localization.uploadStatus : _localization.uploadFailed,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isSuccess ? Colors.green[700] : Colors.red[700],
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(_uploadStatus),
            
            if (_uploadResults.isNotEmpty) ...[
              SizedBox(height: 16),
              Text(
                _localization.details,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Container(
                height: 150,
                child: ListView.builder(
                  itemCount: _uploadResults.length,
                  itemBuilder: (context, index) {
                    final result = _uploadResults[index];
                    final isResultSuccess = result.contains('✓') || result.contains('successfully');
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 1),
                      child: Text(
                        result,
                        style: TextStyle(
                          fontSize: 11,
                          color: isResultSuccess ? Colors.green[700] : Colors.red[700],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.download, color: Colors.green[700]),
                SizedBox(width: 8),
                Text(
                  'Download Templates & Guidelines',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Download ready-to-use templates with TGO emission factors',
              style: TextStyle(color: Colors.grey[700]),
            ),
            SizedBox(height: 16),
            
            // Template download button
            ElevatedButton.icon(
              onPressed: _downloadExcelTemplate,
              icon: Icon(Icons.insert_drive_file),
              label: Text('Download Excel Template'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
              ),
            ),
            SizedBox(height: 16),
            
            // Sample data preview
            Text(
              'Template Format (4 columns - Date/Category/Amount/Unit):',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Date,Category,Amount,Unit\n'
                '15/01/2024,grid_electricity,500,kwh\n'
                '20/01/2024,gas_diesel_oil,100,litre\n'
                '25/01/2024,motor_gasoline_catalyst,50,litre\n'
                '01/02/2024,natural_gas_mj,1500,mj\n'
                '05/02/2024,lpg_kg,25,kg\n'
                '10/02/2024,r134a,2,kg',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                ),
              ),
            ),
            SizedBox(height: 12),
            
            // Guidelines button
            ElevatedButton.icon(
              onPressed: _showTemplateHelp,
              icon: Icon(Icons.help_outline),
              label: Text('View Category Guidelines'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[600],
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadFile() async {
    try {
      setState(() {
        _isUploading = true;
        _uploadStatus = 'Selecting file...';
        _uploadResults.clear();
        _selectedFileName = null;
      });

      // Pick any supported file type
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'xls', 'pdf', 'jpg', 'jpeg', 'png'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        setState(() {
          _isUploading = false;
          _uploadStatus = 'No file selected';
        });
        return;
      }

      PlatformFile file = result.files.first;
      
      setState(() {
        _selectedFileName = file.name;
        _uploadStatus = 'Reading file: ${file.name}';
      });

      // Check file size
      if (file.size > 16 * 1024 * 1024) {
        setState(() {
          _isUploading = false;
          _uploadStatus = 'Error: File too large. Maximum size is 16MB.';
        });
        return;
      }

      // Check if we have file bytes
      if (file.bytes == null) {
        setState(() {
          _isUploading = false;
          _uploadStatus = 'Error: Cannot read file content. Try a different browser or use mobile app.';
        });
        return;
      }

      // Process based on file type
      final extension = file.extension?.toLowerCase();
      
      if (['csv', 'xlsx', 'xls'].contains(extension)) {
        await _processSpreadsheet(file);
      } else if (extension == 'pdf') {
        await _processPDF(file);
      } else if (['jpg', 'jpeg', 'png'].contains(extension)) {
        await _processImage(file);
      } else {
        setState(() {
          _isUploading = false;
          _uploadStatus = 'Error: Unsupported file type: $extension';
        });
      }

    } catch (e) {
      setState(() {
        _isUploading = false;
        _uploadStatus = 'Error: $e';
      });
    }
  }

  Future<void> _processSpreadsheet(PlatformFile file) async {
    try {
      setState(() {
        _uploadStatus = 'Processing spreadsheet...';
      });

      List<List<dynamic>> data;
      
      if (file.extension?.toLowerCase() == 'csv') {
        String csvContent = String.fromCharCodes(file.bytes!);
        data = CsvToListConverter().convert(csvContent);
      } else {
        final excel = Excel.decodeBytes(file.bytes!);
        final sheetName = excel.tables.keys.first;
        final sheet = excel.tables[sheetName]!;
        
        data = [];
        for (int rowIndex = 0; rowIndex < sheet.maxRows; rowIndex++) {
          List<Data?> row = sheet.row(rowIndex);
          List<dynamic> processedRow = [];
          
          for (var cell in row) {
            if (cell?.value != null) {
              processedRow.add(cell!.value.toString());
            } else {
              processedRow.add('');
            }
          }
          
          if (processedRow.any((cell) => cell.toString().trim().isNotEmpty)) {
            data.add(processedRow);
          }
        }
      }

      await _processSpreadsheetData(data);

    } catch (e) {
      setState(() {
        _isUploading = false;
        _uploadStatus = 'Error processing spreadsheet: $e';
      });
    }
  }

  Future<void> _processSpreadsheetData(List<List<dynamic>> data) async {
    if (data.isEmpty) {
      setState(() {
        _isUploading = false;
        _uploadStatus = 'Error: No data found in file';
      });
      return;
    }

    List<String> results = [];
    int successCount = 0;
    int errorCount = 0;

    // Skip header row, process data rows
    for (int i = 1; i < data.length; i++) {
      try {
        List<dynamic> row = data[i];
        
        if (row.length < 4) {
          results.add('Row ${i + 1}: Not enough columns (need at least 4)');
          errorCount++;
          continue;
        }

        String dateStr = row[0].toString().trim();
        String category = row[1].toString().toLowerCase().trim();
        double amount = double.parse(row[2].toString().trim());
        String unit = row[3].toString().toLowerCase().trim();

        DateTime date = DateTime.parse(dateStr);
        
        // Validate category using TGO emission categories
        if (!Constants.emissionCategories.contains(category)) {
          results.add('Row ${i + 1}: Invalid category "$category". Please use TGO categories.');
          errorCount++;
          continue;
        }

        // Validate unit matches category using TGO category units
        if (Constants.categoryUnits[category] != unit) {
          results.add('Row ${i + 1}: Invalid unit "$unit" for category "$category". Expected "${Constants.categoryUnits[category]}"');
          errorCount++;
          continue;
        }

        final apiResult = await ApiService.addEmission(
          category: category,
          amount: amount,
          unit: unit,
          month: date.month,
          year: date.year,
        );

        if (apiResult['success']) {
          final co2 = apiResult['co2_equivalent']?.toStringAsFixed(2) ?? '0';
          results.add('Row ${i + 1}: ✓ Added successfully ($co2 kg CO₂)');
          successCount++;
        } else {
          results.add('Row ${i + 1}: ✗ ${apiResult['message']}');
          errorCount++;
        }

      } catch (e) {
        results.add('Row ${i + 1}: ✗ Error - $e');
        errorCount++;
      }

      setState(() {
        _uploadStatus = 'Processing row ${i + 1} of ${data.length - 1}...';
      });
    }

    setState(() {
      _isUploading = false;
      _uploadStatus = 'Spreadsheet upload completed: $successCount successful, $errorCount failed';
      _uploadResults = results;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Upload completed: $successCount successful, $errorCount failed'),
        backgroundColor: errorCount == 0 ? Colors.green : (successCount > 0 ? Colors.orange : Colors.red),
      ),
    );
  }

  Future<void> _processPDF(PlatformFile file) async {
    setState(() {
      _uploadStatus = 'Sending PDF to server for processing...';
    });

    try {
      // Create a temporary file-like object for the backend
      final result = await _uploadToBackend(file, 'pdf');
      
      setState(() {
        _isUploading = false;
        _uploadStatus = result['success'] 
            ? 'PDF processed successfully: ${result['message']}' 
            : 'PDF processing failed: ${result['message']}';
      });

    } catch (e) {
      setState(() {
        _isUploading = false;
        _uploadStatus = 'Error processing PDF: $e';
      });
    }
  }

  Future<void> _processImage(PlatformFile file) async {
    setState(() {
      _uploadStatus = 'Sending image to server for OCR processing...';
    });

    try {
      // Send image for OCR processing
      final result = await _uploadToBackend(file, 'image');
      
      setState(() {
        _isUploading = false;
        _uploadStatus = result['success'] 
            ? 'OCR processed successfully: ${result['message']}' 
            : 'OCR processing failed: ${result['message']}';
      });

      // Refresh dashboard if successful
      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully extracted ${result['extracted_data']?['usage_kwh'] ?? 'N/A'} kWh from bill'),
            backgroundColor: Colors.green,
          ),
        );
      }

    } catch (e) {
      setState(() {
        _isUploading = false;
        _uploadStatus = 'Error processing image: $e';
      });
    }
  }

  // Helper method to upload files to backend
  Future<Map<String, dynamic>> _uploadToBackend(PlatformFile file, String type) async {
    try {
      final token = await ApiService.getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${Constants.apiUrl}/upload'),
      );

      request.headers['Authorization'] = 'Bearer $token';
      
      // Add file from bytes
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        file.bytes!,
        filename: file.name,
      ));

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();
      var data = jsonDecode(responseBody);

      return {
        'success': response.statusCode == 200,
        'message': data['message'] ?? 'Upload completed',
        'extracted_data': data['extracted_data'],
      };
    } catch (e) {
      return {'success': false, 'message': 'Upload error: $e'};
    }
  }

  // Download Excel template
  void _downloadExcelTemplate() {
    try {
      final excel = Excel.createExcel();
      
      // Remove default sheet and create a new one
      excel.delete('Sheet1');
      Sheet sheet = excel['TGO_Emissions_Template'];
      
      // Get template data
      final templateData = UploadService.generateExcelTemplateData();
      
      // Add data to sheet
      for (int rowIndex = 0; rowIndex < templateData.length; rowIndex++) {
        final row = templateData[rowIndex];
        for (int colIndex = 0; colIndex < row.length; colIndex++) {
          final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: rowIndex));
          
          cell.value = TextCellValue(row[colIndex].toString());
          
          // Style header row
          if (rowIndex == 0) {
            cell.cellStyle = CellStyle(
              fontColorHex: ExcelColor.white,
              backgroundColorHex: ExcelColor.green700,
            );
          }
        }
      }
      
      // Auto-fit columns for 4 columns
      sheet.setColumnWidth(0, 15); // Date column
      sheet.setColumnWidth(1, 30); // Category column (wider for category names)
      sheet.setColumnWidth(2, 12); // Amount column
      sheet.setColumnWidth(3, 12); // Unit column
      
      final bytes = excel.encode();
      if (bytes != null) {
        final blob = html.Blob([bytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        final url = html.Url.createObjectUrlFromBlob(blob);
        
        final anchor = html.AnchorElement(href: url);
        anchor.download = 'tgo_emissions_template.xlsx';
        anchor.click();
          
        html.Url.revokeObjectUrl(url);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Excel template downloaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Failed to encode Excel file');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error downloading Excel template: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showTemplateHelp() {
    final categoryGuide = UploadService.getCategoryGuide();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('TGO Category Guidelines'),
        content: Container(
          width: double.maxFinite,
          height: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TGO Emission Factor Categories',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green[700]),
                ),
                SizedBox(height: 16),
                
                Text(
                  'Format Requirements:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('• Date: DD/MM/YYYY format (e.g., 15/01/2024)'),
                Text('• Category: Use exact category keys from the guide below'),
                Text('• Amount: Numeric value (decimal allowed)'),
                Text('• Unit: Must match the category unit exactly (lowercase)'),
                SizedBox(height: 20),
                
                // Category guide
                ...categoryGuide.entries.map((scopeEntry) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        margin: EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.green[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          scopeEntry.key,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                      ...scopeEntry.value.map((category) {
                        return Padding(
                          padding: EdgeInsets.only(left: 16, bottom: 4),
                          child: Text(
                            '${category['category']} (${category['unit']}) - ${category['description']}',
                            style: TextStyle(fontSize: 12),
                          ),
                        );
                      }).toList(),
                      SizedBox(height: 12),
                    ],
                  );
                }).toList(),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Got it!'),
          ),
        ],
      ),
    );
  }
}
