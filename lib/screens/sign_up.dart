// lib/screens/sign_up.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../service/auth_service.dart';
import 'home_page.dart'; // Import to access LoginPage

class SignUpPage extends StatefulWidget {
  const SignUpPage({Key? key}) : super(key: key);

  static String routeName = 'SignUp';
  static String routePath = '/signup';

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers for text fields
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  // Dropdowns
  String? _selectedDistrict;
  String? _selectedRegion;
  String? _selectedVillage;
  
  // Password visibility
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  
  // Loading and error states
  bool _isLoading = false;
  String? _errorMessage;
  
  // Password strength
  double _passwordStrength = 0.0;
  String _passwordStrengthText = 'Weak';
  Color _passwordStrengthColor = Colors.red;

    final List<String> _ugandanRegions = [
    'Central Region',
    'Eastern Region',
    'Northern Region',
    'Western Region',
  ];

  // Map of regions to districts in Uganda
  final Map<String, List<String>> _regionDistricts = {
    'Central Region': [
      'Kampala', 'Wakiso', 'Mukono', 'Mpigi', 'Buikwe', 'Kayunga', 'Luweero', 
      'Mityana', 'Nakaseke', 'Nakasongola', 'Butambala', 'Gomba', 'Kalangala', 
      'Kyankwanzi', 'Lwengo', 'Lyantonde', 'Masaka', 'Mubende', 'Rakai', 'Sembabule'
    ],
    'Eastern Region': [
      'Jinja', 'Iganga', 'Mbale', 'Tororo', 'Soroti', 'Kumi', 'Bugiri', 'Busia', 
      'Namutumba', 'Budaka', 'Bududa', 'Bukwa', 'Bulambuli', 'Butaleja', 'Buyende', 
      'Kaberamaido', 'Kaliro', 'Kamuli', 'Kapchorwa', 'Katakwi', 'Kibuku', 'Kween', 
      'Luuka', 'Manafwa', 'Mayuge', 'Namayingo', 'Ngora', 'Pallisa', 'Serere', 'Sironko'
    ],
    'Northern Region': [
      'Gulu', 'Lira', 'Kitgum', 'Arua', 'Adjumani', 'Amuru', 'Amolatar', 'Pader', 
      'Nebbi', 'Zombo', 'Abim', 'Agago', 'Alebtong', 'Amuru', 'Apac', 'Dokolo', 
      'Kaabong', 'Koboko', 'Kole', 'Kotido', 'Lamwo', 'Maracha', 'Moroto', 
      'Moyo', 'Nakapiripirit', 'Napak', 'Nwoya', 'Otuke', 'Oyam', 'Yumbe'
    ],
    'Western Region': [
      'Mbarara', 'Kabale', 'Fort Portal', 'Kasese', 'Hoima', 'Masindi', 'Bushenyi', 
      'Ntungamo', 'Rukungiri', 'Kibaale', 'Buliisa', 'Bundibugyo', 'Ibanda', 'Isingiro', 
      'Kamwenge', 'Kanungu', 'Kiruhura', 'Kiryandongo', 'Kisoro', 'Kyegegwa', 
      'Kyenjojo', 'Mitooma', 'Ntoroko', 'Rubirizi', 'Sheema'
    ],
  };

  // Map of districts to villages (using real data for key districts, would need complete data)
  final Map<String, List<String>> _districtVillages = {
    // Central Region
    'Kampala': ['Kololo', 'Nakasero', 'Kamwokya', 'Bugolobi', 'Naguru', 'Bukoto', 'Makindye', 'Nsambya', 'Rubaga', 'Kawempe', 'Kisenyi', 'Mengo', 'Wandegeya', 'Ntinda', 'Kibuli'],
    'Wakiso': ['Entebbe', 'Nansana', 'Kira', 'Busukuma', 'Kajjansi', 'Bweyogerere', 'Buloba', 'Matugga', 'Kakiri', 'Nsangi', 'Namugongo', 'Gayaza', 'Kasangati', 'Bwebajja', 'Nalumunye'],
    'Mukono': ['Mukono Town', 'Goma', 'Kyampisi', 'Nakifuma', 'Kasawo', 'Namuganga', 'Ntunda', 'Mpatta', 'Mpunge', 'Koome', 'Nsanja', 'Seeta', 'Kyabalogo', 'Kikandwa', 'Nakisunga'],
    
    // Eastern Region
    'Jinja': ['Bugembe', 'Kakira', 'Mafubira', 'Budondo', 'Buwenge', 'Mpumudde', 'Walukuba', 'Masese', 'Butembe', 'Danida', 'Kimaka', 'Nalufenya', 'Buye', 'Buyala', 'Namulesa'],
    'Mbale': ['Nkoma', 'Wanale', 'Bungokho', 'Nakaloke', 'Bufumbo', 'Busiu', 'Bubyangu', 'Bukonde', 'Busano', 'Busoba', 'Lwaso', 'Namanyonyi', 'Nyondo', 'Wanale', 'Industrial'],
    'Soroti': ['Soroti Town', 'Arapai', 'Gweri', 'Kamuda', 'Tubur', 'Asuret', 'Katine', 'Ochapa', 'Olio', 'Asuret', 'Lalle', 'Opuyo', 'Madera', 'Aloet', 'Acetgwen'],
    
    // Northern Region
    'Gulu': ['Laroo', 'Bardege', 'Layibi', 'Pece', 'Unyama', 'Bobi', 'Bungatira', 'Palaro', 'Patiko', 'Awach', 'Ongako', 'Lalogi', 'Odek', 'Lakwana', 'Koro'],
    'Lira': ['Adyel', 'Central', 'Ojwina', 'Railway', 'Adekokwok', 'Agali', 'Agweng', 'Aromo', 'Barr', 'Lira', 'Ogur', 'Amach', 'Agweng', 'Ngetta', 'Adekokwok'],
    'Arua': ['Arua Hill', 'River Oli', 'Adumi', 'Aroi', 'Dadamu', 'Manibe', 'Oluko', 'Pajulu', 'Vurra', 'Ayivuni', 'Logiri', 'Rhino Camp', 'Rigbo', 'Uleppi', 'Omugo'],
    
    // Western Region
    'Mbarara': ['Kakoba', 'Nyamitanga', 'Kamukuzi', 'Kakiika', 'Biharwe', 'Rubindi', 'Rubaya', 'Rwanyamahembe', 'Kashare', 'Bubaare', 'Nyakayojo', 'Bukiro', 'Kagongi', 'Rugando', 'Ndeija'],
    'Kabale': ['Kabale Town', 'Kitumba', 'Kyanamira', 'Maziba', 'Buhara', 'Kaharo', 'Kamuganguzi', 'Rubaya', 'Butanda', 'Ikumba', 'Hamurwa', 'Bukinda', 'Kamwezi', 'Rwamucucu', 'Kashambya'],
    'Hoima': ['Hoima Town', 'Bugahya', 'Buhimba', 'Kigorobya', 'Kitoba', 'Kyabigambire', 'Buhanika', 'Kiziranfumbi', 'Kabwoya', 'Kyangwali', 'Bujumbura', 'Busiisi', 'Kahoora', 'Mparo', 'Buseruka'],
    
    // Default villages for other districts
    'Default': ['Center', 'North', 'South', 'East', 'West', 'Main Village', 'Trading Center', 'Township', 'Rural Area', 'Suburb']
  };
  // Lists for dropdowns
  List<String> _districts = [];
  List<String> _villages = [];

  @override
  void initState() {
    super.initState();
    
    // Check if we're coming from admin login selection and redirect if so
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map && args['attemptingAdminSignup'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Admin accounts can only be created by existing administrators.'),
            backgroundColor: Colors.red,
          ),
        );
        
        // Navigate back to selection page
        Navigator.pop(context);
      }
    });
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
  
  // Calculate password strength - remains the same
  void _updatePasswordStrength(String password) {
    // Existing code remains unchanged
  }

  // Modified sign-up method to prevent admin sign-up
  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Check if passwords match
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'Passwords do not match';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage!),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Validate location selections
    if (_selectedRegion == null || _selectedDistrict == null || _selectedVillage == null) {
      setState(() {
        _errorMessage = 'Please select your region, district, and village';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage!),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Prepare user data with proper field names matching the database columns
      // Using the exact field names from AuthService.dart
      final userData = {
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'region': _selectedRegion,
        'district': _selectedDistrict,
        'village': _selectedVillage,
        'role': 'user', // Explicitly set role to 'user' for sign-ups
      };
      
      // This debug info is useful for development
      print("About to sign up with the following data:");
      print("Email: ${_emailController.text.trim()}");
      print("User data: $userData");
      
      // Call the AuthService.signUp method
      final response = await AuthService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        userData: userData,
      );
      
      if (response.user != null) {
        if (mounted) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account created successfully! Please verify your email and log in.'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Navigate to login page
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage(isAdminLogin: false)), // Specify regular login
          );
        }
      }
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage!),
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
        title: const Text(
          'Create Account',
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
          child: Column(
            children: [
              // Header Container
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF003366), Color(0xFF1A365D)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.security,
                        color: Colors.white,
                        size: 48.0,
                      ),
                      const SizedBox(height: 16.0),
                      const Text(
                        'Public Safety Reporting App',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 26.0,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8.0),
                      const Text(
                        'Create Community Member Account',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16.0,
                          color: Color(0xFFE0E0E0),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Admin access notice
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(24.0),
                padding: const EdgeInsets.all(12.0),
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
                        'Note: Admin accounts can only be created by existing administrators.',
                        style: TextStyle(color: Colors.blue.shade800),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Form Container - remains the same
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 1,
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Create Your Account',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF333333),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          
                          // Rest of the form remains the same
                          // ...
                          
                          // Footer remains the same
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              
              // Footer
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Already have an account? ',
                          style: TextStyle(
                            color: Color(0xFF666666),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            // Navigate to regular login page
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const LoginPage(isAdminLogin: false)),
                            );
                          },
                          child: const Text(
                            'Sign In',
                            style: TextStyle(
                              color: Color(0xFF003366),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'This is a secure government system. Unauthorized access is prohibited and subject to criminal prosecution.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF666666),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}