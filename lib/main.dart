import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  
  await Supabase.initialize(
    url: dotenv.get('SUPABASE_URL'),
    anonKey: dotenv.get('SUPABASE_ANON_KEY'),
  );

  runApp(const ProviderScope(child: BookstoreApp()));
}

class BookstoreApp extends StatelessWidget {
  const BookstoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Bookstore',
      theme: AppTheme.lightTheme.copyWith(
        textTheme: GoogleFonts.interTextTheme(AppTheme.lightTheme.textTheme),
      ),
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
