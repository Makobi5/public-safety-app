// lib/screens/home_page.dart

import 'package:flutter/material.dart';
import 'sign_up.dart'; // Import SignUpPage
import 'package:supabase_flutter/supabase_flutter.dart';
import '../service/auth_service.dart';
import 'forgot_password.dart'; // Import the ForgotPasswordPage
import 'incident_report_form.dart'; // Import the IncidentReportFormPage
import 'admin_dashboard.dart'; // Import the AdminDashboard

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  static String routeName = 'Homepage';
  static String routePath = '/homepage';

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isAuthenticated = false;
  bool _isAdmin = false;

@override
void initState() {
  super.initState();
  _checkAuthentication();
  
  // Listen for auth state changes
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    final AuthChangeEvent event = data.event;
    if (event == AuthChangeEvent.signedIn) {
      setState(() {
        _isAuthenticated = true;
      });
    } else if (event == AuthChangeEvent.signedOut) {
      setState(() {
        _isAuthenticated = false;
      });
    }
  });
  
  print("HomePage initState completed");
}

Future<void> _checkAuthentication() async {
  final isAuth = AuthService.isAuthenticated;
  bool isAdmin = false;
  
  if (isAuth) {
    isAdmin = await AuthService.isUserAdmin();
    print("User is admin: $isAdmin"); // Add this debug log
  }
  
  setState(() {
    _isAuthenticated = isAuth;
    _isAdmin = isAdmin;
  });
}

  @override
  Widget build(BuildContext context) {
    print("HomePage.build called");
    
    // Get screen size for responsive design
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;

    return Scaffold(
      key: scaffoldKey,
      appBar: AppBar(
        title: const Text(
          'PSRA',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF003366),
        elevation: 0,
        actions: [
          if (_isAuthenticated && _isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings),
              onPressed: () {
                Navigator.pushNamed(context, 'AdminDashboard');
              },
              tooltip: 'Admin Dashboard',
            ),
          if (_isAuthenticated)
            IconButton(
              icon: const Icon(Icons.account_circle),
              onPressed: () {
                Navigator.pushNamed(context, '/profile');
              },
              tooltip: 'Profile',
            ),
          IconButton(
            icon: Icon(_isAuthenticated ? Icons.logout : Icons.login),
            onPressed: () async {
              if (_isAuthenticated) {
                try {
                  await AuthService.signOut();
                  setState(() {
                    _isAuthenticated = false;
                    _isAdmin = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Successfully logged out')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${e.toString()}')),
                  );
                }
              } else {
                Navigator.pushNamed(context, 'Login');
              }
            },
            tooltip: _isAuthenticated ? 'Sign Out' : 'Sign In',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: screenSize.width * 0.05,
              vertical: 20.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      Hero(
                        tag: 'logo',
                        child: Container(
                          height: screenSize.height * 0.15,
                          width: screenSize.height * 0.15,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.shield,
                            size: screenSize.height * 0.08,
                            color: const Color(0xFF003366),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Public Safety Reporting App',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 24 : 32,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF003366),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _isAdmin 
                          ? 'Administrator Portal'
                          : 'Keeping our community safe together',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 16 : 18,
                          color: _isAdmin ? Colors.blue.shade700 : Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                // Admin welcome message
                if (_isAuthenticated && _isAdmin)
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.verified_user, color: Colors.blue.shade700),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Welcome, Administrator',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You have admin privileges. Access the Admin Dashboard to manage users and system settings.',
                          style: TextStyle(
                            color: Colors.blue.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 32),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade50, Colors.grey.shade100],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 1,
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isAdmin
                            ? 'Manage community safety reports and resources'
                            : 'Report safety concerns and help create a safer neighborhood',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isSmallScreen ? 16 : 18,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF003366),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Show different feature items based on role
                      if (_isAdmin) ...[
                        FeatureItem(
                          icon: Icons.dashboard,
                          text: 'Access administrative tools',
                          isSmallScreen: isSmallScreen,
                        ),
                        const SizedBox(height: 16),
                        FeatureItem(
                          icon: Icons.people,
                          text: 'Manage user accounts',
                          isSmallScreen: isSmallScreen,
                        ),
                        const SizedBox(height: 16),
                        FeatureItem(
                          icon: Icons.assessment,
                          text: 'Review and respond to reports',
                          isSmallScreen: isSmallScreen,
                        ),
                        const SizedBox(height: 16),
                        FeatureItem(
                          icon: Icons.settings,
                          text: 'Configure system settings',
                          isSmallScreen: isSmallScreen,
                        ),
                      ] else ...[
                        FeatureItem(
                          icon: Icons.assignment_turned_in,
                          text: 'Report incidents easily',
                          isSmallScreen: isSmallScreen,
                        ),
                        const SizedBox(height: 16),
                        FeatureItem(
                          icon: Icons.track_changes,
                          text: 'Track your reports\' status',
                          isSmallScreen: isSmallScreen,
                        ),
                        const SizedBox(height: 16),
                        FeatureItem(
                          icon: Icons.group_work,
                          text: 'Support safety initiatives',
                          isSmallScreen: isSmallScreen,
                        ),
                        const SizedBox(height: 16),
                        FeatureItem(
                          icon: Icons.notifications_active,
                          text: 'Receive important alerts',
                          isSmallScreen: isSmallScreen,
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: screenSize.height * 0.05),
                Center(
                  child: Container(
                    width: isSmallScreen ? screenSize.width * 0.6 : screenSize.width * 0.4,
                    height: isSmallScreen ? 48 : 56,
                    child: ElevatedButton(
                      onPressed: () {
                        print("Button pressed");
                        if (_isAuthenticated) {
                          if (_isAdmin) {
                            // Navigate to admin dashboard for admins
                            Navigator.pushNamed(context, 'AdminDashboard');
                          } else {
                            // Navigate to incident report form for regular users
                            Navigator.pushNamed(context, 'IncidentReport');
                          }
                        } else {
                          // Navigate to account selection if not authenticated
                          try {
                            Navigator.push(
                              context, 
                              MaterialPageRoute(builder: (context) => const AccountTypeSelectionPage())
                            );
                          } catch (e) {
                            print("Error navigating: $e");
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Navigation error: $e')),
                            );
                          }
                        }
                      },
                      style: ButtonStyle(
                        backgroundColor: MaterialStateProperty.all(const Color(0xFF003366)),
                        shape: MaterialStateProperty.all(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        elevation: MaterialStateProperty.all(3),
                      ),
                      child: Text(
                        _isAdmin 
                            ? 'Admin Dashboard' 
                            : (_isAuthenticated ? 'Report Incident' : 'Get Started'),
                        style: TextStyle(
                          fontSize: isSmallScreen ? 15 : 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: screenSize.height * 0.03),
                if (!_isAdmin)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.emergency, color: Colors.red.shade700, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Emergency? Call 999',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Feature item component for cleaner code organization
class FeatureItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isSmallScreen;

  const FeatureItem({
    Key? key,
    required this.icon,
    required this.text,
    required this.isSmallScreen,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF003366).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF003366),
            size: isSmallScreen ? 22 : 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: isSmallScreen ? 15 : 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class AccountTypeSelectionPage extends StatelessWidget {
  const AccountTypeSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Select Account Type',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF003366),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: screenSize.width * 0.05,
              vertical: 24.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: screenSize.height * 0.05),
                Hero(
                  tag: 'logo',
                  child: Container(
                    height: screenSize.height * 0.1,
                    width: screenSize.height * 0.1,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.shield,
                      size: screenSize.height * 0.06,
                      color: const Color(0xFF003366),
                    ),
                  ),
                ),
                SizedBox(height: screenSize.height * 0.04),
                Text(
                  'Select your account type',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 22 : 26,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF003366),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Choose the role that best describes you',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 15 : 17,
                    color: Colors.grey[700],
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: screenSize.height * 0.06),
                
                // Community Member Card
                _buildAccountTypeCard(
                  context,
                  title: 'Community Member',
                  description: 'Report incidents and track community safety initiatives',
                  icon: Icons.person,
                  isSmallScreen: isSmallScreen,
                  isAdmin: false,
                ),
                
                SizedBox(height: screenSize.height * 0.03),
                
                // Admin Card
                _buildAccountTypeCard(
                  context,
                  title: 'Admin',
                  description: 'Manage reports and coordinate response efforts',
                  icon: Icons.admin_panel_settings,
                  isSmallScreen: isSmallScreen,
                  isAdmin: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildAccountTypeCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required bool isSmallScreen,
    required bool isAdmin,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (isAdmin) {
              // Navigate to admin login page
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage(isAdminLogin: true)),
              );
            } else {
              // Navigate to regular login page
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage(isAdminLogin: false)),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: isSmallScreen ? 30 : 36,
                    color: const Color(0xFF003366),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: isSmallScreen ? 18 : 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF003366),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: isSmallScreen ? 14 : 15,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Color(0xFF003366),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  final bool isAdminLogin;
  
  const LoginPage({
    super.key, 
    this.isAdminLogin = false // Default to regular user login
  });

  static const routeName = 'Login';
  static const routePath = '/login';

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;
  
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
  
// Update this method in your LoginPage class

// Update the _signIn method in _LoginPageState class

Future<void> _signIn() async {
  if (!_formKey.currentState!.validate()) return;
  
  setState(() {
    _isLoading = true;
    _errorMessage = null;
  });

  try {
    if (widget.isAdminLogin) {
      // Admin login flow
      final response = await AuthService.signInAsAdmin(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      
      if (response.user != null) {
        if (mounted) {
          // Navigate to admin dashboard on successful admin login
          Navigator.of(context).pushNamedAndRemoveUntil(
            'AdminDashboard', 
            (route) => false
          );
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Admin login successful!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } else {
      // Regular user login flow
      final response = await AuthService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      
      if (response.user != null) {
        if (mounted) {
          // Check if user is admin (some admins might try to login through regular user flow)
          final isAdmin = await AuthService.isUserAdmin();
          
          // Navigate based on user role
          if (isAdmin) {
            Navigator.of(context).pushNamedAndRemoveUntil(
              'AdminDashboard', 
              (route) => false
            );
          } else {
            // Navigate to user dashboard for regular users
            Navigator.of(context).pushNamedAndRemoveUntil(
              'UserDashboard', 
              (route) => false
            );
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Login successful!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    }
  } on AuthException catch (e) {
    setState(() {
      _errorMessage = e.message;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_errorMessage ?? 'An error occurred during login'),
        backgroundColor: Colors.red,
      ),
    );
  } catch (e) {
    setState(() {
      _errorMessage = 'An unexpected error occurred. Please try again.';
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_errorMessage!),
        backgroundColor: Colors.red,
      ),
    );
  } finally {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isAdminLogin ? 'Admin Login' : 'Login',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF003366),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: screenSize.width * 0.05,
              vertical: 24.0,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: screenSize.height * 0.02),
                  Text(
                    widget.isAdminLogin ? 'Admin Access' : 'Welcome Back',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 24 : 28,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF003366),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.isAdminLogin 
                      ? 'Login with administrator credentials'
                      : 'Login to continue to your account',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 15 : 17,
                      color: Colors.grey[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  // Show admin login notice if applicable
                  if (widget.isAdminLogin)
                    Container(
                      margin: const EdgeInsets.only(top: 20),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Note: Only authorized administrators can access this area. New admin accounts must be created by existing administrators.',
                              style: TextStyle(color: Colors.blue.shade800),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  SizedBox(height: screenSize.height * 0.05),
                  
                  // Show error message if there is one
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade300),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade800),
                      ),
                    ),
                  
                  // Email Field
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      hintText: 'Enter your email',
                      prefixIcon: const Icon(Icons.email, color: Color(0xFF003366)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF003366), width: 2),
                      ),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!value.contains('@') || !value.contains('.')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  
                  SizedBox(height: screenSize.height * 0.03),
                  
                  // Password Field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Enter your password',
                      prefixIcon: const Icon(Icons.lock, color: Color(0xFF003366)),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility : Icons.visibility_off,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF003366), width: 2),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        // Navigate to ForgotPasswordPage instead of showing dialog
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ForgotPasswordPage()),
                        );
                      },
                      child: const Text(
                        'Forgot Password?',
                        style: TextStyle(
                          color: Color(0xFF003366),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  
                  SizedBox(height: screenSize.height * 0.03),
                  
                  // Login Button
                  Center(
                    child: Container(
                      width: isSmallScreen ? screenSize.width * 0.7 : screenSize.width * 0.5,
                      height: isSmallScreen ? 46 : 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _signIn,
                        style: ButtonStyle(
                          backgroundColor: MaterialStateProperty.all(
                            widget.isAdminLogin 
                                ? Colors.indigo.shade700 
                                : const Color(0xFF003366)
                          ),
                          shape: MaterialStateProperty.all(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          elevation: MaterialStateProperty.all(3),
                        ),
                        child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              widget.isAdminLogin ? 'Admin Login' : 'Login',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                      ),),
                  ),
                  
                  SizedBox(height: screenSize.height * 0.03),
                  
                  // Register option - only show for regular user login
                  if (!widget.isAdminLogin)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Don\'t have an account?',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 15,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            // Navigate to registration
                            print("Register Now button pressed");
                            try {
                              Navigator.pushNamed(context, 'SignUp');
                            } catch (e) {
                              print("Error navigating to SignUp: $e");
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Navigation error: $e')),
                              );
                            }
                          },
                          child: const Text(
                            'Register Now',
                            style: TextStyle(
                              color: Color(0xFF003366),
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                  // Admin instructions - only show for admin login
                  if (widget.isAdminLogin)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Text(
                        'For admin account requests, please contact an existing administrator.',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
