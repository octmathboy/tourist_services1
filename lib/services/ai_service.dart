import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AIService {
  // 🔑 Groq API Key
  static const String _groqApiKey = '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';
  static const String _groqUrl = 'https://api.groq.com/openai/v1/chat/completions';
  
  // 🗺️ Google Maps API Key
  static const String _googlePlacesApiKey = 'AIzaSyBU0BZeORfj2mNcARrUc4IfYZUm0zQggiA';

  String currentCity = "Oran";
  final List<Map<String, String>> _messages = [];

  Future<void> initLocation() async {
    currentCity = "Oran";
  }

  Future<void> initChatSession() async {
    await initLocation();
    _messages.clear();
    _messages.add({
      "role": "system",
      "content": "You are a travel assistant for tourist_services1 in $currentCity. ALWAYS respond in English."
    });
  }

  Future<String> sendMessage(String userMessage) async {
    if (_messages.isEmpty) await initChatSession();
    _messages.add({"role": "user", "content": userMessage});

    try {
      final response = await http.post(
        Uri.parse(_groqUrl),
        headers: {
          'Authorization': 'Bearer $_groqApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "model": "llama-3.1-8b-instant",
          "messages": _messages,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        String reply = data['choices'][0]['message']['content'];
        _messages.add({"role": "assistant", "content": reply});
        return reply;
      }
    } catch (e) {
      debugPrint("Chat error: $e");
    }
    return "Something went wrong.";
  }

  /// 🎯 Fetch Tour Packages (AI Prompt)
  Future<List<Map<String, dynamic>>> fetchToursFromAI([String? city]) async {
    String targetCity = (city != null && city.isNotEmpty) ? city : currentCity;
    String prompt = """
Provide 3 realistic tour packages for tourists in $targetCity, Algeria.
Respond ONLY in English with a valid JSON array. No markdown tags.
[
  {
    "title": "Tour Title",
    "location": "$targetCity",
    "duration": "1 Day",
    "price": "4,500 DZD",
    "rating": "4.8",
    "description": "Tour description here."
  }
]
""";

    try {
      final response = await http.post(
        Uri.parse(_groqUrl),
        headers: {
          'Authorization': 'Bearer $_groqApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "model": "llama-3.1-8b-instant",
          "messages": [{"role": "user", "content": prompt}],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        String rawContent = data['choices'][0]['message']['content'] ?? '[]';
        rawContent = rawContent.replaceAll('```json', '').replaceAll('```', '').trim();
        return List<Map<String, dynamic>>.from(jsonDecode(rawContent));
      }
    } catch (e) {
      debugPrint("Error fetching tours: $e");
    }
    return [];
  }

  /// 📍 REAL GPS & PHOTOS: Fetches directly from Google Places API
  Future<List<Map<String, dynamic>>> fetchServicesFromAI({
    required String city,
    required String category,
  }) async {
    String searchCity = city.isNotEmpty ? city : currentCity;

    if (_googlePlacesApiKey.isNotEmpty && _googlePlacesApiKey != 'ضع_مفتاح_الماب_الخاص_بك_هنا') {
      try {
        final realPlaces = await _fetchFromGooglePlaces(searchCity, category);
        if (realPlaces.isNotEmpty) return realPlaces;
      } catch (e) {
        debugPrint("Google Places API error, falling back to Groq: $e");
      }
    }

    return await _fetchFallbackGroqServices(searchCity, category);
  }

  /// 🌐 Live Google Places API HTTP Request
  Future<List<Map<String, dynamic>>> _fetchFromGooglePlaces(
      String city, String category) async {
    final String query = "$category in $city, Algeria";
    final Uri url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/textsearch/json?query=${Uri.encodeComponent(query)}&key=$_googlePlacesApiKey');

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List results = data['results'] ?? [];

      List<Map<String, dynamic>> places = [];
      for (var place in results.take(5)) {
        final photos = place['photos'] as List?;
        
        String getPhotoUrl(int index) {
          if (photos != null && photos.length > index) {
            String photoRef = photos[index]['photo_reference'];
            return 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photo_reference=$photoRef&key=$_googlePlacesApiKey';
          }
          return 'https://images.pexels.com/photos/1307698/pexels-photo-1307698.jpeg';
        }

        places.add({
          "name": place['name'] ?? 'Place Name',
          "address": place['formatted_address'] ?? '$city, Algeria',
          "phone": "+213000000000",
          "rating": (place['rating'] as num?)?.toDouble() ?? 4.5,
          "lat": place['geometry']['location']['lat'],
          "lng": place['geometry']['location']['lng'],
          "tag": category,
          "hours": place['opening_hours']?['open_now'] == true ? "Open Now" : "Check opening hours",
          "storefront_image": getPhotoUrl(0),
          "menu_image": getPhotoUrl(1),
          "food_image": getPhotoUrl(2),
          "highlights": [
            "User Rating: ${place['rating']} Stars on Google Maps",
            "Total Reviews: ${place['user_ratings_total'] ?? 'N/A'} Google reviewers",
            "Located at ${place['formatted_address']}"
          ]
        });
      }
      return places;
    }
    return [];
  }

  /// 🤖 Fallback JSON generator
  Future<List<Map<String, dynamic>>> _fetchFallbackGroqServices(
      String city, String category) async {
    String prompt = """
Provide 4 real places for $category in $city, Algeria.
Respond ONLY in English with a valid JSON array of objects.
[
  {
    "name": "Place Name",
    "address": "Neighborhood, $city",
    "phone": "+21341000000",
    "rating": 4.5,
    "lat": 35.6980,
    "lng": -0.6330,
    "tag": "$category",
    "hours": "Open 08:00 AM - 10:00 PM",
    "storefront_image": "https://images.pexels.com/photos/1307698/pexels-photo-1307698.jpeg",
    "menu_image": "https://images.pexels.com/photos/588776/pexels-photo-588776.jpeg",
    "food_image": "https://images.pexels.com/photos/205961/pexels-photo-205961.jpeg",
    "highlights": ["Recommended by locals", "Popular destination"]
  }
]
""";

    try {
      final response = await http.post(
        Uri.parse(_groqUrl),
        headers: {
          'Authorization': 'Bearer $_groqApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "model": "llama-3.1-8b-instant",
          "messages": [{"role": "user", "content": prompt}],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        String rawContent = data['choices'][0]['message']['content'] ?? '[]';
        rawContent = rawContent.replaceAll('```json', '').replaceAll('```', '').trim();
        return List<Map<String, dynamic>>.from(jsonDecode(rawContent));
      }
    } catch (e) {
      debugPrint("Fallback Groq API error: $e");
    }
    return [];
  }

  /// 🏛️ NEW METHOD: Fetch Tourist Attractions for PlacesScreen
  Future<List<Map<String, dynamic>>> fetchTouristPlacesFromAI({
    required String city,
  }) async {
    String searchCity = city.isNotEmpty ? city : currentCity;

    if (_googlePlacesApiKey.isNotEmpty) {
      try {
        final String query = "top tourist attractions historical places landmarks in $searchCity, Algeria";
        final Uri url = Uri.parse(
            'https://maps.googleapis.com/maps/api/place/textsearch/json?query=${Uri.encodeComponent(query)}&key=$_googlePlacesApiKey');

        final response = await http.get(url);
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final List results = data['results'] ?? [];

          List<Map<String, dynamic>> places = [];
          for (var place in results.take(6)) {
            final photos = place['photos'] as List?;
            String photoUrl = 'https://images.pexels.com/photos/1457812/pexels-photo-1457812.jpeg';
            if (photos != null && photos.isNotEmpty) {
              String photoRef = photos[0]['photo_reference'];
              photoUrl =
                  'https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photo_reference=$photoRef&key=$_googlePlacesApiKey';
            }

            places.add({
              "name": place['name'] ?? 'Landmark',
              "address": place['formatted_address'] ?? '$searchCity, Algeria',
              "rating": (place['rating'] as num?)?.toDouble() ?? 4.7,
              "lat": place['geometry']['location']['lat'],
              "lng": place['geometry']['location']['lng'],
              "image": photoUrl,
              "description":
                  "A major landmark in $searchCity. Rated ${place['rating']} stars with over ${place['user_ratings_total'] ?? 'hundreds of'} Google reviews.",
            });
          }
          if (places.isNotEmpty) return places;
        }
      } catch (e) {
        debugPrint("Google Places API error (Places Screen): $e");
      }
    }

    // Fallback Groq Prompt
    String prompt = """
Provide 5 famous tourist attractions in $searchCity, Algeria.
Respond ONLY in English with a valid JSON array of objects. No markdown tags.
[
  {
    "name": "Attraction Name",
    "address": "Location, $searchCity",
    "rating": 4.8,
    "lat": 35.7000,
    "lng": -0.6300,
    "image": "https://images.pexels.com/photos/1457812/pexels-photo-1457812.jpeg",
    "description": "Historical explanation and details of this landmark."
  }
]
""";

    try {
      final response = await http.post(
        Uri.parse(_groqUrl),
        headers: {
          'Authorization': 'Bearer $_groqApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "model": "llama-3.1-8b-instant",
          "messages": [{"role": "user", "content": prompt}],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        String rawContent = data['choices'][0]['message']['content'] ?? '[]';
        rawContent = rawContent.replaceAll('```json', '').replaceAll('```', '').trim();
        return List<Map<String, dynamic>>.from(jsonDecode(rawContent));
      }
    } catch (e) {
      debugPrint("Groq API Error fetching tourist places: $e");
    }
    return [];
  }
}