
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_app/core/models/book.dart';
import 'package:my_app/features/seller/data/product_repository.dart';
import 'package:my_app/features/auth/data/auth_repository.dart';

class InventoryNotifier extends StreamNotifier<List<Book>> {
  @override
  Stream<List<Book>> build() {
    final user = ref.watch(authRepositoryProvider).currentUser;
    if (user == null) {
      return Stream.value([]);
    }
    return ref.watch(productRepositoryProvider).getSellerBooks(user.id);
  }

  Future<void> addBook(Book book) async {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user != null) {
       String docId = book.id;
       if (docId.isEmpty) {
         docId = ref.read(productRepositoryProvider).generateId();
       }

       // We respect the fields passed from the UI (AddProductScreen)
       // which already fetches and sets sellerId and storeName correctly.
       final bookToSave = Book(
         id: docId,
         title: book.title,
         author: book.author,
         price: book.price,
         imageUrls: book.imageUrls,
         description: book.description,
         rating: book.rating,
         sellerId: book.sellerId.isNotEmpty ? book.sellerId : user.id,
         storeName: book.storeName,
         quantity: book.quantity,
         genre: book.genre,
       );
       print('DEBUG: Adding book: ${bookToSave.title}, SellerID: ${bookToSave.sellerId}, StoreName: ${bookToSave.storeName}');
       await ref.read(productRepositoryProvider).addBook(bookToSave);
    }
  }

  Future<void> updateBook(Book book) async {
     await ref.read(productRepositoryProvider).updateBook(book);
  }

  Future<void> deleteBook(String bookId) async {
    await ref.read(productRepositoryProvider).deleteBook(bookId);
  }
}

final inventoryProvider = StreamNotifierProvider<InventoryNotifier, List<Book>>(InventoryNotifier.new);
