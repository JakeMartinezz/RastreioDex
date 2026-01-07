import 'tracking_event.dart';

class Package {
  final String trackingCode;
  final String? customName;
  final String type;
  final List<TrackingEvent> events;
  final DateTime? lastUpdate;
  final DateTime? estimatedDelivery;
  final String currentStatus;
  final bool isDelivered;
  final bool isArchived;
  final int orderIndex;

  Package({
    required this.trackingCode,
    this.customName,
    required this.type,
    required this.events,
    this.lastUpdate,
    this.estimatedDelivery,
    required this.currentStatus,
    this.isDelivered = false,
    this.isArchived = false,
    this.orderIndex = 0,
  });

  Package copyWith({
    String? trackingCode,
    String? customName,
    String? type,
    List<TrackingEvent>? events,
    DateTime? lastUpdate,
    DateTime? estimatedDelivery,
    String? currentStatus,
    bool? isDelivered,
    bool? isArchived,
    int? orderIndex,
  }) {
    return Package(
      trackingCode: trackingCode ?? this.trackingCode,
      customName: customName ?? this.customName,
      type: type ?? this.type,
      events: events ?? this.events,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      estimatedDelivery: estimatedDelivery ?? this.estimatedDelivery,
      currentStatus: currentStatus ?? this.currentStatus,
      isDelivered: isDelivered ?? this.isDelivered,
      isArchived: isArchived ?? this.isArchived,
      orderIndex: orderIndex ?? this.orderIndex,
    );
  }
}