import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/package.dart';
import '../models/tracking_event.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'packages';

  Stream<List<Package>> getPackagesStream() {
    debugPrint('📡 Iniciando stream do Firestore...');
    return _firestore
        .collection(_collection)
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      debugPrint('📥 Recebidos ${snapshot.docs.length} documentos do Firestore');
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        debugPrint('  - Doc ID: ${doc.id}, Código: ${data['trackingCode']}');
        return Package.fromJson(data);
      }).toList();
    });
  }

  Future<void> addPackage(Package package) async {
    try {
      debugPrint('💾 Adicionando pacote ao Firestore: ${package.trackingCode}');
      final docRef = await _firestore.collection(_collection).add(package.toJson());
      debugPrint('✅ Pacote adicionado com ID: ${docRef.id}');
    } catch (e, stackTrace) {
      debugPrint('❌ Erro ao adicionar pacote: $e');
      debugPrint('Stack: $stackTrace');
      rethrow;
    }
  }

  Future<void> updatePackage(Package package) async {
    await _firestore
        .collection(_collection)
        .doc(package.id)
        .update(package.toJson());
  }

  Future<void> deletePackage(String packageId) async {
    await _firestore.collection(_collection).doc(packageId).delete();
  }

  Future<bool> updatePackageTracking(
      String packageId, List<TrackingEvent> newEvents) async {
    try {
      final doc = await _firestore.collection(_collection).doc(packageId).get();
      if (!doc.exists) return false;

      final package = Package.fromJson({...doc.data()!, 'id': doc.id});

      final hasNewEvents = newEvents.length != package.events.length;

      if (hasNewEvents) {
        final updatedPackage = package.copyWith(
          events: newEvents,
          lastUpdate: DateTime.now(),
          currentStatus:
              newEvents.isNotEmpty ? newEvents.first.status : package.currentStatus,
        );

        await updatePackage(updatedPackage);
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  Future<List<Package>> getAllPackages() async {
    final snapshot = await _firestore
        .collection(_collection)
        .orderBy('addedAt', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return Package.fromJson(data);
    }).toList();
  }
}
