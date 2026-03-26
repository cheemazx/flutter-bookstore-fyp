import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/models/book.dart';

class ChatService {
  final SupabaseClient _supabase = Supabase.instance.client;
  late GenerativeModel _model;
  ChatSession? _chat;
  bool _initialized = false;
  final String _apiKey;

  ChatService(this._apiKey);

  /// Fetches all available books and builds a catalog string for the AI
  Future<String> _buildBookCatalog() async {
    try {
      final response = await _supabase.from('books').select();
      final books = response
          .map((json) => Book.fromMap(json, json['id']))
          .where((book) => book.quantity > 0)
          .toList();

      if (books.isEmpty) {
        return 'Currently there are no books available in the store.';
      }

      final buffer = StringBuffer();
      buffer.writeln('Here are all the books currently available in our bookstore:');
      buffer.writeln();
      for (int i = 0; i < books.length; i++) {
        final b = books[i];
        buffer.writeln('${i + 1}. "${b.title}" by ${b.author}');
        buffer.writeln('   - Genre: ${b.genre}');
        buffer.writeln('   - Price: \$${b.price.toStringAsFixed(2)}');
        buffer.writeln('   - Rating: ${b.rating}/5');
        buffer.writeln('   - Store: ${b.storeName.isNotEmpty ? b.storeName : "Unknown"}');
        buffer.writeln('   - In Stock: ${b.quantity} copies');
        if (b.description.isNotEmpty) {
          buffer.writeln('   - Description: ${b.description}');
        }
        buffer.writeln();
      }
      return buffer.toString();
    } catch (e) {
      print('ChatService._buildBookCatalog error: $e');
      return 'Unable to fetch book catalog at this time.';
    }
  }

  /// Initialize the chat session with the book catalog context
  Future<void> _initChat() async {
    if (_initialized && _chat != null) return;

    final catalog = await _buildBookCatalog();

    final systemInstruction = Content.system('''You are a friendly and knowledgeable AI book assistant for a bookstore app. Your job is to help users find the perfect book based on their preferences.

IMPORTANT RULES:
1. You can ONLY recommend books that are in the catalog below. Never make up or suggest books that aren't listed.
2. When recommending a book, ALWAYS mention: the title, author, price, genre, and which STORE sells it.
3. If no books in the catalog match the user's request, politely say so and suggest the closest alternatives from the catalog.
4. Keep responses concise, warm, and helpful. Use emojis sparingly (1-2 per message max).
5. If the user asks about something unrelated to books, gently redirect them to book recommendations.
6. Format recommendations clearly with each book on its own line.

BOOK CATALOG:
$catalog''');

    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: _apiKey,
    );
    _initialized = true;
  }

  /// Send a message and get a response
  Future<String> sendMessage(String message) async {
    try {
      if (!_initialized) await _initChat();

      final catalog = await _buildBookCatalog();
      final fullPrompt = '''You are a friendly and knowledgeable AI book assistant for a bookstore app. Your job is to help users find the perfect book based on their preferences.

IMPORTANT RULES:
1. You can ONLY recommend books that are in the catalog below. Never make up or suggest books that aren't listed.
2. When recommending a book, ALWAYS mention: the title, author, price, genre, and which STORE sells it.
3. If no books in the catalog match the user's request, politely say so and suggest the closest alternatives from the catalog.
4. Keep responses concise, warm, and helpful. Use emojis sparingly (1-2 per message max).
5. If the user asks about something unrelated to books, gently redirect them to book recommendations.
6. Format recommendations clearly with each book on its own line.

BOOK CATALOG:
$catalog

User Message: $message''';

      _chat = _model.startChat();
      final response = await _chat!.sendMessage(Content.text(fullPrompt));
      return response.text ?? 'Sorry, I couldn\'t generate a response.';
      
    } catch (e) {
      print('ChatService.sendMessage error: $e');
      final errorStr = e.toString();
      
      if (errorStr.toLowerCase().contains('quota')) {
        return 'Sorry, your Google account has exceeded its free Gemini API quota. Please enable billing or use a different Google account.';
      }
      if (errorStr.contains('API key') || errorStr.contains('API_KEY_INVALID')) {
        return 'It looks like the AI API key is invalid or missing. Please check your Gemini API key in the .env file.';
      }
      if (errorStr.contains('SAFETY')) {
        return 'The response was blocked by safety filters. Please try rephrasing your request.';
      }
      
      return 'Sorry, something went wrong: ${e.toString().split('\n').first}';
    }
  }

  /// Reset the chat (e.g., to refresh book catalog)
  void resetChat() {
    _initialized = false;
    _chat = null;
  }
}
