#!/usr/bin/env python3
"""
Complete bilingual TGO Thailand emission factors with ALL 49 factors
This includes all emission factors from the frontend TGO file with Thai translations
"""

from datetime import datetime
from models import emission_factors_collection, db
import json

def get_complete_bilingual_tgo_factors():
    """Get all 49 TGO emission factors with complete English and Thai translations"""
    
    # Scope 1: Direct Emissions - Stationary Combustion (Fossil Fuels) - 12 factors
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
            'category_th': 'การเผาไหม้แบบนิ่ง - เช
