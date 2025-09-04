import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
// import 'package:flutter/foundation.dart';
// import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import '../services/api_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

class UploadDataScreen extends StatefulWidget {
  @override
  _UploadDataScreenState createState() => _UploadDataScreenState();
}

class _UploadDataScreenState extends State<UploadDataScreen> {
  bool _isUploading = false;
  String _uploadStatus = '';
  List<String> _uploadResults = [];
  String? _selectedFileName;


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Upload Data'),
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
                  'Supported File Types',
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
                    'Spreadsheets',
                    'CSV, Excel (.xlsx, .xls)',
                    'Bulk emission data import',
                    Colors.green,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildFileTypeInfo(
                    Icons.picture_as_pdf,
                    'PDF Documents',
                    'Utility bills',
                    'Automatic data extraction',
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
                    'Images',
                    'JPG, PNG photos',
                    'OCR text recognition',
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
                          'File Size Limit',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.orange[700],
                          ),
                        ),
                        Text(
                          'Maximum 16 MB',
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
                'Processing File...',
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
                'Upload Your Files',
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.green[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'CSV • Excel • PDF • Images',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.green[600],
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Tap to select files (max 16MB)',
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
                  isSuccess ? 'Upload Status' : 'Upload Failed',
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
                'Details:',
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
            Text(
              'CSV/Excel Template',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Use this format for spreadsheet uploads:',
              style: TextStyle(color: Colors.grey[700]),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'date,category,amount,unit,description\n'
                '2024-01-15,electricity,500,kWh,Office electricity\n'
                '2024-01-20,transport,150,km,Business travel\n'
                '2024-01-25,diesel,100,liter,Generator fuel\n'
                '2024-02-01,natural_gas,50,cubic_meter,Heating\n'
                '2024-02-05,waste,25,kg,Office waste',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                ),
              ),
            ),
            SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _showTemplateHelp,
              icon: Icon(Icons.help_outline),
              label: Text('View Upload Guidelines'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
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
        
        List<String> validCategories = ['electricity', 'diesel', 'gasoline', 'natural_gas', 'waste', 'transport'];
        if (!validCategories.contains(category)) {
          results.add('Row ${i + 1}: Invalid category "$category"');
          errorCount++;
          continue;
        }

        Map<String, String> validUnits = {
          'electricity': 'kwh',
          'diesel': 'liter',
          'gasoline': 'liter',
          'natural_gas': 'cubic_meter',
          'waste': 'kg',
          'transport': 'km',
        };
        
        if (validUnits[category] != unit) {
          results.add('Row ${i + 1}: Invalid unit "$unit" for category "$category"');
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

  void _showTemplateHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Upload Guidelines'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Spreadsheet Format:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('• Required columns: date, category, amount, unit'),
              Text('• Date format: YYYY-MM-DD (e.g., 2024-01-15)'),
              Text('• Categories: electricity, diesel, gasoline, natural_gas, waste, transport'),
              Text('• Units must match categories (kWh, liter, cubic_meter, kg, km)'),
              SizedBox(height: 16),
              
              Text('PDF Documents:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('• Upload utility bills for automatic processing'),
              Text('• Clear, readable text works best'),
              SizedBox(height: 16),
              
              Text('Images:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('• Take clear photos of electricity bills'),
              Text('• Good lighting and focus important'),
              Text('• Supports Thai electricity bills (MEA/PEA)'),
              SizedBox(height: 16),
              
              Text('File Limits:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('• Maximum file size: 16 MB'),
              Text('• Supported: CSV, Excel, PDF, JPG, PNG'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Got it'),
          ),
        ],
      ),
    );
  }
}

