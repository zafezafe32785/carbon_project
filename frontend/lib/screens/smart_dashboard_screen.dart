import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';
// import 'package:flutter/material.dart';
// import '../utils/constants.dart';
import 'add_emission_screen.dart';
import 'login_screen.dart';

class SmartDashboardScreen extends StatefulWidget {
  const SmartDashboardScreen({super.key});

  @override
  _SmartDashboardScreenState createState() => _SmartDashboardScreenState();
}

class _SmartDashboardScreenState extends State<SmartDashboardScreen> {
  Map<String, dynamic> _dashboardData = {};
  bool _isLoading = true;
  double _monthlyTarget = 5000; // Default target

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
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Smart Carbon Dashboard'),
            if (!_isLoading && _dashboardData['current_year'] != null)
              Text(
                'Year ${_dashboardData['current_year']}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        backgroundColor: Colors.green[700],
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showTargetSettings,
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _dashboardData['has_data'] == false
              ? _buildNoDataView()
              : RefreshIndicator(
                  onRefresh: _loadDashboardData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Alert if exceeding target
                        if ((_dashboardData['current_month_total'] ?? 0) > _monthlyTarget)
                          _buildAlertCard(),
                        
                        // Summary Cards Row
                        _buildSummaryCards(),
                        const SizedBox(height: 20),
                        
                        // Year Comparison Card
                        _buildYearComparisonCard(),
                        const SizedBox(height: 20),

                        _buildTestChart(), // Add this line
                        const SizedBox(height: 20),
                        
                        // Monthly Trend Chart
                        _buildMonthlyTrendChart(),
                        const SizedBox(height: 20),
                        
                        // Category Breakdown
                        if ((_dashboardData['category_breakdown'] as Map?)?.isNotEmpty ?? false)
                          _buildCategoryBreakdown(),
                      ],
                    ),
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddEmissionScreen()),
          ).then((_) => _loadDashboardData()); // Auto refresh after adding
        },
        backgroundColor: Colors.green[700],
        tooltip: 'Add Emission Data',
        child: const Icon(Icons.add),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.insert_chart_outlined, size: 100, color: Colors.grey[400]),
          const SizedBox(height: 20),
          Text(
            'No emission data yet',
            style: TextStyle(fontSize: 20, color: Colors.grey[600]),
          ),
          const SizedBox(height: 10),
          Text(
            'Start by adding your first emission record',
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
            label: const Text('Add First Emission'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            ),
          ),
        ],
      ),
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

    print('Category data: $categoryData'); // Add this debug line
    
    if (categoryData.isEmpty) return const SizedBox.shrink();
    
    // Calculate total for percentages
    final total = categoryData.values.fold<double>(0, (sum, value) => sum + value);
    
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
            ...categoryData.entries.map((entry) {
              final percentage = (entry.value / total * 100).toStringAsFixed(1);
              final color = _getCategoryColor(entry.key);
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
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
                            Text(
                              entry.key.toUpperCase(),
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
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
    final colors = {
      'electricity': Colors.blue,
      'fuel': Colors.orange,
      'diesel': Colors.orange,
      'gasoline': Colors.deepOrange,
      'natural_gas': Colors.red,
      'waste': Colors.purple,
      'transport': Colors.teal,
    };
    return colors[category] ?? Colors.grey;
  }

  void _showTargetSettings() {
    final controller = TextEditingController(text: _monthlyTarget.toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Monthly Target'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current target: ${_monthlyTarget.toStringAsFixed(0)} kg CO₂'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'New Target (kg CO₂)',
                border: OutlineInputBorder(),
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
           child: const Text('Save'),
         ),
       ],
     ),
   );
 }
}

