import 'package:flutter/material.dart';
import 'package:flutter_chat_application/screens/chat/chat_screen.dart';
import 'package:flutter_chat_application/screens/chatList/chat_list_screen.dart';
import 'package:flutter_chat_application/screens/signin/signin_screen.dart';
import 'package:flutter_chat_application/screens/signup/signup_screen.dart';

class RouterApp {
  static const String signIn = '/sign-in';
  static const String signUp = '/sign-up';
  static const String forgotPassword = '/forgot-password';
  static const String chats = '/chats';
  static const String profile = '/profile';
  static const String chat = '/chat';
  static Map<String, WidgetBuilder> routes = {
    signIn: (context) => const SigninScreen(),
    signUp: (context) => const SignUpScreen(),
    chats: (context) => const ChatListScreen(),
    chat: (context) {
      final String id = ModalRoute.of(context)?.settings.arguments as String;
      return ChatScreen(id: id);
    },
  };
}
