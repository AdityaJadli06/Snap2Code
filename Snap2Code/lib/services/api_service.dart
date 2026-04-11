//https://bbqvamxf5dlexddyt4dsy7je3y0wjhop.lambda-url.us-east-1.on.aws/
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl =
      "https://bbqvamxf5dlexddyt4dsy7je3y0wjhop.lambda-url.us-east-1.on.aws/";

  static Future<Map<String, dynamic>> registerUser({
    required String email,
    required String name,
    required String password,
  }) async {
    final url = Uri.parse(baseUrl);

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "email": email,
          "name": name,
          "password": password,
        }),
      );

      final data = jsonDecode(response.body);

      return {
        "status": response.statusCode,
        "data": data,
      };
    } catch (e) {
      return {
        "status": 500,
        "data": {"message": "Network error"},
      };
    }
  }
  static Future<Map<String, dynamic>> loginUser({
    required String email,
    required String password,
  }) async {
    final url = Uri.parse(
      "https://dzpqvvlv6xna7i76bygoyvxqoi0qmjth.lambda-url.us-east-1.on.aws/",
    );

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "email": email,
          "password": password,
        }),
      );

      final data = jsonDecode(response.body);

      return {
        "status": response.statusCode,
        "data": data,
      };
    } catch (e) {
      return {
        "status": 500,
        "data": {"message": "Network error"},
      };
    }
  }
  static Future<bool> verifyToken(String token) async {
    final url = Uri.parse(
      "https://pulst47jc6gnjvsb6y4qekem6q0tllia.lambda-url.us-east-1.on.aws/",
    );

    try {
      final response = await http.get(
        url,
        headers: {
          "Authorization": "Bearer $token",
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> resetPassword(String email) async {
    // This is currently a simulated endpoint as it's not yet available on the backend
    await Future.delayed(const Duration(seconds: 2));
    
    // Logic to simulate success/failure
    if (email.contains('@')) {
      return {
        "status": 200,
        "data": {"message": "Success"}
      };
    } else {
      return {
        "status": 400,
        "data": {"message": "Invalid email address"}
      };
    }
  }
}