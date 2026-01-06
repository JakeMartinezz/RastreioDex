import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/package.dart';
import '../models/tracking_event.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'packages';

  Stream<List<Package>> getPackagesStream({bool showArchived = false}) {
    return _firestore
        .collection(_collection)
        .where('isArchived', isEqualTo: showArchived)
        .orderBy('orderIndex', descending: false)
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return Package.fromJson(data);
          }).toList();
        });
  }

  Future<void> toggleArchive(String packageId, bool archive) async {
    await _firestore.collection(_collection).doc(packageId).update({
      'isArchived': archive,
    });
  }

  Future<int> autoArchiveDeliveredPackages() async {
    try {
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));

      final snapshot = await _firestore
          .collection(_collection)
          .where('isArchived', isEqualTo: false)
          .where('lastUpdate', isLessThan: Timestamp.fromDate(sevenDaysAgo))
          .get();

      int count = 0;
      final batch = _firestore.batch();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final status = (data['currentStatus'] ?? '').toString().toLowerCase();

        if (status.contains('entregue')) {
          batch.update(doc.reference, {'isArchived': true});
          count++;
        }
      }

      if (count > 0) {
        await batch.commit();
        debugPrint('🧹 Auto-arquivados $count pacotes antigos.');
      }
      return count;
    } catch (e) {
      debugPrint('❌ Erro no auto-arquivamento: $e');
      return 0;
    }
  }

  Future<void> addPackage(Package package) async {
    try {
      await _firestore.collection(_collection).add(package.toJson());
    } catch (e) {
      debugPrint('❌ Erro ao adicionar pacote: $e');
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

  // ATUALIZADO: Agora aceita estimatedDelivery opcional
  Future<bool> updatePackageTracking(
    String packageId,
    List<TrackingEvent> newEvents, {
    DateTime? estimatedDelivery,
  }) async {
    try {
      final doc = await _firestore.collection(_collection).doc(packageId).get();
      if (!doc.exists) return false;

      final package = Package.fromJson({...doc.data()!, 'id': doc.id});
      
      final hasNewEvents = newEvents.length != package.events.length;
      final hasNewDate = estimatedDelivery != package.estimatedDelivery;

      // Se houver novos eventos OU a data prevista mudou/apareceu
      if (hasNewEvents || hasNewDate) {
        final updatedPackage = package.copyWith(
          events: newEvents.isNotEmpty ? newEvents : package.events,
          lastUpdate: DateTime.now(),
          currentStatus: newEvents.isNotEmpty
              ? newEvents.first.status
              : package.currentStatus,
          estimatedDelivery: estimatedDelivery ?? package.estimatedDelivery,
          isArchived: false, // Traz de volta se houver novidade
        );

        await updatePackage(updatedPackage);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Erro ao atualizar tracking no firebase: $e');
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

  Future<void> reorderPackages(List<Package> packages) async {
    final batch = _firestore.batch();
    for (int i = 0; i < packages.length; i++) {
      if (packages[i].orderIndex != i) {
        batch.update(_firestore.collection(_collection).doc(packages[i].id), {
          'orderIndex': i,
        });
      }
    }
    await batch.commit();
  }
}