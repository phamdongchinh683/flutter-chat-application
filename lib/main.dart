import 'package:flutter/material.dart';
import 'package:flutter_chat_application/router/router_app.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chat App',
      debugShowCheckedModeBanner: false,
      initialRoute: RouterApp.signIn,
      routes: RouterApp.routes,
    );
  }
}
