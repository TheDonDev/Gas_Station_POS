require('dotenv').config();
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

async function seedAdmin() {
    try {
        await mongoose.connect(MONGO_URI);
        console.log("Connected to MongoDB Atlas...");

        // Check if an admin already exists
        const adminExists = await User.findOne({ role: 'admin' });
        if (adminExists) {
            console.log("Aborting: An administrator already exists (" + adminExists.email + ")");
            process.exit(0);
        }

        // Define your initial credentials here
        const email = "admin@gaspos.com";
        const password = "InitialAdminPassword123"; // CHANGE THIS IMMEDIATELY AFTER LOGIN
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
        process.exit(1);
    }
}

seedAdmin();