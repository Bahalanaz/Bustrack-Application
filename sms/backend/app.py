import os
import socket
import threading
from flask import Flask
from flask_cors import CORS 
from databases_flask_connection import db
from flask_jwt_extended import JWTManager

# --- BLUEPRINT IMPORTS ---
from routes import Login_Signup_bp 
from attendance_analytics import attendance_analytics_bp 
from student_actions import student_actions_bp 
from fleet_management import fleet_bp 
from finance_management import finance_bp 
from reports_management import reports_bp 

app = Flask(__name__)

# ENABLE CORS
CORS(app) 

# CONFIGURATION
basedir = os.path.abspath(os.path.dirname(__file__))
db_path = os.path.join(basedir, 'bus_system.db')
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///' + db_path

app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['JWT_SECRET_KEY'] = 'super-secret-key' 

# INITIALIZE DB
db.init_app(app)
jwt = JWTManager(app)

# REGISTER BLUEPRINTS
app.register_blueprint(Login_Signup_bp)
app.register_blueprint(attendance_analytics_bp)
app.register_blueprint(student_actions_bp)
app.register_blueprint(fleet_bp) 
app.register_blueprint(finance_bp) 
app.register_blueprint(reports_bp)

# CREATE TABLES (Run once)
with app.app_context():
    db.create_all()

# ========================================================
# 📡 AUTO-DISCOVERY RESPONDER (Added for Raspberry Pi)
# ========================================================
# This allows the Pi to shout "Who is admin?" and your 
# laptop to reply "I am admin" automatically.
DISCOVERY_PORT = 5001
DISCOVERY_MESSAGE = "Who is admin?"

def discovery_responder():
    """Listens for Pi discovery broadcasts and replies with IP."""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.bind(("", DISCOVERY_PORT))
        print(f"📡 Discovery Service Listening on Port {DISCOVERY_PORT}...")
        
        while True:
            data, addr = s.recvfrom(1024)
            if data.decode() == DISCOVERY_MESSAGE:
                # Reply with "I am admin" so Pi knows this is the server
                s.sendto(b"I am admin", addr)
    except Exception as e:
        print(f"⚠️ Discovery Error: {e}")

if __name__ == '__main__':
    # 1. Start the Discovery Thread in the background
    threading.Thread(target=discovery_responder, daemon=True).start()
    
    # 2. Start the Flask Server
    # Host='0.0.0.0' is required for external devices (Pi/Phone) to connect!
    app.run(debug=True, host='0.0.0.0', port=5000, use_reloader=False)