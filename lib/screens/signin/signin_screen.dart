import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_chat_application/services/auth_service.dart';
import 'package:flutter_chat_application/storage/secure_storage.dart';
import 'package:flutter_chat_application/widgets/auth_alert.dart';
import 'package:flutter_chat_application/widgets/auth_text_field.dart';
import 'package:rflutter_alert/rflutter_alert.dart';

class SigninScreen extends StatefulWidget {
  const SigninScreen({super.key});

  @override
  State<SigninScreen> createState() => _AuthLoginState();
}

class _AuthLoginState extends State<SigninScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool isLoading = false;
  String errorMessage = '';
  final AuthService _authService = AuthService();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

Future<void> _login() async {
  final email = _emailController.text.trim();
  final password = _passwordController.text.trim();

  if (email.isEmpty) {
    setState(() {
      errorMessage = 'Email must not be empty.';
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

  setState(() {
    isLoading = true;
    errorMessage = '';
  });

  try {
    final result = await _authService.login(email, password);

    if (result.contains("exist") || result.contains("incorrect")) {
       AuthAlert(
        title: "Failed",
        description: result,
        type: AlertType.error,
      ).show(context);
      
    } else {
     const AuthAlert(
        title: "Login Success",
        description: "You have logged in successfully!",
        type: AlertType.success,
      ).show(context);

        await SecureStorage().saveToken(result);

      Timer(
        const Duration(seconds: 1),
        () => Navigator.pushReplacementNamed(context, '/chats'),
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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Welcome to Chat Application!',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
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
              if (errorMessage.isNotEmpty)
                Text(
                  errorMessage,
                  style: const TextStyle(color: Colors.red),
                ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/forgot-password');
                  },
                  child: const Text('Forgot Password?'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator()
                      : const Text(
                          'Login',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account?"),
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/sign-up');
                    },
                    child: const Text('Sign Up'),
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

