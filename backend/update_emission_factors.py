#!/usr/bin/env python3
"""
Update MongoDB emission factors with comprehensive TGO Thailand emission factors
This script syncs the frontend TGO emission factors with the backend database
"""

from datetime import datetime
from models import emission_factors_collection, db
import json

# TGO Emission Factors - Organized by GHG Protocol Scopes
# Updated: April 2022 (TGO Thailand)
# Source: Thailand Greenhouse Gas Management Organization (TGO)

def get_tgo_emission_factors():
    """Get all TGO emission factors organized by category with bilingual support"""
    
    # Scope 1: Direct Emissions - Stationary Combustion (Fossil Fuels)
    scope1_stationary_fossil = {
        'natural_gas_scf': {
            'name': 'Natural Gas (SCF)',
            'name_th': 'ก๊าซธรรมชาติ (SCF)',
            'unit': 'scf',
            'unit_th': 'ลบ.ฟุต',
            'factor': 0.0573,
            'notes': 'Volumetric measurement',
            'notes_th': 'การวัดปริมาตร',
            'category': 'Stationary Combustion - Fossil Fuels',
            'category_th': 'การเผาไหม้แบบนิ่ง - เชื้อเพลิงฟอสซิล'
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
    }

    # Scope 1: Direct Emissions - Stationary Combustion (Biomass)
    scope1_stationary_biomass = {
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
    }

    # Scope 1: Mobile Combustion - On Road Vehicles
    scope1_mobile_on_road = {
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
    }

    # Scope 1: Mobile Combustion - Off Road Equipment (Diesel)
    scope1_mobile_off_road_diesel = {
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
    }

    # Scope 1: Mobile Combustion - Off Road Equipment (Gasoline 4-Stroke)
    scope1_mobile_off_road_gasoline_4s = {
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
    }

    # Scope 1: Mobile Combustion - Off Road Equipment (Gasoline 2-Stroke)
    scope1_mobile_off_road_gasoline_2s = {
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
    }

    # Scope 1: Fugitive Emissions - Refrigerants
    scope1_refrigerants = {
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
    }

    # Scope 2: Indirect Energy Emissions
    scope2_electricity = {
        'grid_electricity': {
            'name': 'Grid Mix Electricity (Thailand)',
            'unit': 'kWh',
            'factor': 0.4999,
            'notes': 'Based on 2016-2018 Thai grid mix',
            'category': 'Purchased Electricity'
        },
    }

    # Combine all emission factors
    all_factors = {}
    
    # Add all scope 1 factors
    all_factors.update(scope1_stationary_fossil)
    all_factors.update(scope1_stationary_biomass)
    all_factors.update(scope1_mobile_on_road)
    all_factors.update(scope1_mobile_off_road_diesel)
    all_factors.update(scope1_mobile_off_road_gasoline_4s)
    all_factors.update(scope1_mobile_off_road_gasoline_2s)
    all_factors.update(scope1_refrigerants)
    
    # Add scope 2 factors
    all_factors.update(scope2_electricity)
    
    return all_factors

def update_emission_factors():
    """Update MongoDB with comprehensive TGO emission factors"""
    
    print("Starting TGO emission factors update...")
    print(f"Database: {db.name}")
    print(f"Collection: {emission_factors_collection.name}")
    
    # Get current count
    current_count = emission_factors_collection.count_documents({})
    print(f"Current emission factors in database: {current_count}")
    
    # Get TGO emission factors
    tgo_factors = get_tgo_emission_factors()
    print(f"TGO emission factors to process: {len(tgo_factors)}")
    
    # Clear existing factors (optional - comment out if you want to keep existing)
    print("\nClearing existing emission factors...")
    emission_factors_collection.delete_many({})
    print("Existing factors cleared.")
    
    # Insert new TGO factors
    print("\nInserting TGO emission factors...")
    inserted_count = 0
    updated_count = 0
    
    for fuel_key, fuel_data in tgo_factors.items():
        # Create emission factor document
        emission_factor = {
            'factor_id': fuel_key.upper(),
            'fuel_key': fuel_key,
            'activity_type': fuel_data['name'].lower().replace(' ', '_').replace('(', '').replace(')', '').replace('-', '_'),
            'name': fuel_data['name'],
            'unit': fuel_data['unit'],
            'value': fuel_data['factor'],
            'factor': fuel_data['factor'],  # Keep both for compatibility
            'notes': fuel_data['notes'],
            'description': f"{fuel_data['name']} emission factor",
            'category': fuel_data['category'],
            'scope': 1 if fuel_data['category'].startswith('Scope 1') or 'Stationary' in fuel_data['category'] or 'Mobile' in fuel_data['category'] or 'Fugitive' in fuel_data['category'] else 2,
            'source': 'TGO Thailand',
            'source_date': 'April 2022',
            'created_at': datetime.utcnow(),
            'updated_at': datetime.utcnow()
        }
        
        # Insert the factor
        try:
            emission_factors_collection.insert_one(emission_factor)
            inserted_count += 1
            print(f"✓ Inserted: {fuel_data['name']} ({fuel_data['unit']}) = {fuel_data['factor']} kgCO₂eq/{fuel_data['unit']}")
        except Exception as e:
            print(f"✗ Error inserting {fuel_key}: {str(e)}")
    
    print(f"\n=== UPDATE SUMMARY ===")
    print(f"Total TGO factors processed: {len(tgo_factors)}")
    print(f"Successfully inserted: {inserted_count}")
    print(f"Errors: {len(tgo_factors) - inserted_count}")
    
    # Verify final count
    final_count = emission_factors_collection.count_documents({})
    print(f"Final emission factors in database: {final_count}")
    
    # Show some examples
    print(f"\n=== SAMPLE FACTORS ===")
    sample_factors = list(emission_factors_collection.find({}).limit(5))
    for factor in sample_factors:
        print(f"- {factor['name']}: {factor['value']} {factor['unit']}")
    
    print(f"\n=== CATEGORIES ===")
    categories = emission_factors_collection.distinct('category')
    for category in sorted(categories):
        count = emission_factors_collection.count_documents({'category': category})
        print(f"- {category}: {count} factors")
    
    return {
        'success': True,
        'inserted': inserted_count,
        'total_factors': final_count,
        'categories': len(categories)
    }

def create_activity_type_mapping():
    """Create mapping between common activity types and TGO factors"""
    
    print("\nCreating activity type mappings...")
    
    # Common activity type mappings
    mappings = [
        # Electricity
        {
            'activity_type': 'electricity',
            'tgo_key': 'grid_electricity',
            'unit': 'kWh',
            'description': 'Grid electricity consumption'
        },
        # Fuels
        {
            'activity_type': 'diesel',
            'tgo_key': 'gas_diesel_oil',
            'unit': 'litre',
            'description': 'Diesel fuel consumption'
        },
        {
            'activity_type': 'gasoline',
            'tgo_key': 'motor_gasoline',
            'unit': 'litre',
            'description': 'Gasoline fuel consumption'
        },
        {
            'activity_type': 'natural_gas',
            'tgo_key': 'natural_gas_scf',
            'unit': 'scf',
            'description': 'Natural gas consumption'
        },
        {
            'activity_type': 'lpg',
            'tgo_key': 'lpg_litre',
            'unit': 'litre',
            'description': 'LPG consumption'
        },
        # Transport
        {
            'activity_type': 'transport',
            'tgo_key': 'motor_gasoline_uncontrolled',
            'unit': 'litre',
            'description': 'Vehicle transport (gasoline)'
        },
        {
            'activity_type': 'transport_diesel',
            'tgo_key': 'gas_diesel_oil_mobile',
            'unit': 'litre',
            'description': 'Vehicle transport (diesel)'
        }
    ]
    
    # Insert mappings as separate collection or update existing factors
    for mapping in mappings:
        # Find the TGO factor
        tgo_factor = emission_factors_collection.find_one({'fuel_key': mapping['tgo_key']})
        
        if tgo_factor:
            # Update the factor to include the common activity type
            emission_factors_collection.update_one(
                {'fuel_key': mapping['tgo_key']},
                {
                    '$addToSet': {
                        'activity_types': mapping['activity_type']
                    },
                    '$set': {
                        'updated_at': datetime.utcnow()
                    }
                }
            )
            print(f"✓ Mapped '{mapping['activity_type']}' to '{mapping['tgo_key']}'")
        else:
            print(f"✗ TGO factor '{mapping['tgo_key']}' not found for mapping '{mapping['activity_type']}'")

def main():
    """Main function to update emission factors"""
    
    print("="*60)
    print("TGO THAILAND EMISSION FACTORS UPDATE")
    print("="*60)
    print("This script will update MongoDB with comprehensive")
    print("TGO Thailand emission factors from April 2022")
    print("="*60)
    
    try:
        # Test database connection
        db.command('ping')
        print("✓ Database connection successful")
        
        # Update emission factors
        result = update_emission_factors()
        
        if result['success']:
            print(f"\n✓ Successfully updated emission factors!")
            print(f"  - Inserted: {result['inserted']} factors")
            print(f"  - Total factors: {result['total_factors']}")
            print(f"  - Categories: {result['categories']}")
            
            # Create activity type mappings
            create_activity_type_mapping()
            
            print(f"\n✓ Emission factors update completed successfully!")
            
        else:
            print(f"\n✗ Update failed!")
            
    except Exception as e:
        print(f"\n✗ Error: {str(e)}")
        import traceback
        traceback.print_exc()

if __name__ == '__main__':
    main()
