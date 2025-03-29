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
    'Kabale': 'Western Region',  // Note: Kabale is in Western Region
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
    
    // Additional newer districts
    // 'Nabilatuk': 'Northern Region',
    // 'Bugweri': 'Eastern Region',
    // 'Kassanda': 'Central Region',
    // 'Kwania': 'Northern Region',
    // 'Kapelebyong': 'Eastern Region',
    // 'Kikuube': 'Western Region',
    // 'Obongi': 'Northern Region',
    // 'Kazo': 'Western Region',
    // 'Rwampara': 'Western Region',
    // 'Kitagwenda': 'Western Region',
    // 'Madi-Okollo': 'Northern Region',
    // 'Karenga': 'Northern Region',
    // 'Kalaki': 'Eastern Region',
    // 'Terego': 'Northern Region',
    // 'Bukimbiri': 'Western Region',
    // 'Ndorwa': 'Western Region',    // Sub-county in Kabale
    // 'Hamurwa': 'Western Region',   // Sub-county in Kabale
  };

  // Method to get region from district
  static String getRegionForDistrict(String district) {
    if (district == null || district.isEmpty) {
      return 'Unknown Region';
    }
    
    // Standardize the district name for lookup
    final standardizedDistrict = district.trim();
    
    // Look up the region in our map
    final region = districtToRegionMap[standardizedDistrict];
    
    // Return the found region or default to "Unknown Region"
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
// Add this to your UgandaRegionsMapper class
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
  
  // Standardize the village name for lookup
  final standardizedVillage = village.trim();
  
  // Look up the district in our map
  final district = villageToDistrictMap[standardizedVillage];
  
  // Return the found district or default to "Unknown District"
  return district ?? 'Unknown District';
}

}