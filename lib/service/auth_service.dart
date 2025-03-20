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
    
    // Add default role as 'user' for all regular sign-ups
    userData['role'] = 'user';
    
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
        'role': userData['role'] ?? 'user', // Include role in profile
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
                'role': userData['role'] ?? 'user', // Include role parameter
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
  
  // New method: Sign in as Admin
// Updated signInAsAdmin method
static Future<AuthResponse> signInAsAdmin({
  required String email,
  required String password,
}) async {
  // First authenticate the user
  final response = await supabase.auth.signInWithPassword(
    email: email,
    password: password,
  );
  
  // Then verify if the user is in the admins table
  if (response.user != null) {
    try {
      // Use an RPC function instead of direct table access to avoid RLS issues
      final isAdmin = await supabase.rpc(
        'is_user_admin',
        params: {'user_uuid': response.user!.id}
      );
      
      if (isAdmin != true) {
        await supabase.auth.signOut();
        throw const AuthException(
          'Not authorized: Admin credentials required.',
        );
      }
    } catch (e) {
      print("Error checking admin status: $e");
      
      // If the RPC function doesn't exist or fails, try a direct check with error handling
      try {
        final adminCount = await supabase.from('admins')
          .select('*')
          .eq('user_id', response.user!.id);
        
        if (adminCount.count == 0) {
          await supabase.auth.signOut();
          throw const AuthException(
            'Not authorized: Admin credentials required.',
          );
        }
      } catch (innerE) {
        // If even the direct check fails, sign out and throw exception
        await supabase.auth.signOut();
        throw const AuthException(
          'Error verifying admin credentials. Please try again.',
        );
      }
    }
  }
  
  return response;
}
  
  // New method: Create Admin Account (can only be used by existing admins)
  static Future<AuthResponse> createAdminAccount({
    required String email,
    required String password,
    required Map<String, dynamic> userData,
  }) async {
    // Verify that the current user is an admin
    if (!await isUserAdmin()) {
      throw const AuthException(
        'Not authorized: Only existing admins can create admin accounts.',
      );
    }
    
    try {
      // Check if user already exists
      final existingUser = await supabase.auth.admin
        .getUserByEmail(email);
        
      String userId;
      
      if (existingUser != null) {
        // User already exists
        userId = existingUser.id;
        print("User already exists with ID: $userId");
      } else {
        // Create a new user
        final signUpResponse = await supabase.auth.signUp(
          email: email,
          password: password,
          data: userData,
        );
        
        if (signUpResponse.user == null) {
          throw Exception("Failed to create user account");
        }
        
        userId = signUpResponse.user!.id;
        print("Created new user with ID: $userId");
        
        // Create user profile
        await _createUserProfile(userId, userData);
      }
      
      // Check if already an admin
      final existingAdmin = await supabase
        .from('admins')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
        
      if (existingAdmin != null) {
        print("User is already an admin");
        if (existingUser != null) {
          // Return the response for existing user
          return AuthResponse(
            user: existingUser,
            session: null,
          );
        }
      } else {
        // Add user to admins table
        await supabase.from('admins').insert({
          'user_id': userId,
          'role': 'admin',
        });
        
        print("Added user to admins table");
      }
      
      // Return the appropriate response
      if (existingUser != null) {
        return AuthResponse(
          user: existingUser,
          session: null,
        );
      } else {
        return AuthResponse(
          user: supabase.auth.currentUser,
          session: supabase.auth.currentSession,
        );
      }
    } catch (e) {
      print("Error in createAdminAccount: $e");
      rethrow;
    }
  }
  
  // Method to add an existing user as admin
  static Future<void> addExistingUserAsAdmin(String userId) async {
    
    // Verify current user is an admin
    if (!await isUserAdmin()) {
      throw const AuthException('Not authorized');
    }
    
    try {
      // Check if user exists
      final userExists = await supabase
        .from('user_profiles')
        .select('user_id')
        .eq('user_id', userId)
        .maybeSingle();
        
      if (userExists == null) {
        throw Exception("User not found");
      }
      
      // Check if already an admin
      final isAlreadyAdmin = await supabase
        .from('admins')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
        
      if (isAlreadyAdmin != null) {
        throw Exception("User is already an admin");
      }
      
      // Add to admins table
      await supabase
        .from('admins')
        .insert({
          'user_id': userId,
          'role': 'admin',
        });
    } catch (e) {
      print("Error adding existing user as admin: $e");
      rethrow;
    }
  }
  
  // New method: Check if current user is an admin
static Future<bool> isUserAdmin() async {
  if (currentUser == null) return false;
  
  try {
    // Use the RPC function we created to check admin status
    final isAdmin = await supabase.rpc(
      'is_user_admin',
      params: {'user_uuid': currentUser!.id}
    );
    
    return isAdmin == true;
  } catch (e) {
    print("Error in RPC call: $e");
    
    // Fallback to direct check
    try {
      final adminRecord = await supabase
        .from('admins')
        .select()
        .eq('user_id', currentUser!.id)
        .single();
      
      return adminRecord != null;
    } catch (fallbackError) {
      print("Error checking admin status: $fallbackError");
      return false;
    }
  }
}
  
  // Get all regular users (for admin to select from)
  static Future<List<Map<String, dynamic>>> getAllRegularUsers() async {
    if (!await isUserAdmin()) {
      throw const AuthException(
        'Not authorized: Only admins can view all users.',
      );
    }
    
    try {
      // Get all user profiles
      final allUsers = await supabase
        .from('user_profiles')
        .select('*');
      
      // Get all admin user_ids
      final adminUsers = await supabase
        .from('admins')
        .select('user_id');
      
      // Create a set of admin user_ids for faster lookup
      final adminUserIds = Set<String>.from(
        adminUsers.map((admin) => admin['user_id'] as String)
      );
      
      // Filter out users who are already admins
      return allUsers
        .where((user) => !adminUserIds.contains(user['user_id']))
        .toList();
    } catch (e) {
      print("Error fetching regular users: $e");
      return [];
    }
  }
  
  // Remove admin privileges
  static Future<void> removeAdminPrivileges(String userId) async {
    // Verify current user is an admin
    if (!await isUserAdmin()) {
      throw const AuthException(
        'Not authorized: Only admins can remove admin privileges.',
      );
    }
    
    // Prevent removing yourself
    if (userId == currentUser!.id) {
      throw Exception("You cannot remove your own admin privileges");
    }
    
    try {
      await supabase
        .from('admins')
        .delete()
        .eq('user_id', userId);
        
      print("Admin privileges removed for user $userId");
    } catch (e) {
      print("Error removing admin privileges: $e");
      rethrow;
    }
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
      
        static get count => null;
}

extension on PostgrestList {
  get count => null;
}

extension on GoTrueAdminApi {
  getUserByEmail(String email) {}
}