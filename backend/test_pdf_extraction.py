"""
Test script to verify PDF bill extraction
"""
import pdfplumber
import re
from typing import Dict, Optional

def convert_thai_date_to_gregorian(date_str: str) -> Optional[Dict[str, int]]:
    """Convert Thai date to Gregorian"""
    try:
        parts = date_str.strip().split('/')
        if len(parts) != 3:
            return None

        day = int(parts[0])
        month = int(parts[1])
        year = int(parts[2])

        if year < 100:
            year += 1900 if year >= 50 else 2000
        if year > 2500:
            year -= 543

        if not (1 <= day <= 31 and 1 <= month <= 12 and 2000 <= year <= 2030):
            return None

        return {'day': day, 'month': month, 'year': year}
    except:
        return None

def calculate_usage_period(reading_month: int, reading_year: int) -> Dict[str, int]:
    """Calculate usage period (reading date - 1 month)"""
    usage_month = reading_month - 1
    usage_year = reading_year

    if usage_month < 1:
        usage_month = 12
        usage_year -= 1

    return {'month': usage_month, 'year': usage_year}

def test_pdf(pdf_path: str):
    """Test PDF extraction"""
    print(f"\n{'='*60}")
    print(f"Testing: {pdf_path}")
    print('='*60)

    try:
        with pdfplumber.open(pdf_path) as pdf:
            text = ""
            for page in pdf.pages:
                text += page.extract_text() + "\n"

        print(f"\nExtracted text ({len(text)} characters):\n")
        print(text[:800])
        print("\n" + "="*60)

        # Detect format
        if 'การไฟฟ้านครหลวง' in text or 'วันที่จดเลขอ่าน' in text:
            format_type = "MEA"
        elif 'การไฟฟ้าส่วนภูมิภาค' in text or 'วันที่อ่านหน่วย' in text:
            format_type = "PEA"
        else:
            format_type = "UNKNOWN"

        print(f"\n✓ Detected format: {format_type}")

        # Extract date
        if format_type == "MEA":
            date_pattern = r'วันที่จดเลขอ่าน[:\s]*(\d{1,2}/\d{1,2}/\d{2,4})'
            usage_pattern = r'จำนวนหน่วย[:\s]*(\d+(?:\.\d+)?)'
        else:  # PEA
            date_pattern = r'วันที่อ่านหน่วย[:\s]*(\d{1,2}/\d{1,2}/\d{2,4})'
            usage_pattern = r'จำนวนที่ใช้[:\s]*(\d+(?:\.\d+)?)'
            period_pattern = r'ประจำเดือน[:\s]*(\d{1,2})/(\d{2,4})'

        # Find date
        date_match = re.search(date_pattern, text, re.IGNORECASE)
        if date_match:
            reading_date_str = date_match.group(1)
            reading_date = convert_thai_date_to_gregorian(reading_date_str)
            print(f"✓ Reading date: {reading_date_str} → {reading_date['month']:02d}/{reading_date['year']}")

            # Calculate usage period
            if format_type == "PEA":
                # Try to find bill period first
                period_match = re.search(period_pattern, text, re.IGNORECASE)
                if period_match:
                    month = int(period_match.group(1))
                    year = int(period_match.group(2))
                    if year < 100:
                        year += 1900 if year >= 50 else 2000
                    if year > 2500:
                        year -= 543
                    usage_period = {'month': month, 'year': year}
                    print(f"✓ Bill period (ประจำเดือน): {period_match.group(1)}/{period_match.group(2)} → {month:02d}/{year}")
                else:
                    usage_period = calculate_usage_period(reading_date['month'], reading_date['year'])
            else:
                usage_period = calculate_usage_period(reading_date['month'], reading_date['year'])

            print(f"✓ Usage period: {usage_period['month']:02d}/{usage_period['year']}")
        else:
            print("✗ Could not find reading date")

        # Find usage
        usage_match = re.search(usage_pattern, text, re.IGNORECASE)
        if usage_match:
            usage = float(usage_match.group(1))
            print(f"✓ Usage: {usage} kWh")

            # Calculate CO2
            emission_factor = 0.4999
            co2 = usage * emission_factor
            print(f"✓ CO2 equivalent: {co2:.2f} kg CO2")
        else:
            print("✗ Could not find usage")

        print("\n" + "="*60)
        print("✓ PDF Extraction Test Complete!")
        print("="*60 + "\n")

    except Exception as e:
        print(f"\n✗ Error: {str(e)}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    # Test with your sample PDFs
    # Replace these paths with actual PDF file paths if you have them

    print("\n" + "="*60)
    print("PDF BILL EXTRACTION TEST")
    print("="*60)

    # Example: Test PEA bill
    # test_pdf("path/to/pea_bill.pdf")

    # Example: Test MEA bill
    # test_pdf("path/to/mea_bill.pdf")

    print("\nTo test with your PDFs, update the paths in this script.")
    print("Example: test_pdf('your_pea_bill.pdf')")
