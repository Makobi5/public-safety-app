// lib/main.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/home_page.dart';
import 'screens/sign_up.dart';
import 'service/auth_service.dart';
import 'screens/profile_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://hqpwvtunvcsoteyexfhz.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhxcHd2dHVudmNzb3RleWV4Zmh6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDAzOTcxNDcsImV4cCI6MjA1NTk3MzE0N30.OfSHUa4atxgy8Q93aHBSa-O4aos8aCQcSsgTsRKsXIY',
  );
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Community SafeWatch',
      theme: ThemeData(
        primaryColor: const Color(0xFF003366),
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: const Color(0xFF003366),
          secondary: Colors.blue[700],
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Inter',
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF003366),
            foregroundColor: Colors.white,
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF003366),
          foregroundColor: Colors.white,
        ),
      ),
      // Using initialRoute instead of home property
      initialRoute: '/',
      routes: {
        '/': (context) => FutureBuilder<bool>(
          future: _checkSession(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              // No logic change needed, just return HomePage for now
              return const HomePage();
            }
            
            // Show a loading spinner while checking session
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          },
        ),
        '/homepage': (context) => const HomePage(),
        'Homepage': (context) => const HomePage(),
        'SignUp': (context) => const SignUpPage(),
        'Login': (context) => const LoginPage(),
        '/profile': (context) => const ProfilePage(),
      },
    );
  }
  
  // Check if there's a valid session
  static Future<bool> _checkSession() async {
    return AuthService.isAuthenticated;
  }
}