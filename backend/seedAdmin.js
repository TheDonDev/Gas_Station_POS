require('dotenv').config();
// Force DNS resolution to use Google's DNS to prevent queryTxt ETIMEOUT on some networks
const dns = require('dns');
dns.setServers(['8.8.8.8', '8.8.4.4']);

const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

// Use your existing connection string from .env or the fallback
const MONGO_URI = process.env.MONGO_URI || "mongodb://127.0.0.1:27017/gas_pos";

// We define the schema here to match your server.js model
const userSchema = new mongoose.Schema({
    email: { type: String, required: true, unique: true },
    password: { type: String, required: true },
    role: { type: String, enum: ['admin', 'operator'], default: 'operator' },
    createdAt: { type: Date, default: Date.now }
});

const User = mongoose.model('User', userSchema);

const mongooseOptions = {
    serverSelectionTimeoutMS: 15000, // Reduced for faster troubleshooting feedback
    connectTimeoutMS: 15000,
    family: 4, // Force IPv4 to avoid DNS resolution timeouts
};

const maskUri = (uri) => {
    if (!uri) return 'UNDEFINED';
    return uri.replace(/\/\/(.*):(.*)@/, '//****:****@');
};

async function seedAdmin() {
    try {
        if (!process.env.MONGO_URI) console.warn("⚠️ MONGO_URI not found in env, using fallback.");
        const safeUri = maskUri(MONGO_URI);
        console.log(`📡 Attempting to connect to: ${safeUri}`);
        await mongoose.connect(MONGO_URI, mongooseOptions);
        console.log("*****************************************");
        console.log("✅ DATABASE CONNECTED SUCCESSFULLY");
        console.log("*****************************************");

        // Check if an admin already exists
        const adminExists = await User.findOne({ role: 'admin' });
        if (adminExists) {
            console.log("Aborting: An administrator already exists (" + adminExists.email + ")");
            process.exit(0);
        }

        // Define your initial credentials here
        const email = "admin@gaspos.com";
        const password = "admin123"; // CHANGE THIS IMMEDIATELY AFTER LOGIN
        const hashedPassword = await bcrypt.hash(password, 10);

        const admin = new User({
            email,
            password: hashedPassword,
            role: 'admin'
        });

        await admin.save();
        console.log("-----------------------------------------");
        console.log("SUCCESS: Initial Admin Account Created!");
        console.log("Email: " + email);
        console.log("Password: " + password);
        console.log("-----------------------------------------");
        process.exit(0);
    } catch (err) {
        console.error("Error seeding admin:", err);
        if (err.message.includes('queryTxt ETIMEOUT')) {
            console.log("\n🛑 DETECTED DNS TIMEOUT");
            console.log("Please use the standard 'mongodb://' connection string instead of 'mongodb+srv://' in your .env file.\n");
            console.log("Find this in Atlas under Connect -> Drivers -> Node.js -> Version 2.2.12 or earlier.");
            console.log("This format skips the problematic DNS SRV lookup entirely.");
        }
        process.exit(1);
    }
}

seedAdmin();