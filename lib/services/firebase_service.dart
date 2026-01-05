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
        // ALTERADO: Ordena pelo índice personalizado e depois pela data como critério de desempate
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

  // ... (mantenha os métodos addPackage, updatePackage, deletePackage, updatePackageTracking iguais) ...
  // Apenas certifique-se de que os métodos existentes usem o novo toJson() do modelo que já inclui o orderIndex.
  
  // MANTENHA O RESTANTE DA CLASSE E ADICIONE ESTE NOVO MÉTODO NO FINAL:

  Future<void> reorderPackages(List<Package> packages) async {
    final batch = _firestore.batch();

    for (int i = 0; i < packages.length; i++) {
      final package = packages[i];
      // Só atualiza se o índice mudou para economizar escritas
      if (package.orderIndex != i) {
        final docRef = _firestore.collection(_collection).doc(package.id);
        batch.update(docRef, {'orderIndex': i});
      }
    }

    try {
      await batch.commit();
      debugPrint('✅ Ordem atualizada no Firebase');
    } catch (e) {
      debugPrint('❌ Erro ao reordenar: $e');
    }
  }

  // Copie os outros métodos (addPackage, etc) do seu arquivo original se necessário, 
  // mas a única mudança lógica crítica é no getPackagesStream e o novo reorderPackages.
  Future<void> addPackage(Package package) async {
      // ... (código existente)
      // Nota: Ao adicionar, você pode querer definir o orderIndex como 0 (início) ou packages.length (fim)
      // Mas o padrão 0 do modelo já funciona (vai para o topo).
       try {
        debugPrint('💾 Adicionando pacote ao Firestore: ${package.trackingCode}');
        final docRef = await _firestore.collection(_collection).add(package.toJson());
        debugPrint('✅ Pacote adicionado com ID: ${docRef.id}');
      } catch (e, stackTrace) {
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
      String packageId, List<TrackingEvent> newEvents) async {
    // ... (mantenha o código original aqui)
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
    // ... (mantenha o código original aqui)
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