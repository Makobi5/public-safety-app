// lib/screens/user_management_screen.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../service/auth_service.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({Key? key}) : super(key: key);

  static String routeName = 'UserManagement';
  static String routePath = '/user-management';

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _searchController = TextEditingController();
  
  late TabController _tabController;
  
  bool _isLoading = false;
  bool _isUserListLoading = false;
  String? _successMessage;
  String? _errorMessage;
  
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchUsers();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _searchController.dispose();
    super.dispose();
  }
  
  // Fetch all users from database
 // Modify the _fetchUsers method in _UserManagementScreenState class
Future<void> _fetchUsers() async {
  setState(() {
    _isUserListLoading = true;
  });
  
  try {
    final supabase = Supabase.instance.client;
    
    // Use the RPC function we created in the database
    final response = await supabase.rpc('get_users_with_profiles');
    
    if (response != null && response is List) {
      print('Response data sample:');
      if (response.isNotEmpty) {
        print(response[0]);  // Print first user to see the structure
      }
      
      setState(() {
        _users = response.cast<Map<String, dynamic>>();
        _filteredUsers = List.from(_users);
        _debugRoles();  // Call our debug function
      });
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error fetching users: $e'),
        backgroundColor: Colors.red,
      ),
    );
  } finally {
    setState(() {
      _isUserListLoading = false;
    });
  }
}
  
  // Add new admin
  Future<void> _addAdmin() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      // Create a new admin user
      final userData = {
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'role': 'admin', // Set role as admin
      };
      
      // Call a special method to create admin account
      await AuthService.createAdminAccount(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        userData: userData,
      );
      
      setState(() {
        _successMessage = 'Admin account created successfully!';
        // Clear form fields
        _emailController.clear();
        _passwordController.clear();
        _firstNameController.clear();
        _lastNameController.clear();
      });
      
      // Refresh user list
      _fetchUsers();
      
    } catch (e) {
      setState(() {
        _errorMessage = 'Error creating admin account: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Search/filter users
  void _filterUsers(String searchText) {
    setState(() {
      if (searchText.isEmpty) {
        _filteredUsers = List.from(_users);
      } else {
        final query = searchText.toLowerCase();
        _filteredUsers = _users.where((user) {
          final firstName = user['first_name']?.toString().toLowerCase() ?? '';
          final lastName = user['last_name']?.toString().toLowerCase() ?? '';
          final email = user['users']?['email']?.toString().toLowerCase() ?? '';
          final role = user['role']?.toString().toLowerCase() ?? '';
          
          return firstName.contains(query) || 
                 lastName.contains(query) || 
                 email.contains(query) ||
                 role.contains(query);
        }).toList();
      }
    });
  }
  
  // Delete user
  Future<void> _confirmDeleteUser(String userId, String name) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete $name? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      await _deleteUser(userId);
    }
  }
  void _debugRoles() {
  print('Total users: ${_users.length}');
  for (var user in _users) {
    print('User: ${user['first_name']} ${user['last_name']}, Role: "${user['role']}"');
  }
}
  Future<void> _deleteUser(String userId) async {
  setState(() {
    _isLoading = true;
  });
  
  try {
    final supabase = Supabase.instance.client;
    
    // Call the secure function to delete the user
    final result = await supabase.rpc(
      'force_delete_user',
      params: {
        'user_id_param': userId
      }
    );
    
    print('Delete user result: $result');
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('User deleted successfully'),
        backgroundColor: Colors.green,
      ),
    );
    
    // Refresh user list
    await _fetchUsers();
    
  } catch (e) {
    print('Error in _deleteUser: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error deleting user: $e'),
        backgroundColor: Colors.red,
      ),
    );
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}
 String _getRoleDisplay(String role) {
  switch (role.toLowerCase()) {  // Make case insensitive
    case 'admin':
      return 'Administrator';
    case 'field_officer':
      return 'Field Officer';
    case 'user':
      return 'Standard User';
    default:
      return role;
  }
}
  
  // Edit user role
  Future<void> _showEditRoleDialog(Map<String, dynamic> user) async {
    final String currentRole = user['role'] ?? 'user';
    String selectedRole = currentRole;
    
    final newRole = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit User Role'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: const Text('Admin'),
                value: 'admin',
                groupValue: selectedRole,
                onChanged: (value) {
                  setState(() {
                    selectedRole = value!;
                  });
                },
              ),
              RadioListTile<String>(
                title: const Text('Standard User'),
                value: 'user',
                groupValue: selectedRole,
                onChanged: (value) {
                  setState(() {
                    selectedRole = value!;
                  });
                },
              ),
              RadioListTile<String>(
                title: const Text('Field Officer'),
                value: 'field_officer',
                groupValue: selectedRole,
                onChanged: (value) {
                  setState(() {
                    selectedRole = value!;
                  });
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(selectedRole),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF003366),
            ),
            child: const Text('Update Role'),
          ),
        ],
      ),
    );
    
    if (newRole != null && newRole != currentRole) {
      await _updateUserRole(user['user_id'], newRole);
    }
  }
  
Future<void> _updateUserRole(String userId, String newRole) async {
  setState(() {
    _isLoading = true;
  });
  
  try {
    print('Starting role update for user $userId to $newRole');
    final supabase = Supabase.instance.client;
    
    // Step 1: Update the role in user_profiles table
    final updateResult = await supabase.rpc(
      'force_update_user_role',
      params: {
        'user_id_param': userId,
        'new_role_param': newRole
      }
    );
    
    print('Role update result: $updateResult');
    
    // Step 2: Sync with admins table if new role is admin
    if (newRole.toLowerCase() == 'admin') {
      // Add to admins table if not exists
      try {
        await supabase.from('admins').upsert({
          'user_id': userId,
          'role': 'admin',
          'created_at': DateTime.now().toIso8601String()
        });
        print('Added user to admins table');
      } catch (e) {
        print('Error adding to admins table: $e');
        // Continue since user_profiles is the source of truth
      }
    } else {
      // Remove from admins table if user is no longer an admin
      try {
        await supabase.from('admins')
          .delete()
          .eq('user_id', userId);
        print('Removed user from admins table if existed');
      } catch (e) {
        print('Error removing from admins table: $e');
        // Continue since user_profiles is the source of truth
      }
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('User role updated successfully'),
        backgroundColor: Colors.green,
      ),
    );
    
    // Refresh user list
    await _fetchUsers();
    
  } catch (e) {
    print('Error in _updateUserRole: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error updating user role: $e'),
        backgroundColor: Colors.red,
      ),
    );
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}
  
  // Reset user password
  Future<void> _showResetPasswordDialog(String userId, String email) async {
    final TextEditingController newPasswordController = TextEditingController();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reset password for $email'),
            const SizedBox(height: 16),
            TextField(
              controller: newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(),
                hintText: 'Enter new password',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF003366),
            ),
            child: const Text('Reset Password'),
          ),
        ],
      ),
    );
    
    if (confirmed == true && newPasswordController.text.isNotEmpty) {
      await _resetPassword(userId, newPasswordController.text);
    }
    
    newPasswordController.dispose();
  }
  // Add this method to your _UserManagementScreenState class
Widget _buildStatCard(String title, String value, Color valueColor) {
  return Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    ),
  );
}

Color _getRoleColor(String role) {
  switch (role.toLowerCase()) {  // Make case insensitive
    case 'admin':
      return Colors.purple.shade700;
    case 'field_officer':
      return Colors.orange.shade700;
    case 'user':
      return Colors.blue.shade700;
    default:
      return Colors.grey.shade700;
  }
}

Future<void> _resetPassword(String userId, String newPassword) async {
  setState(() {
    _isLoading = true;
  });
  
  try {
    final supabase = Supabase.instance.client;
    
    // Step 1: Check if the user has permission to reset passwords
    final permissionResult = await supabase.rpc(
      'secure_reset_password',
      params: {
        'user_id_param': userId,
        'new_password_param': newPassword
      }
    );
    
    print('Permission check result: $permissionResult');
    
    // Step 2: Call the Edge Function to actually reset the password
    final response = await supabase.functions.invoke(
      'reset-password',
      body: {
        'user_id': userId,
        'new_password': newPassword
      },
    );
    
    // Get the response data and check for errors in the data
    final data = response.data;
    if (data != null && data['error'] != null) {
      throw Exception(data['error']);
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Password reset successfully'),
        backgroundColor: Colors.green,
      ),
    );
    
  } catch (e) {
    print('Error in _resetPassword: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error resetting password: $e'),
        backgroundColor: Colors.red,
      ),
    );
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'User Management',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF003366),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'User List'),
            Tab(text: 'Add Admin'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchUsers,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUserList(),
          _buildAddAdminForm(),
        ],
      ),
    );
  }
  
  Widget _buildUserList() {
    return Column(
      children: [
        // Search box
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search users...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            ),
            onChanged: _filterUsers,
          ),
        ),
        
        // User summary stats
        // User summary stats
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
  child: Row(
    children: [
      _buildStatCard(
        'Total Users',
        _users.length.toString(),
        Colors.blue.shade800,
      ),
      const SizedBox(width: 12),
      _buildStatCard(
        'Admins',
        _users.where((user) => 
          (user['role'] ?? '').toString().toLowerCase() == 'admin'
        ).length.toString(),
        Colors.purple.shade800,
      ),
      const SizedBox(width: 12),
      _buildStatCard(
        'Field Officers',
        _users.where((user) => 
          (user['role'] ?? '').toString().toLowerCase() == 'field_officer'
        ).length.toString(),
        Colors.orange.shade800,
      ),
    ],
  ),
),
        // User list
        Expanded(
          child: _isUserListLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF003366),
                  ),
                )
              : _filteredUsers.isEmpty
                  ? const Center(
                      child: Text('No users found'),
                    )
                  : ListView.builder(
                      itemCount: _filteredUsers.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      itemBuilder: (context, index) {
                        final user = _filteredUsers[index];
                        return _buildUserItem(user);
                      },
                    ),
        ),
      ],
    );
  }
  
  Widget _buildUserItem(Map<String, dynamic> user) {
  final firstName = user['first_name'] ?? '';
  final lastName = user['last_name'] ?? '';
  final fullName = '$firstName $lastName';
  final email = user['users']?['email'] ?? 'No email';
  final role = (user['role'] ?? 'user').toString(); // Ensure it's a string
  final userId = user['user_id'] ?? '';
  
  return Card(
    margin: const EdgeInsets.only(bottom: 12.0),
    elevation: 2,
    child: Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User avatar with role color - use toLowerCase for case insensitivity
              CircleAvatar(
                backgroundColor: _getRoleColor(role),
                radius: 25,
                child: Text(
                  fullName.isNotEmpty ? fullName.substring(0, 1).toUpperCase() : '?',
                  style: const TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // User info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName.isNotEmpty ? fullName : 'No name',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getRoleColor(role).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _getRoleDisplay(role), // This will now use case-insensitive comparison
                        style: TextStyle(
                          color: _getRoleColor(role),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          // Action buttons
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Edit role button
                OutlinedButton.icon(
                  onPressed: () => _showEditRoleDialog(user),
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit Role'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF003366),
                  ),
                ),
                const SizedBox(width: 8),
                // Reset password button
                OutlinedButton.icon(
                  onPressed: () => _showResetPasswordDialog(userId, email),
                  icon: const Icon(Icons.password),
                  label: const Text('Reset Password'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange.shade800,
                  ),
                ),
                const SizedBox(width: 8),
                // Delete user button
                OutlinedButton.icon(
                  onPressed: () => _confirmDeleteUser(userId, fullName),
                  icon: const Icon(Icons.delete),
                  label: const Text('Delete'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
Widget _buildPermissionItem(String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8.0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.check_circle, size: 18, color: Colors.green.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text),
        ),
      ],
    ),
  );
}


  Widget _buildAddAdminForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Add Admin Form
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Create New Admin Account',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF003366),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Success message
                    if (_successMessage != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade300),
                        ),
                        child: Text(
                          _successMessage!,
                          style: TextStyle(color: Colors.green.shade800),
                        ),
                      ),
                    
                    // Error message
                    if (_errorMessage != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
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
                    
                    // First Name
                    TextFormField(
                      controller: _firstNameController,
                      decoration: const InputDecoration(
                        labelText: 'First Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter first name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Last Name
                    TextFormField(
                      controller: _lastNameController,
                      decoration: const InputDecoration(
                        labelText: 'Last Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter last name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Email
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter email';
                        }
                        if (!value.contains('@') || !value.contains('.')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Password
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter password';
                        }
                        if (value.length < 8) {
                          return 'Password must be at least 8 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    
                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _addAdmin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF003366),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                                'Create Admin Account',
                                style: TextStyle(fontSize: 16),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Admin permissions description
          const SizedBox(height: 24),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      const Text(
                        'Administrator Permissions',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Administrators have full access to the system, including:',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildPermissionItem('User management (add, edit, delete users)'),
                  _buildPermissionItem('Access to all incidents and reports'),
                  _buildPermissionItem('Emergency alert capabilities'),
                  _buildPermissionItem('System configuration and settings'),
                  _buildPermissionItem('View and export analytics data'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }}