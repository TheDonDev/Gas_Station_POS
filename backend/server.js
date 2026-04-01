require('dotenv').config();
// Force DNS resolution to use Google's DNS to prevent queryTxt ETIMEOUT on some networks
const dns = require('dns');
dns.setServers(['8.8.8.8', '8.8.4.4']);

const express = require('express');
const cors = require('cors');
const axios = require('axios');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const mongoose = require('mongoose');
const crypto = require('crypto');
const nodemailer = require('nodemailer');
const winston = require('winston');
const morgan = require('morgan');

// --- LOGGER CONFIGURATION (Winston) ---
const logger = winston.createLogger({
    level: 'info',
    format: winston.format.combine(
        winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
        winston.format.errors({ stack: true }),
        winston.format.splat(),
        winston.format.json()
    ),
    defaultMeta: { service: 'gas-pos-backend' },
    transports: [
        // Write all logs with importance level of `error` or less to `error.log`
        new winston.transports.File({ filename: 'logs/error.log', level: 'error' }),
        // Write all logs with importance level of `info` or less to `combined.log`
        new winston.transports.File({ filename: 'logs/combined.log' }),
    ],
});

// If we're not in production then log to the `console` with simple format
if (process.env.NODE_ENV !== 'production') {
    logger.add(new winston.transports.Console({
        format: winston.format.combine(
            winston.format.colorize(),
            winston.format.simple()
        ),
    }));
}

// Stream for Morgan to use Winston
const morganStream = {
    write: (text) => logger.info(text.trim()),
};

const app = express();
app.use(cors());
app.use(express.json());

// MongoDB Connection
const MONGO_URI = process.env.MONGO_URI || "mongodb://127.0.0.1:27017/gas_pos";

// HTTP Request Logging (Morgan)
app.use(morgan(':method :url :status :res[content-length] - :response-time ms', { stream: morganStream }));

const mongooseOptions = {
    serverSelectionTimeoutMS: 30000, // Increase to 30 seconds for unstable DNS
    connectTimeoutMS: 30000,
    family: 4, // Force IPv4 to avoid DNS resolution timeouts
    heartbeatFrequencyMS: 10000,
    retryWrites: true,
};

// Disable buffering globally to catch connection issues immediately
mongoose.set('bufferCommands', false);

/**
 * Safely masks the MongoDB URI for logging purposes.
 * Prevents credentials from appearing in logs/stdout.
 */
const maskUri = (uri) => {
    if (!uri) return 'UNDEFINED';
    // Regex to find credentials between // and @
    return uri.replace(/\/\/(.*):(.*)@/, '//****:****@');
};

const connectDB = async (retryCount = 0) => {
    const MAX_RETRIES = 5;
    const RETRY_DELAY_MS = 5000;

    try {
        const safeUri = maskUri(MONGO_URI);
        logger.info(`📡 Attempting to connect to: ${safeUri} (Attempt ${retryCount + 1}/${MAX_RETRIES})`);
        await mongoose.connect(MONGO_URI, mongooseOptions);
        logger.info("*****************************************");
        logger.info("✅ DATABASE CONNECTED SUCCESSFULLY");
        logger.info("*****************************************");
    } catch (err) {
        logger.error(`❌ Connection attempt ${retryCount + 1} failed: %s`, err.message);
        
        if (retryCount < MAX_RETRIES - 1) {
            logger.info(`🔄 Retrying in ${RETRY_DELAY_MS / 1000}s...`);
            await new Promise(resolve => setTimeout(resolve, RETRY_DELAY_MS));
            return connectDB(retryCount + 1);
        } else {
            logger.error("💥 Max retries reached. Database connection failed.");
            logger.warn("The server will continue to run, but DB-dependent features will fail.");
        }
    }
};

// Connection Monitoring
mongoose.connection.on('error', err => logger.error("MongoDB Runtime Error: %O", err));
mongoose.connection.on('disconnected', () => logger.warn("MongoDB Disconnected. Attempting to reconnect..."));
mongoose.connection.on('reconnected', () => logger.info("MongoDB Reconnected"));

// User Schema and Model
const userSchema = new mongoose.Schema({
    email: { type: String, required: true, unique: true },
    password: { type: String, required: true },
    role: { type: String, enum: ['admin', 'operator'], default: 'operator' },
    createdAt: { type: Date, default: Date.now },
    resetPasswordToken: String,
    resetPasswordExpires: Date,
    otpCode: String,
    otpExpires: Date
});

const User = mongoose.model('User', userSchema);

// Simple in-memory store for M-Pesa transaction results
const transactionStatus = {};
// In-memory store for registration OTPs (Email -> {code, expires})
const registrationOTPs = {};

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

// Send Verification OTP (Generic)
app.post('/send-otp', async (req, res) => {
    const { email, type } = req.body; // type: 'register' or 'change-password'

    if (!process.env.EMAIL_USER || !process.env.EMAIL_PASS) {
        logger.error("❌ EMAIL_USER or EMAIL_PASS missing in .env file");
        return res.status(500).json({ error: "Server configuration error: Email credentials missing" });
    }

    try {
        const otp = Math.floor(100000 + Math.random() * 900000).toString();
        const expires = Date.now() + 600000; // 10 minutes

        if (type === 'register') {
            registrationOTPs[email] = { otp, expires };
        } else {
            const user = await User.findOne({ email });
            if (!user) return res.status(404).json({ error: "User not found" });
            user.otpCode = otp;
            user.otpExpires = expires;
            await user.save();
        }

        logger.info(`📧 Attempting to send ${type} OTP to: ${email}`);
        const transporter = nodemailer.createTransport({
            service: 'gmail',
            auth: { user: process.env.EMAIL_USER, pass: process.env.EMAIL_PASS },
        });

        await transporter.sendMail({
            to: email,
            from: process.env.EMAIL_USER,
            subject: 'Your Verification Code',
            text: `Your verification code is: ${otp}. It expires in 10 minutes.`
        });

        res.status(200).json({ message: "OTP sent successfully" });
    } catch (error) {
        if (error.code === 'EAUTH') {
            logger.error("❌ SMTP Authentication Failed: Check if you are using a 16-character Gmail App Password.");
            logger.error("   Details: %O", error.response);
        } else {
            logger.error("OTP Mail Error: %O", error);
        }
        res.status(500).json({ error: "Failed to send OTP" });
    }
});

// Register Endpoint
app.post('/register', async (req, res) => {
    const { email, password, role, otp } = req.body;
    try {
        // Verify OTP
        const stored = registrationOTPs[email];
        if (!stored || stored.otp !== otp || Date.now() > stored.expires) {
            return res.status(400).json({ error: "Invalid or expired verification code" });
        }

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

        delete registrationOTPs[email];
        res.status(201).json({ message: "User registered successfully" });
    } catch (error) {
        logger.error("Registration Database Error: %s", error.message);
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
        logger.error("Login Database Error: %s", error.message);
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
        from: process.env.EMAIL_USER,
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
        logger.error("Forgot Password Database Error: %s", error.message);
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
        logger.error("Reset Password Database Error: %s", error.message);
        res.status(500).json({ error: "Internal Server Error: Database connection failed" });
    }
});

// --- SETTINGS & PROFILE ENDPOINTS ---

// Change Password (Available to both Admin and Operator)
app.post('/update-password', authenticateToken, async (req, res) => {
    const { newPassword, otp } = req.body;
    try {
        if (!newPassword || newPassword.length < 6) {
            return res.status(400).json({ error: "Password must be at least 6 characters long" });
        }

        const user = await User.findById(req.user.userId);
        
        // 2FA for Operators
        if (user.role === 'operator') {
            if (!otp || user.otpCode !== otp || Date.now() > user.otpExpires) {
                return res.status(400).json({ error: "Invalid or expired 2FA code" });
            }
            user.otpCode = undefined;
            user.otpExpires = undefined;
        }

        const hashedPassword = await bcrypt.hash(newPassword, 10);
        user.password = hashedPassword;
        await user.save();
        
        res.status(200).json({ message: "Password updated successfully" });
    } catch (error) {
        logger.error("Update Password Error: %s", error.message);
        res.status(500).json({ error: "Internal Server Error: Failed to update password" });
    }
});

// Update Store Settings (Admin Only)
app.post('/admin/update-settings', authenticateToken, authorizeRole(['admin']), async (req, res) => {
    const { storeName } = req.body;
    try {
        // Implementation for updating store settings in a Settings collection
        res.status(200).json({ message: "Store settings updated successfully" });
    } catch (error) {
        res.status(500).json({ error: "Failed to update settings" });
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
        logger.error("M-Pesa STK Push Error: %O", error.response ? error.response.data : error.message);
        res.status(error.response ? error.response.status : 500).json(
            error.response ? error.response.data : { error: "Failed to process STK push" }
        );
    }
});

// Callback URL (where Safaricom sends payment results)
app.post('/callback', (req, res) => {
    logger.info('--- M-PESA CALLBACK RECEIVED ---');
    const { CheckoutRequestID, ResultCode } = req.body.Body.stkCallback;
    
    // Store the result (0 means Success)
    transactionStatus[CheckoutRequestID] = ResultCode === 0 ? 'SUCCESS' : 'FAILED';
    
    logger.info(`Transaction ${CheckoutRequestID} resulted in: ${transactionStatus[CheckoutRequestID]}`);
    res.status(200).send("OK");
});

// Status Check Endpoint (Polling)
app.get('/status/:checkoutId', (req, res) => {
    const status = transactionStatus[req.params.checkoutId] || 'PENDING';
    res.status(200).json({ status });
});

// Global Error Handler to prevent HTML responses
app.use((err, req, res, next) => {
    logger.error("Global Error Handler: %O", err);
    res.status(500).json({ error: "Internal Server Error", message: err.message });
});

const PORT = process.env.PORT || 3000;

const startServer = async () => {
    await connectDB();
    app.listen(PORT, '0.0.0.0', () => logger.info(`🚀 Server running on port ${PORT}`));
};

startServer();