import 'package:flutter/material.dart';

class Constants {
  // API Configuration - IMPORTANT: Update this based on where you run
  // For Web/Chrome on same machine as backend:
  static const String baseUrl = 'http://localhost:5000';
  
  // API Endpoints
  static const String apiUrl = '$baseUrl/api';
  
  // Emission Categories
  static const List<String> emissionCategories = [
    'electricity',
    'diesel', 
    'gasoline',
    'natural_gas',
    'waste',
    'transport',
  ];
  
  static const Map<String, String> categoryUnits = {
    'electricity': 'kWh',
    'diesel': 'liter',
    'gasoline': 'liter', 
    'natural_gas': 'cubic_meter',
    'waste': 'kg',
    'transport': 'km',
  };
  
  static const Map<String, IconData> categoryIcons = {
    'electricity': Icons.bolt,
    'diesel': Icons.local_gas_station,
    'gasoline': Icons.local_gas_station,
    'natural_gas': Icons.whatshot,
    'waste': Icons.delete,
    'transport': Icons.directions_car,
  };

  // ADD THESE MISSING PROPERTIES FOR SMART DASHBOARD:
  
  // Colors for categories (used in charts)
  static const Map<String, int> categoryColors = {
    'electricity': 0xFF2196F3, // Blue
    'diesel': 0xFFFF9800, // Orange
    'gasoline': 0xFFFF5722, // Deep Orange
    'natural_gas': 0xFFF44336, // Red
    'waste': 0xFF9C27B0, // Purple
    'transport': 0xFF009688, // Teal
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
  
  // Helper methods for smart dashboard
  static String getCategoryDisplayName(String category) {
    switch (category) {
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
        return category.toUpperCase();
    }
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