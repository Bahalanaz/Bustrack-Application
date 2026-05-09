import requests
import time
import sys
import threading

# ==========================================
# ⚙️ CONFIGURATION
# ==========================================
# REPLACE with your Laptop's IP (e.g., 192.168.1.53)
SERVER_URL = "http://192.168.8.18:5000"
# ==========================================

def send_heartbeat():
    """Tells the server 'I am online' (Green Dot on Dashboard)"""
    while True:
        try:
            requests.post(f"{SERVER_URL}/Heartbeat", timeout=2)
        except:
            pass
        time.sleep(5)

def main():
    print("\n========================================")
    print("      🚌 UNIBUS HARDWARE SCANNER       ")
    print("========================================")
    print(f"Connecting to: {SERVER_URL}\n")

    # 1. ASK USER TO SELECT MODE
    print("SELECT DEVICE LOCATION:")
    print(" [1] 🚌 School Bus (Attendance Mode)")
    print(" [2] 👨‍💻 Admin Office (Linking Mode)")
    
    choice = input("\nEnter 1 or 2: ").strip()

    current_source = "BUS" # Default
    mode_name = "BUS ATTENDANCE"

    if choice == '2':
        current_source = "ADMIN"
        mode_name = "ADMIN LINKING"
    
    print(f"\n✅ STARTING IN {mode_name} MODE...")
    print(f"Communicating as source: '{current_source}'")
    print("----------------------------------------")
    print("👉 PLUG IN USB READER & SCAN CARD NOW")
    
    # Start Heartbeat in background
    threading.Thread(target=send_heartbeat, daemon=True).start()

    while True:
        try:
            # 2. WAIT FOR USB READER INPUT
            # The reader types the number and hits 'Enter' automatically
            card_id = input() 

            if not card_id.strip(): continue

            print(f"\n🔔 Card Scanned: {card_id}")
            
            # 3. SEND TO SERVER
            payload = {
                "card_id": card_id,
                "source": current_source  # <--- SENDS 'BUS' OR 'ADMIN' BASED ON YOUR CHOICE
            }

            try:
                response = requests.post(f"{SERVER_URL}/Scan_Card_To_Buffer", json=payload, timeout=3)
                
                if response.status_code == 200:
                    data = response.json()
                    msg = data.get('message', 'Success')
                    
                    # PRETTY PRINT THE RESULT
                    if current_source == "ADMIN" and data.get('type') == 'LINKING':
                        print(f"🎉 SUCCESS: Linked to {data.get('student')}!")
                    elif current_source == "BUS":
                        print(f"✅ ATTENDANCE: {data.get('student')} ({data.get('type')})")
                    else:
                        print(f"ℹ️  Info: {msg}")

                elif response.status_code == 404:
                     print(f"❌ Error: Card not registered.")
                else:
                    print(f"⚠️ Server Error: {response.status_code}")

            except requests.exceptions.ConnectionError:
                print(f"❌ FAILED: Could not reach {SERVER_URL}. Is your PC on?")
            except Exception as e:
                print(f"❌ ERROR: {e}")
            
            # Small delay to prevent double-scanning
            time.sleep(1.5)

        except KeyboardInterrupt:
            print("\nStopping...")
            sys.exit(0)

if __name__ == "__main__":
    main()