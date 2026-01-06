import 'tracking_event.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Package {
  final String id;
  final String trackingCode;
  final String? customName;
  final String type;
  final List<TrackingEvent> events;
  final DateTime addedAt;
  final DateTime? lastUpdate;
  final DateTime? estimatedDelivery; // NOVO CAMPO
  final String currentStatus;
  final int orderIndex;
  final bool isArchived;

  Package({
    required this.id,
    required this.trackingCode,
    this.customName,
    required this.type,
    required this.events,
    required this.addedAt,
    this.lastUpdate,
    this.estimatedDelivery, // Adicionar no construtor
    required this.currentStatus,
    this.orderIndex = 0,
    this.isArchived = false,
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
      addedAt: json['addedAt'] is Timestamp 
          ? (json['addedAt'] as Timestamp).toDate()
          : (json['addedAt'] != null ? DateTime.parse(json['addedAt'].toString()) : DateTime.now()),
      lastUpdate: json['lastUpdate'] is Timestamp
          ? (json['lastUpdate'] as Timestamp).toDate()
          : (json['lastUpdate'] != null ? DateTime.parse(json['lastUpdate'].toString()) : null),
      // Parse da data prevista do Firebase
      estimatedDelivery: json['estimatedDelivery'] is Timestamp
          ? (json['estimatedDelivery'] as Timestamp).toDate()
          : (json['estimatedDelivery'] != null ? DateTime.parse(json['estimatedDelivery'].toString()) : null),
      currentStatus: json['currentStatus'] ?? 'Aguardando rastreamento',
      orderIndex: json['orderIndex'] ?? 0,
      isArchived: json['isArchived'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'trackingCode': trackingCode,
      'customName': customName,
      'type': type,
      'events': events.map((e) => e.toJson()).toList(),
      'addedAt': Timestamp.fromDate(addedAt),
      'lastUpdate': lastUpdate != null ? Timestamp.fromDate(lastUpdate!) : null,
      'estimatedDelivery': estimatedDelivery != null ? Timestamp.fromDate(estimatedDelivery!) : null, // Salvar no banco
      'currentStatus': currentStatus,
      'orderIndex': orderIndex,
      'isArchived': isArchived,
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
    DateTime? estimatedDelivery, // Adicionar no copyWith
    String? currentStatus,
    int? orderIndex,
    bool? isArchived,
  }) {
    return Package(
      id: id ?? this.id,
      trackingCode: trackingCode ?? this.trackingCode,
      customName: customName ?? this.customName,
      type: type ?? this.type,
      events: events ?? this.events,
      addedAt: addedAt ?? this.addedAt,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      estimatedDelivery: estimatedDelivery ?? this.estimatedDelivery,
      currentStatus: currentStatus ?? this.currentStatus,
      orderIndex: orderIndex ?? this.orderIndex,
      isArchived: isArchived ?? this.isArchived,
    );
  }
}