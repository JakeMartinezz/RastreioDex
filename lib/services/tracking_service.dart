import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/tracking_event.dart';

class TrackingService {
  static const String _apiKey = 'Sua-chave-de-api';
  static const String _apiUrl = 'https://api-labs.wonca.com.br/wonca.labs.v1.LabsService/Track';

  static Future<List<TrackingEvent>> trackPackage(String trackingCode, {int retryCount = 0}) async {
    try {
      debugPrint('🌐 Rastreando via Wonca Labs: $trackingCode (tentativa ${retryCount + 1}/3)');

      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Apikey $_apiKey',
        },
        body: json.encode({
          'code': trackingCode,
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('⏱️ Timeout após 30 segundos');
          throw Exception('Tempo esgotado. A API não respondeu a tempo.');
        },
      );

      debugPrint('📊 Status code: ${response.statusCode}');
      debugPrint('📄 Tamanho da resposta: ${response.body.length} caracteres');

      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          debugPrint('✅ JSON principal decodificado');
          debugPrint('🔑 Chaves do JSON: ${data.keys.toList()}');

          // A API Wonca retorna: {"json": "...", "carrier": "...", "results": [...]}
          // O JSON real está dentro da chave "json" como string
          if (data['json'] != null) {
            debugPrint('✅ Chave "json" encontrada');
            debugPrint('📝 Tipo de data["json"]: ${data['json'].runtimeType}');

            final trackingData = json.decode(data['json']);
            debugPrint('✅ JSON interno decodificado');
            debugPrint('🔑 Chaves do tracking: ${trackingData.keys.toList()}');

            if (trackingData['eventos'] != null) {
              debugPrint('✅ Chave "eventos" encontrada');
              debugPrint('📝 Tipo de eventos: ${trackingData['eventos'].runtimeType}');

              if (trackingData['eventos'] is List) {
                debugPrint('✅ "eventos" é uma List');
              } else {
                debugPrint('❌ "eventos" NÃO é uma List!');
                return [];
              }
            } else {
              debugPrint('❌ Chave "eventos" NÃO encontrada no tracking!');
              debugPrint('📋 Dados disponíveis: $trackingData');
              return [];
            }

            if (trackingData['eventos'] != null && trackingData['eventos'] is List) {
            final eventos = trackingData['eventos'] as List;
            debugPrint('📋 Total de eventos: ${eventos.length}');

            final events = eventos.map((evento) {
              // Parse da data do formato {"date": "2026-01-05 07:43:24.000000", ...}
              DateTime eventDate;
              try {
                if (evento['dtHrCriado'] != null && evento['dtHrCriado']['date'] != null) {
                  final dateStr = evento['dtHrCriado']['date'].toString().split('.')[0];
                  eventDate = DateTime.parse(dateStr.replaceAll(' ', 'T'));
                } else {
                  eventDate = DateTime.now();
                }
              } catch (e) {
                debugPrint('⚠️ Erro ao parsear data: $e');
                eventDate = DateTime.now();
              }

              // Extrai descrição e local
              final descricao = evento['descricao'] ?? evento['descricaoFrontEnd'] ?? '';
              final descricaoWeb = evento['descricaoWeb'] ?? '';

              // Monta o local a partir da unidade
              String location = 'Brasil';
              if (evento['unidade'] != null && evento['unidade']['endereco'] != null) {
                final endereco = evento['unidade']['endereco'];
                final cidade = endereco['cidade'] ?? '';
                final uf = endereco['uf'] ?? '';
                if (cidade.isNotEmpty && uf.isNotEmpty) {
                  location = '$cidade - $uf';
                } else if (uf.isNotEmpty) {
                  location = uf;
                }
              }

              debugPrint('  📍 $descricao - $location');

              return TrackingEvent(
                status: descricaoWeb.isNotEmpty ? descricaoWeb : descricao,
                description: descricao,
                location: location,
                dateTime: eventDate,
              );
            }).toList();

            debugPrint('✅ ${events.length} eventos convertidos com sucesso');
            return events;
          }
        } else {
          debugPrint('❌ Chave "json" NÃO encontrada na resposta!');
          debugPrint('📋 Chaves disponíveis: ${data.keys.toList()}');
          debugPrint('📄 Resposta completa: ${response.body.substring(0, 500)}');
        }

        } catch (e, stack) {
          debugPrint('❌ Erro ao parsear JSON: $e');
          debugPrint('Stack: ${stack.toString().substring(0, 300)}');
          debugPrint('📄 Resposta que causou erro: ${response.body.substring(0, 500)}');
        }

        debugPrint('⚠️ Nenhum evento encontrado na resposta');
      } else {
        debugPrint('❌ Erro HTTP: ${response.statusCode}');
        debugPrint('📄 Body: ${response.body}');
      }

      return [];
    } catch (e, stackTrace) {
      debugPrint('❌ Erro ao rastrear: $e');

      // Retry logic - tenta até 3 vezes
      if (retryCount < 2) {
        debugPrint('🔄 Tentando novamente em 2 segundos...');
        await Future.delayed(const Duration(seconds: 2));
        return trackPackage(trackingCode, retryCount: retryCount + 1);
      }

      debugPrint('❌ Falhou após 3 tentativas');
      debugPrint('Stack: ${stackTrace.toString().substring(0, 200)}');
      return [];
    }
  }

  static String getPackageType(String trackingCode) {
    if (trackingCode.isEmpty || trackingCode.length < 2) {
      return 'Outros';
    }

    final prefix = trackingCode.substring(0, 2).toUpperCase();

    switch (prefix) {
      case 'SS':
      case 'SW':
      case 'SD':
        return 'SEDEX';
      case 'PO':
      case 'PJ':
      case 'PK':
      case 'PL':
        return 'PAC';
      case 'JD':
      case 'JE':
      case 'JH':
        return 'SEDEX Hoje';
      case 'RE':
      case 'RA':
        return 'Registro';
      case 'AA':
      case 'AB':
      case 'AC':
      case 'AD':
        return 'Internacional';
      default:
        return 'Outros';
    }
  }

  static bool isValidTrackingCode(String code) {
    if (code.isEmpty) return false;

    // Formato: 2 letras + 9 números + 2 letras
    final regex = RegExp(r'^[A-Z]{2}\d{9}[A-Z]{2}$');
    return regex.hasMatch(code.toUpperCase());
  }
}
