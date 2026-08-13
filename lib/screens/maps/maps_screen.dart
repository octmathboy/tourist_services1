import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tourist_services1/services/ai_service.dart';
import 'package:url_launcher/url_launcher.dart';

class MapsScreen extends StatefulWidget {
  const MapsScreen({super.key});

  @override
  State<MapsScreen> createState() => _MapsScreenState();
}

class _MapsScreenState extends State<MapsScreen> {
  GoogleMapController? _mapController;
  final AIService _aiService = AIService();

  static const LatLng _initialPosition = LatLng(35.6971, -0.6308); // Oran default
  LatLng? _selectedLocation;
  Set<Marker> _markers = {};

  // Text-based State Variables
  String _placeName = "Tap any location on Google Maps";
  String _aiGeneratedText = "Select any point on the map below to receive a custom AI guide description about that area.";
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      LatLng userLatLng = LatLng(position.latitude, position.longitude);
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(userLatLng, 15));
    } catch (e) {
      debugPrint("GPS Location error: $e");
    }
  }

  Future<void> _openNavigation() async {
    if (_selectedLocation == null) return;
    final Uri googleMapsUrl = Uri.parse(
        "https://www.google.com/maps/dir/?api=1&destination=${_selectedLocation!.latitude},${_selectedLocation!.longitude}");
    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    }
  }

  /// Handle Map Tap & Fetch Pure Text Description from AI
  Future<void> _onMapTapped(LatLng position) async {
    setState(() {
      _selectedLocation = position;
      _isLoading = true;
      _placeName = "Locating spot...";
      _aiGeneratedText = "Generating detailed tourist guide text for this location...";
      _markers = {
        Marker(
          markerId: const MarkerId("selected_place"),
          position: position,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      };
    });

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      String formattedAddress = "Oran, Algeria";
      String rawName = "Selected Location";

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        rawName = place.name ?? place.street ?? "Selected Location";
        formattedAddress = "${place.street ?? ''}, ${place.subLocality ?? ''}, ${place.locality ?? ''}, ${place.country ?? ''}".trim();
      }

      String prompt = """
You are a knowledgeable tourist guide.
A user tapped on a location with these details:
Spot Name/Street: $rawName
Full Address: $formattedAddress
GPS Coordinates: ${position.latitude}, ${position.longitude}

Write a clear, engaging, and informative text paragraph describing this place or surrounding neighborhood. Highlight its significance, tourist appeal, nearby amenities, or tips for visitors. 
Requirements:
1. Respond ONLY in English.
2. Do NOT use tables, bullet points, or structured key-value formats.
3. Write as a continuous, natural text narrative.
4. Do NOT ask any questions or ask the user to respond.
""";

      String aiResponse = await _aiService.sendMessage(prompt);

      setState(() {
        _placeName = rawName;
        _aiGeneratedText = aiResponse.trim();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _placeName = "Selected Point";
        _aiGeneratedText = "This spot is located at coordinates (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}). Unable to load detailed AI insights at the moment.";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Explore Map & AI Insights"),
      ),
      body: Column(
        children: [
          // ----------------------------------------------------
          // 1/3 TOP SECTION: Pure Text Description Card
          // ----------------------------------------------------
          Expanded(
            flex: 1,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12.0),
              color: Colors.grey[100],
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 10),
                          Text(
                            "AI is crafting location details...",
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Spot Title & Navigation Button Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  _placeName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.indigo,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (_selectedLocation != null)
                                ElevatedButton.icon(
                                  onPressed: _openNavigation,
                                  icon: const Icon(Icons.directions, size: 16),
                                  label: const Text("Directions", style: TextStyle(fontSize: 12)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blueAccent,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Full AI Text Narrative
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12.0),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 5,
                                  offset: const Offset(0, 2),
                                )
                              ],
                            ),
                            child: Text(
                              _aiGeneratedText,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.5,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),

          // ----------------------------------------------------
          // 2/3 BOTTOM SECTION: Google Maps View
          // ----------------------------------------------------
          Expanded(
            flex: 2,
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: _initialPosition,
                zoom: 14.0,
              ),
              onMapCreated: (controller) => _mapController = controller,
              onTap: _onMapTapped,
              markers: _markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: true,
            ),
          ),
        ],
      ),
    );
  }
}