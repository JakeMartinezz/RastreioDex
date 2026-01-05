import 'tracking_event.dart';

class Package {
  final String id;
  final String trackingCode;
  final String? customName;
  final String type;
  final List<TrackingEvent> events;
  final DateTime addedAt;
  final DateTime? lastUpdate;
  final String currentStatus;
  final int orderIndex;

  Package({
    required this.id,
    required this.trackingCode,
    this.customName,
    required this.type,
    required this.events,
    required this.addedAt,
    this.lastUpdate,
    required this.currentStatus,
    this.orderIndex = 0, // Valor padrão
  });

  factory Package.fromJson(Map<String, dynamic> json) {
    return Package(
      id: json['id'] ?? '',
      trackingCode: json['trackingCode'] ?? '',
      customName: json['customName'],
      type: json['type'] ?? 'SEDEX',
      events: (json['events'] as List<dynamic>?)
              ?.map((e) => TrackingEvent.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      addedAt: json['addedAt'] != null
          ? DateTime.parse(json['addedAt'])
          : DateTime.now(),
      lastUpdate: json['lastUpdate'] != null
          ? DateTime.parse(json['lastUpdate'])
          : null,
      currentStatus: json['currentStatus'] ?? 'Aguardando rastreamento',
      orderIndex: json['orderIndex'] ?? 0, // <--- LÊ O INDEX
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'trackingCode': trackingCode,
      'customName': customName,
      'type': type,
      'events': events.map((e) => e.toJson()).toList(),
      'addedAt': addedAt.toIso8601String(),
      'lastUpdate': lastUpdate?.toIso8601String(),
      'currentStatus': currentStatus,
      'orderIndex': orderIndex, // <--- SALVA O INDEX
    };
  }

  Package copyWith({
    String? id,
    String? trackingCode,
    String? customName,
    String? type,
    List<TrackingEvent>? events,
    DateTime? addedAt,
    DateTime? lastUpdate,
    String? currentStatus,
    int? orderIndex,
  }) {
    return Package(
      id: id ?? this.id,
      trackingCode: trackingCode ?? this.trackingCode,
      customName: customName ?? this.customName,
      type: type ?? this.type,
      events: events ?? this.events,
      addedAt: addedAt ?? this.addedAt,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      currentStatus: currentStatus ?? this.currentStatus,
      orderIndex: orderIndex ?? this.orderIndex,
    );
  }
}
