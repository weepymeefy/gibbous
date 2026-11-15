import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gibbous/services/profile_service.dart';
import 'package:gibbous/pages/onboarding.dart';
import 'package:gibbous/pages/dashboard.dart';

void main() {
  runApp(const GibbousApp());
}

class GibbousApp extends StatelessWidget {
  const GibbousApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GIBBOUS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        textTheme: GoogleFonts.montserratTextTheme(),
      ),
      home: const AppStartup(),
    );
  }
}

class AppStartup extends StatefulWidget {
  const AppStartup({super.key});

  @override
  State<AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends State<AppStartup> {
  @override
  void initState() {
    super.initState();
    _checkUser();
  }

  Future<void> _checkUser() async {
    final profile = await ProfileService().loadProfile();
    if (!mounted) return;

    if (profile.isNotEmpty) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardPage()));
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const OnboardingPage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(child: CircularProgressIndicator(color: Color(0xFFD4A843))),
    );
  }
}