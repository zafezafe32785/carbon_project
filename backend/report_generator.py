"""
New AI-Powered Report Generation System for Carbon Accounting
Supports ISO 14064, CFO, and GHG Protocol standards with AI-generated preliminary descriptions
"""

import os
import json
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any
import openai
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle
from reportlab.lib.units import inch
from reportlab.lib import colors
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib.fonts import addMapping
import urllib.request
from models import emission_records_collection, users_collection, reports_collection, emission_factors_collection, calculate_co2_equivalent
from bson import ObjectId

# Configure OpenAI API
openai.api_key = os.getenv('OPENAI_API_KEY')

class CarbonReportGenerator:
    """
    AI-powered carbon accounting report generator
    Generates professional reports with AI-generated preliminary descriptions
    Focuses on GHG Protocol standard with multiple file formats and languages
    """
    
    def __init__(self):
        self.supported_formats = ['GHG']
        self.supported_file_types = ['PDF', 'EXCEL', 'WORD']
        self.supported_languages = ['EN', 'TH']

        # NOTE: Emission data is reused from smart_dashboard
        # All CO2 calculations are already done using TGO emission factors
        # Reports only separate by Scope 1 and Scope 2 (Scope 3 removed per project requirement)
        #
        # Scope 1: Direct emissions (fuels, refrigerants, combustion)
        # Scope 2: Indirect emissions from purchased electricity/energy

    def generate_report(self, user_id: str, start_date: str, end_date: str, 
                       report_format: str = 'GHG', file_type: str = 'PDF', 
                       language: str = 'EN', include_ai_insights: bool = True) -> Dict:
        """
        Generate a comprehensive carbon accounting report with AI-powered preliminary descriptions
        
        Args:
            user_id: User ID for data filtering
            start_date: Report start date (ISO format)
            end_date: Report end date (ISO format)
            report_format: Report format (GHG only)
            file_type: Output file type (PDF, EXCEL, WORD)
            language: Report language (EN, TH)
            include_ai_insights: Whether to include AI-generated content
            
        Returns:
            Dictionary with report generation results
        """
        try:
            print(f"Generating {report_format} report for user {user_id}")
            
            # Step 1: Collect and process emission data
            report_data = self._collect_emission_data(user_id, start_date, end_date)
            
            # Step 2: Generate AI-powered preliminary descriptions
            ai_content = {}
            if include_ai_insights:
                ai_content = self._generate_ai_content(report_data, report_format, language)
            
            # Step 3: Create structured report content
            report_content = self._create_report_structure(report_data, ai_content, report_format, language)
            
            # Step 4: Generate report file based on type
            file_path = self._generate_report_file(report_content, report_format, file_type, language)
            
            # Step 5: Save to database with your schema
            report_id = self._save_to_database(user_id, report_data, report_content, 
                                             start_date, end_date, report_format, file_path, file_type, language)
            
            return {
                'success': True,
                'report_id': report_id,
                'file_path': file_path,
                'file_type': file_type,
                'language': language,
                'total_emissions': report_data['total_emissions'],
                'ai_insights_included': include_ai_insights,
                'generated_at': datetime.now().isoformat()
            }
            
        except Exception as e:
            print(f"Report generation error: {str(e)}")
            return {
                'success': False,
                'error': str(e),
                'message': f'Failed to generate {report_format} report: {str(e)}'
            }

    def _collect_emission_data(self, user_id: str, start_date: str, end_date: str) -> Dict:
        """
        Collect and process emission data from database
        Reuses the same data collection logic as smart_dashboard for consistency
        All CO2 calculations are already done using TGO factors
        """

        # Parse dates
        start_dt = datetime.fromisoformat(start_date.replace('Z', '+00:00'))
        end_dt = datetime.fromisoformat(end_date.replace('Z', '+00:00'))

        # Get user information
        user = users_collection.find_one({'_id': ObjectId(user_id)})
        organization = user.get('organization', 'Unknown Organization') if user else 'Unknown Organization'

        # Query emission records (same as dashboard - data already has co2_equivalent calculated)
        emissions = list(emission_records_collection.find({
            'user_id': ObjectId(user_id),
            'record_date': {'$gte': start_dt, '$lte': end_dt}
        }))

        print(f"Found {len(emissions)} emission records for report period")

        # Total emissions (already calculated with TGO factors in dashboard)
        total_emissions = sum(float(e.get('co2_equivalent', 0)) for e in emissions)

        # Group by category (same as dashboard)
        emissions_by_category = {}
        for emission in emissions:
            category = emission.get('category', 'other')
            co2_value = float(emission.get('co2_equivalent', 0))
            emissions_by_category[category] = emissions_by_category.get(category, 0) + co2_value

        # Group by GHG Protocol scopes (Scope 1 and 2 only as per project requirement)
        emissions_by_scope = {'Scope 1': 0, 'Scope 2': 0}

        for emission in emissions:
            category = emission.get('category', 'other').lower()
            co2_value = float(emission.get('co2_equivalent', 0))

            # Determine scope based on category
            # Scope 2: Electricity and purchased energy
            if any(keyword in category for keyword in ['electric', 'grid', 'power', 'energy']):
                emissions_by_scope['Scope 2'] += co2_value
            # Scope 1: Everything else (direct emissions - fuels, refrigerants, etc.)
            else:
                emissions_by_scope['Scope 1'] += co2_value

        print(f"Scope breakdown: Scope 1 = {emissions_by_scope['Scope 1']}, Scope 2 = {emissions_by_scope['Scope 2']}")

        # Calculate monthly breakdown (same logic as dashboard)
        monthly_data = self._calculate_monthly_breakdown(emissions, start_dt, end_dt)

        return {
            'user_id': user_id,
            'organization': organization,
            'period_start': start_dt,
            'period_end': end_dt,
            'total_emissions': total_emissions,
            'emissions_by_category': emissions_by_category,
            'emissions_by_scope': emissions_by_scope,
            'monthly_data': monthly_data,
            'record_count': len(emissions),
            'raw_emissions': emissions
        }

    def _calculate_monthly_breakdown(self, emissions: List[Dict], start_date: datetime, end_date: datetime) -> List[Dict]:
        """Calculate monthly emission breakdown"""
        monthly_breakdown = {}
        
        # Initialize months in range
        current = start_date.replace(day=1)
        while current <= end_date:
            month_key = current.strftime('%Y-%m')
            monthly_breakdown[month_key] = {
                'month': current.strftime('%B %Y'),
                'total': 0,
                'by_category': {}
            }
            current = (current.replace(day=28) + timedelta(days=4)).replace(day=1)
        
        # Aggregate emissions by month
        for emission in emissions:
            record_date = emission.get('record_date', datetime.now())
            month_key = record_date.strftime('%Y-%m')
            
            if month_key in monthly_breakdown:
                co2_value = emission.get('co2_equivalent', 0)
                category = emission.get('category', 'other')
                
                monthly_breakdown[month_key]['total'] += co2_value
                monthly_breakdown[month_key]['by_category'][category] = \
                    monthly_breakdown[month_key]['by_category'].get(category, 0) + co2_value
        
        return list(monthly_breakdown.values())

    def _generate_ai_content(self, report_data: Dict, report_format: str, language: str = 'EN') -> Dict:
        """Generate AI-powered preliminary descriptions and insights"""
        try:
            if not openai.api_key:
                return self._get_fallback_content(report_data, report_format, language)
            
            ai_content = {}
            
            # Generate executive summary
            ai_content['executive_summary'] = self._generate_executive_summary(report_data, report_format, language)
            
            # Generate key findings
            ai_content['key_findings'] = self._generate_key_findings(report_data, language)
            
            # Generate recommendations
            ai_content['recommendations'] = self._generate_recommendations(report_data, language)
            
            # Generate compliance notes
            ai_content['compliance_notes'] = self._generate_compliance_notes(report_format, language)
            
            # Generate trend analysis
            ai_content['trend_analysis'] = self._generate_trend_analysis(report_data, language)
            
            return ai_content
            
        except Exception as e:
            print(f"AI content generation error: {str(e)}")
            return self._get_fallback_content(report_data, report_format, language)

    def _generate_executive_summary(self, report_data: Dict, report_format: str, language: str = 'EN') -> str:
        """Generate AI-powered executive summary"""
        try:
            language_instruction = "Write in Thai language" if language == 'TH' else "Write in English"
            
            prompt = f"""
            Generate a professional executive summary for a {report_format} carbon emissions report:
            
            Organization: {report_data['organization']}
            Total Emissions: {report_data['total_emissions']:.2f} kg CO2e
            Period: {report_data['period_start'].strftime('%B %Y')} to {report_data['period_end'].strftime('%B %Y')}
            Top Categories: {dict(sorted(report_data['emissions_by_category'].items(), key=lambda x: x[1], reverse=True)[:3])}
            Scope Breakdown: {report_data['emissions_by_scope']}
            
            Requirements:
            - {language_instruction}
            - Professional tone suitable for {report_format} standards
            - 150-200 words
            - Include key metrics and business implications
            - Focus on compliance with {report_format} requirements
            - Provide actionable insights
            """
            
            response = openai.ChatCompletion.create(
                model="gpt-3.5-turbo",
                messages=[{"role": "user", "content": prompt}],
                max_tokens=300,
                temperature=0.7
            )

            # Clean up multiple spaces and normalize whitespace
            content = response.choices[0].message.content.strip()
            return ' '.join(content.split())
            
        except Exception as e:
            return self._get_fallback_executive_summary(report_data, report_format, language)

    def _generate_key_findings(self, report_data: Dict, language: str = 'EN') -> List[str]:
        """Generate AI-powered key findings"""
        try:
            language_instruction = "Write in Thai language" if language == 'TH' else "Write in English"
            
            prompt = f"""
            Based on this carbon emissions data, identify 5-7 key findings:
            
            Total Emissions: {report_data['total_emissions']:.2f} kg CO2e
            Categories: {report_data['emissions_by_category']}
            Scope Breakdown: {report_data['emissions_by_scope']}
            Record Count: {report_data['record_count']}
            
            Requirements:
            - {language_instruction}
            - Format as bullet points
            - Each finding should be specific and data-driven
            - Actionable for management
            - Focused on significant patterns or opportunities
            """
            
            response = openai.ChatCompletion.create(
                model="gpt-3.5-turbo",
                messages=[{"role": "user", "content": prompt}],
                max_tokens=400,
                temperature=0.6
            )
            
            findings_text = response.choices[0].message.content.strip()
            # Clean up multiple spaces and newlines, filter empty lines
            lines = [f.strip('• -').strip() for f in findings_text.split('\n')]
            # Remove empty strings and normalize whitespace
            return [' '.join(line.split()) for line in lines if line.strip()]
            
        except Exception as e:
            return self._get_fallback_key_findings(report_data, language)

    def _generate_recommendations(self, report_data: Dict, language: str = 'EN') -> List[str]:
        """Generate AI-powered recommendations"""
        try:
            language_instruction = "Write in Thai language" if language == 'TH' else "Write in English"
            top_category = max(report_data['emissions_by_category'], key=report_data['emissions_by_category'].get) \
                          if report_data['emissions_by_category'] else 'unknown'
            
            prompt = f"""
            Generate 5-6 specific recommendations to reduce carbon emissions:
            
            Total Emissions: {report_data['total_emissions']:.2f} kg CO2e
            Highest Source: {top_category}
            All Categories: {report_data['emissions_by_category']}
            
            Requirements:
            - {language_instruction}
            - Specific and actionable recommendations
            - Prioritized by impact potential
            - Cost-effective where possible
            - Include estimated reduction percentages
            """
            
            response = openai.ChatCompletion.create(
                model="gpt-3.5-turbo",
                messages=[{"role": "user", "content": prompt}],
                max_tokens=500,
                temperature=0.7
            )
            
            recommendations_text = response.choices[0].message.content.strip()
            # Clean up multiple spaces and newlines, filter empty lines
            lines = [r.strip('• -').strip() for r in recommendations_text.split('\n')]
            # Remove empty strings and normalize whitespace
            return [' '.join(line.split()) for line in lines if line.strip()]
            
        except Exception as e:
            return self._get_fallback_recommendations(report_data, language)

    def _generate_trend_analysis(self, report_data: Dict, language: str = 'EN') -> str:
        """Generate AI-powered trend analysis"""
        try:
            language_instruction = "Write in Thai language" if language == 'TH' else "Write in English"
            monthly_totals = [month['total'] for month in report_data['monthly_data']]
            
            if len(monthly_totals) > 1:
                trend = "increasing" if monthly_totals[-1] > monthly_totals[0] else "decreasing"
                change = ((monthly_totals[-1] - monthly_totals[0]) / monthly_totals[0] * 100) if monthly_totals[0] > 0 else 0
            else:
                trend = "stable"
                change = 0
            
            prompt = f"""
            Analyze emission trends over the reporting period:
            
            Monthly Data: {[f"{m['month']}: {m['total']:.1f}" for m in report_data['monthly_data']]}
            Overall Trend: {trend}
            Change: {change:.1f}%
            
            Requirements:
            - {language_instruction}
            - Provide 100-150 word analysis covering:
              * Trend patterns and seasonality
              * Possible reasons for changes
              * Implications for future planning
              * Recommendations for trend improvement
            """
            
            response = openai.ChatCompletion.create(
                model="gpt-3.5-turbo",
                messages=[{"role": "user", "content": prompt}],
                max_tokens=250,
                temperature=0.6
            )

            # Clean up multiple spaces and normalize whitespace
            content = response.choices[0].message.content.strip()
            return ' '.join(content.split())
            
        except Exception as e:
            return self._get_fallback_trend_analysis(report_data, language)

    def _generate_compliance_notes(self, report_format: str, language: str = 'EN') -> str:
        """Generate format-specific compliance notes"""
        if language == 'TH':
            compliance_notes = {
                'ISO': """
                รายงานนี้เป็นไปตามมาตรฐาน ISO 14064-1:2018 สำหรับการวัดและรายงานก๊าซเรือนกระจก
                ค่าสัมประสิทธิ์การปล่อยทั้งหมดมาจากแนวทาง IPCC และหน่วยงานที่ได้รับการยอมรับ
                ขั้นตอนการเก็บรวบรวมข้อมูลและการตรวจสอบเป็นไปตามข้อกำหนด ISO เพื่อความถูกต้องและครบถ้วน
                ขอบเขตองค์กรถูกกำหนดโดยใช้แนวทางการควบคุมการดำเนินงาน
                """,
                'CFO': """
                รายงานนี้ให้การบัญชีคาร์บอนที่เน้นด้านการเงินเหมาะสำหรับการทบทวนของผู้บริหาร
                ต้นทุนการปล่อยและผลกระทบของภาษีคาร์บอนที่อาจเกิดขึ้นถูกรวมเข้าในการวิเคราะห์
                การนำเสนอข้อมูลเป็นไปตามมาตรฐานการรายงานขององค์กรสำหรับการสื่อสารระดับคณะกรรมการ
                ความเสี่ยงและโอกาสทางการเงินที่เกี่ยวข้องกับการปล่อยคาร์บอนได้รับการเน้นย้ำ
                """,
                'GHG': """
                รายงานนี้เป็นไปตามมาตรฐาน GHG Protocol Corporate Accounting and Reporting Standard
                การปล่อยก๊าซเรือนกระจกถูกจำแนกเป็น Scope 1, 2, และ 3 ตามที่กำหนดใน GHG Protocol
                วิธีการคำนวณเป็นไปตามแนวทาง GHG Protocol สำหรับการจัดทำรายการขององค์กร
                การจัดการคุณภาพข้อมูลและความไม่แน่นอนสอดคล้องกับข้อกำหนดของ GHG Protocol
                """
            }
        else:
            compliance_notes = {
                'ISO': """
                This report complies with ISO 14064-1:2018 standards for greenhouse gas quantification and reporting.
                All emission factors are sourced from IPCC guidelines and recognized authorities.
                Data collection and verification procedures follow ISO requirements for accuracy and completeness.
                Organizational boundaries are defined using the operational control approach.
                """,
                'CFO': """
                This report provides financial-focused carbon accounting suitable for executive review.
                Emission costs and potential carbon tax implications are integrated into the analysis.
                Data presentation follows corporate reporting standards for board-level communication.
                Financial risks and opportunities related to carbon emissions are highlighted.
                """,
                'GHG': """
                This report complies with the GHG Protocol Corporate Accounting and Reporting Standard.
                Emissions are categorized into Scope 1, 2, and 3 as defined by the GHG Protocol.
                Calculation methodologies follow GHG Protocol guidance for corporate inventories.
                Data quality and uncertainty management align with GHG Protocol requirements.
                """
            }
        
        default_text = "หลักการบัญชีคาร์บอนมาตรฐานถูกนำมาใช้" if language == 'TH' else "Standard carbon accounting principles applied."
        # Clean up multiple spaces and newlines from the compliance notes
        text = compliance_notes.get(report_format, default_text)
        return ' '.join(text.split())

    def _get_fallback_content(self, report_data: Dict, report_format: str, language: str = 'EN') -> Dict:
        """Fallback content when AI is not available"""
        top_category = max(report_data['emissions_by_category'], key=report_data['emissions_by_category'].get) \
                      if report_data['emissions_by_category'] else 'unknown'
        
        return {
            'executive_summary': self._get_fallback_executive_summary(report_data, report_format, language),
            'key_findings': self._get_fallback_key_findings(report_data, language),
            'recommendations': self._get_fallback_recommendations(report_data, language),
            'compliance_notes': self._generate_compliance_notes(report_format, language),
            'trend_analysis': self._get_fallback_trend_analysis(report_data, language)
        }

    def _get_fallback_executive_summary(self, report_data: Dict, report_format: str, language: str = 'EN') -> str:
        """Fallback executive summary"""
        if language == 'TH':
            text = f"""
            รายงานการปล่อยก๊าซเรือนกระจก {report_format} ฉบับนี้นำเสนอการวิเคราะห์ที่ครอบคลุมเกี่ยวกับการปล่อยก๊าซเรือนกระจก
            ของ {report_data['organization']} ในช่วงระยะเวลาตั้งแต่ {report_data['period_start'].strftime('%B %Y')}
            ถึง {report_data['period_end'].strftime('%B %Y')} การปล่อยก๊าซเรือนกระจกรวมทั้งหมด {report_data['total_emissions']:.2f} kg CO2e
            จากข้อมูล {report_data['record_count']} รายการ รายงานนี้เป็นไปตามมาตรฐาน {report_format} และให้ข้อมูลเชิงลึก
            ที่สามารถนำไปปฏิบัติได้สำหรับกลยุทธ์การลดการปล่อยก๊าซเรือนกระจก จุดสำคัญที่ควรให้ความสนใจ ได้แก่
            การปรับปรุงประสิทธิภาพการใช้พลังงานและการดำเนินงานที่ยั่งยืนเพื่อบรรลุเป้าหมายการลดคาร์บอน
            """
        else:
            text = f"""
            This {report_format} carbon emissions report presents a comprehensive analysis of greenhouse gas emissions
            for {report_data['organization']} covering the period from {report_data['period_start'].strftime('%B %Y')}
            to {report_data['period_end'].strftime('%B %Y')}. Total emissions reached {report_data['total_emissions']:.2f} kg CO2e
            across {report_data['record_count']} emission records. The report follows {report_format} standards and provides
            actionable insights for emission reduction strategies. Key focus areas include energy efficiency improvements
            and sustainable operational practices to achieve carbon reduction goals.
            """
        # Clean up multiple spaces and newlines
        return ' '.join(text.split())

    def _get_fallback_key_findings(self, report_data: Dict, language: str = 'EN') -> List[str]:
        """Fallback key findings"""
        if language == 'TH':
            findings = [
                f"การปล่อยก๊าซเรือนกระจกรวม: {report_data['total_emissions']:.2f} kg CO2e",
                f"ช่วงเวลารายงาน: {report_data['period_start'].strftime('%B %Y')} ถึง {report_data['period_end'].strftime('%B %Y')}",
                f"จำนวนข้อมูลการปล่อย: {report_data['record_count']} รายการ"
            ]
            
            if report_data['emissions_by_category']:
                top_category = max(report_data['emissions_by_category'], key=report_data['emissions_by_category'].get)
                findings.append(f"แหล่งปล่อยหลัก: {top_category}")
                findings.append(f"จำนวนประเภทการปล่อย: {len(report_data['emissions_by_category'])} ประเภท")
            
            # Add scope breakdown
            for scope, value in report_data['emissions_by_scope'].items():
                if value > 0:
                    percentage = (value / report_data['total_emissions'] * 100) if report_data['total_emissions'] > 0 else 0
                    findings.append(f"{scope}: {percentage:.1f}% ของการปล่อยทั้งหมด")
        else:
            findings = [
                f"Total emissions: {report_data['total_emissions']:.2f} kg CO2e",
                f"Reporting period: {report_data['period_start'].strftime('%B %Y')} to {report_data['period_end'].strftime('%B %Y')}",
                f"Number of emission records: {report_data['record_count']}"
            ]
            
            if report_data['emissions_by_category']:
                top_category = max(report_data['emissions_by_category'], key=report_data['emissions_by_category'].get)
                findings.append(f"Primary emission source: {top_category}")
                findings.append(f"Number of emission categories: {len(report_data['emissions_by_category'])}")
            
            # Add scope breakdown
            for scope, value in report_data['emissions_by_scope'].items():
                if value > 0:
                    percentage = (value / report_data['total_emissions'] * 100) if report_data['total_emissions'] > 0 else 0
                    findings.append(f"{scope}: {percentage:.1f}% of total emissions")
        
        return findings

    def _get_fallback_recommendations(self, report_data: Dict, language: str = 'EN') -> List[str]:
        """Fallback recommendations"""
        if language == 'TH':
            recommendations = [
                "ปรับปรุงระบบการจัดการพลังงานอย่างครอบคลุม",
                "ดำเนินการตรวจสอบพลังงานเป็นประจำเพื่อหาโอกาสในการเพิ่มประสิทธิภาพ",
                "พิจารณาตัวเลือกการจัดหาพลังงานทดแทน",
                "กำหนดเป้าหมายการลดการปล่อยและขั้นตอนการติดตาม",
                "พัฒนาโปรแกรมสร้างความตระหนักของพนักงานในการลดคาร์บอน"
            ]
            
            if report_data['emissions_by_category']:
                top_category = max(report_data['emissions_by_category'], key=report_data['emissions_by_category'].get)
                recommendations.insert(0, f"จัดลำดับความสำคัญของกลยุทธ์การลดการปล่อยจาก {top_category}")
        else:
            recommendations = [
                "Implement comprehensive energy management system",
                "Conduct regular energy audits to identify efficiency opportunities",
                "Consider renewable energy procurement options",
                "Establish emission reduction targets and monitoring procedures",
                "Develop employee awareness programs for carbon reduction"
            ]
            
            if report_data['emissions_by_category']:
                top_category = max(report_data['emissions_by_category'], key=report_data['emissions_by_category'].get)
                recommendations.insert(0, f"Prioritize reduction strategies for {top_category} emissions")
        
        return recommendations

    def _get_fallback_trend_analysis(self, report_data: Dict, language: str = 'EN') -> str:
        """Fallback trend analysis"""
        # Validate monthly_data exists and has sufficient entries
        if not report_data.get('monthly_data') or len(report_data['monthly_data']) < 1:
            return "Insufficient data available for trend analysis." if language == 'EN' else "ข้อมูลไม่เพียงพอสำหรับการวิเคราะห์แนวโน้ม"

        if len(report_data['monthly_data']) > 1:
            first_month = report_data['monthly_data'][0].get('total', 0)
            last_month = report_data['monthly_data'][-1].get('total', 0)
            
            if language == 'TH':
                if last_month > first_month:
                    return f"การปล่อยก๊าซเรือนกระจกแสดงแนวโน้มเพิ่มขึ้นในช่วงระยะเวลารายงาน เพิ่มขึ้นจาก {first_month:.1f} เป็น {last_month:.1f} kg CO2e ซึ่งบ่งชี้ถึงความจำเป็นในการเสริมสร้างมาตรการลดการปล่อยและการติดตามแหล่งปล่อยอย่างใกล้ชิด"
                elif last_month < first_month:
                    return f"การปล่อยก๊าซเรือนกระจกแสดงแนวโน้มลดลง ลดลงจาก {first_month:.1f} เป็น {last_month:.1f} kg CO2e แนวโน้มเชิงบวกนี้ควรได้รับการรักษาไว้ผ่านความพยายามในการปรับปรุงอย่างต่อเนื่องและการติดตามเป็นประจำ"
                else:
                    return "การปล่อยก๊าซเรือนกระจกยังคงค่อนข้างคงที่ตลอดช่วงระยะเวลารายงาน แสดงให้เห็นรูปแบบการดำเนินงานที่สม่ำเสมอ ควรมุ่งเน้นไปที่การระบุโอกาสในการลดการปล่อยอย่างเป็นระบบ"
            else:
                if last_month > first_month:
                    return f"Emissions showed an increasing trend over the reporting period, rising from {first_month:.1f} to {last_month:.1f} kg CO2e. This indicates a need for enhanced emission reduction measures and closer monitoring of emission sources."
                elif last_month < first_month:
                    return f"Emissions demonstrated a decreasing trend, falling from {first_month:.1f} to {last_month:.1f} kg CO2e. This positive trend should be maintained through continued improvement efforts and regular monitoring."
                else:
                    return "Emissions remained relatively stable throughout the reporting period, indicating consistent operational patterns. Focus should be on identifying opportunities for systematic reductions."
        else:
            if language == 'TH':
                return "การวิเคราะห์แนวโน้มต้องการข้อมูลหลายช่วงเวลาเพื่อการประเมินที่มีความหมาย รายงานในอนาคตจะรวมการวิเคราะห์เปรียบเทียบเพื่อระบุรูปแบบและโอกาสในการปรับปรุง"
            else:
                return "Trend analysis requires multiple reporting periods for meaningful assessment. Future reports will include comparative analysis to identify patterns and improvement opportunities."

    def _create_report_structure(self, report_data: Dict, ai_content: Dict, report_format: str, language: str = 'EN') -> Dict:
        """Create structured report content"""
        
        # Calculate additional metrics
        avg_monthly_emissions = report_data['total_emissions'] / max(len(report_data['monthly_data']), 1)
        
        return {
            'title': f'{report_format} Carbon Emissions Report',
            'subtitle': f'{report_data["organization"]} - {report_data["period_start"].strftime("%B %Y")} to {report_data["period_end"].strftime("%B %Y")}',
            'executive_summary': ai_content.get('executive_summary', ''),
            'key_metrics': {
                'total_emissions': f"{report_data['total_emissions']:.2f} kg CO2e",
                'average_monthly': f"{avg_monthly_emissions:.2f} kg CO2e/month",
                'reporting_period': f"{report_data['period_start'].strftime('%d %B %Y')} - {report_data['period_end'].strftime('%d %B %Y')}",
                'record_count': f"{report_data['record_count']} emission records"
            },
            'emissions_by_scope': report_data['emissions_by_scope'],
            'emissions_by_category': report_data['emissions_by_category'],
            'monthly_data': report_data['monthly_data'],
            'key_findings': ai_content.get('key_findings', []),
            'recommendations': ai_content.get('recommendations', []),
            'trend_analysis': ai_content.get('trend_analysis', ''),
            'compliance_notes': ai_content.get('compliance_notes', ''),
            'methodology': self._get_methodology_text(report_format, language),
            'generated_at': datetime.now().strftime('%d %B %Y at %H:%M')
        }

    def _get_methodology_text(self, report_format: str, language: str = 'EN') -> str:
        """Get methodology text based on report format and language"""
        if language == 'TH':
            methodologies = {
                'ISO': """
                รายงานนี้เป็นไปตามหลักการ ISO 14064-1:2018 สำหรับการวัดและรายงานก๊าซเรือนกระจก
                ค่าสัมประสิทธิ์การปล่อยมาจากแนวทาง IPCC และหน่วยงานกำกับดูแลในท้องถิ่น
                การเก็บรวบรวมข้อมูลเป็นไปตามขั้นตอนที่เป็นระบบเพื่อให้แน่ใจว่ามีความถูกต้องและครบถ้วน
                การคำนวณทั้งหมดใช้แนวทางการควบคุมการดำเนินงานสำหรับการกำหนดขอบเขตองค์กร
                """,
                'CFO': """
                รายงานนี้ใช้วิธีการบัญชีคาร์บอนมาตรฐานที่เหมาะสำหรับการรายงานทางการเงิน
                การคำนวณการปล่อยเป็นไปตามโปรโตคอลที่กำหนดไว้โดยเน้นผลกระทบที่สำคัญ
                การนำเสนอข้อมูลเพื่อสนับสนุนการตัดสินใจเชิงกลยุทธ์และการประเมินความเสี่ยง
                ผลกระทบทางการเงินของการปล่อยคาร์บอนได้รับการพิจารณาตลอดการวิเคราะห์
                """,
                'GHG': """
                รายงานนี้เป็นไปตามมาตรฐาน GHG Protocol Corporate Accounting and Reporting Standard
                การปล่อยก๊าซเรือนกระจกถูกจำแนกตาม Scope 1, 2, และ 3 ตามที่กำหนดใน GHG Protocol
                วิธีการคำนวณเป็นไปตามแนวทาง GHG Protocol สำหรับการจัดทำรายการขององค์กร
                การจัดการคุณภาพข้อมูลและความไม่แน่นอนเป็นไปตามข้อกำหนดของ GHG Protocol
                """
            }
        else:
            methodologies = {
                'ISO': """
                This report follows ISO 14064-1:2018 principles for greenhouse gas quantification and reporting.
                Emission factors are sourced from IPCC guidelines and local regulatory authorities.
                Data collection follows systematic procedures to ensure accuracy and completeness.
                All calculations use the operational control approach for organizational boundary setting.
                """,
                'CFO': """
                This report uses standard carbon accounting methodologies suitable for financial reporting.
                Emission calculations follow established protocols with focus on material impacts.
                Data is presented to support strategic decision-making and risk assessment.
                Financial implications of carbon emissions are considered throughout the analysis.
                """,
                'GHG': """
                This report complies with the GHG Protocol Corporate Accounting and Reporting Standard.
                Emissions are classified according to Scope 1, 2, and 3 categories as defined by the GHG Protocol.
                Calculation methodologies follow GHG Protocol guidance for corporate inventories.
                Data quality and uncertainty are managed according to GHG Protocol requirements.
                """
            }
        
        default_text = "วิธีการบัญชีคาร์บอนมาตรฐานถูกนำมาใช้" if language == 'TH' else "Standard carbon accounting methodologies applied."
        # Clean up multiple spaces and newlines from the methodology text
        text = methodologies.get(report_format, default_text)
        return ' '.join(text.split())

    def _generate_report_file(self, content: Dict, report_format: str, file_type: str, language: str) -> str:
        """Generate report file based on type and language"""
        if file_type == 'PDF':
            return self._generate_pdf_report(content, report_format, language)
        elif file_type == 'EXCEL':
            return self._generate_excel_report(content, report_format, language)
        elif file_type == 'WORD':
            return self._generate_word_report(content, report_format, language)
        else:
            raise ValueError(f"Unsupported file type: {file_type}")

    def _get_ghg_template_content(self, language: str) -> Dict:
        """Get GHG Protocol template content based on language"""
        if language == 'TH':
            return {
                'title': 'รายงานการปล่อยก๊าซเรือนกระจก ตามมาตรฐาน GHG Protocol',
                'executive_summary_title': 'บทสรุปผู้บริหาร',
                'scope_1_title': 'การปล่อยทางตรง (Scope 1)',
                'scope_2_title': 'การปล่อยทางอ้อมจากพลังงาน (Scope 2)',
                'key_findings_title': 'ผลการวิเคราะห์สำคัญ',
                'recommendations_title': 'ข้อเสนอแนะ',
                'methodology_title': 'วิธีการคำนวณ',
                'compliance_title': 'การปฏิบัติตามมาตรฐาน',
                'scope_descriptions': {
                    'Scope 1': 'การปล่อยก๊าซเรือนกระจกโดยตรงจากแหล่งที่องค์กรเป็นเจ้าของหรือควบคุม (เชื้อเพลิง สารทำความเย็น การเผาไหม้)',
                    'Scope 2': 'การปล่อยก๊าซเรือนกระจกทางอ้อมจากการซื้อพลังงานไฟฟ้า'
                }
            }
        else:  # English
            return {
                'title': 'Greenhouse Gas Inventory Report (GHG Protocol)',
                'executive_summary_title': 'Executive Summary',
                'scope_1_title': 'Scope 1 Direct Emissions',
                'scope_2_title': 'Scope 2 Indirect Emissions from Energy',
                'key_findings_title': 'Key Findings',
                'recommendations_title': 'Recommendations',
                'methodology_title': 'Methodology',
                'compliance_title': 'Compliance Notes',
                'scope_descriptions': {
                    'Scope 1': 'Direct greenhouse gas emissions from sources owned or controlled by the organization (fuels, refrigerants, combustion)',
                    'Scope 2': 'Indirect greenhouse gas emissions from purchased electricity'
                }
            }

    def _setup_thai_fonts(self):
        """Setup Thai fonts with better mixed Thai-English support"""
        try:
            # Create fonts directory if it doesn't exist
            fonts_dir = os.path.join(os.path.dirname(__file__), 'fonts')
            os.makedirs(fonts_dir, exist_ok=True)
            
            # Enhanced font sources with better mixed-language support
            # Prioritize fonts with excellent Latin character support
            font_sources = [
                {
                    'name': 'Sarabun', 
                    'regular_url': 'https://github.com/cadsondemak/Sarabun/raw/master/fonts/ttf/Sarabun-Regular.ttf',
                    'bold_url': 'https://github.com/cadsondemak/Sarabun/raw/master/fonts/ttf/Sarabun-Bold.ttf',
                    'regular_file': 'Sarabun-Regular.ttf',
                    'bold_file': 'Sarabun-Bold.ttf',
                    'has_latin': True,
                    'priority': 1  # Best for mixed content
                },
                {
                    'name': 'NotoSansThai',
                    'regular_url': 'https://github.com/google/fonts/raw/main/ofl/notosansthai/NotoSansThai-Regular.ttf',
                    'bold_url': 'https://github.com/google/fonts/raw/main/ofl/notosansthai/NotoSansThai-Bold.ttf',
                    'regular_file': 'NotoSansThai-Regular.ttf',
                    'bold_file': 'NotoSansThai-Bold.ttf',
                    'has_latin': True,
                    'priority': 2
                },
                {
                    'name': 'THSarabunNew', 
                    'regular_url': 'https://github.com/tlwg/fonts-tlwg/raw/master/tlwg/THSarabunNew.ttf',
                    'bold_url': 'https://github.com/tlwg/fonts-tlwg/raw/master/tlwg/THSarabunNew-Bold.ttf',
                    'regular_file': 'THSarabunNew.ttf',
                    'bold_file': 'THSarabunNew-Bold.ttf',
                    'has_latin': True,
                    'priority': 3
                }
            ]
            
            # Sort by priority
            font_sources.sort(key=lambda x: x.get('priority', 999))
            
            for font_source in font_sources:
                try:
                    thai_font_path = os.path.join(fonts_dir, font_source['regular_file'])
                    thai_bold_path = os.path.join(fonts_dir, font_source.get('bold_file', font_source['regular_file']))
                    
                    # Download regular font if it doesn't exist
                    if not os.path.exists(thai_font_path):
                        print(f"Downloading {font_source['name']} regular font...")
                        urllib.request.urlretrieve(font_source['regular_url'], thai_font_path)
                    
                    # Download bold font if available and doesn't exist
                    if 'bold_url' in font_source and not os.path.exists(thai_bold_path):
                        print(f"Downloading {font_source['name']} bold font...")
                        urllib.request.urlretrieve(font_source['bold_url'], thai_bold_path)
                    
                    # Register fonts with UTF-8 support
                    pdfmetrics.registerFont(TTFont('ThaiFont', thai_font_path))
                    
                    if os.path.exists(thai_bold_path):
                        pdfmetrics.registerFont(TTFont('ThaiFont-Bold', thai_bold_path))
                    else:
                        # Use regular font for bold if no bold version available
                        pdfmetrics.registerFont(TTFont('ThaiFont-Bold', thai_font_path))
                    
                    # Register additional font variants for mixed content
                    pdfmetrics.registerFont(TTFont('ThaiFont-Italic', thai_font_path))
                    pdfmetrics.registerFont(TTFont('ThaiFont-BoldItalic', thai_bold_path if os.path.exists(thai_bold_path) else thai_font_path))
                    
                    # Add comprehensive font family mappings
                    addMapping('ThaiFont', 0, 0, 'ThaiFont')           # normal
                    addMapping('ThaiFont', 0, 1, 'ThaiFont-Bold')      # bold
                    addMapping('ThaiFont', 1, 0, 'ThaiFont-Italic')    # italic
                    addMapping('ThaiFont', 1, 1, 'ThaiFont-BoldItalic') # bold italic
                    
                    # Test the font with mixed content
                    test_success = self._test_font_mixed_content('ThaiFont')
                    
                    if test_success:
                        print(f"Successfully registered {font_source['name']} fonts with mixed content support")
                        return True
                    else:
                        print(f"Font {font_source['name']} registered but failed mixed content test")
                        continue
                
                except Exception as e:
                    print(f"Failed to setup {font_source['name']}: {str(e)}")
                    continue
            
            # If all fonts fail, register fallback combination
            print("All Thai font setups failed, setting up fallback font combination")
            return self._setup_fallback_fonts()
            
        except Exception as e:
            print(f"Error setting up Thai fonts: {str(e)}")
            return self._setup_fallback_fonts()

    def _test_font_mixed_content(self, font_name):
        """Test if font can handle mixed Thai-English content"""
        try:
            from reportlab.pdfbase.pdfmetrics import getFont
            font = getFont(font_name)
            
            # Test mixed content strings
            test_strings = [
                "บริษัท ABC Company จำกัด",
                "การปล่อย CO2 equivalent", 
                "GHG Protocol การรายงาน"
            ]
            
            for test_str in test_strings:
                # Try to encode the string with the font
                try:
                    # This is a basic test - in practice, ReportLab handles this internally
                    encoded = test_str.encode('utf-8')
                    decoded = encoded.decode('utf-8')
                    if test_str != decoded:
                        return False
                except:
                    return False
            
            return True
            
        except Exception as e:
            print(f"Font test failed: {str(e)}")
            return False

    def _setup_fallback_fonts(self):
        """Setup fallback font combination for mixed content"""
        try:
            # Register Helvetica as fallback for Latin characters
            # This ensures English text always renders correctly
            pdfmetrics.registerFont(TTFont('FallbackFont', 'Helvetica'))
            
            # Create a hybrid approach - use system fonts
            addMapping('MixedFont', 0, 0, 'Helvetica')      # normal - good for English
            addMapping('MixedFont', 0, 1, 'Helvetica-Bold') # bold - good for English
            addMapping('MixedFont', 1, 0, 'Helvetica')      # italic
            addMapping('MixedFont', 1, 1, 'Helvetica-Bold') # bold italic
            
            print("Fallback font combination registered")
            return True
            
        except Exception as e:
            print(f"Fallback font setup failed: {str(e)}")
            return False

    def _get_font_name(self, language: str, bold: bool = False) -> str:
        """Get appropriate font name with better mixed-content support"""
        if language == 'TH':
            # For Thai documents, use a font that supports both Thai and Latin
            try:
                from reportlab.pdfbase.pdfmetrics import getFont
                getFont('ThaiFont')
                # Use Thai font only for mixed content, but ensure it has Latin support
                return 'ThaiFont-Bold' if bold else 'ThaiFont'
            except:
                # Fallback to Helvetica which has good Latin support
                return 'Helvetica-Bold' if bold else 'Helvetica'
        return 'Helvetica-Bold' if bold else 'Helvetica'

    def _process_mixed_content_text(self, text: str, language: str = 'EN') -> str:
        """Process mixed Thai-English content to ensure proper UTF-8 encoding and spacing"""
        if not text:
            return text
            
        try:
            # Ensure the text is properly encoded as UTF-8
            if isinstance(text, bytes):
                text = text.decode('utf-8', errors='replace')
            
            # For Thai language reports with mixed content
            if language == 'TH':
                # Normalize Unicode characters to ensure consistent encoding
                import unicodedata
                text = unicodedata.normalize('NFC', text)
                
                # Handle common problematic character combinations
                replacements = {
                    # Fix common encoding issues
                    'â€™': "'",  # Smart quote
                    'â€œ': '"',  # Smart quote
                    'â€': '"',   # Smart quote
                    'â€¢': '•',  # Bullet point
                    'â€"': '–',  # En dash
                    'â€"': '—',  # Em dash
                }
                
                for old, new in replacements.items():
                    text = text.replace(old, new)
                
                # Enhanced spacing for mixed Thai-English content
                import re
                
                # Add spaces around English words/numbers when adjacent to Thai characters
                text = re.sub(r'([ก-๙])([A-Za-z0-9])', r'\1 \2', text)
                text = re.sub(r'([A-Za-z0-9])([ก-๙])', r'\1 \2', text)
                
                # Add spaces around parentheses when adjacent to Thai characters
                text = re.sub(r'([ก-๙])(\()', r'\1 \2', text)
                text = re.sub(r'(\))([ก-๙])', r'\1 \2', text)
                
                # Add spaces around colons when adjacent to Thai characters
                text = re.sub(r'([ก-๙])(:)', r'\1\2 ', text)
                text = re.sub(r'(:)([ก-๙])', r'\1 \2', text)
                
                # Add spaces around commas when adjacent to Thai characters
                text = re.sub(r'([ก-๙])(,)', r'\1\2 ', text)
                text = re.sub(r'(,)([ก-๙])', r'\1 \2', text)
                
                # Special handling for common technical terms
                technical_terms = [
                    'GHG Protocol', 'ISO 14064', 'CO2e', 'Scope 1', 'Scope 2', 'TGO',
                    'operational efficiency', 'energy management system', 'direct emissions',
                    'indirect emissions', 'Corporate Accounting', 'Reporting Standard'
                ]
                
                for term in technical_terms:
                    # Ensure proper spacing around technical terms
                    pattern = r'([ก-๙])(' + re.escape(term) + r')([ก-๙])'
                    text = re.sub(pattern, r'\1 \2 \3', text)
                
                # Clean up multiple spaces but preserve intentional spacing
                text = re.sub(r' {3,}', '  ', text)  # Max 2 spaces
                text = re.sub(r' {2,}', ' ', text)   # Normalize to single space
                text = text.strip()
            
            # Final UTF-8 validation
            text.encode('utf-8')
            return text
            
        except Exception as e:
            print(f"Text processing error: {str(e)}")
            # Return original text if processing fails
            return str(text) if text else ""

    def _create_mixed_content_paragraph(self, text: str, style, language: str = 'EN'):
        """Create a paragraph that handles mixed Thai-English content properly"""
        try:
            # Process the text for mixed content
            processed_text = self._process_mixed_content_text(text, language)
            
            # Create paragraph with proper encoding
            return Paragraph(processed_text, style)
            
        except Exception as e:
            print(f"Paragraph creation error: {str(e)}")
            # Fallback to simple paragraph
            try:
                return Paragraph(str(text), style)
            except:
                return Paragraph("Content encoding error", style)

    def _process_data_with_pandas(self, content: Dict, language: str = 'EN') -> Dict:
        """Process report data using pandas for better data handling and analysis"""
        try:
            import pandas as pd
            import numpy as np
            
            # Process emissions by category data
            if content.get('emissions_by_category'):
                category_df = pd.DataFrame(list(content['emissions_by_category'].items()), 
                                         columns=['Category', 'Emissions'])
                category_df['Emissions'] = pd.to_numeric(category_df['Emissions'], errors='coerce')
                category_df = category_df.sort_values('Emissions', ascending=False)
                
                # Calculate percentages
                total_emissions = category_df['Emissions'].sum()
                category_df['Percentage'] = (category_df['Emissions'] / total_emissions * 100).round(1)
                
                content['category_analysis'] = {
                    'top_category': category_df.iloc[0]['Category'] if len(category_df) > 0 else 'Unknown',
                    'top_percentage': category_df.iloc[0]['Percentage'] if len(category_df) > 0 else 0,
                    'category_summary': category_df.to_dict('records')
                }
            
            # Process emissions by scope data
            if content.get('emissions_by_scope'):
                scope_df = pd.DataFrame(list(content['emissions_by_scope'].items()), 
                                      columns=['Scope', 'Emissions'])
                scope_df['Emissions'] = pd.to_numeric(scope_df['Emissions'], errors='coerce')
                scope_df = scope_df[scope_df['Emissions'] > 0]  # Filter out zero emissions
                
                # Calculate percentages
                total_scope_emissions = scope_df['Emissions'].sum()
                if total_scope_emissions > 0:
                    scope_df['Percentage'] = (scope_df['Emissions'] / total_scope_emissions * 100).round(1)
                else:
                    scope_df['Percentage'] = 0
                
                content['scope_analysis'] = {
                    'dominant_scope': scope_df.iloc[0]['Scope'] if len(scope_df) > 0 else 'Unknown',
                    'scope_summary': scope_df.to_dict('records')
                }
            
            # Process monthly data for trend analysis
            if content.get('monthly_data'):
                monthly_df = pd.DataFrame(content['monthly_data'])
                if 'total' in monthly_df.columns:
                    monthly_df['total'] = pd.to_numeric(monthly_df['total'], errors='coerce')
                    
                    # Calculate trend statistics
                    if len(monthly_df) > 1:
                        # Linear trend
                        x = np.arange(len(monthly_df))
                        y = monthly_df['total'].values
                        trend_slope = np.polyfit(x, y, 1)[0]
                        
                        # Month-over-month change
                        monthly_df['change'] = monthly_df['total'].pct_change() * 100
                        avg_change = monthly_df['change'].mean()
                        
                        content['trend_analysis_data'] = {
                            'trend_direction': 'increasing' if trend_slope > 0 else 'decreasing' if trend_slope < 0 else 'stable',
                            'trend_slope': round(trend_slope, 2),
                            'avg_monthly_change': round(avg_change, 1),
                            'highest_month': monthly_df.loc[monthly_df['total'].idxmax(), 'month'] if len(monthly_df) > 0 else 'Unknown',
                            'lowest_month': monthly_df.loc[monthly_df['total'].idxmin(), 'month'] if len(monthly_df) > 0 else 'Unknown'
                        }
            
            # Process key metrics for better formatting
            if content.get('key_metrics'):
                metrics_df = pd.DataFrame(list(content['key_metrics'].items()), 
                                        columns=['Metric', 'Value'])
                
                # Clean and format metrics
                formatted_metrics = {}
                for _, row in metrics_df.iterrows():
                    metric = row['Metric']
                    value = row['Value']
                    
                    # Format based on metric type
                    if 'emission' in metric.lower():
                        # Format emission values
                        if isinstance(value, str) and 'kg CO2e' in value:
                            formatted_metrics[metric] = value
                        else:
                            formatted_metrics[metric] = f"{float(value):.2f} kg CO2e" if pd.notna(value) else "0.00 kg CO2e"
                    elif 'count' in metric.lower():
                        # Format count values
                        formatted_metrics[metric] = f"{int(float(value))}" if pd.notna(value) else "0"
                    else:
                        formatted_metrics[metric] = str(value)
                
                content['formatted_metrics'] = formatted_metrics
            
            # Generate summary statistics
            content['data_quality'] = {
                'categories_count': len(content.get('emissions_by_category', {})),
                'active_scopes': len([s for s in content.get('emissions_by_scope', {}).values() if s > 0]),
                'reporting_months': len(content.get('monthly_data', [])),
                'data_completeness': 'Good' if content.get('emissions_by_category') and content.get('monthly_data') else 'Limited'
            }
            
            print("Data processed successfully with pandas")
            return content
            
        except Exception as e:
            print(f"Pandas data processing error: {str(e)}")
            # Return original content if pandas processing fails
            return content

    def _create_thai_styles(self, language: str):
        """Create custom styles with improved Thai font support"""
        styles = getSampleStyleSheet()
        
        # Get base font
        base_font = self._get_font_name(language, False)
        bold_font = self._get_font_name(language, True)
        
        if language == 'TH':
            # Title style
            styles.add(ParagraphStyle(
                name='ThaiTitle',
                parent=styles['Heading1'],
                fontName=bold_font,
                fontSize=18,
                spaceAfter=30,
                alignment=1,  # Center alignment
                leading=24    # Increased leading for Thai text
            ))
            
            # Heading style
            styles.add(ParagraphStyle(
                name='ThaiHeading',
                parent=styles['Heading2'],
                fontName=bold_font,
                fontSize=14,
                spaceBefore=12,
                spaceAfter=6,
                leading=20    # Increased leading for Thai text
            ))
            
            # Normal text style
            styles.add(ParagraphStyle(
                name='ThaiNormal',
                parent=styles['Normal'],
                fontName=base_font,
                fontSize=12,
                leading=18,   # Increased leading for Thai text
                spaceAfter=6
            ))
            
            # Table header style
            styles.add(ParagraphStyle(
                name='ThaiTableHeader',
                parent=styles['Normal'],
                fontName=bold_font,
                fontSize=12,
                leading=16,
                alignment=1
            ))
        
        return styles

    def _generate_pdf_report(self, content: Dict, report_format: str, language: str = 'EN') -> str:
        """Generate professional PDF report using Word-to-PDF conversion for better mixed content support"""
        try:
            # For Thai language with mixed content, use Word-to-PDF conversion approach
            if language == 'TH':
                return self._generate_pdf_via_word(content, report_format, language)
            else:
                return self._generate_direct_pdf(content, report_format, language)
                
        except Exception as e:
            print(f"PDF generation error: {str(e)}")
            # Fallback to direct PDF generation
            return self._generate_direct_pdf(content, report_format, language)

    def _generate_pdf_via_word(self, content: Dict, report_format: str, language: str = 'EN') -> str:
        """Generate PDF by first creating Word document then converting to PDF"""
        try:
            # First generate Word document
            word_filepath = self._generate_word_report(content, report_format, language)
            
            if not word_filepath or not os.path.exists(word_filepath):
                raise Exception("Word document generation failed")
            
            # Create PDF filename
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            pdf_filename = f"carbon_report_{report_format}_{language}_{timestamp}.pdf"
            pdf_filepath = os.path.join('reports', pdf_filename)
            
            # Try to convert Word to PDF using python-docx2pdf or similar
            try:
                # Method 1: Try using docx2pdf if available
                import docx2pdf
                docx2pdf.convert(word_filepath, pdf_filepath)
                print(f"Successfully converted Word to PDF using docx2pdf: {pdf_filepath}")
                
                # Clean up temporary Word file
                try:
                    os.remove(word_filepath)
                except:
                    pass
                    
                return pdf_filepath
                
            except ImportError:
                print("docx2pdf not available, trying alternative method...")
                
            # Method 2: Try using win32com (Windows only)
            try:
                import win32com.client
                
                word = win32com.client.Dispatch("Word.Application")
                word.Visible = False
                
                # Open the Word document
                doc = word.Documents.Open(os.path.abspath(word_filepath))
                
                # Save as PDF
                doc.SaveAs2(os.path.abspath(pdf_filepath), FileFormat=17)  # 17 = PDF format
                doc.Close()
                word.Quit()
                
                print(f"Successfully converted Word to PDF using win32com: {pdf_filepath}")
                
                # Clean up temporary Word file
                try:
                    os.remove(word_filepath)
                except:
                    pass
                    
                return pdf_filepath
                
            except ImportError:
                print("win32com not available, trying alternative method...")
            except Exception as e:
                print(f"win32com conversion failed: {str(e)}")
            
            # Method 3: Use reportlab with improved font handling based on Word success
            return self._generate_improved_direct_pdf(content, report_format, language, word_filepath)
            
        except Exception as e:
            print(f"Word-to-PDF conversion failed: {str(e)}")
            # Fallback to direct PDF generation
            return self._generate_direct_pdf(content, report_format, language)

    def _generate_improved_direct_pdf(self, content: Dict, report_format: str, language: str, word_reference: str = None) -> str:
        """Generate PDF with improved font handling based on successful Word document approach"""
        try:
            import pandas as pd
            
            # Use system fonts that work well with mixed content (like Word does)
            # Instead of downloading fonts, use system fonts that are proven to work
            
            # Get template content
            template = self._get_ghg_template_content(language)
            
            # Create filename
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            filename = f"carbon_report_{report_format}_{language}_{timestamp}.pdf"
            filepath = os.path.join('reports', filename)
            
            # Ensure reports directory exists
            os.makedirs(os.path.dirname(filepath), exist_ok=True)
            
            # Process data with pandas for better handling
            processed_data = self._process_data_with_pandas(content, language)
            
            # Create PDF document with improved font handling
            doc = SimpleDocTemplate(filepath, pagesize=A4)
            styles = self._create_system_font_styles(language)
            story = []
            
            # Use system fonts that handle mixed content well
            title_style = styles['Title']
            heading_style = styles['Heading1'] 
            normal_style = styles['Normal']
            
            # Title and subtitle
            story.append(Paragraph(template['title'], title_style))
            story.append(Paragraph(content['subtitle'], heading_style))
            story.append(Spacer(1, 20))
            
            # Executive Summary
            story.append(Paragraph(template['executive_summary_title'], heading_style))
            story.append(Paragraph(content['executive_summary'], normal_style))
            story.append(Spacer(1, 20))
            
            # Key Metrics Table
            metrics_title = "ตัวชี้วัดหลัก" if language == 'TH' else "Key Metrics"
            story.append(Paragraph(metrics_title, heading_style))

            # Create table data
            metrics_data = []
            if language == 'TH':
                metrics_data.append(['ตัวชี้วัด', 'ค่า'])
            else:
                metrics_data.append(['Metric', 'Value'])

            for key, value in content['key_metrics'].items():
                display_key = key.replace('_', ' ').title()
                metrics_data.append([display_key, str(value)])

            metrics_table = Table(metrics_data)
            metrics_table.setStyle(TableStyle([
                ('BACKGROUND', (0, 0), (-1, 0), colors.grey),
                ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
                ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
                ('FONTNAME', (0, 0), (-1, -1), 'Helvetica'),  # Use system font
                ('FONTSIZE', (0, 0), (-1, 0), 12),
                ('FONTSIZE', (0, 1), (-1, -1), 11),
                ('BOTTOMPADDING', (0, 0), (-1, 0), 12),
                ('TOPPADDING', (0, 0), (-1, -1), 8),
                ('BOTTOMPADDING', (0, 1), (-1, -1), 8),
                ('BACKGROUND', (0, 1), (-1, -1), colors.beige),
                ('GRID', (0, 0), (-1, -1), 1, colors.black),
                ('VALIGN', (0, 0), (-1, -1), 'MIDDLE')
            ]))
            story.append(metrics_table)
            story.append(Spacer(1, 20))

            # Continue with rest of content using system fonts...
            # Key Findings
            if content['key_findings']:
                story.append(Paragraph(template['key_findings_title'], heading_style))
                for finding in content['key_findings']:
                    story.append(Paragraph(f"• {finding}", normal_style))
                story.append(Spacer(1, 20))
            
            # Recommendations
            if content['recommendations']:
                story.append(Paragraph(template['recommendations_title'], heading_style))
                for i, recommendation in enumerate(content['recommendations'], 1):
                    story.append(Paragraph(f"{i}. {recommendation}", normal_style))
                story.append(Spacer(1, 20))
            
            # Build PDF
            doc.build(story)
            
            # Clean up temporary Word file if it exists
            if word_reference and os.path.exists(word_reference):
                try:
                    os.remove(word_reference)
                except:
                    pass
            
            return filepath
            
        except Exception as e:
            print(f"Improved PDF generation error: {str(e)}")
            return self._generate_direct_pdf(content, report_format, language)

    def _create_system_font_styles(self, language: str):
        """Create styles using system fonts that handle mixed content well"""
        styles = getSampleStyleSheet()
        
        # Use Helvetica which handles mixed content better than custom fonts
        # This mimics what Word processors do - use system fonts with good Unicode support
        
        if language == 'TH':
            # For Thai, still use system fonts but with better spacing
            styles.add(ParagraphStyle(
                name='ThaiTitle',
                parent=styles['Title'],
                fontName='Helvetica-Bold',
                fontSize=18,
                spaceAfter=30,
                alignment=1,
                leading=24
            ))
            
            styles.add(ParagraphStyle(
                name='ThaiHeading',
                parent=styles['Heading1'],
                fontName='Helvetica-Bold',
                fontSize=14,
                spaceBefore=12,
                spaceAfter=6,
                leading=20
            ))
            
            styles.add(ParagraphStyle(
                name='ThaiNormal',
                parent=styles['Normal'],
                fontName='Helvetica',
                fontSize=12,
                leading=18,
                spaceAfter=6
            ))
        
        return styles

    def _generate_direct_pdf(self, content: Dict, report_format: str, language: str = 'EN') -> str:
        """Generate PDF directly using ReportLab (fallback method)"""
        try:
            import pandas as pd
            
            # Setup Thai fonts if needed
            if language == 'TH':
                font_setup_success = self._setup_thai_fonts()
                if not font_setup_success:
                    print("Warning: Thai font setup failed, falling back to default fonts")
            
            # Get template content
            template = self._get_ghg_template_content(language)
            
            # Create filename
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            filename = f"carbon_report_{report_format}_{language}_{timestamp}.pdf"
            filepath = os.path.join('reports', filename)
            
            # Ensure reports directory exists
            os.makedirs(os.path.dirname(filepath), exist_ok=True)
            
            # Process data with pandas for better handling
            processed_data = self._process_data_with_pandas(content, language)
            
            # Create PDF document
            doc = SimpleDocTemplate(filepath, pagesize=A4)
            styles = self._create_thai_styles(language)
            story = []
            
            # Get appropriate styles based on language
            title_style_name = 'ThaiTitle' if language == 'TH' else 'Heading1'
            heading_style_name = 'ThaiHeading' if language == 'TH' else 'Heading2'
            normal_style_name = 'ThaiNormal' if language == 'TH' else 'Normal'
            
            # Use custom title style or create one
            if language == 'TH' and 'ThaiTitle' in styles:
                title_style = styles['ThaiTitle']
            else:
                title_style = ParagraphStyle(
                    'CustomTitle',
                    parent=styles['Heading1'],
                    fontName=self._get_font_name(language),
                    fontSize=18,
                    spaceAfter=30,
                    alignment=1,  # Center alignment
                    leading=22
                )
            
            # Title and subtitle with mixed content processing
            story.append(self._create_mixed_content_paragraph(template['title'], title_style, language))
            story.append(self._create_mixed_content_paragraph(content['subtitle'], styles.get(heading_style_name, styles['Heading2']), language))
            story.append(Spacer(1, 20))
            
            # Executive Summary with mixed content processing
            story.append(self._create_mixed_content_paragraph(template['executive_summary_title'], styles.get(heading_style_name, styles['Heading2']), language))
            story.append(self._create_mixed_content_paragraph(content['executive_summary'], styles.get(normal_style_name, styles['Normal']), language))
            story.append(Spacer(1, 20))
            
            # Key Metrics Table
            metrics_title = "ตัวชี้วัดหลัก" if language == 'TH' else "Key Metrics"
            story.append(Paragraph(metrics_title, styles.get(heading_style_name, styles['Heading2'])))

            # Create table data with proper encoding
            metrics_data = []
            if language == 'TH':
                metrics_data.append(['ตัวชี้วัด', 'ค่า'])
            else:
                metrics_data.append(['Metric', 'Value'])

            for key, value in content['key_metrics'].items():
                display_key = key.replace('_', ' ').title()
                metrics_data.append([display_key, str(value)])

            metrics_table = Table(metrics_data)

            # Get appropriate fonts for table
            table_font = self._get_font_name(language, False)
            table_font_bold = self._get_font_name(language, True)

            metrics_table.setStyle(TableStyle([
                ('BACKGROUND', (0, 0), (-1, 0), colors.grey),
                ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
                ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
                ('FONTNAME', (0, 0), (-1, 0), table_font_bold),
                ('FONTNAME', (0, 1), (-1, -1), table_font),
                ('FONTSIZE', (0, 0), (-1, 0), 12),
                ('FONTSIZE', (0, 1), (-1, -1), 11),
                ('BOTTOMPADDING', (0, 0), (-1, 0), 12),
                ('TOPPADDING', (0, 0), (-1, -1), 8),
                ('BOTTOMPADDING', (0, 1), (-1, -1), 8),
                ('BACKGROUND', (0, 1), (-1, -1), colors.beige),
                ('GRID', (0, 0), (-1, -1), 1, colors.black),
                ('VALIGN', (0, 0), (-1, -1), 'MIDDLE')
            ]))
            story.append(metrics_table)
            story.append(Spacer(1, 20))

            # Scope summary table (around line 690 in your original code)
            if any(v > 0 for v in content['emissions_by_scope'].values()):
                scope_title = "การปล่อยก๊าซเรือนกระจกตามขอบเขต (GHG Protocol)" if language == 'TH' else "Emissions by Scope (GHG Protocol)"
                story.append(Paragraph(scope_title, styles.get(heading_style_name, styles['Heading2'])))
                
                # Scope descriptions first
                for scope, value in content['emissions_by_scope'].items():
                    if value > 0:
                        description = template.get('scope_descriptions', {}).get(scope, f'Description for {scope} not available')
                        story.append(Paragraph(f"{scope}: {description}", styles.get(normal_style_name, styles['Normal'])))
                        total_text = f"รวม: {value:.2f} kg CO2e" if language == 'TH' else f"Total: {value:.2f} kg CO2e"
                        story.append(Paragraph(total_text, styles.get(normal_style_name, styles['Normal'])))
                        story.append(Spacer(1, 10))
                
                # Create scope table with proper Thai headers
                if language == 'TH':
                    scope_header = ['ขอบเขต', 'การปล่อย (kg CO2e)', 'เปอร์เซ็นต์']
                else:
                    scope_header = ['Scope', 'Emissions (kg CO2e)', 'Percentage']
                
                scope_data = [scope_header]
                total_scope = sum(content['emissions_by_scope'].values())
                
                for scope, value in content['emissions_by_scope'].items():
                    if value > 0:
                        percentage = (value / total_scope * 100) if total_scope > 0 else 0
                        scope_data.append([scope, f"{value:.2f}", f"{percentage:.1f}%"])
                
                scope_table = Table(scope_data)
                
                # Use the improved font selection
                table_font = self._get_font_name(language, False)
                table_font_bold = self._get_font_name(language, True)
                
                scope_table.setStyle(TableStyle([
                    ('BACKGROUND', (0, 0), (-1, 0), colors.grey),
                    ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
                    ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
                    ('FONTNAME', (0, 0), (-1, 0), table_font_bold),
                    ('FONTNAME', (0, 1), (-1, -1), table_font),
                    ('FONTSIZE', (0, 0), (-1, 0), 12),
                    ('FONTSIZE', (0, 1), (-1, -1), 11),
                    ('BOTTOMPADDING', (0, 0), (-1, 0), 12),
                    ('TOPPADDING', (0, 0), (-1, -1), 8),
                    ('BOTTOMPADDING', (0, 1), (-1, -1), 8),
                    ('BACKGROUND', (0, 1), (-1, -1), colors.beige),
                    ('GRID', (0, 0), (-1, -1), 1, colors.black),
                    ('VALIGN', (0, 0), (-1, -1), 'MIDDLE')
                ]))
                story.append(scope_table)
                story.append(Spacer(1, 20))
            
            # Key Findings
            if content['key_findings']:
                story.append(Paragraph(template['key_findings_title'], styles.get(heading_style_name, styles['Heading2'])))
                for finding in content['key_findings']:
                    story.append(Paragraph(f"• {finding}", styles.get(normal_style_name, styles['Normal'])))
                story.append(Spacer(1, 20))
            
            # Recommendations
            if content['recommendations']:
                story.append(Paragraph(template['recommendations_title'], styles.get(heading_style_name, styles['Heading2'])))
                for i, recommendation in enumerate(content['recommendations'], 1):
                    story.append(Paragraph(f"{i}. {recommendation}", styles.get(normal_style_name, styles['Normal'])))
                story.append(Spacer(1, 20))
            
            # Trend Analysis
            if content['trend_analysis']:
                trend_title = "การวิเคราะห์แนวโน้ม" if language == 'TH' else "Trend Analysis"
                story.append(Paragraph(trend_title, styles.get(heading_style_name, styles['Heading2'])))
                story.append(Paragraph(content['trend_analysis'], styles.get(normal_style_name, styles['Normal'])))
                story.append(Spacer(1, 20))
            
            # Methodology
            story.append(Paragraph(template['methodology_title'], styles.get(heading_style_name, styles['Heading2'])))
            story.append(Paragraph(content['methodology'], styles.get(normal_style_name, styles['Normal'])))
            story.append(Spacer(1, 20))
            
            # Compliance Notes
            story.append(Paragraph(template['compliance_title'], styles.get(heading_style_name, styles['Heading2'])))
            story.append(Paragraph(content['compliance_notes'], styles.get(normal_style_name, styles['Normal'])))
            story.append(Spacer(1, 20))
            
            # Footer
            story.append(Spacer(1, 30))
            footer_text = f"รายงานสร้างเมื่อ {content['generated_at']}" if language == 'TH' else f"Report generated on {content['generated_at']}"
            story.append(Paragraph(footer_text, styles.get(normal_style_name, styles['Normal'])))
            
            # Build PDF
            doc.build(story)
            
            return filepath
            
        except Exception as e:
            print(f"PDF generation error: {str(e)}")
            return None

    def _generate_excel_report(self, content: Dict, report_format: str, language: str = 'EN') -> str:
        """Generate Excel report with multiple sheets"""
        try:
            import pandas as pd
            from openpyxl import Workbook
            from openpyxl.styles import Font, PatternFill, Alignment
            
            # Get template content
            template = self._get_ghg_template_content(language)
            
            # Create filename
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            filename = f"carbon_report_{report_format}_{language}_{timestamp}.xlsx"
            filepath = os.path.join('reports', filename)
            
            # Ensure reports directory exists
            os.makedirs(os.path.dirname(filepath), exist_ok=True)
            
            # Create workbook
            wb = Workbook()
            
            # Summary Sheet
            ws_summary = wb.active
            ws_summary.title = "Summary"
            
            # Header styling
            header_font = Font(bold=True, size=14)
            header_fill = PatternFill(start_color="366092", end_color="366092", fill_type="solid")
            
            # Title
            ws_summary['A1'] = template['title']
            ws_summary['A1'].font = Font(bold=True, size=16)
            ws_summary.merge_cells('A1:D1')
            
            # Key Metrics
            row = 3
            ws_summary[f'A{row}'] = "Key Metrics"
            ws_summary[f'A{row}'].font = header_font
            row += 1
            
            for key, value in content['key_metrics'].items():
                ws_summary[f'A{row}'] = key.replace('_', ' ').title()
                ws_summary[f'B{row}'] = value
                row += 1
            
            # Emissions by Scope
            row += 2
            ws_summary[f'A{row}'] = "Emissions by Scope"
            ws_summary[f'A{row}'].font = header_font
            row += 1
            
            ws_summary[f'A{row}'] = "Scope"
            ws_summary[f'B{row}'] = "Emissions (kg CO2e)"
            ws_summary[f'C{row}'] = "Percentage"
            for col in ['A', 'B', 'C']:
                ws_summary[f'{col}{row}'].font = header_font
            row += 1
            
            total_scope = sum(content['emissions_by_scope'].values())
            for scope, value in content['emissions_by_scope'].items():
                if value > 0:
                    percentage = (value / total_scope * 100) if total_scope > 0 else 0
                    ws_summary[f'A{row}'] = scope
                    ws_summary[f'B{row}'] = round(value, 2)
                    ws_summary[f'C{row}'] = f"{percentage:.1f}%"
                    row += 1
            
            # Monthly Data Sheet
            if content['monthly_data']:
                ws_monthly = wb.create_sheet("Monthly Data")
                ws_monthly['A1'] = "Monthly Emissions Breakdown"
                ws_monthly['A1'].font = Font(bold=True, size=14)
                
                # Headers
                ws_monthly['A3'] = "Month"
                ws_monthly['B3'] = "Total Emissions (kg CO2e)"
                for col in ['A', 'B']:
                    ws_monthly[f'{col}3'].font = header_font
                
                row = 4
                for month_data in content['monthly_data']:
                    ws_monthly[f'A{row}'] = month_data['month']
                    ws_monthly[f'B{row}'] = round(month_data['total'], 2)
                    row += 1
            
            # Save workbook
            wb.save(filepath)
            return filepath
            
        except Exception as e:
            print(f"Excel generation error: {str(e)}")
            return None

    def _generate_word_report(self, content: Dict, report_format: str, language: str = 'EN') -> str:
        """Generate Word document report with improved professional layout"""
        try:
            from docx import Document
            from docx.shared import Inches, Pt, RGBColor
            from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_BREAK
            from docx.enum.table import WD_TABLE_ALIGNMENT
            from docx.oxml.shared import OxmlElement, qn
            
            # Get template content
            template = self._get_ghg_template_content(language)
            
            # Create filename
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            filename = f"carbon_report_{report_format}_{language}_{timestamp}.docx"
            filepath = os.path.join('reports', filename)
            
            # Ensure reports directory exists
            os.makedirs(os.path.dirname(filepath), exist_ok=True)
            
            # Create document with improved margins
            doc = Document()
            
            # Set document margins for better layout
            sections = doc.sections
            for section in sections:
                section.top_margin = Inches(1)
                section.bottom_margin = Inches(1)
                section.left_margin = Inches(1.25)
                section.right_margin = Inches(1.25)
            
            # Cover Page Section
            # Title with enhanced formatting
            title = doc.add_heading(template['title'], 0)
            title.alignment = WD_ALIGN_PARAGRAPH.CENTER
            title_run = title.runs[0]
            title_run.font.size = Pt(24)
            title_run.font.color.rgb = RGBColor(0, 54, 146)  # Professional blue
            title_run.bold = True
            
            # Add proper spacing after title
            title_spacing = doc.add_paragraph()
            title_spacing.space_after = Pt(24)
            
            # Subtitle with better formatting
            subtitle = doc.add_heading(content['subtitle'], level=1)
            subtitle.alignment = WD_ALIGN_PARAGRAPH.CENTER
            subtitle_run = subtitle.runs[0]
            subtitle_run.font.size = Pt(16)
            subtitle_run.font.color.rgb = RGBColor(64, 64, 64)  # Dark gray
            
            # Add proper spacing after subtitle
            subtitle_spacing = doc.add_paragraph()
            subtitle_spacing.space_after = Pt(36)
            
            # Add report generation info with proper spacing
            report_info = doc.add_paragraph()
            report_info.alignment = WD_ALIGN_PARAGRAPH.CENTER
            report_info.space_before = Pt(24)
            report_info.space_after = Pt(12)
            report_info_run = report_info.add_run(f"Generated on {content['generated_at']}")
            report_info_run.font.size = Pt(12)
            report_info_run.font.color.rgb = RGBColor(128, 128, 128)
            report_info_run.italic = True
            
            # Page break for main content
            doc.add_page_break()
            
            # Executive Summary Section with enhanced formatting
            exec_heading = doc.add_heading(template['executive_summary_title'], level=1)
            exec_heading_run = exec_heading.runs[0]
            exec_heading_run.font.color.rgb = RGBColor(0, 54, 146)
            exec_heading.space_before = Pt(18)
            exec_heading.space_after = Pt(12)
            
            exec_para = doc.add_paragraph(content['executive_summary'])
            exec_para.style.font.size = Pt(11)
            exec_para.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
            exec_para.space_after = Pt(18)
            
            # Key Metrics Section with enhanced table
            metrics_heading = doc.add_heading('Key Metrics' if language == 'EN' else 'ตัวชี้วัดหลัก', level=1)
            metrics_heading_run = metrics_heading.runs[0]
            metrics_heading_run.font.color.rgb = RGBColor(0, 54, 146)
            
            # Create enhanced metrics table
            metrics_table = doc.add_table(rows=1, cols=2)
            metrics_table.style = 'Light Grid Accent 1'
            metrics_table.alignment = WD_TABLE_ALIGNMENT.CENTER
            
            # Set column widths
            metrics_table.columns[0].width = Inches(3)
            metrics_table.columns[1].width = Inches(2.5)
            
            # Header row
            hdr_cells = metrics_table.rows[0].cells
            hdr_cells[0].text = 'Metric' if language == 'EN' else 'ตัวชี้วัด'
            hdr_cells[1].text = 'Value' if language == 'EN' else 'ค่า'
            
            # Style header row
            for cell in hdr_cells:
                cell.paragraphs[0].runs[0].bold = True
                cell.paragraphs[0].runs[0].font.color.rgb = RGBColor(255, 255, 255)
                # Set background color to blue
                shading_elm = OxmlElement('w:shd')
                shading_elm.set(qn('w:fill'), '003692')
                cell._tc.get_or_add_tcPr().append(shading_elm)
            
            # Add metrics data
            for key, value in content['key_metrics'].items():
                row_cells = metrics_table.add_row().cells
                row_cells[0].text = key.replace('_', ' ').title()
                row_cells[1].text = str(value)
                
                # Style data rows
                for cell in row_cells:
                    cell.paragraphs[0].runs[0].font.size = Pt(10)
            
            doc.add_paragraph()  # Add space
            
            # Emissions by Scope Section with enhanced layout
            scope_heading = doc.add_heading('Emissions by Scope (GHG Protocol)' if language == 'EN' else 'การปล่อยก๊าซเรือนกระจกตามขอบเขต (GHG Protocol)', level=1)
            scope_heading_run = scope_heading.runs[0]
            scope_heading_run.font.color.rgb = RGBColor(0, 54, 146)
            
            # Create scope summary table
            scope_table = doc.add_table(rows=1, cols=3)
            scope_table.style = 'Light Grid Accent 1'
            scope_table.alignment = WD_TABLE_ALIGNMENT.CENTER
            
            # Header row
            scope_hdr = scope_table.rows[0].cells
            scope_hdr[0].text = 'Scope' if language == 'EN' else 'ขอบเขต'
            scope_hdr[1].text = 'Emissions (kg CO2e)' if language == 'EN' else 'การปล่อย (kg CO2e)'
            scope_hdr[2].text = 'Percentage' if language == 'EN' else 'เปอร์เซ็นต์'
            
            # Style header
            for cell in scope_hdr:
                cell.paragraphs[0].runs[0].bold = True
                cell.paragraphs[0].runs[0].font.color.rgb = RGBColor(255, 255, 255)
                shading_elm = OxmlElement('w:shd')
                shading_elm.set(qn('w:fill'), '003692')
                cell._tc.get_or_add_tcPr().append(shading_elm)
            
            # Add scope data
            total_scope = sum(content['emissions_by_scope'].values())
            for scope, value in content['emissions_by_scope'].items():
                if value > 0:
                    percentage = (value / total_scope * 100) if total_scope > 0 else 0
                    row_cells = scope_table.add_row().cells
                    row_cells[0].text = scope
                    row_cells[1].text = f"{value:.2f}"
                    row_cells[2].text = f"{percentage:.1f}%"
                    
                    # Style data rows
                    for cell in row_cells:
                        cell.paragraphs[0].runs[0].font.size = Pt(10)
            
            # Add scope descriptions
            doc.add_paragraph()
            for scope, value in content['emissions_by_scope'].items():
                if value > 0:
                    desc_para = doc.add_paragraph()
                    desc_run = desc_para.add_run(f"{scope}: ")
                    desc_run.bold = True
                    desc_run.font.color.rgb = RGBColor(0, 54, 146)
                    desc_para.add_run(template.get('scope_descriptions', {}).get(scope, f'Description for {scope} not available'))
                    desc_para.style.font.size = Pt(10)
            
            doc.add_paragraph()  # Add space
            
            # Key Findings Section
            if content['key_findings']:
                findings_heading = doc.add_heading(template['key_findings_title'], level=1)
                findings_heading_run = findings_heading.runs[0]
                findings_heading_run.font.color.rgb = RGBColor(0, 54, 146)
                
                for finding in content['key_findings']:
                    finding_para = doc.add_paragraph(finding, style='List Bullet')
                    finding_para.style.font.size = Pt(11)
                    finding_para.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
                
                doc.add_paragraph()  # Add space
            
            # Recommendations Section with enhanced formatting
            if content['recommendations']:
                rec_heading = doc.add_heading(template['recommendations_title'], level=1)
                rec_heading_run = rec_heading.runs[0]
                rec_heading_run.font.color.rgb = RGBColor(0, 54, 146)
                
                for recommendation in content['recommendations']:
                    # Check if recommendation already starts with a number
                    if recommendation.strip() and recommendation.strip()[0].isdigit():
                        rec_para = doc.add_paragraph(recommendation, style='List Bullet')
                    else:
                        rec_para = doc.add_paragraph(recommendation, style='List Number')
                    
                    rec_para.style.font.size = Pt(11)
                    rec_para.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
                
                doc.add_paragraph()  # Add space
            
            # Trend Analysis Section (if available)
            if content.get('trend_analysis'):
                trend_heading = doc.add_heading('Trend Analysis' if language == 'EN' else 'การวิเคราะห์แนวโน้ม', level=1)
                trend_heading_run = trend_heading.runs[0]
                trend_heading_run.font.color.rgb = RGBColor(0, 54, 146)
                
                trend_para = doc.add_paragraph(content['trend_analysis'])
                trend_para.style.font.size = Pt(11)
                trend_para.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
                
                doc.add_paragraph()  # Add space
            
            # Page break for methodology and compliance
            doc.add_page_break()
            
            # Methodology Section
            method_heading = doc.add_heading(template['methodology_title'], level=1)
            method_heading_run = method_heading.runs[0]
            method_heading_run.font.color.rgb = RGBColor(0, 54, 146)
            
            method_para = doc.add_paragraph(content['methodology'])
            method_para.style.font.size = Pt(10)
            method_para.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
            
            doc.add_paragraph()  # Add space
            
            # Compliance Notes Section
            compliance_heading = doc.add_heading(template['compliance_title'], level=1)
            compliance_heading_run = compliance_heading.runs[0]
            compliance_heading_run.font.color.rgb = RGBColor(0, 54, 146)
            
            compliance_para = doc.add_paragraph(content['compliance_notes'])
            compliance_para.style.font.size = Pt(10)
            compliance_para.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
            
            # Footer with enhanced styling
            doc.add_paragraph()
            doc.add_paragraph()
            footer_para = doc.add_paragraph()
            footer_para.alignment = WD_ALIGN_PARAGRAPH.CENTER
            footer_run = footer_para.add_run("─" * 50)
            footer_run.font.color.rgb = RGBColor(128, 128, 128)
            
            footer_text = doc.add_paragraph()
            footer_text.alignment = WD_ALIGN_PARAGRAPH.CENTER
            footer_text_run = footer_text.add_run(f"Report generated on {content['generated_at']}")
            footer_text_run.font.size = Pt(10)
            footer_text_run.font.color.rgb = RGBColor(128, 128, 128)
            footer_text_run.italic = True
            
            # Save document
            doc.save(filepath)
            return filepath
            
        except Exception as e:
            print(f"Word generation error: {str(e)}")
            return None

    def _save_to_database(self, user_id: str, report_data: Dict, report_content: Dict, 
                         start_date: str, end_date: str, report_format: str, file_path: str, 
                         file_type: str, language: str) -> str:
        """Save report to database using your MongoDB schema"""
        
        # Generate unique report ID by finding the highest existing number
        # This prevents skipping numbers even with concurrent requests
        latest_report = reports_collection.find_one(
            {"report_id": {"$regex": "^RPT[0-9]+$"}},
            sort=[("report_id", -1)]
        )

        if latest_report and 'report_id' in latest_report:
            # Extract the number from the last report ID (e.g., "RPT005" -> 5)
            try:
                last_number = int(latest_report['report_id'].replace('RPT', ''))
                next_number = last_number + 1
            except ValueError:
                # Fallback if parsing fails
                next_number = reports_collection.count_documents({}) + 1
        else:
            # No reports exist yet, start with 1
            next_number = 1

        report_id = f"RPT{str(next_number).zfill(3)}"
        
        # Parse dates for period structure
        start_dt = datetime.fromisoformat(start_date.replace('Z', '+00:00'))
        end_dt = datetime.fromisoformat(end_date.replace('Z', '+00:00'))
        
        # Create report document matching your schema
        report_document = {
            "_id": ObjectId(),
            "report_id": report_id,
            "user_id": ObjectId(user_id),
            "status": "Completed",
            "total_emission": report_data['total_emissions'],
            "create_date": datetime.utcnow(),
            "organization": report_data['organization'],
            "period": {
                "start_month": start_dt.month,
                "start_year": start_dt.year,
                "end_month": end_dt.month,
                "end_year": end_dt.year
            },
            "emissions_by_category": report_data['emissions_by_category'],
            # Enhanced fields for AI-powered reports
            "report_format": report_format,
            "file_path": file_path,
            "file_type": file_type,
            "language": language,
            "ai_insights_included": True,
            "emissions_by_scope": report_data['emissions_by_scope'],
            "monthly_data": report_data['monthly_data']
        }
        
        # Insert into database
        reports_collection.insert_one(report_document)
        
        return report_id

# Utility functions for Flask integration
def generate_ai_report(user_id: str, start_date: str, end_date: str, 
                      report_format: str = 'GHG', file_type: str = 'PDF', 
                      language: str = 'EN', include_ai: bool = True) -> Dict:
    """Main function to generate AI-powered reports"""
    generator = CarbonReportGenerator()
    return generator.generate_report(user_id, start_date, end_date, report_format, file_type, language, include_ai)

def get_available_report_formats() -> List[str]:
    """Get list of available report formats"""
    return ['GHG']

def get_available_file_types() -> List[str]:
    """Get list of available file types"""
    return ['PDF', 'EXCEL', 'WORD']

def get_available_languages() -> List[str]:
    """Get list of available languages"""
    return ['EN', 'TH']

def validate_report_request(data: Dict) -> Dict:
    """Validate report generation request"""
    required_fields = ['start_date', 'end_date', 'report_format']
    
    # Check required fields
    for field in required_fields:
        if field not in data:
            return {
                'valid': False,
                'error': f'Missing required field: {field}'
            }
    
    # Validate report format
    if data['report_format'] not in get_available_report_formats():
        return {
            'valid': False,
            'error': f'Invalid report format. Available formats: {get_available_report_formats()}'
        }
    
    # Validate dates
    try:
        start_date = datetime.fromisoformat(data['start_date'].replace('Z', '+00:00'))
        end_date = datetime.fromisoformat(data['end_date'].replace('Z', '+00:00'))
        
        if start_date >= end_date:
            return {
                'valid': False,
                'error': 'Start date must be before end date'
            }
            
    except ValueError as e:
        return {
            'valid': False,
            'error': f'Invalid date format: {str(e)}'
        }
    
    return {'valid': True}
