import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_strings.dart';

class ToursScreen extends StatefulWidget {
  const ToursScreen({super.key});

  @override
  State<ToursScreen> createState() => _ToursScreenState();
}

class _ToursScreenState extends State<ToursScreen> {
  // Dynamic user coordinates
  double? userLat;
  double? userLng;
  bool _isLoadingLocation = true;

  @override
  void initState() {
    super.initState();
    _initUserLocation();
  }

  /// Fetch user location dynamically
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

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  Future<void> _openMapLocation(double lat, double lng) async {
    final Uri googleMapsUrl =
        Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng");
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              const Text(
                AppStrings.toursTitle,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                "Explore available tours & excursions published on web",
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('services')
                      .where('category',
                          whereIn: ['tour', 'guide', 'taxi']).snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.teal),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text(
                          "No tours or excursion guides available yet.",
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      );
                    }

                    final rawDocs = snapshot.data!.docs;

                    // Filter: distance <= 50 km
                    final docs = rawDocs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final double lat =
                          (data['lat'] as num?)?.toDouble() ?? 0.0;
                      final double lng =
                          (data['lng'] as num?)?.toDouble() ?? 0.0;
                      return userLat == null ||
                          _calculateDistanceKm(lat, lng) <= 50.0;
                    }).toList();

                    // Sort: nearest to farthest
                    docs.sort((a, b) {
                      final dataA = a.data() as Map<String, dynamic>;
                      final dataB = b.data() as Map<String, dynamic>;
                      final double latA =
                          (dataA['lat'] as num?)?.toDouble() ?? 0.0;
                      final double lngA =
                          (dataA['lng'] as num?)?.toDouble() ?? 0.0;
                      final double latB =
                          (dataB['lat'] as num?)?.toDouble() ?? 0.0;
                      final double lngB =
                          (dataB['lng'] as num?)?.toDouble() ?? 0.0;

                      return _calculateDistanceKm(latA, lngA)
                          .compareTo(_calculateDistanceKm(latB, lngB));
                    });

                    if (docs.isEmpty) {
                      return const Center(
                        child: Text(
                          "No tours available within 50 km.",
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;

                        final String name = data['name'] ?? 'Guided Tour';
                        final String address = data['address'] ?? '';
                        final String phone = data['phone'] ?? '';
                        final String description = data['description'] ?? '';
                        final double lat =
                            (data['lat'] as num?)?.toDouble() ?? 0.0;
                        final double lng =
                            (data['lng'] as num?)?.toDouble() ?? 0.0;
                        final double rating =
                            (data['rating'] as num?)?.toDouble() ?? 4.9;

                        final List images = data['images'] ?? [];
                        final String primaryImg =
                            images.isNotEmpty ? images[0] : '';

                        final distKm = _calculateDistanceKm(lat, lng);

                        return Card(
                          elevation: 3,
                          margin: const EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: primaryImg.isNotEmpty
                                          ? Image.network(
                                              primaryImg,
                                              width: 60,
                                              height: 60,
                                              fit: BoxFit.cover,
                                              errorBuilder: (c, e, s) =>
                                                  Container(
                                                width: 60,
                                                height: 60,
                                                color: Colors.teal.shade100,
                                                child: const Icon(Icons.explore,
                                                    color: Colors.teal),
                                              ),
                                            )
                                          : Container(
                                              width: 60,
                                              height: 60,
                                              color: Colors.teal.shade100,
                                              child: const Icon(Icons.explore,
                                                  color: Colors.teal),
                                            ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: const TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              const Icon(Icons.place,
                                                  size: 14, color: Colors.grey),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  userLat != null
                                                      ? "$address (${distKm.toStringAsFixed(1)} km)"
                                                      : address,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                      color: Colors.grey,
                                                      fontSize: 13),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.star,
                                              size: 14, color: Colors.amber),
                                          const SizedBox(width: 2),
                                          Text(
                                            rating.toString(),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.amber.shade900,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (description.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    description,
                                    style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 14),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (phone.isNotEmpty)
                                      OutlinedButton.icon(
                                        onPressed: () => _makePhoneCall(phone),
                                        icon: const Icon(Icons.phone),
                                        label: const Text("Call Guide"),
                                      ),
                                    if (phone.isNotEmpty)
                                      const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      onPressed: () =>
                                          _openMapLocation(lat, lng),
                                      icon: const Icon(Icons.map),
                                      label: const Text("Location"),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.teal,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
