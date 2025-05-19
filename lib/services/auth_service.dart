import 'dart:convert';

import 'package:flutter_chat_application/models/user_model.dart';
import 'package:http/http.dart' as http;

class AuthService {
  static const String _baseUrl = 'http://localhost:3030/api/v1/auth';

  Future<Map<String, dynamic>> signup(User user) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(user.toJson()),
      );
      print(response);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        final errorBody = json.decode(response.body);
        return {'message': errorBody['message']};
      }
    } catch (e) {
      return {'message': e};
    }
  }

  Future<String> login(String email, String password) async {
    final Uri loginUrl = Uri.parse('$_baseUrl/login');

    final response = await http.post(
      loginUrl,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    final responseData = jsonDecode(response.body);
    return responseData['data'];
  }
}
