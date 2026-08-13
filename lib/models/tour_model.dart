class TourModel {
  final String id;
  final String title;
  final String city;
  final String duration;
  final double priceDzd;
  final double rating;
  final String imageUrl;
  final List<String> highlights;
  final String description;

  TourModel({
    required this.id,
    required this.title,
    required this.city,
    required this.duration,
    required this.priceDzd,
    required this.rating,
    required this.imageUrl,
    required this.highlights,
    required this.description,
  });

  factory TourModel.fromJson(Map<String, dynamic> json) {
    return TourModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      city: json['city'] ?? '',
      duration: json['duration'] ?? '',
      priceDzd: (json['priceDzd'] ?? 0).toDouble(),
      rating: (json['rating'] ?? 0.0).toDouble(),
      imageUrl: json['imageUrl'] ?? '',
      highlights: List<String>.from(json['highlights'] ?? []),
      description: json['description'] ?? '',
    );
  }
}