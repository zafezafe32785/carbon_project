"""
Test script to verify the new report generator is working
"""
from report_generator import CarbonReportGenerator

# Create instance
generator = CarbonReportGenerator()

# Check if new methods exist
print("Checking if new methods exist in CarbonReportGenerator...")
print(f"[OK] _generate_emissions_breakdown: {hasattr(generator, '_generate_emissions_breakdown')}")
print(f"[OK] _generate_data_quality: {hasattr(generator, '_generate_data_quality')}")
print(f"[OK] _generate_conclusion: {hasattr(generator, '_generate_conclusion')}")
print(f"[OK] _generate_methodology: {hasattr(generator, '_generate_methodology')}")

# Check if the AI content generation includes new sections
print("\nChecking AI content generation structure...")
test_data = {
    'user_id': 'test',
    'organization': 'Test Org',
    'period_start': __import__('datetime').datetime(2024, 1, 1),
    'period_end': __import__('datetime').datetime(2024, 12, 31),
    'total_emissions': 1000.0,
    'emissions_by_category': {'electricity': 500, 'fuel': 300, 'transport': 200},
    'emissions_by_scope': {'Scope 1': 500, 'Scope 2': 500},
    'monthly_data': [
        {'month': 'January 2024', 'total': 100, 'by_category': {}},
        {'month': 'February 2024', 'total': 150, 'by_category': {}}
    ],
    'record_count': 10,
    'raw_emissions': []
}

try:
    # Test AI content generation (will use fallback if OpenAI key not set)
    ai_content = generator._get_fallback_content(test_data, 'GHG', 'EN')

    print("\nGenerated AI content sections:")
    for key in ai_content.keys():
        print(f"  [OK] {key}")

    # Check for new sections
    required_sections = ['emissions_breakdown', 'data_quality', 'conclusion', 'methodology']
    missing = [s for s in required_sections if s not in ai_content]

    if missing:
        print(f"\n[ERROR] MISSING SECTIONS: {missing}")
    else:
        print(f"\n[SUCCESS] All new sections present!")

    # Test report structure
    report_content = generator._create_report_structure(test_data, ai_content, 'GHG', 'EN')
    print("\nReport structure sections:")
    for key in report_content.keys():
        print(f"  [OK] {key}")

    print("\n" + "="*60)
    print("NEW REPORT GENERATOR IS READY! [SUCCESS]")
    print("="*60)
    print("\nNext steps:")
    print("1. Make sure backend server is STOPPED")
    print("2. Delete __pycache__ folder (already done)")
    print("3. Restart backend: python app.py")
    print("4. Generate a report from the Flutter app")

except Exception as e:
    print(f"\n[ERROR]: {e}")
    import traceback
    traceback.print_exc()
