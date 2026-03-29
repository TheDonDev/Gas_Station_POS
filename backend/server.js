const express = require('express');
const axios = require('axios');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

const app = express();
app.use(express.json());

// Mock Database (In production, use MongoDB or PostgreSQL)
const users = [];
const JWT_SECRET = process.env.JWT_SECRET || "super_secret_gas_pos_key";

// --- AUTHENTICATION ENDPOINTS ---

// Register Endpoint
app.post('/register', async (req, res) => {
    const { email, password } = req.body;
    if (users.find(u => u.email === email)) {
        return res.status(400).json({ error: "User already exists" });
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    const newUser = { id: Date.now(), email, password: hashedPassword };
    users.push(newUser);

    res.status(201).json({ message: "User registered successfully" });
});

// Login Endpoint
app.post('/login', async (req, res) => {
    const { email, password } = req.body;
    const user = users.find(u => u.email === email);

    if (!user || !(await bcrypt.compare(password, user.password))) {
        return res.status(401).json({ error: "Invalid credentials" });
    }

    const token = jwt.sign({ userId: user.id, email: user.email }, JWT_SECRET, { expiresIn: '1h' });
    res.status(200).json({ token, email: user.email });
});

// M-Pesa Credentials
// Load credentials from environment variables for production readiness
const consumerKey = process.env.MPESA_CONSUMER_KEY || "g0MmzwVquthei5Yv0ZkaaQP3F2Z7AHFzLUiRBkcm9OH6YgA8"; // Default to sandbox for dev
const consumerSecret = process.env.MPESA_CONSUMER_SECRET || "5p0z8EA7adEpoVaTuImTkG7s3PCLHrz2tSU5R4mAxsdGj64wNyQMPF4gTAA6PDYO"; // Default to sandbox for dev
const shortCode = process.env.MPESA_SHORTCODE || "174379"; // Default to sandbox for dev
const passKey = process.env.MPESA_PASSKEY || "bfb279f9aa9bdbcf158e97dd71a467cd2e0c893059b10f78e6b72ada1ed2c919"; // Default to sandbox for dev

// Production vs Sandbox URL
const mpesaBaseUrl = process.env.NODE_ENV === 'production' ? 'https://api.safaricom.co.ke' : 'https://sandbox.safaricom.co.ke';

// Generate Access Token Middleware
const generateToken = async (req, res, next) => {
    const auth = Buffer.from(`${consumerKey}:${consumerSecret}`).toString('base64');
    try {
        const response = await axios.get(`${mpesaBaseUrl}/oauth/v1/generate?grant_type=client_credentials`, {
            headers: { Authorization: `Basic ${auth}` }
        });
        req.token = response.data.access_token;
        next();
    } catch (error) {
        res.status(401).send("Failed to generate token");
    }
};

// STK Push Endpoint
app.post('/stkpush', generateToken, async (req, res) => {
    const phone = req.body.phone;
    const amount = req.body.amount;

    const date = new Date();
    const timestamp =
        date.getFullYear() +
        ("0" + (date.getMonth() + 1)).slice(-2) +
        ("0" + date.getDate()).slice(-2) +
        ("0" + date.getHours()).slice(-2) +
        ("0" + date.getMinutes()).slice(-2) +
        ("0" + date.getSeconds()).slice(-2);

    const password = Buffer.from(shortCode + passKey + timestamp).toString('base64');

    const data = {
        BusinessShortCode: shortCode,
        Password: password,
        Timestamp: timestamp,
        TransactionType: "CustomerPayBillOnline",
        Amount: amount,
        PartyA: phone,
        PartyB: shortCode,
        PhoneNumber: phone,
        // Use environment variable for production callback URL
        CallBackURL: process.env.MPESA_CALLBACK_URL, 
        AccountReference: "GasStationPOS",
        TransactionDesc: "LPG Refill Payment"
    };

    try {
        const response = await axios.post(`${mpesaBaseUrl}/mpesa/stkpush/v1/processrequest`, data, {
            headers: { Authorization: `Bearer ${req.token}` }
        });
        res.status(200).json(response.data);
    } catch (error) {
        console.error("M-Pesa STK Push Error:", error.response ? error.response.data : error.message);
        res.status(error.response ? error.response.status : 500).json(
            error.response ? error.response.data : { error: "Failed to process STK push" }
        );
    }
});

// Callback URL (where Safaricom sends payment results)
app.post('/callback', (req, res) => {
    console.log('--- M-PESA CALLBACK RECEIVED ---');
    console.log(JSON.stringify(req.body, null, 2));
    res.status(200).send("OK");
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));