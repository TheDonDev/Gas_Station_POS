import 'dart:io';
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

  // Launch backend executable if running in release mode on Windows
  if (Platform.isWindows && kReleaseMode) {
    _startBackendProcess();
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

void _startBackendProcess() async {
  try {
    // Assumes gas-backend.exe is in the same folder as the Flutter app
    final String backendPath = join(File(Platform.resolvedExecutable).parent.path, 'gas-backend.exe');
    if (await File(backendPath).exists()) {
      await Process.start(backendPath, [], mode: ProcessStartMode.detached);
      debugPrint("Backend process started successfully.");
    } else {
      debugPrint("Backend executable not found at $backendPath");
    }
  } catch (e) {
    debugPrint("Failed to start backend: $e");
  }
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
            home: _getInitialScreen(),
          );
        },
      ),
    );
  }

  Widget _getInitialScreen() {
    final String? token = Uri.base.queryParameters['token'];
    if (token != null && token.isNotEmpty) {
      return ResetPasswordScreen(token: token);
    }

    return FutureBuilder(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        final prefs = snapshot.data as SharedPreferences?;
        final String? savedToken = prefs?.getString('auth_token');

        if (savedToken != null && savedToken.isNotEmpty) {
          // Initialize AuthProvider with saved data
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.read<AuthProvider>().login(
              prefs!.getString('user_email')!,
              prefs.getString('user_role')!,
              savedToken,
            );
          });
          return const DashboardScreen();
        }
        return const WelcomeScreen();
      },
    );
  }
}
