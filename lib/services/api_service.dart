//https://bbqvamxf5dlexddyt4dsy7je3y0wjhop.lambda-url.us-east-1.on.aws/
import 'dart:convert';
import 'package:http/http.dart' as http;




class ApiService {

  static Future<List<dynamic>> fetchNotes(String email) async {
    final url = Uri.parse(
      "https://o3j2rdk2v4l3unndb3uqfmpyre0qipes.lambda-url.us-east-1.on.aws/getNotes",
    );

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "userId": email,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return data["notes"] ?? [];
      } else {
        return [];
      }
    } catch (e) {
      print("Fetch Notes Error: $e");
      return [];
    }
  }

  static Future<bool> saveNote({
    required String email,
    required String title,
    required String content,
    required List<String> videos,
  }) async {
    return await saveNoteToCloud(
      userId: email,
      title: title,
      content: content,
      videos: videos,
    );
  }

  static Future<List<String>> getYoutubeVideos(String query) async {
    final url = Uri.parse(
      "https://www.googleapis.com/youtube/v3/search"
          "?part=snippet&type=video&maxResults=3&q=$query&key=small",
    );

    try {
      final response = await http.get(url);
      final data = jsonDecode(response.body);

      List<String> videoLinks = [];
      if (data["items"] != null) {
        for (var item in data["items"]) {
          final videoId = item["id"]["videoId"];
          if (videoId != null) {
            videoLinks.add("https://www.youtube.com/watch?v=$videoId");
          }
        }
      }
      return videoLinks;
    } catch (e) {
      print("YouTube API Error: $e");
      return [];
    }
  }




  static Future<String> generateNotes(String text) async {
    final url = Uri.parse("https://openrouter.ai/api/v1/chat/completions");

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "Authorization": "Bearer sk-or-v1-big",
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

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data["choices"] != null) {
        String content = data["choices"][0]["message"]["content"];
        
        // Find all headings (Main # and Subtopics @)
        RegExp headingRegExp = RegExp(r'^[#@]\s*(.+)$', multiLine: true);
        Iterable<RegExpMatch> matches = headingRegExp.allMatches(content);
        
        List<String> allVideos = [];
        String finalContent = "";
        int lastIndex = 0;

        for (var match in matches) {
          // Add the content before this heading
          finalContent += content.substring(lastIndex, match.start);
          
          String headingText = match.group(0)!;
          String topicName = match.group(1)!;
          
          finalContent += "$headingText\n";
          
          // Fetch videos for this specific heading
          List<String> videos = await getYoutubeVideos(topicName);
          if (videos.isNotEmpty) {
            finalContent += "\n! Recommended Videos for $topicName:\n";
            for (var v in videos) {
              finalContent += "! $v\n";
              allVideos.add(v);
            }
            finalContent += "\n";
          }
          
          lastIndex = match.end;
        }
        
        // Add remaining content
        finalContent += content.substring(lastIndex);
        
        return jsonEncode({
          "notes": finalContent,
          "videos": allVideos
        });
      } else {
        return jsonEncode({
          "notes": "API Error: ${data.toString()}",
          "videos": []
        });
      }
    } catch (e) {
      return jsonEncode({
        "notes": "Exception: $e",
        "videos": []
      });
    }
  }



  static Future<bool> saveNoteToCloud({
    required String userId,
    required String title,
    required String content,
    required List<String> videos,
  }) async {
    final url = Uri.parse(
      "https://o3j2rdk2v4l3unndb3uqfmpyre0qipes.lambda-url.us-east-1.on.aws/",
    );

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "userId": userId,
          "title": title,
          "content": content,
          "videos": videos,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }


  static Future<String> performCloudOcr(String imagePath, List<int> imageBytes) async {
    final url = Uri.parse("https://openrouter.ai/api/v1/chat/completions");

    try {
      final base64Image = base64Encode(imageBytes);
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer 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",
        },
        body: jsonEncode({
          "model": "google/gemini-flash-1.5-8b", // Cheap and fast for OCR
          "messages": [
            {
              "role": "user",
              "content": [
                {"type": "text", "text": "Extract all text from this image. Only return the text found, nothing else."},
                {
                  "type": "image_url",
                  "image_url": {"url": "data:image/jpeg;base64,$base64Image"}
                }
              ]
            }
          ]
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data["choices"] != null) {
        return data["choices"][0]["message"]["content"];
      } else {
        return "Cloud OCR Error: ${response.body}";
      }
    } catch (e) {
      return "Cloud OCR Exception: $e";
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
          "Accept": "application/json",
        },
        body: jsonEncode({
          "email": email,
          "name": name,
          "password": password,
        }),
      );

      print("Register Status: ${response.statusCode}");
      print("Register Response: ${response.body}");

      dynamic data;
      try {
        data = jsonDecode(response.body);
      } catch (e) {
        data = {"message": response.body};
      }

      return {
        "status": response.statusCode,
        "data": data,
      };
    } catch (e) {
      print("Register Exception: $e");
      return {
        "status": 500,
        "data": {"message": "Network error: $e"},
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
          "Accept": "application/json",
        },
        body: jsonEncode({
          "email": email,
          "password": password,
        }),
      );

      print("Login Status: ${response.statusCode}");
      print("Login Response: ${response.body}");

      dynamic data;
      try {
        data = jsonDecode(response.body);
      } catch (e) {
        data = {"message": response.body};
      }

      return {
        "status": response.statusCode,
        "data": data,
      };
    } catch (e) {
      print("Login Exception: $e");
      return {
        "status": 500,
        "data": {"message": "Network error: $e"},
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
          "Accept": "application/json",
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      print("VerifyToken Exception: $e");
      return false;
    }
  }
}