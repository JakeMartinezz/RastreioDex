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

  factory TrackingEvent.fromMap(Map<String, dynamic> map) {
    return TrackingEvent(
      status: map['status'] ?? '',
      description: map['description'] ?? '',
      location: map['location'] ?? '',
      dateTime: map['dateTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['dateTime'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'status': status,
      'description': description,
      'location': location,
      'dateTime': dateTime.millisecondsSinceEpoch,
    };
  }
}
