import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/package.dart';
import '../models/tracking_event.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'packages';

  // ALTERADO: Recebe parâmetro para filtrar arquivados
  Stream<List<Package>> getPackagesStream({bool showArchived = false}) {
    return _firestore
        .collection(_collection)
        .where('isArchived', isEqualTo: showArchived) // <--- FILTRO
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

  // NOVO: Alternar status de arquivamento
  Future<void> toggleArchive(String packageId, bool archive) async {
    await _firestore.collection(_collection).doc(packageId).update({
      'isArchived': archive,
    });
  }

  // NOVO: Automação para arquivar entregues há mais de 7 dias
  Future<int> autoArchiveDeliveredPackages() async {
    try {
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));

      // Busca pacotes entregues, não arquivados e atualizados há mais de 7 dias
      // Nota: Isso pode exigir um índice composto no Firebase (verifique o console)
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

        // Verificação dupla se foi entregue
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

  // ... (Mantenha os outros métodos: addPackage, updatePackage, deletePackage, reorderPackages, etc.)

  // Certifique-se que o addPackage usa o novo toJson()
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

  Future<bool> updatePackageTracking(
    String packageId,
    List<TrackingEvent> newEvents,
  ) async {
    try {
      final doc = await _firestore.collection(_collection).doc(packageId).get();
      if (!doc.exists) return false;

      final package = Package.fromJson({...doc.data()!, 'id': doc.id});
      final hasNewEvents = newEvents.length != package.events.length;

      if (hasNewEvents) {
        // Se receber atualização, desarquiva automaticamente (opcional, mas bom UX)
        final updatedPackage = package.copyWith(
          events: newEvents,
          lastUpdate: DateTime.now(),
          currentStatus: newEvents.isNotEmpty
              ? newEvents.first.status
              : package.currentStatus,
          isArchived:
              false, // Traz de volta para a tela principal se tiver novidade
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
