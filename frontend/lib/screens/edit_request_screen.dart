import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/localization_service.dart';

class EditRequestScreen extends StatefulWidget {
  const EditRequestScreen({super.key});

  @override
  _EditRequestScreenState createState() => _EditRequestScreenState();
}

class _EditRequestScreenState extends State<EditRequestScreen>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> _emissionRecords = [];
  List<Map<String, dynamic>> _userRequests = [];
  List<Map<String, dynamic>> _filteredRecords = [];
  List<Map<String, dynamic>> _filteredRequests = [];
  
  bool _isLoading = true;
  bool _isSubmittingRequest = false;
  
  late TabController _tabController;
  late TextEditingController _searchController;
  
  // Filter and sort options
  String _recordSortBy = 'date'; // date, category, amount
  bool _recordSortAscending = false;
  String _requestFilterStatus = 'all'; // all, pending, approved, rejected
  String _requestSortBy = 'date'; // date, type, status

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController = TextEditingController();
    _searchController.addListener(_onSearchChanged);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _filterAndSortData();
  }

  void _filterAndSortData() {
    final query = _searchController.text.toLowerCase();
    
    // Filter records
    _filteredRecords = _emissionRecords.where((record) {
      if (query.isEmpty) return true;
      return record['category'].toString().toLowerCase().contains(query) ||
             record['unit'].toString().toLowerCase().contains(query);
    }).toList();
    
    // Sort records
    _filteredRecords.sort((a, b) {
      int comparison = 0;
      switch (_recordSortBy) {
        case 'date':
          final dateA = DateTime(a['year'], a['month']);
          final dateB = DateTime(b['year'], b['month']);
          comparison = dateA.compareTo(dateB);
          break;
        case 'category':
          comparison = a['category'].compareTo(b['category']);
          break;
        case 'amount':
          comparison = (a['co2_equivalent'] as double).compareTo(b['co2_equivalent'] as double);
          break;
      }
      return _recordSortAscending ? comparison : -comparison;
    });
    
    // Filter requests
    _filteredRequests = _userRequests.where((request) {
      bool statusMatch = _requestFilterStatus == 'all' || 
                        request['status'] == _requestFilterStatus;
      bool queryMatch = query.isEmpty ||
                       request['request_type'].toString().toLowerCase().contains(query) ||
                       request['reason'].toString().toLowerCase().contains(query);
      return statusMatch && queryMatch;
    }).toList();
    
    // Sort requests by date (newest first)
    _filteredRequests.sort((a, b) {
      final dateA = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime.now();
      final dateB = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime.now();
      return dateB.compareTo(dateA);
    });
    
    setState(() {});
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final emissionsResult = await ApiService.getEmissions();
      final requestsResult = await ApiService.getEditRequests();
      
      if (mounted) {
        setState(() {
          if (emissionsResult['success']) {
            _emissionRecords = List<Map<String, dynamic>>.from(
              emissionsResult['data']['emissions'] ?? []
            );
          }
          
          if (requestsResult['success']) {
            _userRequests = List<Map<String, dynamic>>.from(
              requestsResult['data']['requests'] ?? []
            );
          }
          
          _isLoading = false;
        });
        
        _filterAndSortData();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorMessage('Failed to load data: $e');
      }
    }
  }

  void _showErrorMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.red[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _showSuccessMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.green[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _submitRequest({
    required String recordId,
    required String requestType,
    required String reason,
    Map<String, dynamic>? proposedChanges,
  }) async {
    setState(() => _isSubmittingRequest = true);
    
    try {
      final result = await ApiService.createEditRequest(
        recordId: recordId,
        requestType: requestType,
        reason: reason,
        proposedChanges: proposedChanges,
      );
      
      if (mounted) {
        setState(() => _isSubmittingRequest = false);
        
        if (result['success']) {
          _showSuccessMessage(result['message']);
          await _loadData(); // Refresh data
        } else {
          _showErrorMessage(result['message']);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmittingRequest = false);
        _showErrorMessage('Failed to submit request: $e');
      }
    }
  }

  void _showAdvancedEditDialog(Map<String, dynamic> record) {
    final localization = Provider.of<LocalizationService>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (context) => _AdvancedEditDialog(
        record: record,
        localization: localization,
        onSubmit: _submitRequest,
        isLoading: _isSubmittingRequest,
      ),
    );
  }

  void _showAdvancedDeleteDialog(Map<String, dynamic> record) {
    final localization = Provider.of<LocalizationService>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (context) => _AdvancedDeleteDialog(
        record: record,
        localization: localization,
        onSubmit: _submitRequest,
        isLoading: _isSubmittingRequest,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LocalizationService>(
      builder: (context, localization, child) {
        return Scaffold(
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  expandedHeight: 200,
                  floating: false,
                  pinned: true,
                  backgroundColor: Colors.green[700],
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(
                      localization.isThaiLanguage
                          ? 'จัดการคำขอ'
                          : 'Manage Requests',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.green[700]!,
                            Colors.green[800]!,
                          ],
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            right: -50,
                            top: -50,
                            child: Container(
                              width: 200,
                              height: 200,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.1),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 20,
                            top: 40,
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.05),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _TabBarDelegate(
                    TabBar(
                      controller: _tabController,
                      indicatorColor: Colors.green[600],
                      labelColor: Colors.green[700],
                      unselectedLabelColor: Colors.grey[600],
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                      tabs: [
                        Tab(
                          icon: const Icon(Icons.assessment),
                          text: localization.isThaiLanguage
                              ? 'ข้อมูลการปล่อย'
                              : 'Emission Records',
                        ),
                        Tab(
                          icon: const Icon(Icons.list_alt),
                          text: localization.isThaiLanguage
                              ? 'คำขอของฉัน'
                              : 'My Requests',
                        ),
                      ],
                    ),
                  ),
                ),
              ];
            },
            body: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      // Search and filter bar
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(16),
                          ),
                        ),
                        child: _buildSearchAndFilters(localization),
                      ),
                      // Tab content
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildEnhancedEmissionRecordsTab(localization),
                            _buildEnhancedMyRequestsTab(localization),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          floatingActionButton: _tabController.index == 0 && _filteredRecords.isNotEmpty
              ? FloatingActionButton(
                  onPressed: () => _showBulkActionsDialog(localization),
                  backgroundColor: Colors.green[600],
                  child: const Icon(Icons.checklist, color: Colors.white),
                )
              : null,
        );
      },
    );
  }

  Widget _buildSearchAndFilters(LocalizationService localization) {
    return Column(
      children: [
        // Search bar
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: localization.isThaiLanguage
                ? 'ค้นหาข้อมูล...'
                : 'Search data...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.green[600]!),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        
        // Filter chips
        Row(
          children: [
            if (_tabController.index == 0) ...[
              _buildSortChip(
                localization.isThaiLanguage ? 'เรียง: วันที่' : 'Sort: Date',
                _recordSortBy == 'date',
                () => setState(() {
                  _recordSortBy = 'date';
                  _filterAndSortData();
                }),
              ),
              const SizedBox(width: 8),
              _buildSortChip(
                localization.isThaiLanguage ? 'เรียง: ประเภท' : 'Sort: Category',
                _recordSortBy == 'category',
                () => setState(() {
                  _recordSortBy = 'category';
                  _filterAndSortData();
                }),
              ),
              const SizedBox(width: 8),
              _buildSortChip(
                localization.isThaiLanguage ? 'เรียง: ปริมาณ' : 'Sort: Amount',
                _recordSortBy == 'amount',
                () => setState(() {
                  _recordSortBy = 'amount';
                  _filterAndSortData();
                }),
              ),
            ] else ...[
              _buildFilterChip(
                localization.isThaiLanguage ? 'ทั้งหมด' : 'All',
                _requestFilterStatus == 'all',
                () => setState(() {
                  _requestFilterStatus = 'all';
                  _filterAndSortData();
                }),
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                localization.isThaiLanguage ? 'รอดำเนินการ' : 'Pending',
                _requestFilterStatus == 'pending',
                () => setState(() {
                  _requestFilterStatus = 'pending';
                  _filterAndSortData();
                }),
                color: Colors.orange,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                localization.isThaiLanguage ? 'อนุมัติ' : 'Approved',
                _requestFilterStatus == 'approved',
                () => setState(() {
                  _requestFilterStatus = 'approved';
                  _filterAndSortData();
                }),
                color: Colors.green,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                localization.isThaiLanguage ? 'ปฏิเสธ' : 'Rejected',
                _requestFilterStatus == 'rejected',
                () => setState(() {
                  _requestFilterStatus = 'rejected';
                  _filterAndSortData();
                }),
                color: Colors.red,
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildSortChip(String label, bool isSelected, VoidCallback onTap) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: Colors.green[100],
      checkmarkColor: Colors.green[700],
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap,
      {Color? color}) {
    final materialColor = _getMaterialColor(color ?? Colors.green);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: materialColor[100],
      checkmarkColor: materialColor[700],
    );
  }

  MaterialColor _getMaterialColor(Color color) {
    if (color == Colors.orange) return Colors.orange;
    if (color == Colors.red) return Colors.red;
    if (color == Colors.blue) return Colors.blue;
    return Colors.green; // default
  }

  Widget _buildEnhancedEmissionRecordsTab(LocalizationService localization) {
    if (_filteredRecords.isEmpty) {
      return _buildEmptyState(
        icon: Icons.assessment_outlined,
        title: localization.isThaiLanguage
            ? (_searchController.text.isNotEmpty ? 'ไม่พบข้อมูลที่ค้นหา' : 'ไม่มีข้อมูลการปล่อย')
            : (_searchController.text.isNotEmpty ? 'No search results' : 'No emission records found'),
        subtitle: localization.isThaiLanguage
            ? (_searchController.text.isNotEmpty ? 'ลองเปลี่ยนคำค้นหา' : 'เพิ่มข้อมูลการปล่อยก่อนเพื่อขอแก้ไข/ลบ')
            : (_searchController.text.isNotEmpty ? 'Try different search terms' : 'Add emission records first to request edits/deletes'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredRecords.length,
      itemBuilder: (context, index) {
        final record = _filteredRecords[index];
        return _buildEnhancedRecordCard(record, localization);
      },
    );
  }

  Widget _buildEnhancedMyRequestsTab(LocalizationService localization) {
    if (_filteredRequests.isEmpty) {
      return _buildEmptyState(
        icon: Icons.list_alt_outlined,
        title: localization.isThaiLanguage
            ? (_searchController.text.isNotEmpty ? 'ไม่พบคำขอที่ค้นหา' : 'ไม่มีคำขอ')
            : (_searchController.text.isNotEmpty ? 'No matching requests' : 'No requests found'),
        subtitle: localization.isThaiLanguage
            ? (_searchController.text.isNotEmpty ? 'ลองเปลี่ยนคำค้นหาหรือตัวกรอง' : 'คำขอแก้ไข/ลบข้อมูลจะแสดงที่นี่')
            : (_searchController.text.isNotEmpty ? 'Try different search terms or filters' : 'Your edit/delete requests will appear here'),
      );
    }

    // Add summary stats
    return Column(
      children: [
        _buildRequestSummary(localization),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _filteredRequests.length,
            itemBuilder: (context, index) {
              final request = _filteredRequests[index];
              return _buildEnhancedRequestCard(request, localization);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedRecordCard(
      Map<String, dynamic> record, LocalizationService localization) {
    final hasPendingRequest = _userRequests.any(
      (request) =>
          request['record_id'] == record['record_id'] &&
          request['status'] == 'pending',
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: hasPendingRequest
            ? null
            : () => _showRecordDetailsDialog(record, localization),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.eco,
                      color: Colors.green[700],
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record['category'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${record['amount']} ${record['unit']}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!hasPendingRequest)
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _showAdvancedEditDialog(record);
                        } else if (value == 'delete') {
                          _showAdvancedDeleteDialog(record);
                        }
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, color: Colors.blue[600], size: 20),
                              const SizedBox(width: 8),
                              Text(
                                localization.isThaiLanguage ? 'ขอแก้ไข' : 'Request Edit',
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red[600], size: 20),
                              const SizedBox(width: 8),
                              Text(
                                localization.isThaiLanguage ? 'ขอลบ' : 'Request Delete',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildInfoChip(
                    '${record['month']}/${record['year']}',
                    Icons.calendar_today,
                    Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  _buildInfoChip(
                    '${record['co2_equivalent']?.toStringAsFixed(2)} kg CO₂e',
                    Icons.cloud,
                    Colors.orange,
                  ),
                  if (hasPendingRequest) ...[
                    const SizedBox(width: 8),
                    _buildInfoChip(
                      localization.isThaiLanguage ? 'มีคำขอรอดำเนินการ' : 'Pending Request',
                      Icons.schedule,
                      Colors.orange,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestSummary(LocalizationService localization) {
    final pending = _userRequests.where((r) => r['status'] == 'pending').length;
    final approved = _userRequests.where((r) => r['status'] == 'approved').length;
    final rejected = _userRequests.where((r) => r['status'] == 'rejected').length;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryItem(
              localization.isThaiLanguage ? 'รอดำเนินการ' : 'Pending',
              pending.toString(),
              Colors.orange,
              Icons.schedule,
            ),
          ),
          Container(width: 1, height: 40, color: Colors.grey[300]),
          Expanded(
            child: _buildSummaryItem(
              localization.isThaiLanguage ? 'อนุมัติ' : 'Approved',
              approved.toString(),
              Colors.green,
              Icons.check_circle,
            ),
          ),
          Container(width: 1, height: 40, color: Colors.grey[300]),
          Expanded(
            child: _buildSummaryItem(
              localization.isThaiLanguage ? 'ปฏิเสธ' : 'Rejected',
              rejected.toString(),
              Colors.red,
              Icons.cancel,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String count, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          count,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildEnhancedRequestCard(
      Map<String, dynamic> request, LocalizationService localization) {
    final isEdit = request['request_type'] == 'edit';
    final status = request['status'] ?? 'pending';
    
    Color statusColor = Colors.orange;
    IconData statusIcon = Icons.schedule;
    
    switch (status) {
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.schedule;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isEdit ? Colors.blue[100] : Colors.red[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isEdit ? Icons.edit : Icons.delete,
            color: isEdit ? Colors.blue[600] : Colors.red[600],
            size: 20,
          ),
        ),
        title: Text(
          localization.isThaiLanguage
              ? (isEdit ? 'คำขอแก้ไขข้อมูล' : 'คำขอลบข้อมูล')
              : (isEdit ? 'Edit Request' : 'Delete Request'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Row(
          children: [
            Icon(statusIcon, size: 16, color: statusColor),
            const SizedBox(width: 4),
            Text(
              localization.isThaiLanguage
                  ? (status == 'pending' ? 'รอดำเนินการ' : 
                     status == 'approved' ? 'อนุมัติแล้ว' : 'ปฏิเสธ')
                  : status.toUpperCase(),
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (request['original_data'] != null) ...[
                  _buildDataContainer(
                    localization.isThaiLanguage ? 'ข้อมูลเดิม:' : 'Original Data:',
                    request['original_data'],
                    Colors.grey[100]!,
                  ),
                  const SizedBox(height: 12),
                ],
                
                if (isEdit && request['proposed_changes'] != null) ...[
                  _buildDataContainer(
                    localization.isThaiLanguage ? 'ข้อมูลใหม่ที่เสนอ:' : 'Proposed Changes:',
                    request['proposed_changes'],
                    Colors.blue[50]!,
                  ),
                  const SizedBox(height: 12),
                ],
                
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.yellow[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localization.isThaiLanguage ? 'เหตุผล:' : 'Reason:',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(request['reason'] ?? ''),
                    ],
                  ),
                ),
                
                if (request['admin_notes'] != null || request['rejection_reason'] != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: status == 'approved' ? Colors.green[50] : Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localization.isThaiLanguage
                              ? 'หมายเหตุจากผู้ดูแลระบบ:'
                              : 'Admin Notes:',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(request['admin_notes'] ?? request['rejection_reason'] ?? ''),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataContainer(String title, Map<String, dynamic> data, Color backgroundColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Category: ${data['category']}'),
          Text('Amount: ${data['amount']} ${data['unit']}'),
          Text('Period: ${data['month']}/${data['year']}'),
          if (data['co2_equivalent'] != null)
            Text('CO₂e: ${data['co2_equivalent']?.toStringAsFixed(2)} kg'),
        ],
      ),
    );
  }

  void _showRecordDetailsDialog(Map<String, dynamic> record, LocalizationService localization) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          localization.isThaiLanguage ? 'รายละเอียดข้อมูล' : 'Record Details',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow(
              localization.isThaiLanguage ? 'ประเภท:' : 'Category:',
              record['category'],
            ),
            _buildDetailRow(
              localization.isThaiLanguage ? 'ปริมาณ:' : 'Amount:',
              '${record['amount']} ${record['unit']}',
            ),
            _buildDetailRow(
              localization.isThaiLanguage ? 'ช่วงเวลา:' : 'Period:',
              '${record['month']}/${record['year']}',
            ),
            _buildDetailRow(
              'CO₂e:',
              '${record['co2_equivalent']?.toStringAsFixed(2)} kg',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(localization.isThaiLanguage ? 'ปิด' : 'Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showAdvancedEditDialog(record);
            },
            child: Text(localization.isThaiLanguage ? 'แก้ไข' : 'Edit'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showBulkActionsDialog(LocalizationService localization) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          localization.isThaiLanguage ? 'การดำเนินการแบบกลุ่ม' : 'Bulk Actions',
        ),
        content: Text(
          localization.isThaiLanguage
              ? 'ฟีเจอร์นี้จะพร้อมใช้งานในเวอร์ชั่นถัดไป'
              : 'This feature will be available in the next version',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(localization.isThaiLanguage ? 'ปิด' : 'Close'),
          ),
        ],
      ),
    );
  }
}

class _AdvancedEditDialog extends StatefulWidget {
  final Map<String, dynamic> record;
  final LocalizationService localization;
  final Future<void> Function({
    required String recordId,
    required String requestType,
    required String reason,
    Map<String, dynamic>? proposedChanges,
  }) onSubmit;
  final bool isLoading;

  const _AdvancedEditDialog({
    required this.record,
    required this.localization,
    required this.onSubmit,
    required this.isLoading,
  });

  @override
  _AdvancedEditDialogState createState() => _AdvancedEditDialogState();
}

class _AdvancedEditDialogState extends State<_AdvancedEditDialog> {
  late TextEditingController _reasonController;
  late TextEditingController _categoryController;
  late TextEditingController _amountController;
  late TextEditingController _unitController;
  late TextEditingController _monthController;
  late TextEditingController _yearController;

  @override
  void initState() {
    super.initState();
    _reasonController = TextEditingController();
    _categoryController = TextEditingController(text: widget.record['category']);
    _amountController = TextEditingController(text: widget.record['amount'].toString());
    _unitController = TextEditingController(text: widget.record['unit']);
    _monthController = TextEditingController(text: widget.record['month'].toString());
    _yearController = TextEditingController(text: widget.record['year'].toString());
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _categoryController.dispose();
    _amountController.dispose();
    _unitController.dispose();
    _monthController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.edit, color: Colors.blue[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.localization.isThaiLanguage ? 'ขอแก้ไขข้อมูล' : 'Request Edit',
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.localization.isThaiLanguage ? 'ข้อมูลเดิม:' : 'Original data:',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text('${widget.record['category']} - ${widget.record['amount']} ${widget.record['unit']}'),
                  Text('${widget.record['month']}/${widget.record['year']} - ${widget.record['co2_equivalent']?.toStringAsFixed(2)} kg CO₂e'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            Text(
              widget.localization.isThaiLanguage ? 'ข้อมูลใหม่ที่ต้องการ:' : 'Proposed changes:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            
            TextField(
              controller: _categoryController,
              decoration: InputDecoration(
                labelText: widget.localization.isThaiLanguage ? 'ประเภทการปล่อย' : 'Category',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: widget.localization.isThaiLanguage ? 'ปริมาณ' : 'Amount',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _unitController,
                    decoration: InputDecoration(
                      labelText: widget.localization.isThaiLanguage ? 'หน่วย' : 'Unit',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _monthController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: widget.localization.isThaiLanguage ? 'เดือน' : 'Month',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _yearController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: widget.localization.isThaiLanguage ? 'ปี' : 'Year',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            TextField(
              controller: _reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: widget.localization.isThaiLanguage ? 'เหตุผลในการขอแก้ไข *' : 'Reason for edit *',
                hintText: widget.localization.isThaiLanguage
                    ? 'เช่น: ป้อนข้อมูลผิดพลาด, ข้อมูลไม่ถูกต้อง'
                    : 'e.g., Wrong input, Incorrect data',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.localization.isThaiLanguage ? 'ยกเลิก' : 'Cancel'),
        ),
        ElevatedButton(
          onPressed: widget.isLoading
              ? null
              : () {
                  final reason = _reasonController.text.trim();
                  if (reason.isNotEmpty) {
                    final proposedChanges = {
                      'category': _categoryController.text.trim(),
                      'amount': double.tryParse(_amountController.text.trim()) ?? widget.record['amount'],
                      'unit': _unitController.text.trim(),
                      'month': int.tryParse(_monthController.text.trim()) ?? widget.record['month'],
                      'year': int.tryParse(_yearController.text.trim()) ?? widget.record['year'],
                    };
                    
                    Navigator.of(context).pop();
                    widget.onSubmit(
                      recordId: widget.record['record_id'],
                      requestType: 'edit',
                      reason: reason,
                      proposedChanges: proposedChanges,
                    );
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          child: widget.isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(widget.localization.isThaiLanguage ? 'ส่งคำขอแก้ไข' : 'Submit Edit Request'),
        ),
      ],
    );
  }
}

class _AdvancedDeleteDialog extends StatefulWidget {
  final Map<String, dynamic> record;
  final LocalizationService localization;
  final Future<void> Function({
    required String recordId,
    required String requestType,
    required String reason,
    Map<String, dynamic>? proposedChanges,
  }) onSubmit;
  final bool isLoading;

  const _AdvancedDeleteDialog({
    required this.record,
    required this.localization,
    required this.onSubmit,
    required this.isLoading,
  });

  @override
  _AdvancedDeleteDialogState createState() => _AdvancedDeleteDialogState();
}

class _AdvancedDeleteDialogState extends State<_AdvancedDeleteDialog> {
  late TextEditingController _reasonController;

  @override
  void initState() {
    super.initState();
    _reasonController = TextEditingController();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.delete, color: Colors.red[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.localization.isThaiLanguage ? 'ขอลบข้อมูล' : 'Request Delete',
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red[600], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      widget.localization.isThaiLanguage ? 'ข้อมูลที่ต้องการลบ:' : 'Record to delete:',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('${widget.record['category']} - ${widget.record['amount']} ${widget.record['unit']}'),
                Text('${widget.record['month']}/${widget.record['year']} - ${widget.record['co2_equivalent']?.toStringAsFixed(2)} kg CO₂e'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          TextField(
            controller: _reasonController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: widget.localization.isThaiLanguage ? 'เหตุผลในการขอลบข้อมูล *' : 'Reason for deletion *',
              hintText: widget.localization.isThaiLanguage
                  ? 'เช่น: ป้อนข้อมูลผิดพลาด, ข้อมูลซ้ำซ้อน'
                  : 'e.g., Wrong input, Duplicate data',
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.localization.isThaiLanguage ? 'ยกเลิก' : 'Cancel'),
        ),
        ElevatedButton(
          onPressed: widget.isLoading
              ? null
              : () {
                  final reason = _reasonController.text.trim();
                  if (reason.isNotEmpty) {
                    Navigator.of(context).pop();
                    widget.onSubmit(
                      recordId: widget.record['record_id'],
                      requestType: 'delete',
                      reason: reason,
                    );
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: widget.isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(widget.localization.isThaiLanguage ? 'ส่งคำขอลบ' : 'Submit Delete Request'),
        ),
      ],
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar;
  }
}
