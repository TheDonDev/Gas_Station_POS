import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gas_store_pos/providers/inventory_provider.dart';
import 'package:gas_store_pos/providers/cart_provider.dart';
import 'package:gas_store_pos/providers/customer_provider.dart';
import 'package:gas_store_pos/providers/printer_provider.dart';
import 'package:gas_store_pos/providers/auth_provider.dart';
import 'package:gas_store_pos/providers/theme_provider.dart';
import 'package:gas_store_pos/screens/welcome_screen.dart';
import 'package:gas_store_pos/screens/reset_password_screen.dart';
import 'package:gas_store_pos/screens/dashboard_screen.dart';
import 'package:gas_store_pos/data/database_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // In production, we connect to the Render cloud URL defined in ApiConfig.
  if (Platform.isWindows && kDebugMode) {
    debugPrint("Debug mode detected: Ensure your Node.js backend is running manually on port 3000.");
  }

  // Initialize database factory for Desktop support if running on Windows/Linux
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  
  // Ensure DB is created on startup
  await DatabaseService().database;

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => InventoryProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => CustomerProvider()),
        ChangeNotifierProvider(create: (_) => PrinterProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Gas Store POS',
            debugShowCheckedModeBanner: false,
            theme: ThemeProvider.lightTheme.copyWith(
              textTheme: GoogleFonts.poppinsTextTheme(ThemeData.light().textTheme),
            ),
            darkTheme: ThemeProvider.darkTheme.copyWith(
              textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
            ),
            themeMode: themeProvider.themeMode,
            home: Consumer<AuthProvider>(
              builder: (context, auth, _) {
                if (auth.isAuthenticated) {
                  return const DashboardScreen();
                }
                return _getInitialScreen(auth);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _getInitialScreen(AuthProvider auth) {
    final String? token = Uri.base.queryParameters['token'];
    if (token != null && token.isNotEmpty) {
      return ResetPasswordScreen(token: token);
    }

    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final prefs = snapshot.data!;
        final sessionStr = prefs.getString('user_session');

        if (sessionStr != null && sessionStr.isNotEmpty) {
          final sessionData = jsonDecode(sessionStr);
          
          // Session Timeout Check (24 Hours)
          final int loginTime = sessionData['login_time'] ?? 0;
          final int currentTime = DateTime.now().millisecondsSinceEpoch;
          const int twentyFourHoursMs = 24 * 60 * 60 * 1000;

          if (currentTime - loginTime > twentyFourHoursMs) {
            prefs.remove('user_session');
            return const WelcomeScreen();
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            auth.login(sessionData['email'], sessionData['role'], sessionData['token']);
          });
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        return const WelcomeScreen();
      },
    );
  }
}
