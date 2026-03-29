# ⛽ Gas Station POS - Next-Gen LPG Management

A world-class, full-stack Point of Sale (POS) and Inventory Management system specifically engineered for LPG (Liquid Petroleum Gas) wholesale and retail operations. This solution combines a high-performance Flutter frontend with a robust Node.js/MongoDB backend.

---

## 🚀 Key Features

### 🔐 Advanced Authentication
- **Modern UI Flow**: Welcome screen with options for Login and Registration.
- **Secure Access**: JWT-based authentication with Bcrypt password hashing.
- **Password Recovery**: Integrated "Forgot Password" flow utilizing Nodemailer for secure token-based resets via email.
- **Aesthetics**: World-class design featuring **Glassmorphism**, **Hero Animations**, and a custom **Animated Mesh Background**.

### 📦 Core Operations
- **Inventory Management**: Specialized tracking for full/empty cylinders and bulk LPG levels.
- **Wholesale POS**: Streamlined cart system for rapid processing of retail refills.
- **Retailer Directory**: Manage a database of frequent retailers and wholesale customers.

### 💳 Payments & Printing
- **M-Pesa Integration**: Native STK Push triggers for automated mobile payments.
- **Transaction Polling**: Real-time status checking for M-Pesa transactions.
- **Thermal Printing**: Support for ESC/POS receipt printing via USB and Bluetooth.

### 📊 Admin & Maintenance
- **Analytics Dashboard**: Visual sales summaries, revenue tracking, and top-selling product charts using `fl_chart`.
- **Data Resilience**: Local SQLite backup/restore functionality and production-ready MongoDB persistence.
- **Maintenance**: Built-in factory reset and data maintenance tools.

---

## 🛠 Tech Stack

- **Frontend**: Flutter (Provider for State Management, Google Fonts, fl_chart)
- **Backend**: Node.js & Express.js
- **Database**: MongoDB (Production/User Auth) & SQLite (Local Transactions/Inventory)
- **DevOps**: Docker & Docker Compose
- **Payments**: Safaricom Daraja API (M-Pesa)

---

## 📦 Getting Started

### Option 1: Docker (Full Stack - Recommended)
The easiest way to run the entire stack (Frontend, Backend, and MongoDB) is using Docker Compose.

1.  Ensure you have a `.env` file in the `backend/` directory with your M-Pesa and Email credentials.
2.  Run the following command in the root directory:
    ```bash
    docker compose up --build
    ```
3.  Access the Flutter Web app at `http://localhost:8080`.

### Option 2: Manual Development
**Backend:**
1. Navigate to `backend/`.
2. Run `npm install` and `npm start`.

**Frontend:**
1. Run `flutter pub get`.
2. Run `flutter run -d windows` (or `chrome`).

---

## ⚙️ Environment Variables
Create a `.env` file in the `backend/` folder:

```env
PORT=3000
MONGO_URI=mongodb://db:27017/gas_pos
JWT_SECRET=your_secret_key

MPESA_CONSUMER_KEY=your_key
MPESA_CONSUMER_SECRET=your_secret
MPESA_SHORTCODE=174379
MPESA_PASSKEY=your_passkey
MPESA_CALLBACK_URL=https://your-domain.com/callback

EMAIL_USER=your-email@gmail.com
EMAIL_PASS=your-app-password
```

---

## 🛡 Security & Design
- **CORS Enabled**: Backend configured for cross-origin requests.
- **Responsive Design**: UI adapts for Windows Desktop and Web browsers.
- **Network Awareness**: Flutter app automatically detects environment to route API calls (10.0.2.2 for Android vs localhost for Desktop).

## 📜 License
This project is licensed under the ISC License.