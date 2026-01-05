import 'package:flutter/material.dart';
import '../models/package.dart';
import '../services/firebase_service.dart';
import '../services/tracking_service.dart';
import 'package_details_screen.dart';

class AddPackageScreen extends StatefulWidget {
  const AddPackageScreen({super.key});

  @override
  State<AddPackageScreen> createState() => _AddPackageScreenState();
}

class _AddPackageScreenState extends State<AddPackageScreen> {
  final _formKey = GlobalKey<FormState>();
  final _trackingCodeController = TextEditingController();
  final _customNameController = TextEditingController();
  final FirebaseService _firebaseService = FirebaseService();
  bool _isLoading = false;
  String _loadingMessage = '';

  @override
  void dispose() {
    _trackingCodeController.dispose();
    _customNameController.dispose();
    super.dispose();
  }

  Future<void> _addPackage() async {
    if (!_formKey.currentState!.validate()) return;

    // Esconde o teclado
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _loadingMessage = 'Buscando rastreamento...';
    });

    try {
      final trackingCode = _trackingCodeController.text.trim().toUpperCase();
      final customName = _customNameController.text.trim();

      debugPrint('🔍 Rastreando código: $trackingCode');
      setState(() => _loadingMessage = 'Buscando informações da encomenda...\nPode levar alguns segundos');

      final events = await TrackingService.trackPackage(trackingCode);
      debugPrint('📦 Eventos encontrados: ${events.length}');

      final packageType = TrackingService.getPackageType(trackingCode);
      debugPrint('📮 Tipo identificado: $packageType');

      final package = Package(
        id: DateTime.now().millisecondsSinceEpoch.toString(), // ID temporário
        trackingCode: trackingCode,
        customName: customName.isEmpty ? null : customName,
        type: packageType,
        events: events,
        addedAt: DateTime.now(),
        lastUpdate: events.isNotEmpty ? DateTime.now() : null,
        currentStatus:
            events.isNotEmpty ? events.first.status : 'Aguardando rastreamento',
      );

      debugPrint('💾 Salvando no Firebase em background...');
      // Salva em background, não espera
      _firebaseService.addPackage(package).then((_) {
        debugPrint('✅ Salvo no Firebase com sucesso!');
      }).catchError((e) {
        debugPrint('⚠️ Erro ao salvar no Firebase: $e');
      });

      debugPrint('📱 Abrindo tela de detalhes...');

      if (mounted) {
        // Fecha a tela de adicionar
        Navigator.of(context).pop();

        // Abre a tela de detalhes
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PackageDetailsScreen(package: package),
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ ERRO ao adicionar: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OK',
              onPressed: () {},
            ),
          ),
        );
      }
    } finally {
      debugPrint('🔄 Finalizando... mounted=$mounted');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingMessage = '';
        });
        debugPrint('✅ Estado limpo');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Adicionar Encomenda'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _trackingCodeController,
                decoration: const InputDecoration(
                  labelText: 'Código de Rastreio',
                  hintText: 'Ex: SS123456789BR',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.local_shipping),
                ),
                textCapitalization: TextCapitalization.characters,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Digite o código de rastreio';
                  }
                  if (!TrackingService.isValidTrackingCode(value.toUpperCase())) {
                    return 'Código inválido (formato: AA123456789BB)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _customNameController,
                decoration: const InputDecoration(
                  labelText: 'Nome personalizado (opcional)',
                  hintText: 'Ex: Presente para João',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.label),
                ),
              ),
              const SizedBox(height: 24),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue),
                          SizedBox(width: 8),
                          Text(
                            'Como rastrear',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Text('• O código tem 13 caracteres: AA123456789BR'),
                      Text('• Encontre na etiqueta da encomenda'),
                      Text('• O rastreamento é atualizado em tempo real'),
                      SizedBox(height: 8),
                      Text(
                        'A busca pode levar até 30 segundos',
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (_isLoading) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 12),
                      Text(
                        _loadingMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Por favor, aguarde...',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              ElevatedButton(
                onPressed: _isLoading ? null : _addPackage,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Adicionar Encomenda',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
