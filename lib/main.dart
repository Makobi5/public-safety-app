import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'screens/home_page.dart';  // Adjust import path as needed
import 'screens/sign_up.dart';  // Adjust import path as needed

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Community SafeWatch',
      theme: ThemeData(
        primaryColor: const Color(0xFF003366),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Inter',
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => HomePage(),
        'SignUp': (context) => SignUpPage(),
        'Login': (context) => LoginPage(),
      },
    );
  }
}

// This is a placeholder - replace with your actual LoginPage
class LoginPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Login',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF003366),
      ),
      body: Center(
        child: Text('Login Page'),
      ),
    );
  }
}