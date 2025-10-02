import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/localization_service.dart';
import '../utils/tgo_emission_factors.dart';

class AddEmissionScreen extends StatefulWidget {
  const AddEmissionScreen({super.key});

  @override
  _AddEmissionScreenState createState() => _AddEmissionScreenState();
}

class _AddEmissionScreenState extends State<AddEmissionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _searchController = TextEditingController();
  final LocalizationService _localization = LocalizationService();
  
  String? _selectedCategory;
  String? _selectedFuelKey;
  Map<String, dynamic>? _selectedFuel;
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  bool _isLoading = false;
  
  List<String> _categories = [];
  List<Map<String, dynamic>> _fuelsInCategory = [];
  List<Map<String, dynamic>> _filteredFuels = [];

  @override
  void initState() {
    super.initState();
    _categories = TGOEmissionFactors.getCategories();
    _searchController.addListener(_filterFuels);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onCategoryChanged(String? category) {
    setState(() {
      _selectedCategory = category;
      _selectedFuelKey = null;
      _selectedFuel = null;
      _fuelsInCategory = category != null 
          ? TGOEmissionFactors.getFuelsByCategory(category)
          : [];
      _filteredFuels = _fuelsInCategory;
      _searchController.clear();
    });
  }

  void _onFuelChanged(String? fuelKey) {
    setState(() {
      _selectedFuelKey = fuelKey;
      _selectedFuel = _filteredFuels.firstWhere(
        (fuel) => fuel['key'] == fuelKey,
        orElse: () => {},
      );
    });
  }

  void _filterFuels() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredFuels = _fuelsInCategory.where((fuel) {
        return fuel['name'].toString().toLowerCase().contains(query) ||
               fuel['unit'].toString().toLowerCase().contains(query);
      }).toList();
    });
  }

  double _calculateCO2Equivalent() {
    if (_selectedFuelKey == null || _amountController.text.isEmpty) return 0.0;
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    return TGOEmissionFactors.calculateCO2Equivalent(_selectedFuelKey!, amount);
  }

  Future<void> _submitEmission() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final amount = double.parse(_amountController.text);
    final co2Equivalent = _calculateCO2Equivalent();

    final result = await ApiService.addEmission(
      category: _selectedFuel!['name'],
      amount: amount,
      unit: _selectedFuel!['unit'],
      month: _selectedMonth,
      year: _selectedYear,
    );

    setState(() => _isLoading = false);

    if (result['success']) {
      final successMessage = _localization.isThaiLanguage 
        ? 'เพิ่มข้อมูลการปล่อยสำเร็จ!\n${_selectedFuel!['name']}: $amount ${_selectedFuel!['unit']}\n${_localization.co2Equivalent}: ${co2Equivalent.toStringAsFixed(2)} kg'
        : 'Emission added!\n${_selectedFuel!['name']}: $amount ${_selectedFuel!['unit']}\n${_localization.co2Equivalent}: ${co2Equivalent.toStringAsFixed(2)} kg';
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
      _resetForm();
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _resetForm() {
    _amountController.clear();
    _searchController.clear();
    setState(() {
      _selectedCategory = null;
      _selectedFuelKey = null;
      _selectedFuel = null;
      _fuelsInCategory = [];
      _filteredFuels = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_localization.addEmissionData),
        backgroundColor: Colors.green[700],
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showTGOInfo,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info Card
              Card(
                color: Colors.blue[50],
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _localization.usingTgoFactors,
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Step 1: Category Selection
              _buildSectionHeader('1. ${_localization.selectEmissionCategory}'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  hintText: _localization.chooseEmissionCategory,
                  prefixIcon: const Icon(Icons.category),
                ),
                items: _categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(
                      category,
                      style: const TextStyle(fontSize: 14),
                    ),
                  );
                }).toList(),
                onChanged: _onCategoryChanged,
                validator: (value) {
                  if (value == null) return _localization.pleaseSelectCategory;
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Step 2: Fuel Type Selection
              if (_selectedCategory != null) ...[
                _buildSectionHeader('2. ${_localization.selectFuelEnergyType}'),
                const SizedBox(height: 8),
                
                // Search field
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    hintText: _localization.searchFuelTypes,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _filterFuels();
                            },
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Fuel dropdown - exactly like category dropdown (single line only)
                DropdownButtonFormField<String>(
                  value: _selectedFuelKey,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    hintText: _localization.chooseFuelEnergyType,
                    prefixIcon: const Icon(Icons.local_gas_station),
                  ),
                  isExpanded: true,
                  menuMaxHeight: 400,
                  items: _filteredFuels.map((fuel) {
                    return DropdownMenuItem<String>(
                      value: fuel['key'] as String,
                      child: Text(
                        fuel['name'] as String,
                        style: const TextStyle(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: _onFuelChanged,
                  validator: (value) {
                    if (value == null) return _localization.pleaseSelectFuelType;
                    return null;
                  },
                ),
                const SizedBox(height: 20),
              ],

              // Step 3: Amount Input
              if (_selectedFuel != null) ...[
                _buildSectionHeader('3. ${_localization.enterConsumptionAmount}'),
                const SizedBox(height: 8),
                
                // Fuel info card
                Card(
                  color: Colors.green[50],
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedFuel!['name'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_localization.emissionFactor}: ${_selectedFuel!['factor']} kgCO₂eq/${_selectedFuel!['unit']}',
                          style: TextStyle(color: Colors.grey[700], fontSize: 12),
                        ),
                        if (_selectedFuel!['notes'].isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${_localization.note}: ${_selectedFuel!['notes']}',
                            style: TextStyle(color: Colors.grey[600], fontSize: 12, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    labelText: _localization.amount,
                    suffixText: _selectedFuel!['unit'],
                    hintText: _localization.enterConsumptionAmount,
                    prefixIcon: const Icon(Icons.straighten),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return _localization.pleaseEnterAmount;
                    }
                    if (double.tryParse(value) == null) {
                      return _localization.pleaseEnterValidNumber;
                    }
                    if (double.parse(value) <= 0) {
                      return _localization.amountMustBeGreaterThanZero;
                    }
                    return null;
                  },
                  onChanged: (value) {
                    setState(() {}); // Trigger rebuild to update CO2 calculation
                  },
                ),
                const SizedBox(height: 12),
                
                // CO2 Calculation Preview
                if (_amountController.text.isNotEmpty && double.tryParse(_amountController.text) != null) ...[
                  Card(
                    color: Colors.orange[50],
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(Icons.calculate, color: Colors.orange[700]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _localization.co2EquivalentCalculation,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '${_amountController.text} ${_selectedFuel!['unit']} × ${_selectedFuel!['factor']} = ${_calculateCO2Equivalent().toStringAsFixed(2)} kg CO₂eq',
                                  style: TextStyle(color: Colors.grey[700], fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
              ],

              // Step 4: Period Selection
              if (_selectedFuel != null) ...[
                _buildSectionHeader('4. ${_localization.selectReportingPeriod}'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // Month Dropdown
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _selectedMonth,
                        decoration: InputDecoration(
                          labelText: _localization.month,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(Icons.calendar_month),
                        ),
                        items: List.generate(12, (index) {
                          final month = index + 1;
                          return DropdownMenuItem(
                            value: month,
                            child: Text(_localization.getMonthName(month)),
                          );
                        }),
                        onChanged: (value) {
                          setState(() {
                            _selectedMonth = value!;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Year Dropdown
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _selectedYear,
                        decoration: InputDecoration(
                          labelText: _localization.year,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(Icons.calendar_today),
                        ),
                        items: List.generate(5, (index) {
                          final year = DateTime.now().year - index;
                          return DropdownMenuItem(
                            value: year,
                            child: Text(year.toString()),
                          );
                        }),
                        onChanged: (value) {
                          setState(() {
                            _selectedYear = value!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitEmission,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            _localization.addEmissionRecord,
                            style: const TextStyle(fontSize: 16, color: Colors.white),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Reset Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: _resetForm,
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(_localization.resetForm),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  void _showTGOInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_localization.tgoEmissionFactors),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _localization.tgoDescription,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('${_localization.updated} ${_localization.isThaiLanguage ? "เมษายน 2022" : "April 2022"}'),
              const SizedBox(height: 12),
              Text(_localization.tgoFactorsDescription),
              const SizedBox(height: 8),
              Text('• ${_localization.scope1}'),
              Text('• ${_localization.scope2}'),
              Text('• ${_localization.scope3}'),
              const SizedBox(height: 12),
              Text(
                _localization.allFactorsDescription,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_localization.close),
          ),
        ],
      ),
    );
  }
}
