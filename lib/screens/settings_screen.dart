import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

import '../services/preferences_service.dart';
import '../services/notification_service.dart';
import '../services/database_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Configurações
  bool _hideDelivered = false;
  bool _autoArchive = false;
  bool _smartPaste = true;
  String _updateFrequency = '1 hora';
  final TextEditingController _apiKeyController = TextEditingController();
  bool _isLoading = true;

  final List<String> _frequencyOptions = [
    '15 min',
    '30 min',
    '1 hora',
    '4 horas',
    'Manual',
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final hide = await PreferencesService.getHideDelivered();
    final archive = await PreferencesService.getAutoArchive();
    final smart = await PreferencesService.getSmartPaste();
    final freq = await PreferencesService.getUpdateFrequency();
    final api = await PreferencesService.getApiKey();

    setState(() {
      _hideDelivered = hide;
      _autoArchive = archive;
      _smartPaste = smart;
      _updateFrequency = freq;
      _apiKeyController.text = api;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Configurações'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Geral'),
              Tab(text: 'Desenvolvedor'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildGeneralTab(),
            _buildDeveloperTab(),
          ],
        ),
      ),
    );
  }

  // --- ABA GERAL ---
  Widget _buildGeneralTab() {
    return ListView(
      children: [
        _buildSectionHeader('Preferências'),
        SwitchListTile(
          secondary: const Icon(Icons.content_paste_go),
          title: const Text('Smart Paste'),
          subtitle: const Text('Detectar rastreio ao abrir app'),
          value: _smartPaste,
          onChanged: (val) {
            setState(() => _smartPaste = val);
            PreferencesService.saveSmartPaste(val);
          },
        ),
        const Divider(),
        _buildSectionHeader('Organização'),
        SwitchListTile(
          secondary: const Icon(Icons.visibility_off),
          title: const Text('Ocultar Entregues'),
          subtitle: const Text('Esconde da lista principal'),
          value: _hideDelivered,
          onChanged: (val) {
            setState(() {
              _hideDelivered = val;
              if (val) {
                _autoArchive = false;
                PreferencesService.saveAutoArchive(false);
              }
            });
            PreferencesService.saveHideDelivered(val);
          },
        ),
        SwitchListTile(
          secondary: const Icon(Icons.archive),
          title: const Text('Arquivar Entregues'),
          subtitle: const Text('Move para aba Arquivados'),
          value: _autoArchive,
          onChanged: (val) {
            setState(() {
              _autoArchive = val;
              if (val) {
                _hideDelivered = false;
                PreferencesService.saveHideDelivered(false);
              }
            });
            PreferencesService.saveAutoArchive(val);
          },
        ),
        const Divider(),
        _buildSectionHeader('Sincronização'),
        ListTile(
          leading: const Icon(Icons.sync),
          title: const Text('Frequência de Atualização'),
          subtitle: Text(_updateFrequency),
          onTap: _showFrequencySelector,
        ),
      ],
    );
  }

  // --- ABA DESENVOLVEDOR ---
  Widget _buildDeveloperTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('API Wonca Labs'),
        const SizedBox(height: 10),
        TextField(
          controller: _apiKeyController,
          decoration: const InputDecoration(
            labelText: 'Chave de API',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.vpn_key),
          ),
          onChanged: (val) => PreferencesService.saveApiKey(val.trim()),
        ),
        
        const SizedBox(height: 24),
        _buildSectionHeader('Backup & Restauração (JSON)'),
        const SizedBox(height: 10),
        
        Card(
          elevation: 2,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.upload_file),
                title: const Text('Fazer Backup'),
                subtitle: const Text('Exportar dados para JSON'),
                onTap: _exportBackup,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('Restaurar Backup'),
                subtitle: const Text('Importar dados de JSON'),
                onTap: _importBackup,
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
        _buildSectionHeader('Testes'),
        
        // Botão pequeno para teste de notificação
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Testar Notificação (10s delay)'),
            IconButton.filledTonal(
              icon: const Icon(Icons.notifications_active),
              tooltip: 'Testar notificação',
              onPressed: () {
                HapticFeedback.mediumImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Aguarde 10 segundos...')),
                );
                
                Future.delayed(const Duration(seconds: 10), () {
                  NotificationService.showNotification(
                    'Teste Rápido',
                    'Notificação de teste funcionou! 🚀',
                  );
                });
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).primaryColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showFrequencySelector() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return RadioGroup<String>(
          groupValue: _updateFrequency,
          onChanged: (val) {
            if (val != null) {
              setState(() => _updateFrequency = val);
              PreferencesService.saveUpdateFrequency(val);
              Navigator.pop(context);
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _frequencyOptions.map((option) {
              return RadioListTile<String>(
                title: Text(option),
                value: option,
                // groupValue e onChanged são geridos pelo RadioGroup pai
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // --- LÓGICA DE BACKUP ---

  Future<void> _exportBackup() async {
    final password = await _showPasswordDialog(isEncrypting: true);
    if (password == null) return; 

    try {
      final data = await DatabaseService.instance.exportAllData();
      String jsonString = jsonEncode(data);

      String fileContent = jsonString;
      String fileName = 'rastreiodex_backup_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.json';

      if (password.isNotEmpty) {
        final key = encrypt.Key.fromUtf8(password.padRight(32).substring(0, 32));
        final iv = encrypt.IV.fromLength(16);
        final encrypter = encrypt.Encrypter(encrypt.AES(key));
        
        final encrypted = encrypter.encrypt(jsonString, iv: iv);
        
        final backupMap = {
          "encrypted": true,
          "iv": iv.base64,
          "data": encrypted.base64
        };
        fileContent = jsonEncode(backupMap);
      }

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(fileContent);

      await Share.shareXFiles([XFile(file.path)], text: 'Backup RastreioDex');

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao criar backup: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _importBackup() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result == null) return;

      final file = File(result.files.single.path!);
      String content = await file.readAsString();
      
      dynamic decoded;
      try {
        decoded = jsonDecode(content);
      } catch (e) {
        throw 'Arquivo inválido ou corrompido.';
      }

      if (decoded is Map && decoded['encrypted'] == true) {
        String? password;
        bool success = false;
        
        while (!success) {
          password = await _showPasswordDialog(isEncrypting: false);
          if (password == null) return; 

          try {
            final key = encrypt.Key.fromUtf8(password.padRight(32).substring(0, 32));
            final iv = encrypt.IV.fromBase64(decoded['iv']);
            final encrypter = encrypt.Encrypter(encrypt.AES(key));
            
            final decryptedString = encrypter.decrypt64(decoded['data'], iv: iv);
            decoded = jsonDecode(decryptedString);
            success = true;
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Senha incorreta! Tente novamente.')),
              );
            }
          }
        }
      }

      if (decoded is List) {
        if (!mounted) return;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Restaurar Backup?'),
            content: Text('Isso substituirá suas encomendas atuais por ${decoded.length} itens do backup.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Restaurar')),
            ],
          ),
        );

        if (confirm == true) {
          await DatabaseService.instance.importData(decoded);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Backup restaurado com sucesso!'), backgroundColor: Colors.green),
            );
          }
        }
      } else {
        throw 'Formato de arquivo não reconhecido.';
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao restaurar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<String?> _showPasswordDialog({required bool isEncrypting}) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text(isEncrypting ? 'Proteger Backup' : 'Desbloquear Backup'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(isEncrypting 
                ? 'Digite uma senha para criptografar o arquivo (opcional).' 
                : 'Este backup é criptografado. Digite a senha.'),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                obscureText: true,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Senha',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: Text(isEncrypting 
                ? (controller.text.isEmpty ? 'Sem Senha' : 'Criptografar') 
                : 'Desbloquear'),
            ),
          ],
        );
      },
    );
  }
}
