import 'dart:async'; // Import necessário para tratar TimeoutExceptions se explícitas
import 'package:flutter/material.dart';
import '../models/package.dart';
import '../services/firebase_service.dart';
import '../services/tracking_service.dart';

class EditPackageScreen extends StatefulWidget {
  final Package package;

  const EditPackageScreen({super.key, required this.package});

  @override
  State<EditPackageScreen> createState() => _EditPackageScreenState();
}

class _EditPackageScreenState extends State<EditPackageScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _trackingCodeController;
  late TextEditingController _customNameController;
  final FirebaseService _firebaseService = FirebaseService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _trackingCodeController = TextEditingController(text: widget.package.trackingCode);
    _customNameController = TextEditingController(text: widget.package.customName ?? '');
  }

  @override
  void dispose() {
    _trackingCodeController.dispose();
    _customNameController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    // Fecha o teclado para evitar bugs visuais
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Verificação de Segurança do ID
      if (widget.package.id.isEmpty) {
        throw Exception('Erro interno: ID do pacote não encontrado.');
      }

      final newCode = _trackingCodeController.text.trim().toUpperCase();
      final newName = _customNameController.text.trim();
      
      // Se o código mudou, recalculamos o tipo (SEDEX, PAC, etc)
      String newType = widget.package.type;
      if (newCode != widget.package.trackingCode) {
        newType = TrackingService.getPackageType(newCode);
      }

      // CORREÇÃO: Criamos uma nova instância manualmente em vez de usar copyWith.
      // O copyWith do seu modelo ignora nulos (?? this.field), o que impede 
      // de "apagar" o nome personalizado se o usuário deixar o campo vazio.
      final updatedPackage = Package(
        id: widget.package.id, // Mantém o ID original (Crucial!)
        trackingCode: newCode,
        customName: newName.isEmpty ? null : newName, // Agora permite nulo
        type: newType,
        events: widget.package.events, // Mantém histórico
        addedAt: widget.package.addedAt,
        lastUpdate: widget.package.lastUpdate,
        currentStatus: widget.package.currentStatus,
      );

      // CORREÇÃO: Adicionado timeout para evitar carregamento infinito
      await _firebaseService.updatePackage(updatedPackage).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('O servidor demorou muito para responder.');
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alterações salvas com sucesso!')),
        );
        // Retorna o pacote atualizado para a tela anterior
        Navigator.pop(context, updatedPackage);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Encomenda'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
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
                  helperText: 'Deixe em branco para remover o nome',
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _saveChanges,
                  icon: _isLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                      : const Icon(Icons.save),
                  label: Text(_isLoading ? 'Salvando...' : 'Salvar Alterações'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}