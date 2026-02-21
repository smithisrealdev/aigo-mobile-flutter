class Destination {
  final String id;
  final String name;
  final String location;
  final String imageUrl;
  final double rating;
  final String? description;
  final bool saved;

  const Destination({
    required this.id,
    required this.name,
    required this.location,
    required this.imageUrl,
    this.rating = 4.5,
    this.description,
    this.saved = false,
  });
}

class Trip {
  final String id;
  final String destination;
  final String imageUrl;
  final DateTime startDate;
  final DateTime endDate;
  final String status;

  const Trip({
    required this.id,
    required this.destination,
    required this.imageUrl,
    required this.startDate,
    required this.endDate,
    this.status = 'upcoming',
  });
}
