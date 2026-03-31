require('dotenv').config();
const express = require('express');
const cors = require('cors');
const axios = require('axios');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const mongoose = require('mongoose');
const crypto = require('crypto');
const nodemailer = require('nodemailer');

const app = express();
app.use(cors());
app.use(express.json());

// MongoDB Connection
const MONGO_URI = process.env.MONGO_URI || "mongodb://127.0.0.1:27017/gas_pos";

const mongooseOptions = {
    serverSelectionTimeoutMS: 5000, // Keep trying to connect for 5 seconds
};

// Disable buffering globally to catch connection issues immediately
mongoose.set('bufferCommands', false);

const connectDB = async () => {
    try {
        console.log(`📡 Attempting to connect to: ${MONGO_URI.split('@')[1] || MONGO_URI}`);
        await mongoose.connect(MONGO_URI, mongooseOptions);
        console.log("*****************************************");
        console.log("✅ DATABASE CONNECTED SUCCESSFULLY");
        console.log("*****************************************");
        // Start listening only AFTER the database is connected
        app.listen(PORT, '0.0.0.0', () => console.log(`Server running on port ${PORT}`));
    } catch (err) {
        console.error("❌ Could not connect to MongoDB:", err.message);
        process.exit(1); // Exit if DB connection fails
    }
};

// Connection Monitoring
mongoose.connection.on('error', err => console.error("MongoDB Runtime Error:", err));
mongoose.connection.on('disconnected', () => console.warn("MongoDB Disconnected. Attempting to reconnect..."));
mongoose.connection.on('reconnected', () => console.log("MongoDB Reconnected"));

// User Schema and Model
const userSchema = new mongoose.Schema({
    email: { type: String, required: true, unique: true },
    password: { type: String, required: true },
    role: { type: String, enum: ['admin', 'operator'], default: 'operator' },
    createdAt: { type: Date, default: Date.now },
    resetPasswordToken: String,
    resetPasswordExpires: Date
});

const User = mongoose.model('User', userSchema);

// Simple in-memory store for M-Pesa transaction results
const transactionStatus = {};

const JWT_SECRET = process.env.JWT_SECRET || "super_secret_gas_pos_key";

// --- MIDDLEWARE ---

// Verify JWT Token
const authenticateToken = (req, res, next) => {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];

    if (!token) return res.status(401).json({ error: "Access denied. No token provided." });

    jwt.verify(token, JWT_SECRET, (err, user) => {
        if (err) return res.status(403).json({ error: "Invalid or expired token." });
        req.user = user;
        next();
    });
};

// Restrict access by role
const authorizeRole = (roles) => {
    return (req, res, next) => {
        if (!roles.includes(req.user.role)) {
            return res.status(403).json({ error: "Forbidden: You do not have permission to perform this action." });
        }
        next();
    };
};

// --- AUTHENTICATION ENDPOINTS ---

// Register Endpoint
app.post('/register', async (req, res) => {
    const { email, password, role } = req.body;
    try {
        const existingUser = await User.findOne({ email });
        if (existingUser) {
            return res.status(400).json({ error: "User already exists" });
        }

        // Enforce Single Admin Policy
        if (role === 'admin') {
            const adminExists = await User.findOne({ role: 'admin' });
            if (adminExists) {
                return res.status(400).json({ error: "An administrator account already exists. Only one admin is allowed." });
            }
        }

        const hashedPassword = await bcrypt.hash(password, 10);
        const newUser = new User({ email, password: hashedPassword, role: role || 'operator' });
        await newUser.save();

        res.status(201).json({ message: "User registered successfully" });
    } catch (error) {
        console.error("Registration Database Error:", error.message);
        res.status(500).json({ error: "Internal Server Error: Database connection failed" });
    }
});

// Login Endpoint
app.post('/login', async (req, res) => {
    const { email, password } = req.body;
    try {
        const user = await User.findOne({ email });

        if (!user || !(await bcrypt.compare(password, user.password))) {
            return res.status(401).json({ error: "Invalid credentials" });
        }

        const token = jwt.sign({ userId: user._id, email: user.email, role: user.role }, JWT_SECRET, { expiresIn: '1h' });
        res.status(200).json({ token, email: user.email, role: user.role });
    } catch (error) {
        console.error("Login Database Error:", error.message);
        res.status(500).json({ error: "Internal Server Error: Database connection failed" });
    }
});

// --- PASSWORD RESET ENDPOINTS ---

// Forgot Password: Request a reset link
app.post('/forgot-password', async (req, res) => {
    const { email } = req.body;
    try {
        const user = await User.findOne({ email });

    if (!user) {
        return res.status(404).json({ error: "User with this email does not exist" });
    }

    // Generate a secure random token
    const token = crypto.randomBytes(20).toString('hex');

    // Set token and expiry (e.g., 1 hour from now)
    user.resetPasswordToken = token;
    user.resetPasswordExpires = Date.now() + 3600000; 
    await user.save();

    // Configure Nodemailer (Example using a Gmail/SMTP setup)
    // In production, use environment variables for these credentials!
    const transporter = nodemailer.createTransport({
        service: 'gmail',
        auth: {
            user: process.env.EMAIL_USER,
            pass: process.env.EMAIL_PASS,
        },
    });

    const resetUrl = `http://localhost:8080/reset-password?token=${token}`;

    const mailOptions = {
        to: user.email,
        from: 'passwordreset@gaspos.com',
        subject: 'Gas Station POS Password Reset',
        text: `You are receiving this because you (or someone else) have requested the reset of the password for your account.\n\n` +
              `Please click on the following link, or paste this into your browser to complete the process:\n\n` +
              `${resetUrl}\n\n` +
              `If you did not request this, please ignore this email.\n`
    };

    try {
        await transporter.sendMail(mailOptions);
        res.status(200).json({ message: "Reset email sent successfully" });
    } catch (error) {
        res.status(500).json({ error: "Error sending reset email" });
    }
    } catch (error) {
        console.error("Forgot Password Database Error:", error.message);
        res.status(500).json({ error: "Internal Server Error: Database connection failed" });
    }
});

// Reset Password: Use the token to set a new password
app.post('/reset-password', async (req, res) => {
    const { token, newPassword } = req.body;
    try {
        const user = await User.findOne({
            resetPasswordToken: token,
            resetPasswordExpires: { $gt: Date.now() }
        });

        if (!user) {
            return res.status(400).json({ error: "Password reset token is invalid or has expired" });
        }

        // Hash the new password and clear the reset fields
        user.password = await bcrypt.hash(newPassword, 10);
        user.resetPasswordToken = undefined;
        user.resetPasswordExpires = undefined;
        await user.save();

        res.status(200).json({ message: "Password has been successfully updated" });
    } catch (error) {
        console.error("Reset Password Database Error:", error.message);
        res.status(500).json({ error: "Internal Server Error: Database connection failed" });
    }
});

// Example of a protected admin route (e.g., getting all users)
app.get('/admin/users', authenticateToken, authorizeRole(['admin']), async (req, res) => {
    const users = await User.find({}, '-password');
    res.json(users);
});

// Health Check Endpoint to verify server and DB status
app.get('/health', (req, res) => {
    const dbStatus = mongoose.connection.readyState;
    const statusMap = { 0: 'disconnected', 1: 'connected', 2: 'connecting', 3: 'disconnecting' };
    res.status(200).json({
        status: 'UP',
        database: statusMap[dbStatus] || 'unknown'
    });
});

// M-Pesa Credentials
// Load credentials from environment variables for production readiness
const consumerKey = process.env.MPESA_CONSUMER_KEY;
const consumerSecret = process.env.MPESA_CONSUMER_SECRET;
const shortCode = process.env.MPESA_SHORTCODE;
const passKey = process.env.MPESA_PASSKEY;

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
    const { CheckoutRequestID, ResultCode } = req.body.Body.stkCallback;
    
    // Store the result (0 means Success)
    transactionStatus[CheckoutRequestID] = ResultCode === 0 ? 'SUCCESS' : 'FAILED';
    
    console.log(`Transaction ${CheckoutRequestID} resulted in: ${transactionStatus[CheckoutRequestID]}`);
    res.status(200).send("OK");
});

// Status Check Endpoint (Polling)
app.get('/status/:checkoutId', (req, res) => {
    const status = transactionStatus[req.params.checkoutId] || 'PENDING';
    res.status(200).json({ status });
});

// Global Error Handler to prevent HTML responses
app.use((err, req, res, next) => {
    console.error(err.stack);
    res.status(500).json({ error: "Internal Server Error", message: err.message });
});

const PORT = process.env.PORT || 3000;
connectDB();