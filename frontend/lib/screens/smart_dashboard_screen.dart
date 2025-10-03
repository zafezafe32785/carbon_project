import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/localization_service.dart';
import '../utils/constants.dart';
import 'add_emission_screen.dart';
import 'login_screen.dart';
import 'upload_data_screen.dart';
import 'report_generation_screen.dart';
import 'admin_screen.dart';
import 'edit_request_screen.dart';

class SmartDashboardScreen extends StatefulWidget {
  const SmartDashboardScreen({super.key});

  @override
  _SmartDashboardScreenState createState() => _SmartDashboardScreenState();
}

class _SmartDashboardScreenState extends State<SmartDashboardScreen> {
  Map<String, dynamic> _dashboardData = {};
  bool _isLoading = true;
  double _monthlyTarget = 5000; // Default target
  String _selectedScope = 'All'; // For bar chart filtering

  // Chart visualization preferences
  String _trendChartType = 'line'; // line, bar, area
  String _categoryChartType = 'pie'; // pie, bar, donut
  String _timeRange = 'year'; // year, 6months, 3months
  bool _showComparison = true; // Show previous year comparison

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;
  
    setState(() => _isLoading = true);
  
    try {
      final result = await ApiService.getDashboardData();
    
      if (result['success']) {
        setState(() {
          _dashboardData = result['data'];
          _isLoading = false;
        });

    // Better debug output
    print('=== Dashboard Data Received ===');
    print('Current Month Total: ${_dashboardData['current_month_total']}');
    print('Current Year Total: ${_dashboardData['current_year_total']}');
    print('Last Year Total: ${_dashboardData['last_year_total']}');
    print('Monthly Trend Length: ${_dashboardData['monthly_trend']?.length ?? 0}');
    print('Monthly Trend Data: ${_dashboardData['monthly_trend']}');
    print('==============================');
        // Check for missing data
        if (_dashboardData['missing_categories']?.isNotEmpty ?? false) {
          _showMissingDataAlert();
        }

        // Check for category increases (show after a short delay to not overwhelm user)
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _showCategoryWarnings();
          }
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      
        // Don't logout on refresh, just show error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to load data'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  List<Map<String, dynamic>> _detectCategoryIncreases({double threshold = 50.0}) {
    final currentMonth = _dashboardData['current_month_category_breakdown'] as Map?;
    final lastMonth = _dashboardData['last_month_category_breakdown'] as Map?;

    if (currentMonth == null || lastMonth == null) return [];

    List<Map<String, dynamic>> warnings = [];

    currentMonth.forEach((category, currentValue) {
      final current = (currentValue ?? 0).toDouble();
      final previous = (lastMonth[category] ?? 0).toDouble();

      // Only warn if there was previous data and current is significantly higher
      if (previous > 0 && current > previous) {
        final increasePercentage = ((current - previous) / previous * 100);

        if (increasePercentage >= threshold) {
          warnings.add({
            'category': category,
            'current': current,
            'previous': previous,
            'increase_percentage': increasePercentage,
          });
        }
      }
    });

    // Sort by highest increase percentage
    warnings.sort((a, b) => (b['increase_percentage'] as double).compareTo(a['increase_percentage'] as double));

    return warnings;
  }

  void _showCategoryWarnings() {
    final warnings = _detectCategoryIncreases(threshold: 50.0);

    if (warnings.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.trending_up, color: Colors.orange),
            SizedBox(width: 8),
            Text('Emission Increase Alert'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Significant increases detected compared to last month:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              ...warnings.map((warning) {
                final category = Constants.getCategoryDisplayName(warning['category']);
                final percentage = warning['increase_percentage'].toStringAsFixed(1);
                final current = warning['current'].toStringAsFixed(0);
                final previous = warning['previous'].toStringAsFixed(0);

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.arrow_upward, color: Colors.orange.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              category,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Increased by $percentage%',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Last month: $previous kg CO₂ → This month: $current kg CO₂',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Dismiss'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Could navigate to detailed analysis or add emission screen
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('View Details'),
          ),
        ],
      ),
    );
  }

  void _showMissingDataAlert() {
    final missing = _dashboardData['missing_categories'] as List;
    if (missing.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Missing Data'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('No data recorded this month for:'),
            const SizedBox(height: 8),
            ...missing.map((cat) => Text('• ${cat.toString().toUpperCase()}')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddEmissionScreen()),
              ).then((_) => _loadDashboardData()); // Reload after adding
            },
            child: const Text('Add Now'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LocalizationService>(
      builder: (context, localization, child) {
        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: _buildModernAppBar(localization),
          drawer: _buildModernDrawer(localization),
          body: _isLoading
              ? _buildLoadingView()
              : _dashboardData['has_data'] == false
                  ? _buildNoDataView()
                  : RefreshIndicator(
                      onRefresh: _loadDashboardData,
                      color: const Color(0xFF059669),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Welcome Header
                            _buildWelcomeHeader(),
                            const SizedBox(height: 24),
                            
                            // Alert if exceeding target
                            if ((_dashboardData['current_month_total'] ?? 0) > _monthlyTarget)
                              _buildModernAlertCard(),

                            // Alert for category increases
                            if (_detectCategoryIncreases(threshold: 50.0).isNotEmpty)
                              _buildCategoryIncreaseCard(),

                            // Quick Stats Grid
                            _buildQuickStatsGrid(),
                            const SizedBox(height: 24),
                            
                            // Charts Section
                            _buildChartsSection(),
                            const SizedBox(height: 24),
                            
                            // Category Breakdown
                            if ((_dashboardData['category_breakdown'] as Map?)?.isNotEmpty ?? false)
                              _buildModernCategoryBreakdown(),
                            
                            const SizedBox(height: 24),
                            
                            // Quick Actions
                            _buildQuickActions(),
                            
                            const SizedBox(height: 100), // Space for FAB
                          ],
                        ),
                      ),
                    ),
          floatingActionButton: _buildModernFAB(),
        );
      },
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.green[700],
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.eco, size: 60, color: Colors.white),
                SizedBox(height: 10),
                Text(
                  'Carbon Accounting',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                  ),
                ),
                Text(
                  'Smart Dashboard',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Dashboard'),
            selected: true,
            selectedTileColor: Colors.green[50],
            onTap: () {
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.add_circle),
            title: const Text('Add Emission'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddEmissionScreen()),
              ).then((_) => _loadDashboardData());
            },
          ),
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('Upload Data'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => UploadDataScreen()),
              ).then((_) => _loadDashboardData());
            },
          ),
          ListTile(
            leading: const Icon(Icons.assessment),
            title: const Text('Generate Reports'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReportGenerationScreen()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Target Settings'),
            onTap: () {
              Navigator.pop(context);
              _showTargetSettings();
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () async {
              Navigator.pop(context);
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

  Widget _buildTestChart() {
  return Card(
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Test Chart',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: true),
                titlesData: const FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: true),
                minX: 0,
                maxX: 11,
                minY: 0,
                maxY: 100,
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      const FlSpot(0, 20),
                      const FlSpot(1, 30),
                      const FlSpot(2, 25),
                      const FlSpot(3, 40),
                      const FlSpot(4, 35),
                      const FlSpot(5, 50),
                    ],
                    isCurved: true,
                    color: Colors.blue,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildNoDataView() {
    return Consumer<LocalizationService>(
      builder: (context, localization, child) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.insert_chart_outlined, size: 100, color: Colors.grey[400]),
              const SizedBox(height: 20),
              Text(
                localization.noEmissionDataYet,
                style: TextStyle(fontSize: 20, color: Colors.grey[600]),
              ),
              const SizedBox(height: 10),
              Text(
                localization.isThaiLanguage ? 'เริ่มต้นด้วยการเพิ่มบันทึกการปล่อยครั้งแรก' : 'Start by adding your first emission record',
                style: TextStyle(color: Colors.grey[500]),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddEmissionScreen()),
                  ).then((_) => _loadDashboardData());
                },
                icon: const Icon(Icons.add),
                label: Text(localization.addFirstEmission),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAlertCard() {
    final exceeded = (_dashboardData['current_month_total'] ?? 0) - _monthlyTarget;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.warning, color: Colors.red[700], size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Monthly Target Exceeded!',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red[700],
                  ),
                ),
                Text(
                  'Over target by ${exceeded.toStringAsFixed(0)} kg CO₂',
                  style: TextStyle(color: Colors.red[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final currentMonth = _dashboardData['current_month_total'] ?? 0;
    final monthChange = _dashboardData['month_change_percentage'] ?? 0;
    final currentYear = _dashboardData['current_year_total'] ?? 0;
    
    return SizedBox(
      height: 120,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildMetricCard(
            'This Month',
            '${currentMonth.toStringAsFixed(0)} kg',
            'Month ${_dashboardData['current_month']} / ${_dashboardData['current_year']}',
            monthChange > 0 ? Colors.red : Colors.green,
            '${monthChange > 0 ? "+" : ""}${monthChange.toStringAsFixed(1)}%',
          ),
          const SizedBox(width: 12),
          _buildMetricCard(
            'Target Status',
            '${(currentMonth / _monthlyTarget * 100).toStringAsFixed(0)}%',
            'of ${_monthlyTarget.toStringAsFixed(0)} kg',
            currentMonth > _monthlyTarget ? Colors.red : Colors.orange,
            currentMonth > _monthlyTarget ? 'Over' : 'On Track',
          ),
          const SizedBox(width: 12),
          _buildMetricCard(
            'Year Total',
            '${currentYear.toStringAsFixed(0)} kg',
            'Since January',
            Colors.blue,
            '${_dashboardData['current_year']}',
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    String subtitle,
    Color color,
    String badge,
  ) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildYearComparisonCard() {
    final thisYear = _dashboardData['current_year_total'] ?? 0;
    final lastYear = _dashboardData['last_year_total'] ?? 0;
    final change = _dashboardData['year_change_percentage'] ?? 0;
    final currentYear = _dashboardData['current_year'] ?? DateTime.now().year;
    final previousYear = _dashboardData['last_year'] ?? (DateTime.now().year - 1);
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Year-over-Year Comparison',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      '$previousYear',
                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${lastYear.toStringAsFixed(0)} kg',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
                Icon(
                  change < 0 ? Icons.trending_down : Icons.trending_up,
                  size: 40,
                  color: change < 0 ? Colors.green : Colors.red,
                ),
                Column(
                  children: [
                    Text(
                      '$currentYear',
                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${thisYear.toStringAsFixed(0)} kg',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: change < 0 ? Colors.green[50] : Colors.red[50],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${change > 0 ? "+" : ""}${change.toStringAsFixed(1)}% ${change < 0 ? "reduction" : "increase"}',
                  style: TextStyle(
                    color: change < 0 ? Colors.green[700] : Colors.red[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyTrendChart() {
    final monthlyData = _dashboardData['monthly_trend'] as List? ?? [];
    final lastYearData = _dashboardData['last_year_trend'] as List? ?? [];
    final hasCurrentYearData = monthlyData.any((m) => m['hasData'] == true);
    final hasLastYearData = lastYearData.any((m) => (m['total'] ?? 0) > 0);
    
    if (!hasCurrentYearData && !hasLastYearData) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Text(
                'Monthly Emissions Trend',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),
              Icon(Icons.show_chart, size: 60, color: Colors.grey[400]),
              const SizedBox(height: 20),
              Text(
                'No data to display',
                style: TextStyle(color: Colors.grey[600]),
              ),
              Text(
                'Add more emission data to see trends',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }
    
    // Find max value for Y axis
    double maxY = 0;
    for (var data in monthlyData) {
      if (data['total'] > maxY) maxY = data['total'].toDouble();
    }
    for (var data in lastYearData) {
      if (data['total'] > maxY) maxY = data['total'].toDouble();
    }
    maxY = maxY * 1.2; // Add 20% padding
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Monthly Emissions Trend',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    if (hasCurrentYearData) ...[
                      Container(
                        width: 20,
                        height: 3,
                        color: Colors.green[700],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_dashboardData['current_year']}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                    if (hasCurrentYearData && hasLastYearData)
                      const SizedBox(width: 12),
                    if (hasLastYearData) ...[
                      Container(
                        width: 20,
                        height: 3,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_dashboardData['last_year']}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  maxY: maxY > 0 ? maxY : 100,
                  minY: 0,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey[300]!,
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return const Text('0');
                          return Text('${value.toInt()}');
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          const months = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];
                          if (value.toInt() >= 0 && value.toInt() < months.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                months[value.toInt()],
                                style: const TextStyle(fontSize: 12),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    if (hasCurrentYearData)
                      LineChartBarData(
                        spots: monthlyData.asMap().entries.map((entry) {
                          return FlSpot(
                            entry.key.toDouble(),
                            (entry.value['total'] ?? 0).toDouble(),
                          );
                        }).toList(),
                        isCurved: true,
                        color: Colors.green[700],
                        barWidth: 3,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: monthlyData[index]['hasData'] ? 4 : 0,
                              color: Colors.green[700]!,
                              strokeWidth: 0,
                            );
                          },
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          color: Colors.green[700]!.withOpacity(0.1),
                        ),
                      ),
                    if (hasLastYearData)
                      LineChartBarData(
                        spots: lastYearData.asMap().entries.map((entry) {
                          return FlSpot(
                            entry.key.toDouble(),
                            (entry.value['total'] ?? 0).toDouble(),
                          );
                        }).toList(),
                        isCurved: true,
                        color: Colors.grey[400],
                        barWidth: 2,
                        dashArray: [5, 5],
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(show: false),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBreakdown() {
    final categoryData = _dashboardData['category_breakdown'] as Map? ?? {};

    if (categoryData.isEmpty) return const SizedBox.shrink();

    // Normalize and merge duplicate categories
    final normalizedCategoryData = <String, double>{};
    for (final entry in categoryData.entries) {
      final value = (entry.value ?? 0).toDouble();
      if (value > 0.01) { // Filter out very small values
        // Normalize category key: lowercase, replace spaces/dashes/parentheses with underscores
        String normalizedKey = entry.key.toString()
            .toLowerCase()
            .trim()
            .replaceAll(RegExp(r'[-()\s]+'), '_')  // Replace all spaces, dashes, parens with underscore
            .replaceAll(RegExp(r'_+'), '_')        // Replace multiple underscores with single
            .replaceAll(RegExp(r'^_|_$'), '');     // Remove leading/trailing underscores

        // Sum up values for the same normalized category
        normalizedCategoryData[normalizedKey] =
            (normalizedCategoryData[normalizedKey] ?? 0.0) + value;
      }
    }

    if (normalizedCategoryData.isEmpty) return const SizedBox.shrink();

    // Calculate total for percentages
    final total = normalizedCategoryData.values.fold<double>(0, (sum, value) => sum + value);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Emissions by Category',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ...normalizedCategoryData.entries.map((entry) {
              final percentage = (entry.value / total * 100).toStringAsFixed(1);
              final color = _getCategoryColor(entry.key);
              final displayName = Constants.getCategoryDisplayName(entry.key);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  displayName,
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${entry.value.toStringAsFixed(0)} kg ($percentage%)',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: entry.value / total,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 6,
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    // Use the Constants helper to determine scope - this handles ALL TGO categories correctly
    final categoryLower = category.toLowerCase();
    final scope = Constants.getCategoryScope(categoryLower);

    // Scope 1 (Direct Emissions) - Green
    if (scope == 1) {
      return const Color(0xFF059669); // Green for Scope 1
    }

    // Scope 2 (Indirect Energy Emissions) - Blue
    if (scope == 2) {
      return const Color(0xFF3B82F6); // Blue for Scope 2
    }

    // Fallback: Use keyword matching for legacy/unmapped categories
    if (_containsScope1Keywords(categoryLower)) {
      return const Color(0xFF059669); // Green for Scope 1
    }

    if (_containsScope2Keywords(categoryLower)) {
      return const Color(0xFF3B82F6); // Blue for Scope 2
    }

    // Default color for truly unclassified categories
    return Colors.grey;
  }

  // Fallback keyword matching for legacy categories not in Constants
  bool _containsScope1Keywords(String categoryName) {
    final scope1Keywords = [
      'fuel', 'gasoline', 'diesel', 'natural gas', 'lpg', 'coal', 'kerosene',
      'mobile', 'vehicle', 'transport', 'combustion', 'stationary', 'biomass',
      'bagasse', 'biogas', 'wood', 'anthracite', 'bituminous', 'lignite',
      'refrigerant', 'fugitive', 'cng', 'heavy fuel oil', 'gas oil',
      'equipment', 'machinery', 'agriculture', 'forestry', 'construction',
      'r-', 'hfc', 'pfc', 'sf6', 'nf3'  // Refrigerant codes
    ];

    return scope1Keywords.any((keyword) => categoryName.contains(keyword));
  }

  // Fallback keyword matching for legacy categories not in Constants
  bool _containsScope2Keywords(String categoryName) {
    final scope2Keywords = [
      'electricity', 'electric', 'grid', 'power', 'energy', 'kwh'
    ];

    return scope2Keywords.any((keyword) => categoryName.contains(keyword));
  }

  // Enhanced Chart Implementations
  Widget _buildEnhancedLineChart() {
    final monthlyData = _dashboardData['monthly_trend'] as List? ?? [];
    final lastYearData = _dashboardData['last_year_trend'] as List? ?? [];

    List<dynamic> displayData = _getFilteredMonthlyData(monthlyData);
    List<dynamic> displayLastYear = _getFilteredMonthlyData(lastYearData);

    final hasCurrentYearData = displayData.any((m) => (m['total'] ?? 0) > 0);
    final hasLastYearData = displayLastYear.any((m) => (m['total'] ?? 0) > 0);

    if (!hasCurrentYearData && !hasLastYearData) {
      return _buildEmptyChartState();
    }

    double maxY = 0;
    for (var data in displayData) {
      if (data['total'] > maxY) maxY = data['total'].toDouble();
    }
    if (_showComparison) {
      for (var data in displayLastYear) {
        if (data['total'] > maxY) maxY = data['total'].toDouble();
      }
    }
    maxY = maxY * 1.2;

    return SizedBox(
      height: 280,
      child: LineChart(
        LineChartData(
          maxY: maxY > 0 ? maxY : 100,
          minY: 0,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 5,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey[200]!,
                strokeWidth: 1,
                dashArray: [5, 5],
              );
            },
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const Text('0');
                  return Text(
                    '${(value / 1000).toStringAsFixed(1)}k',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final months = _getMonthLabels();
                  if (value.toInt() >= 0 && value.toInt() < months.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        months[value.toInt()],
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final month = _getMonthLabels()[spot.x.toInt()];
                  final year = spot.barIndex == 0
                      ? _dashboardData['current_year']
                      : _dashboardData['last_year'];
                  return LineTooltipItem(
                    '$month $year\n${spot.y.toStringAsFixed(0)} kg CO₂',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  );
                }).toList();
              },
            ),
          ),
          lineBarsData: [
            if (hasCurrentYearData)
              LineChartBarData(
                spots: displayData.asMap().entries.map((entry) {
                  return FlSpot(
                    entry.key.toDouble(),
                    (entry.value['total'] ?? 0).toDouble(),
                  );
                }).toList(),
                isCurved: true,
                curveSmoothness: 0.3,
                color: const Color(0xFF059669),
                barWidth: 3,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) {
                    return FlDotCirclePainter(
                      radius: 5,
                      color: const Color(0xFF059669),
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    );
                  },
                ),
                shadow: const Shadow(
                  color: Color(0xFF059669),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ),
            if (hasLastYearData && _showComparison)
              LineChartBarData(
                spots: displayLastYear.asMap().entries.map((entry) {
                  return FlSpot(
                    entry.key.toDouble(),
                    (entry.value['total'] ?? 0).toDouble(),
                  );
                }).toList(),
                isCurved: true,
                curveSmoothness: 0.3,
                color: Colors.grey[400],
                barWidth: 2,
                dashArray: [8, 4],
                dotData: const FlDotData(show: false),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedAreaChart() {
    final monthlyData = _dashboardData['monthly_trend'] as List? ?? [];
    final lastYearData = _dashboardData['last_year_trend'] as List? ?? [];

    List<dynamic> displayData = _getFilteredMonthlyData(monthlyData);
    List<dynamic> displayLastYear = _getFilteredMonthlyData(lastYearData);

    final hasCurrentYearData = displayData.any((m) => (m['total'] ?? 0) > 0);
    final hasLastYearData = displayLastYear.any((m) => (m['total'] ?? 0) > 0);

    if (!hasCurrentYearData && !hasLastYearData) {
      return _buildEmptyChartState();
    }

    double maxY = 0;
    for (var data in displayData) {
      if (data['total'] > maxY) maxY = data['total'].toDouble();
    }
    if (_showComparison) {
      for (var data in displayLastYear) {
        if (data['total'] > maxY) maxY = data['total'].toDouble();
      }
    }
    maxY = maxY * 1.2;

    return SizedBox(
      height: 280,
      child: LineChart(
        LineChartData(
          maxY: maxY > 0 ? maxY : 100,
          minY: 0,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey[200]!,
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const Text('0');
                  return Text(
                    '${(value / 1000).toStringAsFixed(1)}k',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final months = _getMonthLabels();
                  if (value.toInt() >= 0 && value.toInt() < months.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        months[value.toInt()],
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            if (hasCurrentYearData)
              LineChartBarData(
                spots: displayData.asMap().entries.map((entry) {
                  return FlSpot(
                    entry.key.toDouble(),
                    (entry.value['total'] ?? 0).toDouble(),
                  );
                }).toList(),
                isCurved: true,
                curveSmoothness: 0.35,
                color: const Color(0xFF059669),
                barWidth: 3,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) {
                    return FlDotCirclePainter(
                      radius: 4,
                      color: const Color(0xFF059669),
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    );
                  },
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF059669).withOpacity(0.4),
                      const Color(0xFF059669).withOpacity(0.1),
                      const Color(0xFF059669).withOpacity(0.0),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            if (hasLastYearData && _showComparison)
              LineChartBarData(
                spots: displayLastYear.asMap().entries.map((entry) {
                  return FlSpot(
                    entry.key.toDouble(),
                    (entry.value['total'] ?? 0).toDouble(),
                  );
                }).toList(),
                isCurved: true,
                curveSmoothness: 0.35,
                color: Colors.grey[400],
                barWidth: 2,
                dashArray: [5, 5],
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: Colors.grey[300]!.withOpacity(0.15),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildScopeDonutChart() {
    final categoryData = _dashboardData['category_breakdown'] as Map? ?? {};

    double scope1Total = 0.0;
    double scope2Total = 0.0;

    for (final entry in categoryData.entries) {
      final categoryName = entry.key.toString().toLowerCase();
      final value = (entry.value ?? 0).toDouble();

      final scope = Constants.getCategoryScope(categoryName);
      if (scope == 1) {
        scope1Total += value;
      } else if (scope == 2) {
        scope2Total += value;
      } else {
        if (_containsScope2Keywords(categoryName)) {
          scope2Total += value;
        } else if (_containsScope1Keywords(categoryName)) {
          scope1Total += value;
        } else {
          if (categoryName.contains('electric') || categoryName.contains('grid') || categoryName.contains('power')) {
            scope2Total += value;
          } else {
            scope1Total += value;
          }
        }
      }
    }

    final total = scope1Total + scope2Total;

    if (total <= 0) {
      return _buildEmptyChartState();
    }

    return SizedBox(
      height: 280,
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: PieChart(
              PieChartData(
                centerSpaceRadius: 80,
                sectionsSpace: 3,
                sections: [
                  PieChartSectionData(
                    value: scope1Total,
                    title: '${(scope1Total / total * 100).toStringAsFixed(1)}%',
                    color: const Color(0xFFEF4444),
                    radius: 60,
                    titleStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  PieChartSectionData(
                    value: scope2Total,
                    title: '${(scope2Total / total * 100).toStringAsFixed(1)}%',
                    color: const Color(0xFF3B82F6),
                    radius: 60,
                    titleStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDonutLegendItem(
                  'Scope 1',
                  scope1Total,
                  total,
                  const Color(0xFFEF4444),
                ),
                const SizedBox(height: 16),
                _buildDonutLegendItem(
                  'Scope 2',
                  scope2Total,
                  total,
                  const Color(0xFF3B82F6),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${total.toStringAsFixed(0)} kg',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonutLegendItem(String label, double value, double total, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 24),
          child: Text(
            '${value.toStringAsFixed(0)} kg',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScopeBarChart() {
    final categoryData = _dashboardData['category_breakdown'] as Map? ?? {};

    double scope1Total = 0.0;
    double scope2Total = 0.0;

    for (final entry in categoryData.entries) {
      final categoryName = entry.key.toString().toLowerCase();
      final value = (entry.value ?? 0).toDouble();

      final scope = Constants.getCategoryScope(categoryName);
      if (scope == 1) {
        scope1Total += value;
      } else if (scope == 2) {
        scope2Total += value;
      } else {
        if (_containsScope2Keywords(categoryName)) {
          scope2Total += value;
        } else if (_containsScope1Keywords(categoryName)) {
          scope1Total += value;
        } else {
          if (categoryName.contains('electric') || categoryName.contains('grid') || categoryName.contains('power')) {
            scope2Total += value;
          } else {
            scope1Total += value;
          }
        }
      }
    }

    final total = scope1Total + scope2Total;

    if (total <= 0) {
      return _buildEmptyChartState();
    }

    final maxY = (scope1Total > scope2Total ? scope1Total : scope2Total) * 1.2;

    return SizedBox(
      height: 280,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final label = groupIndex == 0 ? 'Scope 1' : 'Scope 2';
                return BarTooltipItem(
                  '$label\n${rod.toY.toStringAsFixed(0)} kg CO₂',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  switch (value.toInt()) {
                    case 0:
                      return const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Scope 1',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    case 1:
                      return const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Scope 2',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    default:
                      return const Text('');
                  }
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${(value / 1000).toStringAsFixed(1)}k',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey[200]!,
                strokeWidth: 1,
              );
            },
          ),
          borderData: FlBorderData(show: false),
          barGroups: [
            BarChartGroupData(
              x: 0,
              barRods: [
                BarChartRodData(
                  toY: scope1Total,
                  color: const Color(0xFFEF4444),
                  width: 60,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(8),
                  ),
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFEF4444),
                      const Color(0xFFEF4444).withOpacity(0.7),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ],
            ),
            BarChartGroupData(
              x: 1,
              barRods: [
                BarChartRodData(
                  toY: scope2Total,
                  color: const Color(0xFF3B82F6),
                  width: 60,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(8),
                  ),
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF3B82F6),
                      const Color(0xFF3B82F6).withOpacity(0.7),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyChartState() {
    return SizedBox(
      height: 280,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.insert_chart_outlined, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              'No data available',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<dynamic> _getFilteredMonthlyData(List<dynamic> yearData) {
    if (_timeRange == '3months') {
      final now = DateTime.now();
      final currentMonth = now.month - 1;
      final startMonth = (currentMonth - 2).clamp(0, 11);
      return yearData.sublist(startMonth, currentMonth + 1);
    } else if (_timeRange == '6months') {
      final now = DateTime.now();
      final currentMonth = now.month - 1;
      final startMonth = (currentMonth - 5).clamp(0, 11);
      return yearData.sublist(startMonth, currentMonth + 1);
    }
    return yearData;
  }

  List<String> _getMonthLabels() {
    const allMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    if (_timeRange == '3months') {
      final now = DateTime.now();
      final currentMonth = now.month - 1;
      final startMonth = (currentMonth - 2).clamp(0, 11);
      return allMonths.sublist(startMonth, currentMonth + 1);
    } else if (_timeRange == '6months') {
      final now = DateTime.now();
      final currentMonth = now.month - 1;
      final startMonth = (currentMonth - 5).clamp(0, 11);
      return allMonths.sublist(startMonth, currentMonth + 1);
    }
    return allMonths;
  }

  // Modern UI Components
  PreferredSizeWidget _buildModernAppBar(LocalizationService localization) {
    return AppBar(
      title: Text(
        localization.isThaiLanguage ? 'แดชบอร์ดคาร์บอน' : 'Carbon Dashboard',
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
      ),
      backgroundColor: const Color(0xFF059669),
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _loadDashboardData,
          tooltip: localization.isThaiLanguage ? 'รีเฟรชข้อมูล' : 'Refresh Data',
        ),
        IconButton(
          icon: const Icon(Icons.tune_rounded),
          onPressed: _showTargetSettings,
          tooltip: localization.settings,
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildModernDrawer(LocalizationService localization) {
    return Drawer(
      child: Column(
        children: [
          Container(
            height: 200,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF059669), Color(0xFF047857)],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.eco_rounded,
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      localization.appTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      localization.smartDashboard,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // Language Switcher in Sidebar
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: ListTile(
                    leading: Icon(Icons.language, color: Colors.green[700]),
                    title: Text(
                      localization.isThaiLanguage ? 'เปลี่ยนภาษา' : 'Change Language',
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
                _buildDrawerItem(
                  icon: Icons.dashboard_rounded,
                  title: localization.smartDashboard,
                  isSelected: true,
                  onTap: () => Navigator.pop(context),
                ),
                _buildDrawerItem(
                  icon: Icons.add_circle_rounded,
                  title: localization.addEmission,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddEmissionScreen()),
                    ).then((_) => _loadDashboardData());
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.upload_file_rounded,
                  title: localization.uploadData,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => UploadDataScreen()),
                    ).then((_) => _loadDashboardData());
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.assessment_rounded,
                  title: localization.generateReport,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ReportGenerationScreen()),
                    );
                  },
                ),
                // Show edit/delete requests only for NON-admin users
                if (_dashboardData['is_admin'] != true)
                  _buildDrawerItem(
                    icon: Icons.edit_note_rounded,
                    title: localization.isThaiLanguage 
                      ? 'คำขอแก้ไข/ลบข้อมูล' 
                      : 'Edit/Delete Requests',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const EditRequestScreen()),
                      );
                    },
                  ),
                // Show admin panel only for admin users
                if (_dashboardData['is_admin'] == true)
                  _buildDrawerItem(
                    icon: Icons.admin_panel_settings_rounded,
                    title: localization.isThaiLanguage ? 'แผงผู้ดูแลระบบ' : 'Admin Panel',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AdminScreen()),
                      );
                    },
                  ),
                const Divider(height: 32),
                _buildDrawerItem(
                  icon: Icons.settings_rounded,
                  title: localization.isThaiLanguage ? 'เป้าหมายรายเดือน' : 'Monthly target',
                  onTap: () {
                    Navigator.pop(context);
                    _showTargetSettings();
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.logout_rounded,
                  title: localization.isThaiLanguage ? 'ออกจากระบบ' : 'Logout',
                  onTap: () async {
                    Navigator.pop(context);
                    await ApiService.clearToken();
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? const Color(0xFF059669) : Colors.grey[600],
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? const Color(0xFF059669) : Colors.grey[800],
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        selected: isSelected,
        selectedTileColor: const Color(0xFF059669).withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildLoadingView() {
    return Consumer<LocalizationService>(
      builder: (context, localization, child) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                color: Color(0xFF059669),
                strokeWidth: 3,
              ),
              const SizedBox(height: 16),
              Text(
                localization.isThaiLanguage ? 'กำลังโหลดแดชบอร์ด...' : 'Loading dashboard...',
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWelcomeHeader() {
    final currentMonth = _dashboardData['current_month'] ?? DateTime.now().month;
    final monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF059669), Color(0xFF047857)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF059669).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Shared Dashboard',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.people, size: 12, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'All Users',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${monthNames[currentMonth - 1]} Overview',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _dashboardData.containsKey('total_users') && _dashboardData.containsKey('users_with_data') 
                    ? 'Collective data from ${_dashboardData['users_with_data']}/${_dashboardData['total_users']} users'
                    : 'View collective carbon footprint across all users',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.public,
              size: 32,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernAlertCard() {
    final exceeded = (_dashboardData['current_month_total'] ?? 0) - _monthlyTarget;
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red[50]!, Colors.red[100]!],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.warning_rounded, color: Colors.red[700], size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Monthly Target Exceeded!',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red[700],
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Over target by ${exceeded.toStringAsFixed(0)} kg CO₂',
                  style: TextStyle(color: Colors.red[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryIncreaseCard() {
    final warnings = _detectCategoryIncreases(threshold: 50.0);
    if (warnings.isEmpty) return const SizedBox.shrink();

    final topWarning = warnings.first;
    final category = Constants.getCategoryDisplayName(topWarning['category']);
    final percentage = topWarning['increase_percentage'].toStringAsFixed(0);

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange[50]!, Colors.orange[100]!],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: InkWell(
        onTap: _showCategoryWarnings,
        borderRadius: BorderRadius.circular(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.trending_up_rounded, color: Colors.orange[700], size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Emission Spike Detected!',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[700],
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$category increased by $percentage% vs last month',
                    style: TextStyle(color: Colors.orange[600]),
                  ),
                  if (warnings.length > 1) ...[
                    const SizedBox(height: 4),
                    Text(
                      '+${warnings.length - 1} more ${warnings.length - 1 == 1 ? 'category' : 'categories'}',
                      style: TextStyle(
                        color: Colors.orange[500],
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.orange[600], size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStatsGrid() {
    final currentMonth = _dashboardData['current_month_total'] ?? 0;
    final monthChange = _dashboardData['month_change_percentage'] ?? 0;
    final currentYear = _dashboardData['current_year_total'] ?? 0;
    
    // Calculate scope totals for current month
    final categoryData = _dashboardData['category_breakdown'] as Map? ?? {};
    double scope1Month = 0.0;
    double scope2Month = 0.0;

    for (final entry in categoryData.entries) {
      final categoryName = entry.key.toString().toLowerCase();
      final value = (entry.value ?? 0).toDouble();

      final scope = Constants.getCategoryScope(categoryName);
      if (scope == 1) {
        scope1Month += value;
      } else if (scope == 2) {
        scope2Month += value;
      } else {
        // Fallback to keyword matching for unmapped categories
        if (_containsScope1Keywords(categoryName)) {
          scope1Month += value;
        } else if (_containsScope2Keywords(categoryName)) {
          scope2Month += value;
        } else {
          // Default to Scope 1 for unknown categories
          scope1Month += value;
        }
      }
    }
    
    // Calculate scope totals for current year
    // We'll need to get this from yearly data if available, otherwise estimate from monthly
    final yearlyScope1 = _dashboardData['scope1_year_total'] ?? scope1Month;
    final yearlyScope2 = _dashboardData['scope2_year_total'] ?? scope2Month;
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildModernStatCard(
            title: 'This Month',
            value: '${currentMonth.toStringAsFixed(0)}',
            unit: 'kg CO₂',
            icon: Icons.calendar_month_rounded,
            color: const Color(0xFF3B82F6),
            trend: monthChange,
          ),
          const SizedBox(width: 12),
          _buildModernStatCard(
            title: 'Target Progress',
            value: '${(currentMonth / _monthlyTarget * 100).toStringAsFixed(0)}',
            unit: '%',
            icon: Icons.track_changes_rounded,
            color: currentMonth > _monthlyTarget ? const Color(0xFFEF4444) : const Color(0xFF10B981),
            subtitle: 'of ${_monthlyTarget.toStringAsFixed(0)} kg',
          ),
          const SizedBox(width: 12),
          _buildModernStatCard(
            title: 'Scope 1 - Month',
            value: '${scope1Month.toStringAsFixed(0)}',
            unit: 'kg CO₂',
            icon: Icons.local_fire_department_rounded,
            color: const Color(0xFF059669),
            subtitle: 'Direct emissions',
          ),
          const SizedBox(width: 12),
          _buildModernStatCard(
            title: 'Scope 2 - Month',
            value: '${scope2Month.toStringAsFixed(0)}',
            unit: 'kg CO₂',
            icon: Icons.bolt_rounded,
            color: const Color(0xFF3B82F6),
            subtitle: 'Energy indirect',
          ),
          const SizedBox(width: 12),
          _buildModernStatCard(
            title: 'Scope 1 - Year',
            value: '${yearlyScope1.toStringAsFixed(0)}',
            unit: 'kg CO₂',
            icon: Icons.local_fire_department_rounded,
            color: const Color(0xFF047857),
            subtitle: 'Direct YTD',
          ),
          const SizedBox(width: 12),
          _buildModernStatCard(
            title: 'Scope 2 - Year',
            value: '${yearlyScope2.toStringAsFixed(0)}',
            unit: 'kg CO₂',
            icon: Icons.bolt_rounded,
            color: const Color(0xFF2563EB),
            subtitle: 'Energy YTD',
          ),
          const SizedBox(width: 12),
          _buildModernStatCard(
            title: 'Year Total',
            value: '${currentYear.toStringAsFixed(0)}',
            unit: 'kg CO₂',
            icon: Icons.trending_up_rounded,
            color: const Color(0xFF8B5CF6),
            subtitle: 'Since January',
          ),
          const SizedBox(width: 12),
          _buildModernStatCard(
            title: 'YoY Change',
            value: '${(_dashboardData['year_change_percentage'] ?? 0).abs().toStringAsFixed(1)}',
            unit: '%',
            icon: (_dashboardData['year_change_percentage'] ?? 0) < 0 
                ? Icons.arrow_downward_rounded 
                : Icons.arrow_upward_rounded,
            color: (_dashboardData['year_change_percentage'] ?? 0) < 0 
                ? const Color(0xFF10B981) 
                : const Color(0xFFEF4444),
            subtitle: (_dashboardData['year_change_percentage'] ?? 0) < 0 
                ? 'Decreased' 
                : 'Increased',
            trend: _dashboardData['year_change_percentage'] ?? 0,
          ),
          const SizedBox(width: 12),
          _buildModernStatCard(
            title: 'Records',
            value: '${_dashboardData['record_count'] ?? 0}',
            unit: 'entries',
            icon: Icons.receipt_long_rounded,
            color: const Color(0xFF06B6D4),
            subtitle: 'This month',
          ),
        ],
      ),
    );
  }

  Widget _buildModernStatCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
    String? subtitle,
    double? trend,
  }) {
    return Container(
      width: 190,
      height: 152, // Increased height by 2 pixels to fix overflow
      padding: const EdgeInsets.all(14),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // Use minimum size needed
        children: [
          // Top row with icon and trend - flexible height
          SizedBox(
            height: 30, // Slightly reduced height
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
                if (trend != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: trend > 0 ? Colors.red[50] : Colors.green[50],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${trend > 0 ? "+" : ""}${trend.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: trend > 0 ? Colors.red[600] : Colors.green[600],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          const SizedBox(height: 10), // Reduced spacing
          
          // Value and unit section - flexible but constrained
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(height: 1), // Reduced spacing
                Flexible(
                  child: Text(
                    unit,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
          
          // Bottom section with title and subtitle - constrained height
          Container(
            height: subtitle != null ? 34 : 22, // Slightly reduced heights
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 1), // Reduced spacing
                  Flexible(
                    child: Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.grey[500],
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
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

  Widget _buildChartsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Analytics',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            _buildChartTypeSelector(),
          ],
        ),
        const SizedBox(height: 16),

        // Trend Chart with Type Selection
        _buildTrendChartCard(),
        const SizedBox(height: 16),

        // Category Breakdown with Type Selection
        _buildCategoryChartCard(),
      ],
    );
  }

  Widget _buildChartTypeSelector() {
    return PopupMenuButton<String>(
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF059669).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.tune,
          color: Color(0xFF059669),
          size: 20,
        ),
      ),
      tooltip: 'Chart Settings',
      itemBuilder: (context) => [
        const PopupMenuItem(
          enabled: false,
          child: Text(
            'Chart Settings',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Trend Chart Type:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildChartTypeOption('line', Icons.show_chart, 'Line'),
                  const SizedBox(width: 8),
                  _buildChartTypeOption('area', Icons.area_chart, 'Area'),
                  const SizedBox(width: 8),
                  _buildChartTypeOption('bar', Icons.bar_chart, 'Bar'),
                ],
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Category Chart Type:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildCategoryChartTypeOption('pie', Icons.pie_chart, 'Pie'),
                  const SizedBox(width: 8),
                  _buildCategoryChartTypeOption('donut', Icons.donut_small, 'Donut'),
                  const SizedBox(width: 8),
                  _buildCategoryChartTypeOption('bar', Icons.bar_chart, 'Bar'),
                ],
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        CheckedPopupMenuItem(
          checked: _showComparison,
          value: 'toggle_comparison',
          child: const Text('Show Year Comparison'),
          onTap: () {
            setState(() {
              _showComparison = !_showComparison;
            });
          },
        ),
      ],
    );
  }

  Widget _buildChartTypeOption(String type, IconData icon, String label) {
    final isSelected = _trendChartType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _trendChartType = type;
        });
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF059669) : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : Colors.grey[700],
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.white : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChartTypeOption(String type, IconData icon, String label) {
    final isSelected = _categoryChartType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _categoryChartType = type;
        });
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF8B5CF6) : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : Colors.grey[700],
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.white : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendChartCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _trendChartType == 'line' ? Icons.show_chart_rounded :
                      _trendChartType == 'area' ? Icons.area_chart_rounded :
                      Icons.bar_chart_rounded,
                      color: const Color(0xFF059669),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Monthly Emissions Trend',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              _buildTimeRangeSelector(),
            ],
          ),
          const SizedBox(height: 24),

          // Render chart based on selected type
          if (_trendChartType == 'line')
            _buildEnhancedLineChart()
          else if (_trendChartType == 'area')
            _buildEnhancedAreaChart()
          else
            _buildMonthlyBarChart(),
        ],
      ),
    );
  }

  Widget _buildTimeRangeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _buildTimeRangeButton('3months', '3M'),
          _buildTimeRangeButton('6months', '6M'),
          _buildTimeRangeButton('year', '1Y'),
        ],
      ),
    );
  }

  Widget _buildTimeRangeButton(String range, String label) {
    final isSelected = _timeRange == range;
    return GestureDetector(
      onTap: () {
        setState(() {
          _timeRange = range;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF059669) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChartCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _categoryChartType == 'pie' ? Icons.pie_chart_rounded :
                  _categoryChartType == 'donut' ? Icons.donut_small :
                  Icons.bar_chart_rounded,
                  color: const Color(0xFF8B5CF6),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Emissions by Scope',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Render chart based on selected type
          if (_categoryChartType == 'pie')
            _buildScopeComparisonPieChart()
          else if (_categoryChartType == 'donut')
            _buildScopeDonutChart()
          else
            _buildScopeBarChart(),
        ],
      ),
    );
  }

  Widget _buildModernCategoryBreakdown() {
    final categoryData = _dashboardData['category_breakdown'] as Map? ?? {};

    if (categoryData.isEmpty) return const SizedBox.shrink();

    // Normalize and merge duplicate categories
    final normalizedCategoryData = <String, double>{};
    for (final entry in categoryData.entries) {
      final value = (entry.value ?? 0).toDouble();
      if (value > 0.01) { // Filter out very small values
        // Normalize category key: lowercase, replace spaces/dashes/parentheses with underscores
        String normalizedKey = entry.key.toString()
            .toLowerCase()
            .trim()
            .replaceAll(RegExp(r'[-()\s]+'), '_')  // Replace all spaces, dashes, parens with underscore
            .replaceAll(RegExp(r'_+'), '_')        // Replace multiple underscores with single
            .replaceAll(RegExp(r'^_|_$'), '');     // Remove leading/trailing underscores

        // Sum up values for the same normalized category
        normalizedCategoryData[normalizedKey] =
            (normalizedCategoryData[normalizedKey] ?? 0.0) + value;
      }
    }

    if (normalizedCategoryData.isEmpty) return const SizedBox.shrink();

    // Calculate total for percentages using normalized data
    final total = normalizedCategoryData.values.fold<double>(0, (sum, value) => sum + value);

    // If total is 0 or negative, don't show the breakdown
    if (total <= 0) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.pie_chart_rounded,
                  color: Color(0xFF8B5CF6),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Emissions by Category',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...normalizedCategoryData.entries.map((entry) {
            // Ensure entry.value is not negative and total is positive
            final safeValue = entry.value < 0 ? 0.0 : entry.value.toDouble();
            final percentage = total > 0 ? (safeValue / total * 100).toStringAsFixed(1) : '0.0';
            final color = _getCategoryColor(entry.key);

            // Calculate safe width factor (between 0.0 and 1.0)
            double widthFactor = 0.0;
            if (total > 0 && safeValue > 0) {
              widthFactor = (safeValue / total).clamp(0.0, 1.0);
            }

            // Get friendly display name from Constants
            final displayName = Constants.getCategoryDisplayName(entry.key);

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${safeValue.toStringAsFixed(0)} kg ($percentage%)',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: Colors.grey[200],
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: widthFactor,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: color,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  title: 'Add Data',
                  icon: Icons.add_rounded,
                  color: const Color(0xFF059669),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddEmissionScreen()),
                    ).then((_) => _loadDashboardData());
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  title: 'Upload',
                  icon: Icons.upload_rounded,
                  color: const Color(0xFF3B82F6),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => UploadDataScreen()),
                    ).then((_) => _loadDashboardData());
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  title: 'Reports',
                  icon: Icons.description_rounded,
                  color: const Color(0xFF8B5CF6),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ReportGenerationScreen()),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernFAB() {
    return FloatingActionButton.extended(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddEmissionScreen()),
        ).then((_) => _loadDashboardData());
      },
      backgroundColor: const Color(0xFF059669),
      foregroundColor: Colors.white,
      elevation: 8,
      icon: const Icon(Icons.add_rounded),
      label: const Text(
        'Add Emission',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildMonthlyBarChart() {
    // Use actual data from dashboard or show empty state
    final monthlyData = _dashboardData['monthly_trend'] as List? ?? [];
    final lastYearData = _dashboardData['last_year_trend'] as List? ?? [];
    final hasCurrentYearData = monthlyData.any((m) => (m['total'] ?? 0) > 0);
    final hasLastYearData = lastYearData.any((m) => (m['total'] ?? 0) > 0);
    
    // If no data, show empty state
    if (!hasCurrentYearData && !hasLastYearData) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
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
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.show_chart_rounded,
                    color: Color(0xFF059669),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Monthly Comparison (${DateTime.now().year} vs ${DateTime.now().year - 1})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            Center(
              child: Column(
                children: [
                  Icon(Icons.show_chart, size: 60, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No emission data available',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add emission records to see monthly trends',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      );
    }

    // Create flat line chart data showing actual data or zeros
    List<LineChartBarData> lineBarsData = [];
    
    if (hasCurrentYearData) {
      lineBarsData.add(
        LineChartBarData(
          spots: monthlyData.asMap().entries.map((entry) {
            return FlSpot(entry.key.toDouble(), (entry.value['total'] ?? 0).toDouble());
          }).toList(),
          isCurved: true,
          color: const Color(0xFF059669),
          barWidth: 3,
          dotData: const FlDotData(show: true),
          belowBarData: BarAreaData(
            show: true,
            color: const Color(0xFF059669).withOpacity(0.1),
          ),
        ),
      );
    }
    
    if (hasLastYearData) {
      lineBarsData.add(
        LineChartBarData(
          spots: lastYearData.asMap().entries.map((entry) {
            return FlSpot(entry.key.toDouble(), (entry.value['total'] ?? 0).toDouble());
          }).toList(),
          isCurved: true,
          color: const Color(0xFF6B7280),
          barWidth: 2,
          dashArray: [5, 5],
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.show_chart_rounded,
                  color: Color(0xFF059669),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Monthly Comparison (${DateTime.now().year} vs ${DateTime.now().year - 1})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Legend for year comparison
          Row(
            children: [
              // This Year
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${DateTime.now().year} Total', style: const TextStyle(fontSize: 12)),
                ],
              ),
              const SizedBox(width: 24),
              // Last Year
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 16,
                    height: 3,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6B7280),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${DateTime.now().year - 1} Total', style: const TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Line Chart
          SizedBox(
            height: 250,
            child: LineChart(
              LineChartData(
                maxY: 10000,
                minY: 0,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey[300]!,
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text('${value.toInt()}', style: const TextStyle(fontSize: 10));
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const months = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];
                        if (value.toInt() >= 0 && value.toInt() < months.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              months[value.toInt()],
                              style: const TextStyle(fontSize: 12),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: lineBarsData,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: Colors.grey[800]!,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final month = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                                     'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][spot.x.toInt()];
                        final isCurrentYear = spot.barIndex == 0;
                        final year = isCurrentYear ? DateTime.now().year : DateTime.now().year - 1;
                        
                        return LineTooltipItem(
                          '$month $year\nTotal: ${spot.y.toStringAsFixed(0)} kg CO₂',
                          const TextStyle(color: Colors.white, fontSize: 12),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScopeComparisonPieChart() {
    // Calculate scope totals from category breakdown using scope categorization
    final categoryData = _dashboardData['category_breakdown'] as Map? ?? {};
    
    double scope1Total = 0.0;
    double scope2Total = 0.0;
    
    // Categorize emissions by scope based on category names and TGO structure
    for (final entry in categoryData.entries) {
      final categoryName = entry.key.toString().toLowerCase();
      final value = (entry.value ?? 0).toDouble();

      final scope = Constants.getCategoryScope(categoryName);
      if (scope == 1) {
        scope1Total += value;
      } else if (scope == 2) {
        scope2Total += value;
      } else {
        // Fallback to keyword matching for unmapped categories
        if (_containsScope2Keywords(categoryName)) {
          scope2Total += value;
        } else if (_containsScope1Keywords(categoryName)) {
          scope1Total += value;
        } else {
          // Default: Most emissions are Scope 1 unless specifically electricity
          if (categoryName.contains('electric') || categoryName.contains('grid') || categoryName.contains('power')) {
            scope2Total += value;
          } else {
            scope1Total += value;
          }
        }
      }
    }
    
    final total = scope1Total + scope2Total;
    
    // If no data, show empty gray pie chart
    if (total <= 0) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
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
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.pie_chart_rounded,
                    color: Color(0xFF8B5CF6),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Scope Comparison',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            Row(
              children: [
                // Empty Gray Pie Chart
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 200,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 0,
                        centerSpaceRadius: 40,
                        sections: [
                          PieChartSectionData(
                            color: Colors.grey[300]!,
                            value: 100,
                            title: '',
                            radius: 60,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Empty State Message
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.pie_chart_outline, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No scope data available',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add emission records to see scope breakdown',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }
    
    final scope1Percentage = (scope1Total / total * 100);
    final scope2Percentage = (scope2Total / total * 100);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.pie_chart_rounded,
                  color: Color(0xFF8B5CF6),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Scope Comparison',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          Row(
            children: [
              // Pie Chart
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 200,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: [
                        PieChartSectionData(
                          color: const Color(0xFF059669),
                          value: scope1Total,
                          title: '${scope1Percentage.toStringAsFixed(1)}%',
                          radius: 60,
                          titleStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        PieChartSectionData(
                          color: const Color(0xFF3B82F6),
                          value: scope2Total,
                          title: '${scope2Percentage.toStringAsFixed(1)}%',
                          radius: 60,
                          titleStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              // Legend and Details
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildScopeItem(
                      'Scope 1',
                      'Direct Emissions',
                      scope1Total,
                      scope1Percentage,
                      const Color(0xFF059669),
                    ),
                    const SizedBox(height: 16),
                    _buildScopeItem(
                      'Scope 2',
                      'Indirect Energy',
                      scope2Total,
                      scope2Percentage,
                      const Color(0xFF3B82F6),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Emissions',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            '${total.toStringAsFixed(0)} kg CO₂eq',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScopeItem(String title, String subtitle, double value, double percentage, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${value.toStringAsFixed(0)} kg',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showTargetSettings() {
    final controller = TextEditingController(text: _monthlyTarget.toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.track_changes_rounded, color: Color(0xFF059669)),
            SizedBox(width: 8),
            Text('Set Monthly Target'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Current target: ${_monthlyTarget.toStringAsFixed(0)} kg CO₂',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'New Target (kg CO₂)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.flag_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newTarget = double.tryParse(controller.text);
              if (newTarget != null && newTarget > 0) {
                setState(() {
                  _monthlyTarget = newTarget;
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Target updated to ${_monthlyTarget.toStringAsFixed(0)} kg'),
                    backgroundColor: const Color(0xFF059669),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid target'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
