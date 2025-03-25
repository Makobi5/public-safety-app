// lib/screens/sign_up.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../service/auth_service.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({Key? key}) : super(key: key);

  static String routeName = 'SignUp';
  static String routePath = '/signup';

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  String? _selectedDistrict;
  String? _selectedRegion;
  String? _selectedVillage;
  
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _errorMessage;
  
  // List of Ugandan regions
  final List<String> _ugandanRegions = [
    'Central Region',
    'Eastern Region',
    'Northern Region',
    'Western Region',
    'Other',
  ];

  // Map of regions to districts in Uganda
  final Map<String, List<String>> _regionDistricts = {
    'Central Region': [
      'Kampala', 'Wakiso', 'Mukono', 'Mpigi', 'Buikwe', 'Kayunga', 'Luweero', 
      'Mityana', 'Nakaseke', 'Nakasongola', 'Butambala', 'Gomba', 'Kalangala', 
      'Kyankwanzi', 'Lwengo', 'Lyantonde', 'Masaka', 'Mubende', 'Rakai', 'Sembabule',
      'Other'
    ],
    'Eastern Region': [
      'Jinja', 'Iganga', 'Mbale', 'Tororo', 'Soroti', 'Kumi', 'Bugiri', 'Busia', 
      'Namutumba', 'Budaka', 'Bududa', 'Bukwa', 'Bulambuli', 'Butaleja', 'Buyende', 
      'Kaberamaido', 'Kaliro', 'Kamuli', 'Kapchorwa', 'Katakwi', 'Kibuku', 'Kween', 
      'Luuka', 'Manafwa', 'Mayuge', 'Namayingo', 'Ngora', 'Pallisa', 'Serere', 'Sironko',
      'Other'
    ],
    'Northern Region': [
      'Gulu', 'Lira', 'Kitgum', 'Arua', 'Adjumani', 'Amuru', 'Amolatar', 'Pader', 
      'Nebbi', 'Zombo', 'Abim', 'Agago', 'Alebtong', 'Amuru', 'Apac', 'Dokolo', 
      'Kaabong', 'Koboko', 'Kole', 'Kotido', 'Lamwo', 'Maracha', 'Moroto', 
      'Moyo', 'Nakapiripirit', 'Napak', 'Nwoya', 'Otuke', 'Oyam', 'Yumbe',
      'Other'
    ],
    'Western Region': [
      'Mbarara', 'Kabale', 'Fort Portal', 'Kasese', 'Hoima', 'Masindi', 'Bushenyi', 
      'Ntungamo', 'Rukungiri', 'Kibaale', 'Buliisa', 'Bundibugyo', 'Ibanda', 'Isingiro', 
      'Kamwenge', 'Kanungu', 'Kiruhura', 'Kiryandongo', 'Kisoro', 'Kyegegwa', 
      'Kyenjojo', 'Mitooma', 'Ntoroko', 'Rubirizi', 'Sheema',
      'Other'
    ],
    'Other': ['Other'],
  };

  // Map of districts to villages
  final Map<String, List<String>> _districtVillages = {
    // Central Region
    'Kampala': ['Kololo', 'Nakasero', 'Kamwokya', 'Bugolobi', 'Naguru', 'Bukoto', 'Makindye', 'Nsambya', 'Rubaga', 'Kawempe', 'Kisenyi', 'Mengo', 'Wandegeya', 'Ntinda', 'Kibuli', 'Other'],
    'Wakiso': ['Entebbe', 'Nansana', 'Kira', 'Busukuma', 'Kajjansi', 'Bweyogerere', 'Buloba', 'Matugga', 'Kakiri', 'Nsangi', 'Namugongo', 'Gayaza', 'Kasangati', 'Bwebajja', 'Nalumunye', 'Other'],
    'Mukono': ['Mukono Town', 'Goma', 'Kyampisi', 'Nakifuma', 'Kasawo', 'Namuganga', 'Ntunda', 'Mpatta', 'Mpunge', 'Koome', 'Nsanja', 'Seeta', 'Kyabalogo', 'Kikandwa', 'Nakisunga', 'Other'],
    
    // Eastern Region
    'Jinja': ['Bugembe', 'Kakira', 'Mafubira', 'Budondo', 'Buwenge', 'Mpumudde', 'Walukuba', 'Masese', 'Butembe', 'Danida', 'Kimaka', 'Nalufenya', 'Buye', 'Buyala', 'Namulesa', 'Other'],
    'Mbale': ['Nkoma', 'Wanale', 'Bungokho', 'Nakaloke', 'Bufumbo', 'Busiu', 'Bubyangu', 'Bukonde', 'Busano', 'Busoba', 'Lwaso', 'Namanyonyi', 'Nyondo', 'Wanale', 'Industrial', 'Other'],
    'Soroti': ['Soroti Town', 'Arapai', 'Gweri', 'Kamuda', 'Tubur', 'Asuret', 'Katine', 'Ochapa', 'Olio', 'Asuret', 'Lalle', 'Opuyo', 'Madera', 'Aloet', 'Acetgwen', 'Other'],
    
    // Northern Region
    'Gulu': ['Laroo', 'Bardege', 'Layibi', 'Pece', 'Unyama', 'Bobi', 'Bungatira', 'Palaro', 'Patiko', 'Awach', 'Ongako', 'Lalogi', 'Odek', 'Lakwana', 'Koro', 'Other'],
    'Lira': ['Adyel', 'Central', 'Ojwina', 'Railway', 'Adekokwok', 'Agali', 'Agweng', 'Aromo', 'Barr', 'Lira', 'Ogur', 'Amach', 'Agweng', 'Ngetta', 'Adekokwok', 'Other'],
    'Arua': ['Arua Hill', 'River Oli', 'Adumi', 'Aroi', 'Dadamu', 'Manibe', 'Oluko', 'Pajulu', 'Vurra', 'Ayivuni', 'Logiri', 'Rhino Camp', 'Rigbo', 'Uleppi', 'Omugo', 'Other'],
    
    // Western Region
    'Mbarara': ['Kakoba', 'Nyamitanga', 'Kamukuzi', 'Kakiika', 'Biharwe', 'Rubindi', 'Rubaya', 'Rwanyamahembe', 'Kashare', 'Bubaare', 'Nyakayojo', 'Bukiro', 'Kagongi', 'Rugando', 'Ndeija', 'Other'],
    'Kabale': ['Kabale Town', 'Kitumba', 'Kyanamira', 'Maziba', 'Buhara', 'Kaharo', 'Kamuganguzi', 'Rubaya', 'Butanda', 'Ikumba', 'Hamurwa', 'Bukinda', 'Kamwezi', 'Rwamucucu', 'Kashambya', 'Other'],
    'Hoima': ['Hoima Town', 'Bugahya', 'Buhimba', 'Kigorobya', 'Kitoba', 'Kyabigambire', 'Buhanika', 'Kiziranfumbi', 'Kabwoya', 'Kyangwali', 'Bujumbura', 'Busiisi', 'Kahoora', 'Mparo', 'Buseruka', 'Other'],
    
    // For other districts
    'Other': ['Other'],
    
    // Default villages for any district not explicitly listed
    'Default': ['Center', 'North', 'South', 'East', 'West', 'Main Village', 'Trading Center', 'Township', 'Rural Area', 'Suburb', 'Other']
  };
  
  // Lists for dropdown menus
  List<String> _districts = [];
  List<String> _villages = [];
  
  // Track "Other" selections
  bool _isOtherRegion = false;
  bool _isOtherDistrict = false;
  bool _isOtherVillage = false;
  
  // Controllers for "Other" text fields
  final TextEditingController _otherRegionController = TextEditingController();
  final TextEditingController _otherDistrictController = TextEditingController();
  final TextEditingController _otherVillageController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
  }
  
  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _otherRegionController.dispose();
    _otherDistrictController.dispose();
    _otherVillageController.dispose();
    super.dispose();
  }
  
  // Calculate password strength
  String _getPasswordStrength(String password) {
    if (password.isEmpty) return '';
    
    int strength = 0;
    if (password.length >= 8) strength++;
    if (password.contains(RegExp(r'[A-Z]'))) strength++;
    if (password.contains(RegExp(r'[a-z]'))) strength++;
    if (password.contains(RegExp(r'[0-9]'))) strength++;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength++;
    
    if (strength <= 2) return 'Weak';
    if (strength <= 4) return 'Good';
    return 'Strong';
  }
  
  // Get color based on password strength
  Color _getPasswordStrengthColor(String strength) {
    switch (strength) {
      case 'Weak':
        return Colors.red;
      case 'Good':
        return Colors.green;
      case 'Strong':
        return Colors.blue;
      default:
        return Colors.transparent;
    }
  }
  
  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    // Check if passwords match
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'Passwords do not match';
        _isLoading = false;
      });
      return;
    }
    
    try {
      // Get region value (use text input if "Other" was selected)
      String region = '';
      if (_selectedRegion == 'Other' && _otherRegionController.text.isNotEmpty) {
        region = _otherRegionController.text.trim();
      } else {
        region = _selectedRegion ?? '';
      }
      
      // Get district value (use text input if "Other" was selected)
      String district = '';
      if (_selectedDistrict == 'Other' && _otherDistrictController.text.isNotEmpty) {
        district = _otherDistrictController.text.trim();
      } else {
        district = _selectedDistrict ?? '';
      }
      
      // Get village value (use text input if "Other" was selected)
      String village = '';
      if (_selectedVillage == 'Other' && _otherVillageController.text.isNotEmpty) {
        village = _otherVillageController.text.trim();
      } else {
        village = _selectedVillage ?? '';
      }
      
      // Prepare user data
      final userData = {
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'region': region,
        'district': district,
        'village': village,
        // No need to set role: 'user' as this is handled in AuthService
      };
      
      print("Attempting to sign up user with data: $userData");
      
      // Call auth service to sign up
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
              content: Text('Registration successful! Please check your email for verification.'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Navigate back to login
          Navigator.pushReplacementNamed(context, 'Login');
        }
      }
    } on AuthException catch (e) {
      print("AuthException during signup: ${e.message}");
      setState(() {
        _errorMessage = e.message;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage ?? 'An error occurred during registration'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      print("Unexpected error during signup: $e");
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
                  // Logo and App Name
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
                  const SizedBox(height: 16),
                  Text(
                    'Public Safety Reporting App',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 20 : 24,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF003366),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  
                  // Title
                  Text(
                    'Create Your Account',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 20 : 22,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF003366),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Fill in the details below to register',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 14 : 15,
                      color: Colors.grey[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  SizedBox(height: screenSize.height * 0.03),
                  
                  // Error message container
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 16),
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
                      labelText: 'First Name',
                      hintText: 'Enter your first name',
                      prefixIcon: const Icon(Icons.person, color: Color(0xFF003366)),
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
                      labelText: 'Last Name',
                      hintText: 'Enter your last name',
                      prefixIcon: const Icon(Icons.person, color: Color(0xFF003366)),
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
                        return 'Please enter your last name';
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Region Dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedRegion,
                    decoration: InputDecoration(
                      labelText: 'Select Region',
                      prefixIcon: const Icon(Icons.map, color: Color(0xFF003366)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF003366), width: 2),
                      ),
                    ),
                    items: _ugandanRegions.map((String region) {
                      return DropdownMenuItem<String>(
                        value: region,
                        child: Text(region),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedRegion = newValue;
                        _selectedDistrict = null;
                        _selectedVillage = null;
                        _isOtherRegion = newValue == 'Other';
                        
                        // Update districts based on selected region
                        if (newValue != null && _regionDistricts.containsKey(newValue)) {
                          _districts = _regionDistricts[newValue]!;
                        } else {
                          _districts = [];
                        }
                        
                        _villages = [];
                      });
                    },
                    validator: (value) => value == null ? 'Please select a region' : null,
                  ),
                  
                  // "Other" Region field (conditionally shown)
                  if (_isOtherRegion) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _otherRegionController,
                      decoration: InputDecoration(
                        labelText: 'Specify Region',
                        hintText: 'Enter region name',
                        prefixIcon: const Icon(Icons.edit_location_alt, color: Color(0xFF003366)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF003366), width: 2),
                        ),
                      ),
                      validator: (value) {
                        if (_isOtherRegion && (value == null || value.isEmpty)) {
                          return 'Please specify a region name';
                        }
                        return null;
                      },
                    ),
                  ],
                  
                  const SizedBox(height: 16),
                  
                  // District Dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedDistrict,
                    decoration: InputDecoration(
                      labelText: 'Select District',
                      prefixIcon: const Icon(Icons.location_city, color: Color(0xFF003366)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF003366), width: 2),
                      ),
                    ),
                    items: _districts.map((String district) {
                      return DropdownMenuItem<String>(
                        value: district,
                        child: Text(district),
                      );
                    }).toList(),
                    onChanged: _districts.isEmpty 
                      ? null 
                      : (String? newValue) {
                          setState(() {
                            _selectedDistrict = newValue;
                            _selectedVillage = null;
                            _isOtherDistrict = newValue == 'Other';
                            
                            // Update villages based on selected district
                            if (newValue != null && _districtVillages.containsKey(newValue)) {
                              _villages = _districtVillages[newValue]!;
                            } else {
                              // Use default villages if specific ones aren't available
                              _villages = _districtVillages['Default']!;
                            }
                          });
                        },
                    validator: (value) {
                      if (_selectedRegion != null && (value == null || value.isEmpty)) {
                        return 'Please select a district';
                      }
                      return null;
                    },
                  ),
                  
                  // "Other" District field (conditionally shown)
                  if (_isOtherDistrict) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _otherDistrictController,
                      decoration: InputDecoration(
                        labelText: 'Specify District',
                        hintText: 'Enter district name',
                        prefixIcon: const Icon(Icons.edit_location_alt, color: Color(0xFF003366)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF003366), width: 2),
                        ),
                      ),
                      validator: (value) {
                        if (_isOtherDistrict && (value == null || value.isEmpty)) {
                          return 'Please specify a district name';
                        }
                        return null;
                      },
                    ),
                  ],
                  
                  const SizedBox(height: 16),
                  
                  // Village Dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedVillage,
                    decoration: InputDecoration(
                      labelText: 'Select Village/Area',
                      prefixIcon: const Icon(Icons.location_on, color: Color(0xFF003366)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF003366), width: 2),
                      ),
                    ),
                    items: _villages.map((String village) {
                      return DropdownMenuItem<String>(
                        value: village,
                        child: Text(village),
                      );
                    }).toList(),
                    onChanged: _villages.isEmpty 
                      ? null 
                      : (String? newValue) {
                          setState(() {
                            _selectedVillage = newValue;
                            _isOtherVillage = newValue == 'Other';
                          });
                        },
                    validator: (value) {
                      if (_selectedDistrict != null && (value == null || value.isEmpty)) {
                        return 'Please select a village/area';
                      }
                      return null;
                    },
                  ),
                  
                  // "Other" Village field (conditionally shown)
                  if (_isOtherVillage) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _otherVillageController,
                      decoration: InputDecoration(
                        labelText: 'Specify Village/Area',
                        hintText: 'Enter village or area name',
                        prefixIcon: const Icon(Icons.edit_location_alt, color: Color(0xFF003366)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF003366), width: 2),
                        ),
                      ),
                      validator: (value) {
                        if (_isOtherVillage && (value == null || value.isEmpty)) {
                          return 'Please specify a village or area name';
                        }
                        return null;
                      },
                    ),
                  ],
                  
                  const SizedBox(height: 16),
                  
                  // Email Field
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email Address',
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
                  
                  const SizedBox(height: 16),
                  
                  // Password Field
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          hintText: 'Create a password',
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
                        onChanged: (value) {
                          setState(() {});
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
                      if (_passwordController.text.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0, left: 12.0),
                          child: Row(
                            children: [
                              Text(
                                'Password Strength: ',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                _getPasswordStrength(_passwordController.text),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _getPasswordStrengthColor(
                                    _getPasswordStrength(_passwordController.text),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Confirm Password Field
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      hintText: 'Confirm your password',
                      prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF003366)),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
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
                        return 'Please confirm your password';
                      }
                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Terms and Conditions Checkbox
                  FormField<bool>(
                    initialValue: false,
                    validator: (value) {
                      if (value == false) {
                        return 'You must agree to the Terms and Conditions';
                      }
                      return null;
                    },
                    builder: (FormFieldState<bool> state) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Checkbox(
                                value: state.value,
                                onChanged: (value) {
                                  state.didChange(value);
                                },
                                activeColor: const Color(0xFF003366),
                              ),
                              Expanded(
                                child: Text(
                                  'I agree to the Terms and Conditions and Privacy Policy',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[800],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (state.hasError)
                            Padding(
                              padding: const EdgeInsets.only(left: 12.0),
                              child: Text(
                                state.errorText!,
                                style: TextStyle(
                                  color: Colors.red[700],
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Create Account Button
                  Center(
                    child: Container(
                      width: isSmallScreen ? screenSize.width * 0.7 : screenSize.width * 0.5,
                      height: isSmallScreen ? 46 : 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _signUp,
                        style: ButtonStyle(
                          backgroundColor: MaterialStateProperty.all(const Color(0xFF003366)),
                          shape: MaterialStateProperty.all(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          elevation: MaterialStateProperty.all(3),
                        ),
                        child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Create Account',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                      ),
                    ),
                  ),
                  
                  SizedBox(height: screenSize.height * 0.02),
                  
                  // Already have an account
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account?',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 15,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          // Navigate back to login
                          Navigator.pushReplacementNamed(context, 'Login');
                        },
                        child: const Text(
                          'Sign In',
                          style: TextStyle(
                            color: Color(0xFF003366),
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  // Notice
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Text(
                      'This is a secure government system. Unauthorized access is prohibited and subject to criminal prosecution.',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
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