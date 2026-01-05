class TrackingEvent {
  final String status;
  final String description;
  final String location;
  final DateTime dateTime;

  TrackingEvent({
    required this.status,
    required this.description,
    required this.location,
    required this.dateTime,
  });

  factory TrackingEvent.fromJson(Map<String, dynamic> json) {
    return TrackingEvent(
      status: json['status'] ?? '',
      description: json['description'] ?? '',
      location: json['location'] ?? '',
      dateTime: json['dateTime'] != null
          ? DateTime.parse(json['dateTime'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'description': description,
      'location': location,
      'dateTime': dateTime.toIso8601String(),
    };
  }
}
