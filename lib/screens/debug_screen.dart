import 'package:flutter/material.dart';
import '../models/package.dart';
import '../services/firebase_service.dart';
import '../services/tracking_service.dart';

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  final List<String> _logs = [];
  final _codeController = TextEditingController(text: 'AA361812099BR');
  final FirebaseService _firebaseService = FirebaseService();
  bool _isLoading = false;

  void _addLog(String message) {
    setState(() {
      _logs.insert(0, '${DateTime.now().toLocal().toString().substring(11, 19)} - $message');
    });
  }

  Future<void> _testFirebaseConnection() async {
    setState(() {
      _isLoading = true;
      _logs.clear();
    });

    try {
      _addLog('🔍 Testando conexão com Firebase...');

      final packages = await _firebaseService.getAllPackages();
      _addLog('✅ Firebase conectado!');
      _addLog('📦 Encontradas ${packages.length} encomendas');

      for (var pkg in packages) {
        _addLog('  - ${pkg.trackingCode}: ${pkg.currentStatus}');
      }

      if (packages.isEmpty) {
        _addLog('⚠️ Nenhuma encomenda no banco de dados');
        _addLog('💡 Tente adicionar uma encomenda');
      }
    } catch (e) {
      _addLog('❌ ERRO Firebase: $e');
      _addLog('💡 Verifique:');
      _addLog('  1. google-services.json está em android/app/');
      _addLog('  2. Regras do Firestore permitem leitura/escrita');
      _addLog('  3. App está conectado à internet');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testFirebaseStream() async {
    setState(() {
      _isLoading = true;
      _logs.clear();
    });

    try {
      _addLog('🔍 Testando Stream do Firebase...');

      await Future.delayed(const Duration(seconds: 2));

      _firebaseService.getPackagesStream().listen(
        (packages) {
          _addLog('📥 Stream recebeu ${packages.length} encomendas');
          for (var pkg in packages) {
            _addLog('  - ${pkg.trackingCode}');
          }
        },
        onError: (error) {
          _addLog('❌ Erro no Stream: $error');
        },
      );

      _addLog('✅ Stream iniciado - aguardando dados...');
    } catch (e) {
      _addLog('❌ ERRO ao criar Stream: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testAPITracking() async {
    setState(() {
      _isLoading = true;
      _logs.clear();
    });

    try {
      final code = _codeController.text.trim().toUpperCase();
      _addLog('🌐 Testando API com código: $code');

      if (!TrackingService.isValidTrackingCode(code)) {
        _addLog('⚠️ Código inválido!');
        _addLog('Formato correto: AA123456789BR');
        setState(() => _isLoading = false);
        return;
      }

      _addLog('📡 Fazendo requisição para API...');
      final events = await TrackingService.trackPackage(code);

      if (events.isEmpty) {
        _addLog('⚠️ API retornou 0 eventos');
        _addLog('💡 Possíveis causas:');
        _addLog('  1. Código não encontrado nos Correios');
        _addLog('  2. Encomenda ainda sem rastreamento');
        _addLog('  3. API key inválida ou expirada');
        _addLog('  4. Problema de conexão');
      } else {
        _addLog('✅ API retornou ${events.length} eventos!');
        for (var event in events) {
          _addLog('📍 ${event.status}');
          _addLog('   ${event.description}');
          _addLog('   ${event.location} - ${event.dateTime}');
        }
      }
    } catch (e) {
      _addLog('❌ ERRO na API: $e');
      _addLog('💡 Verifique sua conexão com internet');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testCompleteFlow() async {
    setState(() {
      _isLoading = true;
      _logs.clear();
    });

    try {
      final code = _codeController.text.trim().toUpperCase();
      _addLog('🔄 Testando fluxo completo...');
      _addLog('');

      // 1. Testar API
      _addLog('1️⃣ Buscando rastreamento na API...');
      final events = await TrackingService.trackPackage(code);
      _addLog('   ✅ Recebidos ${events.length} eventos');

      if (events.isEmpty) {
        _addLog('   ⚠️ Sem eventos - usando status padrão');
      }

      // 2. Criar pacote
      _addLog('');
      _addLog('2️⃣ Criando objeto Package...');
      final package = {
        'trackingCode': code,
        'customName': 'Teste Debug',
        'type': TrackingService.getPackageType(code),
        'events': events.map((e) => e.toJson()).toList(),
        'addedAt': DateTime.now().toIso8601String(),
        'lastUpdate': events.isNotEmpty ? DateTime.now().toIso8601String() : null,
        'currentStatus': events.isNotEmpty ? events.first.status : 'Aguardando rastreamento',
      };
      _addLog('   ✅ Package criado');

      // 3. Salvar no Firebase
      _addLog('');
      _addLog('3️⃣ Salvando no Firebase...');
      await _firebaseService.addPackage(
        Package.fromJson(package),
      );
      _addLog('   ✅ Salvo no Firebase!');

      // 4. Verificar leitura
      _addLog('');
      _addLog('4️⃣ Verificando se consegue ler do Firebase...');
      await Future.delayed(const Duration(seconds: 1));
      final packages = await _firebaseService.getAllPackages();
      _addLog('   ✅ Lidos ${packages.length} pacotes');

      final found = packages.any((p) => p.trackingCode == code);
      if (found) {
        _addLog('   ✅ Pacote de teste encontrado!');
        _addLog('');
        _addLog('🎉 TUDO FUNCIONANDO!');
        _addLog('Se não aparece na tela, o problema é na UI');
      } else {
        _addLog('   ❌ Pacote NÃO encontrado na leitura');
        _addLog('   Problema: Firebase salva mas não lê');
      }

    } catch (e, stack) {
      _addLog('');
      _addLog('❌ ERRO: $e');
      _addLog('Stack: ${stack.toString().substring(0, 200)}...');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug - Diagnóstico'),
        backgroundColor: Colors.orange,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.orange.withValues(alpha: 0.1),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'TESTES DE DIAGNÓSTICO',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _codeController,
                  decoration: const InputDecoration(
                    labelText: 'Código para testar API',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _testFirebaseConnection,
                      icon: const Icon(Icons.cloud, size: 16),
                      label: const Text('Testar Firebase', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _testFirebaseStream,
                      icon: const Icon(Icons.stream, size: 16),
                      label: const Text('Testar Stream', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _testAPITracking,
                      icon: const Icon(Icons.api, size: 16),
                      label: const Text('Testar API', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _testCompleteFlow,
                      icon: const Icon(Icons.play_arrow, size: 16),
                      label: const Text('Fluxo Completo', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_isLoading)
            const LinearProgressIndicator(),
          Expanded(
            child: _logs.isEmpty
                ? const Center(
                    child: Text(
                      'Clique em um botão acima para iniciar o teste',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      final log = _logs[index];
                      Color textColor = Colors.black;
                      if (log.contains('✅')) textColor = Colors.green;
                      if (log.contains('❌')) textColor = Colors.red;
                      if (log.contains('⚠️')) textColor = Colors.orange;
                      if (log.contains('💡')) textColor = Colors.blue;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          log,
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            color: textColor,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
