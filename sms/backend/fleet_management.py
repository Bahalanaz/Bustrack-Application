from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required
from databases_flask_connection import db, Bus, Driver, Student, BusStop
from utils import admin_required

fleet_bp = Blueprint('fleet', __name__)

# ==============================================================================
#                                BUS MANAGEMENT
# ==============================================================================

@fleet_bp.route('/admin/fleet/buses', methods=['GET'])
@admin_required()
def get_all_buses():
    """
    Used for the Fleet List Screen.
    """
    try:
        buses = Bus.query.all()
        output = []
        for bus in buses:
            output.append({
                "id": f"B{bus.Bus_ID:03d}", # e.g. B001
                "db_id": bus.Bus_ID,
                "plate": bus.Plate_Number,
                "model": "Toyota Coaster", 
                "status": bus.Bus_Status,
                "capacity": str(bus.Capacity),
                "driver": bus.Driver if bus.Driver else "Unassigned"
            })
        return jsonify(output), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@fleet_bp.route('/admin/fleet/bus', methods=['POST'])
@admin_required()
def add_bus():
    try:
        data = request.get_json()
        
        plate = data.get('plate')
        capacity = data.get('capacity', 30)
        status = data.get('status', 'In-service')
        
        if not plate:
            return jsonify({'error': 'Plate number is required'}), 400
            
        # Check duplicate
        if Bus.query.filter_by(Plate_Number=plate).first():
            return jsonify({'error': 'Bus with this plate already exists'}), 409

        new_bus = Bus(
            Plate_Number=plate,
            Capacity=int(capacity),
            Bus_Status=status,
            Driver=None, # Assigned later
            Bus_Assigned_Location="Main Campus", # Default
            Num_Students_assigned=0
        )
        
        db.session.add(new_bus)
        db.session.commit()
        
        return jsonify({'message': 'Bus added successfully'}), 201
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

# ==============================================================================
#                            DRIVER MANAGEMENT
# ==============================================================================

@fleet_bp.route('/admin/fleet/drivers', methods=['GET'])
@admin_required()
def get_all_drivers():
    try:
        drivers = Driver.query.all()
        output = []
        for d in drivers:
            output.append({
                "id": d.Driver_ID,
                "name": d.Driver_Name,
                "phone": d.Phone_Number,
                "license": f"Exp: {d.License_Expiry}",
                "status": d.Status
            })
        return jsonify(output), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@fleet_bp.route('/admin/fleet/driver', methods=['POST'])
@admin_required()
def add_driver():
    try:
        data = request.get_json()
        
        name = data.get('name')
        phone = data.get('phone')
        license_expiry = data.get('license') # e.g. "2026"
        
        # 1. Get status from App (or default to 'On Shift')
        sent_status = data.get('status', 'On Shift')

        # 2. FIX MISMATCH: Database only accepts 'On Shift', but App sends 'On Duty'
        # We manually convert it here to prevent a database error.
        if sent_status == 'On Duty':
            db_status = 'On Shift'
        else:
            db_status = sent_status

        if not name or not phone:
            return jsonify({'error': 'Name and Phone are required'}), 400

        new_driver = Driver(
            Driver_Name=name,
            Phone_Number=phone,
            License_Expiry=license_expiry,
            Status=db_status  # <--- Uses the corrected status
        )
        
        db.session.add(new_driver)
        db.session.commit()
        
        return jsonify({'message': 'Driver added successfully'}), 201
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@fleet_bp.route('/admin/fleet/bus/assign-driver', methods=['POST'])
@admin_required()
def assign_driver_to_bus():
    """
    Updates the 'Driver' column for a specific Bus.
    Accepts: { "bus_id": 1, "driver_name": "Ahmed Al-Farsi" }
    """
    try:
        data = request.get_json()
        bus_id = data.get('bus_id')
        driver_name = data.get('driver_name') 

        if not bus_id or not driver_name:
            return jsonify({'error': 'Bus ID and Driver Name are required'}), 400

        bus = Bus.query.get(bus_id)
        if not bus:
             return jsonify({'error': 'Bus not found'}), 404

        bus.Driver = driver_name
        db.session.commit()

        return jsonify({'message': 'Driver assigned successfully'}), 200

    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

# ==============================================================================
#                        ROUTE & STOP MANAGEMENT (NEW)
# ==============================================================================

@fleet_bp.route('/admin/routes', methods=['GET'])
@admin_required()
def get_active_routes():
    """
    Used for "Route Management Screen" -> "Active Routes" Tab.
    Calculates live stats for students and stops.
    """
    try:
        buses = Bus.query.all()
        output = []

        for bus in buses:
            # 1. Count Students Assigned to this Bus
            student_count = Student.query.filter_by(Assigned_Bus=bus.Bus_ID).count()
            
            # 2. Count Stops assigned to this Bus
            stop_count = BusStop.query.filter_by(Bus_ID=bus.Bus_ID).count()

            driver_name = bus.Driver if bus.Driver else "No Driver"

            output.append({
                'id': bus.Bus_ID,
                'title': f"Route {bus.Bus_ID} - {bus.Plate_Number}", 
                'driver': driver_name,
                'bus_number': bus.Plate_Number,
                'stops_count': stop_count,
                'student_count': student_count,
                'capacity': bus.Capacity,
                'status': bus.Bus_Status 
            })

        return jsonify(output), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500


@fleet_bp.route('/admin/stops', methods=['GET'])
@admin_required()
def get_all_stops():
    """
    Used for "Route Management Screen" -> "Bus Stops" Tab.
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
                'pickup_time': stop.Pickup_Time,
                'assigned_bus': bus_plate,
                'bus_id': stop.Bus_ID
            })

        return jsonify(output), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500


@fleet_bp.route('/admin/stop', methods=['POST'])
@admin_required()
def add_bus_stop():
    """
    Adds a new Stop and links it to a Bus.
    """
    try:
        data = request.get_json()
        
        if not data.get('name') or not data.get('bus_id'):
            return jsonify({'error': 'Stop Name and Bus ID are required'}), 400

        new_stop = BusStop(
            Stop_Name=data['name'],
            Area_Name=data.get('area', 'General'),
            Bus_ID=data['bus_id'],
            Pickup_Time=data.get('time', '07:00 AM')
        )

        db.session.add(new_stop)
        db.session.commit()

        return jsonify({'message': 'Bus stop added successfully'}), 201

    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@fleet_bp.route('/admin/bus-list', methods=['GET'])
@admin_required()
def get_bus_dropdown():
    """
    Helper for dropdowns: Returns simple ID and Plate Number.
    """
    try:
        buses = Bus.query.all()
        output = [{'id': b.Bus_ID, 'plate': b.Plate_Number} for b in buses]
        return jsonify(output), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# ==============================================================================
#                       BULK STUDENT ASSIGNMENT
# ==============================================================================

@fleet_bp.route('/admin/fleet/bus/<int:bus_id>', methods=['GET'])
@admin_required()
def get_bus_details(bus_id):
    try:
        bus = Bus.query.get(bus_id)
        if not bus:
            return jsonify({'error': 'Bus not found'}), 404

        # Get passengers
        passengers = []
        for s in bus.students:
            passengers.append({
                'id': s.Student_ID,
                'name': s.Student_Name,
                'location': s.Locations,
                'phone': s.Phone_number
            })

        data = {
            "id": f"B{bus.Bus_ID:03d}",
            "db_id": bus.Bus_ID,
            "plate": bus.Plate_Number,
            "model": "Toyota Coaster",
            "status": bus.Bus_Status,
            "capacity": bus.Capacity,
            "current_load": len(passengers),
            "driver": bus.Driver if bus.Driver else "Unassigned",
            "passengers": passengers
        }
        return jsonify(data), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@fleet_bp.route('/admin/fleet/students/unassigned', methods=['GET'])
@admin_required()
def get_unassigned_students():
    try:
        # Fetch students where Assigned_Bus is None
        students = Student.query.filter(Student.Assigned_Bus == None).all()
        
        output = []
        for s in students:
            output.append({
                'id': s.Student_ID,
                'name': s.Student_Name,
                'location': s.Locations
            })
        return jsonify(output), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@fleet_bp.route('/admin/fleet/bus/assign-bulk', methods=['POST'])
@admin_required()
def bulk_assign_students():
    try:
        data = request.get_json()
        bus_id = data.get('bus_id')
        student_ids = data.get('student_ids') # Expecting a List: [1, 5, 20]

        if not bus_id or not student_ids:
            return jsonify({'error': 'Bus ID and Student IDs are required'}), 400

        bus = Bus.query.get(bus_id)
        if not bus:
            return jsonify({'error': 'Bus not found'}), 404
            
        current_count = len(bus.students)
        if current_count + len(student_ids) > bus.Capacity:
             return jsonify({'error': f'Bus is full! Capacity: {bus.Capacity}, Current: {current_count}'}), 400

        students_to_update = Student.query.filter(Student.Student_ID.in_(student_ids)).all()
        
        for s in students_to_update:
            s.Assigned_Bus = bus_id
            s.Bus_fees = 'Pending'
        
        bus.Num_Students_assigned += len(students_to_update)

        db.session.commit()
        return jsonify({'message': f'Successfully assigned {len(students_to_update)} students'}), 200

    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500