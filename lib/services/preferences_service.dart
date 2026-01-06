import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const String _keyHideDelivered = 'hide_delivered';
  static const String _keyAutoArchive = 'auto_archive'; // NOVA CHAVE
  static const String _keyUpdateFrequency = 'update_frequency';
  static const String _keySmartPaste = 'smart_paste';
  static const String _keyApiKey = 'api_key';

  // --- Salvar ---
  static Future<void> saveHideDelivered(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHideDelivered, value);
  }

  static Future<void> saveAutoArchive(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoArchive, value);
  }

  static Future<void> saveUpdateFrequency(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUpdateFrequency, value);
  }

  static Future<void> saveSmartPaste(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySmartPaste, value);
  }

  static Future<void> saveApiKey(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyApiKey, value);
  }

  // --- Ler ---
  static Future<bool> getHideDelivered() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyHideDelivered) ?? false;
  }

  static Future<bool> getAutoArchive() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAutoArchive) ?? false;
  }

  static Future<String> getUpdateFrequency() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUpdateFrequency) ?? '1 hora';
  }

  static Future<bool> getSmartPaste() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keySmartPaste) ?? true;
  }

  static Future<String> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyApiKey) ?? '';
  }
}