import requests
import sys

# Localhost because this runs on your Dev PC
SERVER_URL = "http://127.0.0.1:5000"

def main():
    print(">>> 👨‍💻 ADMIN / VIRTUAL SCANNER STARTED")
    print(f">>> Connecting to: {SERVER_URL}")
    print("------------------------------------------------")

    while True:
        try:
            card_id = input("\nEnter Card ID to Scan (or 'q' to quit): ")

            if card_id.lower() == 'q':
                print("Exiting...")
                break

            if not card_id.strip():
                continue

            # SEND TO SERVER AS 'ADMIN'
            print(f"Sending Card {card_id}...")
            
            payload = {
                "card_id": card_id,
                "source": "ADMIN" # <--- CRITICAL UPDATE
            }
            
            response = requests.post(f"{SERVER_URL}/Scan_Card_To_Buffer", json=payload)

            # Handle Response
            if response.status_code == 200:
                data = response.json()
                print(f">> SUCCESS! {data.get('message')}")
                
                if 'student' in data:
                    print(f"   Student: {data['student']}")
                if 'type' in data:
                    print(f"   Action:  {data['type']}") # Will say 'LINKING' or 'INFO'
            else:
                print(f">> ERROR: Server returned {response.status_code}")

        except requests.exceptions.ConnectionError:
            print(">> CONNECTION FAILED: Make sure 'app.py' is running!")
        except Exception as e:
            print(f">> ERROR: {e}")

if __name__ == "__main__":
    main()