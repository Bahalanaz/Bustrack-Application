import requests
import time
import sys

# Ensure we are pointing to localhost since this runs on your PC
SERVER_URL = "http://127.0.0.1:5000"

def main():
    print(">>> VIRTUAL BUS SCANNER STARTED")
    print(f">>> Connecting to: {SERVER_URL}")
    print("------------------------------------------------")

    while True:
        try:
            # 1. Ask for input
            card_id = input("\nEnter Card ID to Scan (or 'q' to quit): ")

            if card_id.lower() == 'q':
                print("Exiting...")
                break

            if not card_id.strip():
                continue

            # 2. Send to Server
            print(f"Sending Card {card_id}...")
            response = requests.post(f"{SERVER_URL}/Scan_Card_To_Buffer", json={"card_id": card_id})

            # 3. Handle Response
            if response.status_code == 200:
                data = response.json()
                print(f">> SUCCESS! Server Message: {data.get('message')}")
                
                if 'student' in data:
                    print(f"   Student Name: {data['student']}")
                if 'type' in data:
                    print(f"   Action Type:  {data['type']}")
            else:
                print(f">> ERROR: Server returned {response.status_code}")

        except requests.exceptions.ConnectionError:
            print(">> CONNECTION FAILED: Make sure 'app.py' is running!")
        except Exception as e:
            print(f">> ERROR: {e}")

if __name__ == "__main__":
    main()