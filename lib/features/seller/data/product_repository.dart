import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_app/core/models/book.dart';
import 'package:uuid/uuid.dart';

class ProductRepository {
  final SupabaseClient _supabase;
  final Uuid _uuid = const Uuid();

  ProductRepository(this._supabase);
  
  String generateId() => _uuid.v4();

  Future<void> addBook(Book book) async {
    await _supabase.from('books').upsert(book.toMap());
  }

  Future<void> updateBook(Book book) async {
    await _supabase.from('books').update(book.toMap()).eq('id', book.id);
  }

  Future<void> deleteBook(String bookId) async {
    await _supabase.from('books').delete().eq('id', bookId);
  }

  Stream<List<Book>> getSellerBooks(String sellerId) {
    return _supabase
        .from('books')
        .stream(primaryKey: ['id'])
        .eq('sellerId', sellerId)
        .map((data) => data.map((json) => Book.fromMap(json, json['id'])).toList());
  }
  
  Stream<List<Book>> getAllBooks() {
    return _supabase.from('books').stream(primaryKey: ['id']).map((data) {
      return data
          .map((json) => Book.fromMap(json, json['id']))
          .where((book) => book.quantity > 0)
          .toList();
    });
  }

  Stream<Book?> getBook(String bookId) {
    return _supabase.from('books').stream(primaryKey: ['id']).eq('id', bookId).map((data) {
      if (data.isNotEmpty) {
        return Book.fromMap(data.first, data.first['id']);
      }
      return null;
    });
  }
}

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository(Supabase.instance.client);
});
