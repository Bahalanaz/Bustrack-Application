from flask_sqlalchemy import SQLAlchemy
from datetime import datetime, date

db = SQLAlchemy()

# ---------------- Bus Table ----------------
class Bus(db.Model):
    __tablename__ = 'Bus'
    Bus_ID = db.Column(db.Integer, primary_key=True, autoincrement=True)
    Plate_Number = db.Column(db.String(15), unique=True)
    Driver = db.Column(db.String(25)) 
    Bus_Assigned_Location = db.Column(db.String(25)) # General Area (e.g. "Dubai")
    Bus_Status = db.Column(db.Enum('In-service','Unavailable','Stand by', 'Maintenance'))
    Num_Students_assigned = db.Column(db.Integer, default=0)
    Capacity = db.Column(db.Integer, default=30)
    
    # Relationships
    students = db.relationship('Student', backref='bus', lazy=True)
    stops = db.relationship('BusStop', backref='assigned_bus', lazy=True) # <--- NEW: Access route stops

# ---------------- Bus Stop Table (NEW) ----------------
class BusStop(db.Model):
    __tablename__ = 'BusStops'
    Stop_ID = db.Column(db.Integer, primary_key=True, autoincrement=True)
    Stop_Name = db.Column(db.String(50), nullable=False) # e.g. "BurJuman Metro Exit 2"
    Area_Name = db.Column(db.String(50), nullable=False) # e.g. "Bur Dubai"
    Pickup_Time = db.Column(db.String(10)) # Optional: e.g. "07:30 AM"
    
    # Link to Bus (A stop belongs to one Bus Route)
    Bus_ID = db.Column(db.Integer, db.ForeignKey('Bus.Bus_ID'), nullable=False)

# ---------------- Drivers Table ----------------
class Driver(db.Model):
    __tablename__ = 'Drivers'
    Driver_ID = db.Column(db.Integer, primary_key=True, autoincrement=True)
    Driver_Name = db.Column(db.String(50), nullable=False)
    Phone_Number = db.Column(db.String(20), nullable=False)
    License_Expiry = db.Column(db.String(20)) 
    Status = db.Column(db.Enum('On Shift', 'Off Duty'), default='Off Duty')

# ---------------- Students Table ----------------
class Student(db.Model):
    __tablename__ = 'Students'
    Student_ID = db.Column(db.Integer, primary_key=True, autoincrement=True)
    Student_Name = db.Column(db.String(50))
    Student_Username = db.Column(db.String(50))
    Student_Password = db.Column(db.String(50))
    Phone_number = db.Column(db.String(20), unique=True, nullable=False)
    Email = db.Column(db.String(50), unique=True, nullable=False)
    Enrolment = db.Column(db.Enum('Paid','Pending'), default='Pending')
    Bus_fees = db.Column(db.Enum('Paid','Pending'), default='Pending')
    Course = db.Column(db.String(50))
    Year_Level = db.Column(db.String(50))
    
    # Bus Logic
    Assigned_Bus = db.Column(db.Integer, db.ForeignKey('Bus.Bus_ID'), default=None)
    
    # NEW: Specific Stop Selection
    Bus_Stop_ID = db.Column(db.Integer, db.ForeignKey('BusStops.Stop_ID'), default=None)
    pickup_point = db.relationship('BusStop', backref='students_at_stop', lazy=True) 

    Locations = db.Column(db.String(100)) # Keeping for legacy support (optional)
    Card_ID = db.Column(db.String(50), unique=True)

    @property
    def Eligibility(self):
        return 'Valid' if self.Enrolment == 'Paid' and self.Bus_fees == 'Paid' else 'Invalid'

# ---------------- Admins Table ----------------
class Admins(db.Model):
    __tablename__ = 'Admins'
    Admin_ID = db.Column(db.Integer, primary_key=True, autoincrement=True)
    Admin_Name = db.Column(db.String(50), nullable=False)
    Admin_Username = db.Column(db.String(50), unique=True, nullable=False)
    Admin_Password = db.Column(db.String(50), nullable=False)
    Admin_Number = db.Column(db.String(20), unique=True, nullable=False)
    Email = db.Column(db.String(50), unique=True, nullable=False)
    Admin_Account_Status = db.Column(db.Enum('Valid', 'Invalid'), default='Invalid')

# ---------------- Attendance Table ----------------
class Attendance(db.Model):
    __tablename__ = 'Attendance'
    Attendance_ID = db.Column(db.Integer, primary_key=True, autoincrement=True)
    Student_ID = db.Column(db.Integer, db.ForeignKey('Students.Student_ID'))
    Card_ID = db.Column(db.String(50)) 
    Time_Scanned_Date = db.Column(db.DateTime, default=datetime.utcnow)
    Scan_Type = db.Column(db.String(10)) 

# ---------------- Reports Table (Support Tickets) ----------------
class Report(db.Model):
    __tablename__ = 'Reports'
    Report_ID = db.Column(db.Integer, primary_key=True, autoincrement=True)
    Student_ID = db.Column(db.Integer, db.ForeignKey('Students.Student_ID'))
    Assigned_Bus = db.Column(db.String(50))
    Report_Category = db.Column(db.String(50)) 
    Descriptions = db.Column(db.String(250))
    Admin_Comment = db.Column(db.String(250)) 
    Date_Submitted = db.Column(db.DateTime, default=datetime.utcnow)

# ---------------- Exceptions Table (Transport Requests) ----------------
class Exceptions(db.Model):
    __tablename__ = 'Exceptions'
    Exceptions_ID = db.Column(db.Integer, primary_key=True, autoincrement=True)
    Student_ID = db.Column(db.Integer, db.ForeignKey('Students.Student_ID'))
    Date_Request = db.Column(db.Date, default=date.today)
    Descriptions = db.Column(db.String(250))
    Admin_Comment = db.Column(db.String(250))
    Date_Submitted = db.Column(db.DateTime, default=datetime.utcnow)
    Permission = db.Column(db.String(20), default='Pending')

# ---------------- Student Timetable ----------------
class Student_Timetable(db.Model):
    __tablename__ = 'Student_Timetable'
    ST_ID = db.Column(db.Integer, primary_key=True, autoincrement=True)
    Student_ID = db.Column(db.Integer, db.ForeignKey('Students.Student_ID', ondelete='CASCADE'), nullable=False)
    day = db.Column(db.Enum('Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'), nullable=False)
    active = db.Column(db.Boolean, default=False)
    student = db.relationship('Student', backref=db.backref('timetable_entries', lazy=True))
    
    __table_args__ = (db.UniqueConstraint('Student_ID', 'day', name='unique_student_day'),)