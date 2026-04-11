//https://bbqvamxf5dlexddyt4dsy7je3y0wjhop.lambda-url.us-east-1.on.aws/
import 'dart:convert';
import 'package:http/http.dart' as http;




class ApiService {

  static Future<String?> getYoutubeVideo(String query) async {
    final url = Uri.parse(
      "https://www.googleapis.com/youtube/v3/search"
          "?part=snippet&type=video&maxResults=1&q=$query&key=xxxxxx",
    );

    final response = await http.get(url);
    final data = jsonDecode(response.body);

    if (data["items"] != null && data["items"].length > 0) {
      final videoId = data["items"][0]["id"]["videoId"];
      return "https://www.youtube.com/watch?v=$videoId";
    }

    return null;
  }

  static Future<String> generateNotes(String text) async {
    final url = Uri.parse("https://openrouter.ai/api/v1/chat/completions");

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer sk-or-v1-xxxxxxx",
        },
        body: jsonEncode({
          "model": "openai/gpt-3.5-turbo",
          "messages": [
            {
              "role": "user",
              "content": """
You are an expert teacher who explains concepts deeply and clearly.

Convert the following OCR text into COMPLETE STUDY NOTES.

VERY IMPORTANT FORMATTING RULES (STRICT):
- Use '#' ONLY for main topic heading
- Use '@' ONLY for subtopics
- Use '!' for explanations and normal content
- Use '\$' for important points, formulas, or key highlights
- Do NOT use any other symbols or markdown
- Follow this format strictly

Content Rules:
1. Identify the main topic.
2. Write a proper definition of the topic.
3. Break into subtopics.
4. give full answer of the topics included in the text. don't leave topics asking that continue with the explanation?... something like this.

For EACH subtopic:
- Give a clear definition
- Explain how it works step-by-step
- If mathematical:
  • Explain formula
  • Explain each variable
  • Show how it works step-by-step
  
- If Coding related Topics/Computer Science related Topics:
  • Explain The Topic 
  • Explain its advantages and disadvantages
  • Show how it works step-by-step
  • Show formulas if required in the code, and explain the formulas also.
  • Give examples (real-life if possible)
- Give examples (real-life if possible)

4. Expand unclear OCR text into meaningful content.
5. Do NOT summarize — explain in detail.
6. Make it useful for exams and deep understanding.

Format:

# Topic Name

## Definition
(detailed explanation)

## Subtopic 1
- Definition
- Explanation (step-by-step)
- Example

## Subtopic 2
...

OCR Text:
$text
"""
            }
          ]
        }),
      );

      print("STATUS: ${response.statusCode}");
      print("BODY: ${response.body}");

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data["choices"] != null) {
        return data["choices"][0]["message"]["content"];
      } else {
        return "API Error: ${data.toString()}";
      }
    } catch (e) {
      return "Exception: $e";
    }
  }
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
}