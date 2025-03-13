// lib/screens/incident_report_form.dart

import 'package:flutter/material.dart';

class IncidentReportFormPage extends StatefulWidget {
  const IncidentReportFormPage({Key? key}) : super(key: key);

  static String routeName = 'IncidentReport';
  static String routePath = '/incident-report';

  @override
  State<IncidentReportFormPage> createState() => _IncidentReportFormPageState();
}

class _IncidentReportFormPageState extends State<IncidentReportFormPage> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedIncidentType;
  final _descriptionController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  int _currentStep = 0;

  @override
  void dispose() {
    _descriptionController.dispose();
    _additionalLocationController.dispose();
    _landmarkController.dispose();
    _witnessInfoController.dispose();
    _additionalNotesController.dispose();
    _otherRegionController.dispose();
    _otherDistrictController.dispose();
    _otherVillageController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF003366),
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF003366),
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _nextStep() {
    if (_currentStep < 2) {
      setState(() {
        _currentStep += 1;
      });
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep -= 1;
      });
    }
  }

  Widget _buildStepIndicator() {
    final screenSize = MediaQuery.of(context).size;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Text(
                'Step ${_currentStep + 1} of 3: ${_getStepTitle(_currentStep)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: screenSize.width * 0.9,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.3),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Container(
                width: screenSize.width * 0.9 * ((_currentStep + 1) / 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getStepTitle(int step) {
    switch (step) {
      case 0:
        return 'Incident Details';
      case 1:
        return 'Location Information';
      case 2:
        return 'Evidence & Submission';
      default:
        return '';
    }
  }
  
  // Helper method to get formatted location text for review
  String _getLocationText() {
    if (_selectedVillage == null) {
      return 'Not specified';
    }
    
    String locationText = '';
    
    // Add village/area
    if (_selectedVillage == 'Other' && _otherVillageController.text.isNotEmpty) {
      locationText = _otherVillageController.text;
    } else {
      locationText = _selectedVillage!;
    }
    
    // Add district
    if (_selectedDistrict != null) {
      String districtText = _selectedDistrict!;
      if (_selectedDistrict == 'Other' && _otherDistrictController.text.isNotEmpty) {
        districtText = _otherDistrictController.text;
      }
      locationText = '$locationText, $districtText';
    }
    
    // Add region
    if (_selectedRegion != null && _selectedRegion != 'Other') {
      locationText = '$locationText, $_selectedRegion';
    } else if (_selectedRegion == 'Other' && _otherRegionController.text.isNotEmpty) {
      locationText = '$locationText, ${_otherRegionController.text}';
    }
    
    // Add landmark reference if provided
    if (_landmarkController.text.isNotEmpty) {
      locationText = '$locationText (Near ${_landmarkController.text})';
    }
    
    return locationText;
  }
  
  // Store selected values for review
  String? _selectedDistrict;
  String? _selectedRegion;
  String? _selectedVillage;
  final _additionalLocationController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _otherRegionController = TextEditingController();
  final _otherDistrictController = TextEditingController();
  final _otherVillageController = TextEditingController();
  bool _isOtherRegion = false;
  bool _isOtherDistrict = false;
  bool _isOtherVillage = false;
  
  // Evidence and submission data
  List<String> _uploadedFiles = [];
  final _witnessInfoController = TextEditingController();
  final _additionalNotesController = TextEditingController();
  
  // List of Ugandan regions (copied from signup form)
  final List<String> _ugandanRegions = [
    'Central Region',
    'Eastern Region',
    'Northern Region',
    'Western Region',
    'Other',
  ];

  // Map of regions to districts in Uganda (copied from signup form)
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
  
  // Lists for dropdowns
  List<String> _districts = [];
  List<String> _villages = [];

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Submit Safety Report',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF003366),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_currentStep > 0) {
              _previousStep();
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: _buildStepIndicator(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_currentStep == 0) ...[
                        // Incident Details Step
                        const Text(
                          'Incident Type',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                contentPadding: EdgeInsets.symmetric(horizontal: 16),
                                border: InputBorder.none,
                              ),
                              hint: const Text('Select incident type'),
                              value: _selectedIncidentType,
                              onChanged: (value) {
                                setState(() {
                                  _selectedIncidentType = value;
                                });
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select an incident type';
                                }
                                return null;
                              },
                              items: [
                                'Suspicious Activity',
                                'Theft',
                                'Vandalism',
                                'Noise Complaint',
                                'Traffic Issue',
                                'Environmental Hazard',
                                'Other'
                              ].map<DropdownMenuItem<String>>((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        const Text(
                          'Description',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _descriptionController,
                          decoration: InputDecoration(
                            hintText: 'Provide detailed description of the incident',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.all(16),
                          ),
                          maxLines: 4,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a description';
                            }
                            return null;
                          },
                        ),
                        
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Date',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  InkWell(
                                    onTap: () => _selectDate(context),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey.shade300),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.calendar_today, size: 18),
                                          const SizedBox(width: 8),
                                          Text(
                                            _selectedDate == null 
                                                ? 'Select date' 
                                                : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                                            style: TextStyle(
                                              color: _selectedDate == null ? Colors.grey.shade600 : Colors.black,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Time',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  InkWell(
                                    onTap: () => _selectTime(context),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey.shade300),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.access_time, size: 18),
                                          const SizedBox(width: 8),
                                          Text(
                                            _selectedTime == null 
                                                ? 'Select time' 
                                                : _selectedTime!.format(context),
                                            style: TextStyle(
                                              color: _selectedTime == null ? Colors.grey.shade600 : Colors.black,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                      
                      if (_currentStep == 1) ...[
                        // Region Dropdown
                        const Text(
                          'Region*',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.orange.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButtonFormField<String>(
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                                border: InputBorder.none,
                                filled: true,
                                fillColor: Colors.orange.shade50,
                              ),
                              hint: const Text('Select region'),
                              value: _selectedRegion,
                              onChanged: (value) {
                                setState(() {
                                  _selectedRegion = value;
                                  _selectedDistrict = null;
                                  _selectedVillage = null;
                                  _isOtherRegion = value == 'Other';
                                  
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
                              items: _ugandanRegions.map<DropdownMenuItem<String>>((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        
                        // Other Region Field (conditionally shown)
                        if (_isOtherRegion) ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _otherRegionController,
                            decoration: InputDecoration(
                              labelText: 'Specify Region*',
                              hintText: 'Enter region name',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.all(16),
                            ),
                            validator: (value) {
                              if (_isOtherRegion && (value == null || value.isEmpty)) {
                                return 'Please specify a region name';
                              }
                              return null;
                            },
                          ),
                        ],
                        
                        const SizedBox(height: 20),
                        
                        // District Dropdown
                        const Text(
                          'District*',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.grey.shade100,
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                contentPadding: EdgeInsets.symmetric(horizontal: 16),
                                border: InputBorder.none,
                              ),
                              hint: const Text('Select district'),
                              value: _selectedDistrict,
                              onChanged: _districts.isEmpty 
                                ? null 
                                : (value) {
                                    setState(() {
                                      _selectedDistrict = value;
                                      _selectedVillage = null;
                                      _isOtherDistrict = value == 'Other';
                                      
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
                                if (_selectedRegion != null && (value == null || value.isEmpty)) {
                                  return 'Please select a district';
                                }
                                return null;
                              },
                              items: _districts.map<DropdownMenuItem<String>>((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        
                        // Other District Field (conditionally shown)
                        if (_isOtherDistrict) ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _otherDistrictController,
                            decoration: InputDecoration(
                              labelText: 'Specify District*',
                              hintText: 'Enter district name',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.all(16),
                            ),
                            validator: (value) {
                              if (_isOtherDistrict && (value == null || value.isEmpty)) {
                                return 'Please specify a district name';
                              }
                              return null;
                            },
                          ),
                        ],

                        const SizedBox(height: 20),
                        
                        // Village Dropdown
                        const Text(
                          'Village/Area*',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.grey.shade100,
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                contentPadding: EdgeInsets.symmetric(horizontal: 16),
                                border: InputBorder.none,
                              ),
                              hint: const Text('Select village/area'),
                              value: _selectedVillage,
                              onChanged: _villages.isEmpty 
                                ? null 
                                : (value) {
                                    setState(() {
                                      _selectedVillage = value;
                                      _isOtherVillage = value == 'Other';
                                    });
                                  },
                              validator: (value) {
                                if (_selectedDistrict != null && (value == null || value.isEmpty)) {
                                  return 'Please select a village/area';
                                }
                                return null;
                              },
                              items: _villages.map<DropdownMenuItem<String>>((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        
                        // Other Village Field (conditionally shown)
                        if (_isOtherVillage) ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _otherVillageController,
                            decoration: InputDecoration(
                              labelText: 'Specify Village/Area*',
                              hintText: 'Enter village or area name',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.all(16),
                            ),
                            validator: (value) {
                              if (_isOtherVillage && (value == null || value.isEmpty)) {
                                return 'Please specify a village or area name';
                              }
                              return null;
                            },
                          ),
                        ],

                        const SizedBox(height: 20),
                        const Text(
                          'Additional Location Details',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _additionalLocationController,
                          decoration: InputDecoration(
                            hintText: 'Provide any additional details about the location',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.all(16),
                          ),
                          maxLines: 3,
                        ),

                        const SizedBox(height: 20),
                        const Text(
                          'Landmark Reference (Optional)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _landmarkController,
                          decoration: InputDecoration(
                            hintText: 'e.g., Near Kabale University',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.all(16),
                          ),
                        ),
                      ],
                      
                      if (_currentStep == 2) ...[
                        // Evidence & Submission Step
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Text(
                                    'Upload Evidence',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  InkWell(
                                    onTap: () {
                                      // Handle file upload
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('File upload functionality will be implemented')),
                                      );
                                    },
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(24),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey.shade300),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF003366),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.cloud_upload,
                                              color: Colors.white,
                                              size: 32,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          const Text(
                                            'Tap to upload photos or videos',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Maximum 5 files, 10MB each',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  
                                  if (_uploadedFiles.isNotEmpty) ...[
                                    const SizedBox(height: 16),
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: List.generate(
                                          _uploadedFiles.length,
                                          (index) => Container(
                                            margin: const EdgeInsets.only(right: 8),
                                            height: 70,
                                            width: 70,
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade300,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                const Icon(Icons.image, size: 32, color: Colors.grey),
                                                Positioned(
                                                  top: 4,
                                                  right: 4,
                                                  child: InkWell(
                                                    onTap: () {
                                                      setState(() {
                                                        _uploadedFiles.removeAt(index);
                                                      });
                                                    },
                                                    child: Container(
                                                      padding: const EdgeInsets.all(2),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white.withOpacity(0.8),
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: const Icon(Icons.close, size: 16, color: Colors.grey),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 20),
                            
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Additional Information',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Witness Information (Optional)',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _witnessInfoController,
                                    decoration: InputDecoration(
                                      hintText: 'Enter contact details of any witnesses',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      contentPadding: const EdgeInsets.all(12),
                                    ),
                                  ),
                                  
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Additional Notes',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _additionalNotesController,
                                    decoration: InputDecoration(
                                      hintText: 'Any other relevant information about the incident',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      contentPadding: const EdgeInsets.all(12),
                                    ),
                                    maxLines: 3,
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 20),
                            
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Review Your Report',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          'Incident Type:',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          _selectedIncidentType ?? 'Not specified',
                                          style: const TextStyle(
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          'Location:',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          _getLocationText(),
                                          style: const TextStyle(
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          'Date & Time:',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          _selectedDate != null && _selectedTime != null
                                              ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year} ${_selectedTime!.format(context)}'
                                              : 'Not specified',
                                          style: const TextStyle(
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 20),
                            
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      // Save as draft functionality
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Report saved as draft')),
                                      );
                                    },
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      side: const BorderSide(color: Colors.grey),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text(
                                      'Save as Draft',
                                      style: TextStyle(
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                      
                      const SizedBox(height: 24),
                      if (_currentStep < 2)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              onPressed: _currentStep == 0 
                                  ? () => Navigator.of(context).pop() 
                                  : _previousStep,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  side: const BorderSide(color: Color(0xFF003366)),
                                ),
                              ),
                              child: Text(
                                _currentStep == 0 ? 'Cancel' : 'Back',
                                style: const TextStyle(
                                  color: Color(0xFF003366),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                // For the purpose of this demo, we'll just advance without validation
                                _nextStep();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF003366),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: const Text(
                                'Next',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      
                      if (_currentStep == 2)
                        Column(
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                // Submit form
                                if (_formKey.currentState!.validate()) {
                                  // Process form submission
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Report submitted successfully')),
                                  );
                                  Navigator.pop(context);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF003366),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                minimumSize: const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Submit Report',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: _previousStep,
                              child: const Text(
                                'Back',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
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
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        color: Colors.white,
        width: double.infinity,
        child: const Text(
          'All information submitted will be handled confidentially in accordance with privacy regulations.',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}