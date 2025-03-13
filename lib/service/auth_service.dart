// lib/service/auth_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static final supabase = Supabase.instance.client;
  
  // Sign Up method with RLS handling
  static Future<AuthResponse> signUp({
    required String email, 
    required String password,
    required Map<String, dynamic> userData,
  }) async {
    print("Starting sign up process for email: $email");
    print("User data received: $userData");
    
    try {
      // 1. Create the user in Supabase Auth
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
        // Important: Add user metadata during signup
        data: userData, 
      );
      
      print("Auth response received");
      
      // Check if user was created successfully
      if (response.user == null) {
        print("Auth error: No user was created");
        throw Exception("Failed to create user account");
      }
      
      print("User created successfully with ID: ${response.user!.id}");
      
      // Need to sign in once to get proper access token for RLS policies
      try {
        await supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );
        
        // Wait briefly for auth to complete
        await Future.delayed(Duration(milliseconds: 500));
        
        // Now create user profile with proper authentication
        await _createUserProfile(response.user!.id, userData);
        
        // Sign out as the registration flow should continue to login page
        await supabase.auth.signOut();
        
      } catch (e) {
        print("Error during profile creation login: $e");
        // Continue with the flow, as the user was created successfully
      }
      
      return response;
    } catch (e) {
      print("Uncaught error in signUp method: $e");
      rethrow; // Make sure to rethrow so the UI can handle it
    }
  }
  
  // Helper method to create user profile
  static Future<void> _createUserProfile(String userId, Map<String, dynamic> userData) async {
    try {
      print("Creating profile for user: $userId");
      
      // First check if a profile already exists
      final existingProfile = await supabase
        .from('user_profiles')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
        
      if (existingProfile != null) {
        print("Profile already exists: $existingProfile");
        return;
      }
      
      // Try to insert the profile with explicit authorization header
      final profileData = {
        'user_id': userId,
        'first_name': userData['first_name'] ?? '',
        'last_name': userData['last_name'] ?? '',
        'region': userData['region'] ?? '',
        'district': userData['district'] ?? '',
        'village': userData['village'] ?? '',
      };
      
      print("Inserting profile with data: $profileData");
      
      final result = await supabase
        .from('user_profiles')
        .insert(profileData)
        .select();
        
      print("Insert result: $result");
    } catch (e) {
      print("Error creating profile: $e");
      if (e is PostgrestException) {
        print("PostgrestError details: ${e.toString()}");
        
        // Check for RLS policy violation
        if (e.toString().contains("new row violates row-level security policy")) {
          print("RLS policy violation detected. Attempting RPC function call...");
          
          try {
            // Try to call a server-side function that can bypass RLS
            final result = await supabase.rpc(
              'create_user_profile',
              params: {
                'user_id': userId,
                'first_name': userData['first_name'] ?? '',
                'last_name': userData['last_name'] ?? '',
                'region': userData['region'] ?? '',
                'district': userData['district'] ?? '',
                'village': userData['village'] ?? '',
              },
            );
            print("RPC function call result: $result");
          } catch (rpcError) {
            print("RPC function error: $rpcError");
          }
        }
      }
    }
  }
  
  // Sign In method
  static Future<AuthResponse> signIn({
    required String email, 
    required String password,
  }) async {
    final response = await supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
    
    // After successful login, check if profile exists and create it if missing
    if (response.user != null) {
      try {
        final profile = await getUserProfile();
        
        // If profile is missing but we have user metadata, create profile
        if (profile == null && response.user!.userMetadata != null) {
          await _createUserProfile(
            response.user!.id, 
            response.user!.userMetadata as Map<String, dynamic>
          );
        }
      } catch (e) {
        print("Error checking/creating profile after login: $e");
      }
    }
    
    return response;
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
        .select('*')
        .eq('user_id', currentUser!.id)
        .maybeSingle();
      
      print("Profile data fetched: $response");
      return response;
    } catch (e) {
      print('Error fetching user profile: $e');
      
      // Try alternative approach
      try {
        print("Trying alternative approach to fetch profile");
        final List<dynamic> response = await supabase
          .from('user_profiles')
          .select('*')
          .eq('user_id', currentUser!.id);
          
        if (response.isNotEmpty) {
          print("Found profile using alternative approach: ${response.first}");
          return response.first;
        } else {
          print("No profile found with alternative approach");
          return null;
        }
      } catch (altError) {
        print("Alternative fetch approach also failed: $altError");
        return null;
      }
    }
  }
  
  // Update user profile
  static Future<void> updateUserProfile(Map<String, dynamic> data) async {
    if (currentUser == null) throw Exception('User not authenticated');
    
    try {
      await supabase
        .from('user_profiles')
        .update(data)
        .eq('user_id', currentUser!.id);
      
      print("Profile updated successfully");
    } catch (e) {
      print("Error updating profile: $e");
      rethrow;
    }
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