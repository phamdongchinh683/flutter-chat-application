import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_chat_application/models/user_model.dart';
import 'package:flutter_chat_application/services/auth_service.dart';
import 'package:flutter_chat_application/widgets/auth_alert.dart';
import 'package:flutter_chat_application/widgets/auth_text_field.dart';
import 'package:rflutter_alert/rflutter_alert.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _AuthSignUpScreen();
}

class _AuthSignUpScreen extends State<SignUpScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _mobileNumberController = TextEditingController();
  bool isLoading = false;
  String errorMessage = '';
  final AuthService _authService = AuthService();

  Future<void> _Register() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final mobileNumber = _mobileNumberController.text.trim();
    if (email.isEmpty) {
      setState(() {
        errorMessage = 'Email not empty';
      });
      return;
    }

    final emailRegex = RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$");
    if (!emailRegex.hasMatch(email)) {
      setState(() {
        errorMessage = 'Please provide a valid email.';
      });
      return;
    }
    if (password.length < 9 || password.length > 20) {
      setState(() {
        errorMessage = 'Password must be between 9 and 20 characters.';
      });
      return;
    }

    if (mobileNumber.isEmpty) {
      setState(() {
        errorMessage = 'Mobile number not empty';
      });
      return;
    }

    if (mobileNumber.length < 10 || mobileNumber.length > 15) {
      setState(() {
        errorMessage = 'Mobile number must be between 10 and 15 characters';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      User data = User(
        email: email,
        password: password,
        phoneNumber: mobileNumber,
        role: 'user',
      );
      final result = await _authService.signup(data);
      if (result['data'].contains("users_phone_number_unique")) {
        const AuthAlert(
          title: "Failed",
          description: "Mobile number already exists",
          type: AlertType.error,
        ).show(context);
        return;
      }

      if (result['data'].contains("users_email_unique")) {
        const AuthAlert(
          title: "Failed",
          description: "Email already exists",
          type: AlertType.error,
        ).show(context);
        return;
      }

      if (result['data'].contains("success")) {
        const AuthAlert(
          title: "Success",
          description: "You can login now",
          type: AlertType.success,
        ).show(context);
        Timer(
          const Duration(seconds: 1),
          () => Navigator.pushReplacementNamed(context, '/sign-in'),
        );
      }
    } catch (e) {
      AuthAlert(
        title: "Failed",
        description: e.toString(),
        type: AlertType.error,
      ).show(context);
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Create Account',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),
              AuthTextField(
                label: 'Email',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                controller: _emailController,
              ),
              const SizedBox(height: 20),
              AuthTextField(
                label: 'Password',
                icon: Icons.lock_outline,
                obscureText: true,
                controller: _passwordController,
              ),
              const SizedBox(height: 20),
              AuthTextField(
                label: 'Mobile Number',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                controller: _mobileNumberController,
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _Register,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator()
                      : const Text(
                          'Sign Up',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
              const SizedBox(height: 30),
              if (errorMessage.isNotEmpty)
                Text(
                  errorMessage,
                  style: const TextStyle(color: Colors.red),
                ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Already have an account?"),
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/sign-in');
                    },
                    child: const Text('Sign In'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
