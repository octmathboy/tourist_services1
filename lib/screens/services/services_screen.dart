import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_strings.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  // Dynamic user coordinates
  double? userLat;
  double? userLng;
  bool _isLoadingLocation = true;

  @override
  void initState() {
    super.initState();
    _initUserLocation();
  }

  /// Request location access and get coordinates
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

  void _showImagePreview(BuildContext context, String imageUrl) {
    if (imageUrl.isEmpty) return;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.broken_image, size: 80),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
          ],
        ),
      ),
    );
  }

  void _showServicesBottomSheet(
      BuildContext context, String categoryTitle, String categoryKey) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[100],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, controller) {
            return Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    categoryTitle,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('services')
                          .where('category', isEqualTo: categoryKey)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Center(
                            child: Text(
                              "No services available in this category.",
                              style: TextStyle(fontSize: 16),
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
                              "No services within 50 km.",
                              style: TextStyle(fontSize: 16),
                            ),
                          );
                        }

                        return ListView.builder(
                          controller: controller,
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final data =
                                docs[index].data() as Map<String, dynamic>;

                            final String name =
                                data['name'] ?? 'Unnamed Service';
                            final String address = data['address'] ?? '';
                            final String phone = data['phone'] ?? '';
                            final String description =
                                data['description'] ?? '';
                            final double lat =
                                (data['lat'] as num?)?.toDouble() ?? 0.0;
                            final double lng =
                                (data['lng'] as num?)?.toDouble() ?? 0.0;

                            final List images = data['images'] ?? [];
                            final String primaryImg =
                                images.isNotEmpty ? images[0] : '';
                            final String secondaryImg =
                                images.length > 1 ? images[1] : '';
                            final String tertiaryImg =
                                images.length > 2 ? images[2] : '';

                            final distKm = _calculateDistanceKm(lat, lng);

                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              elevation: 2,
                              child: Padding(
                                padding: const EdgeInsets.all(14.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    if (primaryImg.isNotEmpty)
                                      SizedBox(
                                        height: 180,
                                        child: Row(
                                          children: [
                                            Expanded(
                                              flex: 3,
                                              child: GestureDetector(
                                                onTap: () => _showImagePreview(
                                                    context, primaryImg),
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  child: Image.network(
                                                    primaryImg,
                                                    height: double.infinity,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (c, e, s) =>
                                                        Container(
                                                      color: Colors.grey[300],
                                                      child: const Icon(
                                                          Icons.broken_image),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            if (secondaryImg.isNotEmpty ||
                                                tertiaryImg.isNotEmpty)
                                              const SizedBox(width: 8),
                                            if (secondaryImg.isNotEmpty ||
                                                tertiaryImg.isNotEmpty)
                                              Expanded(
                                                flex: 2,
                                                child: Column(
                                                  children: [
                                                    if (secondaryImg.isNotEmpty)
                                                      Expanded(
                                                        child: GestureDetector(
                                                          onTap: () =>
                                                              _showImagePreview(
                                                                  context,
                                                                  secondaryImg),
                                                          child: ClipRRect(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        10),
                                                            child:
                                                                Image.network(
                                                              secondaryImg,
                                                              width: double
                                                                  .infinity,
                                                              fit: BoxFit.cover,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    if (secondaryImg
                                                            .isNotEmpty &&
                                                        tertiaryImg.isNotEmpty)
                                                      const SizedBox(height: 6),
                                                    if (tertiaryImg.isNotEmpty)
                                                      Expanded(
                                                        child: GestureDetector(
                                                          onTap: () =>
                                                              _showImagePreview(
                                                                  context,
                                                                  tertiaryImg),
                                                          child: ClipRRect(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        10),
                                                            child:
                                                                Image.network(
                                                              tertiaryImg,
                                                              width: double
                                                                  .infinity,
                                                              fit: BoxFit.cover,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    const SizedBox(height: 12),
                                    if (description.isNotEmpty)
                                      Text(
                                        description,
                                        style: TextStyle(
                                            color: Colors.grey[800],
                                            fontSize: 14),
                                      ),
                                    const SizedBox(height: 6),
                                    Text(
                                        userLat != null
                                            ? "📍 $address (${distKm.toStringAsFixed(1)} km away)"
                                            : "📍 $address",
                                        style: TextStyle(
                                            color: Colors.grey[700],
                                            fontSize: 13)),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        if (phone.isNotEmpty)
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              onPressed: () =>
                                                  _makePhoneCall(phone),
                                              icon: const Icon(Icons.phone),
                                              label: const Text("Call"),
                                            ),
                                          ),
                                        if (phone.isNotEmpty)
                                          const SizedBox(width: 10),
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: () =>
                                                _openMapLocation(lat, lng),
                                            icon: const Icon(Icons.directions),
                                            label: const Text("Location"),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.teal,
                                              foregroundColor: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
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
            );
          },
        );
      },
    );
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
                AppStrings.servicesTitle,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                AppStrings.servicesSubtitle,
                style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: [
                    _buildServiceCard(
                      context,
                      title: AppStrings.serviceTransport,
                      icon: Icons.directions_car,
                      color: Colors.orange,
                      onTap: () {
                        _showServicesBottomSheet(
                          context,
                          AppStrings.serviceTransport,
                          'taxi',
                        );
                      },
                    ),
                    _buildServiceCard(
                      context,
                      title: AppStrings.serviceHotels,
                      icon: Icons.hotel,
                      color: Colors.blue,
                      onTap: () {
                        _showServicesBottomSheet(
                          context,
                          AppStrings.serviceHotels,
                          'hotel',
                        );
                      },
                    ),
                    _buildServiceCard(
                      context,
                      title: AppStrings.serviceRestaurants,
                      icon: Icons.restaurant,
                      color: Colors.green,
                      onTap: () {
                        _showServicesBottomSheet(
                          context,
                          AppStrings.serviceRestaurants,
                          'restaurant',
                        );
                      },
                    ),
                    _buildServiceCard(
                      context,
                      title: AppStrings.serviceGuides,
                      icon: Icons.person_search,
                      color: Colors.purple,
                      onTap: () {
                        _showServicesBottomSheet(
                          context,
                          AppStrings.serviceGuides,
                          'guide',
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServiceCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.12),
                radius: 30,
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
