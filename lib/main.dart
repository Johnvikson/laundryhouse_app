import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'providers/user_provider.dart';
import 'services/notification_service.dart';
import 'providers/order_provider.dart';
import 'screens/splash1_screen.dart';
import 'customer_page/auth/login_screen.dart';
import 'customer_page/auth/signup_screen.dart';
import 'customer_page/home/home_screen.dart';
import 'customer_page/track/track_screen.dart';
import 'customer_page/profile/profile_screen.dart';
import 'rider_page/auth/rider_login_screen.dart';
import 'rider_page/home/rider_home_screen.dart';
import 'onboarding/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  await NotificationService.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'LaundryHouse',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF9333EA),
            secondary: const Color(0xFF38BDF8),
          ),
          useMaterial3: true,
        ),
        home: const Splash1Screen(),
        routes: {
          '/onboarding': (context) => const OnboardingScreen(),
          '/login': (context) => const CustomerLoginScreen(),
          '/signup': (context) => const CustomerLoginScreen(),
          '/home': (context) => const CustomerHomeScreen(),
          '/track': (context) => const CustomerTrackScreen(),
          '/profile': (context) => const CustomerProfileScreen(),
          '/rider/login': (context) => const RiderLoginScreen(),
          '/rider/home': (context) => const RiderHomeScreen(),
        },
      ),
    );
  }
}
