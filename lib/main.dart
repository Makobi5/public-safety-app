// lib/main.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async'; // For StreamSubscription
import 'screens/home_page.dart';
import 'screens/sign_up.dart';
import 'service/auth_service.dart';
import 'screens/profile_page.dart';
import 'screens/forgot_password.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://hkggxkyzyjptapnqbdlc.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhrZ2d4a3l6eWpwdGFwbnFiZGxjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDE1OTgyNTksImV4cCI6MjA1NzE3NDI1OX0.RSq8Fl40y1PRTl_77UbJWwqbdMIY9mWE7YTH4a-1NsQ',
    debug: true, // Set to false in production
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
      // Start with the HomePage which has the "Get Started" button
      home: const HomePage(),
      routes: {
        '/homepage': (context) => const HomePage(),
        'Homepage': (context) => const HomePage(),
        'SignUp': (context) => const SignUpPage(),
        'Login': (context) => const LoginPage(),
        '/profile': (context) => const ProfilePage(),
        '/forgot-password': (context) => const ForgotPasswordPage(),
      },
    );
  }
}

// This class handles checking authentication and redirecting authenticated users
class AuthCheckRedirect extends StatefulWidget {
  final Widget child;
  
  const AuthCheckRedirect({Key? key, required this.child}) : super(key: key);

  @override
  _AuthCheckRedirectState createState() => _AuthCheckRedirectState();
}

class _AuthCheckRedirectState extends State<AuthCheckRedirect> {
  bool _isChecking = true;
  bool _isAuthenticated = false;
  
  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuth();
    });
  }
  
  Future<void> _checkAuth() async {
    final isAuth = AuthService.isAuthenticated;
    
    if (mounted) {
      setState(() {
        _isAuthenticated = isAuth;
        _isChecking = false;
      });
      
      // If authenticated, redirect to home page
      if (_isAuthenticated) {
        Navigator.of(context).pushReplacementNamed('Homepage');
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return widget.child;
  }
}