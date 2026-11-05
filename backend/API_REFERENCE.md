# RC3 Shared Living App — Complete API Reference & Testing Guide

## 1. Live Server URLs

The backend server is **currently running live** on your Mac at:
- **Swagger Interactive UI:** [http://localhost:8000/docs](http://localhost:8000/docs)
- **ReDoc Interactive UI:** [http://localhost:8000/redoc](http://localhost:8000/redoc)
- **Health Check:** [http://localhost:8000/health](http://localhost:8000/health)

### Mobile App Base URLs:
- **iOS Simulator:** `http://localhost:8000`
- **Android Emulator:** `http://10.0.2.2:8000`
- **Real Phone on Wi-Fi:** `http://<YOUR_MAC_IP>:8000` (Find IP: `ipconfig getifaddr en0`)

---

## 2. Pre-Seeded Demo Accounts

The database comes pre-seeded with the official benchmark household and 3 roommates:

| Member Code | Name | Role | Email | Password |
| :--- | :--- | :--- | :--- | :--- |
| **M01** | **Ali** | Owner | `ali@demo.pk` | `DemoPass123!` |
| **M02** | **Ayesha** | Member | `ayesha@demo.pk` | `DemoPass123!` |
| **M03** | **Bilal** | Member | `bilal@demo.pk` | `DemoPass123!` |

- **Household Name:** `"Lahore Apartment"`
- **Invite Code:** `"LAHORE2026"`
- **Currency:** `"PKR"`
- **Default Budget:** `5000.00 PKR` (`500,000 paisa`)

---

## 3. Headers Required for Requests

Most endpoints require authentication. Once you log in, add this header to subsequent requests:
```http
Authorization: Bearer <your_access_token>
Content-Type: application/json
```
*(Optional for mutations: `Idempotency-Key: <unique-uuid>`)*

---

## 4. Endpoints Reference

### 🔐 Auth

#### `POST /api/auth/login`
```json
// Request Body
{
  "email": "ali@demo.pk",
  "password": "DemoPass123!"
}
// Response (200 OK)
{
  "access_token": "eyJhbGciOi...",
  "refresh_token": "a1b2c3d4...",
  "token_type": "bearer",
  "expires_in": 900,
  "user": {
    "id": "...",
    "email": "ali@demo.pk",
    "display_name": "Ali"
  }
}
```

#### `GET /api/auth/me`
Requires `Authorization: Bearer <token>`
```json
// Response (200 OK)
{
  "id": "...",
  "email": "ali@demo.pk",
  "display_name": "Ali",
  "household_id": "...",
  "member_id": 1,
  "member_code": "M01",
  "role": "owner"
}
```

---

### 👥 Household & Members

#### `GET /api/members`
Official format returning raw array of roommates:
```json
// Response (200 OK)
[
  {"id": "M01", "name": "Ali"},
  {"id": "M02", "name": "Ayesha"},
  {"id": "M03", "name": "Bilal"}
]
```

#### `GET /api/households/me`
```json
// Response (200 OK)
{
  "id": "...",
  "name": "Lahore Apartment",
  "currency": "PKR",
  "invite_code": "LAHORE2026"
}
```

---

### 🛒 Shopping List

Allowed units strictly: `"pack"`, `"dozen"`, `"bottle"`, `"bag"`.

#### `POST /api/shopping`
```json
// Request Body
{
  "title": "Fresh Milk",
  "unit": "bottle",
  "requested_qty": 2
}
// Response (201 Created)
{
  "id": 1,
  "title": "Fresh Milk",
  "unit": "bottle",
  "requested_qty": 2,
  "status": "pending"
}
```

#### `GET /api/shopping`
Returns raw array of items sorted newest-first:
```json
// Response (200 OK)
[
  {
    "id": 1,
    "title": "Fresh Milk",
    "unit": "bottle",
    "requested_qty": 2,
    "status": "pending"
  }
]
```
*(Query param: `GET /api/shopping?status=pending` or `status=bought`)*

---

### ⚡ Atomic Checkout

Converts pending shopping items into an expense split across selected members:

#### `POST /api/shopping/checkout`
```json
// Request Body
{
  "item_ids": [1],
  "total_paid": 780.00,
  "payer_id": "M01",
  "split_members": ["M01", "M02", "M03"]
}
// Response (201 Created)
{
  "id": 1,
  "title": "Grocery: Fresh Milk",
  "category": "Groceries",
  "amount": 780.0,
  "amount_paisa": 78000,
  "payer_id": "M01",
  "split_type": "equal",
  "splits": [
    {"member_id": "M01", "amount": 260.0, "amount_paisa": 26000},
    {"member_id": "M02", "amount": 260.0, "amount_paisa": 26000},
    {"member_id": "M03", "amount": 260.0, "amount_paisa": 26000}
  ],
  "items": [
    {"id": 1, "title": "Fresh Milk", "status": "bought"}
  ]
}
```

---

### 💰 Expenses

#### `POST /api/expenses` (Equal Split)
```json
// Request Body
{
  "title": "Electricity Bill",
  "category": "Utilities",
  "amount": 1020.00,
  "payer_id": "M01",
  "split_type": "equal",
  "split_members": ["M01", "M02", "M03"]
}
```

#### `POST /api/expenses` (Custom Split)
```json
// Request Body
{
  "title": "Internet Bill",
  "category": "Internet",
  "amount": 1500.00,
  "payer_id": "M03",
  "split_type": "custom",
  "custom_splits": [
    {"member_id": "M01", "amount": 500.00},
    {"member_id": "M02", "amount": 300.00},
    {"member_id": "M03", "amount": 700.00}
  ]
}
```

#### `GET /api/expenses`
Lists expenses with pagination and filtering:
`GET /api/expenses?category=Groceries&payer_id=M01&page=1&page_size=20`

---

### ⚖️ Balances & Settlements

#### `GET /api/balances`
Calculates net balances with conservation formula: $\text{Net} = (\text{paid} - \text{owed}) + (\text{sent} - \text{received})$:
```json
// Response (200 OK)
{
  "household_total_spending": 4200.0,
  "household_total_spending_paisa": 420000,
  "is_balanced": true,
  "members": [
    {
      "member_id": "M01",
      "name": "Ali",
      "paid": 1800.0,
      "paid_paisa": 180000,
      "owed": 1550.0,
      "owed_paisa": 155000,
      "net_balance": 250.0,
      "net_balance_paisa": 25000,
      "status": "owed"
    },
    {
      "member_id": "M02",
      "name": "Ayesha",
      "paid": 900.0,
      "paid_paisa": 90000,
      "owed": 1350.0,
      "owed_paisa": 135000,
      "net_balance": -450.0,
      "net_balance_paisa": -45000,
      "status": "owes"
    },
    {
      "member_id": "M03",
      "name": "Bilal",
      "paid": 1500.0,
      "paid_paisa": 150000,
      "owed": 1300.0,
      "owed_paisa": 130000,
      "net_balance": 200.0,
      "net_balance_paisa": 20000,
      "status": "owed"
    }
  ]
}
```

#### `POST /api/settle`
A debtor pays a creditor to resolve debt:
```json
// Request Body
{
  "sender_id": "M02",
  "recipient_id": "M01",
  "amount": 250.00
}
// Response (201 Created)
{
  "id": 1,
  "sender_id": "M02",
  "recipient_id": "M01",
  "amount": 250.0,
  "amount_paisa": 25000,
  "settlement_date": "2026-11-05"
}
```

---

### 📊 Monthly Budget & Dashboard

#### `GET /api/budget/summary`
```json
// Response (200 OK)
{
  "month": "2026-11",
  "limit": 5000.0,
  "limit_paisa": 500000,
  "spent": 4200.0,
  "spent_paisa": 420000,
  "remaining": 800.0,
  "remaining_paisa": 80000,
  "percent": 84,
  "status": "near_limit"
}
```

#### `PUT /api/budget` (Owner / Admin only)
```json
// Request Body
{
  "month": "2026-11",
  "limit": 8000.00
}
```

#### `GET /api/dashboard`
Returns composite mobile home screen in 1 single network request:
```json
// Response (200 OK)
{
  "month": "2026-11",
  "spent": 4200.0,
  "spent_paisa": 420000,
  "limit": 5000.0,
  "limit_paisa": 500000,
  "remaining": 800.0,
  "remaining_paisa": 80000,
  "percent": 84,
  "status": "near_limit",
  "member": {
    "id": "M01",
    "name": "Ali",
    "net_balance": 250.0,
    "net_balance_paisa": 25000,
    "message": "You are owed PKR 250.00"
  },
  "pending_items_count": 0
}
```
*(Query param to inspect specific member: `GET /api/dashboard?member_id=M02`)*

---

## 5. Uniform Error Format

All error responses return RFC-compliant envelope:
```json
{
  "error": {
    "code": "SETTLE_EXCEEDS_DEBT",
    "message": "Settlement amount (500.00 PKR) exceeds member M02's debt (450.00 PKR). Max allowed is 450.00 PKR.",
    "fields": []
  }
}
```
Common error codes:
- `VALIDATION_ERROR` (422)
- `INVALID_AMOUNT` (422)
- `SELF_SETTLEMENT` (422)
- `SETTLE_EXCEEDS_DEBT` (422)
- `SETTLE_EXCEEDS_CREDIT` (422)
- `ITEM_ALREADY_BOUGHT` (409)
- `TOKEN_EXPIRED` / `TOKEN_INVALID` (401)
- `FORBIDDEN` (403)
- `NOT_FOUND` (404)
- `RATE_LIMITED` (429)

