from flask import Blueprint, jsonify
from databases_flask_connection import db, Student
from utils import admin_required

finance_bp = Blueprint('finance', __name__)

@finance_bp.route('/admin/finance', methods=['GET'])
@admin_required()
def get_finance_data():
    try:
        students = Student.query.all()
        
        total_revenue = 0
        outstanding_amount = 0
        payment_list = []
        
        # Hardcoded fee for now (You can make this dynamic later)
        TERM_FEE = 2500 

        for s in students:
            # Determine Status & Amount
            status = s.Bus_fees if s.Bus_fees else "Pending"
            
            if status == 'Paid':
                total_revenue += TERM_FEE
            else:
                outstanding_amount += TERM_FEE

            payment_list.append({
                "student": s.Student_Name,
                "id": str(s.Student_ID),
                "amount": f"AED {TERM_FEE:,}",
                "date": "---", # You might want to add a 'Payment_Date' column to DB later
                "status": status,
                "method": "Card" if status == 'Paid' else "---" 
            })

        return jsonify({
            "revenue": f"AED {total_revenue/1000:.1f}k", # e.g. "AED 12.5k"
            "outstanding": f"AED {outstanding_amount/1000:.1f}k",
            "payments": payment_list
        }), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500