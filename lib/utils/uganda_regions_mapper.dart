class UgandaRegionsMapper {
  // Map of districts to their regions
  static final Map<String, String> districtToRegionMap = {
    // Central Region
    'Buikwe': 'Central Region',
    'Bukomansimbi': 'Central Region',
    'Butambala': 'Central Region',
    'Buvuma': 'Central Region',
    'Gomba': 'Central Region',
    'Kalangala': 'Central Region',
    'Kalungu': 'Central Region',
    'Kampala': 'Central Region',
    'Kayunga': 'Central Region',
    'Kiboga': 'Central Region',
    'Kyankwanzi': 'Central Region',
    'Luweero': 'Central Region',
    'Lwengo': 'Central Region',
    'Lyantonde': 'Central Region',
    'Masaka': 'Central Region',
    'Mityana': 'Central Region',
    'Mpigi': 'Central Region',
    'Mubende': 'Central Region',
    'Mukono': 'Central Region',
    'Nakaseke': 'Central Region',
    'Nakasongola': 'Central Region',
    'Rakai': 'Central Region',
    'Sembabule': 'Central Region',
    'Wakiso': 'Central Region',

    // Eastern Region
    'Amuria': 'Eastern Region',
    'Budaka': 'Eastern Region',
    'Bududa': 'Eastern Region',
    'Bugiri': 'Eastern Region',
    'Bukedea': 'Eastern Region',
    'Bukwa': 'Eastern Region',
    'Bulambuli': 'Eastern Region',
    'Busia': 'Eastern Region',
    'Butaleja': 'Eastern Region',
    'Buyende': 'Eastern Region',
    'Iganga': 'Eastern Region',
    'Jinja': 'Eastern Region',
    'Kaberamaido': 'Eastern Region',
    'Kaliro': 'Eastern Region',
    'Kamuli': 'Eastern Region',
    'Kapchorwa': 'Eastern Region',
    'Katakwi': 'Eastern Region',
    'Kibuku': 'Eastern Region',
    'Kumi': 'Eastern Region',
    'Kween': 'Eastern Region',
    'Luuka': 'Eastern Region',
    'Manafwa': 'Eastern Region',
    'Mayuge': 'Eastern Region',
    'Mbale': 'Eastern Region',
    'Namayingo': 'Eastern Region',
    'Namutumba': 'Eastern Region',
    'Ngora': 'Eastern Region',
    'Pallisa': 'Eastern Region',
    'Serere': 'Eastern Region',
    'Sironko': 'Eastern Region',
    'Soroti': 'Eastern Region',
    'Tororo': 'Eastern Region',

    // Northern Region
    'Abim': 'Northern Region',
    'Adjumani': 'Northern Region',
    'Agago': 'Northern Region',
    'Alebtong': 'Northern Region',
    'Amolatar': 'Northern Region',
    'Amudat': 'Northern Region',
    'Amuru': 'Northern Region',
    'Apac': 'Northern Region',
    'Arua': 'Northern Region',
    'Dokolo': 'Northern Region',
    'Gulu': 'Northern Region',
    'Kaabong': 'Northern Region',
    'Kitgum': 'Northern Region',
    'Koboko': 'Northern Region',
    'Kole': 'Northern Region',
    'Kotido': 'Northern Region',
    'Lamwo': 'Northern Region',
    'Lira': 'Northern Region',
    'Maracha': 'Northern Region',
    'Moroto': 'Northern Region',
    'Moyo': 'Northern Region',
    'Nakapiripirit': 'Northern Region',
    'Napak': 'Northern Region',
    'Nebbi': 'Northern Region',
    'Nwoya': 'Northern Region',
    'Otuke': 'Northern Region',
    'Oyam': 'Northern Region',
    'Pader': 'Northern Region',
    'Yumbe': 'Northern Region',
    'Zombo': 'Northern Region',

    // Western Region
    'Buhweju': 'Western Region',
    'Buliisa': 'Western Region',
    'Bundibugyo': 'Western Region',
    'Bushenyi': 'Western Region',
    'Hoima': 'Western Region',
    'Ibanda': 'Western Region',
    'Isingiro': 'Western Region',
    'Kabale': 'Western Region',
    'Kabarole': 'Western Region',
    'Kamwenge': 'Western Region',
    'Kanungu': 'Western Region',
    'Kasese': 'Western Region',
    'Kibaale': 'Western Region',
    'Kiruhura': 'Western Region',
    'Kiryandongo': 'Western Region',
    'Kisoro': 'Western Region',
    'Kyegegwa': 'Western Region',
    'Kyenjojo': 'Western Region',
    'Masindi': 'Western Region',
    'Mbarara': 'Western Region',
    'Mitooma': 'Western Region',
    'Ntoroko': 'Western Region',
    'Ntungamo': 'Western Region',
    'Rubirizi': 'Western Region',
    'Rukungiri': 'Western Region',
    'Sheema': 'Western Region',
  };

  // Precise coordinate ranges for key districts
  static final Map<String, Map<String, List<double>>> districtCoordinates = {
    'Kabale': {
      'latitude': [-1.35, -1.0],  // More precise Kabale bounds
      'longitude': [29.9, 30.3]
    },
    'Kampala': {
      'latitude': [0.25, 0.4],
      'longitude': [32.5, 32.7]
    },
    // Add more districts as needed
  };

  // Method to get region from coordinates
  static String getRegionForCoordinates(double latitude, double longitude) {
    // First check if coordinates are within Uganda
    if (!_isCoordinateInUganda(latitude, longitude)) {
      return 'Unknown Region';
    }

    // Check specific districts first
    for (var entry in districtCoordinates.entries) {
      final district = entry.key;
      final coords = entry.value;
      if (_isInCoordinateRange(latitude, longitude, coords)) {
        return districtToRegionMap[district] ?? 'Unknown Region';
      }
    }

    // General region detection
    // Western Region (including Kabale)
    if (latitude >= -1.5 && latitude <= 0.5 && longitude >= 29.5 && longitude <= 31.5) {
      return 'Western Region';
    }
    // Central Region
    else if (latitude >= 0.0 && latitude <= 1.5 && longitude >= 31.5 && longitude <= 33.0) {
      return 'Central Region';
    }
    // Eastern Region
    else if (latitude >= 0.5 && latitude <= 2.5 && longitude >= 33.0 && longitude <= 34.5) {
      return 'Eastern Region';
    }
    // Northern Region
    else if (latitude >= 2.0 && latitude <= 4.0 && longitude >= 31.5 && longitude <= 35.0) {
      return 'Northern Region';
    }

    return 'Unknown Region';
  }

  // Method to get district from coordinates
static String getDistrictForCoordinates(double latitude, double longitude) {
  // Precise Kabale district boundaries
  if (latitude >= -1.35 && latitude <= -1.0 && 
      longitude >= 29.9 && longitude <= 30.3) {
    return 'Kabale';
  }
  // Kampala district
  else if (latitude >= 0.25 && latitude <= 0.4 && 
           longitude >= 32.5 && longitude <= 32.7) {
    return 'Kampala';
  }
  
  return 'Unknown District';
}

  // Helper method to check coordinate ranges
  static bool _isInCoordinateRange(double lat, double lon, Map<String, List<double>> coords) {
    return lat >= coords['latitude']![0] && 
           lat <= coords['latitude']![1] && 
           lon >= coords['longitude']![0] && 
           lon <= coords['longitude']![1];
  }

  // Helper method to check if coordinates are in Uganda
  static bool _isCoordinateInUganda(double lat, double lon) {
    const double minLat = -1.5;
    const double maxLat = 4.3;
    const double minLon = 29.5;
    const double maxLon = 35.0;
    return lat >= minLat && lat <= maxLat && lon >= minLon && lon <= maxLon;
  }

  // Method to get region from district
  static String getRegionForDistrict(String district) {
    if (district == null || district.isEmpty) {
      return 'Unknown Region';
    }
    
    final standardizedDistrict = district.trim();
    final region = districtToRegionMap[standardizedDistrict];
    return region ?? 'Unknown Region';
  }

  // Get all districts in a specific region
  static List<String> getDistrictsInRegion(String region) {
    if (region == null || region.isEmpty) {
      return [];
    }
    
    return districtToRegionMap.entries
        .where((entry) => entry.value == region)
        .map((entry) => entry.key)
        .toList();
  }

  // Get all regions
  static List<String> getAllRegions() {
    return [
      'Central Region',
      'Eastern Region',
      'Northern Region',
      'Western Region'
    ];
  }

  // Village to district mapping
  static final Map<String, String> villageToDistrictMap = {
    'Ndorwa': 'Kabale',
    'Hamurwa': 'Kabale',
    'Kabale Town': 'Kabale',
    // Add other village-to-district mappings as needed
  };

  // Method to get district from village
  static String getDistrictForVillage(String village) {
    if (village == null || village.isEmpty) {
      return 'Unknown District';
    }
    
    final standardizedVillage = village.trim();
    final district = villageToDistrictMap[standardizedVillage];
    return district ?? 'Unknown District';
  }
}