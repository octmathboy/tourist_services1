import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import '../../constants/app_colors.dart';

class WorshipScreen extends StatefulWidget {
  const WorshipScreen({super.key});

  @override
  State<WorshipScreen> createState() => _WorshipScreenState();
}

class _WorshipScreenState extends State<WorshipScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';

  // Dynamic user coordinates
  double? userLat;
  double? userLng;
  bool _isLoadingLocation = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initUserLocation();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Request permission and fetch live device location
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

  /// Calculate distance in kilometers using real coordinates
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.network(imageUrl, fit: BoxFit.cover),
        ),
      ),
    );
  }

  Widget _buildWorshipList(String type) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('services')
          .where('category', isEqualTo: 'worship')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Something went wrong'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final rawDocs = snapshot.data?.docs ?? [];

        // 1. Filter by tab type, search query, and distance <= 50 km
        final filteredDocs = rawDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final String name = (data['name'] ?? '').toString().toLowerCase();
          final String address =
              (data['address'] ?? '').toString().toLowerCase();
          final String subcategory =
              (data['subcategory'] ?? '').toString().toLowerCase();
          final double lat = (data['lat'] as num?)?.toDouble() ?? 0.0;
          final double lng = (data['lng'] as num?)?.toDouble() ?? 0.0;

          bool matchesType = false;
          if (type == 'islamic') {
            matchesType = subcategory == 'islamic' ||
                name.contains('mosque') ||
                name.contains('masjid') ||
                address.contains('mosque') ||
                address.contains('masjid') ||
                (!subcategory.contains('christian') &&
                    !name.contains('church'));
          } else {
            matchesType = subcategory == 'christian' ||
                name.contains('church') ||
                name.contains('cathedral') ||
                address.contains('church');
          }

          bool matchesSearch = _searchQuery.isEmpty ||
              name.contains(_searchQuery) ||
              address.contains(_searchQuery);

          double dist = _calculateDistanceKm(lat, lng);

          // If location isn't fetched yet or within 50km
          bool isWithinRange = (userLat == null) ? true : (dist <= 50.0);

          return matchesType && matchesSearch && isWithinRange;
        }).toList();

        // 2. Sort from nearest to farthest
        filteredDocs.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;
          final double latA = (dataA['lat'] as num?)?.toDouble() ?? 0.0;
          final double lngA = (dataA['lng'] as num?)?.toDouble() ?? 0.0;
          final double latB = (dataB['lat'] as num?)?.toDouble() ?? 0.0;
          final double lngB = (dataB['lng'] as num?)?.toDouble() ?? 0.0;

          return _calculateDistanceKm(latA, lngA)
              .compareTo(_calculateDistanceKm(latB, lngB));
        });

        if (filteredDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  type == 'islamic' ? Icons.mosque : Icons.church,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 12),
                Text(
                  type == 'islamic'
                      ? 'No Islamic places within 50km.'
                      : 'No Christian places within 50km.',
                  style: const TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final data = filteredDocs[index].data() as Map<String, dynamic>;

            final String name =
                data['name'] ?? (type == 'islamic' ? 'Mosque' : 'Church');
            final String phone = data['phone'] ?? '';
            final String address = data['address'] ?? '';
            final double lat = (data['lat'] as num?)?.toDouble() ?? 0.0;
            final double lng = (data['lng'] as num?)?.toDouble() ?? 0.0;
            final List<dynamic> images = data['images'] ?? [];
            final String mainImage = images.isNotEmpty ? images.first : '';

            final double distKm = _calculateDistanceKm(lat, lng);

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () => _showImagePreview(context, mainImage),
                          child: Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: type == 'islamic'
                                  ? Colors.teal[50]
                                  : Colors.blue[50],
                              borderRadius: BorderRadius.circular(12),
                              image: mainImage.isNotEmpty
                                  ? DecorationImage(
                                      image: NetworkImage(mainImage),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: mainImage.isEmpty
                                ? Icon(
                                    type == 'islamic'
                                        ? Icons.mosque
                                        : Icons.church,
                                    color: type == 'islamic'
                                        ? Colors.teal
                                        : Colors.blue,
                                    size: 36,
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (address.isNotEmpty)
                                Text(
                                  address,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 13,
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Text(
                                userLat != null
                                    ? "📍 ${distKm.toStringAsFixed(1)} km away"
                                    : "📍 Location unknown",
                                style: const TextStyle(
                                  color: Colors.teal,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (phone.isNotEmpty) ...[
                          OutlinedButton.icon(
                            onPressed: () => _makePhoneCall(phone),
                            icon: const Icon(Icons.phone, size: 16),
                            label: const Text('Call'),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (lat != 0.0 && lng != 0.0) ...[
                          ElevatedButton.icon(
                            onPressed: () => _openMapLocation(lat, lng),
                            icon: const Icon(
                              Icons.directions,
                              size: 16,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'Navigate',
                              style: TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
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
      appBar: AppBar(
        title: const Text(
          'Places of Worship',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.mosque), text: 'Islamic'),
            Tab(icon: Icon(Icons.church), text: 'Christian'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search place or address...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildWorshipList('islamic'),
                _buildWorshipList('christian'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
