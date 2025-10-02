import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/localization_service.dart';
import '../widgets/language_switcher.dart';
import 'login_screen.dart';
import 'add_emission_screen.dart';
import 'smart_dashboard_screen.dart';
import 'upload_data_screen.dart';
import 'report_generation_screen.dart';
import 'edit_request_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic> _dashboardData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    
    try {
      final result = await ApiService.getDashboardData();
      
      if (mounted) {
        if (result['success']) {
          setState(() {
            _dashboardData = result['data'];
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
          });
          
          // Only logout if explicitly unauthorized
          if (result['message'] == 'Session expired') {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(LocalizationService().sessionExpired),
                backgroundColor: Colors.red,
              ),
            );
            await ApiService.clearToken();
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        print('Error loading dashboard: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LocalizationService>(
      builder: (context, localization, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(localization.dashboard),
            backgroundColor: Colors.green[700],
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadDashboardData,
              ),
              // Prominent Language Change Button in AppBar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                child: ElevatedButton.icon(
                  onPressed: () {
                    localization.toggleLanguage();
                    _loadDashboardData();
                  },
                  icon: const Icon(Icons.language, size: 18, color: Colors.white),
                  label: Text(
                    localization.isThaiLanguage ? 'EN' : 'TH',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[800],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 2,
                    minimumSize: const Size(70, 32),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () async {
                  await ApiService.clearToken();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
              ),
            ],
          ),
          drawer: _buildDrawer(localization),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildDashboardContent(localization),
        );
      },
    );
  }

  Widget _buildDrawer(LocalizationService localization) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.green[700],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.eco, size: 60, color: Colors.white),
                const SizedBox(height: 10),
                Text(
                  localization.appTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                  ),
                ),
                Text(
                  localization.trackYourEmissions,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          // Language Switcher in Sidebar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: ListTile(
              leading: Icon(Icons.language, color: Colors.green[700]),
              title: Text(
                localization.changeLanguage,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.green[800],
                ),
              ),
              subtitle: Text(
                localization.isThaiLanguage ? 'ไทย → English' : 'English → ไทย',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.green[600],
                ),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green[700],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  localization.isThaiLanguage ? 'EN' : 'TH',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              onTap: () {
                localization.toggleLanguage();
                _loadDashboardData(); // Refresh data after language change
                Navigator.pop(context); // Close drawer after selection
              },
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: Text(localization.smartDashboard),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SmartDashboardScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.add_circle),
            title: Text(localization.addEmission),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddEmissionScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: Text(localization.uploadData),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => UploadDataScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.assessment),
            title: Text(localization.generateReport),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReportGenerationScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit_note),
            title: Text(
              localization.isThaiLanguage 
                ? 'คำขอแก้ไข/ลบข้อมูล' 
                : 'Edit/Delete Requests'
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EditRequestScreen()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: Text(localization.settings),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(localization.settingsComingSoon)),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: Text(
              localization.logout,
              style: const TextStyle(color: Colors.red),
            ),
            onTap: () async {
              await ApiService.clearToken();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardContent(LocalizationService localization) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Card - Updated for Shared Dashboard
          Card(
            elevation: 4,
            color: Colors.blue[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.public, size: 48, color: Colors.blue[700]),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localization.isThaiLanguage ? 'แดชบอร์ดคาร์บอนร่วม' : 'Shared Carbon Dashboard',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          localization.isThaiLanguage 
                            ? 'ดูการปล่อยรวมจากผู้ใช้ทุกคน'
                            : 'View collective emissions from all users',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        if (_dashboardData.containsKey('total_users') && _dashboardData.containsKey('users_with_data'))
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${_dashboardData['users_with_data']}/${_dashboardData['total_users']} ${localization.isThaiLanguage ? 'ผู้ใช้มีส่วนร่วมข้อมูล' : 'users contributing data'}',
                              style: TextStyle(
                                color: Colors.blue[700],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Quick Actions
          Text(
            localization.isThaiLanguage ? 'การดำเนินการด่วน' : 'Quick Actions',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.5,
            children: [
              _buildActionCard(
                localization.addEmission,
                Icons.add_circle,
                Colors.blue,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddEmissionScreen()),
                  );
                },
              ),
              _buildActionCard(
                localization.uploadData,
                Icons.upload_file,
                Colors.orange,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => UploadDataScreen()),
                  );
                },
              ),
              _buildActionCard(
                localization.generateReport,
                Icons.assessment,
                Colors.purple,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ReportGenerationScreen()),
                  );
                },
              ),
              _buildActionCard(
                localization.smartDashboard,
                Icons.analytics,
                Colors.indigo,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SmartDashboardScreen()),
                  ).then((_) => _loadDashboardData());
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Summary Cards - Always show, handle empty data gracefully
          Row(
            children: [
              Text(
                localization.isThaiLanguage ? 'สรุปเดือนปัจจุบัน' : 'Current Month Summary',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.people, size: 14, color: Colors.blue[700]),
                    const SizedBox(width: 4),
                    Text(
                      localization.isThaiLanguage ? 'ร่วม' : 'Shared',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          
          if (_dashboardData.isNotEmpty && (_dashboardData['current_month_total'] ?? 0) > 0) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            localization.isThaiLanguage ? 'การปล่อยทั้งหมด:' : 'Total Emissions:',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            localization.formatCO2(_dashboardData['current_month_total']?.toDouble() ?? 0.0),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            localization.isThaiLanguage ? 'รวมปี:' : 'Year Total:',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            localization.formatCO2(_dashboardData['current_year_total']?.toDouble() ?? 0.0),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      Icons.eco_outlined,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      localization.isThaiLanguage ? 'ยังไม่มีข้อมูลการปล่อย' : 'No emission data yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      localization.isThaiLanguage 
                        ? 'ยังไม่มีใครเพิ่มข้อมูลการปล่อย เป็นคนแรกที่สนับสนุนแดชบอร์ดร่วม!'
                        : 'No one has added emission data yet. Be the first to contribute to the shared dashboard!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AddEmissionScreen()),
                        ).then((_) => _loadDashboardData());
                      },
                      icon: const Icon(Icons.add_circle, color: Colors.white),
                      label: Text(
                        localization.isThaiLanguage ? 'เพิ่มการปล่อยแรก' : 'Add First Emission',
                        style: const TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
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
    );
  }

  Widget _buildActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Card(
        elevation: 4,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(height: 8),
              Flexible(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
