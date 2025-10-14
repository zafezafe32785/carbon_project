#!/usr/bin/env python3
"""
Generate test Excel files with mockup carbon emissions data for testing upload functionality.
This creates files for 2024 (full year) and 2025 (January to October).
"""

import pandas as pd
import random
from datetime import datetime, timedelta

# Categories with their units based on emission_factors.json
# Using fuel_key values for consistency with database
CATEGORIES = [
    ('grid_electricity', 'kWh'),
    ('diesel', 'litre'),
    ('gasoline', 'litre'),
    ('natural_gas_scf', 'scf'),
    ('lpg', 'litre'),
    ('transport', 'litre'),
    ('lignite_coal', 'kg'),
    ('heavy_fuel_oil_a', 'litre'),
    ('motor_gasoline', 'litre'),
    ('gas_diesel_oil', 'litre'),
    ('cng', 'kg'),
    ('biogas', 'm³'),
    ('r22', 'kg'),
    ('r134a', 'kg'),
]

def generate_test_data(year, month_count):
    """
    Generate test data for carbon emissions.

    Args:
        year: The year for the data
        month_count: Number of months to generate (1-12)

    Returns:
        DataFrame with test data
    """
    data = []

    for month in range(1, month_count + 1):
        # Generate 5-10 records per month with different categories
        num_records = random.randint(5, 10)

        for _ in range(num_records):
            category, unit = random.choice(CATEGORIES)

            # Generate random day in the month
            try:
                day = random.randint(1, 28)  # Safe for all months
                date = datetime(year, month, day)
            except ValueError:
                date = datetime(year, month, 1)

            # Generate realistic amounts based on category
            if category == 'grid_electricity':
                amount = round(random.uniform(100, 5000), 2)
            elif category in ['diesel', 'gasoline', 'motor_gasoline', 'gas_diesel_oil', 'transport']:
                amount = round(random.uniform(50, 1000), 2)
            elif category in ['natural_gas_scf']:
                amount = round(random.uniform(1000, 10000), 2)
            elif category in ['lpg']:
                amount = round(random.uniform(20, 500), 2)
            elif category in ['lignite_coal', 'cng']:
                amount = round(random.uniform(100, 2000), 2)
            elif category in ['heavy_fuel_oil_a']:
                amount = round(random.uniform(50, 800), 2)
            elif category in ['biogas']:
                amount = round(random.uniform(10, 500), 2)
            elif category in ['r22', 'r134a']:
                amount = round(random.uniform(0.5, 50), 2)
            else:
                amount = round(random.uniform(10, 1000), 2)

            data.append({
                'Date': date.strftime('%Y-%m-%d'),
                'Category': category,
                'Amount': amount,
                'Unit': unit
            })

    return pd.DataFrame(data)

def main():
    print("Generating test data files...")

    # Generate 2024 data (full year)
    print("\nGenerating 2024 test data (January - December)...")
    df_2024 = generate_test_data(2024, 12)
    df_2024 = df_2024.sort_values('Date')

    filename_2024 = 'test_data_2024_Jan_Dec.xlsx'
    df_2024.to_excel(filename_2024, index=False, sheet_name='Carbon Data 2024')
    print(f"[OK] Created {filename_2024}")
    print(f"  - Total records: {len(df_2024)}")
    print(f"  - Date range: {df_2024['Date'].min()} to {df_2024['Date'].max()}")
    print(f"  - Categories: {df_2024['Category'].nunique()}")

    # Generate 2025 data (January to October)
    print("\nGenerating 2025 test data (January - October)...")
    df_2025 = generate_test_data(2025, 10)
    df_2025 = df_2025.sort_values('Date')

    filename_2025 = 'test_data_2025_Jan_Oct.xlsx'
    df_2025.to_excel(filename_2025, index=False, sheet_name='Carbon Data 2025')
    print(f"[OK] Created {filename_2025}")
    print(f"  - Total records: {len(df_2025)}")
    print(f"  - Date range: {df_2025['Date'].min()} to {df_2025['Date'].max()}")
    print(f"  - Categories: {df_2025['Category'].nunique()}")

    # Display sample data
    print("\n" + "="*60)
    print("Sample data from 2024 file (first 10 rows):")
    print("="*60)
    print(df_2024.head(10).to_string(index=False))

    print("\n" + "="*60)
    print("Sample data from 2025 file (first 10 rows):")
    print("="*60)
    print(df_2025.head(10).to_string(index=False))

    print("\n" + "="*60)
    print("Summary statistics for 2024:")
    print("="*60)
    print(df_2024.groupby('Category')['Amount'].agg(['count', 'sum', 'mean']).round(2))

    print("\n" + "="*60)
    print("Summary statistics for 2025:")
    print("="*60)
    print(df_2025.groupby('Category')['Amount'].agg(['count', 'sum', 'mean']).round(2))

    print("\n[SUCCESS] Test data generation completed successfully!")
    print(f"\nGenerated files:")
    print(f"  1. {filename_2024} - Full year 2024 data")
    print(f"  2. {filename_2025} - Partial year 2025 data (Jan-Oct)")

if __name__ == '__main__':
    main()
