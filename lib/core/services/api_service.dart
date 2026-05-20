import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';

class ApiService {
  final String? authToken;

  ApiService({this.authToken});

  /// نفس دالة [_post] القديمة، ولكن هنا نستخدم [AppConstants.serverUrl]
  Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> body,
      {bool authenticate = false}) async {
    final uri = Uri.parse('${AppConstants.serverUrl}$endpoint');
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (authenticate && authToken != null) {
      headers['Authorization'] = 'Bearer $authToken';
    }
    final response =
        await http.post(uri, headers: headers, body: jsonEncode(body));
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw decoded['error'] ?? 'خطأ غير معروف';
    }
    return decoded;
  }
}
