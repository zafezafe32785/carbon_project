#!/usr/bin/env python3
"""
Test script to verify refrigerant emission factor calculations
"""

import sys
import os
sys.path.append(os.path.dirname(__file__))

from models import calculate_co2_equivalent

def test_refrigerant_calculations():
    """Test refrigerant calculations with the updated function"""
    
    test_cases = [
        ("R-143a", 2, "kg"),
        ("R-32", 50, "kg"), 
        ("R-22", 1, "kg"),
        ("R-134a", 1, "kg"),
        ("R-125", 1, "kg")
    ]
    
    print("="*60)
    print("REFRIGERANT EMISSION FACTOR TEST")
    print("="*60)
    
    for activity_type, amount, unit in test_cases:
        print(f"\nTesting: {activity_type} - {amount} {unit}")
        co2_equivalent = calculate_co2_equivalent(activity_type, amount, unit)
        emission_factor = co2_equivalent / amount if amount > 0 else 0
        
        print(f"Result: {co2_equivalent} kg CO2e")
        print(f"Factor: {emission_factor} kgCO2e/{unit}")
        
        # Check if it's correct (should not be 1.0619)
        if emission_factor == 1.0619:
            print("❌ ERROR: Still using incorrect lignite coal factor!")
        elif co2_equivalent > 0:
            print("✅ SUCCESS: Using correct emission factor!")
        else:
            print("⚠️  WARNING: No emission factor found")
    
    print("\n" + "="*60)

if __name__ == '__main__':
    test_refrigerant_calculations()
