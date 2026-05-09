from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from datetime import datetime
from databases_flask_connection import db, Student, Bus, Exceptions, Report, Driver, BusStop # <--- Added BusStop
from utils import student_required, admin_required 

student_actions_bp = Blueprint('student_actions', __name__)

# ==================== STUDENT: GET PROFILE & TRANSPORT INFO ====================

@student_actions_bp.route('/student/profile-info', methods=['GET'])
@student_required()
def get_student_profile_info():
    """
    Fetches Student details PLUS Course, Year, Bus, Driver, AND Weekly Schedule.
    """
    try:
        current_user_id = get_jwt_identity()
        student = Student.query.get(current_user_id)
        if not student:
             return jsonify({'error': 'Student not found'}), 404

        bus_data = None
        driver_data = {
            'name': 'Unassigned',
            'phone': 'N/A',
            'status': 'Unknown'
        }
        
        # If student has a bus, fetch Bus & Driver details
        if student.Assigned_Bus:
            bus = Bus.query.get(student.Assigned_Bus)
            if bus:
                bus_data = {
                    'id': f"B{bus.Bus_ID:03d}",
                    'plate': bus.Plate_Number,
                    'status': bus.Bus_Status
                }
                
                if bus.Driver:
                    driver_obj = Driver.query.filter_by(Driver_Name=bus.Driver).first()
                    if driver_obj:
                        driver_data = {
                            'name': driver_obj.Driver_Name,
                            'phone': driver_obj.Phone_Number,
                            'status': driver_obj.Status
                        }
                    else:
                        driver_data['name'] = bus.Driver

        # --- FETCH STOP INFO (NEW) ---
        stop_name = "Not Selected"
        pickup_time = "--:--"
        if student.Bus_Stop_ID:
            stop = BusStop.query.get(student.Bus_Stop_ID)
            if stop:
                stop_name = stop.Stop_Name
                pickup_time = stop.Pickup_Time if stop.Pickup_Time else "07:00 AM"
        # Fallback to old location string if no real stop selected
        elif student.Locations:
            stop_name = student.Locations

        # --- WEEKLY SCHEDULE ---
        weekly_schedule = [
            {'day': 'Monday', 'active': True},
            {'day': 'Tuesday', 'active': True},
            {'day': 'Wednesday', 'active': True},
            {'day': 'Thursday', 'active': True},
            {'day': 'Friday', 'active': True}, 
            {'day': 'Saturday', 'active': False},
            {'day': 'Sunday', 'active': False} 
        ]

        return jsonify({
            'student': {
                'Student_Name': student.Student_Name,
                'Student_ID': student.Student_ID,
                'Course': student.Course if student.Course else "No Course",
                'Year_Level': student.Year_Level if student.Year_Level else "Year 1",
                'Assigned_Bus': bus_data['id'] if bus_data else "Unassigned",
                'Bus_Plate': bus_data['plate'] if bus_data else "N/A",
                'Bus_Location': stop_name, # <--- Updated to show real stop name
                'Pickup_Time': pickup_time, # <--- Added Time
                'Driver_Name': driver_data['name'],
                'Driver_Phone': driver_data['phone'],
                'Driver_Status': driver_data['status']
            },
            'weekly_schedule': weekly_schedule 
        }), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500


# ==================== STUDENT: SELECT STOP (NEW) ====================

@student_actions_bp.route('/student/stops', methods=['GET'])
@student_required()
def get_student_stops_list():
    """
    Returns a list of all available stops for the student to choose from.
    """
    try:
        stops = BusStop.query.all()
        output = []
        for stop in stops:
            bus = Bus.query.get(stop.Bus_ID)
            bus_plate = bus.Plate_Number if bus else "Unknown Bus"
            
            output.append({
                'id': stop.Stop_ID,
                'name': stop.Stop_Name,
                'area': stop.Area_Name,
                'time': stop.Pickup_Time,
                'bus_info': f"Bus {bus_plate}"
            })
        return jsonify(output), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@student_actions_bp.route('/student/select-stop', methods=['POST'])
@student_required()
def select_student_stop():
    """
    Student selects a Stop ID -> System automatically assigns the Bus.
    """
    try:
        current_user_id = get_jwt_identity()
        data = request.get_json()
        stop_id = data.get('stop_id')

        if not stop_id:
            return jsonify({'error': 'Stop ID is required'}), 400

        # 1. Verify Stop Exists
        stop = BusStop.query.get(stop_id)
        if not stop:
            return jsonify({'error': 'Stop not found'}), 404

        # 2. Get Student
        student = Student.query.get(current_user_id)
        if not student:
            return jsonify({'error': 'Student not found'}), 404

        # 3. Update Student (Assign Stop AND Assign Bus)
        student.Bus_Stop_ID = stop.Stop_ID
        student.Assigned_Bus = stop.Bus_ID # <--- AUTO ASSIGN BUS
        student.Locations = stop.Stop_Name # Keep legacy field synced just in case

        # 4. Update Bus Capacity Count
        bus = Bus.query.get(stop.Bus_ID)
        if bus:
            # Recalculate count to be safe
            count = Student.query.filter_by(Assigned_Bus=bus.Bus_ID).count()
            bus.Num_Students_assigned = count + 1 # +1 for this new student (approx)
        
        db.session.commit()

        return jsonify({
            'message': f'Stop selected! You are assigned to Bus {bus.Plate_Number if bus else "?"}'
        }), 200

    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500


# ==================== STUDENT: SUBMIT TRANSPORT REQUEST ====================

@student_actions_bp.route('/student/request-transport', methods=['POST'])
@student_required()
def request_transport():
    try:
        current_user_id = get_jwt_identity()
        data = request.get_json()
        
        request_date_str = data.get('date')
        reason = data.get('reason')
        
        if not request_date_str or not reason:
            return jsonify({'error': 'Date and reason are required'}), 400
            
        try:
            request_date = datetime.strptime(request_date_str, '%Y-%m-%d').date()
        except ValueError:
            return jsonify({'error': 'Invalid date format. Use YYYY-MM-DD'}), 400

        new_request = Exceptions(
            Student_ID=int(current_user_id),
            Date_Request=request_date,
            Descriptions=reason,
            Permission='Pending',
            Date_Submitted=datetime.now()
        )
        
        db.session.add(new_request)
        db.session.commit()
        
        return jsonify({'message': 'Transport request submitted successfully'}), 201

    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500


# ==================== STUDENT: SUBMIT SUPPORT TICKET ====================

@student_actions_bp.route('/student/support-ticket', methods=['POST'])
@student_required()
def submit_support_ticket():
    try:
        current_user_id = get_jwt_identity()
        data = request.get_json()
        
        category = data.get('category')
        description = data.get('description')
        
        if not category or not description:
            return jsonify({'error': 'Category and description are required'}), 400
            
        # Optional: Get Assigned Bus for context
        student = Student.query.get(int(current_user_id))
        bus_info = "N/A"
        if student and student.Assigned_Bus:
            bus = Bus.query.get(student.Assigned_Bus)
            if bus:
                bus_info = bus.Plate_Number

        new_report = Report(
            Student_ID=int(current_user_id),
            Assigned_Bus=bus_info,
            Report_Category=category,
            Descriptions=description,
            Date_Submitted=datetime.now()
        )
        
        db.session.add(new_report)
        db.session.commit()
        
        return jsonify({'message': 'Support ticket submitted successfully'}), 201

    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500


# ==================== ADMIN: VIEW TRANSPORT REQUESTS ====================

@student_actions_bp.route('/admin/transport-requests', methods=['GET'])
@admin_required()
def get_all_transport_requests():
    try:
        requests = Exceptions.query.order_by(Exceptions.Date_Submitted.desc()).all()
        
        output = []
        for req in requests:
            student = Student.query.get(req.Student_ID)
            output.append({
                'id': req.Exceptions_ID,
                'student_name': student.Student_Name if student else "Unknown",
                'student_id': req.Student_ID,
                'date_requested': req.Date_Request.strftime('%Y-%m-%d'),
                'reason': req.Descriptions,
                'status': req.Permission,
                'admin_comment': req.Admin_Comment, # <--- ADDED THIS
                'submitted_at': req.Date_Submitted.strftime('%Y-%m-%d')
            })
            
        return jsonify(output), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500


# ==================== ADMIN: VIEW SUPPORT TICKETS ====================

@student_actions_bp.route('/admin/support-tickets', methods=['GET'])
@admin_required()
def get_all_support_tickets():
    try:
        reports = Report.query.order_by(Report.Date_Submitted.desc()).all()
        
        output = []
        for rep in reports:
            student = Student.query.get(rep.Student_ID)
            output.append({
                'id': rep.Report_ID,
                'student_name': student.Student_Name if student else "Unknown",
                'student_id': rep.Student_ID,
                'category': rep.Report_Category,
                'description': rep.Descriptions,
                'bus': rep.Assigned_Bus,
                'admin_comment': rep.Admin_Comment, # <--- ADDED THIS
                'submitted_at': rep.Date_Submitted.strftime('%Y-%m-%d')
            })
            
        return jsonify(output), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500


# ==================== ADMIN: GET ALL STUDENTS ====================

@student_actions_bp.route('/admin/students', methods=['GET'])
@admin_required()
def get_all_students():
    try:
        students = Student.query.all()
        output = []
        
        for s in students:
            bus = Bus.query.get(s.Assigned_Bus) if s.Assigned_Bus else None
            initials = "".join([n[0] for n in s.Student_Name.split()[:2]]).upper() if s.Student_Name else "??"
            
            output.append({
                "name": s.Student_Name,
                "id": s.Student_ID,
                "route": bus.Plate_Number if bus else "Not Assigned",
                "status": "Active", 
                "nfc": "Linked" if s.Card_ID else "None", 
                "image": initials
            })
            
        return jsonify(output), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500


# ==================== ADMIN: STUDENT ACTIONS ====================

@student_actions_bp.route('/admin/student/<int:student_id>', methods=['DELETE'])
@admin_required()
def delete_student(student_id):
    try:
        student = Student.query.get(student_id)
        if not student:
            return jsonify({'error': 'Student not found'}), 404

        db.session.delete(student)
        db.session.commit()
        
        return jsonify({'message': 'Student deleted successfully'}), 200

    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@student_actions_bp.route('/admin/student/<int:student_id>/link-card', methods=['POST'])
@admin_required()
def link_student_card(student_id):
    try:
        student = Student.query.get(student_id)
        if not student:
            return jsonify({'error': 'Student not found'}), 404

        data = request.get_json()
        new_card_id = data.get('card_id')

        if not new_card_id:
            return jsonify({'error': 'Card ID is required'}), 400

        existing = Student.query.filter_by(Card_ID=new_card_id).first()
        if existing and existing.Student_ID != student_id:
             return jsonify({'error': 'Card ID already assigned to another student'}), 409

        student.Card_ID = new_card_id
        db.session.commit()
        
        return jsonify({'message': 'Card linked successfully'}), 200

    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

# ==================== ADMIN ACTIONS: MANAGE REQUESTS & TICKETS ====================

@student_actions_bp.route('/admin/request/<int:request_id>/respond', methods=['POST'])
@admin_required()
def respond_to_transport_request(request_id):
    try:
        data = request.get_json()
        new_status = data.get('status')
        comment = data.get('comment', '') 
        
        if new_status not in ['Approved', 'Rejected']:
            return jsonify({'error': 'Invalid status. Use Approved or Rejected'}), 400

        req = Exceptions.query.get(request_id)
        if not req:
            return jsonify({'error': 'Request not found'}), 404

        req.Permission = new_status
        req.Admin_Comment = comment 
        db.session.commit()
        
        return jsonify({'message': f'Request {new_status} successfully'}), 200

    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500


@student_actions_bp.route('/admin/report/<int:report_id>/resolve', methods=['POST'])
@admin_required()
def resolve_support_ticket(report_id):
    try:
        data = request.get_json()
        comment = data.get('comment', '') 

        ticket = Report.query.get(report_id)
        if not ticket:
            return jsonify({'error': 'Ticket not found'}), 404

        if "[RESOLVED]" not in ticket.Descriptions:
            ticket.Descriptions = f"[RESOLVED] {ticket.Descriptions}"
        
        ticket.Admin_Comment = comment 
        db.session.commit()
        
        return jsonify({'message': 'Ticket resolved with comment'}), 200

    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

# ==================== STUDENT: VIEW MY ACTIVITY ====================

@student_actions_bp.route('/student/my-activity', methods=['GET'])
@student_required()
def get_my_activity():
    try:
        current_user_id = get_jwt_identity()
        
        my_requests = Exceptions.query.filter_by(Student_ID=current_user_id).order_by(Exceptions.Date_Submitted.desc()).all()
        requests_data = []
        for req in my_requests:
            requests_data.append({
                'id': req.Exceptions_ID,
                'date_requested': req.Date_Request.strftime('%Y-%m-%d'),
                'reason': req.Descriptions,
                'status': req.Permission, 
                'admin_comment': req.Admin_Comment, 
                'type': 'Transport Request'
            })

        my_tickets = Report.query.filter_by(Student_ID=current_user_id).order_by(Report.Date_Submitted.desc()).all()
        tickets_data = []
        for ticket in my_tickets:
            status = "Resolved" if "[RESOLVED]" in ticket.Descriptions else "Open"
            clean_desc = ticket.Descriptions.replace("[RESOLVED]", "").strip()
            
            tickets_data.append({
                'id': ticket.Report_ID,
                'category': ticket.Report_Category,
                'description': clean_desc,
                'status': status,
                'admin_comment': ticket.Admin_Comment, 
                'date': ticket.Date_Submitted.strftime('%Y-%m-%d'),
                'type': 'Support Ticket'
            })

        return jsonify({
            'requests': requests_data,
            'tickets': tickets_data
        }), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500