import requests

# ⚠️ Make sure this matches your Flask Server IP
SERVER_URL = "http://127.0.0.1:5000" 

def simulate_admin_scan():
    # 1. Simulate scanning a card on the ADMIN PC
    card_id = "CARD_99999" # Test ID
    
    print(f"Simulating Scan of: {card_id}")
    
    payload = {
        "card_id": card_id,
        "source": "ADMIN" # <--- IMPORTANT: Tells server to apply the link!
    }
    
    try:
        response = requests.post(f"{SERVER_URL}/Scan_Card_To_Buffer", json=payload)
        print("Server Response:", response.json())
    except Exception as e:
        print("Error:", e)

if __name__ == "__main__":
    simulate_admin_scan()