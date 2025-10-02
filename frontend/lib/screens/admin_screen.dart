import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/localization_service.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  _AdminScreenState createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _auditLogs = [];
  List<Map<String, dynamic>> _editRequests = [];
  bool _isLoading = true;
  bool _isLoadingUsers = false;
  bool _isLoadingLogs = false;
  bool _isLoadingRequests = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadUsers(),
      _loadAuditLogs(),
      _loadEditRequests(),
    ]);
    setState(() => _isLoading = false);
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoadingUsers = true);
    try {
      final result = await ApiService.getUsers();
      if (result['success']) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(result['data']);
        });
      } else {
        _showErrorSnackBar('Failed to load users: ${result['message']}');
      }
    } catch (e) {
      _showErrorSnackBar('Error loading users: $e');
    } finally {
      setState(() => _isLoadingUsers = false);
    }
  }

  Future<void> _loadAuditLogs() async {
    setState(() => _isLoadingLogs = true);
    try {
      final result = await ApiService.getAuditLogs();
      if (result['success']) {
        setState(() {
          _auditLogs = List<Map<String, dynamic>>.from(result['data']);
        });
      } else {
        _showErrorSnackBar('Failed to load audit logs: ${result['message']}');
      }
    } catch (e) {
      _showErrorSnackBar('Error loading audit logs: $e');
    } finally {
      setState(() => _isLoadingLogs = false);
    }
  }

  Future<void> _loadEditRequests() async {
    setState(() => _isLoadingRequests = true);
    try {
      final result = await ApiService.getAllEditRequests();
      if (result['success']) {
        setState(() {
          _editRequests = List<Map<String, dynamic>>.from(result['data']['requests']);
        });
      } else {
        _showErrorSnackBar('Failed to load edit requests: ${result['message']}');
      }
    } catch (e) {
      _showErrorSnackBar('Error loading edit requests: $e');
    } finally {
      setState(() => _isLoadingRequests = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
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

  @override
  Widget build(BuildContext context) {
    return Consumer<LocalizationService>(
      builder: (context, localization, child) {
        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: _buildAppBar(localization),
          body: _isLoading
              ? _buildLoadingView(localization)
              : Column(
                  children: [
                    _buildTabBar(localization),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildUsersTab(localization),
                          _buildEditRequestsTab(localization),
                          _buildAuditLogsTab(localization),
                        ],
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(LocalizationService localization) {
    return AppBar(
      title: Text(
        localization.adminPanel,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
      ),
      backgroundColor: const Color(0xFF7C3AED),
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _loadInitialData,
          tooltip: localization.isThaiLanguage ? 'รีเฟรชข้อมูล' : 'Refresh Data',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildTabBar(LocalizationService localization) {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: const Color(0xFF7C3AED),
        unselectedLabelColor: Colors.grey[600],
        indicatorColor: const Color(0xFF7C3AED),
        indicatorWeight: 3,
        tabs: [
          Tab(
            icon: const Icon(Icons.people_rounded),
            text: localization.userManagement,
          ),
          Tab(
            icon: const Icon(Icons.edit_note_rounded),
            text: localization.isThaiLanguage ? 'คำขอแก้ไข/ลบ' : 'Edit Requests',
          ),
          Tab(
            icon: const Icon(Icons.history_rounded),
            text: localization.isThaiLanguage ? 'บันทึกตรวจสอบ' : 'Audit Logs',
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingView(LocalizationService localization) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: Color(0xFF7C3AED),
            strokeWidth: 3,
          ),
          const SizedBox(height: 16),
          Text(
            localization.isThaiLanguage ? 'กำลังโหลดข้อมูลผู้ดูแลระบบ...' : 'Loading admin data...',
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersTab(LocalizationService localization) {
    return RefreshIndicator(
      onRefresh: _loadUsers,
      color: const Color(0xFF7C3AED),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildUsersHeader(),
            const SizedBox(height: 20),
            Expanded(
              child: _isLoadingUsers
                  ? const Center(child: CircularProgressIndicator())
                  : _buildUsersList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'User Management',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Text(
              '${_users.length} users registered',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
        ElevatedButton.icon(
          onPressed: _showAddUserDialog,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add User'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7C3AED),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUsersList() {
    if (_users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No users found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final user = _users[index];
        return _buildUserCard(user);
      },
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final isAdmin = user['is_admin'] ?? false;
    final createdAt = DateTime.tryParse(user['created_at'] ?? '');
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: isAdmin ? const Color(0xFF7C3AED).withOpacity(0.1) : const Color(0xFF059669).withOpacity(0.1),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Icon(
              isAdmin ? Icons.admin_panel_settings_rounded : Icons.person_rounded,
              color: isAdmin ? const Color(0xFF7C3AED) : const Color(0xFF059669),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      user['username'] ?? 'Unknown',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isAdmin)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'ADMIN',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF7C3AED),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  user['email'] ?? 'No email',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                if (createdAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Joined ${_formatDate(createdAt)}',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) => _handleUserAction(value, user),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'toggle_admin',
                child: Row(
                  children: [
                    Icon(
                      isAdmin ? Icons.remove_moderator_rounded : Icons.admin_panel_settings_rounded,
                      size: 20,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Text(isAdmin ? 'Remove Admin' : 'Make Admin'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'reset_password',
                child: Row(
                  children: [
                    Icon(Icons.lock_reset_rounded, size: 20, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Reset Password'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_rounded, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete User'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditRequestsTab(LocalizationService localization) {
    return RefreshIndicator(
      onRefresh: _loadEditRequests,
      color: const Color(0xFF7C3AED),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildEditRequestsHeader(localization),
            const SizedBox(height: 20),
            Expanded(
              child: _isLoadingRequests
                  ? const Center(child: CircularProgressIndicator())
                  : _buildEditRequestsList(localization),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditRequestsHeader(LocalizationService localization) {
    final pendingCount = _editRequests.where((req) => req['status'] == 'pending').length;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localization.isThaiLanguage ? 'คำขอแก้ไข/ลบข้อมูล' : 'Edit/Delete Requests',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Text(
          localization.isThaiLanguage 
            ? 'คำขอทั้งหมด ${_editRequests.length} รายการ (รอดำเนินการ $pendingCount รายการ)'
            : '${_editRequests.length} total requests ($pendingCount pending)',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildEditRequestsList(LocalizationService localization) {
    if (_editRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.edit_note_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              localization.isThaiLanguage ? 'ไม่มีคำขอแก้ไข/ลบข้อมูล' : 'No edit/delete requests found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            Text(
              localization.isThaiLanguage 
                ? 'คำขอจะปรากฏที่นี่เมื่อผู้ใช้ส่งคำขอ' 
                : 'User requests will appear here',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _editRequests.length,
      itemBuilder: (context, index) {
        final request = _editRequests[index];
        return _buildEditRequestCard(request, localization);
      },
    );
  }

  Widget _buildEditRequestCard(Map<String, dynamic> request, LocalizationService localization) {
    final status = request['status'] ?? 'pending';
    final requestType = request['request_type'] ?? 'edit';
    final userInfo = request['user_info'] ?? {};
    final createdAt = DateTime.tryParse(request['created_at'] ?? '');
    final daysRemaining = request['days_remaining'] ?? 0;
    final expiresSoon = request['expires_soon'] ?? false;
    
    Color statusColor;
    IconData statusIcon;
    
    switch (status.toLowerCase()) {
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.pending_rounded;
        break;
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel_rounded;
        break;
      case 'expired':
        statusColor = Colors.grey;
        statusIcon = Icons.schedule_rounded;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: expiresSoon && status == 'pending' 
          ? Border.all(color: Colors.red, width: 2)
          : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Icon(
                  requestType == 'edit' ? Icons.edit_rounded : Icons.delete_rounded,
                  color: statusColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          localization.isThaiLanguage 
                            ? (requestType == 'edit' ? 'คำขอแก้ไข' : 'คำขอลบ')
                            : '${requestType.toUpperCase()} Request',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, size: 12, color: statusColor),
                              const SizedBox(width: 4),
                              Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'by ${userInfo['username'] ?? 'Unknown User'} (${userInfo['email'] ?? 'No email'})',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    if (createdAt != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            'Submitted ${_formatTimestamp(createdAt)}',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                          if (status == 'pending' && daysRemaining <= 30) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: expiresSoon ? Colors.red[50] : Colors.blue[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$daysRemaining days left',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: expiresSoon ? Colors.red[700] : Colors.blue[700],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (status == 'pending')
                PopupMenuButton<String>(
                  onSelected: (value) => _handleRequestAction(value, request),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'approve',
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_rounded, size: 20, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(localization.isThaiLanguage ? 'อนุมัติ' : 'Approve'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'reject',
                      child: Row(
                        children: [
                          Icon(Icons.cancel_rounded, size: 20, color: Colors.red),
                          const SizedBox(width: 8),
                          Text(localization.isThaiLanguage ? 'ปฏิเสธ' : 'Reject'),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localization.isThaiLanguage ? 'รายละเอียด:' : 'Details:',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${localization.isThaiLanguage ? 'รหัสบันทึก' : 'Record ID'}: ${request['record_id'] ?? 'N/A'}',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  '${localization.isThaiLanguage ? 'เหตุผล' : 'Reason'}: ${request['reason'] ?? 'No reason provided'}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditLogsTab(LocalizationService localization) {
    return RefreshIndicator(
      onRefresh: _loadAuditLogs,
      color: const Color(0xFF7C3AED),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAuditLogsHeader(localization),
            const SizedBox(height: 20),
            Expanded(
              child: _isLoadingLogs
                  ? const Center(child: CircularProgressIndicator())
                  : _buildAuditLogsList(localization),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuditLogsHeader(LocalizationService localization) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localization.isThaiLanguage ? 'บันทึกตรวจสอบ' : 'Audit Logs',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Text(
          localization.isThaiLanguage ? 
            'บันทึกกิจกรรม ${_auditLogs.length} รายการ' : 
            '${_auditLogs.length} activities recorded',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildAuditLogsList(LocalizationService localization) {
    if (_auditLogs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No audit logs found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _auditLogs.length,
      itemBuilder: (context, index) {
        final log = _auditLogs[index];
        return _buildAuditLogCard(log);
      },
    );
  }

  Widget _buildAuditLogCard(Map<String, dynamic> log) {
    final action = log['action'] ?? 'Unknown';
    final username = log['username'] ?? 'Unknown User';
    final timestamp = DateTime.tryParse(log['timestamp'] ?? '');
    final details = log['details'] ?? {};
    
    IconData icon;
    Color iconColor;
    
    switch (action.toLowerCase()) {
      case 'add_emission':
        icon = Icons.add_circle_rounded;
        iconColor = Colors.green;
        break;
      case 'upload_data':
        icon = Icons.upload_rounded;
        iconColor = Colors.blue;
        break;
      case 'delete_emission':
        icon = Icons.delete_rounded;
        iconColor = Colors.red;
        break;
      case 'login':
        icon = Icons.login_rounded;
        iconColor = Colors.purple;
        break;
      case 'logout':
        icon = Icons.logout_rounded;
        iconColor = Colors.orange;
        break;
      default:
        icon = Icons.info_rounded;
        iconColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatActionTitle(action),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'by $username',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _formatLogDetails(details),
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (timestamp != null)
            Text(
              _formatTimestamp(timestamp),
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 11,
              ),
            ),
        ],
      ),
    );
  }

  String _formatActionTitle(String action) {
    switch (action.toLowerCase()) {
      case 'add_emission':
        return 'Added Emission Record';
      case 'upload_data':
        return 'Uploaded Data File';
      case 'delete_emission':
        return 'Deleted Emission Record';
      case 'login':
        return 'User Login';
      case 'logout':
        return 'User Logout';
      default:
        return action.replaceAll('_', ' ').toUpperCase();
    }
  }

  String _formatLogDetails(Map<String, dynamic> details) {
    final List<String> parts = [];
    
    if (details['category'] != null) {
      parts.add('Category: ${details['category']}');
    }
    if (details['amount'] != null) {
      parts.add('Amount: ${details['amount']}');
    }
    if (details['co2_amount'] != null) {
      parts.add('CO₂: ${details['co2_amount']} kg');
    }
    if (details['file_name'] != null) {
      parts.add('File: ${details['file_name']}');
    }
    
    return parts.join(' • ');
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  // Simple display helper for audit_id system (no complex date parsing needed)
  String _getRequestDisplay(Map<String, dynamic> request) {
    final auditId = request['audit_id'] ?? 'N/A';
    final sequence = request['sequence'] ?? 0;
    final daysRemaining = request['days_remaining'] ?? 0;
    
    if (request['status'] == 'pending' && daysRemaining > 0) {
      return 'Audit: $auditId | $daysRemaining days left';
    }
    return 'Audit: $auditId | Seq: #$sequence';
  }

  void _showAddUserDialog() {
    final usernameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool isAdmin = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.person_add_rounded, color: Color(0xFF7C3AED)),
              SizedBox(width: 8),
              Text('Add New User'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: usernameController,
                decoration: InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.person_rounded),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.email_rounded),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.lock_rounded),
                ),
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text('Admin User'),
                subtitle: const Text('Grant admin privileges'),
                value: isAdmin,
                onChanged: (value) {
                  setState(() {
                    isAdmin = value ?? false;
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => _createUser(
                usernameController.text,
                emailController.text,
                passwordController.text,
                isAdmin,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Create User'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createUser(String username, String email, String password, bool isAdmin) async {
    if (username.isEmpty || email.isEmpty || password.isEmpty) {
      _showErrorSnackBar('Please fill in all fields');
      return;
    }

    try {
      final result = await ApiService.createUser(username, email, password, isAdmin);
      if (result['success']) {
        Navigator.pop(context);
        _showSuccessSnackBar('User created successfully');
        _loadUsers();
      } else {
        _showErrorSnackBar('Failed to create user: ${result['message']}');
      }
    } catch (e) {
      _showErrorSnackBar('Error creating user: $e');
    }
  }

  void _handleUserAction(String action, Map<String, dynamic> user) {
    switch (action) {
      case 'toggle_admin':
        _toggleAdminStatus(user);
        break;
      case 'reset_password':
        _showResetPasswordDialog(user);
        break;
      case 'delete':
        _showDeleteUserDialog(user);
        break;
    }
  }

  Future<void> _toggleAdminStatus(Map<String, dynamic> user) async {
    final isAdmin = user['is_admin'] ?? false;
    final newStatus = !isAdmin;
    
    try {
      final result = await ApiService.updateUserAdminStatus(user['id'], newStatus);
      if (result['success']) {
        _showSuccessSnackBar(
          newStatus ? 'User promoted to admin' : 'Admin privileges removed'
        );
        _loadUsers();
      } else {
        _showErrorSnackBar('Failed to update user: ${result['message']}');
      }
    } catch (e) {
      _showErrorSnackBar('Error updating user: $e');
    }
  }

  void _showResetPasswordDialog(Map<String, dynamic> user) {
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.lock_reset_rounded, color: Colors.blue),
            const SizedBox(width: 8),
            Text('Reset Password for ${user['username']}'),
          ],
        ),
        content: TextField(
          controller: passwordController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'New Password',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            prefixIcon: const Icon(Icons.lock_rounded),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _resetUserPassword(user['id'], passwordController.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Reset Password'),
          ),
        ],
      ),
    );
  }

  Future<void> _resetUserPassword(int userId, String newPassword) async {
    if (newPassword.isEmpty) {
      _showErrorSnackBar('Please enter a new password');
      return;
    }

    try {
      final result = await ApiService.resetUserPassword(userId, newPassword);
      if (result['success']) {
        Navigator.pop(context);
        _showSuccessSnackBar('Password reset successfully');
      } else {
        _showErrorSnackBar('Failed to reset password: ${result['message']}');
      }
    } catch (e) {
      _showErrorSnackBar('Error resetting password: $e');
    }
  }

  void _showDeleteUserDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete User'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete user "${user['username']}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _deleteUser(user['id']),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteUser(int userId) async {
    try {
      final result = await ApiService.deleteUser(userId);
      if (result['success']) {
        Navigator.pop(context);
        _showSuccessSnackBar('User deleted successfully');
        _loadUsers();
      } else {
        _showErrorSnackBar('Failed to delete user: ${result['message']}');
      }
    } catch (e) {
      _showErrorSnackBar('Error deleting user: $e');
    }
  }

  void _handleRequestAction(String action, Map<String, dynamic> request) {
    switch (action) {
      case 'approve':
        _approveRequest(request);
        break;
      case 'reject':
        _rejectRequest(request);
        break;
    }
  }

  Future<void> _approveRequest(Map<String, dynamic> request) async {
    try {
      final result = await ApiService.approveEditRequest(request['request_id']);
      if (result['success']) {
        _showSuccessSnackBar('Request approved successfully');
        _loadEditRequests();
      } else {
        _showErrorSnackBar('Failed to approve request: ${result['message']}');
      }
    } catch (e) {
      _showErrorSnackBar('Error approving request: $e');
    }
  }

  Future<void> _rejectRequest(Map<String, dynamic> request) async {
    try {
      final result = await ApiService.rejectEditRequest(request['request_id']);
      if (result['success']) {
        _showSuccessSnackBar('Request rejected successfully');
        _loadEditRequests();
      } else {
        _showErrorSnackBar('Failed to reject request: ${result['message']}');
      }
    } catch (e) {
      _showErrorSnackBar('Error rejecting request: $e');
    }
  }
}
