from datetime import datetime
from pymongo import MongoClient, ASCENDING, DESCENDING
from bson import ObjectId
import os
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
def calculate_co2_equivalent(activity_type, amount, unit):
    """Calculate CO2 equivalent based on activity type, amount, and unit"""
    
    # Find emission factor
    factor = emission_factors_collection.find_one({
        'activity_type': activity_type,
        'unit': unit
    })
    
    if factor:
        return amount * factor['value']
    
    # Default factors if not in database
    default_factors = {
        'electricity': {'kWh': 0.233},
        'diesel': {'liter': 2.68},
        'gasoline': {'liter': 2.31},
        'natural_gas': {'cubic_meter': 1.92},
        'waste': {'kg': 0.467},
        'transport': {'km': 0.12}
    }
    
    if activity_type in default_factors and unit in default_factors[activity_type]:
        return amount * default_factors[activity_type][unit]
    
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