import requests
import time
import threading

# ⚠️ REPLACE WITH YOUR LAPTOP'S IP ADDRESS (e.g. 192.168.1.15)
# Do not use localhost if running on a real Pi
# If testing on the SAME PC as the server:
# Remove ALL spaces inside the quotes
SERVER_URL = "http://192.168.8.18:5000"
def send_heartbeat():
    """Tells the server 'I am online' every 5 seconds"""
    while True:
        try:
            requests.post(f"{SERVER_URL}/Heartbeat", timeout=2)
            # print("Heartbeat sent")
        except:
            print("Server unreachable (Heartbeat)")
        time.sleep(5)

# Start heartbeat in the background
threading.Thread(target=send_heartbeat, daemon=True).start()

def main():
    print(f"🚗 Bus Scanner Started... Connecting to {SERVER_URL}")
    
    # --- IF USING REAL PI HARDWARE (Uncomment below) ---
    # from mfrc522 import SimpleMFRC522
    # reader = SimpleMFRC522()
    
    try:
        while True:
            # --- OPTION A: REAL SENSOR ---
            # print("Place card...")
            # id, text = reader.read()
            # card_id = str(id)
            
            # --- OPTION B: KEYBOARD SIMULATION (For Testing on PC) ---
            card_id = input("Enter Card ID to Simulate Scan: ")

            print(f"Card Detected: {card_id}")
            
            # Send to Backend
            try:
                requests.post(f"{SERVER_URL}/Scan_Card_To_Buffer", json={"card_id": card_id})
                print(">> Sent to Server")
            except Exception as e:
                print(f"Failed to send: {e}")
            
            # time.sleep(2) # Anti-bounce delay

    except KeyboardInterrupt:
        print("\nStopping...")
        # GPIO.cleanup()

if __name__ == "__main__":
    main()