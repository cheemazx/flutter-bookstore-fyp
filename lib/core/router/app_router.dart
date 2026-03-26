
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/book.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/seller/presentation/seller_orders_screen.dart';
import '../../features/seller/presentation/seller_notifications_screen.dart';
import '../../features/seller/presentation/seller_dashboard_screen.dart';
import '../../features/seller/presentation/store_profile_screen.dart';
import '../../features/seller/presentation/add_product_screen.dart';
import '../../features/seller/presentation/seller_analytics_screen.dart';
import '../../features/buyer/presentation/buyer_home_screen.dart';
import '../../features/buyer/presentation/product_details_screen.dart';
import '../../features/buyer/presentation/cart_screen.dart';
import '../../features/buyer/presentation/checkout_screen.dart';
import '../../features/buyer/presentation/buyer_profile_screen.dart';
import '../../features/buyer/presentation/edit_profile_screen.dart';
import '../../features/buyer/presentation/order_history_screen.dart';
import '../../features/buyer/presentation/buyer_settings_screen.dart';
import '../../features/buyer/presentation/order_details_screen.dart';
import '../../features/buyer/presentation/chatbot_screen.dart';
import '../../core/models/order_model.dart';

final appRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/seller-dashboard',
      builder: (context, state) => const SellerDashboardScreen(),
    ),
    GoRoute(
      path: '/seller-orders',
      builder: (context, state) => const SellerOrdersScreen(),
    ),
    GoRoute(
      path: '/store-profile',
      builder: (context, state) => const StoreProfileScreen(),
    ),
    GoRoute(
      path: '/add-product',
      builder: (context, state) {
        final bookToEdit = state.extra as Book?;
        return AddProductScreen(bookToEdit: bookToEdit);
      },
    ),
    GoRoute(
      path: '/buyer-home',
      builder: (context, state) => const BuyerHomeScreen(),
    ),
    GoRoute(
      path: '/product-details/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        final book = state.extra as Book?;
        return ProductDetailsScreen(bookId: id, book: book);
      },
    ),
    GoRoute(
      path: '/cart',
      builder: (context, state) => const CartScreen(),
    ),
    GoRoute(
      path: '/checkout',
      builder: (context, state) => const CheckoutScreen(),
    ),
    GoRoute(
      path: '/buyer-profile',
      builder: (context, state) => const BuyerProfileScreen(),
    ),
    GoRoute(
      path: '/edit-profile',
      builder: (context, state) => const EditProfileScreen(),
    ),
    GoRoute(
      path: '/order-history',
      builder: (context, state) => const OrderHistoryScreen(),
    ),
    GoRoute(
      path: '/buyer-settings',
      builder: (context, state) => const BuyerSettingsScreen(),
    ),
    GoRoute(
      path: '/order-details',
      builder: (context, state) {
        final order = state.extra as OrderModel;
        return OrderDetailsScreen(order: order);
      },
    ),
    GoRoute(
      path: '/chatbot',
      builder: (context, state) => const ChatbotScreen(),
    ),
    GoRoute(
      path: '/seller-notifications',
      builder: (context, state) => const SellerNotificationsScreen(),
    ),
    GoRoute(
      path: '/seller-analytics',
      builder: (context, state) => const SellerAnalyticsScreen(),
    ),
  ],
);
