import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/request_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isStaff = false; // Toggle between Passenger and Staff login

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      final provider = Provider.of<RequestProvider>(context, listen: false);
      final success = await provider.login(
        _emailController.text,
        _passwordController.text,
        _isStaff,
      );

      if (success && mounted) {
        // Navigation is handled automatically by main.dart listening to auth state
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logged in as ${provider.currentUser?.name}'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    }
  }

  // Pre-fill fields for easy demo testing
  void _useDemoLogin(bool isStaffUser) {
    setState(() {
      _isStaff = isStaffUser;
      if (isStaffUser) {
        _emailController.text = 'sunil@railnet.gov.in';
        _passwordController.text = 'password123';
      } else {
        _emailController.text = 'ramesh@gmail.com';
        _passwordController.text = 'password123';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<RequestProvider>().isLoading;

    // Accessibility-focused design: large buttons, high contrast orange/blue colors
    final primaryColor = _isStaff ? Colors.indigo.shade800 : Colors.orange.shade800;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'RailSahayak - Accessibility',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: primaryColor,
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Indian Railways Tricolour Accent Accent Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(width: 30, height: 6, color: Colors.orange),
                            Container(width: 30, height: 6, color: Colors.white),
                            Container(width: 30, height: 6, color: Colors.green),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'RailSahayak',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: primaryColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Indian Railways Boarding Assistance App',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Accessible Role Segmented Switch
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => setState(() => _isStaff = false),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: !_isStaff ? Colors.orange.shade800 : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Passenger',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: !_isStaff ? Colors.white : const Color(0xFF212121),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: () => setState(() => _isStaff = true),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: _isStaff ? Colors.indigo.shade800 : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Railway Staff',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: _isStaff ? Colors.white : const Color(0xFF212121),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Email Field
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'Email Address / user ID',
                            hintText: 'Enter registered email',
                            prefixIcon: const Icon(Icons.email),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // Password Field
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        // Login Button
                        ElevatedButton(
                          onPressed: isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Login Securely',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                        ),
                        const SizedBox(height: 16),
                        
                        const Divider(),
                        const SizedBox(height: 8),
                        
                        // Accessible Quick Login Section for Testing
                        const Text(
                          'Demo Quick Actions (Beginner Testing):',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  _useDemoLogin(false);
                                  _handleLogin();
                                },
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: Colors.orange.shade800),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                                child: Text('Passenger', style: TextStyle(color: Colors.orange.shade800, fontSize: 13)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  _useDemoLogin(true);
                                  _handleLogin();
                                },
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: Colors.indigo.shade800),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                                child: Text('Staff / Guard', style: TextStyle(color: Colors.indigo.shade800, fontSize: 13)),
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
      ),
    );
  }
}
extension ColorsExtension on Colors {
  static const black800 = Color(0xFF212121);
}
