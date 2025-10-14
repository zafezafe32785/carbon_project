import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import '../services/api_service.dart';
import '../utils/constants.dart';
import 'package:path_provider/path_provider.dart';

class ReportGenerationScreen extends StatefulWidget {
  const ReportGenerationScreen({Key? key}) : super(key: key);

  @override
  State<ReportGenerationScreen> createState() => _ReportGenerationScreenState();
}

class _ReportGenerationScreenState extends State<ReportGenerationScreen> {
  final ApiService _apiService = ApiService();
  
  // Form controllers
  DateTime _startDate = DateTime(DateTime.now().year, 1, 1);
  DateTime _endDate = DateTime.now();
  String _selectedFormat = 'GHG';
  String _selectedFileType = 'PDF';
  String _selectedLanguage = 'EN';
  bool _isGenerating = false;
  
  // Available options
  List<Map<String, String>> _availableFormats = [];
  List<Map<String, String>> _availableFileTypes = [];
  List<Map<String, String>> _availableLanguages = [];
  
  // Preview data
  Map<String, dynamic>? _previewData;
  bool _isLoadingPreview = false;

  @override
  void initState() {
    super.initState();
    _loadAvailableFormats();
    _loadAvailableFileTypes();
    _loadAvailableLanguages();
  }

  Future<void> _loadAvailableFormats() async {
    try {
      final response = await _apiService.get('/reports/formats');
      if (response['success'] == true) {
        setState(() {
          _availableFormats = List<Map<String, String>>.from(
            response['formats'].map((format) => {
              'code': format['code'].toString(),
              'name': format['name'].toString(),
              'description': format['description'].toString(),
            })
          );
          if (_availableFormats.isNotEmpty) {
            _selectedFormat = _availableFormats.first['code']!;
          }
        });
      } else {
        // Fallback to default formats if API fails - GHG only
        setState(() {
          _availableFormats = [
            {
              'code': 'GHG',
              'name': 'GHG',
              'description': 'GHG Protocol Corporate Accounting and Reporting Standard'
            },
          ];
          _selectedFormat = 'GHG';
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to load report formats: $e');
      // Fallback to default formats - GHG only
      setState(() {
        _availableFormats = [
          {
            'code': 'GHG',
            'name': 'GHG',
            'description': 'GHG Protocol Corporate Accounting and Reporting Standard'
          },
        ];
        _selectedFormat = 'GHG';
      });
    }
  }

  Future<void> _loadAvailableFileTypes() async {
    try {
      final response = await _apiService.get('/reports/file-types');
      if (response['success'] == true) {
        setState(() {
          _availableFileTypes = List<Map<String, String>>.from(
            response['file_types'].map((fileType) => {
              'code': fileType['code'].toString(),
              'name': fileType['name'].toString(),
              'description': fileType['description'].toString(),
            })
          );
          if (_availableFileTypes.isNotEmpty) {
            _selectedFileType = _availableFileTypes.first['code']!;
          }
        });
      } else {
        // Fallback to default file types
        setState(() {
          _availableFileTypes = [
            {
              'code': 'PDF',
              'name': 'PDF',
              'description': 'Portable Document Format - Professional report layout'
            },
            {
              'code': 'EXCEL',
              'name': 'Excel',
              'description': 'Microsoft Excel - Data analysis and charts'
            },
            {
              'code': 'WORD',
              'name': 'Word',
              'description': 'Microsoft Word - Editable document format'
            },
          ];
          _selectedFileType = 'PDF';
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to load file types: $e');
      // Fallback to default file types
      setState(() {
        _availableFileTypes = [
          {
            'code': 'PDF',
            'name': 'PDF',
            'description': 'Portable Document Format - Professional report layout'
          },
          {
            'code': 'EXCEL',
            'name': 'Excel',
            'description': 'Microsoft Excel - Data analysis and charts'
          },
          {
            'code': 'WORD',
            'name': 'Word',
            'description': 'Microsoft Word - Editable document format'
          },
        ];
        _selectedFileType = 'PDF';
      });
    }
  }

  Future<void> _loadAvailableLanguages() async {
    try {
      final response = await _apiService.get('/reports/languages');
      if (response['success'] == true) {
        setState(() {
          _availableLanguages = List<Map<String, String>>.from(
            response['languages'].map((language) => {
              'code': language['code'].toString(),
              'name': language['name'].toString(),
              'description': language['description'].toString(),
            })
          );
          if (_availableLanguages.isNotEmpty) {
            _selectedLanguage = _availableLanguages.first['code']!;
          }
        });
      } else {
        // Fallback to default languages
        setState(() {
          _availableLanguages = [
            {
              'code': 'EN',
              'name': 'English',
              'description': 'English - International standard language'
            },
            {
              'code': 'TH',
              'name': 'ภาษาไทย',
              'description': 'Thai - ภาษาไทย สำหรับรายงานในประเทศไทย'
            },
          ];
          _selectedLanguage = 'EN';
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to load languages: $e');
      // Fallback to default languages
      setState(() {
        _availableLanguages = [
          {
            'code': 'EN',
            'name': 'English',
            'description': 'English - International standard language'
          },
          {
            'code': 'TH',
            'name': 'ภาษาไทย',
            'description': 'Thai - ภาษาไทย สำหรับรายงานในประเทศไทย'
          },
        ];
        _selectedLanguage = 'EN';
      });
    }
  }


  Future<void> _previewReportData() async {
    setState(() {
      _isLoadingPreview = true;
      _previewData = null;
    });

    try {
      final requestData = {
        'start_date': _startDate.toIso8601String(),
        'end_date': _endDate.toIso8601String(),
        'report_format': _selectedFormat,
      };

      final response = await _apiService.post('/reports/preview', requestData);
      
      if (response['success'] == true) {
        setState(() {
          _previewData = response['preview'];
        });
      } else {
        _showErrorSnackBar(response['message'] ?? 'Failed to preview report data');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to preview report: $e');
    } finally {
      setState(() {
        _isLoadingPreview = false;
      });
    }
  }

  Future<void> _generateReport() async {
    if (_previewData == null) {
      _showErrorSnackBar('Please preview the report data first');
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      final requestData = {
        'start_date': _startDate.toIso8601String(),
        'end_date': _endDate.toIso8601String(),
        'report_format': _selectedFormat,
        'file_type': _selectedFileType,
        'language': _selectedLanguage,
        'include_ai_insights': true,
      };

      final response = await _apiService.post('/reports/generate-ai', requestData);
      
      if (response['success'] == true) {
        _showSuccessSnackBar('Report generated successfully!');

        // Directly show download dialog
        _downloadReport(response['report_id']);
      } else {
        _showErrorSnackBar(response['message'] ?? 'Failed to generate report');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to generate report: $e');
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  Future<void> _downloadReport(String reportId) async {
    try {
      _showInfoSnackBar('Preparing download...');
      
      // First get download info
      final response = await _apiService.get('/reports/download/$reportId?info=true');
      
      if (response['success'] == true) {
        final fileUrl = response['download_url'];
        final fileName = response['file_name'] ?? 'report.pdf';
        
        // Show download dialog with file information
        _showDownloadDialog(reportId, fileName, fileUrl);
      } else {
        _showErrorSnackBar(response['message'] ?? 'Failed to prepare download');
      }
    } catch (e) {
      _showErrorSnackBar('Download preparation failed: $e');
    }
  }

  void _showDownloadDialog(String reportId, String fileName, String fileUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Download Report'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Report ID: $reportId'),
              const SizedBox(height: 8),
              Text('File Name: $fileName'),
              const SizedBox(height: 8),
              const Text('The report is ready for download.'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  border: Border.all(color: Colors.blue.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'The file will be downloaded to your device\'s default download location.',
                        style: TextStyle(fontSize: 12, color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _performDownload(fileUrl, fileName);
              },
              icon: const Icon(Icons.download),
              label: const Text('Download'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Constants.primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performDownload(String fileUrl, String fileName) async {
    try {
      _showInfoSnackBar('Starting download...');

      final token = await ApiService.getToken();
      final response = await http.get(
        Uri.parse(fileUrl),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        // Get the Downloads directory
        Directory? downloadsDirectory;

        if (Platform.isAndroid) {
          downloadsDirectory = Directory('/storage/emulated/0/Download');
          if (!await downloadsDirectory.exists()) {
            downloadsDirectory = await getExternalStorageDirectory();
          }
        } else if (Platform.isIOS) {
          downloadsDirectory = await getApplicationDocumentsDirectory();
        } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
          downloadsDirectory = await getDownloadsDirectory();
        }

        if (downloadsDirectory == null) {
          _showErrorSnackBar('Could not access downloads directory');
          return;
        }

        // Create the file path
        final filePath = '${downloadsDirectory.path}/$fileName';
        final file = File(filePath);

        // Write the file
        await file.writeAsBytes(response.bodyBytes);

        // Show success dialog with file path
        _showDownloadSuccessDialog(fileName, response.bodyBytes.length, filePath);
      } else {
        _showErrorSnackBar('Download failed: Server returned ${response.statusCode}');
      }
    } catch (e) {
      _showErrorSnackBar('Download failed: $e');
    }
  }

  void _showDownloadSuccessDialog(String fileName, int fileSize, String filePath) {
    final fileSizeKB = (fileSize / 1024).toStringAsFixed(1);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Download Complete'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('File: $fileName'),
              const SizedBox(height: 4),
              Text('Size: $fileSizeKB KB'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border.all(color: Colors.green.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.folder, color: Colors.green, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'File Location',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      filePath,
                      style: const TextStyle(fontSize: 11, color: Colors.green),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generate Reports'),
        backgroundColor: Constants.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Report Configuration Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Report Configuration',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Date Range Selection
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Start Date'),
                              const SizedBox(height: 4),
                              InkWell(
                                onTap: () async {
                                  final date = await showDatePicker(
                                    context: context,
                                    initialDate: _startDate,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime.now(),
                                  );
                                  if (date != null) {
                                    setState(() {
                                      _startDate = date;
                                      _previewData = null; // Reset preview
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${_startDate.day}/${_startDate.month}/${_startDate.year}',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('End Date'),
                              const SizedBox(height: 4),
                              InkWell(
                                onTap: () async {
                                  final date = await showDatePicker(
                                    context: context,
                                    initialDate: _endDate,
                                    firstDate: _startDate,
                                    lastDate: DateTime.now(),
                                  );
                                  if (date != null) {
                                    setState(() {
                                      _endDate = date;
                                      _previewData = null; // Reset preview
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${_endDate.day}/${_endDate.month}/${_endDate.year}',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Report Format Selection
                    const Text('Report Format'),
                    const SizedBox(height: 4),
                    _availableFormats.isEmpty
                        ? Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                SizedBox(width: 8),
                                Text('Loading formats...'),
                              ],
                            ),
                          )
                        : DropdownButtonFormField<String>(
                            value: _availableFormats.any((format) => format['code'] == _selectedFormat) 
                                ? _selectedFormat 
                                : _availableFormats.first['code'],
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                            ),
                            items: _availableFormats.map((format) {
                              return DropdownMenuItem<String>(
                                value: format['code'],
                                child: Container(
                                  constraints: const BoxConstraints(maxHeight: 60),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        format['name']!,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      const SizedBox(height: 2),
                                      Flexible(
                                        child: Text(
                                          format['description']!,
                                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _selectedFormat = value;
                                  _previewData = null; // Reset preview
                                });
                              }
                            },
                          ),
                    
                    const SizedBox(height: 16),
                    
                    // File Type Selection
                    const Text('File Type'),
                    const SizedBox(height: 4),
                    _availableFileTypes.isEmpty
                        ? Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                SizedBox(width: 8),
                                Text('Loading file types...'),
                              ],
                            ),
                          )
                        : DropdownButtonFormField<String>(
                            value: _availableFileTypes.any((fileType) => fileType['code'] == _selectedFileType) 
                                ? _selectedFileType 
                                : _availableFileTypes.first['code'],
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                            ),
                            items: _availableFileTypes.map((fileType) {
                              return DropdownMenuItem<String>(
                                value: fileType['code'],
                                child: Container(
                                  constraints: const BoxConstraints(maxHeight: 60),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        fileType['name']!,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      const SizedBox(height: 2),
                                      Flexible(
                                        child: Text(
                                          fileType['description']!,
                                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _selectedFileType = value;
                                });
                              }
                            },
                          ),
                    
                    const SizedBox(height: 16),
                    
                    // Language Selection
                    const Text('Language'),
                    const SizedBox(height: 4),
                    _availableLanguages.isEmpty
                        ? Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                SizedBox(width: 8),
                                Text('Loading languages...'),
                              ],
                            ),
                          )
                        : DropdownButtonFormField<String>(
                            value: _availableLanguages.any((language) => language['code'] == _selectedLanguage) 
                                ? _selectedLanguage 
                                : _availableLanguages.first['code'],
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                            ),
                            items: _availableLanguages.map((language) {
                              return DropdownMenuItem<String>(
                                value: language['code'],
                                child: Container(
                                  constraints: const BoxConstraints(maxHeight: 60),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        language['name']!,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      const SizedBox(height: 2),
                                      Flexible(
                                        child: Text(
                                          language['description']!,
                                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _selectedLanguage = value;
                                });
                              }
                            },
                          ),
                    
                    const SizedBox(height: 16),
                    
                    // AI Insights Info (Always Enabled)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        border: Border.all(color: Colors.green.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.auto_awesome, color: Colors.green),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'AI Insights Enabled',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                                Text(
                                  'All reports include AI-powered analysis and recommendations',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Preview Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoadingPreview ? null : _previewReportData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Constants.primaryColor,
                          foregroundColor: Colors.white,
                        ),
                        child: _isLoadingPreview
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text('Loading Preview...'),
                                ],
                              )
                            : const Text('Preview Report Data'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Preview Data Card
            if (_previewData != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Report Preview',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      _buildPreviewItem('Period', _previewData!['period']),
                      _buildPreviewItem('Total Emissions', '${_previewData!['total_emissions']} kg CO2e'),
                      _buildPreviewItem('Records Count', '${_previewData!['record_count']} records'),
                      _buildPreviewItem('Organization', _previewData!['organization']),
                      
                      const SizedBox(height: 16),
                      
                      // Emissions by Category
                      if (_previewData!['emissions_by_category'] != null) ...[
                        const Text(
                          'Emissions by Category:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        ..._previewData!['emissions_by_category'].entries.map<Widget>((entry) {
                          return Padding(
                            padding: const EdgeInsets.only(left: 16, bottom: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(entry.key.toString().toUpperCase()),
                                Text('${entry.value.toStringAsFixed(2)} kg CO2e'),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                      
                      const SizedBox(height: 16),
                      
                      // Emissions by Scope
                      if (_previewData!['emissions_by_scope'] != null) ...[
                        const Text(
                          'Emissions by Scope:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        ..._previewData!['emissions_by_scope'].entries.map<Widget>((entry) {
                          if (entry.value > 0) {
                            return Padding(
                              padding: const EdgeInsets.only(left: 16, bottom: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(entry.key.toString()),
                                  Text('${entry.value.toStringAsFixed(2)} kg CO2e'),
                                ],
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        }).toList(),
                      ],
                      
                      const SizedBox(height: 16),
                      
                      // Generate Report Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isGenerating ? null : _generateReport,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isGenerating
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Text('Generating Report...'),
                                  ],
                                )
                              : const Text(
                                  'Generate AI Report',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}
