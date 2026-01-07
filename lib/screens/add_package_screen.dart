import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/package.dart';
import '../services/firebase_service.dart';
import '../services/tracking_service.dart';
import '../services/preferences_service.dart';
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkClipboardAndAutoPaste();
    });
  }

  Future<void> _checkClipboardAndAutoPaste() async {
    final isEnabled = await PreferencesService.getSmartPaste();
    if (!isEnabled) return; 

    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text == null) return;

      final text = data!.text!.trim().toUpperCase();

      if (!TrackingService.isValidTrackingCode(text)) return;
      if (_trackingCodeController.text.isNotEmpty) return;

      final packages = await _firebaseService.getAllPackages();
      final isDuplicate = packages.any((p) => p.trackingCode == text);

      if (isDuplicate) return;

      if (mounted) {
        HapticFeedback.lightImpact();
        setState(() {
          _trackingCodeController.text = text;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Código detectado: $text'),
            backgroundColor: Colors.green[700],
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Erro no Smart Paste: $e');
    }
  }

  @override
  void dispose() {
    _trackingCodeController.dispose();
    _customNameController.dispose();
    super.dispose();
  }

  Future<void> _addPackage() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _loadingMessage = 'Buscando rastreamento...';
    });

    try {
      final trackingCode = _trackingCodeController.text.trim().toUpperCase();
      final customName = _customNameController.text.trim();

      setState(() => _loadingMessage = 'Buscando informações...\nPode levar alguns segundos');

      // CORREÇÃO: Acessando o Record retornado pela API
      final result = await TrackingService.trackPackage(trackingCode);
      
      final packageType = TrackingService.getPackageType(trackingCode);

      final package = Package(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        trackingCode: trackingCode,
        customName: customName.isEmpty ? null : customName,
        type: packageType,
        events: result.events, // Acessa a lista de eventos do Record
        addedAt: DateTime.now(),
        lastUpdate: result.events.isNotEmpty ? DateTime.now() : null,
        estimatedDelivery: result.estimatedDelivery, // Passa a nova data prevista
        currentStatus: result.events.isNotEmpty 
            ? result.events.first.status 
            : 'Aguardando rastreamento',
      );

      _firebaseService.addPackage(package).catchError((e) {
        debugPrint('⚠️ Erro ao salvar no Firebase: $e');
      });

      if (mounted) {
        HapticFeedback.mediumImpact();
        Navigator.of(context).pop();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PackageDetailsScreen(package: package),
          ),
        );
      }
    } catch (e) {
      String errorMessage = e.toString().contains('Chave de API') 
          ? 'Configure sua Chave de API nas configurações!' 
          : 'Erro: $e';

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingMessage = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Adicionar Encomenda')),
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
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.local_shipping),
                ),
                textCapitalization: TextCapitalization.characters,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Digite o código';
                  if (!TrackingService.isValidTrackingCode(value.toUpperCase())) return 'Formato inválido';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _customNameController,
                decoration: const InputDecoration(
                  labelText: 'Nome personalizado (opcional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.label),
                ),
              ),
              const SizedBox(height: 24),
              if (_isLoading) ...[
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 12),
                Text(_loadingMessage, textAlign: TextAlign.center),
                const SizedBox(height: 24),
              ],
              ElevatedButton(
                onPressed: _isLoading ? null : _addPackage,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: const Text('Adicionar Encomenda'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}