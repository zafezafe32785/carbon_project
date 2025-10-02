/// TGO Emission Factors - Organized by GHG Protocol Scopes
/// Updated: April 2022 (TGO Thailand)
/// Source: Thailand Greenhouse Gas Management Organization (TGO)

class TGOEmissionFactors {
  // Scope 1: Direct Emissions
  static const Map<String, Map<String, dynamic>> scope1StationaryFossil = {
    'natural_gas_scf': {
      'name': 'Natural Gas (SCF)',
      'unit': 'scf',
      'factor': 0.0573,
      'notes': 'Volumetric measurement',
      'category': 'Stationary Combustion - Fossil Fuels'
    },
    'natural_gas_mj': {
      'name': 'Natural Gas (MJ)',
      'unit': 'MJ',
      'factor': 0.0562,
      'notes': 'Energy content measurement',
      'category': 'Stationary Combustion - Fossil Fuels'
    },
    'lignite_coal': {
      'name': 'Lignite Coal',
      'unit': 'kg',
      'factor': 1.0619,
      'notes': '',
      'category': 'Stationary Combustion - Fossil Fuels'
    },
    'heavy_fuel_oil_a': {
      'name': 'Heavy Fuel Oil A',
      'unit': 'litre',
      'factor': 3.2200,
      'notes': 'Lower viscosity, lighter grade',
      'category': 'Stationary Combustion - Fossil Fuels'
    },
    'heavy_fuel_oil_c': {
      'name': 'Heavy Fuel Oil C',
      'unit': 'litre',
      'factor': 3.2457,
      'notes': 'Higher viscosity, heavier grade',
      'category': 'Stationary Combustion - Fossil Fuels'
    },
    'gas_diesel_oil': {
      'name': 'Gas/Diesel Oil',
      'unit': 'litre',
      'factor': 2.7078,
      'notes': '',
      'category': 'Stationary Combustion - Fossil Fuels'
    },
    'anthracite_coal': {
      'name': 'Anthracite Coal',
      'unit': 'kg',
      'factor': 3.1000,
      'notes': '',
      'category': 'Stationary Combustion - Fossil Fuels'
    },
    'sub_bituminous_coal': {
      'name': 'Sub-bituminous Coal',
      'unit': 'kg',
      'factor': 2.5454,
      'notes': '',
      'category': 'Stationary Combustion - Fossil Fuels'
    },
    'jet_kerosene': {
      'name': 'Jet Kerosene',
      'unit': 'litre',
      'factor': 2.4775,
      'notes': '',
      'category': 'Stationary Combustion - Fossil Fuels'
    },
    'lpg_litre': {
      'name': 'LPG (Liquefied Petroleum Gas)',
      'unit': 'litre',
      'factor': 1.6812,
      'notes': '',
      'category': 'Stationary Combustion - Fossil Fuels'
    },
    'lpg_kg': {
      'name': 'LPG (Liquefied Petroleum Gas)',
      'unit': 'kg',
      'factor': 3.1134,
      'notes': '1 litre = 0.54 kg',
      'category': 'Stationary Combustion - Fossil Fuels'
    },
    'motor_gasoline': {
      'name': 'Motor Gasoline',
      'unit': 'litre',
      'factor': 2.1894,
      'notes': '',
      'category': 'Stationary Combustion - Fossil Fuels'
    },
  };

  static const Map<String, Map<String, dynamic>> scope1StationaryBiomass = {
    'fuel_wood': {
      'name': 'Fuel Wood',
      'unit': 'kg',
      'factor': 0.0304,
      'notes': 'Excludes biogenic CO₂',
      'category': 'Stationary Combustion - Biomass'
    },
    'bagasse': {
      'name': 'Bagasse',
      'unit': 'kg',
      'factor': 0.0143,
      'notes': 'Excludes biogenic CO₂',
      'category': 'Stationary Combustion - Biomass'
    },
    'palm_kernel_shell': {
      'name': 'Palm Kernel Shell',
      'unit': 'kg',
      'factor': 0.0352,
      'notes': 'Excludes biogenic CO₂',
      'category': 'Stationary Combustion - Biomass'
    },
    'corn_cob': {
      'name': 'Corn Cob',
      'unit': 'kg',
      'factor': 0.0319,
      'notes': 'Excludes biogenic CO₂',
      'category': 'Stationary Combustion - Biomass'
    },
    'biogas': {
      'name': 'Biogas',
      'unit': 'm³',
      'factor': 0.0011,
      'notes': 'Excludes biogenic CO₂',
      'category': 'Stationary Combustion - Biomass'
    },
    'fuel_wood_co2': {
      'name': 'Fuel Wood (CO₂ only)',
      'unit': 'kg',
      'factor': 1.7909,
      'notes': 'Includes biogenic CO₂',
      'category': 'Stationary Combustion - Biomass'
    },
    'bagasse_co2': {
      'name': 'Bagasse (CO₂ only)',
      'unit': 'kg',
      'factor': 0.7530,
      'notes': 'Includes biogenic CO₂',
      'category': 'Stationary Combustion - Biomass'
    },
    'palm_kernel_shell_co2': {
      'name': 'Palm Kernel Shell (CO₂ only)',
      'unit': 'kg',
      'factor': 1.8530,
      'notes': 'Includes biogenic CO₂',
      'category': 'Stationary Combustion - Biomass'
    },
    'corn_cob_co2': {
      'name': 'Corn Cob (CO₂ only)',
      'unit': 'kg',
      'factor': 1.6780,
      'notes': 'Includes biogenic CO₂',
      'category': 'Stationary Combustion - Biomass'
    },
    'biogas_co2': {
      'name': 'Biogas (CO₂ only)',
      'unit': 'm³',
      'factor': 1.1428,
      'notes': 'Includes biogenic CO₂',
      'category': 'Stationary Combustion - Biomass'
    },
  };

  static const Map<String, Map<String, dynamic>> scope1MobileOnRoad = {
    'motor_gasoline_uncontrolled': {
      'name': 'Motor Gasoline - Uncontrolled',
      'unit': 'litre',
      'factor': 2.2394,
      'notes': '',
      'category': 'Mobile Combustion - On Road Vehicles'
    },
    'motor_gasoline_catalyst': {
      'name': 'Motor Gasoline - Oxidation Catalyst',
      'unit': 'litre',
      'factor': 2.2719,
      'notes': '',
      'category': 'Mobile Combustion - On Road Vehicles'
    },
    'motor_gasoline_low_mileage': {
      'name': 'Motor Gasoline - Low Mileage Light Duty (1995+)',
      'unit': 'litre',
      'factor': 2.2327,
      'notes': '',
      'category': 'Mobile Combustion - On Road Vehicles'
    },
    'gas_diesel_oil_mobile': {
      'name': 'Gas/Diesel Oil',
      'unit': 'litre',
      'factor': 2.7406,
      'notes': '',
      'category': 'Mobile Combustion - On Road Vehicles'
    },
    'cng': {
      'name': 'Compressed Natural Gas (CNG)',
      'unit': 'kg',
      'factor': 2.2609,
      'notes': '',
      'category': 'Mobile Combustion - On Road Vehicles'
    },
    'lpg_mobile_litre': {
      'name': 'LPG - Mobile',
      'unit': 'litre',
      'factor': 1.7306,
      'notes': '',
      'category': 'Mobile Combustion - On Road Vehicles'
    },
    'lpg_mobile_kg': {
      'name': 'LPG - Mobile',
      'unit': 'kg',
      'factor': 3.2049,
      'notes': '1 litre = 0.54 kg',
      'category': 'Mobile Combustion - On Road Vehicles'
    },
  };

  static const Map<String, Map<String, dynamic>> scope1MobileOffRoadDiesel = {
    'diesel_agriculture': {
      'name': 'Agriculture Equipment',
      'unit': 'litre',
      'factor': 2.9793,
      'notes': '',
      'category': 'Mobile Combustion - Off Road Equipment (Diesel)'
    },
    'diesel_forestry': {
      'name': 'Forestry Equipment',
      'unit': 'litre',
      'factor': 2.9793,
      'notes': '',
      'category': 'Mobile Combustion - Off Road Equipment (Diesel)'
    },
    'diesel_industrial': {
      'name': 'Industrial Equipment',
      'unit': 'litre',
      'factor': 2.9793,
      'notes': '',
      'category': 'Mobile Combustion - Off Road Equipment (Diesel)'
    },
    'diesel_household': {
      'name': 'Household Equipment',
      'unit': 'litre',
      'factor': 2.9793,
      'notes': '',
      'category': 'Mobile Combustion - Off Road Equipment (Diesel)'
    },
  };

  static const Map<String, Map<String, dynamic>> scope1MobileOffRoadGasoline4Stroke = {
    'gasoline_4s_agriculture': {
      'name': 'Agriculture Equipment',
      'unit': 'litre',
      'factor': 2.2738,
      'notes': '',
      'category': 'Mobile Combustion - Off Road Equipment (Gasoline 4-Stroke)'
    },
    'gasoline_4s_forestry': {
      'name': 'Forestry Equipment',
      'unit': 'litre',
      'factor': 2.1816,
      'notes': '',
      'category': 'Mobile Combustion - Off Road Equipment (Gasoline 4-Stroke)'
    },
    'gasoline_4s_industrial': {
      'name': 'Industrial Equipment',
      'unit': 'litre',
      'factor': 2.2455,
      'notes': '',
      'category': 'Mobile Combustion - Off Road Equipment (Gasoline 4-Stroke)'
    },
    'gasoline_4s_household': {
      'name': 'Household Equipment',
      'unit': 'litre',
      'factor': 2.3116,
      'notes': '',
      'category': 'Mobile Combustion - Off Road Equipment (Gasoline 4-Stroke)'
    },
  };

  static const Map<String, Map<String, dynamic>> scope1MobileOffRoadGasoline2Stroke = {
    'gasoline_2s_agriculture': {
      'name': 'Agriculture Equipment',
      'unit': 'litre',
      'factor': 2.3171,
      'notes': '',
      'category': 'Mobile Combustion - Off Road Equipment (Gasoline 2-Stroke)'
    },
    'gasoline_2s_forestry': {
      'name': 'Forestry Equipment',
      'unit': 'litre',
      'factor': 2.3454,
      'notes': '',
      'category': 'Mobile Combustion - Off Road Equipment (Gasoline 2-Stroke)'
    },
    'gasoline_2s_industrial': {
      'name': 'Industrial Equipment',
      'unit': 'litre',
      'factor': 2.3077,
      'notes': '',
      'category': 'Mobile Combustion - Off Road Equipment (Gasoline 2-Stroke)'
    },
    'gasoline_2s_household': {
      'name': 'Household Equipment',
      'unit': 'litre',
      'factor': 2.3549,
      'notes': '',
      'category': 'Mobile Combustion - Off Road Equipment (Gasoline 2-Stroke)'
    },
  };

  static const Map<String, Map<String, dynamic>> scope1Refrigerants = {
    'r22': {
      'name': 'R-22 (HCFC-22)',
      'unit': 'kg',
      'factor': 1760.0000,
      'notes': 'GWP: 1,760',
      'category': 'Fugitive Emissions - Refrigerants'
    },
    'r32': {
      'name': 'R-32',
      'unit': 'kg',
      'factor': 677.0000,
      'notes': 'GWP: 677',
      'category': 'Fugitive Emissions - Refrigerants'
    },
    'r125': {
      'name': 'R-125',
      'unit': 'kg',
      'factor': 3170.0000,
      'notes': 'GWP: 3,170',
      'category': 'Fugitive Emissions - Refrigerants'
    },
    'r134': {
      'name': 'R-134',
      'unit': 'kg',
      'factor': 1120.0000,
      'notes': 'GWP: 1,120',
      'category': 'Fugitive Emissions - Refrigerants'
    },
    'r134a': {
      'name': 'R-134a',
      'unit': 'kg',
      'factor': 1300.0000,
      'notes': 'GWP: 1,300',
      'category': 'Fugitive Emissions - Refrigerants'
    },
    'r143': {
      'name': 'R-143',
      'unit': 'kg',
      'factor': 328.0000,
      'notes': 'GWP: 328',
      'category': 'Fugitive Emissions - Refrigerants'
    },
    'r143a': {
      'name': 'R-143a',
      'unit': 'kg',
      'factor': 4800.0000,
      'notes': 'GWP: 4,800',
      'category': 'Fugitive Emissions - Refrigerants'
    },
  };

  // Scope 2: Indirect Energy Emissions
  static const Map<String, Map<String, dynamic>> scope2Electricity = {
    'grid_electricity': {
      'name': 'Grid Mix Electricity (Thailand)',
      'unit': 'kWh',
      'factor': 0.4999,
      'notes': 'Based on 2016-2018 Thai grid mix',
      'category': 'Purchased Electricity'
    },
  };

  // Combined data structure for easy access
  static Map<String, Map<String, Map<String, dynamic>>> getAllEmissionFactors() {
    return {
      'Scope 1 - Stationary Combustion (Fossil Fuels)': scope1StationaryFossil,
      'Scope 1 - Stationary Combustion (Biomass)': scope1StationaryBiomass,
      'Scope 1 - Mobile Combustion (On Road)': scope1MobileOnRoad,
      'Scope 1 - Mobile Combustion (Off Road - Diesel)': scope1MobileOffRoadDiesel,
      'Scope 1 - Mobile Combustion (Off Road - Gasoline 4-Stroke)': scope1MobileOffRoadGasoline4Stroke,
      'Scope 1 - Mobile Combustion (Off Road - Gasoline 2-Stroke)': scope1MobileOffRoadGasoline2Stroke,
      'Scope 1 - Fugitive Emissions (Refrigerants)': scope1Refrigerants,
      'Scope 2 - Purchased Electricity': scope2Electricity,
    };
  }

  // Helper method to get all fuel types as a flat list
  static List<Map<String, dynamic>> getAllFuelTypes() {
    List<Map<String, dynamic>> allFuels = [];
    
    getAllEmissionFactors().forEach((categoryName, fuels) {
      fuels.forEach((key, fuelData) {
        allFuels.add({
          'key': key,
          'name': fuelData['name'],
          'unit': fuelData['unit'],
          'factor': fuelData['factor'],
          'notes': fuelData['notes'],
          'category': categoryName,
          'scope': categoryName.startsWith('Scope 1') ? 1 : 2,
        });
      });
    });
    
    return allFuels;
  }

  // Helper method to get fuels by category
  static List<Map<String, dynamic>> getFuelsByCategory(String category) {
    final allFactors = getAllEmissionFactors();
    if (!allFactors.containsKey(category)) return [];
    
    List<Map<String, dynamic>> fuels = [];
    allFactors[category]!.forEach((key, fuelData) {
      fuels.add({
        'key': key,
        'name': fuelData['name'],
        'unit': fuelData['unit'],
        'factor': fuelData['factor'],
        'notes': fuelData['notes'],
        'category': category,
        'scope': category.startsWith('Scope 1') ? 1 : 2,
      });
    });
    
    return fuels;
  }

  // Helper method to get categories
  static List<String> getCategories() {
    return getAllEmissionFactors().keys.toList();
  }

  // Helper method to calculate CO2 equivalent
  static double calculateCO2Equivalent(String fuelKey, double amount) {
    final allFuels = getAllFuelTypes();
    final fuel = allFuels.firstWhere(
      (f) => f['key'] == fuelKey,
      orElse: () => {'factor': 0.0},
    );
    return amount * fuel['factor'];
  }
}
