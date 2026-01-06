import 'package:flutter/material.dart';
import '../services/preferences_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _hideDelivered = false;
  bool _autoArchive = false; // NOVO ESTADO
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

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
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

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        children: [
          _buildSectionHeader('Geral'),

          SwitchListTile(
            secondary: const Icon(Icons.content_paste_go),
            title: const Text('Smart Paste'),
            subtitle: const Text(
              'Detectar rastreio ao entrar na tela de cadastro',
            ),
            value: _smartPaste,
            onChanged: (val) {
              setState(() => _smartPaste = val);
              PreferencesService.saveSmartPaste(val);
            },
          ),

          const Divider(),
          _buildSectionHeader('Organização'),

          // OPÇÃO 1: Ocultar Entregues
          SwitchListTile(
            secondary: const Icon(Icons.visibility_off),
            title: const Text('Ocultar Entregues'),
            subtitle: const Text('Apenas esconde da lista principal'),
            value: _hideDelivered,
            onChanged: (val) {
              setState(() {
                _hideDelivered = val;
                // Lógica de exclusão mútua: Se ativar Ocultar, desativa Arquivar
                if (val) {
                  _autoArchive = false;
                  PreferencesService.saveAutoArchive(false);
                }
              });
              PreferencesService.saveHideDelivered(val);
            },
          ),

          // OPÇÃO 2: Arquivar Automaticamente (NOVO)
          SwitchListTile(
            secondary: const Icon(Icons.archive),
            title: const Text('Arquivar Entregues'),
            subtitle: const Text('Move automaticamente para a aba Arquivados'),
            value: _autoArchive,
            onChanged: (val) {
              setState(() {
                _autoArchive = val;
                // Lógica de exclusão mútua: Se ativar Arquivar, desativa Ocultar
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
            onTap: () {
              _showFrequencySelector();
            },
          ),

          const Divider(),
          _buildSectionHeader('Desenvolvedor'),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chave de API (Wonca Labs)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _apiKeyController,
                  decoration: const InputDecoration(
                    hintText: 'Cole sua chave aqui',
                    border: OutlineInputBorder(),
                    helperText: 'Necessário para rastrear novas encomendas',
                    prefixIcon: Icon(Icons.vpn_key),
                  ),
                  onChanged: (val) {
                    PreferencesService.saveApiKey(val.trim());
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: _frequencyOptions.map((option) {
            return RadioListTile<String>(
              title: Text(option),
              value: option,
              groupValue: _updateFrequency,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (val) {
                if (val != null) {
                  setState(() => _updateFrequency = val);
                  PreferencesService.saveUpdateFrequency(val);
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
        );
      },
    );
  }
}
