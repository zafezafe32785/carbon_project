#!/usr/bin/env python3
"""
Debug script to see what's in the database
"""

import sys
import os
sys.path.append(os.path.dirname(__file__))

from models import emission_factors_collection

def debug_database():
    """Check what's actually in the emission_factors collection"""
    
    print("="*60)
    print("DATABASE DEBUG - EMISSION FACTORS")
    print("="*60)
    
    # Get all emission factors
    factors = list(emission_factors_collection.find())
    
    print(f"Total emission factors: {len(factors)}")
    print("\nAll emission factors in database:")
    
    for i, factor in enumerate(factors, 1):
        print(f"\n{i}. Name: '{factor.get('name', 'N/A')}'")
        print(f"   Fuel Key: '{factor.get('fuel_key', 'N/A')}'")
        print(f"   Unit: '{factor.get('unit', 'N/A')}'")
        print(f"   Value: {factor.get('value', 'N/A')}")
        print(f"   Category: '{factor.get('category', 'N/A')}'")
    
    print("\n" + "="*60)
    
    # Test specific searches
    print("\nTEST SEARCHES:")
    
    # Search for R-143a exactly
    result = emission_factors_collection.find_one({'name': 'R-143a'})
    print(f"\nExact search 'R-143a': {result}")
    
    # Search for r143a fuel_key
    result = emission_factors_collection.find_one({'fuel_key': 'r143a'})
    print(f"\nFuel key search 'r143a': {result}")
    
    # Search with regex
    import re
    result = emission_factors_collection.find_one({
        'name': {'$regex': f'^R-143a$', '$options': 'i'}
    })
    print(f"\nRegex search '^R-143a$': {result}")

if __name__ == '__main__':
    debug_database()
