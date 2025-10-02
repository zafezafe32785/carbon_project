from datetime import datetime
from pymongo import MongoClient, ASCENDING, DESCENDING
from bson import ObjectId
import os
import re
from dotenv import load_dotenv

load_dotenv()

# MongoDB connection
client = MongoClient(os.getenv('MONGO_URI', 'mongodb://localhost:27017/'))
db = client['carbon_accounting']

# Collections (matching your existing database)
users_collection = db['users']
emission_records_collection = db['emission_records']  # Changed from 'emissions'
emission_factors_collection = db['emission_factors']
reports_collection = db['reports']
audits_collection = db['audits']  # Added this
edit_requests_collection = db['edit_requests']  # Added for user requests

# Create indexes for better performance
def create_indexes():
    print("Creating database indexes...")
    
    # User indexes
    users_collection.create_index([('email', ASCENDING)], unique=True)
    
    # Emission records indexes
    emission_records_collection.create_index([('user_id', ASCENDING)])
    emission_records_collection.create_index([('year', DESCENDING), ('month', DESCENDING)])
    emission_records_collection.create_index([('category', ASCENDING)])
    
    # Reports indexes
    reports_collection.create_index([('user_id', ASCENDING)])
    reports_collection.create_index([('create_date', DESCENDING)])
    
    # Emission factors indexes
    emission_factors_collection.create_index([('activity_type', ASCENDING), ('unit', ASCENDING)])
    
    # Audits indexes
    audits_collection.create_index([('user_id', ASCENDING)])
    audits_collection.create_index([('audit_time', DESCENDING)])
    
    print("Indexes created successfully!")

# Check if emission factors already exist
def check_emission_factors():
    count = emission_factors_collection.count_documents({})
    print(f"Found {count} emission factors in database")
    
    if count > 0:
        # Display existing factors
        factors = emission_factors_collection.find()
        print("\nExisting emission factors:")
        for factor in factors:
            print(f"- {factor.get('activity_type', 'Unknown')}: {factor.get('value', 0)} {factor.get('unit', '')}")
    
    return count

# Initialize default emission factors only if needed
def init_emission_factors():
    # Check if factors already exist
    if check_emission_factors() > 0:
        print("\nEmission factors already initialized. Skipping...")
        return
    
    print("\nInitializing emission factors...")
    
    default_factors = [
        {
            'factor_id': 'EF001',
            'unit': 'kWh',
            'value': 0.233,  # kg CO2e per kWh
            'activity_type': 'electricity',
            'description': 'Grid electricity emission factor'
        },
        {
            'factor_id': 'EF002',
            'unit': 'liter',
            'value': 2.68,  # kg CO2e per liter
            'activity_type': 'diesel',
            'description': 'Diesel fuel emission factor'
        },
        {
            'factor_id': 'EF003',
            'unit': 'liter',
            'value': 2.31,  # kg CO2e per liter
            'activity_type': 'gasoline',
            'description': 'Gasoline fuel emission factor'
        },
        {
            'factor_id': 'EF004',
            'unit': 'cubic_meter',
            'value': 1.92,  # kg CO2e per cubic meter
            'activity_type': 'natural_gas',
            'description': 'Natural gas emission factor'
        },
        {
            'factor_id': 'EF005',
            'unit': 'kg',
            'value': 0.467,  # kg CO2e per kg
            'activity_type': 'waste',
            'description': 'General waste emission factor'
        },
        {
            'factor_id': 'EF006',
            'unit': 'km',
            'value': 0.12,  # kg CO2e per km
            'activity_type': 'transport',
            'description': 'Average vehicle transport emission factor'
        }
    ]
    
    inserted = 0
    for factor in default_factors:
        emission_factors_collection.insert_one(factor)
        print(f"Added emission factor: {factor['activity_type']}")
        inserted += 1
    
    print(f"\nEmission factors initialized! Added {inserted} factors.")

# Helper function to calculate CO2 equivalent
def calculate_co2_equivalent(activity_type, amount, unit, language='en'):
    """Calculate CO2 equivalent based on activity type, amount, and unit using TGO factors
    
    Args:
        activity_type (str): The activity type (supports English and Thai)
        amount (float): The amount of activity
        unit (str): The unit of measurement (supports English and Thai)
        language (str): Language preference ('en' or 'th')
    
    Returns:
        float: CO2 equivalent in kg
    """
    
    # Normalize inputs
    activity_type_lower = activity_type.lower().strip()
    unit_lower = unit.lower().strip()
    
    print(f"Looking for emission factor: activity_type='{activity_type}', unit='{unit}'")
    
    # PRIORITY 1: Try direct fuel_key match (highest priority)
    factor = emission_factors_collection.find_one({
        'fuel_key': activity_type_lower,
        'unit': {'$regex': f'^{re.escape(unit)}$', '$options': 'i'}
    })
    
    if factor:
        print(f"Found fuel_key match: {factor['fuel_key']} = {factor['value']} {factor['unit']}")
        return amount * factor['value']
    
    # PRIORITY 2: Try exact name match (for refrigerants like "R-143a")
    factor = emission_factors_collection.find_one({
        'name': activity_type,  # Exact match only
        'unit': unit
    })
    
    if factor:
        print(f"Found exact name match: {factor['name']} = {factor['value']} {factor['unit']}")
        return amount * factor['value']
    
    # PRIORITY 3: Try case-insensitive exact name match
    factor = emission_factors_collection.find_one({
        'name': {'$regex': f'^{re.escape(activity_type)}$', '$options': 'i'},
        'unit': unit
    })
    
    if factor:
        print(f"Found case-insensitive exact name match: {factor['name']} = {factor['value']} {factor['unit']}")
        return amount * factor['value']
    
    # PRIORITY 2: Try refrigerant fuel_key mapping (R-143a -> r143a)
    refrigerant_mappings = {
        'r-22': 'r22',
        'r-32': 'r32', 
        'r-125': 'r125',
        'r-134': 'r134',
        'r-134a': 'r134a',
        'r-143': 'r143',
        'r-143a': 'r143a'
    }
    
    mapped_refrigerant = refrigerant_mappings.get(activity_type_lower)
    if mapped_refrigerant:
        factor = emission_factors_collection.find_one({
            'fuel_key': mapped_refrigerant,
            'unit': unit_lower
        })
        
        if factor:
            print(f"Found refrigerant match: {mapped_refrigerant} = {factor['value']} {factor['unit']}")
            return amount * factor['value']
    
    # PRIORITY 3: Try activity_type exact match 
    factor = emission_factors_collection.find_one({
        'activity_type': activity_type_lower,
        'unit': unit_lower
    })
    
    if factor:
        print(f"Found activity_type match: {factor['activity_type']} = {factor['value']} {factor['unit']}")
        return amount * factor['value']
    
    # PRIORITY 4: Try to find by activity_types array (for mapped common types)
    factor = emission_factors_collection.find_one({
        'activity_types': activity_type_lower,
        '$or': [
            {'unit': unit_lower},
            {'unit_th': unit_lower}
        ]
    })
    
    if factor:
        print(f"Found activity_types array match: {factor['name']} = {factor['value']} {factor['unit']}")
        return amount * factor['value']
    
    # PRIORITY 5: Try unit variations
    unit_mappings = {
        'kwh': 'kWh',
        'kw': 'kWh', 
        'liter': 'litre',
        'l': 'litre',
        'litre': 'litre',
        'kg': 'kg',
        'kilogram': 'kg',
        'km': 'km',
        'kilometer': 'km',
        'cubic_meter': 'm³',
        'm3': 'm³',
        'scf': 'scf',
        'mj': 'MJ'
    }
    
    mapped_unit = unit_mappings.get(unit_lower, unit_lower)
    if mapped_unit != unit_lower:
        factor = emission_factors_collection.find_one({
            'activity_types': activity_type_lower,
            'unit': mapped_unit
        })
        
        if factor:
            print(f"Found unit mapping match: {factor['name']} = {factor['value']} {mapped_unit}")
            return amount * factor['value']
    
    # PRIORITY 6: Activity type mappings for common categories
    activity_mappings = {
        'electricity': 'grid_electricity',
        'diesel': 'gas_diesel_oil',
        'gasoline': 'motor_gasoline', 
        'petrol': 'motor_gasoline',
        'natural_gas': 'natural_gas_scf',
        'lpg': 'lpg_litre',
        'transport': 'motor_gasoline_uncontrolled',
        'vehicle': 'motor_gasoline_uncontrolled'
    }
    
    mapped_activity = activity_mappings.get(activity_type_lower)
    if mapped_activity:
        factor = emission_factors_collection.find_one({
            'fuel_key': mapped_activity
        })
        
        if factor:
            print(f"Found activity mapping match: {mapped_activity} = {factor['value']} {factor['unit']}")
            return amount * factor['value']
    
    # PRIORITY 7: Hardcoded TGO fallbacks
    # Fallback to TGO Thailand grid electricity factor for electricity
    if 'electric' in activity_type_lower or 'power' in activity_type_lower:
        if unit_lower in ['kwh', 'kw']:
            print(f"Using TGO electricity fallback: 0.4999 kgCO2/kWh")
            return amount * 0.4999  # TGO Thailand grid factor
    
    # Fallback to TGO diesel factor for diesel
    if 'diesel' in activity_type_lower:
        if unit_lower in ['litre', 'liter', 'l']:
            print(f"Using TGO diesel fallback: 2.7078 kgCO2/litre")
            return amount * 2.7078  # TGO diesel factor
    
    # Fallback to TGO gasoline factor for gasoline
    if 'gasoline' in activity_type_lower or 'petrol' in activity_type_lower:
        if unit_lower in ['litre', 'liter', 'l']:
            print(f"Using TGO gasoline fallback: 2.1894 kgCO2/litre")
            return amount * 2.1894  # TGO gasoline factor
    
    print(f"❌ ERROR: No emission factor found for activity_type='{activity_type}', unit='{unit}'")
    
    # Debug: Show what's actually in the database
    print("Available emission factors in database:")
    factors = emission_factors_collection.find().limit(5)
    for f in factors:
        print(f"  - {f.get('name', 'N/A')} ({f.get('fuel_key', 'N/A')}) = {f.get('value', 0)} {f.get('unit', 'N/A')}")
    
    return 0

# Display database info
def display_db_info():
    print("\n" + "="*50)
    print("DATABASE INFORMATION")
    print("="*50)
    print(f"Database: {db.name}")
    print(f"Collections: {', '.join(db.list_collection_names())}")
    print("\nDocument counts:")
    print(f"- Users: {users_collection.count_documents({})}")
    print(f"- Emission Records: {emission_records_collection.count_documents({})}")
    print(f"- Emission Factors: {emission_factors_collection.count_documents({})}")
    print(f"- Reports: {reports_collection.count_documents({})}")
    print(f"- Audits: {audits_collection.count_documents({})}")
    print("="*50)

# Initialize database
if __name__ == '__main__':
    print("Starting database initialization...")
    create_indexes()
    init_emission_factors()
    display_db_info()
    print("\nDatabase setup completed!")
