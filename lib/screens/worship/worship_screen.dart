import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Phone dialer launcher
  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  // Google Maps navigation launcher
  Future<void> _openMapLocation(double lat, double lng) async {
    final Uri googleMapsUrl =
        Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng");
    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    }
  }

  // Image preview modal
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

        final docs = snapshot.data?.docs ?? [];

        // Filter by tab type (Islamic vs Christian) and search query
        final filteredDocs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final String name = (data['name'] ?? '').toString().toLowerCase();
          final String address =
              (data['address'] ?? '').toString().toLowerCase();
          final String subcategory =
              (data['subcategory'] ?? '').toString().toLowerCase();

          // Check tab type matching
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

          // Search query matching
          bool matchesSearch = _searchQuery.isEmpty ||
              name.contains(_searchQuery) ||
              address.contains(_searchQuery);

          return matchesType && matchesSearch;
        }).toList();

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
                      ? 'No Islamic places found.'
                      : 'No Christian places found.',
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
            final double? lat = (data['lat'] as num?)?.toDouble();
            final double? lng = (data['lng'] as num?)?.toDouble();
            final List<dynamic> images = data['images'] ?? [];
            final String mainImage = images.isNotEmpty ? images.first : '';

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
                        // Image / Icon Thumbnail
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

                        // Title & Details
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
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),

                    // Actions (Call & Navigate)
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
                        if (lat != null && lng != null) ...[
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
          // Search Input Bar
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

          // Tab Views
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
