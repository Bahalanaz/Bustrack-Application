# ------------------------ Backend Admin Flask ------------------------

from flask import Flask, request, jsonify
from flask_sqlalchemy import SQLAlchemy
import socket
import threading

app = Flask(__name__)

# ------------------------ DATABASE CONFIG ------------------------
app.config['SQLALCHEMY_DATABASE_URI'] = (
    'mysql+mysqlconnector://2Vw36VoAqmWrKcM.root:fyLhwjpY2c978Is7'
    '@gateway01.eu-central-1.prod.aws.tidbcloud.com:4000/db_bustrack'
    '?ssl_ca=C:\\Users\\maram\\OneDrive\\Desktop\\PROJECTS CODES\\isrgrootx1.pem'
)
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
db = SQLAlchemy(app)

# ------------------------ DATABASE MODELS ------------------------
class Student(db.Model):
    __tablename__ = 'Students'
    Student_ID = db.Column(db.Integer, primary_key=True, autoincrement=True)    
    Student_Name = db.Column(db.String(50))
    Student_Username = db.Column(db.String(50))
    Student_Password = db.Column(db.String(50))
    Phone_Number = db.Column(db.String(20), unique=True, nullable=False)
    Email = db.Column(db.String(50), unique=True, nullable=False)
    Enrolment = db.Column(db.Enum('Paid', 'Pending'), default='Pending')
    Bus_fees = db.Column(db.Enum('Paid', 'Pending'), default='Pending')
    Course = db.Column(db.String(50))
    Year_Level = db.Column(db.String(50))
    
    # Re-added foreign key to Bus table
    Assigned_Bus = db.Column(db.Integer, db.ForeignKey('Bus.Bus_ID'), nullable=True)
    
    Locations = db.Column(db.String(100))
    Card_ID = db.Column(db.String(50), unique=True)

    # Relationship to Bus (optional, useful for ORM queries)
    bus = db.relationship('Bus', backref=db.backref('students', lazy=True))
    
    @property
    def Eligibility(self):
        return 'Valid' if self.Enrolment == 'Paid' and self.Bus_fees == 'Paid' else 'Invalid'


# ------------------------ LINKING MODE ------------------------
linking_active = False
linking_student_id = None

# ------------------------ ROUTES ------------------------
@app.route('/Start_Linking', methods=['POST'])
def start_linking():
    global linking_active, linking_student_id
    data = request.get_json()
    student_id = data.get("student_id")
    student = Student.query.get(student_id)
    if not student:
        return jsonify({"error": f"Student {student_id} not found"}), 404
    linking_student_id = student_id
    linking_active = True
    return jsonify({"message": "Linking mode activated", "student_id": linking_student_id})

@app.route('/Get_Linking_Status', methods=['GET'])
def get_linking_status():
    return jsonify({"linking_mode": linking_active, "student_id": linking_student_id})

@app.route('/Assign_Card', methods=['POST'])
def assign_card():
    global linking_active, linking_student_id
    data = request.get_json()
    student_id = data.get("student_id")
    card_id = data.get("card_id")
    try:
        student = Student.query.get(student_id)
        if not student:
            return jsonify({"error": "Student not found"}), 404
        student.Card_ID = card_id
        db.session.commit()
        linking_active = False
        linking_student_id = None
        return jsonify({"message": f"Card {card_id} assigned to student {student_id} successfully!"})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/Search_Student', methods=['GET'])
def search_student():
    query_name = request.args.get('name', '').strip()
    query_id = request.args.get('id', '').strip()
    if not query_name and not query_id:
        return jsonify({"error": "Please provide a search name or student ID"}), 400
    query = Student.query
    if query_id:
        if not query_id.isdigit():
            return jsonify({"error": "Student ID must be a number"}), 400
        query = query.filter(Student.Student_ID == int(query_id))
    if query_name:
        query = query.filter(Student.Student_Name.ilike(f"%{query_name}%"))
    matching_students = query.all()
    results = [
        {"Student_ID": s.Student_ID, "Student_Name": s.Student_Name, "Card_ID": s.Card_ID, "Email": s.Email}
        for s in matching_students
    ]
    return jsonify({"students": results})

# ------------------------ BACKEND IP AUTO-DETECTION ------------------------
@app.route('/Get_Backend_IP', methods=['GET'])
def get_backend_ip():
    hostname = socket.gethostname()
    local_ip = socket.gethostbyname(hostname)
    return jsonify({"ip": local_ip})

# ------------------------ DISCOVERY RESPONDER ------------------------
DISCOVERY_PORT = 5001
DISCOVERY_MESSAGE = "Who is admin?"

def discovery_responder():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.bind(("", DISCOVERY_PORT))
    while True:
        data, addr = s.recvfrom(1024)
        if data.decode() == DISCOVERY_MESSAGE:
            s.sendto(b"I am admin", addr)

threading.Thread(target=discovery_responder, daemon=True).start()

# ------------------------ MAIN ------------------------
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=False)

# FRONTEND NOTES for START LINKING:
# - Endpoint: POST /Start_Linking
# - Request body: JSON with student ID
#   {
#       "student_id": 1
#   }
# - Success: 200 response with message and "student_id"
# - Failure: 404 if student not found, 500 if server error
# - Frontend should trigger this when user wants to link a card to a student
# - After success, the Raspberry Pi will be in linking mode and ready to receive card scans

# FRONTEND NOTES for GET LINKING STATUS:
# - Endpoint: GET /Get_Linking_Status
# - Success: 200 response with JSON
#   {
#       "linking_mode": true/false,
#       "student_id": <id> or null
#   }
# - Frontend should poll this endpoint to know whether linking mode is active
# - Useful for showing UI state: e.g., "Scan card now" message

# FRONTEND NOTES for ASSIGN CARD:
# - Endpoint: POST /Assign_Card
# - Request body: JSON
#   {
#       "student_id": 1,
#       "card_id": "RFID123456"
#   }
# - Success: 200 response with confirmation message
# - Failure: 404 if student not found, 500 if server error
# - Frontend typically does NOT call this directly unless simulating a scan
# - Normally, the Raspberry Pi sends the card automatically when in linking mode

# FRONTEND NOTES for SEARCH STUDENT:
# - Endpoint: GET /Search_Student
# - Query parameters: either "name" or "id" (or both)
#   Example: /Search_Student?name=Alice&id=1
# - Success: 200 response with JSON array of matching students
#   [
#       {"Student_ID": 1, "Student_Name": "Alice Smith", "Card_ID": "RFID123456", "Email": "alice@example.com"},
#       ...
#   ]
# - Failure: 400 if no parameters provided
# - Frontend should display matching students for selection or information

# FRONTEND NOTES for GET BACKEND IP:
# - Endpoint: GET /Get_Backend_IP
# - Success: 200 response with JSON
#   {
#       "ip": "192.168.1.100"
#   }
# - Frontend can use this to display or configure the Pi to communicate with backend
# - Mostly used for auto-discovery/debugging, not required for normal card linking
