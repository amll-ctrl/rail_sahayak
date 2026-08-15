import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/request_provider.dart';
import 'models/user_profile.dart';
import 'screens/auth/login_screen.dart';
import 'screens/passenger/passenger_home.dart';
import 'screens/staff/staff_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => RequestProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Select the currentUser to watch and rebuild screen routing reactively
    final currentUser = context.select((RequestProvider provider) => provider.currentUser);

    return MaterialApp(
      title: 'RailSahayak Accessibility Helper',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.orange.shade800,
          primary: Colors.orange.shade800,
          secondary: Colors.indigo.shade800,
        ),
        // Accessibility additions: clear layout spacing and high contrast text styles
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
          bodyLarge: TextStyle(fontSize: 16, height: 1.4),
          bodyMedium: TextStyle(fontSize: 14, height: 1.3),
        ),
        cardTheme: const CardThemeData(
          elevation: 2,
          margin: EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
        ),
      ),
      // Reactive Navigation routing based on auth user role
      home: _getHomeRoute(currentUser),
    );
  }

  Widget _getHomeRoute(UserProfile? user) {
    if (user == null) {
      return const LoginScreen();
    }
    
    if (user.role == UserRole.staff) {
      return const StaffDashboard();
    } else {
      return const PassengerHome();
    }
  }
}
