import requests
import time
import threading
import sys

# ⚠️ REPLACE WITH YOUR LAPTOP'S IP ADDRESS (e.g. 192.168.1.53)
SERVER_URL = "http://192.168.1.53:5000"

def send_heartbeat():
    """Tells the server 'I am online' every 5 seconds"""
    while True:
        try:
            requests.post(f"{SERVER_URL}/Heartbeat", timeout=2)
        except:
            print("Server unreachable (Heartbeat)")
        time.sleep(5)

# Start heartbeat in the background
threading.Thread(target=send_heartbeat, daemon=True).start()

def main():
    print(f"🚗 BUS SCANNER STARTED... Connecting to {SERVER_URL}")
    
    # --- UNCOMMENT FOR REAL PI ---
    # from mfrc522 import SimpleMFRC522
    # reader = SimpleMFRC522()
    
    try:
        while True:
            # --- OPTION A: REAL SENSOR ---
            # id, text = reader.read()
            # card_id = str(id)
            
            # --- OPTION B: KEYBOARD (Testing) ---
            card_id = input("Enter Card ID (Bus Mode): ")

            if not card_id.strip(): continue

            print(f"Card Detected: {card_id}")
            
            # SEND TO SERVER AS 'BUS'
            try:
                payload = {
                    "card_id": card_id, 
                    "source": "BUS"  # <--- CRITICAL UPDATE
                }
                response = requests.post(f"{SERVER_URL}/Scan_Card_To_Buffer", json=payload)
                
                if response.status_code == 200:
                    data = response.json()
                    print(f">> ✅ {data.get('message')} ({data.get('student', 'Unknown')})")
                else:
                    print(f">> ❌ Server Error: {response.status_code}")
                    
            except Exception as e:
                print(f"Failed to send: {e}")
            
            # time.sleep(2) # Anti-bounce

    except KeyboardInterrupt:
        print("\nStopping...")

if __name__ == "__main__":
    main()