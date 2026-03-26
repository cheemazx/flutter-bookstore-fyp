import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';

void main() async {
  final envFile = File('.env');
  final lines = await envFile.readAsLines();
  String apiKey = '';
  for (var line in lines) {
    if (line.startsWith('GEMINI_API_KEY=')) {
      apiKey = line.split('=')[1];
      break;
    }
  }

  if (apiKey.isEmpty) {
    print('No API key found!');
    return;
  }

  final response = await http.get(Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey'));
  print(response.body);
}
