import requests

base_url = "http://127.0.0.1:8000"
login_url = f"{base_url}/api/auth/members/login/"
initiate_url = f"{base_url}/api/subscriptions/chargily/initiate/"

# Try to login with a test account or create one
data = {"email": "test@fittech.com", "password": "password123"}

# Let's try registering first
reg = requests.post(f"{base_url}/api/auth/members/register/", json={
    "email": "test@fittech.com", 
    "password": "password123", 
    "password_confirm": "password123",
    "first_name": "Test",
    "last_name": "User"
})
print("Register:", reg.status_code, reg.text)

# Login
res = requests.post(login_url, json=data)
print("Login:", res.status_code)
if res.status_code == 200:
    token = res.json().get('access')
    headers = {"Authorization": f"Bearer {token}"}
    
    # Try initiating payment
    pay = requests.post(initiate_url, json={"plan_id": 1}, headers=headers)
    print("Initiate:", pay.status_code, pay.text)
else:
    print(res.text)

