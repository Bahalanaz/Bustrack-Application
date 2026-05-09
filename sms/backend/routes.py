from flask import request, jsonify, Blueprint
from flask_jwt_extended import create_access_token
from sqlalchemy import or_
import re
from datetime import datetime
# Imports from your database connection file
from databases_flask_connection import db, Student, Admins, Report, Attendance

Login_Signup_bp = Blueprint("login", __name__)

# =======================================================
#       GLOBALS FOR RFID & STATUS
# =======================================================
latest_scanned_card = None
last_heartbeat = None             # To track if Pi is online
linking_target_student_id = None  # To track which student we are linking

# =======================================================
#                 EXISTING AUTH ROUTES
# =======================================================

# STUDENT SIGNUP
@Login_Signup_bp.route("/Signup_Student", methods=['POST'])
def Signup_Student():
    try:
        data = request.get_json()
        Name = data.get("Student_Name")
        Username = data.get("Student_Username")
        Email = data.get("Email")
        Password = data.get("Student_Password")
        Phone_Number = data.get("Student_Number")
        Course = data.get("Course")
        Year_Level = data.get("Year_Level")
        Locations = data.get("Locations")

        if not Name or not Email or not Password or not Username or not Phone_Number:
            return jsonify({"message": "Name, username, email, password, and phone number are required"}), 400

        email_regex = r"[^@]+@[^@]+\.[^@]+"
        if not re.match(email_regex, Email):
            return jsonify({"message": "Invalid email format"}), 400

        if len(Password) < 6 or not re.search(r"\d", Password):
            return jsonify({"message": "Password must be at least 6 characters long and contain a number"}), 400

        if Student.query.filter_by(Phone_number=Phone_Number).first():
            return jsonify({"message": "Phone number already registered"}), 409

        if Student.query.filter_by(Email=Email).first():
            return jsonify({"message": "Email already registered"}), 409

        if Student.query.filter_by(Student_Username=Username).first():
            return jsonify({"message": "Username already taken"}), 409

        if not Course or not Year_Level:
            return jsonify({"message": "Course and Year Level are required"}), 400

        new_student = Student(
            Student_Name=Name,
            Student_Username=Username,
            Email=Email,
            Student_Password=Password,
            Phone_number=Phone_Number,
            Course=Course,
            Year_Level=Year_Level,
            Locations=Locations,
            Enrolment='Pending', 
            Bus_fees='Pending'
        )

        db.session.add(new_student)
        db.session.commit()
        return jsonify({"message": "Signup successful"}), 201

    except Exception as e:
        return jsonify({"message": "An error occurred during signup", "error": str(e)}), 500
    

# ADMIN SIGNUP
@Login_Signup_bp.route("/Signup_Admin", methods=['POST'])
def Signup_Admin():
    try:
        data = request.get_json()
        Name = data.get("Admin_Name")
        Username = data.get("Admin_Username")
        Password = data.get("Admin_Password")
        Phone_Number = data.get("Admin_Number")
        Email = data.get("Email")

        if not Name or not Email or not Password or not Username or not Phone_Number:
            return jsonify({"message": "Name, username, email, password, and phone number are required"}), 400

        email_regex = r"[^@]+@[^@]+\.[^@]+"
        if not re.match(email_regex, Email):
            return jsonify({"message": "Invalid email format"}), 400

        if len(Password) < 6 or not re.search(r"\d", Password):
            return jsonify({"message": "Password must be at least 6 characters long and contain a number"}), 400

        if Admins.query.filter_by(Admin_Number=Phone_Number).first():
            return jsonify({"message": "Phone number already registered"}), 409
        if Admins.query.filter_by(Email=Email).first():
            return jsonify({"message": "Email already registered"}), 409
        if Admins.query.filter_by(Admin_Username=Username).first():
            return jsonify({"message": "Username already taken"}), 409

        new_admin = Admins(
            Admin_Name=Name,
            Admin_Username=Username,
            Email=Email,
            Admin_Password=Password,
            Admin_Number=Phone_Number,
            Admin_Account_Status='Valid' 
        )

        db.session.add(new_admin)
        db.session.commit()
        return jsonify({"message": "Signup successful"}), 201

    except Exception as e:
        return jsonify({"message": "An error occurred during signup", "error": str(e)}), 500
    

# STUDENT LOGIN (DEBUG MODE)
@Login_Signup_bp.route("/Login_Student", methods=['POST'])
def Login_Student():
    try:
        data = request.get_json()
        Username_or_Email = data.get("Username_or_Email")
        Password = data.get("Password")

        # --- DEBUG PRINT 1: What did the frontend send? ---
        print("\n" + "="*40)
        print(f"LOGIN ATTEMPT:")
        print(f" -> Input: '{Username_or_Email}'")
        print(f" -> Password: '{Password}'")
        
        if not Username_or_Email or not Password:
            return jsonify({"message": "Username/email and password are required"}), 400

        # --- DEBUG PRINT 2: Check ALL matches, not just the first one ---
        # We search for ANY student that matches the username OR the email
        potential_matches = Student.query.filter(
            or_(
                Student.Student_Username == Username_or_Email,
                Student.Email == Username_or_Email
            )
        ).all()

        print(f" -> Database found {len(potential_matches)} matches for this input.")
        
        for idx, s in enumerate(potential_matches):
            print(f"    [{idx}] ID: {s.Student_ID} | User: {s.Student_Username} | Email: {s.Email}")

        # If we found nothing
        if not potential_matches:
            print(" -> Result: No user found.")
            print("="*40 + "\n")
            return jsonify({"message": "User not found"}), 404

        # We take the first match (Standard Logic)
        student = potential_matches[0]
        print(f" -> Selected Student: {student.Student_Name} (ID: {student.Student_ID})")

        # Check Password
        if student.Student_Password != Password:
            print(f" -> Result: Password Mismatch! (Expected: {student.Student_Password}, Got: {Password})")
            print("="*40 + "\n")
            return jsonify({"message": "Incorrect password"}), 401

        # SUCCESS
        print(f" -> Result: LOGIN SUCCESS for {student.Student_Name}")
        print("="*40 + "\n")

        access_token = create_access_token(
            identity=str(student.Student_ID),
            additional_claims={
                "role": "student",
                "Name": student.Student_Name,
                "Username": student.Student_Username,
                "Email": student.Email
            }
        )

        return jsonify({
            "message": "Login successful",
            "access_token": access_token,
            "student": {
                "ID": student.Student_ID,
                "Name": student.Student_Name,
                "Username": student.Student_Username,
                "Email": student.Email,
                "Course": student.Course,
                "Year_Level": student.Year_Level
            }
        }), 200

    except Exception as e:
        print(f"!!! CRITICAL ERROR: {e}")
        return jsonify({"message": "An error occurred during login", "error": str(e)}), 500
    

# ADMIN LOGIN
@Login_Signup_bp.route("/Login_Admin", methods=['POST'])
def Login_Admin():
    try:
        data = request.get_json()
        Username_or_Email = data.get("Username_or_Email")
        Password = data.get("Password")

        if not Username_or_Email or not Password:
            return jsonify({"message": "Username/email and password are required"}), 400

        admin = Admins.query.filter(
            (Admins.Admin_Username == Username_or_Email) |
            (Admins.Email == Username_or_Email)
        ).first()

        if not admin:
            return jsonify({"message": "Admin not found"}), 404

        if admin.Admin_Password != Password:
            return jsonify({"message": "Incorrect password"}), 401

        if admin.Admin_Account_Status != 'Valid':
            return jsonify({"message": "Your account doesn’t have permission."}), 403

        access_token = create_access_token(
            identity=str(admin.Admin_ID),
            additional_claims={
                "role": "admin",
                "Name": admin.Admin_Name,
                "Username": admin.Admin_Username,
                "Email": admin.Email,
                "Status": admin.Admin_Account_Status
            }
        )

        return jsonify({
            "message": "Login successful",
            "access_token": access_token,
            "admin": {
                "ID": admin.Admin_ID,
                "Name": admin.Admin_Name,
                "Username": admin.Admin_Username,
                "Email": admin.Email,
                "Status": admin.Admin_Account_Status
            }
        }), 200

    except Exception as e:
        return jsonify({"message": "An error occurred during login", "error": str(e)}), 500

# SUBMIT REPORT
@Login_Signup_bp.route("/Submit_Report", methods=['POST'])
def Submit_Report():
    try:
        data = request.get_json()
        student_id = data.get("Student_ID")
        category = data.get("Category")
        description = data.get("Description")
        
        if not student_id or not description:
            return jsonify({"message": "Student ID and Description are required"}), 400

        new_report = Report(
            Student_ID=student_id,
            Report_Category=category,
            Descriptions=description,
            Assigned_Bus="Pending",
            Date_Submitted=datetime.utcnow()
        )

        db.session.add(new_report)
        db.session.commit()

        return jsonify({"message": "Report submitted successfully"}), 201

    except Exception as e:
        return jsonify({"message": "Error submitting report", "error": str(e)}), 500


# RECORD ATTENDANCE (Smart Entry/Exit)
@Login_Signup_bp.route("/Record_Attendance", methods=['POST'])
def Record_Attendance():
    try:
        data = request.get_json()
        student_id = data.get("Student_ID")
        
        if not student_id:
            return jsonify({"message": "Student ID required"}), 400

        # Check the LAST scan for this student today
        today_start = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)
        
        last_scan = Attendance.query.filter(
            Attendance.Student_ID == student_id,
            Attendance.Time_Scanned_Date >= today_start
        ).order_by(Attendance.Time_Scanned_Date.desc()).first()

        # Determine Entry/Exit
        new_type = 'Entry'
        if last_scan and last_scan.Scan_Type == 'Entry':
            new_type = 'Exit'

        # Create Record
        new_scan = Attendance(
            Student_ID=student_id,
            Card_ID="APP_SIMULATION",
            Time_Scanned_Date=datetime.utcnow(),
            Scan_Type=new_type 
        )

        db.session.add(new_scan)
        db.session.commit()

        return jsonify({
            "message": "Scan recorded successfully", 
            "type": new_type,
            "timestamp": str(new_scan.Time_Scanned_Date)
        }), 201

    except Exception as e:
        return jsonify({"message": "Error recording scan", "error": str(e)}), 500


# GET STUDENT HISTORY
@Login_Signup_bp.route("/Get_Attendance/<int:student_id>", methods=['GET'])
def Get_Attendance(student_id):
    try:
        logs = Attendance.query.filter_by(Student_ID=student_id).order_by(Attendance.Time_Scanned_Date.desc()).all()
        
        history_list = []
        for log in logs:
            history_list.append({
                "Attendance_ID": log.Attendance_ID,
                "Time": log.Time_Scanned_Date.strftime("%Y-%m-%d %H:%M:%S"),
                "Type": log.Scan_Type 
            })

        return jsonify({"history": history_list}), 200

    except Exception as e:
        return jsonify({"message": "Error fetching history", "error": str(e)}), 500


# =======================================================
#       ADMIN MANAGEMENT & LINKING ROUTES (NEW)
# =======================================================

# 1. PI HEARTBEAT (Pi sends this to say "I'm alive")
@Login_Signup_bp.route('/Heartbeat', methods=['POST'])
def heartbeat():
    global last_heartbeat
    last_heartbeat = datetime.utcnow()
    return jsonify({"status": "alive"})

# 2. SYSTEM STATUS (Flutter checks this for Green/Red dot)
#    AND PI CHECKS THIS TO KNOW IF IT SHOULD LINK OR SCAN ATTENDANCE
@Login_Signup_bp.route('/System_Status', methods=['GET'])      # <--- For Flutter
@Login_Signup_bp.route('/Get_Linking_Status', methods=['GET']) # <--- For Raspberry Pi
def get_system_status():
    global last_heartbeat, linking_target_student_id
    
    # 1. Check if Pi is online
    is_online = False
    if last_heartbeat:
        # If Pi pinged in the last 10 seconds, it's online
        delta = datetime.utcnow() - last_heartbeat
        if delta.total_seconds() < 10:
            is_online = True
            
    # 2. Return Status
    return jsonify({
        "pi_connected": is_online,
        "linking_mode": linking_target_student_id is not None, # True if waiting for link
        "student_id": linking_target_student_id               # The Pi NEEDS this ID
    })

# 3. SET LINKING MODE (Flutter sets "Next scan belongs to Student X")
@Login_Signup_bp.route('/Set_Linking_Mode', methods=['POST'])
def set_linking_mode():
    global linking_target_student_id
    data = request.get_json()
    
    # Send student_id to start linking, or null to stop
    linking_target_student_id = data.get("student_id")
    
    status = "started" if linking_target_student_id else "stopped"
    return jsonify({"message": f"Linking mode {status} for Student {linking_target_student_id}"})

# 4. RFID BUFFER & AUTO-LINKING & ATTENDANCE LOGIC
@Login_Signup_bp.route('/Scan_Card_To_Buffer', methods=['POST'])
def scan_card_to_buffer():
    """
    Handles ALL card scans.
    Requires 'card_id'.
    Optional 'source': 'BUS' or 'ADMIN'.
    """
    global latest_scanned_card, linking_target_student_id
    
    data = request.get_json()
    card_id = data.get("card_id")
    source = data.get("source", "ADMIN") # Default to ADMIN if not sent (e.g., old script)
    
    # Update global buffer (helpful for debugging)
    latest_scanned_card = card_id

    print(f" >>> SCANNED: {card_id} | SOURCE: {source}")

    # --- LOGIC A: LINKING MODE ---
    # Only link if the scan came from ADMIN and linking is active.
    # We DO NOT let the Bus link cards.
    if source != 'BUS' and linking_target_student_id is not None:
        try:
            student = Student.query.get(linking_target_student_id)
            if student:
                student.Card_ID = card_id
                db.session.commit()
                
                # Turn off linking mode
                linking_target_student_id = None 
                
                return jsonify({
                    "message": "LINK_SUCCESS", 
                    "card_id": card_id, 
                    "student": student.Student_Name,
                    "type": "LINKING"
                })
        except Exception as e:
            return jsonify({"error": str(e)}), 500

    # --- LOGIC B: ATTENDANCE MODE ---
    # If not linking (or if it's the Bus), it's attendance.
    try:
        # 1. Find who owns this card
        student = Student.query.filter_by(Card_ID=card_id).first()
        
        if student:
            # 2. Check their last scan today to toggle Entry/Exit
            today_start = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)
            
            last_scan = Attendance.query.filter(
                Attendance.Student_ID == student.Student_ID,
                Attendance.Time_Scanned_Date >= today_start
            ).order_by(Attendance.Time_Scanned_Date.desc()).first()

            # Default is Entry
            new_type = 'Entry'
            # If they already entered, now they are exiting
            if last_scan and last_scan.Scan_Type == 'Entry':
                new_type = 'Exit'

            # 3. Create the Attendance Record
            new_scan = Attendance(
                Student_ID=student.Student_ID,
                Card_ID=card_id,
                Time_Scanned_Date=datetime.utcnow(),
                Scan_Type=new_type 
            )

            db.session.add(new_scan)
            db.session.commit()

            print(f"✅ ATTENDANCE: {student.Student_Name} - {new_type}")
            
            return jsonify({
                "message": "ATTENDANCE_RECORDED",
                "student": student.Student_Name,
                "type": new_type,
                "time": str(new_scan.Time_Scanned_Date)
            })

        else:
            print(f"⚠️ UNKNOWN CARD: {card_id}")
            return jsonify({"message": "UNKNOWN_CARD", "card_id": card_id, "type": "ERROR"}), 404

    except Exception as e:
        return jsonify({"error": str(e)}), 500


# 5. SEARCH STUDENT
@Login_Signup_bp.route('/Search_Student', methods=['GET'])
def search_student():
    query_name = request.args.get('name', '').strip()
    
    if not query_name:
        students = Student.query.all()
    else:
        students = Student.query.filter(Student.Student_Name.ilike(f"%{query_name}%")).all()

    results = []
    for s in students:
        results.append({
            "Student_ID": s.Student_ID,
            "Student_Name": s.Student_Name,
            "Email": s.Email,
            "Locations": s.Locations if hasattr(s, 'Locations') else "N/A",
            "Card_ID": s.Card_ID if hasattr(s, 'Card_ID') else None 
        })
    
    return jsonify({"students": results})


# 6. DELETE STUDENT
@Login_Signup_bp.route('/Delete_Student/<int:student_id>', methods=['DELETE'])
def delete_student(student_id):
    student = Student.query.get(student_id)
    if not student:
        return jsonify({"error": "Student not found"}), 404
    
    try:
        db.session.delete(student)
        db.session.commit()
        return jsonify({"message": "Student deleted successfully"})
    except Exception as e:
        return jsonify({"error": str(e)}), 500


# 7. ASSIGN CARD (Manual Backup)
# 7. ASSIGN CARD (Manual Backup & Smart Scanner Link)
@Login_Signup_bp.route('/Assign_Card', methods=['POST'])
def assign_card():
    # ⚠️ FIX: We need to access this global to turn it off
    global latest_scanned_card, linking_target_student_id
    
    data = request.get_json()
    student_id = data.get("student_id")
    card_id = data.get("card_id")

    student = Student.query.get(student_id)
    if not student:
        return jsonify({"error": "Student not found"}), 404

    try:
        student.Card_ID = card_id
        db.session.commit()
        
        # ⚠️ CRITICAL FIX: Turn off the "Linking Mode" switch
        linking_target_student_id = None 
        latest_scanned_card = None 
        
        print(f" >>> CARD LINKED: {card_id} to Student {student_id}. Mode reset.")
        
        return jsonify({"message": "Card linked successfully"})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# 8. GET DETAILS FOR STUDENT SCREEN
# 8. GET DETAILS FOR STUDENT SCREEN
@Login_Signup_bp.route('/Get_Student_Profile_And_Logs/<int:student_id>', methods=['GET'])
def get_student_profile_and_logs(student_id):
    student = Student.query.get(student_id)
    if not student:
        return jsonify({"error": "Student not found"}), 404

    logs = Attendance.query.filter_by(Student_ID=student_id).order_by(Attendance.Time_Scanned_Date.desc()).all()
    
    history_list = []
    for log in logs:
        history_list.append({
            "Scan_Type": log.Scan_Type,
            "Date": log.Time_Scanned_Date.strftime("%Y-%m-%d"), 
            "Time": log.Time_Scanned_Date.strftime("%I:%M %p")  
        })

    # --- Stop & Bus Details ---
    stop_name = "Not Selected"
    pickup_time = "--:--"
    if student.pickup_point:
        stop_name = student.pickup_point.Stop_Name
        pickup_time = student.pickup_point.Pickup_Time if student.pickup_point.Pickup_Time else "--:--"

    bus_plate = "N/A"
    driver_name = "Unassigned"
    driver_phone = ""
    if student.bus: 
        bus_plate = student.bus.Plate_Number
        driver_name = student.bus.Driver if student.bus.Driver else "Unassigned"

    return jsonify({
        "student": {
            "Student_Name": student.Student_Name,
            "Student_ID": student.Student_ID,
            
            # 👇 THIS WAS MISSING - ADD THESE TWO LINES 👇
            "Course": student.Course,         
            "Year_Level": student.Year_Level, 
            # 👆 THIS WAS MISSING 👆

            "Assigned_Bus": str(student.Assigned_Bus) if student.Assigned_Bus else "Unassigned",
            "Bus_Location": stop_name,
            "Pickup_Time": pickup_time,
            "Bus_Plate": bus_plate,
            "Driver_Name": driver_name,
            "Driver_Phone": driver_phone
        },
        "attendance_history": history_list
    })

# 9. ADMIN DASHBOARD STATS
@Login_Signup_bp.route('/admin/dashboard', methods=['GET'])
def admin_dashboard():
    date_str = datetime.now().strftime("%B %d, %Y")
    today_start = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)
    
    total_students = Student.query.count()
    present_count = db.session.query(Attendance.Student_ID).filter(
        Attendance.Time_Scanned_Date >= today_start,
        Attendance.Scan_Type == 'Entry'
    ).distinct().count()
    
    pending = total_students - present_count
    progress = (present_count / total_students) if total_students > 0 else 0

    recent_scans = db.session.query(Attendance, Student).join(
        Student, Attendance.Student_ID == Student.Student_ID
    ).order_by(Attendance.Time_Scanned_Date.desc()).limit(5).all()

    live_feed = []
    for scan, student in recent_scans:
        live_feed.append({
            "name": student.Student_Name,
            "action": "Boarded Bus" if scan.Scan_Type == 'Entry' else "Left Bus",
            "time": scan.Time_Scanned_Date.strftime("%I:%M %p"),
            "is_entry": scan.Scan_Type == 'Entry'
        })

    return jsonify({
        "date_str": date_str,
        "stats": {
            "present": present_count,
            "total_expected": total_students,
            "pending": pending,
            "progress": progress
        },
        "live_feed": live_feed
    })