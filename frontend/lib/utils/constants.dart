import 'package:flutter/material.dart';

class Constants {
  // API Configuration - Works in both development and production
  // In production (deployed), uses relative URL which goes through Nginx
  // In development, change to 'http://localhost:5000' if running locally
  static const String baseUrl = '';  // Empty = relative URLs (production)

  // API Endpoints
  static const String apiUrl = '/api';  // Relative URL goes through Nginx proxy
  
  // App Colors
  static const Color primaryColor = Color(0xFF2E7D32); // Green
  static const Color secondaryColor = Color(0xFF4CAF50);
  static const Color accentColor = Color(0xFF81C784);
  
  // TGO Emission Categories - Based on TGO Emission Factors
  static const List<String> emissionCategories = [
    // Scope 1 - Stationary Combustion (Fossil Fuels)
    'natural_gas_scf',
    'natural_gas_mj',
    'lignite_coal',
    'heavy_fuel_oil_a',
    'heavy_fuel_oil_c',
    'gas_diesel_oil',
    'anthracite_coal',
    'sub_bituminous_coal',
    'jet_kerosene',
    'lpg_litre',
    'lpg_kg',
    'motor_gasoline',
    
    // Scope 1 - Stationary Combustion (Biomass)
    'fuel_wood',
    'bagasse',
    'palm_kernel_shell',
    'corn_cob',
    'biogas',
    'fuel_wood_co2',
    'bagasse_co2',
    'palm_kernel_shell_co2',
    'corn_cob_co2',
    'biogas_co2',
    
    // Scope 1 - Mobile Combustion (On Road)
    'motor_gasoline_uncontrolled',
    'motor_gasoline_catalyst',
    'motor_gasoline_low_mileage',
    'gas_diesel_oil_mobile',
    'cng',
    'lpg_mobile_litre',
    'lpg_mobile_kg',
    
    // Scope 1 - Mobile Combustion (Off Road - Diesel)
    'diesel_agriculture',
    'diesel_forestry',
    'diesel_industrial',
    'diesel_household',
    
    // Scope 1 - Mobile Combustion (Off Road - Gasoline 4-Stroke)
    'gasoline_4s_agriculture',
    'gasoline_4s_forestry',
    'gasoline_4s_industrial',
    'gasoline_4s_household',
    
    // Scope 1 - Mobile Combustion (Off Road - Gasoline 2-Stroke)
    'gasoline_2s_agriculture',
    'gasoline_2s_forestry',
    'gasoline_2s_industrial',
    'gasoline_2s_household',
    
    // Scope 1 - Fugitive Emissions (Refrigerants)
    'r22',
    'r32',
    'r125',
    'r134',
    'r134a',
    'r143',
    'r143a',
    
    // Scope 2 - Purchased Electricity
    'grid_electricity',
  ];
  
  static const Map<String, String> categoryUnits = {
    // Scope 1 - Stationary Combustion (Fossil Fuels)
    'natural_gas_scf': 'scf',
    'natural_gas_mj': 'mj',
    'lignite_coal': 'kg',
    'heavy_fuel_oil_a': 'litre',
    'heavy_fuel_oil_c': 'litre',
    'gas_diesel_oil': 'litre',
    'anthracite_coal': 'kg',
    'sub_bituminous_coal': 'kg',
    'jet_kerosene': 'litre',
    'lpg_litre': 'litre',
    'lpg_kg': 'kg',
    'motor_gasoline': 'litre',
    
    // Scope 1 - Stationary Combustion (Biomass)
    'fuel_wood': 'kg',
    'bagasse': 'kg',
    'palm_kernel_shell': 'kg',
    'corn_cob': 'kg',
    'biogas': 'm³',
    'fuel_wood_co2': 'kg',
    'bagasse_co2': 'kg',
    'palm_kernel_shell_co2': 'kg',
    'corn_cob_co2': 'kg',
    'biogas_co2': 'm³',
    
    // Scope 1 - Mobile Combustion (On Road)
    'motor_gasoline_uncontrolled': 'litre',
    'motor_gasoline_catalyst': 'litre',
    'motor_gasoline_low_mileage': 'litre',
    'gas_diesel_oil_mobile': 'litre',
    'cng': 'kg',
    'lpg_mobile_litre': 'litre',
    'lpg_mobile_kg': 'kg',
    
    // Scope 1 - Mobile Combustion (Off Road - Diesel)
    'diesel_agriculture': 'litre',
    'diesel_forestry': 'litre',
    'diesel_industrial': 'litre',
    'diesel_household': 'litre',
    
    // Scope 1 - Mobile Combustion (Off Road - Gasoline 4-Stroke)
    'gasoline_4s_agriculture': 'litre',
    'gasoline_4s_forestry': 'litre',
    'gasoline_4s_industrial': 'litre',
    'gasoline_4s_household': 'litre',
    
    // Scope 1 - Mobile Combustion (Off Road - Gasoline 2-Stroke)
    'gasoline_2s_agriculture': 'litre',
    'gasoline_2s_forestry': 'litre',
    'gasoline_2s_industrial': 'litre',
    'gasoline_2s_household': 'litre',
    
    // Scope 1 - Fugitive Emissions (Refrigerants)
    'r22': 'kg',
    'r32': 'kg',
    'r125': 'kg',
    'r134': 'kg',
    'r134a': 'kg',
    'r143': 'kg',
    'r143a': 'kg',
    
    // Scope 2 - Purchased Electricity
    'grid_electricity': 'kwh',
  };
  
  static const Map<String, IconData> categoryIcons = {
    // Scope 1 - Stationary Combustion (Fossil Fuels)
    'natural_gas_scf': Icons.whatshot,
    'natural_gas_mj': Icons.whatshot,
    'lignite_coal': Icons.hardware,
    'heavy_fuel_oil_a': Icons.local_gas_station,
    'heavy_fuel_oil_c': Icons.local_gas_station,
    'gas_diesel_oil': Icons.local_gas_station,
    'anthracite_coal': Icons.hardware,
    'sub_bituminous_coal': Icons.hardware,
    'jet_kerosene': Icons.local_gas_station,
    'lpg_litre': Icons.propane_tank,
    'lpg_kg': Icons.propane_tank,
    'motor_gasoline': Icons.local_gas_station,
    
    // Scope 1 - Stationary Combustion (Biomass)
    'fuel_wood': Icons.nature,
    'bagasse': Icons.grass,
    'palm_kernel_shell': Icons.eco,
    'corn_cob': Icons.grain,
    'biogas': Icons.bubble_chart,
    'fuel_wood_co2': Icons.nature,
    'bagasse_co2': Icons.grass,
    'palm_kernel_shell_co2': Icons.eco,
    'corn_cob_co2': Icons.grain,
    'biogas_co2': Icons.bubble_chart,
    
    // Scope 1 - Mobile Combustion (On Road)
    'motor_gasoline_uncontrolled': Icons.directions_car,
    'motor_gasoline_catalyst': Icons.directions_car,
    'motor_gasoline_low_mileage': Icons.directions_car,
    'gas_diesel_oil_mobile': Icons.local_shipping,
    'cng': Icons.compress,
    'lpg_mobile_litre': Icons.propane_tank,
    'lpg_mobile_kg': Icons.propane_tank,
    
    // Scope 1 - Mobile Combustion (Off Road - Diesel)
    'diesel_agriculture': Icons.agriculture,
    'diesel_forestry': Icons.forest,
    'diesel_industrial': Icons.factory,
    'diesel_household': Icons.home,
    
    // Scope 1 - Mobile Combustion (Off Road - Gasoline 4-Stroke)
    'gasoline_4s_agriculture': Icons.agriculture,
    'gasoline_4s_forestry': Icons.forest,
    'gasoline_4s_industrial': Icons.factory,
    'gasoline_4s_household': Icons.home,
    
    // Scope 1 - Mobile Combustion (Off Road - Gasoline 2-Stroke)
    'gasoline_2s_agriculture': Icons.agriculture,
    'gasoline_2s_forestry': Icons.forest,
    'gasoline_2s_industrial': Icons.factory,
    'gasoline_2s_household': Icons.home,
    
    // Scope 1 - Fugitive Emissions (Refrigerants)
    'r22': Icons.ac_unit,
    'r32': Icons.ac_unit,
    'r125': Icons.ac_unit,
    'r134': Icons.ac_unit,
    'r134a': Icons.ac_unit,
    'r143': Icons.ac_unit,
    'r143a': Icons.ac_unit,
    
    // Scope 2 - Purchased Electricity
    'grid_electricity': Icons.bolt,
  };

  // Colors for categories (used in charts) - Updated for TGO categories
  static const Map<String, int> categoryColors = {
    // Scope 1 - Stationary Combustion (Fossil Fuels) - Red shades
    'natural_gas_scf': 0xFFE53935,
    'natural_gas_mj': 0xFFD32F2F,
    'lignite_coal': 0xFF1976D2,
    'heavy_fuel_oil_a': 0xFFFF5722,
    'heavy_fuel_oil_c': 0xFFBF360C,
    'gas_diesel_oil': 0xFFFF9800,
    'anthracite_coal': 0xFF424242,
    'sub_bituminous_coal': 0xFF616161,
    'jet_kerosene': 0xFFFFB74D,
    'lpg_litre': 0xFF9C27B0,
    'lpg_kg': 0xFF7B1FA2,
    'motor_gasoline': 0xFFFF5722,
    
    // Scope 1 - Stationary Combustion (Biomass) - Green shades
    'fuel_wood': 0xFF2E7D32,
    'bagasse': 0xFF388E3C,
    'palm_kernel_shell': 0xFF43A047,
    'corn_cob': 0xFF4CAF50,
    'biogas': 0xFF66BB6A,
    'fuel_wood_co2': 0xFF81C784,
    'bagasse_co2': 0xFF4CAF50,
    'palm_kernel_shell_co2': 0xFF66BB6A,
    'corn_cob_co2': 0xFF81C784,
    'biogas_co2': 0xFFA5D6A7,
    
    // Scope 1 - Mobile Combustion (On Road) - Blue shades
    'motor_gasoline_uncontrolled': 0xFF1976D2,
    'motor_gasoline_catalyst': 0xFF1E88E5,
    'motor_gasoline_low_mileage': 0xFF2196F3,
    'gas_diesel_oil_mobile': 0xFF42A5F5,
    'cng': 0xFF64B5F6,
    'lpg_mobile_litre': 0xFF90CAF9,
    'lpg_mobile_kg': 0xFFBBDEFB,
    
    // Scope 1 - Mobile Combustion (Off Road - Diesel) - Orange shades
    'diesel_agriculture': 0xFFFF9800,
    'diesel_forestry': 0xFFFFB74D,
    'diesel_industrial': 0xFFFFCC02,
    'diesel_household': 0xFFFFC107,
    
    // Scope 1 - Mobile Combustion (Off Road - Gasoline 4-Stroke) - Purple shades
    'gasoline_4s_agriculture': 0xFF9C27B0,
    'gasoline_4s_forestry': 0xFFAB47BC,
    'gasoline_4s_industrial': 0xFFBA68C8,
    'gasoline_4s_household': 0xFFCE93D8,
    
    // Scope 1 - Mobile Combustion (Off Road - Gasoline 2-Stroke) - Indigo shades
    'gasoline_2s_agriculture': 0xFF3F51B5,
    'gasoline_2s_forestry': 0xFF5C6BC0,
    'gasoline_2s_industrial': 0xFF7986CB,
    'gasoline_2s_household': 0xFF9FA8DA,
    
    // Scope 1 - Fugitive Emissions (Refrigerants) - Cyan shades
    'r22': 0xFF00BCD4,
    'r32': 0xFF26C6DA,
    'r125': 0xFF4DD0E1,
    'r134': 0xFF80DEEA,
    'r134a': 0xFFB2EBF2,
    'r143': 0xFF4FC3F7,
    'r143a': 0xFF81D4FA,
    
    // Scope 2 - Purchased Electricity - Yellow shades
    'grid_electricity': 0xFFFFEB3B,
  };
  
  // Month names
  static const List<String> monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  
  static const List<String> monthNamesShort = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  
  // Helper methods for smart dashboard - Updated for TGO categories
  static String getCategoryDisplayName(String category) {
    switch (category) {
      // Scope 1 - Stationary Combustion (Fossil Fuels)
      case 'natural_gas_scf':
        return 'Natural Gas (SCF)';
      case 'natural_gas_mj':
        return 'Natural Gas (MJ)';
      case 'lignite_coal':
        return 'Lignite Coal';
      case 'heavy_fuel_oil_a':
        return 'Heavy Fuel Oil A';
      case 'heavy_fuel_oil_c':
        return 'Heavy Fuel Oil C';
      case 'gas_diesel_oil':
        return 'Gas/Diesel Oil';
      case 'anthracite_coal':
        return 'Anthracite Coal';
      case 'sub_bituminous_coal':
        return 'Sub-bituminous Coal';
      case 'jet_kerosene':
        return 'Jet Kerosene';
      case 'lpg_litre':
        return 'LPG (Litre)';
      case 'lpg_kg':
        return 'LPG (kg)';
      case 'motor_gasoline':
        return 'Motor Gasoline';
        
      // Scope 1 - Stationary Combustion (Biomass)
      case 'fuel_wood':
        return 'Fuel Wood';
      case 'bagasse':
        return 'Bagasse';
      case 'palm_kernel_shell':
        return 'Palm Kernel Shell';
      case 'corn_cob':
        return 'Corn Cob';
      case 'biogas':
        return 'Biogas';
      case 'fuel_wood_co2':
        return 'Fuel Wood (CO₂ only)';
      case 'bagasse_co2':
        return 'Bagasse (CO₂ only)';
      case 'palm_kernel_shell_co2':
        return 'Palm Kernel Shell (CO₂ only)';
      case 'corn_cob_co2':
        return 'Corn Cob (CO₂ only)';
      case 'biogas_co2':
        return 'Biogas (CO₂ only)';
        
      // Scope 1 - Mobile Combustion (On Road)
      case 'motor_gasoline_uncontrolled':
        return 'Motor Gasoline - Uncontrolled';
      case 'motor_gasoline_catalyst':
        return 'Motor Gasoline - Oxidation Catalyst';
      case 'motor_gasoline_low_mileage':
        return 'Motor Gasoline - Low Mileage Light Duty';
      case 'gas_diesel_oil_mobile':
        return 'Gas/Diesel Oil (Mobile)';
      case 'cng':
        return 'Compressed Natural Gas (CNG)';
      case 'lpg_mobile_litre':
        return 'LPG - Mobile (Litre)';
      case 'lpg_mobile_kg':
        return 'LPG - Mobile (kg)';
        
      // Scope 1 - Mobile Combustion (Off Road - Diesel)
      case 'diesel_agriculture':
        return 'Diesel - Agriculture Equipment';
      case 'diesel_forestry':
        return 'Diesel - Forestry Equipment';
      case 'diesel_industrial':
        return 'Diesel - Industrial Equipment';
      case 'diesel_household':
        return 'Diesel - Household Equipment';
        
      // Scope 1 - Mobile Combustion (Off Road - Gasoline 4-Stroke)
      case 'gasoline_4s_agriculture':
        return 'Gasoline 4S - Agriculture Equipment';
      case 'gasoline_4s_forestry':
        return 'Gasoline 4S - Forestry Equipment';
      case 'gasoline_4s_industrial':
        return 'Gasoline 4S - Industrial Equipment';
      case 'gasoline_4s_household':
        return 'Gasoline 4S - Household Equipment';
        
      // Scope 1 - Mobile Combustion (Off Road - Gasoline 2-Stroke)
      case 'gasoline_2s_agriculture':
        return 'Gasoline 2S - Agriculture Equipment';
      case 'gasoline_2s_forestry':
        return 'Gasoline 2S - Forestry Equipment';
      case 'gasoline_2s_industrial':
        return 'Gasoline 2S - Industrial Equipment';
      case 'gasoline_2s_household':
        return 'Gasoline 2S - Household Equipment';
        
      // Scope 1 - Fugitive Emissions (Refrigerants)
      case 'r22':
        return 'R-22 (HCFC-22)';
      case 'r32':
        return 'R-32';
      case 'r125':
        return 'R-125';
      case 'r134':
        return 'R-134';
      case 'r134a':
        return 'R-134a';
      case 'r143':
        return 'R-143';
      case 'r143a':
        return 'R-143a';
        
      // Scope 2 - Purchased Electricity
      case 'grid_electricity':
        return 'Grid Mix Electricity (Thailand)';
        
      // Legacy categories (for backward compatibility)
      case 'electricity':
        return 'Electricity';
      case 'diesel':
        return 'Diesel Fuel';
      case 'gasoline':
        return 'Gasoline';
      case 'natural_gas':
        return 'Natural Gas';
      case 'waste':
        return 'Waste';
      case 'transport':
        return 'Transportation';
        
      default:
        return category.replaceAll('_', ' ').split(' ').map((word) => 
          word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1)).join(' ');
    }
  }
  
  // Get category scope (1 or 2)
  static int getCategoryScope(String category) {
    if (category == 'grid_electricity') {
      return 2; // Scope 2
    }
    return 1; // All others are Scope 1
  }
  
  // Get category type
  static String getCategoryType(String category) {
    if (category.startsWith('natural_gas') || category.contains('coal') || 
        category.contains('fuel_oil') || category == 'gas_diesel_oil' ||
        category.contains('kerosene') || category.contains('lpg') ||
        category == 'motor_gasoline') {
      return 'Stationary Combustion - Fossil Fuels';
    } else if (category.contains('wood') || category == 'bagasse' ||
               category.contains('palm') || category.contains('corn') ||
               category.contains('biogas')) {
      return 'Stationary Combustion - Biomass';
    } else if (category.contains('motor_gasoline') && category.contains('mobile') ||
               category.contains('gas_diesel_oil_mobile') || category == 'cng' ||
               category.contains('lpg_mobile')) {
      return 'Mobile Combustion - On Road';
    } else if (category.contains('diesel_') && !category.contains('mobile')) {
      return 'Mobile Combustion - Off Road (Diesel)';
    } else if (category.contains('gasoline_4s_')) {
      return 'Mobile Combustion - Off Road (Gasoline 4-Stroke)';
    } else if (category.contains('gasoline_2s_')) {
      return 'Mobile Combustion - Off Road (Gasoline 2-Stroke)';
    } else if (category.startsWith('r') && category.length <= 5) {
      return 'Fugitive Emissions - Refrigerants';
    } else if (category.contains('electricity')) {
      return 'Purchased Electricity';
    }
    return 'Other';
  }
  
  static String getMonthName(int month, {bool short = false}) {
    if (month < 1 || month > 12) return '';
    return short ? monthNamesShort[month - 1] : monthNames[month - 1];
  }
  
  static String formatCO2(double co2) {
    if (co2 >= 1000) {
      return '${(co2 / 1000).toStringAsFixed(2)} tons CO₂';
    }
    return '${co2.toStringAsFixed(2)} kg CO₂';
  }
  
  // Default targets
  static const double defaultMonthlyTarget = 1000.0; // kg CO2
  static const double defaultYearlyTarget = 12000.0; // kg CO2
}
