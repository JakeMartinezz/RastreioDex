import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/tracking_event.dart';

class TrackingService {
  // Chave de API e URL
  static const String _apiKey = ''; // <--- INSIRA SUA CHAVE AQUI
  static const String _apiUrl = 'https://api-labs.wonca.com.br/wonca.labs.v1.LabsService/Track';

  // --- OTIMIZAÇÃO: GRUPOS DE PREFIXOS ---
  // É muito mais fácil manter listas de siglas do que um mapa gigante de 1:1
  static const Map<String, List<String>> _prefixGroups = {
    'SEDEX': [
      'AA', 'AB', 'AC', 'AD', 'AE', 'AJ', 'AX', 'AY', 'DA', 'DF', 'DG', 'DH', 
      'DJ', 'DK', 'DL', 'DM', 'DN', 'DO', 'DP', 'DQ', 'DU', 'DV', 'DW', 'DY', 
      'DZ', 'OA', 'OB', 'OC', 'OD', 'OF', 'OG', 'OH', 'OI', 'OJ', 'OK', 'OM', 
      'ON', 'OO', 'OP', 'OS', 'OT', 'OU', 'OV', 'OX', 'OY', 'OZ', 'QB', 'SA', 
      'SE', 'SF', 'SG', 'SH', 'SI', 'SK', 'SL', 'SN', 'SO', 'SQ', 'SR', 'SS', 
      'SU', 'SW', 'SZ', 'TA', 'TE', 'TF', 'TG', 'TH', 'TI', 'TJ', 'TK', 'TL', 
      'TN'
    ],
    'SEDEX 10': ['DX', 'OR', 'SB', 'SX', 'TC', 'TM'],
    'SEDEX 12': ['DD', 'OE', 'SM', 'TD'],
    'SEDEX Hoje': ['AZ', 'OW', 'SJ', 'SP', 'TB'],
    'SEDEX a Cobrar': ['SC'],
    
    'PAC': [
      'AK', 'AL', 'AQ', 'AS', 'OL', 'PA', 'PB', 'PD', 'PE', 'PF', 'PG', 'PH', 
      'PI', 'PJ', 'PK', 'PL', 'PM', 'PN', 'PO', 'PP', 'PS', 'PT', 'PU', 'PV', 
      'PW', 'PX', 'PY', 'PZ', 'QA', 'QC', 'QD', 'QE', 'QF', 'QG', 'QH', 'QI', 
      'QJ', 'QK', 'QL', 'QM', 'QN', 'QP', 'QQ', 'QR', 'QS', 'QT', 'QU', 'QV', 
      'QW', 'QX', 'QY', 'QZ', 'XL'
    ],
    'PAC Mini': ['AV', 'AW', 'PQ', 'PR', 'QO'],
    'PAC a Cobrar': ['PC'],
    
    'Internacional': [
      'AR', 'CA', 'CB', 'CC', 'CD', 'CE', 'CF', 'CG', 'CH', 'CI', 'CJ', 'CK', 
      'CL', 'CM', 'CN', 'CO', 'CP', 'CQ', 'CR', 'CS', 'CT', 'CU', 'CV', 'CW', 
      'CX', 'CY', 'CZ', 'IF', 'IG', 'IN', 'MS', 'RD', 'RF', 'RG', 'RH', 'RI', 
      'RL', 'RN', 'RP', 'RR', 'RS', 'RT', 'RU', 'RV', 'RW', 'RX', 'RY', 'RZ', 
      'VA', 'VB', 'VC', 'VD', 'VE', 'VF', 'VG', 'VH', 'VI', 'VJ', 'VK', 'VL', 
      'VM', 'VN', 'VO', 'VP', 'VQ', 'VR', 'VS', 'VT', 'VU', 'VV', 'VW', 'VX', 
      'VY', 'VZ'
    ],
    'EMS Internacional': [
      'EA', 'EB', 'EC', 'ED', 'EE', 'EF', 'EG', 'EH', 'EI', 'EJ', 'EK', 'EL', 
      'EN', 'EO', 'EP', 'EQ', 'ER', 'ES', 'ET', 'EU', 'EV', 'EW', 'EX', 'EY', 'EZ'
    ],
    'Prime Internacional': [
      'LA', 'LB', 'LC', 'LD', 'LE', 'LF', 'LG', 'LH', 'LI', 'LJ', 'LK', 'LL', 
      'LM', 'LN', 'LO', 'LP', 'LQ', 'LR', 'LS', 'LT', 'LU', 'LV', 'LW', 'LX', 
      'LY', 'LZ'
    ],
    'Packet Standard': ['NA', 'NB', 'NC', 'ND', 'NL', 'NM', 'NN', 'NO', 'NX'],
    'Packet Express': ['IX', 'KL', 'YL'],
    'Packet Mini': ['XP'],
    
    'Importação': [
      'UA', 'UB', 'UC', 'UD', 'UE', 'UF', 'UG', 'UH', 'UI', 'UJ', 'UK', 'UL', 
      'UM', 'UN', 'UO', 'UP', 'UQ', 'UR', 'US', 'UT', 'UU', 'UV', 'UW', 'UX', 
      'UY', 'UZ'
    ],
    'Tributado': ['XR', 'XX', 'XA'],
    
    'Carta': [
      'BD', 'BE', 'BG', 'BH', 'BI', 'BJ', 'BK', 'BL', 'BN', 'BO', 'BP', 'BR', 
      'BT', 'BV', 'BY', 'BZ', 'DT', 'FJ', 'JA', 'JB', 'JD', 'JE', 'JF', 'JI', 
      'JK', 'JQ', 'JV', 'JW', 'JX', 'JY', 'JZ', 'MH', 'MI', 'YB', 'YC'
    ],
    'Registrado': [
      'FA', 'FB', 'FC', 'FD', 'FF', 'FH', 'FM', 'FR', 'JC', 'JG', 'JH', 'JJ', 
      'JL', 'JO', 'JR', 'JS', 'JT', 'JU', 'RA', 'RC', 'RJ', 'RK', 'RM', 'RO', 
      'RQ', 'YA', 'YG', 'YI', 'YJ', 'YM', 'YN', 'YO', 'YP', 'YQ', 'YR'
    ],
    'Mala Direta': ['JM', 'JN', 'MD', 'RE', 'YD'],
    
    'Expresso': ['BC', 'BF', 'DB', 'DC', 'DE', 'DI', 'DR', 'DS', 'ST', 'SV', 'SY', 'YF'],
    'Telegrama': [
      'MA', 'MB', 'MC', 'ME', 'MF', 'MG', 'MJ', 'MK', 'MM', 'MN', 'MO', 'MP', 
      'MT', 'MV', 'MW', 'MY', 'MZ', 'NE'
    ],
    'Logística': [
      'FE', 'IA', 'IB', 'IC', 'ID', 'IE', 'IH', 'II', 'IK', 'IM', 'IP', 'IR', 
      'IS', 'IT', 'IU'
    ],
    'Sedex Mundi': ['EM', 'XM'],
  };

  // Cache para o mapa reverso (gerado sob demanda)
  static Map<String, String>? _cachedPrefixMap;

  // Getter que constrói o mapa apenas uma vez
  static Map<String, String> get _prefixMap {
    if (_cachedPrefixMap != null) return _cachedPrefixMap!;
    
    _cachedPrefixMap = {};
    _prefixGroups.forEach((type, prefixes) {
      for (var prefix in prefixes) {
        _cachedPrefixMap![prefix] = type;
      }
    });
    return _cachedPrefixMap!;
  }

  // Lógica da API Wonca Labs
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
      
      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          
          if (data['json'] != null) {
            final trackingData = json.decode(data['json']);
            
            if (trackingData['eventos'] != null && trackingData['eventos'] is List) {
              final eventos = trackingData['eventos'] as List;
              debugPrint('📋 Total de eventos: ${eventos.length}');

              final events = eventos.map((evento) {
                // Parse da data
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

                // Descrição e local
                final descricao = evento['descricao'] ?? evento['descricaoFrontEnd'] ?? '';
                final descricaoWeb = evento['descricaoWeb'] ?? '';

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

                return TrackingEvent(
                  status: descricaoWeb.isNotEmpty ? descricaoWeb : descricao,
                  description: descricao,
                  location: location,
                  dateTime: eventDate,
                );
              }).toList();

              return events;
            } else {
              debugPrint('❌ Chave "eventos" NÃO encontrada ou inválida no tracking!');
              return [];
            }
          } else {
            debugPrint('❌ Chave "json" NÃO encontrada na resposta!');
          }
        } catch (e, stack) {
          debugPrint('❌ Erro ao parsear JSON: $e');
          debugPrint('Stack: ${stack.toString().substring(0, 300)}');
        }
      } else {
        debugPrint('❌ Erro HTTP: ${response.statusCode}');
      }

      return [];
    } catch (e) {
      debugPrint('❌ Erro ao rastrear: $e');

      // Retry logic - tenta até 3 vezes
      if (retryCount < 2) {
        debugPrint('🔄 Tentando novamente em 2 segundos...');
        await Future.delayed(const Duration(seconds: 2));
        return trackPackage(trackingCode, retryCount: retryCount + 1);
      }

      debugPrint('❌ Falhou após 3 tentativas');
      return [];
    }
  }

  // Lógica de classificação robusta
  static String getPackageType(String trackingCode) {
    if (trackingCode.isEmpty || trackingCode.length < 2) {
      return 'Outros';
    }

    final prefix = trackingCode.substring(0, 2).toUpperCase();
    
    // 1. Tenta encontrar a sigla específica no mapa gerado
    if (_prefixMap.containsKey(prefix)) {
      return _prefixMap[prefix]!;
    }

    // 2. Fallback genérico por letra inicial (caso a sigla não esteja na lista)
    final firstLetter = prefix[0];
    
    switch (firstLetter) {
      case 'A': // Geralmente SEDEX ou PAC (Misturados)
      case 'D': // Geralmente SEDEX
      case 'O': // Geralmente SEDEX ou PAC
      case 'S': 
        if (prefix.startsWith('S')) return 'SEDEX';
        return 'Encomenda Nacional';
        
      case 'E': return 'EMS Internacional';
      case 'F': return 'Sedex/Registrado'; // Alguns F são sedex
        
      case 'L': // Prime
      case 'C': // Colis
      case 'U': // Importação
      case 'V': // Valor Declarado
      case 'R': // Registrado
        return 'Internacional/Registrado';
        
      case 'P': return 'PAC';
      case 'I': return 'Internacional';
        
      case 'B': 
      case 'J': 
        return 'Carta/Registrado';
        
      default:
        return 'Encomenda (Outros)';
    }
  }

  static bool isValidTrackingCode(String code) {
    if (code.isEmpty) return false;
    // Formato: 2 letras + 9 números + 2 letras
    final regex = RegExp(r'^[A-Z]{2}\d{9}[A-Z]{2}$');
    return regex.hasMatch(code.toUpperCase());
  }
}