import 'package:flutter/material.dart';

class LocalizationService extends ChangeNotifier {
  static final LocalizationService _instance = LocalizationService._internal();
  factory LocalizationService() => _instance;
  LocalizationService._internal();

  String _currentLanguage = 'en';
  String get currentLanguage => _currentLanguage;
  bool get isThaiLanguage => _currentLanguage == 'th';

  void setLanguage(String languageCode) {
    _currentLanguage = languageCode;
    notifyListeners();
  }

  void toggleLanguage() {
    _currentLanguage = _currentLanguage == 'en' ? 'th' : 'en';
    notifyListeners();
  }

  // App Title and Navigation
  String get appTitle => isThaiLanguage ? 'ระบบบัญชีคาร์บอน' : 'Carbon Accounting';
  String get dashboard => isThaiLanguage ? 'แดชบอร์ด' : 'Dashboard';
  String get smartDashboard => isThaiLanguage ? 'แดชบอร์ดอัจฉริยะ' : 'Smart Dashboard';
  String get addEmission => isThaiLanguage ? 'เพิ่มข้อมูลการปล่อย' : 'Add Emission';
  String get reports => isThaiLanguage ? 'รายงาน' : 'Reports';
  String get admin => isThaiLanguage ? 'ผู้ดูแลระบบ' : 'Admin';
  String get uploadData => isThaiLanguage ? 'อัปโหลดข้อมูล' : 'Upload Data';

  // Authentication
  String get login => isThaiLanguage ? 'เข้าสู่ระบบ' : 'Login';
  String get register => isThaiLanguage ? 'สมัครสมาชิก' : 'Register';
  String get logout => isThaiLanguage ? 'ออกจากระบบ' : 'Logout';
  String get email => isThaiLanguage ? 'อีเมล' : 'Email';
  String get password => isThaiLanguage ? 'รหัสผ่าน' : 'Password';
  String get confirmPassword => isThaiLanguage ? 'ยืนยันรหัสผ่าน' : 'Confirm Password';
  String get fullName => isThaiLanguage ? 'ชื่อ-นามสกุล' : 'Full Name';
  String get username => isThaiLanguage ? 'ชื่อผู้ใช้' : 'Username';

  // Emission Categories
  String getCategoryName(String category) {
    if (isThaiLanguage) {
      switch (category) {
        case 'electricity': return 'ไฟฟ้า';
        case 'diesel': return 'น้ำมันดีเซล';
        case 'gasoline': return 'น้ำมันเบนซิน';
        case 'natural_gas': return 'ก๊าซธรรมชาติ';
        case 'waste': return 'ขยะ';
        case 'transport': return 'การขนส่ง';
        default: return category;
      }
    } else {
      switch (category) {
        case 'electricity': return 'Electricity';
        case 'diesel': return 'Diesel Fuel';
        case 'gasoline': return 'Gasoline';
        case 'natural_gas': return 'Natural Gas';
        case 'waste': return 'Waste';
        case 'transport': return 'Transportation';
        default: return category.toUpperCase();
      }
    }
  }

  String getUnitName(String unit) {
    if (isThaiLanguage) {
      switch (unit) {
        case 'kWh': return 'กิโลวัตต์ชั่วโมง';
        case 'liter': return 'ลิตร';
        case 'litre': return 'ลิตร';
        case 'cubic_meter': return 'ลูกบาศก์เมตร';
        case 'kg': return 'กิโลกรัม';
        case 'km': return 'กิโลเมตร';
        case 'scf': return 'ลูกบาศก์ฟุต';
        case 'MJ': return 'เมกะจูล';
        case 'm³': return 'ลูกบาศก์เมตร';
        default: return unit;
      }
    } else {
      return unit;
    }
  }

  // Common UI Elements
  String get save => isThaiLanguage ? 'บันทึก' : 'Save';
  String get cancel => isThaiLanguage ? 'ยกเลิก' : 'Cancel';
  String get delete => isThaiLanguage ? 'ลบ' : 'Delete';
  String get edit => isThaiLanguage ? 'แก้ไข' : 'Edit';
  String get add => isThaiLanguage ? 'เพิ่ม' : 'Add';
  String get search => isThaiLanguage ? 'ค้นหา' : 'Search';
  String get filter => isThaiLanguage ? 'กรอง' : 'Filter';
  String get loading => isThaiLanguage ? 'กำลังโหลด...' : 'Loading...';
  String get noData => isThaiLanguage ? 'ไม่มีข้อมูล' : 'No Data';
  String get error => isThaiLanguage ? 'ข้อผิดพลาด' : 'Error';
  String get success => isThaiLanguage ? 'สำเร็จ' : 'Success';
  String get warning => isThaiLanguage ? 'คำเตือน' : 'Warning';
  String get confirm => isThaiLanguage ? 'ยืนยัน' : 'Confirm';

  // Dashboard
  String get totalEmissions => isThaiLanguage ? 'การปล่อยทั้งหมด' : 'Total Emissions';
  String get monthlyEmissions => isThaiLanguage ? 'การปล่อยรายเดือน' : 'Monthly Emissions';
  String get yearlyEmissions => isThaiLanguage ? 'การปล่อยรายปี' : 'Yearly Emissions';
  String get emissionsByCategory => isThaiLanguage ? 'การปล่อยตามหมวดหมู่' : 'Emissions by Category';
  String get carbonFootprint => isThaiLanguage ? 'รอยเท้าคาร์บอน' : 'Carbon Footprint';
  String get co2Equivalent => isThaiLanguage ? 'เทียบเท่า CO₂' : 'CO₂ Equivalent';
  String get kgCO2 => isThaiLanguage ? 'กก. CO₂' : 'kg CO₂';
  String get tonsCO2 => isThaiLanguage ? 'ตัน CO₂' : 'tons CO₂';

  // Forms
  String get category => isThaiLanguage ? 'หมวดหมู่' : 'Category';
  String get amount => isThaiLanguage ? 'จำนวน' : 'Amount';
  String get unit => isThaiLanguage ? 'หน่วย' : 'Unit';
  String get date => isThaiLanguage ? 'วันที่' : 'Date';
  String get month => isThaiLanguage ? 'เดือน' : 'Month';
  String get year => isThaiLanguage ? 'ปี' : 'Year';
  String get description => isThaiLanguage ? 'รายละเอียด' : 'Description';
  String get notes => isThaiLanguage ? 'หมายเหตุ' : 'Notes';

  // Report Generation
  String get generateReport => isThaiLanguage ? 'สร้างรายงาน' : 'Generate Report';
  String get reportType => isThaiLanguage ? 'ประเภทรายงาน' : 'Report Type';
  String get standardGHG => isThaiLanguage ? 'มาตรฐาน GHG' : 'GHG Standard';
  String get iso14064 => isThaiLanguage ? 'มาตรฐาน ISO 14064' : 'ISO 14064';
  String get customReport => isThaiLanguage ? 'รายงานกำหนดเอง' : 'Custom Report';
  String get downloadPDF => isThaiLanguage ? 'ดาวน์โหลด PDF' : 'Download PDF';
  String get downloadWord => isThaiLanguage ? 'ดาวน์โหลด Word' : 'Download Word';

  // Add Emission Screen
  String get addEmissionData => isThaiLanguage ? 'เพิ่มข้อมูลการปล่อย' : 'Add Emission Data';
  String get selectEmissionCategory => isThaiLanguage ? 'เลือกหมวดหมู่การปล่อย' : 'Select Emission Category';
  String get chooseEmissionCategory => isThaiLanguage ? 'เลือกหมวดหมู่การปล่อย' : 'Choose emission category';
  String get pleaseSelectCategory => isThaiLanguage ? 'กรุณาเลือกหมวดหมู่' : 'Please select a category';
  String get selectFuelEnergyType => isThaiLanguage ? 'เลือกประเภทเชื้อเพลิง/พลังงาน' : 'Select Fuel/Energy Type';
  String get chooseFuelEnergyType => isThaiLanguage ? 'เลือกประเภทเชื้อเพลิง/พลังงาน' : 'Choose fuel/energy type';
  String get searchFuelTypes => isThaiLanguage ? 'ค้นหาประเภทเชื้อเพลิง...' : 'Search fuel types...';
  String get pleaseSelectFuelType => isThaiLanguage ? 'กรุณาเลือกประเภทเชื้อเพลิง' : 'Please select a fuel type';
  String get enterConsumptionAmount => isThaiLanguage ? 'กรอกปริมาณการใช้' : 'Enter Consumption Amount';
  String get emissionFactor => isThaiLanguage ? 'ค่าสัมประสิทธิ์การปล่อย' : 'Emission Factor';
  String get note => isThaiLanguage ? 'หมายเหตุ' : 'Note';
  String get pleaseEnterAmount => isThaiLanguage ? 'กรุณากรอกปริมาณ' : 'Please enter amount';
  String get pleaseEnterValidNumber => isThaiLanguage ? 'กรุณากรอกตัวเลขที่ถูกต้อง' : 'Please enter a valid number';
  String get amountMustBeGreaterThanZero => isThaiLanguage ? 'ปริมาณต้องมากกว่า 0' : 'Amount must be greater than 0';
  String get co2EquivalentCalculation => isThaiLanguage ? 'การคำนวณเทียบเท่า CO₂' : 'CO₂ Equivalent Calculation';
  String get selectReportingPeriod => isThaiLanguage ? 'เลือกช่วงเวลารายงาน' : 'Select Reporting Period';
  String get addEmissionRecord => isThaiLanguage ? 'เพิ่มบันทึกการปล่อย' : 'Add Emission Record';
  String get resetForm => isThaiLanguage ? 'รีเซ็ตฟอร์ม' : 'Reset Form';
  String get tgoEmissionFactors => isThaiLanguage ? 'ค่าสัมประสิทธิ์การปล่อย TGO' : 'TGO Emission Factors';
  String get usingTgoFactors => isThaiLanguage ? 'ใช้ค่าสัมประสิทธิ์การปล่อยของ TGO ประเทศไทย (เมษายน 2022)' : 'Using TGO Thailand emission factors (April 2022)';
  String get tgoDescription => isThaiLanguage ? 'องค์การบริหารจัดการก๊าซเรือนกระจกประเทศไทย (TGO)' : 'Thailand Greenhouse Gas Management Organization (TGO)';
  String get updated => isThaiLanguage ? 'อัปเดต:' : 'Updated:';
  String get tgoFactorsDescription => isThaiLanguage ?
    'แอปนี้ใช้ค่าสัมประสิทธิ์การปล่อยอย่างเป็นทางการจาก TGO ประเทศไทย จัดระเบียบตามขอบเขต GHG Protocol:' :
    'This app uses official emission factors from TGO Thailand, organized by GHG Protocol Scopes:';
  String get scope1 => isThaiLanguage ? 'ขอบเขตที่ 1: การปล่อยโดยตรงจากแหล่งที่เป็นเจ้าของ/ควบคุม' : 'Scope 1: Direct emissions from owned/controlled sources';
  String get scope2 => isThaiLanguage ? 'ขอบเขตที่ 2: การปล่อยทางอ้อมจากพลังงานที่ซื้อ' : 'Scope 2: Indirect emissions from purchased energy';
  String get allFactorsDescription => isThaiLanguage ? 
    'ค่าสัมประสิทธิ์ทั้งหมดเป็น kgCO₂eq ต่อหน่วย และเป็นไปตามมาตรฐานสากล (IPCC, GHG Protocol)' :
    'All factors are in kgCO₂eq per unit and follow international standards (IPCC, GHG Protocol).';
  String get close => isThaiLanguage ? 'ปิด' : 'Close';

  // Dashboard Screen
  String get overview => isThaiLanguage ? 'ภาพรวม' : 'Overview';
  String get recentEmissions => isThaiLanguage ? 'การปล่อยล่าสุด' : 'Recent Emissions';
  String get viewAll => isThaiLanguage ? 'ดูทั้งหมด' : 'View All';
  String get thisMonth => isThaiLanguage ? 'เดือนนี้' : 'This Month';
  String get thisYear => isThaiLanguage ? 'ปีนี้' : 'This Year';
  String get addNewEmission => isThaiLanguage ? 'เพิ่มการปล่อยใหม่' : 'Add New Emission';
  String get viewReports => isThaiLanguage ? 'ดูรายงาน' : 'View Reports';

  // Upload Data Screen
  String get uploadDataTitle => isThaiLanguage ? 'อัปโหลดข้อมูล' : 'Upload Data';
  String get selectFile => isThaiLanguage ? 'เลือกไฟล์' : 'Select File';
  String get supportedFormats => isThaiLanguage ? 'รูปแบบที่รองรับ' : 'Supported Formats';
  String get uploadFile => isThaiLanguage ? 'อัปโหลดไฟล์' : 'Upload File';
  String get processing => isThaiLanguage ? 'กำลังประมวลผล...' : 'Processing...';
  String get uploadSuccess => isThaiLanguage ? 'อัปโหลดสำเร็จ' : 'Upload Successful';
  String get uploadFailed => isThaiLanguage ? 'อัปโหลดไม่สำเร็จ' : 'Upload Failed';
  String get supportedFileTypes => isThaiLanguage ? 'รูปแบบไฟล์ที่รองรับ' : 'Supported File Types';
  String get spreadsheets => isThaiLanguage ? 'สเปรดชีต' : 'Spreadsheets';
  String get csvExcel => isThaiLanguage ? 'CSV, Excel (.xlsx, .xls)' : 'CSV, Excel (.xlsx, .xls)';
  String get bulkEmissionImport => isThaiLanguage ? 'นำเข้าข้อมูลการปล่อยจำนวนมาก' : 'Bulk emission data import';
  String get pdfDocuments => isThaiLanguage ? 'เอกสาร PDF' : 'PDF Documents';
  String get utilityBills => isThaiLanguage ? 'ใบเสร็จจ่ายค่าสาธารณูปโภค' : 'Utility bills';
  String get automaticExtraction => isThaiLanguage ? 'แยกข้อมูลอัตโนมัติ' : 'Automatic data extraction';
  String get images => isThaiLanguage ? 'รูปภาพ' : 'Images';
  String get jpgPngPhotos => isThaiLanguage ? 'รูปภาพ JPG, PNG' : 'JPG, PNG photos';
  String get ocrTextRecognition => isThaiLanguage ? 'การรู้จำข้อความด้วย OCR' : 'OCR text recognition';
  String get fileSizeLimit => isThaiLanguage ? 'ขีดจำกัดขนาดไฟล์' : 'File Size Limit';
  String get maximum16MB => isThaiLanguage ? 'สูงสุด 16 MB' : 'Maximum 16 MB';
  String get uploadYourFiles => isThaiLanguage ? 'อัปโหลดไฟล์ของคุณ' : 'Upload Your Files';
  String get csvExcelPdfImages => isThaiLanguage ? 'CSV • Excel • PDF • รูปภาพ' : 'CSV • Excel • PDF • Images';
  String get tapToSelectFiles => isThaiLanguage ? 'แตะเพื่อเลือกไฟล์ (สูงสุด 16MB)' : 'Tap to select files (max 16MB)';
  String get processingFile => isThaiLanguage ? 'กำลังประมวลผลไฟล์...' : 'Processing File...';
  String get uploadStatus => isThaiLanguage ? 'สถานะการอัปโหลด' : 'Upload Status';
  String get details => isThaiLanguage ? 'รายละเอียด:' : 'Details:';
  String get csvExcelTemplate => isThaiLanguage ? 'เทมเพลต CSV/Excel' : 'CSV/Excel Template';
  String get useThisFormat => isThaiLanguage ? 'ใช้รูปแบบนี้สำหรับการอัปโหลดสเปรดชีต:' : 'Use this format for spreadsheet uploads:';
  String get viewUploadGuidelines => isThaiLanguage ? 'ดูคู่มือการอัปโหลด' : 'View Upload Guidelines';
  String get uploadGuidelines => isThaiLanguage ? 'คู่มือการอัปโหลด' : 'Upload Guidelines';
  String get spreadsheetFormat => isThaiLanguage ? 'รูปแบบสเปรดชีต:' : 'Spreadsheet Format:';
  String get requiredColumns => isThaiLanguage ? '• คอลัมน์ที่จำเป็น: date, category, amount, unit' : '• Required columns: date, category, amount, unit';
  String get dateFormatInfo => isThaiLanguage ? '• รูปแบบวันที่: YYYY-MM-DD (เช่น 2024-01-15)' : '• Date format: YYYY-MM-DD (e.g., 2024-01-15)';
  String get categoriesInfo => isThaiLanguage ? '• หมวดหมู่: electricity, diesel, gasoline, natural_gas, waste, transport' : '• Categories: electricity, diesel, gasoline, natural_gas, waste, transport';
  String get unitsInfo => isThaiLanguage ? '• หน่วยต้องตรงกับหมวดหมู่ (kWh, liter, cubic_meter, kg, km)' : '• Units must match categories (kWh, liter, cubic_meter, kg, km)';
  String get pdfDocumentsInfo => isThaiLanguage ? 'เอกสาร PDF:' : 'PDF Documents:';
  String get uploadUtilityBills => isThaiLanguage ? '• อัปโหลดใบเสร็จค่าสาธารณูปโภคเพื่อประมวลผลอัตโนมัติ' : '• Upload utility bills for automatic processing';
  String get clearReadableText => isThaiLanguage ? '• ข้อความที่ชัดเจนและอ่านง่ายจะให้ผลลัพธ์ดีที่สุด' : '• Clear, readable text works best';
  String get imagesInfo => isThaiLanguage ? 'รูปภาพ:' : 'Images:';
  String get takeClearPhotos => isThaiLanguage ? '• ถ่ายรูปใบเสร็จค่าไฟฟ้าให้ชัดเจน' : '• Take clear photos of electricity bills';
  String get goodLightingFocus => isThaiLanguage ? '• แสงไฟดีและโฟกัสชัดเป็นสิ่งสำคัญ' : '• Good lighting and focus important';
  String get supportsThaiBills => isThaiLanguage ? '• รองรับใบเสร็จค่าไฟฟ้าไทย (การไฟฟ้านครหลวง/การไฟฟ้าส่วนภูมิภาค)' : '• Supports Thai electricity bills (MEA/PEA)';
  String get fileLimitsInfo => isThaiLanguage ? 'ขีดจำกัดไฟล์:' : 'File Limits:';
  String get maxFileSizeInfo => isThaiLanguage ? '• ขนาดไฟล์สูงสุด: 16 MB' : '• Maximum file size: 16 MB';
  String get supportedFilesInfo => isThaiLanguage ? '• รองรับ: CSV, Excel, PDF, JPG, PNG' : '• Supported: CSV, Excel, PDF, JPG, PNG';
  String get gotIt => isThaiLanguage ? 'เข้าใจแล้ว' : 'Got it';
  String get selectingFile => isThaiLanguage ? 'กำลังเลือกไฟล์...' : 'Selecting file...';
  String get noFileSelected => isThaiLanguage ? 'ไม่ได้เลือกไฟล์' : 'No file selected';
  String get fileTooLarge => isThaiLanguage ? 'ข้อผิดพลาด: ไฟล์ใหญ่เกินไป ขนาดสูงสุดคือ 16MB' : 'Error: File too large. Maximum size is 16MB.';
  String get cannotReadFile => isThaiLanguage ? 'ข้อผิดพลาด: ไม่สามารถอ่านเนื้อหาไฟล์ได้ ลองใช้เบราว์เซอร์อื่นหรือใช้แอปบนมือถือ' : 'Error: Cannot read file content. Try a different browser or use mobile app.';

  // Admin Panel
  String get adminPanel => isThaiLanguage ? 'แผงควบคุมผู้ดูแล' : 'Admin Panel';
  String get userManagement => isThaiLanguage ? 'การจัดการผู้ใช้' : 'User Management';
  String get systemSettings => isThaiLanguage ? 'การตั้งค่าระบบ' : 'System Settings';
  String get dataManagement => isThaiLanguage ? 'การจัดการข้อมูล' : 'Data Management';
  String get systemReports => isThaiLanguage ? 'รายงานระบบ' : 'System Reports';
  String get statistics => isThaiLanguage ? 'สถิติ' : 'Statistics';
  String get users => isThaiLanguage ? 'ผู้ใช้' : 'Users';
  String get totalUsers => isThaiLanguage ? 'ผู้ใช้ทั้งหมด' : 'Total Users';
  String get activeUsers => isThaiLanguage ? 'ผู้ใช้ที่ใช้งาน' : 'Active Users';
  String get role => isThaiLanguage ? 'บทบาท' : 'Role';
  String get status => isThaiLanguage ? 'สถานะ' : 'Status';
  String get actions => isThaiLanguage ? 'การดำเนินการ' : 'Actions';
  String get active => isThaiLanguage ? 'ใช้งาน' : 'Active';
  String get inactive => isThaiLanguage ? 'ไม่ใช้งาน' : 'Inactive';
  String get enable => isThaiLanguage ? 'เปิดใช้งาน' : 'Enable';
  String get disable => isThaiLanguage ? 'ปิดใช้งาน' : 'Disable';

  // Report Generation Screen
  String get reportConfiguration => isThaiLanguage ? 'การตั้งค่ารายงาน' : 'Report Configuration';
  String get selectTemplate => isThaiLanguage ? 'เลือกเทมเพลต' : 'Select Template';
  String get dateRange => isThaiLanguage ? 'ช่วงวันที่' : 'Date Range';
  String get startDate => isThaiLanguage ? 'วันเริ่มต้น' : 'Start Date';
  String get endDate => isThaiLanguage ? 'วันสิ้นสุด' : 'End Date';
  String get includeCharts => isThaiLanguage ? 'รวมแผนภูมิ' : 'Include Charts';
  String get includeDetails => isThaiLanguage ? 'รวมรายละเอียด' : 'Include Details';
  String get preview => isThaiLanguage ? 'ตัวอย่าง' : 'Preview';
  String get download => isThaiLanguage ? 'ดาวน์โหลด' : 'Download';
  String get generating => isThaiLanguage ? 'กำลังสร้าง...' : 'Generating...';
  String get generateReportsTitle => isThaiLanguage ? 'สร้างรายงาน' : 'Generate Reports';
  String get reportPreview => isThaiLanguage ? 'ตัวอย่างรายงาน' : 'Report Preview';
  String get previewReportData => isThaiLanguage ? 'ดูตัวอย่างข้อมูลรายงาน' : 'Preview Report Data';
  String get loadingPreview => isThaiLanguage ? 'กำลังโหลดตัวอย่าง...' : 'Loading Preview...';
  String get generateAIReport => isThaiLanguage ? 'สร้างรายงาน AI' : 'Generate AI Report';
  String get generatingReport => isThaiLanguage ? 'กำลังสร้างรายงาน...' : 'Generating Report...';
  String get generatedReports => isThaiLanguage ? 'รายงานที่สร้างแล้ว' : 'Generated Reports';
  String get aiInsightsEnabled => isThaiLanguage ? 'เปิดใช้ AI Insights' : 'AI Insights Enabled';
  String get aiInsightsDescription => isThaiLanguage ? 'รายงานทุกฉบับรวม AI และคำแนะนำ' : 'All reports include AI-powered analysis and recommendations';
  String get period => isThaiLanguage ? 'ช่วงเวลา' : 'Period';
  String get recordsCount => isThaiLanguage ? 'จำนวนบันทึก' : 'Records Count';
  String get records => isThaiLanguage ? 'บันทึก' : 'records';
  String get organization => isThaiLanguage ? 'องค์กร' : 'Organization';
  String get emissionsByScope => isThaiLanguage ? 'การปล่อยตามขอบเขต:' : 'Emissions by Scope:';
  String get downloadReport => isThaiLanguage ? 'ดาวน์โหลดรายงาน' : 'Download Report';
  String get reportGenerated => isThaiLanguage ? 'สร้างรายงานสำเร็จ' : 'Report Generated Successfully';
  String get downloadComplete => isThaiLanguage ? 'ดาวน์โหลดเสร็จสิ้น' : 'Download Complete';
  String get fileLocation => isThaiLanguage ? 'ตำแหน่งไฟล์' : 'File Location';
  String get downloadToFolder => isThaiLanguage ? 'รายงานถูกดาวน์โหลดไปยังโฟลเดอร์ Downloads ของอุปกรณ์' : 'The report has been downloaded to your device\'s Downloads folder.';
  String get downloadInstructions => isThaiLanguage ? 'ไฟล์จะถูกดาวน์โหลดไปยังตำแหน่งดาวน์โหลดเริ่มต้นของอุปกรณ์' : 'The file will be downloaded to your device\'s default download location.';
  String get reportReady => isThaiLanguage ? 'รายงานพร้อมสำหรับดาวน์โหลด' : 'The report is ready for download.';
  String get reportId => isThaiLanguage ? 'รหัสรายงาน' : 'Report ID';
  String get fileName => isThaiLanguage ? 'ชื่อไฟล์' : 'File Name';
  String get fileSize => isThaiLanguage ? 'ขนาดไฟล์' : 'Size';
  String get generatedAt => isThaiLanguage ? 'สร้างเมื่อ' : 'Generated at';
  String get format => isThaiLanguage ? 'รูปแบบ' : 'Format';
  String get created => isThaiLanguage ? 'สร้างเมื่อ' : 'Created';
  String get loadingFormats => isThaiLanguage ? 'กำลังโหลดรูปแบบ...' : 'Loading formats...';
  String get loadingFileTypes => isThaiLanguage ? 'กำลังโหลดประเภทไฟล์...' : 'Loading file types...';
  String get loadingLanguages => isThaiLanguage ? 'กำลังโหลดภาษา...' : 'Loading languages...';
  String get preparingDownload => isThaiLanguage ? 'กำลังเตรียมดาวน์โหลด...' : 'Preparing download...';
  String get startingDownload => isThaiLanguage ? 'กำลังเริ่มดาวน์โหลด...' : 'Starting download...';
  String get pleasePreviewFirst => isThaiLanguage ? 'กรุณาดูตัวอย่างข้อมูลรายงานก่อน' : 'Please preview the report data first';
  String get reportGeneratedSuccess => isThaiLanguage ? 'สร้างรายงานสำเร็จ!' : 'Report generated successfully!';
  String get downloadPDFButton => isThaiLanguage ? 'ดาวน์โหลด PDF' : 'Download PDF';
  String get aiInsightsIncluded => isThaiLanguage ? 'รวม AI Insights:' : 'AI Insights included:';
  String get executiveSummary => isThaiLanguage ? '• บทสรุปผู้บริหาร' : '• Executive Summary';
  String get keyFindings => isThaiLanguage ? '• ผลการค้นพบหลัก' : '• Key Findings';
  String get recommendations => isThaiLanguage ? '• คำแนะนำ' : '• Recommendations';
  String get trendAnalysis => isThaiLanguage ? '• การวิเคราะห์แนวโน้ม' : '• Trend Analysis';
  String get unknownReport => isThaiLanguage ? 'รายงานไม่ระบุ' : 'Unknown Report';
  String get unknown => isThaiLanguage ? 'ไม่ระบุ' : 'Unknown';

  // Language Switching
  String get language => isThaiLanguage ? 'ภาษา' : 'Language';
  String get english => 'English';
  String get thai => 'ไทย';
  String get switchToEnglish => 'Switch to English';
  String get switchToThai => 'เปลี่ยนเป็นภาษาไทย';

  // Month names
  List<String> get monthNames => isThaiLanguage ? [
    'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
    'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม'
  ] : [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  List<String> get monthNamesShort => isThaiLanguage ? [
    'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
    'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'
  ] : [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  String getMonthName(int month, {bool short = false}) {
    if (month < 1 || month > 12) return '';
    return short ? monthNamesShort[month - 1] : monthNames[month - 1];
  }

  String formatCO2(double co2) {
    if (co2 >= 1000) {
      return isThaiLanguage 
        ? '${(co2 / 1000).toStringAsFixed(2)} ตัน CO₂'
        : '${(co2 / 1000).toStringAsFixed(2)} tons CO₂';
    }
    return isThaiLanguage 
      ? '${co2.toStringAsFixed(2)} กก. CO₂'
      : '${co2.toStringAsFixed(2)} kg CO₂';
  }

  // Error Messages
  String get pleaseEnterEmail => isThaiLanguage ? 'กรุณากรอกอีเมล' : 'Please enter email';
  String get pleaseEnterPassword => isThaiLanguage ? 'กรุณากรอกรหัสผ่าน' : 'Please enter password';
  String get invalidEmailFormat => isThaiLanguage ? 'รูปแบบอีเมลไม่ถูกต้อง' : 'Invalid email format';
  String get passwordTooShort => isThaiLanguage ? 'รหัสผ่านสั้นเกินไป' : 'Password is too short';
  String get passwordsDoNotMatch => isThaiLanguage ? 'รหัสผ่านไม่ตรงกัน' : 'Passwords do not match';
  String get loginFailed => isThaiLanguage ? 'เข้าสู่ระบบไม่สำเร็จ' : 'Login failed';
  String get registrationFailed => isThaiLanguage ? 'การสมัครไม่สำเร็จ' : 'Registration failed';
  String get networkError => isThaiLanguage ? 'เกิดข้อผิดพลาดเครือข่าย' : 'Network error';

  // Success Messages
  String get loginSuccessful => isThaiLanguage ? 'เข้าสู่ระบบสำเร็จ' : 'Login successful';
  String get registrationSuccessful => isThaiLanguage ? 'สมัครสมาชิกสำเร็จ' : 'Registration successful';
  String get dataSaved => isThaiLanguage ? 'บันทึกข้อมูลสำเร็จ' : 'Data saved successfully';
  String get dataDeleted => isThaiLanguage ? 'ลบข้อมูลสำเร็จ' : 'Data deleted successfully';

  // Dashboard specific
  String get sessionExpired => isThaiLanguage ? 'เซสชันหมดอายุ กรุณาเข้าสู่ระบบอีกครั้ง' : 'Session expired. Please login again.';
  String get trackYourEmissions => isThaiLanguage ? 'ติดตามการปล่อยของคุณ' : 'Track your emissions';
  String get changeLanguage => isThaiLanguage ? 'เปลี่ยนภาษา' : 'Change Language';
  String get settings => isThaiLanguage ? 'การตั้งค่า' : 'Settings';
  String get settingsComingSoon => isThaiLanguage ? 'การตั้งค่าจะมาเร็วๆ นี้!' : 'Settings coming soon!';
  String get sharedCarbonDashboard => isThaiLanguage ? 'แดชบอร์ดคาร์บอนร่วม' : 'Shared Carbon Dashboard';
  String get viewCollectiveEmissions => isThaiLanguage ? 'ดูการปล่อยรวมจากผู้ใช้ทุกคน' : 'View collective emissions from all users';
  String get usersContributingData => isThaiLanguage ? 'ผู้ใช้มีส่วนร่วมข้อมูล' : 'users contributing data';
  String get quickActions => isThaiLanguage ? 'การดำเนินการด่วน' : 'Quick Actions';
  String get currentMonthSummary => isThaiLanguage ? 'สรุปเดือนปัจจุบัน' : 'Current Month Summary';
  String get shared => isThaiLanguage ? 'ร่วม' : 'Shared';
  String get totalEmissionsLabel => isThaiLanguage ? 'การปล่อยทั้งหมด:' : 'Total Emissions:';
  String get yearTotal => isThaiLanguage ? 'รวมปี:' : 'Year Total:';
  String get noEmissionDataYet => isThaiLanguage ? 'ยังไม่มีข้อมูลการปล่อย' : 'No emission data yet';
  String get noEmissionDataDescription => isThaiLanguage ? 'ยังไม่มีใครเพิ่มข้อมูลการปล่อย เป็นคนแรกที่สนับสนุนแดชบอร์ดร่วม!' : 'No one has added emission data yet. Be the first to contribute to the shared dashboard!';
  String get addFirstEmission => isThaiLanguage ? 'เพิ่มการปล่อยแรก' : 'Add First Emission';
}
