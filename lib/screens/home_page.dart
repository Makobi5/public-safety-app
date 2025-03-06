import 'package:flutter/material.dart';
import 'sign_up.dart'; // Import SignUpPage

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  static String routeName = 'Homepage';
  static String routePath = '/homepage';

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    print("HomePage initState completed");
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
                        'Keeping our community safe together',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 16 : 18,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
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
                        'Report safety concerns and help create a safer neighborhood',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isSmallScreen ? 16 : 18,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF003366),
                        ),
                      ),
                      const SizedBox(height: 24),
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
                  ),
                ),
                SizedBox(height: screenSize.height * 0.05),
                Center(
                  child: Container(
                    width: isSmallScreen ? screenSize.width * 0.6 : screenSize.width * 0.4,
                    height: isSmallScreen ? 48 : 56,
                    child: ElevatedButton(
                      onPressed: () {
                        print("Get Started button pressed");
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
                        'Get Started',
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
                ),
                
                SizedBox(height: screenSize.height * 0.03),
                
                // Admin Card
                _buildAccountTypeCard(
                  context,
                  title: 'Admin',
                  description: 'Manage reports and coordinate response efforts',
                  icon: Icons.admin_panel_settings,
                  isSmallScreen: isSmallScreen,
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
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const LoginPage())
            );
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
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  
  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    
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
                    'Welcome Back',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 24 : 28,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF003366),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Login to continue to your account',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 15 : 17,
                      color: Colors.grey[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: screenSize.height * 0.05),
                  
                  // Email Field
                  TextFormField(
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
                        // Forgot password functionality
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Password reset feature coming soon')),
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
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            // Handle login
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Login functionality will be implemented soon')),
                            );
                          }
                        },
                        style: ButtonStyle(
                          backgroundColor: MaterialStateProperty.all(const Color(0xFF003366)),
                          shape: MaterialStateProperty.all(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          elevation: MaterialStateProperty.all(3),
                        ),
                        child: const Text(
                          'Login',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  SizedBox(height: screenSize.height * 0.03),
                  
                  // Register option
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
                            Navigator.push(
                              context, 
                              MaterialPageRoute(builder: (context) => const SignUpPage())
                            );
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}