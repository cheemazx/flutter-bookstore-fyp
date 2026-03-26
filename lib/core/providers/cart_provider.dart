import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cart_item.dart';
import '../models/book.dart';
import '../../features/buyer/data/cart_repository.dart';
import '../../features/auth/data/auth_repository.dart';

class CartNotifier extends AsyncNotifier<List<CartItem>> {
  @override
  Future<List<CartItem>> build() async {
    final user = ref.watch(authRepositoryProvider).currentUser;
    if (user == null) return [];
    return ref.read(cartRepositoryProvider).getCartItems(user.id);
  }

  Future<void> _refresh() async {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) return;
    state = const AsyncValue.loading();
    state = AsyncValue.data(
      await ref.read(cartRepositoryProvider).getCartItems(user.id),
    );
  }

  Future<void> addToCart(Book book) async {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user != null) {
      await ref.read(cartRepositoryProvider).addToCart(user.id, book);
      await _refresh();
    }
  }

  Future<void> removeFromCart(String bookId) async {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user != null) {
      await ref.read(cartRepositoryProvider).removeFromCart(user.id, bookId);
      await _refresh();
    }
  }

  Future<void> incrementQuantity(String bookId) async {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user != null) {
      await ref.read(cartRepositoryProvider).updateQuantity(user.id, bookId, 1);
      await _refresh();
    }
  }

  Future<void> decrementQuantity(String bookId) async {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user != null) {
      await ref.read(cartRepositoryProvider).updateQuantity(user.id, bookId, -1);
      await _refresh();
    }
  }

  Future<void> clearCart() async {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user != null) {
      await ref.read(cartRepositoryProvider).clearCart(user.id);
      await _refresh();
    }
  }
}

final cartProvider = AsyncNotifierProvider<CartNotifier, List<CartItem>>(CartNotifier.new);

final cartTotalProvider = Provider<double>((ref) {
  final cartAsync = ref.watch(cartProvider);
  return cartAsync.maybeWhen(
    data: (items) => items.fold(0.0, (sum, item) => sum + item.totalPrice),
    orElse: () => 0.0,
  );
});
