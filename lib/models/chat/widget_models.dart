enum CollapsibleType { day, restaurant, transport, accommodation, details }

class CollapsibleSection {
  final String id;
  final String title;
  final String content;
  final CollapsibleType type;

  const CollapsibleSection({
    required this.id,
    required this.title,
    required this.content,
    required this.type,
  });
}

class FlightInfo {
  final String airline;
  final String iataCode;
  final String from;
  final String to;
  final String departure;
  final String arrival;
  final String duration;
  final String price;
  final String type; // direct, 1 stop, return, outbound
  final String? searchUrl;

  const FlightInfo({
    required this.airline,
    required this.iataCode,
    required this.from,
    required this.to,
    required this.departure,
    required this.arrival,
    required this.duration,
    required this.price,
    required this.type,
    this.searchUrl,
  });
}

class HotelInfo {
  final String name;
  final String area;
  final String rating;
  final String price;
  final bool perNight;
  final List<String> highlights;
  final String? searchUrl;
  final String? imageUrl;
  final String? bookingUrl;

  const HotelInfo({
    required this.name,
    required this.area,
    required this.rating,
    required this.price,
    this.perNight = true,
    this.highlights = const [],
    this.searchUrl,
    this.imageUrl,
    this.bookingUrl,
  });
}

class ServiceInfo {
  final String name;
  final String type;
  final String description;
  final String price;
  final String url;
  final String provider;

  const ServiceInfo({
    required this.name,
    required this.type,
    required this.description,
    required this.price,
    required this.url,
    required this.provider,
  });
}

class TicketInfo {
  final String name;
  final String city;
  final String category;
  final String price;
  final String description;
  final String url;

  const TicketInfo({
    required this.name,
    required this.city,
    required this.category,
    required this.price,
    required this.description,
    required this.url,
  });
}

class BudgetSummaryInfo {
  final String rawBlock;

  const BudgetSummaryInfo(this.rawBlock);
}

class ParsedWidgets {
  final List<FlightInfo> flights;
  final List<HotelInfo> hotels;
  final List<ServiceInfo> services;
  final List<TicketInfo> tickets;
  final BudgetSummaryInfo? budgetSummary;
  final List<CollapsibleSection> collapsibleSections;
  final String cleanText;

  const ParsedWidgets({
    this.flights = const [],
    this.hotels = const [],
    this.services = const [],
    this.tickets = const [],
    this.budgetSummary,
    this.collapsibleSections = const [],
    required this.cleanText,
  });
}
