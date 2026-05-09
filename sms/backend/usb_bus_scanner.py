import requests
import time
import threading
import sys

# ⚠️ REPLACE WITH YOUR LAPTOP'S IP ADDRESS
# Ensure your Pi and Laptop are on the same WiFi
SERVER_URL = "http://192.168.1.53:5000"

def send_heartbeat():
    """
    Tells the server 'I am online' every 5 seconds.
    The Admin Dashboard will show a Green Dot.
    """
    while True:
        try:
            requests.post(f"{SERVER_URL}/Heartbeat", timeout=2)
        except:
            # Silent fail so we don't spam the console
            pass
        time.sleep(5)

def main():
    print(f"🚗 USB BUS SCANNER STARTED")
    print(f"📡 Connecting to: {SERVER_URL}")
    print("--------------------------------")
    print("Plug in the USB Reader and scan a card...")

    # Start Heartbeat in background
    threading.Thread(target=send_heartbeat, daemon=True).start()

    while True:
        try:
            # 1. READ CARD
            # The USB reader types the number and hits 'Enter', 
            # so input() catches it perfectly.
            card_id = input() 

            if not card_id.strip():
                continue

            print(f"🔔 Card Detected: {card_id}")
            
            # 2. PREPARE PAYLOAD
            # We send 'source': 'BUS' so the server knows:
            # "Do NOT link this card to a student profile, just mark attendance."
            payload = {
                "card_id": card_id,
                "source": "BUS" 
            }

            # 3. SEND TO SERVER
            try:
                response = requests.post(f"{SERVER_URL}/Scan_Card_To_Buffer", json=payload, timeout=3)
                
                if response.status_code == 200:
                    data = response.json()
                    student_name = data.get('student', 'Unknown')
                    scan_type = data.get('type', 'Action')
                    
                    print(f">> ✅ SUCCESS: {student_name} ({scan_type})")
                    
                elif response.status_code == 404:
                     print(f">> ❌ Unregistered Card")
                else:
                    print(f">> ⚠️ Server Error: {response.status_code}")

            except requests.exceptions.ConnectionError:
                print(f">> ❌ FAILED: Cannot connect to {SERVER_URL}. Check WiFi/IP.")
            except Exception as e:
                print(f">> ❌ ERROR: {e}")
            
            # Tiny delay to prevent double-scanning
            time.sleep(1)

        except KeyboardInterrupt:
            print("\nStopping...")
            sys.exit(0)

if __name__ == "__main__":
    main()