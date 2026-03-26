import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/cart_item.dart';
import '../../../core/models/book.dart';

class CartRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Fetch all cart items for a user (with full book data)
  Future<List<CartItem>> getCartItems(String userId) async {
    try {
      final cartRows = await _supabase
          .from('cart')
          .select()
          .eq('userId', userId);

      if (cartRows.isEmpty) return [];

      final bookIds = cartRows.map((row) => row['bookId'] as String).toList();

      final booksResponse = await _supabase
          .from('books')
          .select()
          .inFilter('id', bookIds);

      final bookMap = <String, Book>{};
      for (final bookJson in booksResponse) {
        final book = Book.fromMap(bookJson, bookJson['id']);
        bookMap[book.id] = book;
      }

      final cartItems = <CartItem>[];
      for (final row in cartRows) {
        final bookId = row['bookId'] as String;
        final book = bookMap[bookId];
        if (book != null) {
          cartItems.add(CartItem(
            book: book,
            quantity: row['quantity'] as int? ?? 1,
          ));
        }
      }
      return cartItems;
    } catch (e) {
      print('CartRepository.getCartItems error: $e');
      return [];
    }
  }

  Future<void> addToCart(String userId, Book book) async {
    try {
      final response = await _supabase
          .from('cart')
          .select('quantity')
          .eq('userId', userId)
          .eq('bookId', book.id)
          .maybeSingle();

      if (response != null) {
        final currentQuantity = response['quantity'] as int;
        await _supabase
            .from('cart')
            .update({'quantity': currentQuantity + 1})
            .eq('userId', userId)
            .eq('bookId', book.id);
      } else {
        await _supabase.from('cart').insert({
          'userId': userId,
          'bookId': book.id,
          'quantity': 1,
        });
      }
      print('CartRepository.addToCart: success for book ${book.id}');
    } catch (e) {
      print('CartRepository.addToCart error: $e');
      rethrow;
    }
  }

  Future<void> removeFromCart(String userId, String bookId) async {
    await _supabase.from('cart').delete().eq('userId', userId).eq('bookId', bookId);
  }

  Future<void> updateQuantity(String userId, String bookId, int change) async {
    final response = await _supabase
        .from('cart')
        .select('quantity')
        .eq('userId', userId)
        .eq('bookId', bookId)
        .maybeSingle();

    if (response != null) {
      final currentQuantity = response['quantity'] as int;
      final newQuantity = currentQuantity + change;

      if (newQuantity <= 0) {
        await _supabase.from('cart').delete().eq('userId', userId).eq('bookId', bookId);
      } else {
        await _supabase.from('cart').update({'quantity': newQuantity}).eq('userId', userId).eq('bookId', bookId);
      }
    }
  }

  Future<void> clearCart(String userId) async {
    await _supabase.from('cart').delete().eq('userId', userId);
  }
}

final cartRepositoryProvider = Provider<CartRepository>((ref) {
  return CartRepository();
});
