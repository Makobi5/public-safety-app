// lib/main.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async'; // For StreamSubscription
import 'screens/home_page.dart';
import 'screens/sign_up.dart';
import 'service/auth_service.dart';
import 'screens/profile_page.dart';
import 'screens/forgot_password.dart';
import 'screens/incident_report_form.dart'; // Import the incident report form
import 'screens/admin_dashboard.dart'; // Import the admin dashboard
import 'screens/user_dashboard.dart'; // Import the new user dashboard

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
        'Login': (context) => const LoginPage(isAdminLogin: false), // Specify regular login
        'AdminLogin': (context) => const LoginPage(isAdminLogin: true), // Admin login route
        '/profile': (context) => const ProfilePage(),
        '/forgot-password': (context) => const ForgotPasswordPage(),
        'IncidentReport': (context) => const IncidentReportFormPage(),
        '/incident-report': (context) => const IncidentReportFormPage(),
        'AdminDashboard': (context) => const AdminDashboard(), // Admin dashboard route
        '/admin-dashboard': (context) => const AdminDashboard(), // Alternative route path
        'UserDashboard': (context) => const UserDashboard(), // Add user dashboard route
        '/user-dashboard': (context) => const UserDashboard(), // Alternative route path
      },
      // Add route generator for handling parameters in routes
      onGenerateRoute: (settings) {
        if (settings.name == 'Login') {
          // Check if we're passing parameters to the login page
          final args = settings.arguments;
          if (args is Map<String, dynamic> && args.containsKey('isAdminLogin')) {
            return MaterialPageRoute(
              builder: (context) => LoginPage(isAdminLogin: args['isAdminLogin']),
            );
          }
          // Default to regular login if no params
          return MaterialPageRoute(
            builder: (context) => const LoginPage(isAdminLogin: false),
          );
        }
        return null;
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
  bool _isAdmin = false;
  
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
    bool isAdmin = false;
    
    if (isAuth) {
      // Check if the user is an admin
      isAdmin = await AuthService.isUserAdmin();
    }
    
    if (mounted) {
      setState(() {
        _isAuthenticated = isAuth;
        _isAdmin = isAdmin;
        _isChecking = false;
      });
      
      // If authenticated, redirect to appropriate page based on role
      if (_isAuthenticated) {
        if (_isAdmin) {
          // For admin users, go to admin dashboard
          Navigator.of(context).pushReplacementNamed('AdminDashboard');
        } else {
          // For regular users, go to user dashboard instead of homepage
          Navigator.of(context).pushReplacementNamed('UserDashboard');
        }
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

// Add a helper class for role-based route access
class RoleBasedRoute extends StatelessWidget {
  final Widget adminRoute;
  final Widget userRoute;
  
  const RoleBasedRoute({
    Key? key,
    required this.adminRoute,
    required this.userRoute,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: AuthService.isUserAdmin(),
      builder: (context, snapshot) {
        // While loading, show loading indicator
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        // If user is admin, show admin route
        if (snapshot.hasData && snapshot.data == true) {
          return adminRoute;
        }
        
        // Otherwise show user route
        return userRoute;
      },
    );
  }
}