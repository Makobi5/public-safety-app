// lib/services/auth_service.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  // Get Supabase instance
  static SupabaseClient get supabase => Supabase.instance.client;

  // Sign up with email and password - minimalist approach
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    required Map<String, dynamic> userData,
  }) async {
    try {
      // Only do the basic auth without any profile manipulation
      return await supabase.auth.signUp(
        email: email,
        password: password,
      );
    } catch (e) {
      print('Error in signUp: $e');
      rethrow;
    }
  }

  // Sign in with email and password
  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      print('Error in signIn: $e');
      rethrow;
    }
  }

  // Sign out
  static Future<void> signOut() async {
    try {
      await supabase.auth.signOut();
    } catch (e) {
      print('Error in signOut: $e');
      rethrow;
    }
  }

  // Reset password
  static Future<void> resetPassword(String email) async {
    try {
      await supabase.auth.resetPasswordForEmail(email);
    } catch (e) {
      print('Error in resetPassword: $e');
      rethrow;
    }
  }

  // Get current user
  static User? get currentUser => supabase.auth.currentUser;

  // Check if user is logged in
  static bool get isAuthenticated => currentUser != null;

  // Get user profile data
  static Future<Map<String, dynamic>?> getUserProfile() async {
    if (currentUser == null) return null;
    
    try {
      final response = await supabase
          .from('user_profiles')
          .select()
          .eq('id', currentUser!.id)
          .single();
      
      return response;
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }

  // Update user profile
  static Future<void> updateUserProfile(Map<String, dynamic> data) async {
    if (currentUser == null) return;
    
    try {
      await supabase
          .from('user_profiles')
          .update(data)
          .eq('id', currentUser!.id);
    } catch (e) {
      print('Error updating user profile: $e');
      rethrow;
    }
  }

  // Stream of auth changes
  static Stream<AuthState> get onAuthStateChange => 
      supabase.auth.onAuthStateChange;
}