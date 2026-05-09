from flask import Blueprint, jsonify
from databases_flask_connection import db, Bus, Driver, Student
from utils import admin_required

reports_bp = Blueprint('reports', __name__)

@reports_bp.route('/admin/reports/overview', methods=['GET'])
@admin_required()
def get_reports_overview():
    try:
        # 1. Calculate Fleet Utilization
        buses = Bus.query.all()
        total_capacity = 0
        total_assigned = 0
        active_routes_count = 0

        for bus in buses:
            total_capacity += bus.Capacity
            # Recalculate actual assigned count to be safe
            assigned_count = Student.query.filter_by(Assigned_Bus=bus.Bus_ID).count()
            total_assigned += assigned_count
            
            if bus.Bus_Status == 'In-service':
                active_routes_count += 1

        occupancy_rate = 0
        if total_capacity > 0:
            occupancy_rate = int((total_assigned / total_capacity) * 100)

        # 2. Get Driver Statuses
        # (Note: Since we don't have a 'Punctuality Score' in DB yet, 
        # we will use their current status and a placeholder score for now)
        drivers = Driver.query.all()
        driver_list = []
        for d in drivers:
            driver_list.append({
                "name": d.Driver_Name,
                "status": d.Status, # 'On Shift' or 'Off Duty'
                "score": "95%" # Placeholder until we have tracking history
            })

        return jsonify({
            "occupancy": f"{occupancy_rate}%",
            "peak_time": "07:30 AM", # Hardcoded for now (requires complex logs analysis)
            "active_routes": f"{active_routes_count}/{len(buses)}",
            "drivers": driver_list
        }), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500