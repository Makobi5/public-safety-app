// lib/service/auth_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static final supabase = Supabase.instance.client;
  
  // Sign Up method
  static Future<AuthResponse> signUp({
    required String email, 
    required String password,
    required Map<String, dynamic> userData,
  }) async {
    print("Starting sign up process for email: $email");
    print("User data received: $userData");
    
    // 1. Create the user in Supabase Auth
    final response = await supabase.auth.signUp(
      email: email,
      password: password,
    );
    
    // Check if there was an error
    // Check if there was an error
// Check if there was an error
//if (response.error != null) {
  //print("Auth error during signup: ${response.error!}"); // Just print the whole error object
  //throw response.error!;
//}
    
    // 2. Create user profile in user_profiles table
    if (response.user != null) {
      try {
        print("User created successfully with ID: ${response.user!.id}");
        
        final profileData = {
          'user_id': response.user!.id,
          'first_name': userData['first_name'],
          'last_name': userData['last_name'],
          'region': userData['region'],
          'district': userData['district'],
          'village': userData['village'],
        };
        
        print("Inserting profile data: $profileData");
        
        final profileResponse = await supabase.from('user_profiles').insert(profileData);
        
        print("Profile creation response: $profileResponse");
        print("Profile created successfully for user: ${response.user!.id}");
      } catch (e) {
        print("Error creating user profile: $e");
      }
    }
    
    return response;
  }
  
  // Sign In method
  static Future<AuthResponse> signIn({
    required String email, 
    required String password,
  }) async {
    return await supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }
  
  // Sign Out method
  static Future<void> signOut() async {
    await supabase.auth.signOut();
  }
  
  // Get current user
  static User? get currentUser => supabase.auth.currentUser;
  
  // Get user profile data
  static Future<Map<String, dynamic>?> getUserProfile() async {
    if (currentUser == null) return null;
    
    try {
      print("Fetching profile for user: ${currentUser!.id}");
      
      final response = await supabase
        .from('user_profiles')
        .select()
        .eq('user_id', currentUser!.id)
        .single();
      
      print("Profile data fetched: $response");
      return response;
    } catch (e) {
      print('Error fetching user profile: $e');
      return null;
    }
  }
  
  // Update user profile
  static Future<void> updateUserProfile(Map<String, dynamic> data) async {
    if (currentUser == null) throw Exception('User not authenticated');
    
    await supabase
      .from('user_profiles')
      .update(data)
      .eq('user_id', currentUser!.id);
  }
  
  // Reset password
  static Future<void> resetPassword(String email) async {
    await supabase.auth.resetPasswordForEmail(email);
  }
  
  // Update password
  static Future<void> updatePassword(String newPassword) async {
    await supabase.auth.updateUser(
      UserAttributes(
        password: newPassword,
      ),
    );
  }
  
  // Check if user is authenticated
  static bool get isAuthenticated => currentUser != null;
  
  // Get auth state changes stream
  static Stream<AuthState> get onAuthStateChange => 
      supabase.auth.onAuthStateChange;
}