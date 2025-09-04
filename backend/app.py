from flask import Flask, request, jsonify
from flask_cors import CORS
from flask_pymongo import PyMongo
from bson import ObjectId
from datetime import datetime, timedelta
import os
from werkzeug.security import generate_password_hash, check_password_hash
import jwt
from functools import wraps
from config import Config
from models import db, users_collection, emission_records_collection, emission_factors_collection, reports_collection, audits_collection, calculate_co2_equivalent
import pandas as pd
from datetime import datetime, timedelta
# import openai  # For AI text generation
# from reportlab.lib.pagesizes import A4
# from reportlab.pdfgen import canvas
import cv2
import numpy as np
import pytesseract
from PIL import Image
from typing import Dict, Optional, List, Tuple
import logging
import re

if os.name == 'nt':  # Windows
    pytesseract.pytesseract.tesseract_cmd = r'C:\Program Files\Tesseract-OCR\tesseract.exe'

try:
    print("Tesseract version:", pytesseract.get_tesseract_version())
    print("Available languages:", pytesseract.get_languages())
    print("Installation successful!")
except Exception as e:
    print("Error:", e)

app = Flask(__name__)
app.config.from_object(Config)

# Initialize PyMongo
mongo = PyMongo(app)

# Enable CORS
CORS(app, origins=["*"], allow_headers=["Content-Type", "Authorization"])

# Create upload folder if it doesn't exist
os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)

class ThaiElectricityBillOCR:
    """Advanced OCR processor for Thai electricity bills with multiple format support"""
    
    def __init__(self):
        # Configure Tesseract for optimal Thai + English recognition
        self.tesseract_config = '--oem 3 --psm 6 -l tha+eng'
        
        # Bill format patterns - multiple formats supported
        self.bill_patterns = {
    # Format 1: Metropolitan Electricity Authority (MEA)
    'mea': {
        'usage_keywords': ['จำนวนหน่วย', 'จํานวนหน่วย'],
        'amount_keywords': ['รวมเงินที่ต้องชำระทั้งสิ้น', 'รวมเงิน'],
        'period_keywords': ['ประจำเดือน', 'ประจ.เดือน'],
        'meter_current': ['เลขอ่านครั้งนี้', 'ครั้งนี้'],
        'meter_previous': ['เลขอ่านครั้งที่แล้ว', 'ครั้งที่แล้ว']
    },
    # Format 2: Provincial Electricity Authority (PEA)
    'pea': {
        'usage_keywords': ['จำนวนที่ใช้', 'จํานวนที่ใช้', 'หน่วยที่ใช้'],
        'amount_keywords': ['รวมเงินที่ต้องชำระ', 'Amount', 'รวมเงิน'],
        'period_keywords': ['ประจำเดือน', 'ประจ.เดือน', 'Bill Period'],
        'meter_current': ['เลขอ่านปัจจุบัน', 'Current Reading'],
        'meter_previous': ['เลขอ่านครั้งก่อน', 'Previous Reading']
    }
}

        # Enhanced text corrections for common OCR errors
        self.text_corrections = {
        # Thai text corrections
        'จํานวน': 'จำนวน',
        'ประจา': 'ประจำ',
        'เดนอน': 'เดือน',
        'เตือน': 'เดือน',
        'หนวย': 'หน่วย',
        'รวม': 'รวม',
        'เงนิ': 'เงิน',
        'ชาระ': 'ชำระ',
        'ทั้งสิน': 'ทั้งสิ้น',
        
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
        'ู': 'ู',
    }

    def preprocess_image(self, image_bytes: bytes) -> np.ndarray:
        """Advanced image preprocessing for better OCR accuracy"""
        try:
            # Convert bytes to numpy array
            nparr = np.frombuffer(image_bytes, np.uint8)
            image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
            
            if image is None:
                raise ValueError("Could not decode image")
            
            # Resize if image is too small or too large
            height, width = image.shape[:2]
            if width < 800:
                scale = 800 / width
                new_width = int(width * scale)
                new_height = int(height * scale)
                image = cv2.resize(image, (new_width, new_height), interpolation=cv2.INTER_CUBIC)
            elif width > 2000:
                scale = 2000 / width
                new_width = int(width * scale)
                new_height = int(height * scale)
                image = cv2.resize(image, (new_width, new_height), interpolation=cv2.INTER_AREA)
            
            # Convert to grayscale
            gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
            
            # Advanced noise reduction
            denoised = cv2.fastNlMeansDenoising(gray)
            
            # Enhance contrast with adaptive CLAHE
            clahe = cv2.createCLAHE(clipLimit=3.0, tileGridSize=(8, 8))
            enhanced = clahe.apply(denoised)
            
            # Adaptive thresholding for better text extraction
            binary = cv2.adaptiveThreshold(
                enhanced, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, 
                cv2.THRESH_BINARY, 11, 2
            )
            
            # Morphological operations to clean up text
            kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (1, 1))
            cleaned = cv2.morphologyEx(binary, cv2.MORPH_CLOSE, kernel)
            
            # Final smoothing
            result = cv2.medianBlur(cleaned, 3)
            
            return result
            
        except Exception as e:
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
        """Extract electricity usage with multiple keyword support"""
        patterns = self.bill_patterns[bill_format]['usage_keywords']
        
        for keyword in patterns:
            # Try different number extraction patterns after the keyword
            usage_patterns = [
                rf'{re.escape(keyword)}\s*(\d+(?:\.\d+)?)',  # keyword followed by number
                rf'{re.escape(keyword)}[^\d]*(\d+(?:\.\d+)?)',  # keyword with some text then number
                rf'{re.escape(keyword)}.*?(\d+(?:\.\d+)?)\s*(?:kWh|หน่วย|kwh)',  # keyword...number unit
            ]
            
            for pattern in usage_patterns:
                match = re.search(pattern, text, re.IGNORECASE | re.DOTALL)
                if match:
                    try:
                        return float(match.group(1))
                    except ValueError:
                        continue
        
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
            return {
                'success': False,
                'error': str(e),
                'message': f"OCR processing failed: {str(e)}"
            }

# Flask integration function

def process_image_ocr(file, user_id):
    """Use simplified OCR for now"""
    return process_image_ocr_simple(file, user_id)

# def process_image_ocr_simple(file, user_id):
#     """Simplified OCR processing for testing"""
#     try:
#         print("Starting simple OCR processing...")
        
#         # Save file temporarily for processing
#         import tempfile
#         import os
        
#         with tempfile.NamedTemporaryFile(delete=False, suffix='.png') as tmp_file:
#             file.save(tmp_file.name)
            
#             # Basic OCR extraction
#             from PIL import Image
#             import pytesseract
            
#             image = Image.open(tmp_file.name)
#             text = pytesseract.image_to_string(image, lang='tha+eng')
            
#             print(f"Extracted text: {text[:200]}...")
            
#             # Simple number extraction
#             import re
#             numbers = re.findall(r'\d+(?:\.\d+)?', text)
#             print(f"Found numbers: {numbers}")
            
#             # Clean up
#             os.unlink(tmp_file.name)
            
#             if numbers:
#                 # Take the largest reasonable number as usage
#                 reasonable_numbers = [float(n) for n in numbers if 10 <= float(n) <= 10000]
                
#                 if reasonable_numbers:
#                     usage = max(reasonable_numbers)
                    
#                     # Create emission record
#                     from datetime import datetime
#                     now = datetime.now()
                    
#                     co2_equivalent = usage * 0.233  # Thailand grid factor
                    
#                     emission_record = {
#                         'record_id': generate_record_id(),
#                         'user_id': user_id,
#                         'category': 'electricity',
#                         'emission_type': 'electricity',
#                         'amount': usage,
#                         'unit': 'kWh',
#                         'month': now.month,
#                         'year': now.year,
#                         'emission_factor': 0.233,
#                         'co2_equivalent': co2_equivalent,
#                         'calculated_emission': co2_equivalent,
#                         'import_time': datetime.utcnow(),
#                         'record_date': datetime(now.year, now.month, 1),
#                         'created_at': datetime.utcnow(),
#                         'source': 'ocr_simple',
#                         'extracted_text': text[:500]  # Store first 500 chars
#                     }
                    
#                     emission_records_collection.insert_one(emission_record)
                    
#                     return {
#                         'success': True,
#                         'message': f'Successfully extracted {usage} kWh from image',
#                         'usage_kwh': usage,
#                         'co2_equivalent': co2_equivalent,
#                         'record_id': emission_record['record_id']
#                     }
            
#             return {
#                 'success': False,
#                 'message': 'Could not extract electricity usage from image',
#                 'extracted_text': text[:200],
#                 'numbers_found': numbers
#             }
            
#     except Exception as e:
#         print(f"Simple OCR error: {str(e)}")
#         return {
#             'success': False,
#             'message': f'OCR processing failed: {str(e)}'
#         }

# JWT decorator for protected routes
def token_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
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
        except:
            return jsonify({'message': 'Token is invalid'}), 401
        
        return f(current_user, *args, **kwargs)
    
    return decorated

# Helper function to generate unique IDs
def generate_record_id():
    count = emission_records_collection.count_documents({})
    return f"REC{str(count + 1).zfill(3)}"

def generate_report_id():
    count = reports_collection.count_documents({})
    return f"RPT{str(count + 1).zfill(3)}"

def generate_audit_id():
    count = audits_collection.count_documents({})
    return f"AUD{str(count + 1).zfill(3)}"

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
                except:
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
                    'import_time': datetime.utcnow(),
                    'record_date': date_obj,
                    'created_at': datetime.utcnow(),
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
                'get': '/api/reports [GET]'
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
        
        # Check if user exists
        if users_collection.find_one({'email': data['email']}):
            return jsonify({'message': 'User already exists'}), 400
        
        # Create new user (matching your data dictionary structure)
        user = {
            'email': data['email'],
            'username': data.get('username', data['email'].split('@')[0]),
            'password': generate_password_hash(data['password']),
            'organization': data.get('company_name', ''),
            'phone_num': data.get('phone_num', ''),
            'is_admin': False,
            'created_at': datetime.utcnow()
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
        
        user = users_collection.find_one({'email': data['email']})
        
        if not user or not check_password_hash(user['password'], data['password']):
            return jsonify({'message': 'Invalid credentials'}), 401
        
        # Generate token
        token = jwt.encode({
            'user_id': str(user['_id']),
            'email': user['email'],
            'exp': datetime.utcnow() + timedelta(hours=24)
        }, app.config['SECRET_KEY'], algorithm='HS256')
        
        return jsonify({
            'token': token,
            'user_id': str(user['_id']),
            'email': user['email'],
            'organization': user.get('organization', '')
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
        
        # Get emission factor
        emission_factor_doc = emission_factors_collection.find_one({
            'activity_type': data['category'],
            'unit': data['unit']
        })
        
        emission_factor_value = emission_factor_doc['value'] if emission_factor_doc else 0
        
        # Calculate CO2 equivalent
        co2_equivalent = float(data['amount']) * emission_factor_value
        
        # Create emission record (matching your exact structure)
        emission_record = {
            'record_id': generate_record_id(),
            'user_id': current_user['_id'],
            'category': data['category'],
            'emission_type': data.get('emission_type', data['category']),
            'amount': float(data['amount']),
            'unit': data['unit'],
            'month': int(data['month']),
            'year': int(data['year']),
            'emission_factor': emission_factor_value,
            'co2_equivalent': co2_equivalent,
            'calculated_emission': co2_equivalent,
            'import_time': datetime.utcnow(),
            'record_date': datetime(int(data['year']), int(data['month']), 1),
            'created_at': datetime.utcnow()
        }
        
        result = emission_records_collection.insert_one(emission_record)
        
        return jsonify({
            'message': 'Emission record added successfully',
            'record_id': emission_record['record_id'],
            'co2_equivalent': co2_equivalent
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
        
        # Build query
        query = {'user_id': current_user['_id']}
        if month:
            query['month'] = month
        if year:
            query['year'] = year
        if category:
            query['category'] = category
        
        # Get emission records
        emissions = list(emission_records_collection.find(query).sort('created_at', -1))
        
        # Convert ObjectId to string
        for emission in emissions:
            emission['_id'] = str(emission['_id'])
            emission['user_id'] = str(emission['user_id'])
        
        # Calculate total
        total_co2 = sum(e['co2_equivalent'] for e in emissions)
        
        return jsonify({
            'emissions': emissions,
            'total_co2': total_co2,
            'count': len(emissions)
        }), 200
        
    except Exception as e:
        return jsonify({'message': f'Error: {str(e)}'}), 500

# # Dashboard Data
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
        
        print(f"\n=== Dashboard Request ===")
        print(f"Current Month/Year: {current_month}/{current_year}")
        
        # Get ONLY current month/year emissions
        current_month_emissions = list(emission_records_collection.find({
            'user_id': current_user['_id'],
            'year': current_year,
            'month': current_month
        }))
        current_month_total = sum(float(e.get('co2_equivalent', 0)) for e in current_month_emissions)
        print(f"Current month ({current_month}/{current_year}) total: {current_month_total}")
        
        # Get last month
        if current_month == 1:
            last_month = 12
            last_month_year = current_year - 1
        else:
            last_month = current_month - 1
            last_month_year = current_year
            
        last_month_emissions = list(emission_records_collection.find({
            'user_id': current_user['_id'],
            'year': last_month_year,
            'month': last_month
        }))
        last_month_total = sum(float(e.get('co2_equivalent', 0)) for e in last_month_emissions)
        
        # Get ONLY current year emissions
        current_year_emissions = list(emission_records_collection.find({
            'user_id': current_user['_id'],
            'year': current_year
        }))
        current_year_total = sum(float(e.get('co2_equivalent', 0)) for e in current_year_emissions)
        print(f"Current year ({current_year}) total: {current_year_total}")
        
        # Get ONLY last year emissions
        last_year_emissions = list(emission_records_collection.find({
            'user_id': current_user['_id'],
            'year': last_year
        }))
        last_year_total = sum(float(e.get('co2_equivalent', 0)) for e in last_year_emissions)
        print(f"Last year ({last_year}) total: {last_year_total}")
        
        # Category breakdown for CURRENT YEAR ONLY
        category_breakdown = {}
        for e in current_year_emissions:
            cat = e.get('category', 'other')
            category_breakdown[cat] = category_breakdown.get(cat, 0) + float(e.get('co2_equivalent', 0))
        
        # Monthly trend for CURRENT YEAR
        monthly_trend = []
        for m in range(1, 13):
            month_data = [e for e in current_year_emissions if int(e.get('month', 0)) == m]
            month_total = sum(float(e.get('co2_equivalent', 0)) for e in month_data)
            monthly_trend.append({
                'month': m,
                'total': month_total,
                'hasData': len(month_data) > 0
            })
        print(f"Monthly trend: {monthly_trend}")
        
        # Monthly trend for LAST YEAR
        last_year_trend = []
        for m in range(1, 13):
            month_data = [e for e in last_year_emissions if int(e.get('month', 0)) == m]
            month_total = sum(float(e.get('co2_equivalent', 0)) for e in month_data)
            last_year_trend.append({
                'month': m,
                'total': month_total
            })
        
        # Calculate percentages
        month_change_percentage = 0
        if last_month_total > 0:
            month_change_percentage = ((current_month_total - last_month_total) / last_month_total * 100)
        
        year_change_percentage = 0
        if last_year_total > 0:
            year_change_percentage = ((current_year_total - last_year_total) / last_year_total * 100)
        
        response_data = {
            'current_month_total': round(current_month_total, 2),
            'last_month_total': round(last_month_total, 2),
            'month_change_percentage': round(month_change_percentage, 1),
            'current_year_total': round(current_year_total, 2),
            'last_year_total': round(last_year_total, 2),
            'year_change_percentage': round(year_change_percentage, 1),
            'category_breakdown': category_breakdown,
            'monthly_trend': monthly_trend,
            'last_year_trend': last_year_trend,
            'missing_categories': [],
            'current_month': current_month,
            'current_year': current_year,
            'last_year': last_year,
            'has_data': len(current_year_emissions) > 0
        }
        
        print(f"Sending response with {len(monthly_trend)} monthly data points")
        print(f"Response data keys: {response_data.keys()}")
        
        return jsonify(response_data), 200
        
    except Exception as e:
        print(f"Dashboard error: {str(e)}")
        import traceback
        traceback.print_exc()
        return jsonify({'message': f'Error: {str(e)}'}), 500
    
# Create Report
@app.route('/api/reports', methods=['POST'])
@token_required
def create_report(current_user):
    try:
        data = request.get_json()
        
        # Get emissions for the period
        emissions = list(emission_records_collection.find({
            'user_id': current_user['_id'],
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
            'create_date': datetime.utcnow(),
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
        reports = list(reports_collection.find({'user_id': current_user['_id']}).sort('create_date', -1))
        
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

if __name__ == '__main__':
    print("Starting Carbon Accounting API...")
    print(f"Upload folder: {app.config['UPLOAD_FOLDER']}")
    app.run(debug=True, host='0.0.0.0', port=5000)

# File Upload Endpoint
@app.route('/api/upload', methods=['POST'])
@token_required
def upload_file(current_user):
    try:
        print("=== UPLOAD REQUEST ===")
        
        if 'file' not in request.files:
            return jsonify({'success': False, 'message': 'No file provided'}), 400
        
        file = request.files['file']
        if file.filename == '':
            return jsonify({'success': False, 'message': 'No file selected'}), 400
            
        filename = file.filename.lower()
        print(f"Processing file: {filename}")
        
        # Process based on file type
        if filename.endswith(('.xlsx', '.xls', '.csv')):
            print("Processing spreadsheet...")
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
        
        # Get historical data for comparison
        historical = list(emission_records_collection.find({
            'user_id': current_user['_id'],
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

# Multi-format Report Generation
@app.route('/api/reports/generate', methods=['POST'])
@token_required
def generate_formatted_report(current_user):
    try:
        data = request.get_json()
        report_format = data['format']  # ISO, CFO, GHG
        start_date = data['start_date']
        end_date = data['end_date']
        
        # Get emission data
        emissions = get_emissions_for_period(
            current_user['_id'],
            start_date,
            end_date
        )
        
        # Generate report based on format
        if report_format == 'ISO':
            report = generate_iso_14064_report(emissions, current_user)
        elif report_format == 'CFO':
            report = generate_cfo_report(emissions, current_user)
        elif report_format == 'GHG':
            report = generate_ghg_protocol_report(emissions, current_user)
        else:
            return jsonify({'message': 'Invalid report format'}), 400
        
        # Generate AI description
        ai_description = generate_ai_description(emissions, report_format)
        report['ai_description'] = ai_description
        
        # Save report
        report_id = reports_collection.insert_one(report).inserted_id
        
        return jsonify({
            'report_id': str(report_id),
            'download_url': f'/api/reports/download/{report_id}'
        }), 200
        
    except Exception as e:
        return jsonify({'message': f'Error: {str(e)}'}), 500

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
    df = pd.read_excel(file) if file.filename.endswith('.xlsx', '.xls') else pd.read_csv(file)
    
    # Expected columns: date, category, amount, unit
    records_added = 0
    for index, row in df.iterrows():
        emission_record = {
            'record_id': generate_record_id(),
            'user_id': user_id,
            'category': row['category'],
            'amount': float(row['amount']),
            'unit': row['unit'],
            'month': pd.to_datetime(row['date']).month,
            'year': pd.to_datetime(row['date']).year,
            'created_at': datetime.utcnow()
        }
        
        # Calculate CO2
        factor = emission_factors_collection.find_one({
            'activity_type': row['category'],
            'unit': row['unit']
        })
        
        emission_record['co2_equivalent'] = float(row['amount']) * (factor['value'] if factor else 0)
        
        emission_records_collection.insert_one(emission_record)
        records_added += 1
    
    return {'message': f'Successfully imported {records_added} records'}

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
        
        print(f"\n=== Dashboard Request ===")
        print(f"User: {current_user['email']}")
        print(f"Current Month/Year: {current_month}/{current_year}")
        
        # Get ONLY current month emissions
        current_month_emissions = list(emission_records_collection.find({
            'user_id': current_user['_id'],
            'year': current_year,
            'month': current_month
        }))
        
        print(f"Current month emissions count: {len(current_month_emissions)}")
        for e in current_month_emissions:
            print(f"  - {e['category']}: {e['amount']} (month: {e['month']}, year: {e['year']})")
        
        current_month_total = sum(float(e.get('co2_equivalent', 0)) for e in current_month_emissions)
        
        # Get last month
        if current_month == 1:
            last_month = 12
            last_month_year = current_year - 1
        else:
            last_month = current_month - 1
            last_month_year = current_year
            
        last_month_emissions = list(emission_records_collection.find({
            'user_id': current_user['_id'],
            'year': last_month_year,
            'month': last_month
        }))
        last_month_total = sum(float(e.get('co2_equivalent', 0)) for e in last_month_emissions)
        
        # Get current year total
        current_year_emissions = list(emission_records_collection.find({
            'user_id': current_user['_id'],
            'year': current_year
        }))
        current_year_total = sum(float(e.get('co2_equivalent', 0)) for e in current_year_emissions)
        
        # Get last year total
        last_year_emissions = list(emission_records_collection.find({
            'user_id': current_user['_id'],
            'year': last_year
        }))
        last_year_total = sum(float(e.get('co2_equivalent', 0)) for e in last_year_emissions)
        
        # Category breakdown for current year
        category_breakdown = {}
        for e in current_year_emissions:
            cat = e.get('category', 'other')
            category_breakdown[cat] = category_breakdown.get(cat, 0) + float(e.get('co2_equivalent', 0))
        
        # Monthly trend for current year
        monthly_trend = []
        for m in range(1, 13):
            month_data = [e for e in current_year_emissions if e.get('month') == m]
            month_total = sum(float(e.get('co2_equivalent', 0)) for e in month_data)
            monthly_trend.append({
                'month': m,
                'total': month_total,
                'hasData': len(month_data) > 0
            })
        
        # Monthly trend for last year
        last_year_trend = []
        for m in range(1, 13):
            month_data = [e for e in last_year_emissions if e.get('month') == m]
            month_total = sum(float(e.get('co2_equivalent', 0)) for e in month_data)
            last_year_trend.append({
                'month': m,
                'total': month_total
            })
        
        print(f"Current month total: {current_month_total}")
        print(f"Current year total: {current_year_total}")
        print(f"Category breakdown: {category_breakdown}")
        print(f"Monthly trend has data: {any(m['hasData'] for m in monthly_trend)}")
        
        response_data = {
            'current_month_total': current_month_total,
            'last_month_total': last_month_total,
            'month_change_percentage': ((current_month_total - last_month_total) / last_month_total * 100) if last_month_total > 0 else 0,
            'current_year_total': current_year_total,
            'last_year_total': last_year_total,
            'year_change_percentage': ((current_year_total - last_year_total) / last_year_total * 100) if last_year_total > 0 else 0,
            'category_breakdown': category_breakdown,
            'monthly_trend': monthly_trend,
            'last_year_trend': last_year_trend,
            'missing_categories': [],
            'current_month': current_month,
            'current_year': current_year,
            'last_year': last_year,
            'has_data': len(current_year_emissions) > 0
        }
        
        return jsonify(response_data), 200
        
    except Exception as e:
        print(f"Dashboard error: {str(e)}")
        import traceback
        traceback.print_exc()
        return jsonify({'message': f'Error: {str(e)}'}), 500

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