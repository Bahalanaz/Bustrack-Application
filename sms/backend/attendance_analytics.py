from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from datetime import datetime, date, time, timedelta
from sqlalchemy import func, and_
from databases_flask_connection import db, Attendance, Student, Bus, Student_Timetable
from utils import admin_required, student_required

attendance_analytics_bp = Blueprint('attendance_analytics', __name__)

# ==================== NEW: SIMULATE SCAN (TOGGLE) ====================

@attendance_analytics_bp.route('/student/attendance/scan', methods=['POST'])
@student_required()
def simulate_scan():
    """
    BA-NEW: Simulate a card tap. 
    Toggles status: If 'IN' -> Marks 'OUT'. If 'OUT' -> Marks 'IN'.
    """
    try:
        current_user_id = get_jwt_identity()
        student = Student.query.get(int(current_user_id))
        
        if not student:
            return jsonify({'error': 'Student not found'}), 404

        # 1. Find the latest attendance record
        last_record = Attendance.query.filter_by(Student_ID=student.Student_ID)\
            .order_by(Attendance.Time_Scanned_Date.desc())\
            .first()

        now = datetime.now()
        
        # 2. Determine Entry vs Exit (Toggle Logic)
        scan_type = 'Entry' # Default to Entry if no history exists
        
        if last_record:
            # Check the actual Scan_Type from the last record
            if last_record.Scan_Type == 'Entry':
                scan_type = 'Exit'
            elif last_record.Scan_Type == 'Exit':
                scan_type = 'Entry'
            else:
                # Fallback if Scan_Type is null (legacy data)
                # Simple logic: After 2 PM is likely an exit
                if now.hour >= 14:
                    scan_type = 'Exit'

        # 3. Create the new record
        # Note: Bus_ID is removed as requested previously to match DB schema
        new_scan = Attendance(
            Card_ID=f"DIGITAL-{student.Student_ID}", 
            Student_ID=student.Student_ID,
            Time_Scanned_Date=now,
            Scan_Type=scan_type  # <--- Saving to your new column
        )

        db.session.add(new_scan)
        db.session.commit()

        return jsonify({
            'message': 'Scan successful',
            'type': scan_type,
            'timestamp': now.strftime('%Y-%m-%d %I:%M:%S %p')
        }), 200

    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

# ==================== BA-39: STUDENT - VIEW ATTENDANCE HISTORY ====================

@attendance_analytics_bp.route('/student/attendance/history', methods=['GET'])
@student_required()
def get_student_attendance_history():
    try:
        current_user_id = get_jwt_identity()
        
        start_date = request.args.get('start_date', None)
        end_date = request.args.get('end_date', None)
        page = request.args.get('page', 1, type=int)
        per_page = request.args.get('per_page', 20, type=int)
        
        student = Student.query.get(int(current_user_id))
        if not student:
            return jsonify({'error': 'Student not found'}), 404
        
        query = Attendance.query.filter_by(Student_ID=student.Student_ID)
        
        if start_date:
            try:
                start = datetime.strptime(start_date, '%Y-%m-%d')
                query = query.filter(Attendance.Time_Scanned_Date >= start)
            except ValueError:
                return jsonify({'error': 'Invalid start_date format'}), 400
        
        if end_date:
            try:
                end = datetime.strptime(end_date, '%Y-%m-%d').replace(hour=23, minute=59, second=59)
                query = query.filter(Attendance.Time_Scanned_Date <= end)
            except ValueError:
                return jsonify({'error': 'Invalid end_date format'}), 400
        
        paginated = query.order_by(Attendance.Time_Scanned_Date.desc()).paginate(
            page=page, per_page=per_page, error_out=False
        )
        
        history = []
        bus = Bus.query.get(student.Assigned_Bus) if student.Assigned_Bus else None
        
        for record in paginated.items:
            history.append({
                'Attendance_ID': record.Attendance_ID,
                'Date': record.Time_Scanned_Date.strftime('%Y-%m-%d'),
                'Time': record.Time_Scanned_Date.strftime('%I:%M %p'),
                'DateTime': record.Time_Scanned_Date.strftime('%Y-%m-%d %I:%M:%S %p'),
                'Card_ID': record.Card_ID,
                'Bus': bus.Plate_Number if bus else 'N/A',
                'Location': bus.Bus_Assigned_Location if bus else 'N/A',
                'Status': 'Present',
                'Scan_Type': record.Scan_Type # Include scan type in history
            })
        
        total_scans = Attendance.query.filter_by(Student_ID=student.Student_ID).count()
        
        first_day_month = date.today().replace(day=1)
        scans_this_month = Attendance.query.filter(
            and_(
                Attendance.Student_ID == student.Student_ID,
                Attendance.Time_Scanned_Date >= datetime.combine(first_day_month, time.min)
            )
        ).count()
        
        return jsonify({
            'student': {
                'Student_ID': student.Student_ID,
                'Student_Name': student.Student_Name,
                'Assigned_Bus': bus.Plate_Number if bus else 'N/A'
            },
            'attendance_history': history,
            'pagination': {
                'total': paginated.total,
                'pages': paginated.pages,
                'current_page': page,
                'per_page': per_page
            },
            'statistics': {
                'total_scans': total_scans,
                'scans_this_month': scans_this_month
            }
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# ==================== BA-43: VIEW BUS TIMETABLE ====================

@attendance_analytics_bp.route('/student/timetable', methods=['GET'])
@student_required()
def get_student_timetable():
    try:
        current_user_id = get_jwt_identity()
        
        student = Student.query.get(int(current_user_id))
        if not student:
            return jsonify({'error': 'Student not found'}), 404
        
        timetable_entries = Student_Timetable.query.filter_by(Student_ID=student.Student_ID).all()
        bus = Bus.query.get(student.Assigned_Bus) if student.Assigned_Bus else None
        
        days_of_week = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']
        weekly_schedule = []
        
        for day in days_of_week:
            entry = next((t for t in timetable_entries if t.day == day), None)
            weekly_schedule.append({
                'day': day,
                'active': entry.active if entry else False,
                'bus_required': entry.active if entry else False,
                'ST_ID': entry.ST_ID if entry else None
            })
        
        return jsonify({
            'student': {
                'Student_ID': student.Student_ID,
                'Student_Name': student.Student_Name,
                'Assigned_Bus': bus.Plate_Number if bus else 'Not Assigned',
                'Bus_Location': bus.Bus_Assigned_Location if bus else 'N/A'
            },
            'weekly_schedule': weekly_schedule,
            'active_days': sum(1 for day in weekly_schedule if day['active'])
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# ==================== ADMIN ROUTES ====================

@attendance_analytics_bp.route('/admin/student/<int:student_id>/attendance', methods=['GET'])
@admin_required()
def get_admin_view_student_attendance(student_id):
    try:
        student = Student.query.get(student_id)
        if not student:
            return jsonify({'error': 'Student not found'}), 404
        
        start_date = request.args.get('start_date', None)
        end_date = request.args.get('end_date', None)
        
        query = Attendance.query.filter_by(Student_ID=student_id)
        
        if start_date:
            start = datetime.strptime(start_date, '%Y-%m-%d')
            query = query.filter(Attendance.Time_Scanned_Date >= start)
        
        if end_date:
            end = datetime.strptime(end_date, '%Y-%m-%d').replace(hour=23, minute=59, second=59)
            query = query.filter(Attendance.Time_Scanned_Date <= end)
        
        records = query.order_by(Attendance.Time_Scanned_Date.desc()).all()
        
        history = []
        bus = Bus.query.get(student.Assigned_Bus) if student.Assigned_Bus else None
        
        for record in records:
            history.append({
                'Attendance_ID': record.Attendance_ID,
                'Date': record.Time_Scanned_Date.strftime('%Y-%m-%d'),
                'Time': record.Time_Scanned_Date.strftime('%I:%M %p'),
                'Card_ID': record.Card_ID,
                'Bus': bus.Plate_Number if bus else 'N/A',
                'Scan_Type': record.Scan_Type
            })
        
        return jsonify({
            'student': {
                'Student_ID': student.Student_ID,
                'Student_Name': student.Student_Name,
                'Assigned_Bus': bus.Plate_Number if bus else 'N/A'
            },
            'attendance_history': history,
            'total_records': len(history)
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@attendance_analytics_bp.route('/admin/attendance/incomplete-trips', methods=['GET'])
@admin_required()
def get_incomplete_trips_report():
    try:
        selected_date = request.args.get('date', date.today().isoformat())
        bus_id = request.args.get('bus_id', None, type=int)
        
        try:
            check_date = datetime.strptime(selected_date, '%Y-%m-%d').date()
        except ValueError:
            return jsonify({'error': 'Invalid date format'}), 400
        
        start_datetime = datetime.combine(check_date, time.min)
        end_datetime = datetime.combine(check_date, time.max)
        
        query = db.session.query(
            Attendance.Student_ID,
            func.count(Attendance.Attendance_ID).label('scan_count'),
            func.min(Attendance.Time_Scanned_Date).label('first_scan'),
            func.max(Attendance.Time_Scanned_Date).label('last_scan')
        ).filter(
            and_(
                Attendance.Time_Scanned_Date >= start_datetime,
                Attendance.Time_Scanned_Date <= end_datetime
            )
        ).group_by(Attendance.Student_ID)
        
        results = query.all()
        incomplete_trips = []
        
        for result in results:
            if result.scan_count == 1:
                student = Student.query.get(result.Student_ID)
                if not student: continue
                
                if bus_id and student.Assigned_Bus != bus_id: continue
                
                bus = Bus.query.get(student.Assigned_Bus) if student.Assigned_Bus else None
                scan_time = result.first_scan
                
                # Determine scan type based on time
                scan_type = "Morning" if scan_time.hour < 14 else "Afternoon"
                missing_type = "Afternoon" if scan_type == "Morning" else "Morning"
                
                incomplete_trips.append({
                    'Student_ID': student.Student_ID,
                    'Student_Name': student.Student_Name,
                    'Student_Username': student.Student_Username,
                    'Assigned_Bus': bus.Plate_Number if bus else 'N/A',
                    'scan_count': result.scan_count,
                    'scanned_at': scan_time.strftime('%I:%M %p'),
                    'scan_type': scan_type,
                    'missing_scan': missing_type,
                    'status': 'Incomplete Trip'
                })
        
        summary = {
            'date': selected_date,
            'total_incomplete': len(incomplete_trips),
            'morning_only': len([t for t in incomplete_trips if t['scan_type'] == 'Morning']),
            'afternoon_only': len([t for t in incomplete_trips if t['scan_type'] == 'Afternoon'])
        }
        
        return jsonify({'summary': summary, 'incomplete_trips': incomplete_trips}), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@attendance_analytics_bp.route('/admin/timetable/all', methods=['GET'])
@admin_required()
def get_all_timetables():
    try:
        day_filter = request.args.get('day', None)
        buses = Bus.query.filter_by(Bus_Status='In-service').all()
        timetable_overview = []
        
        for bus in buses:
            students = Student.query.filter_by(Assigned_Bus=bus.Bus_ID).all()
            
            if day_filter:
                active_students = []
                for student in students:
                    timetable = Student_Timetable.query.filter_by(
                        Student_ID=student.Student_ID, day=day_filter, active=True
                    ).first()
                    if timetable:
                        active_students.append(student.Student_Name)
                
                timetable_overview.append({
                    'Bus_ID': bus.Bus_ID,
                    'Plate_Number': bus.Plate_Number,
                    'Driver': bus.Driver,
                    'day': day_filter,
                    'students_scheduled': len(active_students),
                    'students': active_students
                })
            else:
                timetable_overview.append({
                    'Bus_ID': bus.Bus_ID,
                    'Plate_Number': bus.Plate_Number,
                    'Driver': bus.Driver,
                    'total_students': len(students)
                })
        
        return jsonify({
            'timetables': timetable_overview,
            'total_buses': len(buses),
            'filtered_by_day': day_filter if day_filter else 'All days'
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# ==================== NEW: ADMIN DASHBOARD STATS ====================

@attendance_analytics_bp.route('/admin/dashboard', methods=['GET'])
@admin_required()
def get_admin_dashboard_stats():
    """
    Returns statistics for the Admin Dashboard:
    1. Expected Students (from Timetable)
    2. Checked-in Count (Present today)
    3. Pending Count
    4. Live Feed (Last 5 scans)
    """
    try:
        today = date.today()
        day_name = today.strftime("%A") # e.g., "Monday"

        # 1. Calculate Expected Students (from Timetable)
        # Count all students who have 'active=True' for Today in the timetable
        expected_count = Student_Timetable.query.filter_by(day=day_name, active=True).count()
        
        # 2. Calculate Checked-In Students
        # Count distinct Student_IDs in Attendance table for Today
        present_count = db.session.query(func.count(func.distinct(Attendance.Student_ID)))\
            .filter(func.date(Attendance.Time_Scanned_Date) == today)\
            .scalar()

        # 3. Get Live Feed (Last 5 scans)
        recent_scans = Attendance.query.order_by(Attendance.Time_Scanned_Date.desc()).limit(5).all()
        
        feed_data = []
        for scan in recent_scans:
            student = Student.query.get(scan.Student_ID)
            bus = Bus.query.get(student.Assigned_Bus) if student.Assigned_Bus else None
            
            # Determine Action Text
            action = f"Bus {bus.Plate_Number if bus else '???'}"
            if scan.Scan_Type == 'Entry':
                action = f"Boarded {action}"
            else:
                action = f"Dropped off {action}"

            feed_data.append({
                'name': student.Student_Name if student else "Unknown",
                'action': action,
                'time': scan.Time_Scanned_Date.strftime("%I:%M %p"), # 12:30 PM
                'is_entry': scan.Scan_Type == 'Entry'
            })

        return jsonify({
            'date_str': today.strftime("%A, %d %b"), # Friday, 12 Dec
            'stats': {
                'total_expected': expected_count,
                'present': present_count,
                'pending': max(0, expected_count - present_count),
                'progress': (present_count / expected_count) if expected_count > 0 else 0
            },
            'live_feed': feed_data
        }), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500