import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'constants/app_strings.dart';
import 'screens/services/services_screen.dart';
import 'screens/emergency/emergency_screen.dart';
import 'screens/ai_agent/ai_chat_screen.dart';
import 'screens/maps/maps_screen.dart';
import 'screens/tours/tours_screen.dart';
import 'screens/places/places_screen.dart';
import 'screens/worship/worship_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with Web Options configuration
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyAMpi80yJqhAeU2DKRdcpJccZn-VM0jTI0",
      appId: "1:996510101280:web:04a6d753c0efd88127f145",
      messagingSenderId: "996510101280",
      projectId: "tourism-app-b14df",
    ),
  );

  runApp(const TouristServicesApp());
}

class TouristServicesApp extends StatelessWidget {
  const TouristServicesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const MainNavigatorScreen(),
    );
  }
}

class MainNavigatorScreen extends StatefulWidget {
  const MainNavigatorScreen({super.key});

  @override
  State<MainNavigatorScreen> createState() => _MainNavigatorScreenState();
}

class _MainNavigatorScreenState extends State<MainNavigatorScreen> {
  int _currentIndex = 0; // Starts at Services screen

  final List<Widget> _screens = const [
    ServicesScreen(),
    MapsScreen(),
    PlacesScreen(),
    WorshipScreen(),
    AiChatScreen(),
    ToursScreen(),
    EmergencyScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.appName),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.teal,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.room_service),
            label: AppStrings.tabServices,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: AppStrings.tabMaps,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.place),
            label: AppStrings.tabPlaces,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.mosque),
            label: AppStrings.tabWorship,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.smart_toy),
            label: AppStrings.tabAiAgent,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.tour),
            label: AppStrings.tabTours,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.security),
            label: AppStrings.tabEmergency,
          ),
        ],
      ),
    );
  }
}
