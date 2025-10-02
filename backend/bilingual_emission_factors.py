#!/usr/bin/env python3
"""
Complete bilingual TGO Thailand emission factors with Thai translations
This replaces the update_emission_factors.py with full bilingual support
"""

from datetime import datetime
from models import emission_factors_collection, db
import json

def get_bilingual_tgo_emission_factors():
    """Get all TGO emission factors with complete English and Thai translations"""
    
    # Scope 1: Direct Emissions - Stationary Combustion (Fossil Fuels)
    scope1_stationary_fossil = {
        'natural_gas_scf': {
            'name': 'Natural Gas (SCF)',
            'name_th': 'ก๊าซธรรมชาติ (ลูกบาศก์ฟุต)',
            'unit': 'scf',
            'unit_th': 'ลบ.ฟุต',
            'factor': 0.0573,
            'notes': 'Volumetric measurement',
            'notes_th': 'การวัดปริมาตร',
            'category': 'Stationary Combustion - Fossil Fuels',
            'category_th': 'การเผาไหม้แบบนิ่ง - เชื้อเพลิงฟอสซิล'
        },
        'natural_gas_mj': {
            'name': 'Natural Gas (MJ)',
            'name_th': 'ก๊าซธรรมชาติ (เมกะจูล)',
            'unit': 'MJ',
            'unit_th': 'MJ',
            'factor': 0.0562,
            'notes': 'Energy content measurement',
            'notes_th': 'การวัดปริมาณพลังงาน',
            'category': 'Stationary Combustion - Fossil Fuels',
            'category_th': 'การเผาไหม้แบบนิ่ง - เชื้อเพลิงฟอสซิล'
        },
        'lignite_coal': {
            'name': 'Lignite Coal',
            'name_th': 'ถ่านหินลิกไนท์',
            'unit': 'kg',
            'unit_th': 'กก.',
            'factor': 1.0619,
            'notes': '',
            'notes_th': '',
            'category': 'Stationary Combustion - Fossil Fuels',
            'category_th': 'การเผาไหม้แบบนิ่ง - เชื้อเพลิงฟอสซิล'
        },
        'heavy_fuel_oil_a': {
            'name': 'Heavy Fuel Oil A',
            'name_th': 'น้ำมันเตาหนัก เอ',
            'unit': 'litre',
            'unit_th': 'ลิตร',
            'factor': 3.2200,
            'notes': 'Lower viscosity, lighter grade',
            'notes_th': 'ความหนืดต่ำ เกรดเบา',
            'category': 'Stationary Combustion - Fossil Fuels',
            'category_th': 'การเผาไหม้แบบนิ่ง - เชื้อเพลิงฟอสซิล'
        },
        'heavy_fuel_oil_c': {
            'name': 'Heavy Fuel Oil C',
            'name_th': 'น้ำมันเตาหนัก ซี',
            'unit': 'litre',
            'unit_th': 'ลิตร',
            'factor': 3.2457,
            'notes': 'Higher viscosity, heavier grade',
            'notes_th': 'ความหนืดสูง เกรดหนัก',
            'category': 'Stationary Combustion - Fossil Fuels',
            'category_th': 'การเผาไหม้แบบนิ่ง - เชื้อเพลิงฟอสซิล'
        },
        'gas_diesel_oil': {
            'name': 'Gas/Diesel Oil',
            'name_th': 'น้ำมันก๊าซโซหีน/ดีเซล',
            'unit': 'litre',
            'unit_th': 'ลิตร',
            'factor': 2.7078,
            'notes': '',
            'notes_th': '',
            'category': 'Stationary Combustion - Fossil Fuels',
            'category_th': 'การเผาไหม้แบบนิ่ง - เชื้อเพลิงฟอสซิล'
        },
        'anthracite_coal': {
            'name': 'Anthracite Coal',
            'name_th': 'ถ่านหินแอนทราไซต์',
            'unit': 'kg',
            'unit_th': 'กก.',
            'factor': 3.1000,
            'notes': '',
            'notes_th': '',
            'category': 'Stationary Combustion - Fossil Fuels',
            'category_th': 'การเผาไหม้แบบนิ่ง - เชื้อเพลิงฟอสซิล'
        },
        'sub_bituminous_coal': {
            'name': 'Sub-bituminous Coal',
            'name_th': 'ถ่านหินซับบิทูมินัส',
            'unit': 'kg',
            'unit_th': 'กก.',
            'factor': 2.5454,
            'notes': '',
            'notes_th': '',
            'category': 'Stationary Combustion - Fossil Fuels',
            'category_th': 'การเผาไหม้แบบนิ่ง - เชื้อเพลิงฟอสซิล'
        },
        'jet_kerosene': {
            'name': 'Jet Kerosene',
            'name_th': 'น้ำมันเจ็ทเคโรซีน',
            'unit': 'litre',
            'unit_th': 'ลิตร',
            'factor': 2.4775,
            'notes': '',
            'notes_th': '',
            'category': 'Stationary Combustion - Fossil Fuels',
            'category_th': 'การเผาไหม้แบบนิ่ง - เชื้อเพลิงฟอสซิล'
        },
        'lpg_litre': {
            'name': 'LPG (Liquefied Petroleum Gas)',
            'name_th': 'แอลพีจี (แก๊สปิโตรเลียมเหลว)',
            'unit': 'litre',
            'unit_th': 'ลิตร',
            'factor': 1.6812,
            'notes': '',
            'notes_th': '',
            'category': 'Stationary Combustion - Fossil Fuels',
            'category_th': 'การเผาไหม้แบบนิ่ง - เชื้อเพลิงฟอสซิล'
        },
        'lpg_kg': {
            'name': 'LPG (Liquefied Petroleum Gas)',
            'name_th': 'แอลพีจี (แก๊สปิโตรเลียมเหลว)',
            'unit': 'kg',
            'unit_th': 'กก.',
            'factor': 3.1134,
            'notes': '1 litre = 0.54 kg',
            'notes_th': '1 ลิตร = 0.54 กิโลกรัม',
            'category': 'Stationary Combustion - Fossil Fuels',
            'category_th': 'การเผาไหม้แบบนิ่ง - เชื้อเพลิงฟอสซิล'
        },
        'motor_gasoline': {
            'name': 'Motor Gasoline',
            'name_th': 'น้ำมันเบนซิน',
            'unit': 'litre',
            'unit_th': 'ลิตร',
            'factor': 2.1894,
            'notes': '',
            'notes_th': '',
            'category': 'Stationary Combustion - Fossil Fuels',
            'category_th': 'การเผาไหม้แบบนิ่ง - เชื้อเพลิงฟอสซิล'
        },
    }

    # Scope 1: Direct Emissions - Stationary Combustion (Biomass)
    scope1_stationary_biomass = {
        'fuel_wood': {
            'name': 'Fuel Wood',
            'name_th': 'ไม้เชื้อเพลิง',
            'unit': 'kg',
            'unit_th': 'กก.',
            'factor': 0.0304,
            'notes': 'Excludes biogenic CO₂',
            'notes_th': 'ไม่รวมคาร์บอนไดออกไซด์จากชีวภาพ',
            'category': 'Stationary Combustion - Biomass',
            'category_th': 'การเผาไหม้แบบนิ่ง - ชีวมวล'
        },
        'bagasse': {
            'name': 'Bagasse',
            'name_th': 'กากอ้อย',
            'unit': 'kg',
            'unit_th': 'กก.',
            'factor': 0.0143,
            'notes': 'Excludes biogenic CO₂',
            'notes_th': 'ไม่รวมคาร์บอนไดออกไซด์จากชีวภาพ',
            'category': 'Stationary Combustion - Biomass',
            'category_th': 'การเผาไหม้แบบนิ่ง - ชีวมวล'
        },
        'palm_kernel_shell': {
            'name': 'Palm Kernel Shell',
            'name_th': 'เปลือกเมล็ดปาล์ม',
            'unit': 'kg',
            'unit_th': 'กก.',
            'factor': 0.0352,
            'notes': 'Excludes biogenic CO₂',
            'notes_th': 'ไม่รวมคาร์บอนไดออกไซด์จากชีวภาพ',
            'category': 'Stationary Combustion - Biomass',
            'category_th': 'การเผาไหม้แบบนิ่ง - ชีวมวล'
        },
        'corn_cob': {
            'name': 'Corn Cob',
            'name_th': 'ซังข้าวโพด',
            'unit': 'kg',
            'unit_th': 'กก.',
            'factor': 0.0319,
            'notes': 'Excludes biogenic CO₂',
            'notes_th': 'ไม่รวมคาร์บอนไดออกไซด์จากชีวภาพ',
            'category': 'Stationary Combustion - Biomass',
            'category_th': 'การเผาไหม้แบบนิ่ง - ชีวมวล'
        },
        'biogas': {
            'name': 'Biogas',
            'name_th': 'ก๊าซชีวภาพ',
            'unit': 'm³',
            'unit_th': 'ลม.',
            'factor': 0.0011,
            'notes': 'Excludes biogenic CO₂',
            'notes_th': 'ไม่รวมคาร์บอนไดออกไซด์จากชีวภาพ',
            'category': 'Stationary Combustion - Biomass',
            'category_th': 'การเผาไหม้แบบนิ่ง - ชีวมวล'
        },
        'grid_electricity': {
            'name': 'Grid Mix Electricity (Thailand)',
            'name_th': 'ไฟฟ้าจากระบบส่ายไฟ (ประเทศไทย)',
            'unit': 'kWh',
            'unit_th': 'กิโลวัตต์ชั่วโมง',
            'factor': 0.4999,
            'notes': 'Based on 2016-2018 Thai grid mix',
            'notes_th': 'อิงจากผลิตภัณฑ์ไฟฟ้าไทย ปี 2559-2561',
            'category': 'Purchased Electricity',
            'category_th': 'การใช้ไฟฟ้าที่ซื้อมา'
        },
    }

    # Complete biomass with CO2 versions
    scope1_stationary_biomass_co2 = {
        'fuel_wood_co2': {
            'name': 'Fuel Wood (CO₂ only)',
            'name_th': 'ไม้เชื้อเพลิง (รวม CO₂)',
            'unit': 'kg',
            'unit_th': 'กก.',
            'factor': 1.7909,
            'notes': 'Includes biogenic CO₂',
            'notes_th': 'รวมคาร์บอนไดออกไซด์จากชีวภาพ',
            'category': 'Stationary Combustion - Biomass',
            'category_th': 'การเผาไหม้แบบนิ่ง - ชีวมวล'
        },
        'bagasse_co2': {
            'name': 'Bagasse (CO₂ only)',
            'name_th': 'กากอ้อย (รวม CO₂)',
            'unit': 'kg',
            'unit_th': 'กก.',
            'factor': 0.7530,
            'notes': 'Includes biogenic CO₂',
            'notes_th': 'รวมคาร์บอนไดออกไซด์จากชีวภาพ',
            'category': 'Stationary Combustion - Biomass',
            'category_th': 'การเผาไหม้แบบนิ่ง - ชีวมวล'
        },
        'palm_kernel_shell_co2': {
            'name': 'Palm Kernel Shell (CO₂ only)',
            'name_th': 'เปลือกเมล็ดปาล์ม (รวม CO₂)',
            'unit': 'kg',
            'unit_th': 'กก.',
            'factor': 1.8530,
            'notes': 'Includes biogenic CO₂',
            'notes_th': 'รวมคาร์บอนไดออกไซด์จากชีวภาพ',
            'category': 'Stationary Combustion - Biomass',
            'category_th': 'การเผาไหม้แบบนิ่ง - ชีวมวล'
        },
        'corn_cob_co2': {
            'name': 'Corn Cob (CO₂ only)',
            'name_th': 'ซังข้าวโพด (รวม CO₂)',
            'unit': 'kg',
            'unit_th': 'กก.',
            'factor': 1.6780,
            'notes': 'Includes biogenic CO₂',
            'notes_th': 'รวมคาร์บอนไดออกไซด์จากชีวภาพ',
            'category': 'Stationary Combustion - Biomass',
            'category_th': 'การเผาไหม้แบบนิ่ง - ชีวมวล'
        },
        'biogas_co2': {
            'name': 'Biogas (CO₂ only)',
            'name_th': 'ก๊าซชีวภาพ (รวม CO₂)',
            'unit': 'm³',
            'unit_th': 'ลม.',
            'factor': 1.1428,
            'notes': 'Includes biogenic CO₂',
            'notes_th': 'รวมคาร์บอนไดออกไซด์จากชีวภาพ',
            'category': 'Stationary Combustion - Biomass',
            'category_th': 'การเผาไหม้แบบนิ่ง - ชีวมวล'
        },
    }

    # Mobile Combustion - On Road Vehicles
    scope1_mobile_on_road = {
        'motor_gasoline_uncontrolled': {
            'name': 'Motor Gasoline - Uncontrolled',
            'name_th': 'น้ำมันเบนซิน - ไม่มีระบบควบคุม',
            'unit': 'litre',
            'unit_th': 'ลิตร',
            'factor': 2.2394,
            'notes': '',
            'notes_th': '',
            'category': 'Mobile Combustion - On Road Vehicles',
            'category_th': 'การเผาไหม้เคลื่อนที่ - ยานพาหนะบนถนน'
        },
        'motor_gasoline_catalyst': {
            'name': 'Motor Gasoline - Oxidation Catalyst',
            'name_th': 'น้ำมันเบนซิน - ตัวเร่งปฏิกิริยาออกซิเดชัน',
            'unit': 'litre',
            'unit_th': 'ลิตร',
            'factor': 2.2719,
            'notes': '',
            'notes_th': '',
            'category': 'Mobile Combustion - On Road Vehicles',
            'category_th': 'การเผาไหม้เคลื่อนที่ - ยานพาหนะบนถนน'
        },
        'motor_gasoline_low_mileage': {
            'name': 'Motor Gasoline - Low Mileage Light Duty (1995+)',
            'name_th': 'น้ำมันเบนซิน - รถเบา ไมล์น้อย (1995+)',
            'unit': 'litre',
            'unit_th': 'ลิตร',
            'factor': 2.2327,
            'notes': '',
            'notes_th': '',
            'category': 'Mobile Combustion - On Road Vehicles',
            'category_th': 'การเผาไหม้เคลื่อนที่ - ยานพาหนะบนถนน'
        },
        'gas_diesel_oil_mobile': {
            'name': 'Gas/Diesel Oil',
            'name_th': 'น้ำมันดีเซล',
            'unit': 'litre',
            'unit_th': 'ลิตร',
            'factor': 2.7406,
            'notes': '',
            'notes_th': '',
            'category': 'Mobile Combustion - On Road Vehicles',
            'category_th': 'การเผาไหม้เคลื่อนที่ - ยานพาหนะบนถนน'
        },
        'cng': {
            'name': 'Compressed Natural Gas (CNG)',
            'name_th': 'ก๊าซธรรมชาติอัด (ซีเอ็นจี)',
            'unit': 'kg',
            'unit_th': 'กก.',
            'factor': 2.2609,
            'notes': '',
            'notes_th': '',
            'category': 'Mobile Combustion - On Road Vehicles',
            'category_th': 'การเผาไหม้เคลื่อนที่ - ยานพาหนะบนถนน'
        },
        'lpg_mobile_litre': {
            'name': 'LPG - Mobile',
            'name_th': 'แอลพีจี - ยานพาหนะ',
            'unit': 'litre',
            'unit_th': 'ลิตร',
            'factor': 1.7306,
            'notes': '',
            'notes_th': '',
            'category': 'Mobile Combustion - On Road Vehicles',
            'category_th': 'การเผาไหม้เคลื่อนที่ - ยานพาหนะบนถนน'
        },
        'lpg_mobile_kg': {
            'name': 'LPG - Mobile',
            'name_th': 'แอลพีจี - ยานพาหนะ',
            'unit': 'kg',
            'unit_th': 'กก.',
            'factor': 3.2049,
            'notes': '1 litre = 0.54 kg',
            'notes_th': '1 ลิตร = 0.54 กิโลกรัม',
            'category': 'Mobile Combustion - On Road Vehicles',
            'category_th': 'การเผาไหม้เคลื่อนที่ - ยานพาหนะบนถนน'
        },
    }

    # Mobile Combustion - Off Road Equipment (Diesel)
    scope1_mobile_off_road_diesel = {
        'diesel_agriculture': {
            'name': 'Agriculture Equipment',
            'name_th': 'เครื่องจักรกลการเกษตร',
            'unit': 'litre',
            'unit_th': 'ลิตร',
            'factor': 2.9793,
            'notes': '',
            'notes_th': '',
            'category': 'Mobile Combustion - Off Road Equipment (Diesel)',
            'category_th': 'การเผาไหม้เคลื่อนที่ - เครื่องจักรนอกถนน (ดีเซล)'
        },
        'diesel_forestry': {
            'name': 'Forestry Equipment',
            'name_th': 'เครื่องจักรป่าไม้',
            'unit': 'litre',
            'unit_th': 'ลิตร',
            'factor': 2.9793,
            'notes': '',
            'notes_th': '',
            'category': 'Mobile Combustion - Off Road Equipment (Diesel)',
            'category_th': 'การเผาไหม้เคลื่อนที่ - เครื่องจักรนอกถนน (ดีเซล)'
        },
        'diesel_industrial': {
            'name': 'Industrial Equipment',
            'name_th': 'เครื่องจักรอุตสาหกรรม',
            'unit': 'litre',
            'unit_th': 'ลิตร',
            'factor': 2.9793,
            'notes': '',
            'notes_th': '',
            'category': 'Mobile Combustion - Off Road Equipment (Diesel)',
            'category_th': 'การเผาไหม้เคลื่อนที่ - เครื่องจักรนอกถนน (ดีเซล)'
        },
        'diesel_household': {
            'name': 'Household Equipment',
            'name_th': 'เครื่องจักรในครัวเรือน',
            'unit': 'litre',
            'unit_th': 'ลิตร',
            'factor': 2.9793,
            'notes': '',
            'notes_th': '',
            'category': 'Mobile Combustion - Off Road Equipment (Diesel)',
            'category_th': 'การเผาไหม้เคลื่อนที่ - เครื่องจักรนอกถนน (ดีเซล)'
        },
    }

    # Mobile Combustion - Off Road Equipment (Gasoline 4-Stroke)
    scope1_mobile_off_road_gasoline_4s = {
        'gasoline_4s_agriculture': {
            'name': 'Agriculture Equipment',
            'name_th': 'เครื่องจักรกลการเกษตร',
            'unit': 'litre',
            'unit_th': 'ลิตร',
            'factor': 2.2738,
            'notes': '',
            'notes_th': '',
            'category': 'Mobile Combustion - Off Road Equipment (Gasoline 4-Stroke)',
            'category_th': 'การเผาไหม้เคลื่อนที่ - เครื่องจักรนอกถนน (เบนซิน 4 จังหวะ)'
        },
        'gasoline_4s_forestry': {
            'name': 'Forestry Equipment',
            'name_th': 'เครื่องจักรป่าไม้',
            'unit': 'litre',
            'unit_th': 'ลิตร',
            'factor': 2.1816,
            'notes': '',
            'notes_th': '',
            'category': 'Mobile Combustion - Off Road Equipment (Gasoline 4-Stroke)',
            'category_th': 'การเผาไหม้เคลื่อนที่ - เครื่องจักรนอกถนน (เบนซิน 4 จังหวะ)'
        },
        'gasoline_4s_industrial': {
            'name': 'Industrial Equipment',
            'name_th': 'เครื่องจักรอุตสาหกรรม',
            'unit': 'litre',
            'unit_th': 'ลิตร',
            'factor': 2.2455,
            'notes': '',
            'notes_th': '',
            'category': 'Mobile Combustion - Off Road Equipment (Gasoline 4-Stroke)',
            'category_th': 'การเผาไหม้เคลื่อนที่ - เครื่องจักรนอกถนน (เบนซิน 4 จังหวะ)'
        },
        'gasoline_4s_household': {
            'name': 'Household Equipment',
            'name_th': 'เครื่องจักรในครัวเรือน',
            'unit': 'litre',
            'unit_th': 'ลิตร',
            'factor': 2.3116,
            'notes': '',
            'notes_th': '',
            'category': 'Mobile Combustion - Off Road Equipment (Gasoline 4-Stroke)',
            'category_th': 'การเผาไหม้เคลื่อนที่ - เครื่องจักรนอกถนน (เบนซิน 4 จังหวะ)'
        },
    }

    # Mobile Combustion - Off Road Equipment (Gasoline 2-Stroke)
    scope1_mobile_off_road_gasoline_2s = {
        'gasoline_2s_agriculture': {
            'name': 'Agriculture Equipment',
            'name_th': 'เครื่องจักรกลการเกษตร',
            'unit': 'litre',
            'unit_th': 'ลิตร',
            'factor': 2.3171,
            'notes': '',
            'notes_th': '',
            'category': 'Mobile Combustion - Off Road Equipment (Gasoline 2-Stroke)',
            'category_th': 'การเผาไหม้เคลื่อนที่ - เครื่องจักรนอกถนน (เบนซิน 2 จังหวะ)'
        },
        'gasoline_2s_forestry': {
            'name': 'Forestry Equipment',
            'name_th': 'เครื่องจักรป่าไม้',
            'unit': 'litre',
            'unit_th': 'ลิตร',
            'factor': 2.3454,
            'notes': '',
            'notes_th': '',
            'category': 'Mobile Combustion - Off Road Equipment (Gasoline 2-Stroke)',
            'category_th': 'การเผาไหม้เคลื่อนที่ - เครื่องจักรนอกถนน (เบนซิน 2 จังหวะ)'
        },
        'gasoline_2s_industrial': {
            'name': 'Industrial Equipment',
            'name_th': 'เครื่องจักรอุตสาหกรรม',
            'unit': 'litre',
            'unit_th': 'ลิตร',
            'factor': 2.3077,
            'notes': '',
            'notes_th': '',
            'category': 'Mobile Combustion - Off Road Equipment (Gasoline 2-Stroke)',
            'category_th': 'การเผาไหม้เคลื่อนที่ - เครื่องจักรนอกถนน (เบนซิน 2 จังหวะ)'
        },
        'gasoline_2s_household': {
            'name': 'Household Equipment',
            'name_th': 'เครื่องจักรในครัวเรือน',
            'unit': 'litre',
            'unit_th': 'ลิตร',
            'factor': 2.3549,
            'notes': '',
            'notes_th': '',
            'category': 'Mobile Combustion - Off Road Equipment (Gasoline 2-Stroke)',
            'category_th': 'การเผาไหม้เคลื่อนที่ - เครื่องจักรนอกถนน (เบนซิน 2 จังหวะ)'
        },
    }

    # Fugitive Emissions - Refrigerants
    scope1_refrigerants = {
        'r22': {
            'name': 'R-22 (HCFC-22)',
            'name_th': 'สารทำความเย็น R-22 (HCFC-22)',
            'unit': 'kg',
            'unit_th': 'กก.',
            'factor': 1760.0000,
            'notes': 'GWP: 1,760',
            'notes_th': 'ศักยภาพความร้อนโลก: 1,760',
            'category': 'Fugitive Emissions - Refrigerants',
            'category_th': 'การปล่อยรั่วไหล - สารทำความเย็น'
        },
        'r32': {
            'name': 'R-32',
            'name_th': 'สารทำความเย็น R-32',
            'unit': 'kg',
            'unit_th': 'กก.',
            'factor': 677.0000,
            'notes': 'GWP: 677',
            'notes_th': 'ศักยภาพความร้อนโลก: 677',
            'category': 'Fugitive Emissions - Refrigerants',
            'category_th': 'การปล่อยรั่วไหล - สารทำความเย็น'
        },
        'r125': {
            'name': 'R-125',
            'name_th': 'สารทำความเย็น R-125',
            'unit': 'kg',
            'unit_th': 'กก.',
            'factor': 3170.0000,
            'notes': 'GWP: 3,170',
            'notes_th': 'ศักยภาพความร้อนโลก: 3,170',
            'category': 'Fugitive Emissions - Refrigerants',
            'category_th': 'การปล่อยรั่วไหล - สารทำความเย็น'
        },
        'r134': {
            'name': 'R-134',
            'name_th': 'สารทำความเย็น R-134',
            'unit': 'kg',
            'unit_th': 'กก.',
            'factor': 1120.0000,
            'notes': 'GWP: 1,120',
            'notes_th': 'ศักยภาพความร้อนโลก: 1,120',
            'category': 'Fugitive Emissions - Refrigerants',
            'category_th': 'การปล่อยรั่วไหล - สารทำความเย็น'
        },
        'r134a': {
            'name': 'R-134a',
            'name_th': 'สารทำความเย็น R-134a',
            'unit': 'kg',
            'unit_th': 'กก.',
            'factor': 1300.0000,
            'notes': 'GWP: 1,300',
            'notes_th': 'ศักยภาพความร้อนโลก: 1,300',
            'category': 'Fugitive Emissions - Refrigerants',
            'category_th': 'การปล่อยรั่วไหล - สารทำความเย็น'
        },
        'r143': {
            'name': 'R-143',
            'name_th': 'สารทำความเย็น R-143',
            'unit': 'kg',
            'unit_th': 'กก.',
            'factor': 328.0000,
            'notes': 'GWP: 328',
            'notes_th': 'ศักยภาพความร้อนโลก: 328',
            'category': 'Fugitive Emissions - Refrigerants',
            'category_th': 'การปล่อยรั่วไหล - สารทำความเย็น'
        },
        'r143a': {
            'name': 'R-143a',
            'name_th': 'สารทำความเย็น R-143a',
            'unit': 'kg',
            'unit_th': 'กก.',
            'factor': 4800.0000,
            'notes': 'GWP: 4,800',
            'notes_th': 'ศักยภาพความร้อนโลก: 4,800',
            'category': 'Fugitive Emissions - Refrigerants',
            'category_th': 'การปล่อยรั่วไหล - สารทำความเย็น'
        },
    }

    # Combine all emission factors
    all_factors = {}
    all_factors.update(scope1_stationary_fossil)
    all_factors.update(scope1_stationary_biomass)
    all_factors.update(scope1_stationary_biomass_co2)
    all_factors.update(scope1_mobile_on_road)
    all_factors.update(scope1_mobile_off_road_diesel)
    all_factors.update(scope1_mobile_off_road_gasoline_4s)
    all_factors.update(scope1_mobile_off_road_gasoline_2s)
    all_factors.update(scope1_refrigerants)
    
    return all_factors

def update_bilingual_emission_factors():
    """Update MongoDB with bilingual TGO emission factors"""
    
    print("Starting bilingual TGO emission factors update...")
    print(f"Database: {db.name}")
    print(f"Collection: {emission_factors_collection.name}")
    
    # Get current count
    current_count = emission_factors_collection.count_documents({})
    print(f"Current emission factors in database: {current_count}")
    
    # Get bilingual TGO emission factors
    tgo_factors = get_bilingual_tgo_emission_factors()
    print(f"Bilingual TGO emission factors to process: {len(tgo_factors)}")
    
    # Clear existing factors
    print("\nClearing existing emission factors...")
    emission_factors_collection.delete_many({})
    print("Existing factors cleared.")
    
    # Insert new bilingual TGO factors
    print("\nInserting bilingual TGO emission factors...")
    inserted_count = 0
    
    for fuel_key, fuel_data in tgo_factors.items():
        # Create bilingual emission factor document
        emission_factor = {
            'factor_id': fuel_key.upper(),
            'fuel_key': fuel_key,
            'activity_type': fuel_data['name'].lower().replace(' ', '_').replace('(', '').replace(')', '').replace('-', '_'),
            
            # English fields
            'name': fuel_data['name'],
            'unit': fuel_data['unit'],
            'notes': fuel_data.get('notes', ''),
            'description': f"{fuel_data['name']} emission factor",
            'category': fuel_data['category'],
            
            # Thai fields
            'name_th': fuel_data.get('name_th', fuel_data['name']),
            'unit_th': fuel_data.get('unit_th', fuel_data['unit']),
            'notes_th': fuel_data.get('notes_th', fuel_data.get('notes', '')),
            'description_th': f"ตัวคูณการปล่อย {fuel_data.get('name_th', fuel_data['name'])}",
            'category_th': fuel_data.get('category_th', fuel_data['category']),
            
            # Common fields
            'value': fuel_data['factor'],
            'factor': fuel_data['factor'],
            'scope': 1 if 'Stationary' in fuel_data['category'] or 'Mobile' in fuel_data['category'] or 'Fugitive' in fuel_data['category'] else 2,
            'source': 'TGO Thailand',
            'source_date': 'April 2022',
            'created_at': datetime.utcnow(),
            'updated_at': datetime.utcnow(),
            'is_bilingual': True
        }
        
        # Add common activity types mapping
        if fuel_key == 'grid_electricity':
            emission_factor['activity_types'] = ['electricity', 'power', 'ไฟฟ้า']
        elif fuel_key == 'gas_diesel_oil' or fuel_key == 'gas_diesel_oil_mobile':
            emission_factor['activity_types'] = ['diesel', 'ดีเซล']
        elif fuel_key == 'motor_gasoline' or fuel_key == 'motor_gasoline_uncontrolled':
            emission_factor['activity_types'] = ['gasoline', 'petrol', 'เบนซิน']
        elif 'natural_gas' in fuel_key:
            emission_factor['activity_types'] = ['natural_gas', 'ก๊าซธรรมชาติ']
        elif 'lpg' in fuel_key:
            emission_factor['activity_types'] = ['lpg', 'แอลพีจี']
        
        # Insert the factor
        try:
            emission_factors_collection.insert_one(emission_factor)
            inserted_count += 1
            print(f"✓ Inserted: {fuel_data['name']} / {fuel_data.get('name_th', 'ไม่มี')} ({fuel_data['unit']}) = {fuel_data['factor']} kgCO₂eq/{fuel_data['unit']}")
        except Exception as e:
            print(f"✗ Error inserting {fuel_key}: {str(e)}")
    
    print(f"\n=== BILINGUAL UPDATE SUMMARY ===")
    print(f"Total factors processed: {len(tgo_factors)}")
    print(f"Successfully inserted: {inserted_count}")
    print(f"Errors: {len(tgo_factors) - inserted_count}")
    
    # Verify final count
    final_count = emission_factors_collection.count_documents({})
    print(f"Final emission factors in database: {final_count}")
    
    return {
        'success': True,
        'inserted': inserted_count,
        'total_factors': final_count
    }

if __name__ == '__main__':
    print("="*60)
    print("BILINGUAL TGO THAILAND EMISSION FACTORS UPDATE")
    print("="*60)
    print("This script will update MongoDB with bilingual")
    print("TGO Thailand emission factors (English/Thai)")
    print("="*60)
    
    try:
        # Test database connection
        db.command('ping')
        print("✓ Database connection successful")
        
        # Update emission factors with bilingual support
        result = update_bilingual_emission_factors()
        
        if result['success']:
            print(f"\n✓ Successfully updated bilingual emission factors!")
            print(f"  - Inserted: {result['inserted']} factors")
            print(f"  - Total factors: {result['total_factors']}")
            
        else:
            print(f"\n✗ Update failed!")
            
    except Exception as e:
        print(f"\n✗ Error: {str(e)}")
        import traceback
        traceback.print_exc()
