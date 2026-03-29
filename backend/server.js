const express = require('express');
const axios = require('axios');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const mongoose = require('mongoose');
const crypto = require('crypto');
const nodemailer = require('nodemailer');

const app = express();
app.use(express.json());

// MongoDB Connection
const MONGO_URI = process.env.MONGO_URI || "mongodb://localhost:27014/gas_pos";
mongoose.connect(MONGO_URI)
    .then(() => console.log("Connected to MongoDB"))
    .catch(err => console.error("Could not connect to MongoDB:", err));

// User Schema and Model
const userSchema = new mongoose.Schema({
    email: { type: String, required: true, unique: true },
    password: { type: String, required: true },
    createdAt: { type: Date, default: Date.now },
    resetPasswordToken: String,
    resetPasswordExpires: Date
});

const User = mongoose.model('User', userSchema);

const JWT_SECRET = process.env.JWT_SECRET || "super_secret_gas_pos_key";

// --- AUTHENTICATION ENDPOINTS ---

// Register Endpoint
app.post('/register', async (req, res) => {
    const { email, password } = req.body;
    
    const existingUser = await User.findOne({ email });
    if (existingUser) {
        return res.status(400).json({ error: "User already exists" });
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    const newUser = new User({ email, password: hashedPassword });
    await newUser.save();

    res.status(201).json({ message: "User registered successfully" });
});

// Login Endpoint
app.post('/login', async (req, res) => {
    const { email, password } = req.body;
    const user = await User.findOne({ email });

    if (!user || !(await bcrypt.compare(password, user.password))) {
        return res.status(401).json({ error: "Invalid credentials" });
    }

    const token = jwt.sign({ userId: user._id, email: user.email }, JWT_SECRET, { expiresIn: '1h' });
    res.status(200).json({ token, email: user.email });
});

// --- PASSWORD RESET ENDPOINTS ---

// Forgot Password: Request a reset link
app.post('/forgot-password', async (req, res) => {
    const { email } = req.body;
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
});

// Reset Password: Use the token to set a new password
app.post('/reset-password', async (req, res) => {
    const { token, newPassword } = req.body;

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
    console.log(JSON.stringify(req.body, null, 2));
    res.status(200).send("OK");
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));