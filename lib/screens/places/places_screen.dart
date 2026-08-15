import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import '../../constants/app_colors.dart';

class PlacesScreen extends StatefulWidget {
  const PlacesScreen({super.key});

  @override
  State<PlacesScreen> createState() => _PlacesScreenState();
}

class _PlacesScreenState extends State<PlacesScreen> {
  // Dynamic user coordinates
  double? userLat;
  double? userLng;
  bool _isLoadingLocation = true;

  @override
  void initState() {
    super.initState();
    _initUserLocation();
  }

  /// Get active user GPS location
  Future<void> _initUserLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() => _isLoadingLocation = false);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) setState(() => _isLoadingLocation = false);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) setState(() => _isLoadingLocation = false);
      return;
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    if (mounted) {
      setState(() {
        userLat = position.latitude;
        userLng = position.longitude;
        _isLoadingLocation = false;
      });
    }
  }

  /// Calculate distance in kilometers
  double _calculateDistanceKm(double lat2, double lng2) {
    if (userLat == null || userLng == null || (lat2 == 0.0 && lng2 == 0.0)) {
      return 0.0;
    }
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 -
        c((lat2 - userLat!) * p) / 2 +
        c(userLat! * p) * c(lat2 * p) * (1 - c((lng2 - userLng!) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  /// Calculate distance in miles
  double _calculateDistanceMiles(double distanceKm) {
    return distanceKm * 0.621371;
  }

  Future<void> _openMapDirections(double lat, double lng) async {
    final Uri googleMapsUrl = Uri.parse(
        "https://www.google.com/maps/dir/?api=1&destination=$lat,$lng");
    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingLocation) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Colors.teal),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Tourist Places & Landmarks"),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('services')
            .where('category', isEqualTo: 'place')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.teal),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "No places published yet from web portal.",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          final rawDocs = snapshot.data!.docs;

          // Filter: distance <= 50 km
          final docs = rawDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final double lat = (data['lat'] as num?)?.toDouble() ?? 0.0;
            final double lng = (data['lng'] as num?)?.toDouble() ?? 0.0;
            return userLat == null || _calculateDistanceKm(lat, lng) <= 50.0;
          }).toList();

          // Sort: nearest to farthest
          docs.sort((a, b) {
            final dataA = a.data() as Map<String, dynamic>;
            final dataB = b.data() as Map<String, dynamic>;
            final double latA = (dataA['lat'] as num?)?.toDouble() ?? 0.0;
            final double lngA = (dataA['lng'] as num?)?.toDouble() ?? 0.0;
            final double latB = (dataB['lat'] as num?)?.toDouble() ?? 0.0;
            final double lngB = (dataB['lng'] as num?)?.toDouble() ?? 0.0;

            return _calculateDistanceKm(latA, lngA)
                .compareTo(_calculateDistanceKm(latB, lngB));
          });

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                "No places available within 50 km.",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;

              final String name = data['name'] ?? 'Landmark';
              final String address = data['address'] ?? '';
              final String description = data['description'] ?? '';
              final double lat = (data['lat'] as num?)?.toDouble() ?? 0.0;
              final double lng = (data['lng'] as num?)?.toDouble() ?? 0.0;
              final double rating = (data['rating'] as num?)?.toDouble() ?? 4.8;

              final List images = data['images'] ?? [];
              final String primaryImg = images.isNotEmpty ? images[0] : '';

              final distKm = _calculateDistanceKm(lat, lng);
              final distMiles = _calculateDistanceMiles(distKm);

              return Card(
                margin: const EdgeInsets.only(bottom: 20),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        primaryImg.isNotEmpty
                            ? Image.network(
                                primaryImg,
                                height: 190,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                  height: 190,
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.photo,
                                      size: 50, color: Colors.grey),
                                ),
                              )
                            : Container(
                                height: 190,
                                color: Colors.grey[300],
                                child: const Icon(Icons.place,
                                    size: 50, color: Colors.grey),
                              ),
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.75),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.star,
                                    color: Colors.amber, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  '$rating',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "📍 $address",
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 12),
                          if (userLat != null && lat != 0.0 && lng != 0.0)
                            Row(
                              children: [
                                Chip(
                                  avatar: const Icon(Icons.navigation,
                                      size: 16, color: Colors.blue),
                                  label: Text(
                                    '${distKm.toStringAsFixed(1)} km',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  backgroundColor: Colors.blue.shade50,
                                ),
                                const SizedBox(width: 8),
                                Chip(
                                  avatar: const Icon(Icons.straighten,
                                      size: 16, color: Colors.purple),
                                  label: Text(
                                    '${distMiles.toStringAsFixed(1)} miles',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  backgroundColor: Colors.purple.shade50,
                                ),
                              ],
                            ),
                          if (userLat != null && lat != 0.0 && lng != 0.0)
                            const SizedBox(height: 12),
                          if (description.isNotEmpty)
                            Text(
                              description,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                                height: 1.3,
                              ),
                            ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _openMapDirections(lat, lng),
                              icon: const Icon(Icons.directions),
                              label: const Text("Get Directions"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
