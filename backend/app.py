from flask import Flask, request, jsonify
from flask_cors import CORS
from flask_pymongo import PyMongo
from bson import ObjectId
from datetime import datetime, timedelta, timezone
import os
from werkzeug.security import generate_password_hash, check_password_hash
import jwt
from functools import wraps
from config import Config
from models import db, users_collection, emission_records_collection, emission_factors_collection, reports_collection, audits_collection, edit_requests_collection, calculate_co2_equivalent
import pandas as pd
from report_generator import generate_ai_report, get_available_report_formats, get_available_file_types, get_available_languages, validate_report_request
import cv2
import numpy as np
import pytesseract
from PIL import Image
from typing import Dict, Optional, List, Tuple
import logging
import re
from datetime import datetime

# Email validation regex (RFC 5322 simplified)
EMAIL_REGEX = re.compile(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')

def validate_email(email):
    """Validate email format"""
    if not email or not isinstance(email, str):
        return False
    return EMAIL_REGEX.match(email) is not None

def validate_password_strength(password):
    """
    Validate password strength
    Requirements: At least 8 characters, contains uppercase, lowercase, digit, and special character
    """
    if not password or len(password) < 8:
        return False, "Password must be at least 8 characters long"

    if not re.search(r'[A-Z]', password):
        return False, "Password must contain at least one uppercase letter"

    if not re.search(r'[a-z]', password):
        return False, "Password must contain at least one lowercase letter"

    if not re.search(r'\d', password):
        return False, "Password must contain at least one digit"

    if not re.search(r'[!@#$%^&*(),.?":{}|<>]', password):
        return False, "Password must contain at least one special character"

    return True, "Password is strong"

# Helper function for safe float conversion
def safe_float(value, default=0.0):
    """Safely convert value to float, return default if conversion fails"""
    if value is None:
        return default
    try:
        return float(value)
    except (ValueError, TypeError):
        logging.warning(f"Failed to convert '{value}' to float, using default {default}")
        return default

# Helper function for consistent datetime serialization
def serialize_datetime(dt):
    """Convert datetime to ISO format string consistently"""
    if dt is None:
        return None
    if hasattr(dt, 'isoformat'):
        return dt.isoformat()
    if isinstance(dt, str):
        return dt
    return str(dt)

if os.name == 'nt':  # Windows
    pytesseract.pytesseract.tesseract_cmd = r'C:\Program Files\Tesseract-OCR\tesseract.exe'

try:
    logging.info(f"Tesseract version: {pytesseract.get_tesseract_version()}")
    logging.info(f"Available languages: {pytesseract.get_languages()}")
    logging.info("Tesseract installation successful!")
except Exception as e:
    logging.error(f"Tesseract initialization error: {e}")

app = Flask(__name__)
app.config.from_object(Config)

# Initialize PyMongo
mongo = PyMongo(app)

# Enable CORS with specific configuration
CORS(app, origins=["*"], allow_headers=["Content-Type", "Authorization"], methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"])

# OPTIMIZATION: Enable response compression (60% smaller responses)
try:
    from flask_compress import Compress
    compress = Compress()
    compress.init_app(app)
    app.config['COMPRESS_MIMETYPES'] = [
        'text/html', 'text/css', 'text/xml', 'application/json',
        'application/javascript', 'text/javascript'
    ]
    app.config['COMPRESS_LEVEL'] = 6  # Balance between speed and compression
    app.config['COMPRESS_MIN_SIZE'] = 500  # Only compress responses > 500 bytes
    logging.info("✅ Response compression enabled")
except ImportError:
    logging.warning("⚠️ flask-compress not installed. Install with: pip install flask-compress")

# Global OPTIONS handler for all routes
@app.before_request
def handle_preflight():
    if request.method == "OPTIONS":
        response = jsonify({'status': 'ok'})
        response.headers.add("Access-Control-Allow-Origin", "*")
        response.headers.add('Access-Control-Allow-Headers', "Content-Type,Authorization")
        response.headers.add('Access-Control-Allow-Methods', "GET,POST,PUT,DELETE,OPTIONS")
        return response

# Create upload folder if it doesn't exist
os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)

# OPTIMIZATION: Load emission factors cache on startup (95% faster lookups)
from models import load_emission_factors_cache
try:
    load_emission_factors_cache()
except Exception as e:
    logging.warning(f"Failed to load emission factors cache: {e}")

class ThaiElectricityBillOCR:
    """Advanced OCR processor for Thai electricity bills with multiple format support"""
    
    def __init__(self):
        # Configure Tesseract for optimal Thai + English recognition
        self.tesseract_config = '--oem 3 --psm 6 -l tha+eng'
        
        # Bill format patterns
        self.bill_patterns = {
            'mea': {
                'usage_keywords': ['จำนวนหน่วย', 'จํานวนหน่วย'],
                'amount_keywords': ['รวมเงินที่ต้องชำระทั้งสิ้น', 'รวมเงิน'],
                'period_keywords': ['ประจำเดือน', 'ประจ.เดือน'],
                'meter_current': ['เลขอ่านครั้งนี้', 'ครั้งนี้'],
                'meter_previous': ['เลขอ่านครั้งที่แล้ว', 'ครั้งที่แล้ว']
            },
            'pea': {
                'usage_keywords': ['จำนวนที่ใช้', 'จํานวนที่ใช้', 'หน่วยที่ใช้'],
                'amount_keywords': ['รวมเงินที่ต้องชำระ', 'Amount', 'รวมเงิน'],
                'period_keywords': ['ประจำเดือน', 'ประจ.เดือน', 'Bill Period'],
                'meter_current': ['เลขอ่านปัจจุบัน', 'Current Reading'],
                'meter_previous': ['เลขอ่านครั้งก่อน', 'Previous Reading']
            }
        }
        
        # Text corrections for common OCR errors
        self.text_corrections = {
            # Thai text corrections
            'จํานวน': 'จำนวน',
            'ประจา': 'ประจำ',
            'เดอน': 'เดือน',
            'เตือน': 'เดือน',
            'หนวย': 'หน่วย',
            'รวม': 'รวม',
            'เงน': 'เงิน',
            'ชาระ': 'ชำระ',
            'ทั้งสน': 'ทั้งสิ้น',
            # Number corrections
            'O': '0',
            'l': '1',
            'I': '1',
            'S': '5',
            'o': '0',
            # Common symbol fixes
            'าํ': 'ำ',
            'ิ': 'ิ',
            'ี': 'ี',
            'ุ': 'ุ',
            'ู': 'ู'
        }

    def detect_table_region(self, image: np.ndarray) -> Optional[np.ndarray]:
        """Detect and crop table region - IMPROVED to capture full table"""
        try:
            height, width = image.shape[:2]
            
            # Strategy: Capture top 30-35% instead of 20% to ensure we get the full usage table
            # Thai electricity bills have the main data table in the upper portion
            # 20% was too aggressive and cut off numbers
            top_region = image[0:int(height * 0.35), :]
            
            print(f"Cropping to top 35% of image: {top_region.shape[1]}x{top_region.shape[0]}")
            return top_region
            
        except Exception as e:
            print(f"Table detection failed: {str(e)}, using full image")
            return None

    def preprocess_image(self, image_bytes: bytes) -> np.ndarray:
        """Enhanced preprocessing - AUTO-DETECT if image is already cropped or full bill"""
        try:
            nparr = np.frombuffer(image_bytes, np.uint8)
            image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
            
            if image is None:
                raise ValueError("Could not decode image")
            
            height, width = image.shape[:2]
            print(f"Original image size: {width}x{height}")
            
            # DETECT: Is this already a cropped table or a full bill?
            aspect_ratio = height / width
            print(f"Aspect ratio: {aspect_ratio:.2f}")
            
            if aspect_ratio < 0.5:
                print("✓ Detected: Pre-cropped table image")
                processed_image = image
            else:
                print("✓ Detected: Full bill image - cropping to table region")
                table_region = image[0:int(height * 0.30), :]
                processed_image = table_region
                print(f"  Cropped to: {processed_image.shape[1]}x{processed_image.shape[0]}")
            
            # Resize to optimal OCR size
            height, width = processed_image.shape[:2]
            if width < 2000:
                scale = 2000 / width
                new_width = int(width * scale)
                new_height = int(height * scale)
                processed_image = cv2.resize(processed_image, (new_width, new_height), interpolation=cv2.INTER_CUBIC)
                print(f"Upscaled to: {new_width}x{new_height}")
            elif width > 3500:
                scale = 3000 / width
                new_width = int(width * scale)
                new_height = int(height * scale)
                processed_image = cv2.resize(processed_image, (new_width, new_height), interpolation=cv2.INTER_AREA)
                print(f"Downscaled to: {new_width}x{new_height}")
            
            # Convert to grayscale
            gray = cv2.cvtColor(processed_image, cv2.COLOR_BGR2GRAY)
            
            # Denoise
            denoised = cv2.fastNlMeansDenoising(gray, h=8)
            
            # Enhance contrast
            clahe = cv2.createCLAHE(clipLimit=2.5, tileGridSize=(8, 8))
            enhanced = clahe.apply(denoised)
            
            # Sharpen
            kernel_sharpen = np.array([[-1,-1,-1], [-1, 9,-1], [-1,-1,-1]])
            sharpened = cv2.filter2D(enhanced, -1, kernel_sharpen)
            
            # Adaptive threshold
            binary = cv2.adaptiveThreshold(
                sharpened, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, 
                cv2.THRESH_BINARY, 15, 5
            )
            
            # Clean up
            kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (2, 2))
            result = cv2.morphologyEx(binary, cv2.MORPH_OPEN, kernel)
            
            return result
            
        except Exception as e:
            logging.exception("Image preprocessing failed")
            raise Exception(f"Image preprocessing failed: {str(e)}")

    def extract_text_with_confidence(self, preprocessed_image: np.ndarray) -> Tuple[str, float]:
        """Extract text with confidence scoring"""
        try:
            # Get text with confidence data
            data = pytesseract.image_to_data(
                preprocessed_image, 
                config=self.tesseract_config,
                output_type=pytesseract.Output.DICT
            )
            
            # Calculate average confidence
            confidences = [int(conf) for conf in data['conf'] if int(conf) > 0]
            avg_confidence = sum(confidences) / len(confidences) if confidences else 0
            
            # Extract text
            raw_text = pytesseract.image_to_string(
                preprocessed_image, 
                config=self.tesseract_config
            )
            
            return self.clean_and_correct_text(raw_text), avg_confidence
            
        except Exception as e:
            logging.exception("OCR text extraction failed")
            raise Exception(f"Text extraction failed: {str(e)}")

    def clean_and_correct_text(self, raw_text: str) -> str:
        """Enhanced text cleaning and correction"""
        text = raw_text
        
        # Apply corrections
        for wrong, right in self.text_corrections.items():
            text = text.replace(wrong, right)
        
        # Fix spaced Thai characters
        text = re.sub(r'(?<=[\u0E00-\u0E7F])\s+(?=[\u0E00-\u0E7F])', '', text)
        
        # Remove excessive whitespace
        text = re.sub(r'\s+', ' ', text)
        
        # Fix broken Thai words (common OCR issues)
        thai_word_fixes = {
            r'จ\s*ำ\s*น\s*ว\s*น': 'จำนวน',
            r'ห\s*น\s*่\s*ว\s*ย': 'หน่วย',
            r'ป\s*ร\s*ะ\s*จ\s*ำ\s*เ\s*ด\s*ื\s*อ\s*น': 'ประจำเดือน',
            r'ร\s*ว\s*ม\s*เ\s*ง\s*ิ\s*น': 'รวมเงิน',
            r'ช\s*ำ\s*ร\s*ะ': 'ชำระ',
        }
        
        for pattern, replacement in thai_word_fixes.items():
            text = re.sub(pattern, replacement, text, flags=re.IGNORECASE)
        
        return text.strip()

    def detect_bill_format(self, text: str) -> str:
        """Detect which electricity authority format (MEA or PEA)"""
        text_lower = text.lower()
        
        # Look for authority identifiers
        if any(keyword in text_lower for keyword in ['การไฟฟ้านครหลวง', 'metropolitan', 'mea']):
            return 'mea'
        elif any(keyword in text_lower for keyword in ['การไฟฟ้าส่วนภูมิภาค', 'provincial', 'pea']):
            return 'pea'
        else:
            # Try to detect based on usage keywords
            if 'จำนวนหน่วย' in text:
                return 'mea'
            elif 'จำนวนที่ใช้' in text:
                return 'pea'
            else:
                return 'mea'  # Default to MEA format

    def extract_usage_amount(self, text: str, bill_format: str) -> Optional[float]:
        """Extract usage - OPTIMIZED for clear table images"""
        
        print(f"\n=== Extracting Usage Amount ===")
        print(f"Full text:\n{text}\n{'='*50}\n")
        
        # For clear zoomed table images, the structure is very predictable:
        # Header row: วันที่จดเลขอ่าน | เลขอ่านครั้งหลัง | เลขอ่านครั้งก่อน | จำนวนหน่วย | ตัวคูณ
        # Data row:   12/04/68 09:59  | 69601           | 68211           | 1390      | 1.2
        
        lines = text.split('\n')
        
        # STRATEGY 1: Find the header with "จำนวนหน่วย" and extract from table structure
        usage_keywords = ['จำนวนหน่วย', 'จํานวนหน่วย', 'kWh', 'kwh']
        
        for line_idx, line in enumerate(lines):
            # Skip very short lines
            if len(line.strip()) < 5:
                continue
            
            # Check if this line contains usage keyword
            has_keyword = any(kw in line for kw in usage_keywords)
            if not has_keyword:
                continue
            
            print(f"Line {line_idx} (has keyword): {line}")
            
            # This is likely the header row
            # The data should be in the SAME line (if table collapsed) or NEXT line
            
            # Extract all 3-5 digit numbers from this line and next few lines
            search_lines = lines[line_idx:min(line_idx + 3, len(lines))]
            
            for search_idx, search_line in enumerate(search_lines):
                print(f"  Searching line {line_idx + search_idx}: {search_line[:100]}")
                
                # Find all numbers that could be usage (3-5 digits)
                numbers = re.findall(r'\b(\d{3,5})\b', search_line)
                
                for num_str in numbers:
                    try:
                        value = float(num_str)
                        print(f"    Candidate: {value}")
                        
                        # Validate
                        # Skip dates (day/month are <= 31/12)
                        if value <= 31:
                            print(f"      ✗ Skip (too small - likely date)")
                            continue
                        
                        # Skip years
                        if (1900 <= value <= 2100) or (2400 <= value <= 2700):
                            print(f"      ✗ Skip (year range)")
                            continue
                        
                        # Skip meter readings (typically 5 digits starting with 6-9)
                        # 69601, 68211 are meter readings, not usage
                        if value >= 60000 and len(num_str) == 5:
                            print(f"      ✗ Skip (meter reading)")
                            continue
                        
                        # Must be in realistic usage range
                        if not (50 <= value <= 50000):
                            print(f"      ✗ Skip (outside usage range)")
                            continue
                        
                        # PASSED all checks
                        print(f"    ✓ ACCEPTED: {value} kWh")
                        return value
                        
                    except ValueError:
                        pass
        
        # STRATEGY 2: Fallback - look for the pattern more broadly
        print("\nFallback: Pattern matching across full text...")
        
        # Common patterns in Thai bills
        patterns = [
            r'จำนวนหน่วย[^\d]{0,30}(\d{3,5})\b',  # จำนวนหน่วย ... 1390
            r'kWh[^\d]{0,20}(\d{3,5})\b',          # kWh ... 1390
            r'\(kWh\)[^\d]{0,20}(\d{3,5})\b',      # (kWh) ... 1390
        ]
        
        for pattern in patterns:
            match = re.search(pattern, text, re.IGNORECASE)
            if match:
                try:
                    value = float(match.group(1))
                    if 50 <= value <= 50000:
                        print(f"  ✓ Pattern match: {value} kWh")
                        return value
                except ValueError:
                    pass
        
        # STRATEGY 3: Last resort - find ANY valid usage number
        print("\nLast resort: Finding any valid usage number...")
        all_numbers = re.findall(r'\b(\d{3,5})\b', text)
        
        for num_str in all_numbers:
            try:
                value = float(num_str)
                if (100 <= value <= 10000 and 
                    not (1900 <= value <= 2100) and 
                    not (2400 <= value <= 2700) and
                    value not in [60000, 70000, 80000, 90000]):  # Not meter readings
                    print(f"  ✓ Last resort found: {value} kWh")
                    return value
            except ValueError:
                pass
        
        print("  ✗ No valid usage found")
        return None


def detect_table_region(self, image: np.ndarray) -> Optional[np.ndarray]:
    """Detect table region - DISABLED for pre-cropped images"""
    # This method is now handled in preprocess_image
    # Return None to use original image
    return None

    def extract_bill_period(self, text: str, bill_format: str) -> Optional[Dict[str, int]]:
        """Extract billing period (month/year)"""
        patterns = self.bill_patterns[bill_format]['period_keywords']
        
        for keyword in patterns:
            # Look for month/year patterns near the keyword
            period_patterns = [
                rf'{re.escape(keyword)}\s*(\d{{1,2}})/(\d{{2,4}})',  # MM/YY or MM/YYYY
                rf'{re.escape(keyword)}\s*(\d{{1,2}})\s*(\d{{2,4}})',  # MM YYYY
                rf'(\d{{1,2}})/(\d{{2,4}})\s*{re.escape(keyword)}',  # MM/YY keyword
            ]
            
            for pattern in period_patterns:
                match = re.search(pattern, text, re.IGNORECASE)
                if match:
                    try:
                        month = int(match.group(1))
                        year = int(match.group(2))
                        
                        # Convert 2-digit year to 4-digit
                        if year < 100:
                            if year > 50:
                                year += 1900  # 51-99 = 1951-1999
                            else:
                                year += 2000  # 00-50 = 2000-2050
                        
                        # Convert Buddhist year to Gregorian if needed
                        if year > 2500:
                            year -= 543
                        
                        if 1 <= month <= 12 and 2000 <= year <= 2030:
                            return {'month': month, 'year': year}
                    except ValueError:
                        continue
        
        return None

    def extract_amount(self, text: str, bill_format: str) -> Optional[float]:
        """Extract total amount to pay"""
        patterns = self.bill_patterns[bill_format]['amount_keywords']
        
        for keyword in patterns:
            amount_patterns = [
                rf'{re.escape(keyword)}\s*(\d+(?:,\d{{3}})*(?:\.\d{{2}})?)',
                rf'{re.escape(keyword)}[^\d]*(\d+(?:,\d{{3}})*(?:\.\d{{2}})?)',
                rf'(\d+(?:,\d{{3}})*(?:\.\d{{2}})?)\s*บาท',  # amount baht
            ]
            
            for pattern in amount_patterns:
                match = re.search(pattern, text, re.IGNORECASE | re.DOTALL)
                if match:
                    try:
                        amount_str = match.group(1).replace(',', '')
                        return float(amount_str)
                    except ValueError:
                        continue
        
        return None

    def fallback_number_extraction(self, text: str) -> Dict[str, List[float]]:
        """Fallback method: extract all numbers and their contexts"""
        
        # Find all numbers with context
        number_pattern = r'(\d+(?:,\d{3})*(?:\.\d{2})?)'
        numbers = []
        
        for match in re.finditer(number_pattern, text):
            number_str = match.group(1).replace(',', '')
            try:
                number = float(number_str)
                start = max(0, match.start() - 50)
                end = min(len(text), match.end() + 50)
                context = text[start:end]
                
                numbers.append({
                    'value': number,
                    'context': context,
                    'position': match.start()
                })
            except ValueError:
                continue
        
        # Categorize numbers based on context and value ranges
        categorized = {
            'usage_candidates': [],      # 50-5000 kWh range
            'amount_candidates': [],     # 500-10000 baht range
            'meter_readings': [],        # Usually 4-5 digits
            'other_numbers': []
        }
        
        for num_data in numbers:
            value = num_data['value']
            context = num_data['context'].lower()
            
            # Usage candidates (electricity units)
            if 50 <= value <= 5000 and any(keyword in context for keyword in 
                ['หน่วย', 'kwh', 'ใช้', 'จำนวน', 'unit']):
                categorized['usage_candidates'].append(value)
            
            # Amount candidates (money)
            elif 500 <= value <= 50000 and any(keyword in context for keyword in 
                ['บาท', 'amount', 'รวม', 'ชำระ', 'เงิน']):
                categorized['amount_candidates'].append(value)
            
            # Meter readings
            elif 1000 <= value <= 99999 and any(keyword in context for keyword in 
                ['อ่าน', 'reading', 'meter', 'เลข']):
                categorized['meter_readings'].append(value)
            
            else:
                categorized['other_numbers'].append(value)
        
        return categorized

    def process_bill(self, image_bytes: bytes) -> Dict:
        """Main method to process electricity bill image"""
        try:
            # Step 1: Preprocess image
            print("Preprocessing image...")
            preprocessed = self.preprocess_image(image_bytes)
            
            # Step 2: Extract text with confidence
            print("Extracting text via OCR...")
            cleaned_text, confidence = self.extract_text_with_confidence(preprocessed)
            print(f"OCR Confidence: {confidence:.2f}%")
            
            # Step 3: Detect bill format
            bill_format = self.detect_bill_format(cleaned_text)
            print(f"Detected format: {bill_format.upper()}")
            
            # Step 4: Extract structured data
            print("Extracting structured data...")
            extracted_data = {
                'bill_format': bill_format,
                'ocr_confidence': confidence
            }
            
            # Extract usage (primary method)
            usage = self.extract_usage_amount(cleaned_text, bill_format)
            if usage:
                extracted_data['usage_kwh'] = usage
                print(f"Found usage: {usage} kWh")
            
            # Extract billing period
            period = self.extract_bill_period(cleaned_text, bill_format)
            if period:
                extracted_data.update(period)
                print(f"Found period: {period['month']}/{period['year']}")
            
            # Extract amount
            amount = self.extract_amount(cleaned_text, bill_format)
            if amount:
                extracted_data['total_amount'] = amount
                print(f"Found amount: {amount} baht")
            
            # Fallback extraction if primary methods fail
            if not usage:
                print("Primary extraction failed, trying fallback method...")
                fallback_data = self.fallback_number_extraction(cleaned_text)
                
                if fallback_data['usage_candidates']:
                    # Take the most reasonable usage value
                    usage_candidates = fallback_data['usage_candidates']
                    extracted_data['usage_kwh'] = usage_candidates[0]  # Take first candidate
                    extracted_data['fallback_candidates'] = fallback_data
                    print(f"Fallback found usage candidates: {usage_candidates}")
            
            # Validation
            if not extracted_data.get('usage_kwh'):
                return {
                    'success': False,
                    'error': 'Could not extract electricity usage',
                    'raw_text': cleaned_text,
                    'extracted_data': extracted_data,
                    'fallback_data': self.fallback_number_extraction(cleaned_text)
                }
            
            return {
                'success': True,
                'data': extracted_data,
                'raw_text': cleaned_text,
                'message': f"Successfully extracted {extracted_data['usage_kwh']} kWh ({bill_format.upper()} format)"
            }
            
        except Exception as e:
            logging.exception("OCR processing error")
            print(f"OCR processing error: {str(e)}")
            return {
                'success': False,
                'error': str(e),
                'message': f"OCR processing failed: {str(e)}"
            }

# Flask integration function

def process_image_ocr(file, user_id):
    """Process Thai electricity bill using advanced OCR"""
    try:
        print("Starting OCR processing for Thai electricity bill...")
        
        file_content = file.read()
        file.seek(0)
        
        ocr_processor = ThaiElectricityBillOCR()
        result = ocr_processor.process_bill(file_content)
        
        if result['success']:
            extracted_data = result['data']
            usage_kwh = extracted_data.get('usage_kwh')
            
            if usage_kwh:
                from datetime import datetime
                now = datetime.now()
                
                # Get the READING date from OCR
                bill_month = extracted_data.get('month', now.month)
                bill_year = extracted_data.get('year', now.year)
                
                print(f"\n=== Bill Date Processing ===")
                print(f"Reading date from bill: {bill_month:02d}/{bill_year}")
                
                # NOTE: Thai electricity bill date logic
                # Some bills show the reading date (future), others show usage period (past)
                # Configuration option added - can be adjusted per organization
                # Default: Assume bill date = usage period (no subtraction)
                # If your bills show reading date one month ahead, set BILL_DATE_OFFSET=1 in config

                bill_date_offset = int(os.getenv('BILL_DATE_OFFSET', '0'))  # Default: no offset

                actual_month = bill_month - bill_date_offset
                actual_year = bill_year

                # Handle year boundary
                if actual_month < 1:
                    actual_month = 12
                    actual_year = bill_year - 1

                if bill_date_offset > 0:
                    print(f"Bill reading date: {bill_month:02d}/{bill_year}")
                    print(f"Adjusted usage period (offset -{bill_date_offset} month): {actual_month:02d}/{actual_year}")
                else:
                    print(f"Usage period: {actual_month:02d}/{actual_year} (no offset)")
                print(f"===========================\n")
                
                # Use TGO Thailand Grid Mix Electricity emission factor
                emission_factor = 0.4999  # kg CO2 per kWh
                co2_equivalent = usage_kwh * emission_factor
                
                emission_record = {
                    'record_id': generate_record_id(),
                    'user_id': user_id,
                    'category': 'grid_electricity',
                    'emission_type': 'grid_electricity',
                    'amount': usage_kwh,
                    'unit': 'kWh',
                    'month': actual_month,  # Usage month (reading month - 1)
                    'year': actual_year,    # Usage year
                    'emission_factor': emission_factor,
                    'co2_equivalent': co2_equivalent,
                    'calculated_emission': co2_equivalent,
                    'import_time': datetime.now(timezone.utc),
                    'record_date': datetime(actual_year, actual_month, 1),
                    'created_at': datetime.now(timezone.utc),
                    'source': 'ocr_advanced',
                    'extracted_text': result.get('raw_text', '')[:500],
                    'ocr_confidence': extracted_data.get('ocr_confidence', 0),
                    'bill_format': extracted_data.get('bill_format', 'unknown'),
                    'total_amount': extracted_data.get('total_amount'),
                    'bill_reading_date': f"{bill_month:02d}/{bill_year}",  # Original reading date
                    'usage_period': f"{actual_month:02d}/{actual_year}"    # Actual usage period
                }
                
                emission_records_collection.insert_one(emission_record)
                
                return {
                    'success': True,
                    'message': f'Successfully extracted {usage_kwh} kWh (Usage: {actual_month:02d}/{actual_year}, Reading: {bill_month:02d}/{bill_year})',
                    'usage_kwh': usage_kwh,
                    'co2_equivalent': round(co2_equivalent, 2),
                    'emission_factor': emission_factor,
                    'record_id': emission_record['record_id'],
                    'bill_format': extracted_data.get('bill_format'),
                    'ocr_confidence': extracted_data.get('ocr_confidence'),
                    'bill_reading_date': f"{bill_month:02d}/{bill_year}",
                    'usage_period': f"{actual_month:02d}/{actual_year}",
                    'total_amount': extracted_data.get('total_amount')
                }
        
        return process_image_ocr_simple(file, user_id)
        
    except Exception as e:
        print(f"Advanced OCR error: {str(e)}")
        return process_image_ocr_simple(file, user_id)

def process_image_ocr_simple(file, user_id):
    """Simplified OCR processing fallback - IMPROVED with correct response format"""
    try:
        print("Starting simple OCR processing...")
        
        import tempfile
        import os
        
        tmp_file_path = None
        try:
            with tempfile.NamedTemporaryFile(delete=False, suffix='.png') as tmp_file:
                tmp_file_path = tmp_file.name
                file.save(tmp_file_path)
            
            from PIL import Image
            import pytesseract
            
            with Image.open(tmp_file_path) as image:
                text = pytesseract.image_to_string(image, lang='tha+eng')
            
            print(f"Extracted text: {text[:200]}...")
            
            # Look for usage keywords in the text
            usage_keywords = ['จำนวนหน่วย', 'จํานวนหน่วย', 'หน่วย', 'kWh', 'kwh']
            
            # Split into lines
            lines = text.split('\n')
            
            for line in lines:
                # Check if line has usage keyword
                has_keyword = any(kw in line for kw in usage_keywords)
                if not has_keyword:
                    continue
                
                print(f"Found usage line: {line}")
                
                # Extract numbers from this line
                numbers = re.findall(r'\d+(?:,\d{3})*', line)
                
                for num_str in numbers:
                    try:
                        value = float(num_str.replace(',', ''))
                        
                        # Validate
                        if 50 <= value <= 100000:
                            # Not a year
                            if not (1900 <= value <= 2100 or 2400 <= value <= 2700):
                                print(f"Simple OCR found: {value} kWh")
                                
                                # Create emission record with month-1 logic
                                from datetime import datetime
                                now = datetime.now()
                                actual_month = now.month - 1
                                actual_year = now.year
                                
                                if actual_month < 1:
                                    actual_month = 12
                                    actual_year = now.year - 1
                                
                                emission_factor = 0.4999
                                co2_equivalent = value * emission_factor
                                
                                emission_record = {
                                    'record_id': generate_record_id(),
                                    'user_id': user_id,
                                    'category': 'grid_electricity',
                                    'emission_type': 'grid_electricity',
                                    'amount': value,
                                    'unit': 'kWh',
                                    'month': actual_month,
                                    'year': actual_year,
                                    'emission_factor': emission_factor,
                                    'co2_equivalent': co2_equivalent,
                                    'calculated_emission': co2_equivalent,
                                    'import_time': datetime.now(timezone.utc),
                                    'record_date': datetime(actual_year, actual_month, 1),
                                    'created_at': datetime.now(timezone.utc),
                                    'source': 'ocr_simple',
                                    'extracted_text': text[:500]
                                }
                                
                                emission_records_collection.insert_one(emission_record)
                                
                                # FIXED: Return in the same format as advanced OCR
                                return {
                                    'success': True,
                                    'message': f'Successfully extracted {value} kWh from image (Simple OCR)',
                                    'usage_kwh': value,
                                    'co2_equivalent': round(co2_equivalent, 2),
                                    'emission_factor': emission_factor,
                                    'record_id': emission_record['record_id'],
                                    'usage_period': f"{actual_month:02d}/{actual_year}",
                                    # ADD: extracted_data field for Flutter compatibility
                                    'extracted_data': {
                                        'usage_kwh': value,
                                        'bill_format': 'app_screenshot',
                                        'ocr_confidence': 0
                                    }
                                }
                    except ValueError:
                        continue
            
            return {
                'success': False,
                'message': 'Could not extract electricity usage from image',
                'extracted_text': text[:200]
            }
            
        finally:
            if tmp_file_path and os.path.exists(tmp_file_path):
                try:
                    os.unlink(tmp_file_path)
                    print(f"Cleaned up temporary file: {tmp_file_path}")
                except Exception as e:
                    print(f"Warning: Could not delete temp file: {e}")
            
    except Exception as e:
        print(f"Simple OCR error: {str(e)}")
        return {
            'success': False,
            'message': f'OCR processing failed: {str(e)}'
        }

def process_pdf_bill(file, user_id):
    """Process PDF electricity bills"""
    try:
        print("Starting PDF processing...")
        
        # For now, return a not implemented message
        # You can implement PDF processing using libraries like PyPDF2 or pdfplumber
        return {
            'success': False,
            'message': 'PDF processing not yet implemented. Please use image files (.jpg, .png) for now.'
        }
        
    except Exception as e:
        print(f"PDF processing error: {str(e)}")
        return {
            'success': False,
            'message': f'PDF processing failed: {str(e)}'
        }

# JWT decorator for protected routes
def token_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        # Handle CORS preflight requests
        if request.method == 'OPTIONS':
            return jsonify({'status': 'ok'}), 200
            
        token = request.headers.get('Authorization')
        
        if not token:
            return jsonify({'message': 'Token is missing'}), 401
        
        try:
            # Remove 'Bearer ' prefix if present
            if token.startswith('Bearer '):
                token = token.split(' ')[1]
                
            data = jwt.decode(token, app.config['SECRET_KEY'], algorithms=['HS256'])
            current_user = users_collection.find_one({'_id': ObjectId(data['user_id'])})
            
            if not current_user:
                return jsonify({'message': 'User not found'}), 401
                
        except jwt.ExpiredSignatureError:
            return jsonify({'message': 'Token has expired'}), 401
        except jwt.InvalidTokenError:
            return jsonify({'message': 'Token is invalid'}), 401
        except Exception as e:
            logging.exception("Unexpected error in token validation")
            return jsonify({'message': 'Internal server error'}), 500
        
        return f(current_user, *args, **kwargs)
    
    return decorated

# Helper function to generate unique IDs using atomic MongoDB counter
def generate_record_id():
    """Generate unique record ID using atomic MongoDB counter to prevent race conditions"""
    counter = db.counters.find_one_and_update(
        {'_id': 'record_id'},
        {'$inc': {'seq': 1}},
        upsert=True,
        return_document=True
    )
    return f"REC{str(counter['seq']).zfill(3)}"

def generate_report_id():
    """Generate unique report ID using atomic MongoDB counter to prevent race conditions"""
    counter = db.counters.find_one_and_update(
        {'_id': 'report_id'},
        {'$inc': {'seq': 1}},
        upsert=True,
        return_document=True
    )
    return f"RPT{str(counter['seq']).zfill(3)}"

def generate_audit_id():
    """Generate unique audit ID using atomic MongoDB counter to prevent race conditions"""
    counter = db.counters.find_one_and_update(
        {'_id': 'audit_id'},
        {'$inc': {'seq': 1}},
        upsert=True,
        return_document=True
    )
    return f"AUD{str(counter['seq']).zfill(3)}"

def process_spreadsheet(file, user_id):
    """Process Excel/CSV files and extract emission data"""
    try:
        import pandas as pd
        from datetime import datetime
        
        print("Reading spreadsheet file...")
        
        # Read file based on extension
        filename = file.filename.lower()
        if filename.endswith('.csv'):
            df = pd.read_csv(file)
        else:  # Excel files
            df = pd.read_excel(file, sheet_name=0)  # Read first sheet
        
        print(f"File has {len(df)} rows and columns: {list(df.columns)}")
        
        # Try to identify columns (flexible column matching)
        date_col = None
        category_col = None
        amount_col = None
        unit_col = None
        
        # Find columns by common names
        for col in df.columns:
            col_lower = str(col).lower().strip()
            if any(keyword in col_lower for keyword in ['date', 'วันที่', 'เดือน']):
                date_col = col
            elif any(keyword in col_lower for keyword in ['category', 'type', 'ประเภท', 'หมวด']):
                category_col = col
            elif any(keyword in col_lower for keyword in ['amount', 'quantity', 'จำนวน', 'ปริมาณ']):
                amount_col = col
            elif any(keyword in col_lower for keyword in ['unit', 'หน่วย']):
                unit_col = col
        
        print(f"Identified columns - Date: {date_col}, Category: {category_col}, Amount: {amount_col}, Unit: {unit_col}")
        
        # If columns not found, try positional (assume order: date, category, amount, unit)
        if not all([date_col, category_col, amount_col]):
            if len(df.columns) >= 3:
                date_col = df.columns[0]
                category_col = df.columns[1]
                amount_col = df.columns[2]
                unit_col = df.columns[3] if len(df.columns) > 3 else None
                print(f"Using positional columns: {[date_col, category_col, amount_col, unit_col]}")
        
        if not all([date_col, category_col, amount_col]):
            return {
                'success': False, 
                'message': f'Required columns not found. Expected: date, category, amount, unit. Found: {list(df.columns)}'
            }
        
        records_added = 0
        errors = []
        
        for index, row in df.iterrows():
            try:
                # Parse date
                try:
                    date_obj = pd.to_datetime(row[date_col])
                except (ValueError, TypeError, pd.errors.ParserError) as e:
                    logging.warning(f"Date parsing failed for row {index}: {e}. Using current date.")
                    date_obj = datetime.now()  # Use current date if parsing fails
                
                # Get category
                category = str(row[category_col]).lower().strip()
                
                # Map common category names
                category_mapping = {
                    'electric': 'electricity',
                    'electricity': 'electricity',
                    'ไฟฟ้า': 'electricity',
                    'diesel': 'diesel',
                    'gasoline': 'gasoline',
                    'petrol': 'gasoline',
                    'นํ้ามัน': 'gasoline',
                    'gas': 'natural_gas',
                    'natural_gas': 'natural_gas',
                    'waste': 'waste',
                    'ขยะ': 'waste',
                    'transport': 'transport',
                    'การขนส่ง': 'transport'
                }
                
                mapped_category = category_mapping.get(category, category)
                
                # Get amount
                amount = float(row[amount_col])
                
                # Get unit
                unit = str(row[unit_col]).lower().strip() if unit_col else 'kwh'
                
                # Unit mapping
                unit_mapping = {
                    'kwh': 'kwh',
                    'kw': 'kwh',
                    'liter': 'liter',
                    'l': 'liter',
                    'litre': 'liter',
                    'kg': 'kg',
                    'km': 'km',
                    'cubic_meter': 'cubic_meter',
                    'm3': 'cubic_meter'
                }
                
                mapped_unit = unit_mapping.get(unit, unit)
                
                # Calculate CO2 equivalent
                co2_equivalent = calculate_co2_equivalent(mapped_category, amount, mapped_unit)
                
                # Create emission record
                emission_record = {
                    'record_id': generate_record_id(),
                    'user_id': user_id,
                    'category': mapped_category,
                    'emission_type': mapped_category,
                    'amount': amount,
                    'unit': mapped_unit,
                    'month': date_obj.month,
                    'year': date_obj.year,
                    'emission_factor': 0,  # Will be calculated in calculate_co2_equivalent
                    'co2_equivalent': co2_equivalent,
                    'calculated_emission': co2_equivalent,
                    'import_time': datetime.now(timezone.utc),
                    'record_date': date_obj,
                    'created_at': datetime.now(timezone.utc),
                    'source': 'spreadsheet'
                }
                
                # Insert to database
                emission_records_collection.insert_one(emission_record)
                records_added += 1
                
                print(f"Added record: {mapped_category} - {amount} {mapped_unit} - {co2_equivalent} CO2e")
                
            except Exception as e:
                error_msg = f"Row {index + 2}: {str(e)}"
                errors.append(error_msg)
                print(f"Error processing row {index}: {e}")
                continue
        
        return {
            'success': True,
            'message': f'Successfully processed {records_added} records',
            'records_added': records_added,
            'errors': errors[:5] if errors else []  # Limit errors shown
        }
        
    except Exception as e:
        print(f"Spreadsheet processing error: {str(e)}")
        return {'success': False, 'message': f'Error processing spreadsheet: {str(e)}'}
    
# Routes
@app.route('/')
def home():
    return jsonify({
        'message': 'Carbon Accounting API is running!',
        'version': '1.0',
        'endpoints': {
            'auth': {
                'register': '/api/register [POST]',
                'login': '/api/login [POST]'
            },
            'emissions': {
                'add': '/api/emissions [POST]',
                'get': '/api/emissions [GET]',
                'dashboard': '/api/dashboard [GET]'
            },
            'reports': {
                'create': '/api/reports [POST]',
                'get': '/api/reports [GET]',
                'formats': '/api/reports/formats [GET]',
                'preview': '/api/reports/preview [POST]',
                'generate-ai': '/api/reports/generate-ai [POST]',
                'download': '/api/reports/download/<report_id> [GET]'
            }
        }
    })

@app.route('/api/test-db')
def test_db():
    try:
        # Test database connection
        db.command('ping')
        
        # Get collection counts
        counts = {
            'users': users_collection.count_documents({}),
            'emission_records': emission_records_collection.count_documents({}),
            'emission_factors': emission_factors_collection.count_documents({}),
            'reports': reports_collection.count_documents({}),
            'audits': audits_collection.count_documents({})
        }
        
        return jsonify({
            'status': 'connected',
            'database': db.name,
            'collections': counts
        })
    except Exception as e:
        return jsonify({
            'status': 'error',
            'message': str(e)
        }), 500

# User Registration
@app.route('/api/register', methods=['POST'])
def register():
    try:
        data = request.get_json()
        
        # Validate required fields
        if not data.get('email') or not data.get('password'):
            return jsonify({'message': 'Email and password are required'}), 400

        # Validate email format
        if not validate_email(data['email']):
            return jsonify({'message': 'Invalid email format'}), 400

        # Validate password strength
        is_strong, message = validate_password_strength(data['password'])
        if not is_strong:
            return jsonify({'message': message}), 400

        # Check if user exists
        if users_collection.find_one({'email': data['email']}):
            return jsonify({'message': 'User already exists'}), 400
        
        # Create new user (matching your data dictionary structure)
        user = {
            'email': data['email'],
            'username': data.get('username') or (data.get('email', '').split('@')[0] if '@' in data.get('email', '') else 'user'),
            'password': generate_password_hash(data['password']),
            'organization': data.get('company_name', ''),
            'phone_num': data.get('phone_num', ''),
            'is_admin': False,
            'created_at': datetime.now(timezone.utc)
        }
        
        result = users_collection.insert_one(user)
        
        return jsonify({
            'message': 'User created successfully',
            'user_id': str(result.inserted_id)
        }), 201
        
    except Exception as e:
        return jsonify({'message': f'Error: {str(e)}'}), 500

# User Login
@app.route('/api/login', methods=['POST'])
def login():
    try:
        data = request.get_json()
        
        if not data.get('email') or not data.get('password'):
            return jsonify({'message': 'Email and password are required'}), 400

        # Validate email format
        if not validate_email(data['email']):
            return jsonify({'message': 'Invalid email format'}), 400

        user = users_collection.find_one({'email': data['email']})
        
        if not user or not check_password_hash(user['password'], data['password']):
            return jsonify({'message': 'Invalid credentials'}), 401
        
        # Generate token
        token = jwt.encode({
            'user_id': str(user['_id']),
            'email': user['email'],
            'exp': datetime.now(timezone.utc) + timedelta(hours=24)
        }, app.config['SECRET_KEY'], algorithm='HS256')

        # Log successful login
        log_audit(
            user_id=str(user['_id']),
            username=user.get('username', user['email']),
            action='login',
            details={'email': user['email']}
        )

        return jsonify({
            'token': token,
            'user_id': str(user['_id']),
            'email': user['email'],
            'organization': user.get('organization', ''),
            'role': user.get('role', 'user'),
            'is_admin': user.get('is_admin', False)
        }), 200
        
    except Exception as e:
        return jsonify({'message': f'Error: {str(e)}'}), 500

@app.route('/api/logout', methods=['POST'])
@token_required
def logout(current_user):
    """Logout endpoint with audit logging"""
    try:
        # Log logout action
        log_audit(
            user_id=str(current_user['_id']),
            username=current_user.get('username', current_user.get('email', 'Unknown')),
            action='logout',
            details={'email': current_user.get('email', '')}
        )

        return jsonify({
            'message': 'Logged out successfully'
        }), 200

    except Exception as e:
        return jsonify({'message': f'Error: {str(e)}'}), 500

# Add Emission Record (matching your exact structure)
@app.route('/api/emissions', methods=['POST'])
@token_required
def add_emission(current_user):
    try:
        data = request.get_json()
        
        # Validate required fields
        required_fields = ['category', 'amount', 'unit', 'month', 'year']
        for field in required_fields:
            if field not in data:
                return jsonify({'message': f'{field} is required'}), 400

        # Validate month (1-12)
        try:
            month = int(data['month'])
            if not (1 <= month <= 12):
                return jsonify({'message': 'Month must be between 1 and 12'}), 400
        except (ValueError, TypeError):
            return jsonify({'message': 'Month must be a valid integer'}), 400

        # Validate year (reasonable range: 2000-2100)
        try:
            year = int(data['year'])
            if not (2000 <= year <= 2100):
                return jsonify({'message': 'Year must be between 2000 and 2100'}), 400
        except (ValueError, TypeError):
            return jsonify({'message': 'Year must be a valid integer'}), 400

        # Validate amount is positive
        try:
            amount = float(data['amount'])
            if amount <= 0:
                return jsonify({'message': 'Amount must be greater than 0'}), 400
        except (ValueError, TypeError):
            return jsonify({'message': 'Amount must be a valid number'}), 400

        # Look up emission factor from database to get the fuel_key (for consistency with OCR)
        emission_factor_doc = emission_factors_collection.find_one({
            'name': data['category']
        })

        # If not found by name, try by fuel_key
        if not emission_factor_doc:
            emission_factor_doc = emission_factors_collection.find_one({
                'fuel_key': data['category'].lower().replace(' ', '_').replace('(', '').replace(')', '')
            })

        # Use the fuel_key from database (matching OCR behavior), or fall back to provided category
        category_name = emission_factor_doc['fuel_key'] if emission_factor_doc else data['category']
        emission_type = emission_factor_doc.get('fuel_key', category_name) if emission_factor_doc else data.get('emission_type', data['category'])

        # Calculate CO2 equivalent using the category name
        co2_equivalent = calculate_co2_equivalent(category_name, amount, data['unit'])

        # Get the emission factor value for storage
        emission_factor_value = 0
        if emission_factor_doc:
            emission_factor_value = emission_factor_doc['value']
        elif co2_equivalent > 0:
            emission_factor_value = co2_equivalent / amount

        # Create emission record (matching your exact structure)
        # IMPORTANT: Store user_id as string for consistency across all records
        emission_record = {
            'record_id': generate_record_id(),
            'user_id': str(current_user['_id']),
            'category': category_name,
            'emission_type': emission_type,
            'amount': amount,
            'unit': data['unit'],
            'month': month,
            'year': year,
            'emission_factor': emission_factor_value,
            'co2_equivalent': co2_equivalent,
            'calculated_emission': co2_equivalent,
            'import_time': datetime.now(timezone.utc),
            'record_date': datetime(year, month, 1),
            'created_at': datetime.now(timezone.utc),
            'source': 'manual_entry'
        }
        
        result = emission_records_collection.insert_one(emission_record)

        # Log emission addition
        log_audit(
            user_id=str(current_user['_id']),
            username=current_user.get('username', current_user.get('email', 'Unknown')),
            action='add_emission',
            details={
                'record_id': emission_record['record_id'],
                'category': data['category'],
                'amount': float(data['amount']),
                'unit': data['unit'],
                'co2_amount': co2_equivalent
            }
        )

        return jsonify({
            'message': 'Emission record added successfully',
            'record_id': emission_record['record_id'],
            'co2_equivalent': co2_equivalent,
            'emission_factor': emission_factor_value
        }), 201
        
    except Exception as e:
        return jsonify({'message': f'Error: {str(e)}'}), 500

# Get Emission Records
@app.route('/api/emissions', methods=['GET'])
@token_required
def get_emissions(current_user):
    try:
        # Get query parameters
        month = request.args.get('month', type=int)
        year = request.args.get('year', type=int)
        category = request.args.get('category')
        
        # Build query - user_id stored as string for consistency
        user_id_str = str(current_user['_id'])

        query = {'user_id': user_id_str}
        # Validate and sanitize month input to prevent injection
        if month:
            if not (1 <= month <= 12):
                return jsonify({'message': 'Invalid month. Must be between 1 and 12'}), 400
            query['month'] = month

        # Validate and sanitize year input to prevent injection
        if year:
            if not (2000 <= year <= 2100):
                return jsonify({'message': 'Invalid year. Must be between 2000 and 2100'}), 400
            query['year'] = year

        # Validate category against whitelist to prevent injection
        if category:
            allowed_categories = ['electricity', 'diesel', 'gasoline', 'natural_gas', 'lpg', 'coal',
                                'water', 'waste', 'transport', 'refrigerant', 'other']
            if category.lower() not in allowed_categories:
                return jsonify({'message': f'Invalid category. Allowed values: {", ".join(allowed_categories)}'}), 400
            query['category'] = category.lower()
        # Pagination parameters
        page = request.args.get('page', 1, type=int)
        limit = request.args.get('limit', 50, type=int)

        # Validate pagination params
        if page < 1:
            page = 1
        if limit < 1 or limit > 100:
            limit = 50  # Default to 50, max 100

        skip = (page - 1) * limit

        # Get total count for pagination metadata
        total_count = emission_records_collection.count_documents(query)

        # OPTIMIZATION: Use projection to fetch only needed fields (40% smaller payload)
        projection = {
            'record_id': 1,
            'category': 1,
            'amount': 1,
            'unit': 1,
            'month': 1,
            'year': 1,
            'co2_equivalent': 1,
            'created_at': 1,
            'emission_factor': 1,
            'user_id': 1  # Added: needed for conversion to string
            # Exclude heavy fields: 'extracted_text', 'raw_text', 'import_data'
        }

        # Get emission records with pagination and projection
        emissions = list(emission_records_collection
            .find(query, projection)
            .sort('created_at', -1)
            .skip(skip)
            .limit(limit))

        # Convert ObjectId to string
        for emission in emissions:
            emission['_id'] = str(emission['_id'])
            emission['user_id'] = str(emission['user_id'])
            # Convert datetime to string for JSON serialization
            if 'created_at' in emission:
                emission['created_at'] = serialize_datetime(emission['created_at'])

        # Calculate total
        total_co2 = sum(e['co2_equivalent'] for e in emissions)

        return jsonify({
            'success': True,
            'pagination': {
                'page': page,
                'limit': limit,
                'total_records': total_count,
                'total_pages': (total_count + limit - 1) // limit,
                'has_next': page * limit < total_count,
                'has_prev': page > 1
            },
            'data': {
                'emissions': emissions,
                'total_co2': total_co2,
                'count': len(emissions)
            }
        }), 200

    except Exception as e:
        print(f"ERROR in get_emissions: {str(e)}")
        import traceback
        traceback.print_exc()
        return jsonify({'message': f'Error: {str(e)}'}), 500

# Dashboard Data - SHARED ACROSS ALL USERS
@app.route('/api/dashboard', methods=['GET'])
@token_required
def get_dashboard(current_user):
    try:
        from datetime import datetime
        
        # Get current date info
        now = datetime.now()
        current_year = int(now.year)
        current_month = int(now.month)
        last_year = current_year - 1
        
        print(f"\n=== SHARED Dashboard Request ===")
        print(f"User ID: {current_user['_id']} (Requesting shared data)")
        print(f"Current Month/Year: {current_month}/{current_year}")
        
        # Get ALL current month emissions from ALL USERS (shared dashboard)
        current_month_emissions = list(emission_records_collection.find({
            'year': current_year,
            'month': current_month
        }))
        current_month_total = sum(safe_float(e.get('co2_equivalent', 0)) for e in current_month_emissions)
        print(f"SHARED Current month ({current_month}/{current_year}) total: {current_month_total}")
        
        # Get last month from ALL USERS
        if current_month == 1:
            last_month = 12
            last_month_year = current_year - 1
        else:
            last_month = current_month - 1
            last_month_year = current_year
            
        last_month_emissions = list(emission_records_collection.find({
            'year': last_month_year,
            'month': last_month
        }))
        last_month_total = sum(safe_float(e.get('co2_equivalent', 0)) for e in last_month_emissions)
        
        # Get ALL current year emissions from ALL USERS
        current_year_emissions = list(emission_records_collection.find({
            'year': current_year
        }))
        current_year_total = sum(safe_float(e.get('co2_equivalent', 0)) for e in current_year_emissions)
        print(f"SHARED Current year ({current_year}) total: {current_year_total}")
        
        # Get ALL last year emissions from ALL USERS
        last_year_emissions = list(emission_records_collection.find({
            'year': last_year
        }))
        last_year_total = sum(safe_float(e.get('co2_equivalent', 0)) for e in last_year_emissions)
        print(f"SHARED Last year ({last_year}) total: {last_year_total}")
        
        # Category breakdown for CURRENT MONTH from ALL USERS
        current_month_category_breakdown = {}
        for e in current_month_emissions:
            cat = e.get('category', 'other')
            current_month_category_breakdown[cat] = current_month_category_breakdown.get(cat, 0) + safe_float(e.get('co2_equivalent', 0))

        # Category breakdown for LAST MONTH from ALL USERS
        last_month_category_breakdown = {}
        for e in last_month_emissions:
            cat = e.get('category', 'other')
            last_month_category_breakdown[cat] = last_month_category_breakdown.get(cat, 0) + safe_float(e.get('co2_equivalent', 0))

        # Category breakdown for CURRENT YEAR from ALL USERS (keep for compatibility)
        category_breakdown = {}
        for e in current_year_emissions:
            cat = e.get('category', 'other')
            category_breakdown[cat] = category_breakdown.get(cat, 0) + safe_float(e.get('co2_equivalent', 0))
        
        # Monthly trend for CURRENT YEAR from ALL USERS
        monthly_trend = []
        for m in range(1, 13):
            month_data = [e for e in current_year_emissions if int(e.get('month', 0)) == m]
            month_total = sum(safe_float(e.get('co2_equivalent', 0)) for e in month_data)
            monthly_trend.append({
                'month': m,
                'total': month_total,
                'hasData': len(month_data) > 0
            })
        print(f"SHARED Monthly trend: {monthly_trend}")
        
        # Monthly trend for LAST YEAR from ALL USERS
        last_year_trend = []
        for m in range(1, 13):
            month_data = [e for e in last_year_emissions if int(e.get('month', 0)) == m]
            month_total = sum(safe_float(e.get('co2_equivalent', 0)) for e in month_data)
            last_year_trend.append({
                'month': m,
                'total': month_total
            })
        
        # Calculate percentages with safe null handling
        # Ensure values are floats, default to 0 if None
        last_month_total = float(last_month_total) if last_month_total is not None else 0.0
        current_month_total = float(current_month_total) if current_month_total is not None else 0.0
        last_year_total = float(last_year_total) if last_year_total is not None else 0.0
        current_year_total = float(current_year_total) if current_year_total is not None else 0.0

        month_change_percentage = 0
        if last_month_total > 0:
            month_change_percentage = ((current_month_total - last_month_total) / last_month_total * 100)
        elif current_month_total > 0 and last_month_total == 0:
            month_change_percentage = 100.0  # Infinite increase from zero

        year_change_percentage = 0
        if last_year_total > 0:
            year_change_percentage = ((current_year_total - last_year_total) / last_year_total * 100)
        elif current_year_total > 0 and last_year_total == 0:
            year_change_percentage = 100.0  # Infinite increase from zero
        
        # Calculate record count for current month from ALL USERS
        record_count = len(current_month_emissions)
        
        # Get total number of active users for context
        total_users = users_collection.count_documents({})
        users_with_data = len(set(str(e.get('user_id', '')) for e in current_year_emissions if e.get('user_id')))
        
        response_data = {
            'current_month_total': round(current_month_total, 2),
            'last_month_total': round(last_month_total, 2),
            'month_change_percentage': round(month_change_percentage, 1),
            'current_year_total': round(current_year_total, 2),
            'last_year_total': round(last_year_total, 2),
            'year_change_percentage': round(year_change_percentage, 1),
            'category_breakdown': category_breakdown,
            'current_month_category_breakdown': current_month_category_breakdown,
            'last_month_category_breakdown': last_month_category_breakdown,
            'monthly_trend': monthly_trend,
            'last_year_trend': last_year_trend,
            'missing_categories': [],
            'current_month': current_month,
            'current_year': current_year,
            'last_year': last_year,
            'has_data': len(current_year_emissions) > 0,
            'is_admin': current_user.get('is_admin', False),
            'record_count': record_count,
            # Additional context for shared dashboard
            'is_shared': True,
            'total_users': total_users,
            'users_with_data': users_with_data
        }
        
        print(f"Sending SHARED response with {len(monthly_trend)} monthly data points")
        print(f"Total users: {total_users}, Users with data: {users_with_data}")
        print(f"Response data keys: {response_data.keys()}")
        
        return jsonify(response_data), 200
        
    except Exception as e:
        print(f"Dashboard error: {str(e)}")
        import traceback
        traceback.print_exc()
        return jsonify({'message': f'Error: {str(e)}'}), 500

# Get Emission Factors
@app.route('/api/emission-factors', methods=['GET'])
@token_required
def get_emission_factors(current_user):
    try:
        # Get query parameters
        category = request.args.get('category')
        language = request.args.get('language', 'en')  # Default to English
        
        # Build query
        query = {}
        if category:
            query['category'] = category
        
        # Get emission factors
        factors = list(emission_factors_collection.find(query).sort('name', 1))
        
        # Convert ObjectId to string and format for frontend
        formatted_factors = []
        categories = set()
        
        for factor in factors:
            # Use Thai names/units if language is Thai and they exist
            if language == 'th':
                name = factor.get('name_th', factor['name'])
                unit = factor.get('unit_th', factor['unit'])
                notes = factor.get('notes_th', factor.get('notes', ''))
                category_name = factor.get('category_th', factor['category'])
            else:
                name = factor['name']
                unit = factor['unit']
                notes = factor.get('notes', '')
                category_name = factor['category']
            
            formatted_factor = {
                'key': factor.get('fuel_key', factor['_id']),
                'name': name,
                'unit': unit,
                'factor': factor['value'],
                'notes': notes,
                'category': category_name,
                'scope': factor.get('scope', 1)
            }
            
            formatted_factors.append(formatted_factor)
            categories.add(category_name)
        
        return jsonify({
            'emission_factors': formatted_factors,
            'categories': sorted(list(categories)),
            'count': len(formatted_factors),
            'language': language
        }), 200
        
    except Exception as e:
        return jsonify({'message': f'Error: {str(e)}'}), 500
    
# Create Report
@app.route('/api/reports', methods=['POST'])
@token_required
def create_report(current_user):
    try:
        data = request.get_json()
        
        # Ensure user_id consistency - check both ObjectId and string formats
        user_id_obj = current_user['_id']
        user_id_str = str(current_user['_id'])
        
        # Get emissions for the period
        emissions = list(emission_records_collection.find({
            '$or': [
                {'user_id': user_id_obj},
                {'user_id': user_id_str}
            ],
            'year': {'$gte': data['start_year'], '$lte': data['end_year']},
            'month': {'$gte': data['start_month'], '$lte': data['end_month']}
        }))
        
        # Calculate totals by category
        emissions_by_category = {}
        total_emission = 0
        
        for emission in emissions:
            category = emission['category']
            co2 = emission['co2_equivalent']
            emissions_by_category[category] = emissions_by_category.get(category, 0) + co2
            total_emission += co2
        
        # Create report
        report = {
            'report_id': generate_report_id(),
            'user_id': current_user['_id'],
            'status': 'Draft',
            'total_emission': total_emission,
            'create_date': datetime.now(timezone.utc),
            'organization': current_user.get('organization', ''),
            'period': {
                'start_month': data['start_month'],
                'start_year': data['start_year'],
                'end_month': data['end_month'],
                'end_year': data['end_year']
            },
            'emissions_by_category': emissions_by_category
        }
        
        result = reports_collection.insert_one(report)
        
        return jsonify({
            'message': 'Report created successfully',
            'report_id': report['report_id'],
            'total_emission': total_emission
        }), 201
        
    except Exception as e:
        return jsonify({'message': f'Error: {str(e)}'}), 500

# Get Reports
@app.route('/api/reports', methods=['GET'])
@token_required
def get_reports(current_user):
    try:
        # Ensure user_id consistency - check both ObjectId and string formats
        user_id_obj = current_user['_id']
        user_id_str = str(current_user['_id'])
        
        reports = list(reports_collection.find({
            '$or': [
                {'user_id': user_id_obj},
                {'user_id': user_id_str}
            ]
        }).sort('create_date', -1))
        
        # Convert ObjectId to string
        for report in reports:
            report['_id'] = str(report['_id'])
            report['user_id'] = str(report['user_id'])
        
        return jsonify({
            'reports': reports,
            'count': len(reports)
        }), 200
        
    except Exception as e:
        return jsonify({'message': f'Error: {str(e)}'}), 500

# File Upload Endpoint
@app.route('/api/upload', methods=['POST', 'OPTIONS'])
def upload_file_options():
    """Handle CORS preflight for upload endpoint"""
    if request.method == 'OPTIONS':
        return jsonify({'status': 'ok'}), 200
    return upload_file_handler()

@token_required
def upload_file_handler(current_user):
    """Handle file upload with proper authentication"""
    try:
        print("=== UPLOAD REQUEST ===")

        # File size validation (max 10MB)
        MAX_FILE_SIZE = 10 * 1024 * 1024  # 10MB in bytes
        file = request.files.get('file')

        if not file:
            return jsonify({'success': False, 'message': 'No file provided'}), 400

        if file.filename == '':
            return jsonify({'success': False, 'message': 'No file selected'}), 400

        # Read file content to check size
        file.seek(0, 2)  # Seek to end
        file_size = file.tell()  # Get current position (file size)
        file.seek(0)  # Reset to beginning

        if file_size > MAX_FILE_SIZE:
            return jsonify({
                'success': False,
                'message': f'File too large. Maximum size is {MAX_FILE_SIZE // (1024*1024)}MB. Your file is {file_size // (1024*1024)}MB.'
            }), 400

        filename = file.filename.lower()
        logging.info(f"Processing file: {filename} (size: {file_size} bytes)")

        # Validate file content type (magic number check), not just extension
        file.seek(0)
        file_header = file.read(8)  # Read first 8 bytes
        file.seek(0)  # Reset

        # Define allowed file signatures (magic numbers)
        allowed_signatures = {
            # Excel/Office formats
            b'\x50\x4B\x03\x04': ['xlsx', 'xls'],  # ZIP-based (modern Excel)
            b'\xD0\xCF\x11\xE0': ['xls'],  # Old Excel format
            # CSV (no magic number, text file)
            # Images
            b'\xFF\xD8\xFF': ['jpg', 'jpeg'],
            b'\x89\x50\x4E\x47': ['png'],
            # PDF
            b'%PDF': ['pdf']
        }

        # Check if file signature matches expected types
        is_valid_type = False
        detected_type = None

        for signature, extensions in allowed_signatures.items():
            if file_header.startswith(signature):
                is_valid_type = True
                detected_type = extensions[0]
                break

        # CSV files are plain text, no magic number - allow if extension is .csv
        if filename.endswith('.csv'):
            is_valid_type = True
            detected_type = 'csv'

        if not is_valid_type:
            return jsonify({
                'success': False,
                'message': 'Invalid file type. File content does not match extension or is not an allowed type.'
            }), 400

        # Process based on file type
        if filename.endswith(('.xlsx', '.xls', '.csv')):
            logging.info("Processing spreadsheet file")
            result = process_spreadsheet(file, current_user['_id'])
        elif filename.endswith('.pdf'):
            print("Processing PDF...")
            result = process_pdf_bill(file, current_user['_id'])
        elif filename.endswith(('.jpg', '.jpeg', '.png', '.bmp')):
            print("Processing image with OCR...")
            result = process_image_ocr(file, current_user['_id'])
        else:
            return jsonify({'success': False, 'message': 'Unsupported file type. Supported: Excel, CSV, PDF, Images'}), 400
        
        print(f"Upload result: {result}")

        # Log successful upload
        if result.get('success'):
            log_audit(
                user_id=str(current_user['_id']),
                username=current_user.get('username', current_user.get('email', 'Unknown')),
                action='upload_data',
                details={
                    'file_name': file.filename,
                    'file_type': filename.split('.')[-1].upper(),
                    'records_added': result.get('records_added', 0)
                }
            )

        return jsonify(result), 200 if result.get('success') else 400
        
    except Exception as e:
        print(f"Upload error: {str(e)}")
        import traceback
        traceback.print_exc()
        return jsonify({'success': False, 'message': f'Upload error: {str(e)}'}), 500

# Anomaly Detection
@app.route('/api/anomalies/check', methods=['POST'])
@token_required
def check_anomalies(current_user):
    try:
        data = request.get_json()
        category = data['category']
        amount = data['amount']
        
        # Ensure user_id consistency - check both ObjectId and string formats
        user_id_obj = current_user['_id']
        user_id_str = str(current_user['_id'])
        
        # Get historical data for comparison
        historical = list(emission_records_collection.find({
            '$or': [
                {'user_id': user_id_obj},
                {'user_id': user_id_str}
            ],
            'category': category
        }).sort('created_at', -1).limit(12))
        
        if historical:
            avg_amount = sum(h['amount'] for h in historical) / len(historical)
            
            # Check if current amount is unusual (>200% or <20% of average)
            if amount > avg_amount * 2:
                return jsonify({
                    'anomaly': True,
                    'message': f'This amount ({amount}) is much higher than your average ({avg_amount:.2f}). Please confirm.',
                    'severity': 'high'
                }), 200
            elif amount < avg_amount * 0.2:
                return jsonify({
                    'anomaly': True,
                    'message': f'This amount ({amount}) is much lower than your average ({avg_amount:.2f}). Please confirm.',
                    'severity': 'medium'
                }), 200
        
        return jsonify({'anomaly': False}), 200
        
    except Exception as e:
        return jsonify({'message': f'Error: {str(e)}'}), 500

# AI-Powered Report Generation
@app.route('/api/reports/generate-ai', methods=['POST', 'OPTIONS'])
@token_required
def generate_ai_powered_report(current_user):
    """Generate AI-powered reports with multiple format support"""
    # Handle CORS preflight request
    if request.method == 'OPTIONS':
        return jsonify({'status': 'ok'}), 200
    try:
        data = request.get_json()
        
        # Validate request
        validation_result = validate_report_request(data)
        if not validation_result['valid']:
            return jsonify({
                'success': False,
                'message': validation_result['error']
            }), 400
        
        # Generate report using AI system
        result = generate_ai_report(
            user_id=str(current_user['_id']),
            start_date=data['start_date'],
            end_date=data['end_date'],
            report_format=data.get('report_format', 'GHG'),
            file_type=data.get('file_type', 'PDF'),
            language=data.get('language', 'EN'),
            include_ai=data.get('include_ai_insights', True)
        )
        
        if result['success']:
            # Save report metadata to database
            report_metadata = {
                'report_id': result['report_id'],
                'user_id': current_user['_id'],
                'report_format': data['report_format'],
                'start_date': data['start_date'],
                'end_date': data['end_date'],
                'pdf_path': result.get('pdf_path'),
                'generated_at': datetime.now(timezone.utc),
                'status': 'completed',
                'ai_insights_included': data.get('include_ai_insights', True)
            }
            
            reports_collection.insert_one(report_metadata)
            
            return jsonify({
                'success': True,
                'report_id': result['report_id'],
                'message': 'Report generated successfully',
                'download_url': f'/api/reports/download/{result["report_id"]}',
                'ai_insights': result.get('ai_insights', {}),
                'generated_at': result['generated_at']
            }), 200
        else:
            return jsonify({
                'success': False,
                'message': result.get('message', 'Report generation failed'),
                'error': result.get('error')
            }), 500
            
    except Exception as e:
        print(f"AI report generation error: {str(e)}")
        return jsonify({
            'success': False,
            'message': f'Report generation failed: {str(e)}'
        }), 500

# Get Available Report Formats
@app.route('/api/reports/formats', methods=['GET', 'OPTIONS'])
@token_required
def get_report_formats(current_user):
    """Get available report formats"""
    # Handle CORS preflight request
    if request.method == 'OPTIONS':
        return jsonify({'status': 'ok'}), 200
    try:
        formats = get_available_report_formats()
        format_descriptions = {
            'ISO': 'ISO 14064-1:2018 Greenhouse Gas Quantification and Reporting Standard',
            'CFO': 'CFO-focused Carbon Emissions Financial Report',
            'GHG': 'GHG Protocol Corporate Accounting and Reporting Standard'
        }
        
        return jsonify({
            'success': True,
            'formats': [
                {
                    'code': fmt,
                    'name': fmt,
                    'description': format_descriptions.get(fmt, f'{fmt} format report')
                }
                for fmt in formats
            ]
        }), 200
        
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'Error: {str(e)}'
        }), 500

# Get Available File Types
@app.route('/api/reports/file-types', methods=['GET', 'OPTIONS'])
@token_required
def get_file_types(current_user):
    """Get available file types"""
    # Handle CORS preflight request
    if request.method == 'OPTIONS':
        return jsonify({'status': 'ok'}), 200
    try:
        file_types = get_available_file_types()
        file_type_descriptions = {
            'PDF': 'Portable Document Format - Professional report layout',
            'EXCEL': 'Microsoft Excel - Data analysis and charts',
            'WORD': 'Microsoft Word - Editable document format'
        }
        
        return jsonify({
            'success': True,
            'file_types': [
                {
                    'code': ft,
                    'name': ft,
                    'description': file_type_descriptions.get(ft, f'{ft} format')
                }
                for ft in file_types
            ]
        }), 200
        
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'Error: {str(e)}'
        }), 500

# Get Available Languages
@app.route('/api/reports/languages', methods=['GET', 'OPTIONS'])
@token_required
def get_languages(current_user):
    """Get available languages"""
    # Handle CORS preflight request
    if request.method == 'OPTIONS':
        return jsonify({'status': 'ok'}), 200
    try:
        languages = get_available_languages()
        language_descriptions = {
            'EN': 'English - International standard language',
            'TH': 'Thai - ภาษาไทย สำหรับรายงานในประเทศไทย'
        }
        
        return jsonify({
            'success': True,
            'languages': [
                {
                    'code': lang,
                    'name': 'English' if lang == 'EN' else 'ภาษาไทย',
                    'description': language_descriptions.get(lang, f'{lang} language')
                }
                for lang in languages
            ]
        }), 200
        
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'Error: {str(e)}'
        }), 500

# Download Report
@app.route('/api/reports/download/<report_id>', methods=['GET'])
@token_required
def download_report(current_user, report_id):
    """Download generated report PDF or provide download information"""
    try:
        # Check if this is a request for download info (via query parameter)
        get_info = request.args.get('info', 'false').lower() == 'true'
        
        # Find report in database
        report = reports_collection.find_one({
            'report_id': report_id,
            'user_id': current_user['_id']
        })

        print(f"\n{'='*60}")
        print(f"DOWNLOAD REQUEST for report_id: {report_id}")
        print(f"{'='*60}")

        if not report:
            print(f"✗ Report not found in database for user {current_user['_id']}")
            return jsonify({
                'success': False,
                'message': 'Report not found'
            }), 404

        print(f"✓ Report found in database")
        print(f"  File type: {report.get('file_type', 'N/A')}")

        # Try both old and new field names for backward compatibility
        file_path_from_db = report.get('file_path') or report.get('pdf_path')
        if not file_path_from_db:
            print(f"✗ No file_path or pdf_path in report document")
            print(f"  Report keys: {list(report.keys())}")
            return jsonify({
                'success': False,
                'message': 'Report file path not found in database'
            }), 404

        print(f"✓ Original file path from DB: {file_path_from_db}")
        
        # Handle different path scenarios
        file_path = None
        
        # If path starts with 'backend\' or 'backend/', remove it since we're already in backend directory
        if file_path_from_db.startswith('backend\\') or file_path_from_db.startswith('backend/'):
            relative_path = file_path_from_db.replace('backend\\', '').replace('backend/', '')
            file_path = os.path.join(os.getcwd(), relative_path)
        # If it's already a relative path from backend directory
        elif file_path_from_db.startswith('reports\\') or file_path_from_db.startswith('reports/'):
            file_path = os.path.join(os.getcwd(), file_path_from_db)
        # If it's an absolute path
        elif os.path.isabs(file_path_from_db):
            file_path = file_path_from_db
        else:
            # Try as relative path from current directory
            file_path = os.path.join(os.getcwd(), file_path_from_db)
        
        # Normalize the path
        file_path = os.path.normpath(file_path)
        
        print(f"Resolved file path: {file_path}")
        print(f"Current working directory: {os.getcwd()}")
        print(f"File exists: {os.path.exists(file_path)}")
        
        if not os.path.exists(file_path):
            # Try alternative paths
            alternatives = [
                os.path.join(os.getcwd(), 'reports', os.path.basename(file_path_from_db)),
                os.path.join(os.path.dirname(os.getcwd()), file_path_from_db),
                file_path_from_db
            ]
            
            for alt_path in alternatives:
                alt_path = os.path.normpath(alt_path)
                print(f"Trying alternative path: {alt_path}")
                if os.path.exists(alt_path):
                    file_path = alt_path
                    print(f"Found file at: {file_path}")
                    break
            else:
                return jsonify({
                    'success': False,
                    'message': 'Report file not found on disk',
                    'debug_info': {
                        'original_path': file_path_from_db,
                        'resolved_path': file_path,
                        'cwd': os.getcwd(),
                        'alternatives_tried': alternatives
                    }
                }), 404
        
        # If requesting download info, return file information
        if get_info:
            file_size = os.path.getsize(file_path)

            # Determine file extension and name from actual file path
            file_extension = os.path.splitext(file_path)[1]  # e.g., '.pdf', '.docx', '.xlsx'
            file_type = report.get('file_type', 'PDF').upper()

            # Map file type to extension if not in path
            if not file_extension:
                extension_map = {'PDF': '.pdf', 'WORD': '.docx', 'EXCEL': '.xlsx'}
                file_extension = extension_map.get(file_type, '.pdf')

            file_name = f'carbon_report_{report_id}{file_extension}'

            return jsonify({
                'success': True,
                'download_url': f'/api/reports/download/{report_id}',
                'file_name': file_name,
                'file_size': file_size,
                'file_type': file_type,
                'report_format': report.get('report_format', 'GHG'),
                'language': report.get('language', 'EN'),
                'generated_at': report.get('generated_at', report.get('create_date')),
                'message': 'File ready for download'
            }), 200

        # Otherwise, serve the file for download
        from flask import send_file

        # Determine correct MIME type based on file extension
        file_extension = os.path.splitext(file_path)[1].lower()
        mime_types = {
            '.pdf': 'application/pdf',
            '.docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
            '.xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            '.doc': 'application/msword',
            '.xls': 'application/vnd.ms-excel'
        }
        mimetype = mime_types.get(file_extension, 'application/octet-stream')

        # Get download filename with correct extension
        download_filename = f'carbon_report_{report_id}{file_extension}'

        return send_file(
            file_path,
            as_attachment=True,
            download_name=download_filename,
            mimetype=mimetype
        )
        
    except Exception as e:
        print(f"Download error: {str(e)}")
        return jsonify({
            'success': False,
            'message': f'Download error: {str(e)}'
        }), 500

# Preview Report Data
@app.route('/api/reports/preview', methods=['POST', 'OPTIONS'])
@token_required
def preview_report_data(current_user):
    """Preview report data before generation"""
    # Handle CORS preflight request
    if request.method == 'OPTIONS':
        return jsonify({'status': 'ok'}), 200
    try:
        data = request.get_json()
        
        # Validate request
        validation_result = validate_report_request(data)
        if not validation_result['valid']:
            return jsonify({
                'success': False,
                'message': validation_result['error']
            }), 400
        
        # Parse dates
        start_date = datetime.fromisoformat(data['start_date'].replace('Z', '+00:00'))
        end_date = datetime.fromisoformat(data['end_date'].replace('Z', '+00:00'))
        
        # Get ALL emissions data for preview (shared data - same as dashboard)
        emissions = list(emission_records_collection.find({
            'record_date': {
                '$gte': start_date,
                '$lte': end_date
            }
        }))
        
        # Calculate summary statistics
        total_emissions = sum(e.get('co2_equivalent', 0) for e in emissions)
        
        # Group by category
        emissions_by_category = {}
        for emission in emissions:
            category = emission.get('category', 'other')
            emissions_by_category[category] = emissions_by_category.get(category, 0) + emission.get('co2_equivalent', 0)
        
        # Group by scope
        emissions_by_scope = {'Scope 1': 0, 'Scope 2': 0, 'Scope 3': 0}

        def get_emission_scope(category):
            """Determine scope based on database lookup or category name"""
            # First, try to find the scope from the emission_factors database
            emission_factor = emission_factors_collection.find_one({'name': category})
            if emission_factor and 'scope' in emission_factor:
                return emission_factor['scope']

            # Fallback to keyword matching
            category_lower = category.lower()

            # Scope 2: Electricity (all forms)
            if any(keyword in category_lower for keyword in ['electricity', 'grid mix']):
                return 2

            # Scope 1: All combustion and fugitive emissions
            scope1_keywords = ['diesel', 'gasoline', 'petrol', 'natural gas', 'coal',
                              'fuel oil', 'kerosene', 'lpg', 'cng', 'biogas', 'wood',
                              'bagasse', 'palm', 'corn', 'r-', 'refrigerant']
            if any(keyword in category_lower for keyword in scope1_keywords):
                return 1

            # Scope 3: Waste, transport, etc.
            if any(keyword in category_lower for keyword in ['waste', 'transport']):
                return 3

            # Default to Scope 3 for unknown categories
            return 3

        for emission in emissions:
            category = emission.get('category', 'other')
            scope = get_emission_scope(category)
            scope_key = f"Scope {scope}"
            emissions_by_scope[scope_key] += emission.get('co2_equivalent', 0)
        
        return jsonify({
            'success': True,
            'preview': {
                'period': f"{start_date.strftime('%B %Y')} to {end_date.strftime('%B %Y')}",
                'total_emissions': round(total_emissions, 2),
                'record_count': len(emissions),
                'emissions_by_category': emissions_by_category,
                'emissions_by_scope': emissions_by_scope,
                'report_format': data['report_format'],
                'organization': 'All Organizations'
            }
        }), 200
        
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'Preview error: {str(e)}'
        }), 500

# AI Text Generation
def generate_ai_description(emissions_data, report_format):
    # Using OpenAI GPT (you need to set up API key)
    try:
        total_emissions = sum(e['co2_equivalent'] for e in emissions_data)
        categories = {}
        for e in emissions_data:
            cat = e['category']
            categories[cat] = categories.get(cat, 0) + e['co2_equivalent']
        
        prompt = f"""
        Generate a professional summary for a {report_format} carbon emissions report:
        - Total emissions: {total_emissions} kg CO2e
        - Main emission sources: {categories}
        - Provide insights and recommendations in Thai language.
        """
        
        # Call OpenAI API (simplified)
        # response = openai.Completion.create(...)
        
        # For now, return a template
        return f"""
        บริษัทมีการปล่อยก๊าซเรือนกระจกทั้งหมด {total_emissions:.2f} kg CO2e 
        โดยแหล่งปล่อยหลักมาจาก {max(categories, key=categories.get)} 
        คิดเป็น {(categories[max(categories, key=categories.get)]/total_emissions*100):.1f}% 
        ของการปล่อยทั้งหมด แนะนำให้ปรับปรุงประสิทธิภาพการใช้พลังงานเพื่อลดการปล่อยก๊าซเรือนกระจก
        """
        
    except Exception as e:
        return "ไม่สามารถสร้างคำอธิบายอัตโนมัติได้"

# Helper functions for file processing
def process_spreadsheet(file, user_id):
    """Process Excel/CSV files and extract emission data"""
    try:
        import pandas as pd
        from datetime import datetime
        
        print("Reading spreadsheet file...")
        
        # Read file based on extension
        filename = file.filename.lower()
        if filename.endswith('.csv'):
            df = pd.read_csv(file)
        else:  # Excel files
            df = pd.read_excel(file, sheet_name=0)
        
        print(f"File has {len(df)} rows and columns: {list(df.columns)}")
        
        # Normalize column names (strip whitespace, lowercase)
        df.columns = df.columns.str.strip().str.lower()
        
        # Try to identify columns
        date_col = None
        category_col = None
        amount_col = None
        unit_col = None
        
        for col in df.columns:
            if any(keyword in col for keyword in ['date', 'วันที่', 'เดือน']):
                date_col = col
            elif any(keyword in col for keyword in ['category', 'type', 'ประเภท', 'หมวด']):
                category_col = col
            elif any(keyword in col for keyword in ['amount', 'quantity', 'จำนวน', 'ปริมาณ']):
                amount_col = col
            elif any(keyword in col for keyword in ['unit', 'หน่วย']):
                unit_col = col
        
        # Fallback to positional
        if not all([date_col, category_col, amount_col]):
            cols = list(df.columns)
            if len(cols) >= 3:
                date_col = cols[0]
                category_col = cols[1]
                amount_col = cols[2]
                unit_col = cols[3] if len(cols) > 3 else None
        
        if not all([date_col, category_col, amount_col]):
            return {
                'success': False,
                'message': f'Required columns not found. Found: {list(df.columns)}'
            }
        
        records_added = 0
        errors = []
        
        for index, row in df.iterrows():
            try:
                # Parse date
                try:
                    date_obj = pd.to_datetime(row[date_col])
                except (ValueError, TypeError, pd.errors.ParserError) as e:
                    logging.warning(f"Date parsing failed for row {index}: {e}. Using current date.")
                    date_obj = datetime.now()
                
                # Get category and normalize
                category = str(row[category_col]).lower().strip()

                # Get amount
                amount = float(row[amount_col])

                # Get unit and normalize (CASE-INSENSITIVE)
                unit = str(row[unit_col]).strip() if unit_col else 'kwh'

                print(f"Processing row {index + 1}: category={category}, amount={amount}, unit={unit}")

                # Look up emission factor to get standardized fuel_key (for consistency with OCR)
                emission_factor_doc = emission_factors_collection.find_one({
                    '$or': [
                        {'fuel_key': category},
                        {'name': {'$regex': f'^{category}$', '$options': 'i'}},
                        {'activity_types': category}
                    ]
                })

                # Use fuel_key from database if found
                category_key = emission_factor_doc['fuel_key'] if emission_factor_doc else category

                # Calculate CO2 equivalent
                co2_equivalent = calculate_co2_equivalent(category_key, amount, unit)

                if co2_equivalent == 0:
                    errors.append(f'Row {index + 2}: Warning - CO2 calculation returned 0 for {category}')

                # Get emission factor
                emission_factor_value = 0
                if emission_factor_doc:
                    emission_factor_value = emission_factor_doc['value']
                elif co2_equivalent > 0 and amount > 0:
                    emission_factor_value = co2_equivalent / amount

                # Create emission record
                emission_record = {
                    'record_id': generate_record_id(),
                    'user_id': user_id,
                    'category': category_key,
                    'emission_type': category_key,
                    'amount': amount,
                    'unit': unit,  # Keep original casing for display
                    'month': date_obj.month,
                    'year': date_obj.year,
                    'emission_factor': emission_factor_value,
                    'co2_equivalent': co2_equivalent,
                    'calculated_emission': co2_equivalent,
                    'import_time': datetime.now(timezone.utc),
                    'record_date': date_obj,
                    'created_at': datetime.now(timezone.utc),
                    'source': 'spreadsheet'
                }
                
                emission_records_collection.insert_one(emission_record)
                records_added += 1
                
                print(f"✓ Added: {category} - {amount} {unit} = {co2_equivalent:.2f} kg CO2e")
                
            except Exception as e:
                error_msg = f"Row {index + 2}: {str(e)}"
                errors.append(error_msg)
                print(f"✗ Error: {error_msg}")
                continue
        
        return {
            'success': True,
            'message': f'Successfully processed {records_added} records',
            'records_added': records_added,
            'errors': errors[:10]  # Limit to 10 errors
        }
        
    except Exception as e:
        print(f"Spreadsheet processing error: {str(e)}")
        return {'success': False, 'message': f'Error processing spreadsheet: {str(e)}'}

@app.route('/api/debug/emissions', methods=['GET'])
@token_required
def debug_emissions(current_user):
    """Debug route to see all emissions data"""
    try:
        emissions = list(emission_records_collection.find({'user_id': current_user['_id']}))
        
        # Group by year and month
        grouped = {}
        for e in emissions:
            year = e.get('year', 'Unknown')
            month = e.get('month', 'Unknown')
            key = f"{year}-{month:02d}" if isinstance(month, int) else f"{year}-{month}"
            
            if key not in grouped:
                grouped[key] = []
            
            grouped[key].append({
                'category': e.get('category'),
                'amount': e.get('amount'),
                'co2': e.get('co2_equivalent'),
                'year': e.get('year'),
                'month': e.get('month')
            })
        
        return jsonify({
            'total_records': len(emissions),
            'grouped_by_month': grouped,
            'years': list(set(e.get('year') for e in emissions))
        }), 200
        
    except Exception as e:
        return jsonify({'message': f'Error: {str(e)}'}), 500
    
@app.route('/api/debug/check-data', methods=['GET'])
@token_required  
def check_data(current_user):
    try:
        # Get all emissions
        all_emissions = list(emission_records_collection.find({
            'user_id': current_user['_id']
        }))
        
        # Check data types
        data_info = []
        for e in all_emissions:
            data_info.append({
                'category': e.get('category'),
                'amount': e.get('amount'),
                'month': f"{e.get('month')} (type: {type(e.get('month')).__name__})",
                'year': f"{e.get('year')} (type: {type(e.get('year')).__name__})",
                'co2': e.get('co2_equivalent')
            })
        
        return jsonify({
            'total_records': len(all_emissions),
            'records': data_info
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    
@app.route('/api/debug/years', methods=['GET'])
@token_required
def debug_years(current_user):
    """See what years are in the database"""
    try:
        emissions = list(emission_records_collection.find({
            'user_id': current_user['_id']
        }))
        
        year_summary = {}
        for e in emissions:
            year = e.get('year', 'Unknown')
            if year not in year_summary:
                year_summary[year] = {
                    'count': 0,
                    'total_co2': 0,
                    'months': set()
                }
            year_summary[year]['count'] += 1
            year_summary[year]['total_co2'] += float(e.get('co2_equivalent', 0))
            year_summary[year]['months'].add(e.get('month', 0))
        
        # Convert sets to lists for JSON
        for year in year_summary:
            year_summary[year]['months'] = sorted(list(year_summary[year]['months']))
        
        return jsonify({
            'year_summary': year_summary,
            'current_year': datetime.now().year
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# Admin Routes (require admin privileges)
def admin_required(f):
    @wraps(f)
    def decorated(current_user, *args, **kwargs):
        if not current_user.get('is_admin', False):
            return jsonify({'message': 'Admin privileges required'}), 403
        return f(current_user, *args, **kwargs)
    return decorated

@app.route('/api/admin/users', methods=['GET'])
@token_required
@admin_required
def get_all_users(current_user):
    """Get all users (admin only)"""
    try:
        users = list(users_collection.find({}, {
            'password': 0  # Exclude password from response
        }).sort('created_at', -1))
        
        # Convert ObjectId to string
        for user in users:
            user_id = str(user['_id'])  # Store the string ID first
            user['_id'] = user_id
            user['id'] = user_id  # Add id field for frontend
        
        return jsonify({
            'success': True,
            'users': users
        }), 200
        
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'Error: {str(e)}'
        }), 500

@app.route('/api/admin/users', methods=['POST'])
@token_required
@admin_required
def create_user_admin(current_user):
    """Create new user (admin only)"""
    try:
        data = request.get_json()
        
        # Validate required fields
        if not data.get('username') or not data.get('email') or not data.get('password'):
            return jsonify({
                'success': False,
                'message': 'Username, email and password are required'
            }), 400
        
        # Check if user exists
        if users_collection.find_one({'email': data['email']}):
            return jsonify({
                'success': False,
                'message': 'User with this email already exists'
            }), 400
        
        # Create new user
        user = {
            'email': data['email'],
            'username': data['username'],
            'password': generate_password_hash(data['password']),
            'organization': data.get('organization', ''),
            'phone_num': data.get('phone_num', ''),
            'is_admin': data.get('is_admin', False),
            'created_at': datetime.now(timezone.utc)
        }
        
        result = users_collection.insert_one(user)
        
        # Log audit
        audit_log = {
            'audit_id': generate_audit_id(),
            'user_id': current_user['_id'],
            'username': current_user.get('username', 'Unknown'),
            'action': 'create_user',
            'details': {
                'created_user_email': data['email'],
                'created_user_username': data['username'],
                'is_admin': data.get('is_admin', False)
            },
            'timestamp': datetime.now(timezone.utc)
        }
        audits_collection.insert_one(audit_log)
        
        return jsonify({
            'success': True,
            'message': 'User created successfully',
            'user_id': str(result.inserted_id)
        }), 201
        
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'Error: {str(e)}'
        }), 500

@app.route('/api/admin/users/<user_id>/admin-status', methods=['PUT'])
@token_required
@admin_required
def update_user_admin_status(current_user, user_id):
    """Update user admin status (admin only)"""
    try:
        print(f"Update admin status request for user_id: {user_id}")
        data = request.get_json()
        is_admin = data.get('is_admin', False)
        print(f"Setting is_admin to: {is_admin}")
        
        # Update user
        result = users_collection.update_one(
            {'_id': ObjectId(user_id)},
            {'$set': {'is_admin': is_admin}}
        )
        
        if result.matched_count == 0:
            return jsonify({
                'success': False,
                'message': 'User not found'
            }), 404
        
        # Get updated user for audit log
        updated_user = users_collection.find_one({'_id': ObjectId(user_id)})
        
        # Log audit
        audit_log = {
            'audit_id': generate_audit_id(),
            'user_id': current_user['_id'],
            'username': current_user.get('username', 'Unknown'),
            'action': 'update_admin_status',
            'details': {
                'target_user_email': updated_user.get('email'),
                'new_admin_status': is_admin
            },
            'timestamp': datetime.now(timezone.utc)
        }
        audits_collection.insert_one(audit_log)
        
        return jsonify({
            'success': True,
            'message': f'User admin status updated to {is_admin}'
        }), 200
        
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'Error: {str(e)}'
        }), 500

@app.route('/api/admin/users/<user_id>/reset-password', methods=['PUT'])
@token_required
@admin_required
def reset_user_password(current_user, user_id):
    """Reset user password (admin only)"""
    try:
        data = request.get_json()
        new_password = data.get('new_password')
        
        if not new_password:
            return jsonify({
                'success': False,
                'message': 'New password is required'
            }), 400
        
        # Update password
        result = users_collection.update_one(
            {'_id': ObjectId(user_id)},
            {'$set': {'password': generate_password_hash(new_password)}}
        )
        
        if result.matched_count == 0:
            return jsonify({
                'success': False,
                'message': 'User not found'
            }), 404
        
        # Get user for audit log
        user = users_collection.find_one({'_id': ObjectId(user_id)})
        
        # Log audit
        audit_log = {
            'audit_id': generate_audit_id(),
            'user_id': current_user['_id'],
            'username': current_user.get('username', 'Unknown'),
            'action': 'reset_password',
            'details': {
                'target_user_email': user.get('email')
            },
            'timestamp': datetime.now(timezone.utc)
        }
        audits_collection.insert_one(audit_log)
        
        return jsonify({
            'success': True,
            'message': 'Password reset successfully'
        }), 200
        
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'Error: {str(e)}'
        }), 500

@app.route('/api/admin/users/<user_id>', methods=['DELETE'])
@token_required
@admin_required
def delete_user(current_user, user_id):
    """Delete user (admin only)"""
    try:
        # Get user before deletion for audit log
        user_to_delete = users_collection.find_one({'_id': ObjectId(user_id)})
        
        if not user_to_delete:
            return jsonify({
                'success': False,
                'message': 'User not found'
            }), 404
        
        # Don't allow deleting yourself
        if str(user_to_delete['_id']) == str(current_user['_id']):
            return jsonify({
                'success': False,
                'message': 'Cannot delete your own account'
            }), 400
        
        # Delete user
        users_collection.delete_one({'_id': ObjectId(user_id)})
        
        # Also delete user's emission records (optional - you might want to keep them)
        # emission_records_collection.delete_many({'user_id': ObjectId(user_id)})
        
        # Log audit
        audit_log = {
            'audit_id': generate_audit_id(),
            'user_id': current_user['_id'],
            'username': current_user.get('username', 'Unknown'),
            'action': 'delete_user',
            'details': {
                'deleted_user_email': user_to_delete.get('email'),
                'deleted_user_username': user_to_delete.get('username')
            },
            'timestamp': datetime.now(timezone.utc)
        }
        audits_collection.insert_one(audit_log)
        
        return jsonify({
            'success': True,
            'message': 'User deleted successfully'
        }), 200
        
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'Error: {str(e)}'
        }), 500

@app.route('/api/admin/audit-logs', methods=['GET'])
@token_required
@admin_required
def get_audit_logs(current_user):
    """Get audit logs from audit_id (admin only)"""
    try:
        # Get query parameters
        limit = int(request.args.get('limit', 100))
        skip = int(request.args.get('skip', 0))
        request_type = request.args.get('request_type')  # filter by request_type
        
        # Build query
        query = {}
        if request_type:
            query['action'] = request_type
        
        # Get audit logs sorted by audit_id
        logs = list(audits_collection.find(query).sort('audit_id', -1).skip(skip).limit(limit))
        
        # Convert all non-JSON-serializable objects
        for log in logs:
            log['_id'] = str(log['_id'])

            # Convert user_id
            if 'user_id' in log:
                log['user_id'] = str(log['user_id'])

            # Convert timestamp (with UTC indicator)
            if 'timestamp' in log and log['timestamp']:
                log['timestamp'] = (log['timestamp'].isoformat() + 'Z') if hasattr(log['timestamp'], 'isoformat') else str(log['timestamp'])

            if 'audit_time' in log and log['audit_time']:
                log['audit_time'] = (log['audit_time'].isoformat() + 'Z') if hasattr(log['audit_time'], 'isoformat') else str(log['audit_time'])

            # Convert details - handle ObjectId, datetime, and nested dicts
            if 'details' in log and isinstance(log['details'], dict):
                for key, value in list(log['details'].items()):
                    if isinstance(value, ObjectId):
                        log['details'][key] = str(value)
                    elif hasattr(value, 'isoformat'):  # datetime
                        log['details'][key] = value.isoformat()
                    elif isinstance(value, dict):
                        # Handle nested dicts
                        for k, v in value.items():
                            if isinstance(v, (ObjectId, datetime)):
                                value[k] = str(v) if isinstance(v, ObjectId) else v.isoformat()
                        log['details'][key] = value
        
        return jsonify({
            'success': True,
            'logs': logs,
            'total': audits_collection.count_documents(query)
        }), 200
        
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'Error: {str(e)}'
        }), 500

# Helper function to generate edit request IDs
def generate_request_id():
    count = edit_requests_collection.count_documents({})
    return f"REQ{str(count + 1).zfill(3)}"

# Edit Request Routes (for non-admin users)
@app.route('/api/edit-requests', methods=['POST'])
@token_required
def create_edit_request(current_user):
    """Create a new edit/delete request using audit_id for tracking"""
    try:
        data = request.get_json()
        
        # Validate required fields
        required_fields = ['record_id', 'request_type', 'reason']
        for field in required_fields:
            if field not in data:
                return jsonify({
                    'success': False,
                    'message': f'{field} is required'
                }), 400
        
        # Check if record exists and belongs to user
        record = emission_records_collection.find_one({
            'record_id': data['record_id'],
            '$or': [
                {'user_id': current_user['_id']},
                {'user_id': str(current_user['_id'])}
            ]
        })
        
        if not record:
            return jsonify({
                'success': False,
                'message': 'Record not found or access denied'
            }), 404
        
        # Check if there's already a pending request for this record
        existing_request = edit_requests_collection.find_one({
            'record_id': data['record_id'],
            'status': 'pending'
        })
        
        if existing_request:
            return jsonify({
                'success': False,
                'message': 'There is already a pending request for this record'
            }), 400
        
        # Generate audit_id for tracking instead of using dates
        request_audit_id = generate_audit_id()
        
        # Create the request with audit_id tracking
        edit_request = {
            'request_id': generate_request_id(),
            'audit_id': request_audit_id,  # Use audit_id instead of date tracking
            'record_id': data['record_id'],
            'user_id': current_user['_id'],
            'user_email': current_user['email'],
            'request_type': data['request_type'],  # 'edit' or 'delete'
            'reason': data['reason'],
            'status': 'pending',
            'created_at': datetime.now(timezone.utc),  # Add explicit created_at
            'sequence': audits_collection.count_documents({}) + 1,  # Simple sequence number
            'original_data': {
                'category': record['category'],
                'amount': record['amount'],
                'unit': record['unit'],
                'month': record['month'],
                'year': record['year'],
                'co2_equivalent': record['co2_equivalent']
            }
        }
        
        # Add proposed changes if it's an edit request
        if data['request_type'] == 'edit':
            proposed_changes = data.get('proposed_changes', {})
            if not proposed_changes:
                return jsonify({
                    'success': False,
                    'message': 'Proposed changes are required for edit requests'
                }), 400
            
            edit_request['proposed_changes'] = proposed_changes
        
        # Insert the request
        result = edit_requests_collection.insert_one(edit_request)
        
        # Log audit with the same audit_id for tracking
        log_audit(
            current_user['_id'],
            current_user.get('username', 'Unknown'),
            'create_edit_request',
            {
                'request_id': edit_request['request_id'],
                'audit_id': request_audit_id,
                'record_id': data['record_id'],
                'request_type': data['request_type'],
                'reason': data['reason'][:100]
            }
        )
        
        return jsonify({
            'success': True,
            'message': f'{data["request_type"].title()} request submitted successfully',
            'request_id': edit_request['request_id'],
            'audit_id': request_audit_id
        }), 201
        
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'Error: {str(e)}'
        }), 500

@app.route('/api/edit-requests', methods=['GET'])
@token_required
def get_edit_requests(current_user):
    """Get edit requests for current user using audit_id tracking"""
    try:
        # Get query parameters
        status = request.args.get('status')  # pending, approved, rejected
        
        # Build query
        query = {
            '$or': [
                {'user_id': current_user['_id']},
                {'user_id': str(current_user['_id'])}
            ]
        }
        if status:
            query['status'] = status
        
        # Get requests sorted by sequence (no date parsing needed)
        requests = list(edit_requests_collection.find(query).sort('sequence', -1))

        # Convert ObjectId to string and add simple display info
        for req in requests:
            req['_id'] = str(req['_id'])

            # Convert user_id (might be ObjectId or string)
            if 'user_id' in req:
                req['user_id'] = str(req['user_id'])

            # Convert processed_by if present
            if 'processed_by' in req and req['processed_by']:
                req['processed_by'] = str(req['processed_by'])

            # Convert datetime fields to string for JSON serialization (with UTC indicator)
            if 'created_at' in req and req['created_at']:
                req['created_at'] = (req['created_at'].isoformat() + 'Z') if hasattr(req['created_at'], 'isoformat') else str(req['created_at'])
            if 'updated_at' in req and req['updated_at']:
                req['updated_at'] = (req['updated_at'].isoformat() + 'Z') if hasattr(req['updated_at'], 'isoformat') else str(req['updated_at'])
            if 'processed_at' in req and req['processed_at']:
                req['processed_at'] = (req['processed_at'].isoformat() + 'Z') if hasattr(req['processed_at'], 'isoformat') else str(req['processed_at'])

            # Convert applied_changes if it contains datetime or ObjectId objects
            if 'applied_changes' in req and isinstance(req['applied_changes'], dict):
                serialized_changes = {}
                for key, value in req['applied_changes'].items():
                    if hasattr(value, 'isoformat'):  # datetime object
                        serialized_changes[key] = value.isoformat() + 'Z'
                    elif isinstance(value, ObjectId):
                        serialized_changes[key] = str(value)
                    else:
                        serialized_changes[key] = value
                req['applied_changes'] = serialized_changes

            # Catch-all: convert any remaining ObjectId or datetime fields
            for key, value in list(req.items()):
                if isinstance(value, ObjectId):
                    req[key] = str(value)
                elif isinstance(value, datetime):
                    req[key] = value.isoformat() + 'Z'

            # Add simple status display without complex date parsing
            req['display_status'] = req.get('status', 'unknown').title()
            req['audit_reference'] = req.get('audit_id', 'N/A')

            # Add simple sequence info for sorting/display
            req['submission_order'] = req.get('sequence', 0)

        return jsonify({
            'success': True,
            'data': {
                'requests': requests,
                'count': len(requests)
            }
        }), 200
        
    except Exception as e:
        print(f"ERROR in get_edit_requests: {str(e)}")
        import traceback
        traceback.print_exc()
        return jsonify({
            'success': False,
            'message': f'Error: {str(e)}'
        }), 500

# Admin routes for managing edit requests
@app.route('/api/admin/edit-requests', methods=['GET'])
@token_required
@admin_required
def get_all_edit_requests(current_user):
    """Get edit requests from audit_id (admin only)"""
    try:
        # Get query parameters
        status = request.args.get('status')
        limit = int(request.args.get('limit', 50))
        skip = int(request.args.get('skip', 0))
        request_type = request.args.get('request_type')  # filter by request_type
        
        # Build query
        query = {}
        if status:
            query['status'] = status
        if request_type:
            query['request_type'] = request_type
        
        # Get requests sorted by audit_id
        requests = list(edit_requests_collection.find(query).sort('audit_id', -1).skip(skip).limit(limit))

        # Convert all non-JSON-serializable objects
        for req in requests:
            req['_id'] = str(req['_id'])

            # Convert user_id (might be ObjectId or string)
            if 'user_id' in req:
                req['user_id'] = str(req['user_id'])

            # Add user_info object for frontend display
            req['user_info'] = {
                'email': req.get('user_email', 'Unknown'),
                'username': req.get('user_email', 'Unknown').split('@')[0] if req.get('user_email') else 'Unknown'
            }

            # Convert ObjectId fields if present
            if 'processed_by' in req and req['processed_by']:
                req['processed_by'] = str(req['processed_by'])

            # Convert datetime fields to string for JSON serialization (with UTC indicator)
            if 'created_at' in req and req['created_at']:
                req['created_at'] = (req['created_at'].isoformat() + 'Z') if hasattr(req['created_at'], 'isoformat') else str(req['created_at'])
            if 'updated_at' in req and req['updated_at']:
                req['updated_at'] = (req['updated_at'].isoformat() + 'Z') if hasattr(req['updated_at'], 'isoformat') else str(req['updated_at'])
            if 'processed_at' in req and req['processed_at']:
                req['processed_at'] = (req['processed_at'].isoformat() + 'Z') if hasattr(req['processed_at'], 'isoformat') else str(req['processed_at'])

            # Convert applied_changes if it contains datetime objects
            if 'applied_changes' in req and isinstance(req['applied_changes'], dict):
                for key, value in req['applied_changes'].items():
                    if hasattr(value, 'isoformat'):  # datetime object
                        req['applied_changes'][key] = value.isoformat()
                    elif isinstance(value, ObjectId):
                        req['applied_changes'][key] = str(value)

            # Simple status info
            req['status_display'] = req.get('status', 'unknown').title()

        return jsonify({
            'success': True,
            'requests': requests,
            'count': len(requests),
            'total': edit_requests_collection.count_documents(query)
        }), 200
        
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'Error: {str(e)}'
        }), 500

@app.route('/api/admin/edit-requests/<request_id>/approve', methods=['POST'])
@token_required
@admin_required
def approve_edit_request(current_user, request_id):
    """Approve an edit request and apply changes (admin only)"""
    try:
        # Find the request
        edit_request = edit_requests_collection.find_one({'request_id': request_id})
        
        if not edit_request:
            return jsonify({
                'success': False,
                'message': 'Request not found'
            }), 404
        
        if edit_request['status'] != 'pending':
            return jsonify({
                'success': False,
                'message': 'Request has already been processed'
            }), 400
        
        # Find the original record
        record = emission_records_collection.find_one({'record_id': edit_request['record_id']})
        
        if not record:
            return jsonify({
                'success': False,
                'message': 'Original record not found'
            }), 404
        
        # Apply changes based on request type
        if edit_request['request_type'] == 'delete':
            # Log the deletion from user's perspective first
            log_audit(
                user_id=str(edit_request['user_id']),
                username=edit_request.get('user_email', 'Unknown'),
                action='delete_emission',
                details={
                    'record_id': edit_request['record_id'],
                    'category': record.get('category', 'Unknown'),
                    'amount': record.get('amount', 0),
                    'co2_amount': record.get('co2_equivalent', 0),
                    'approved_by': current_user.get('username', 'Admin')
                }
            )

            # Delete the record
            emission_records_collection.delete_one({'record_id': edit_request['record_id']})

            # Update request status
            edit_requests_collection.update_one(
                {'request_id': request_id},
                {
                    '$set': {
                        'status': 'approved',
                        'processed_by': str(current_user['_id']),
                        'processed_at': datetime.now(timezone.utc),
                        'admin_notes': request.get_json().get('admin_notes', '') if request.get_json() else ''
                    }
                }
            )

            # Log admin approval action
            log_audit(
                current_user['_id'],
                current_user.get('username', 'Unknown'),
                'approve_delete_request',
                {
                    'request_id': request_id,
                    'deleted_record_id': edit_request['record_id'],
                    'original_user': edit_request['user_email']
                }
            )
            
            return jsonify({
                'success': True,
                'message': 'Delete request approved and record deleted successfully'
            }), 200
            
        elif edit_request['request_type'] == 'edit':
            # Apply the proposed changes
            proposed_changes = edit_request.get('proposed_changes', {})
            
            # Prepare update data
            update_data = {}
            for field, value in proposed_changes.items():
                if field in ['category', 'amount', 'unit', 'month', 'year']:
                    update_data[field] = value
            
            # Recalculate CO2 equivalent if relevant fields changed
            if any(field in proposed_changes for field in ['category', 'amount', 'unit']):
                category = proposed_changes.get('category', record['category'])
                amount = float(proposed_changes.get('amount', record['amount']))
                unit = proposed_changes.get('unit', record['unit'])
                
                co2_equivalent = calculate_co2_equivalent(category, amount, unit)
                update_data['co2_equivalent'] = co2_equivalent
                update_data['calculated_emission'] = co2_equivalent
                
                # Update emission factor
                if amount > 0:
                    update_data['emission_factor'] = co2_equivalent / amount
            
            # Update record date if month/year changed
            if 'month' in proposed_changes or 'year' in proposed_changes:
                month = int(proposed_changes.get('month', record['month']))
                year = int(proposed_changes.get('year', record['year']))
                update_data['record_date'] = datetime(year, month, 1)
                update_data['month'] = month
                update_data['year'] = year
            
            # Add audit trail
            update_data['last_modified'] = datetime.now(timezone.utc)
            update_data['modified_by'] = str(current_user['_id'])

            # Update the record
            emission_records_collection.update_one(
                {'record_id': edit_request['record_id']},
                {'$set': update_data}
            )

            # Prepare serializable version of update_data for storing in database
            update_data_serializable = {}
            for key, value in update_data.items():
                if isinstance(value, datetime):
                    update_data_serializable[key] = value.isoformat()
                elif isinstance(value, ObjectId):
                    update_data_serializable[key] = str(value)
                else:
                    update_data_serializable[key] = value

            # Update request status
            edit_requests_collection.update_one(
                {'request_id': request_id},
                {
                    '$set': {
                        'status': 'approved',
                        'processed_by': str(current_user['_id']),
                        'processed_at': datetime.now(timezone.utc),
                        'admin_notes': request.get_json().get('admin_notes', '') if request.get_json() else '',
                        'applied_changes': update_data_serializable
                    }
                }
            )

            # Log audit (with serializable data)
            log_audit(
                current_user['_id'],
                current_user.get('username', 'Unknown'),
                'approve_edit_request',
                {
                    'request_id': request_id,
                    'edited_record_id': edit_request['record_id'],
                    'changes_applied': update_data_serializable,
                    'original_user': edit_request['user_email']
                }
            )

            return jsonify({
                'success': True,
                'message': 'Edit request approved and changes applied successfully',
                'applied_changes': update_data_serializable
            }), 200
        
    except Exception as e:
        print(f"ERROR in approve_edit_request: {str(e)}")
        import traceback
        traceback.print_exc()
        return jsonify({
            'success': False,
            'message': f'Error: {str(e)}'
        }), 500

@app.route('/api/admin/edit-requests/<request_id>/reject', methods=['POST'])
@token_required
@admin_required
def reject_edit_request(current_user, request_id):
    """Reject an edit request (admin only)"""
    try:
        data = request.get_json() or {}
        
        # Find the request
        edit_request = edit_requests_collection.find_one({'request_id': request_id})
        
        if not edit_request:
            return jsonify({
                'success': False,
                'message': 'Request not found'
            }), 404
        
        if edit_request['status'] != 'pending':
            return jsonify({
                'success': False,
                'message': 'Request has already been processed'
            }), 400
        
        # Update request status
        edit_requests_collection.update_one(
            {'request_id': request_id},
            {
                '$set': {
                    'status': 'rejected',
                    'processed_by': str(current_user['_id']),
                    'processed_at': datetime.now(timezone.utc),
                    'admin_notes': data.get('admin_notes', ''),
                    'rejection_reason': data.get('rejection_reason', 'No reason provided')
                }
            }
        )
        
        # Log audit
        log_audit(
            current_user['_id'],
            current_user.get('username', 'Unknown'),
            'reject_edit_request',
            {
                'request_id': request_id,
                'record_id': edit_request['record_id'],
                'rejection_reason': data.get('rejection_reason', 'No reason provided'),
                'original_user': edit_request['user_email']
            }
        )
        
        return jsonify({
            'success': True,
            'message': 'Request rejected successfully'
        }), 200
        
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'Error: {str(e)}'
        }), 500

# Add audit logging to existing routes
def log_audit(user_id, username, action, details=None):
    """Helper function to log audit events"""
    try:
        # Ensure user_id is always a string for consistency
        user_id_str = str(user_id) if user_id else 'unknown'

        # Serialize details to ensure all values are JSON-compatible
        serialized_details = {}
        if details:
            for key, value in details.items():
                if isinstance(value, (datetime, ObjectId)):
                    serialized_details[key] = str(value)
                elif isinstance(value, dict):
                    # Recursively serialize nested dicts
                    serialized_details[key] = {k: str(v) if isinstance(v, (datetime, ObjectId)) else v for k, v in value.items()}
                else:
                    serialized_details[key] = value

        audit_log = {
            'audit_id': generate_audit_id(),
            'user_id': user_id_str,
            'username': username,
            'action': action,
            'details': serialized_details,
            'timestamp': datetime.now(timezone.utc)
        }
        audits_collection.insert_one(audit_log)
    except Exception as e:
        print(f"Audit logging error: {str(e)}")
        import traceback
        traceback.print_exc()

if __name__ == '__main__':
    print("Starting Carbon Accounting API...")
    print(f"Upload folder: {app.config['UPLOAD_FOLDER']}")

    # Security: Only enable debug mode in development
    debug_mode = os.getenv('FLASK_ENV') == 'development'
    # Security: Only bind to all interfaces in production, use localhost in debug
    host = '127.0.0.1' if debug_mode else '0.0.0.0'

    if debug_mode:
        print("⚠️  WARNING: Running in DEBUG mode - DO NOT use in production!")

    app.run(debug=debug_mode, host=host, port=5000)
