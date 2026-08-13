import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';

import 'services/services_screen.dart';
import 'maps/maps_screen.dart';
import 'places/places_screen.dart';
import 'worship/worship_screen.dart';
import 'ai_agent/ai_chat_screen.dart';
import 'tours/tours_screen.dart';
import 'emergency/emergency_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 3; // Default screen: AI Assistant

  void _changeLanguage(String langCode) {
    setState(() {
      AppStrings.currentLanguage = langCode;
    });
  }

  // Updated List of Screens including PlacesScreen
  final List<Widget> _pages = const [
    ServicesScreen(),
    MapsScreen(),
    PlacesScreen(), // 🏛️ New Tourist Places Screen
    AiChatScreen(),
    ToursScreen(),
    EmergencyScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    bool isRtl = AppStrings.currentLanguage == 'ar';

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(AppStrings.getText('appName')),
          backgroundColor: AppColors.primaryColor,
          foregroundColor: Colors.white,
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.language),
              onSelected: _changeLanguage,
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'ar', child: Text('العربية 🇩🇿')),
                PopupMenuItem(value: 'en', child: Text('English 🇬🇧')),
                PopupMenuItem(value: 'fr', child: Text('Français 🇫🇷')),
                PopupMenuItem(value: 'es', child: Text('Español 🇪🇸')),
              ],
            ),
          ],
        ),
        body: IndexedStack(
          index: _selectedIndex,
          children: _pages,
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppColors.primaryColor,
          unselectedItemColor: AppColors.textSecondary,
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.room_service),
              label: AppStrings.getText('tabServices'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.map_outlined),
              label: AppStrings.getText('tabMaps'),
            ),
            const BottomNavigationBarItem(
              icon: const Icon(Icons.place),
              label: AppStrings.getText('tabPlaces'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.auto_awesome),
              label: AppStrings.getText('tabAiAgent'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.mosque),
              label: AppStrings.getText('tabWorship'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.explore),
              label: AppStrings.getText('tabTours'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.emergency),
              label: AppStrings.getText('tabEmergency'),
            ),
          ],
        ),
      ),
    );
  }
}
