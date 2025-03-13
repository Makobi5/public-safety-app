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

  // List of Ugandan regions
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
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
  
  // Calculate password strength
  void _updatePasswordStrength(String password) {
    double strength = 0;
    
    if (password.isEmpty) {
      strength = 0;
    } else {
      // Length contribution
      if (password.length >= 8) strength += 0.2;
      
      // Character variety contribution
      if (password.contains(RegExp(r'[A-Z]'))) strength += 0.2; // uppercase
      if (password.contains(RegExp(r'[a-z]'))) strength += 0.2; // lowercase
      if (password.contains(RegExp(r'[0-9]'))) strength += 0.2; // digits
      if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength += 0.2; // special chars
    }
    
    // Update UI
    setState(() {
      _passwordStrength = strength;
      
      if (strength < 0.3) {
        _passwordStrengthText = 'Weak';
        _passwordStrengthColor = Colors.red;
      } else if (strength < 0.7) {
        _passwordStrengthText = 'Medium';
        _passwordStrengthColor = Colors.orange;
      } else {
        _passwordStrengthText = 'Strong';
        _passwordStrengthColor = Colors.green;
      }
    });
  }

  // Modified sign-up method to align with AuthService.dart
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
            MaterialPageRoute(builder: (context) => const LoginPage()),
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
                        'Create Account',
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
              
              // Form Container
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
                          
                          // First Name Field
                          TextFormField(
                            controller: _firstNameController,
                            decoration: InputDecoration(
                              labelText: 'First Name*',
                              hintText: 'Enter your first name',
                              filled: true,
                              fillColor: const Color(0xFFF5F5F5),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.0),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE0E0E0),
                                ),
                              ),
                              suffixIcon: const Icon(Icons.person),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your first name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          // Last Name Field
                          TextFormField(
                            controller: _lastNameController,
                            decoration: InputDecoration(
                              labelText: 'Last Name*',
                              hintText: 'Enter your last name',
                              filled: true,
                              fillColor: const Color(0xFFF5F5F5),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.0),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE0E0E0),
                                ),
                              ),
                              suffixIcon: const Icon(Icons.person),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your last name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          // Region Dropdown
                          DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: 'Select Region*',
                              filled: true,
                              fillColor: const Color(0xFFF5F5F5),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.0),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE0E0E0),
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.arrow_drop_down),
                            isExpanded: true,
                            value: _selectedRegion,
                            hint: const Text('Select a region'),
                            items: _ugandanRegions.map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedRegion = value;
                                _selectedDistrict = null;
                                _selectedVillage = null;
                                
                                // Update districts based on selected region
                                if (value != null && _regionDistricts.containsKey(value)) {
                                  _districts = _regionDistricts[value]!;
                                } else {
                                  _districts = [];
                                }
                                
                                _villages = [];
                              });
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please select a region';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          // District Dropdown
                          DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: 'Select District*',
                              filled: true,
                              fillColor: const Color(0xFFF5F5F5),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.0),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE0E0E0),
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.arrow_drop_down),
                            isExpanded: true,
                            value: _selectedDistrict,
                            hint: const Text('Select a district'),
                            items: _districts.map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: _districts.isEmpty 
                              ? null 
                              : (value) {
                                  setState(() {
                                    _selectedDistrict = value;
                                    _selectedVillage = null;
                                    
                                    // Update villages based on selected district
                                    if (value != null && _districtVillages.containsKey(value)) {
                                      _villages = _districtVillages[value]!;
                                    } else {
                                      // Use default villages if specific ones aren't available
                                      _villages = _districtVillages['Default']!;
                                    }
                                  });
                                },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please select a district';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          // Village Dropdown
                          DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: 'Select Village*',
                              filled: true,
                              fillColor: const Color(0xFFF5F5F5),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.0),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE0E0E0),
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.arrow_drop_down),
                            isExpanded: true,
                            value: _selectedVillage,
                            hint: const Text('Select a village'),
                            items: _villages.map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: _villages.isEmpty 
                              ? null 
                              : (value) {
                                  setState(() {
                                    _selectedVillage = value;
                                  });
                                },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please select a village';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          // Email Field
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: 'Email Address*',
                              hintText: 'Enter your email address',
                              filled: true,
                              fillColor: const Color(0xFFF5F5F5),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.0),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE0E0E0),
                                ),
                              ),
                              suffixIcon: const Icon(Icons.email),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your email';
                              }
                              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                return 'Please enter a valid email address';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          // Password Field
                          TextFormField(
                            controller: _passwordController,
                            obscureText: !_passwordVisible,
                            decoration: InputDecoration(
                              labelText: 'Password*',
                              hintText: 'Enter your password',
                              filled: true,
                              fillColor: const Color(0xFFF5F5F5),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.0),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE0E0E0),
                                ),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _passwordVisible 
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _passwordVisible = !_passwordVisible;
                                  });
                                },
                              ),
                            ),
                            onChanged: (value) {
                              _updatePasswordStrength(value);
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a password';
                              }
                              if (value.length < 8) {
                                return 'Password must be at least 8 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          
                          // Password Strength Indicator
                          Container(
                            width: double.infinity,
                            height: 4.0,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0E0E0),
                              borderRadius: BorderRadius.circular(2.0),
                            ),
                            child: FractionallySizedBox(
                              widthFactor: _passwordStrength,
                              child: Container(
                                height: 4.0,
                                decoration: BoxDecoration(
                                  color: _passwordStrengthColor,
                                  borderRadius: BorderRadius.circular(2.0),
                                ),
                              ),
                            ),
                          ),
                          
                          // Password Strength Text
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              'Password Strength: $_passwordStrengthText',
                              style: TextStyle(
                                fontSize: 12.0,
                                color: _passwordStrengthColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Confirm Password Field
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: !_confirmPasswordVisible,
                            decoration: InputDecoration(
                              labelText: 'Confirm Password*',
                              hintText: 'Confirm your password',
                              filled: true,
                              fillColor: const Color(0xFFF5F5F5),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.0),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE0E0E0),
                                ),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _confirmPasswordVisible 
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _confirmPasswordVisible = !_confirmPasswordVisible;
                                  });
                                },
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please confirm your password';
                              }
                              if (value != _passwordController.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          
                          // Create Account Button
                          Center(
                            child: SizedBox(
                              width: isSmallScreen ? screenSize.width * 0.7 : screenSize.width * 0.5,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _signUp,
                                style: ButtonStyle(
                                  backgroundColor: MaterialStateProperty.all(const Color(0xFF003366)),
                                  shape: MaterialStateProperty.all(
                                    RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(25.0),
                                    ),
                                  ),
                                ),
                                child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                    'Create Account',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                              ),
                            ),
                          ),
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
                            // Navigate to login page
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const LoginPage()),
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