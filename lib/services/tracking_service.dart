import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/tracking_event.dart';

class TrackingService {
  // Chave de API e URL
  static const String _apiKey = 'Sua-chave-de-api'; // <--- INSIRA SUA CHAVE AQUI
  static const String _apiUrl = 'https://api-labs.wonca.com.br/wonca.labs.v1.LabsService/Track';

  // --- MAPA DE PREFIXOS PARA CLASSIFICAÇÃO ---
  static final Map<String, String> _prefixMap = {
    // SEDEX
    'AA': 'SEDEX', 'AB': 'SEDEX', 'AC': 'SEDEX', 'AD': 'SEDEX', 'AE': 'SEDEX',
    'AJ': 'SEDEX', 'AX': 'SEDEX', 'AY': 'SEDEX', 'AZ': 'SEDEX Hoje',
    'DA': 'SEDEX', 'DD': 'SEDEX 12', 'DF': 'SEDEX', 'DG': 'SEDEX', 'DH': 'SEDEX',
    'DJ': 'SEDEX', 'DK': 'SEDEX', 'DL': 'SEDEX', 'DM': 'SEDEX', 'DN': 'SEDEX',
    'DO': 'SEDEX', 'DP': 'SEDEX', 'DQ': 'SEDEX', 'DU': 'SEDEX', 'DV': 'SEDEX',
    'DW': 'SEDEX', 'DX': 'SEDEX 10', 'DY': 'SEDEX', 'DZ': 'SEDEX',
    'OA': 'SEDEX', 'OB': 'SEDEX', 'OC': 'SEDEX', 'OD': 'SEDEX', 'OE': 'SEDEX 12',
    'OF': 'SEDEX', 'OG': 'SEDEX', 'OH': 'SEDEX', 'OI': 'SEDEX', 'OJ': 'SEDEX',
    'OK': 'SEDEX', 'OM': 'SEDEX', 'ON': 'SEDEX', 'OO': 'SEDEX', 'OP': 'SEDEX',
    'OQ': 'SEDEX', 'OR': 'SEDEX 10', 'OS': 'SEDEX', 'OT': 'SEDEX', 'OU': 'SEDEX',
    'OV': 'SEDEX', 'OW': 'SEDEX Hoje', 'OX': 'SEDEX', 'OY': 'SEDEX', 'OZ': 'SEDEX',
    'QB': 'SEDEX', 'SA': 'SEDEX', 'SB': 'SEDEX 10', 'SC': 'SEDEX a Cobrar',
    'SE': 'SEDEX', 'SF': 'SEDEX', 'SG': 'SEDEX', 'SH': 'SEDEX', 'SI': 'SEDEX',
    'SJ': 'SEDEX Hoje', 'SK': 'SEDEX', 'SL': 'SEDEX', 'SM': 'SEDEX 12',
    'SN': 'SEDEX', 'SO': 'SEDEX', 'SP': 'SEDEX Hoje', 'SQ': 'SEDEX', 'SR': 'SEDEX',
    'SS': 'SEDEX', 'SU': 'SEDEX', 'SW': 'SEDEX', 'SX': 'SEDEX 10', 'SZ': 'SEDEX',
    'TA': 'SEDEX', 'TB': 'SEDEX Hoje', 'TC': 'SEDEX 10', 'TD': 'SEDEX 12',
    'TE': 'SEDEX', 'TF': 'SEDEX', 'TG': 'SEDEX', 'TH': 'SEDEX', 'TI': 'SEDEX',
    'TJ': 'SEDEX', 'TK': 'SEDEX', 'TL': 'SEDEX', 'TM': 'SEDEX 10', 'TN': 'SEDEX',

    // PAC e Mini Envios
    'AK': 'PAC', 'AL': 'PAC', 'AQ': 'PAC', 'AS': 'PAC',
    'AV': 'PAC Mini', 'AW': 'PAC Mini',
    'OL': 'PAC', 'PA': 'PAC', 'PB': 'PAC', 'PC': 'PAC a Cobrar',
    'PD': 'PAC', 'PE': 'PAC', 'PF': 'PAC', 'PG': 'PAC', 'PH': 'PAC',
    'PI': 'PAC', 'PJ': 'PAC', 'PK': 'PAC', 'PL': 'PAC', 'PM': 'PAC',
    'PN': 'PAC', 'PO': 'PAC', 'PP': 'PAC', 'PQ': 'PAC Mini', 'PR': 'PAC Mini',
    'PS': 'PAC', 'PT': 'PAC', 'PU': 'PAC', 'PV': 'PAC', 'PW': 'PAC',
    'PX': 'PAC', 'PY': 'PAC', 'PZ': 'PAC', 'QA': 'PAC', 'QC': 'PAC',
    'QD': 'PAC', 'QE': 'PAC', 'QF': 'PAC', 'QG': 'PAC', 'QH': 'PAC',
    'QI': 'PAC', 'QJ': 'PAC', 'QK': 'PAC', 'QL': 'PAC', 'QM': 'PAC',
    'QN': 'PAC', 'QO': 'PAC Mini', 'QP': 'PAC', 'QQ': 'PAC', 'QR': 'PAC',
    'QS': 'PAC', 'QT': 'PAC', 'QU': 'PAC', 'QV': 'PAC', 'QW': 'PAC',
    'QX': 'PAC', 'QY': 'PAC', 'QZ': 'PAC', 'XL': 'PAC',

    // Internacional (Packet, Prime, EMS, Colis, Importação)
    'AR': 'Internacional', 'CA': 'Internacional', 'CB': 'Internacional',
    'CC': 'Internacional', 'CD': 'Internacional', 'CE': 'Internacional',
    'CF': 'Internacional', 'CG': 'Internacional', 'CH': 'Internacional',
    'CI': 'Internacional', 'CJ': 'Internacional', 'CK': 'Internacional',
    'CL': 'Internacional', 'CM': 'Internacional', 'CN': 'Internacional',
    'CO': 'Internacional', 'CP': 'Internacional', 'CQ': 'Internacional',
    'CR': 'Internacional', 'CS': 'Internacional', 'CT': 'Internacional',
    'CU': 'Internacional', 'CV': 'Internacional', 'CW': 'Internacional',
    'CX': 'Internacional', 'CY': 'Internacional', 'CZ': 'Internacional',
    'EA': 'EMS Internacional', 'EB': 'EMS Internacional', 'EC': 'EMS Internacional',
    'ED': 'EMS Internacional', 'EE': 'EMS Internacional', 'EF': 'EMS Internacional',
    'EG': 'EMS Internacional', 'EH': 'EMS Internacional', 'EI': 'EMS Internacional',
    'EJ': 'EMS Internacional', 'EK': 'EMS Internacional', 'EL': 'EMS Internacional',
    'EM': 'Sedex Mundi', 'EN': 'EMS Internacional', 'EO': 'EMS Internacional',
    'EP': 'EMS Internacional', 'EQ': 'EMS Internacional', 'ER': 'EMS Internacional',
    'ES': 'EMS Internacional', 'ET': 'EMS Internacional', 'EU': 'EMS Internacional',
    'EV': 'EMS Internacional', 'EW': 'EMS Internacional', 'EX': 'EMS Internacional',
    'EY': 'EMS Internacional', 'EZ': 'EMS Internacional',
    'IF': 'Internacional', 'IG': 'Internacional', 'IN': 'Internacional',
    'IX': 'Packet Express', 'KL': 'Packet Express',
    'LA': 'Prime Internacional', 'LB': 'Prime Internacional', 'LC': 'Prime Internacional',
    'LD': 'Prime Internacional', 'LE': 'Prime Internacional', 'LF': 'Prime Internacional',
    'LG': 'Prime Internacional', 'LH': 'Prime Internacional', 'LI': 'Prime Internacional',
    'LJ': 'Prime Internacional', 'LK': 'Prime Internacional', 'LL': 'Prime Internacional',
    'LM': 'Prime Internacional', 'LN': 'Prime Internacional', 'LO': 'Prime Internacional',
    'LP': 'Prime Internacional', 'LQ': 'Prime Internacional', 'LR': 'Prime Internacional',
    'LS': 'Prime Internacional', 'LT': 'Prime Internacional', 'LU': 'Prime Internacional',
    'LV': 'Prime Internacional', 'LW': 'Prime Internacional', 'LX': 'Prime Internacional',
    'LY': 'Prime Internacional', 'LZ': 'Prime Internacional',
    'MS': 'Internacional',
    'NA': 'Packet Standard', 'NB': 'Packet Standard', 'NC': 'Packet Standard',
    'ND': 'Packet Standard', 'NL': 'Packet Standard', 'NM': 'Packet Standard',
    'NN': 'Packet Standard', 'NO': 'Packet Standard', 'NX': 'Packet Standard',
    'UA': 'Importação', 'UB': 'Importação', 'UC': 'Importação',
    'UD': 'Importação', 'UE': 'Importação', 'UF': 'Importação',
    'UG': 'Importação', 'UH': 'Importação', 'UI': 'Importação',
    'UJ': 'Importação', 'UK': 'Importação', 'UL': 'Importação',
    'UM': 'Importação', 'UN': 'Importação', 'UO': 'Importação',
    'UP': 'Importação', 'UQ': 'Importação', 'UR': 'Importação',
    'US': 'Importação', 'UT': 'Importação', 'UU': 'Importação',
    'UV': 'Importação', 'UW': 'Importação', 'UX': 'Importação',
    'UY': 'Importação', 'UZ': 'Importação',
    'VA': 'Internacional', 'VB': 'Internacional', 'VC': 'Internacional',
    'VD': 'Internacional', 'VE': 'Internacional', 'VF': 'Internacional',
    'VG': 'Internacional', 'VH': 'Internacional', 'VI': 'Internacional',
    'VJ': 'Internacional', 'VK': 'Internacional', 'VL': 'Internacional',
    'VM': 'Internacional', 'VN': 'Internacional', 'VO': 'Internacional',
    'VP': 'Internacional', 'VQ': 'Internacional', 'VR': 'Internacional',
    'VS': 'Internacional', 'VT': 'Internacional', 'VU': 'Internacional',
    'VV': 'Internacional', 'VW': 'Internacional', 'VX': 'Internacional',
    'VY': 'Internacional', 'VZ': 'Internacional',
    'XA': 'Aviso Tributado', 'XM': 'Sedex Mundi', 'XP': 'Packet Mini',
    'XR': 'Tributado', 'XX': 'Tributado', 'YL': 'Packet Express',

    // Carta, Registrado, Econômica
    'BD': 'Carta', 'BE': 'Carta', 'BG': 'Carta', 'BH': 'Carta',
    'BI': 'Carta', 'BJ': 'Carta', 'BK': 'Carta', 'BL': 'Carta',
    'BN': 'Carta', 'BO': 'Carta', 'BP': 'Carta', 'BR': 'Carta',
    'BT': 'Carta', 'BV': 'Carta', 'BY': 'Carta', 'BZ': 'Carta',
    'DT': 'Carta',
    'FA': 'Registrado', 'FB': 'Registrado', 'FC': 'Registrado',
    'FD': 'Registrado', 'FF': 'Registrado', 'FH': 'Registrado',
    'FJ': 'Carta', 'FM': 'Registrado', 'FR': 'Registrado',
    'JA': 'Carta', 'JB': 'Carta', 'JC': 'Registrado',
    'JD': 'Carta', 'JE': 'Carta', 'JF': 'Carta',
    'JG': 'Registrado', 'JH': 'Registrado', 'JI': 'Carta',
    'JJ': 'Registrado', 'JK': 'Carta', 'JL': 'Registrado',
    'JM': 'Mala Direta', 'JN': 'Mala Direta', 'JO': 'Registrado',
    'JP': 'Receita Federal', 'JQ': 'Carta', 'JR': 'Registrado',
    'JS': 'Registrado', 'JT': 'Registrado', 'JU': 'Registrado',
    'JV': 'Carta', 'JW': 'Carta', 'JX': 'Carta',
    'JY': 'Carta', 'JZ': 'Carta',
    'MD': 'Mala Direta', 'MH': 'Carta', 'MI': 'Carta',
    'RA': 'Registrado', 'RB': 'Carta Registrada', 'RC': 'Registrado',
    'RJ': 'Registrado', 'RK': 'Registrado', 'RM': 'Registrado',
    'RO': 'Registrado', 'RQ': 'Registrado',
    'YA': 'Registrado', 'YB': 'Carta', 'YC': 'Carta',
    'YD': 'Mala Direta', 'YG': 'Registrado', 'YI': 'Registrado',
    'YJ': 'Registrado', 'YM': 'Registrado', 'YN': 'Registrado',
    'YO': 'Registrado', 'YP': 'Registrado', 'YQ': 'Registrado',
    'YR': 'Registrado',

    // Registrado Internacional
    'RD': 'Internacional', 'RE': 'Mala Direta',
    'RF': 'Internacional', 'RG': 'Internacional', 'RH': 'Internacional',
    'RI': 'Internacional', 'RL': 'Internacional', 'RN': 'Internacional',
    'RP': 'Internacional', 'RR': 'Internacional', 'RS': 'Internacional',
    'RT': 'Internacional', 'RU': 'Internacional', 'RV': 'Internacional',
    'RW': 'Internacional', 'RX': 'Internacional', 'RY': 'Internacional',
    'RZ': 'Internacional',

    // Expresso / Remessa Expressa
    'BC': 'Expresso', 'BF': 'Expresso', 'DB': 'Expresso',
    'DC': 'Expresso', 'DE': 'Expresso', 'DI': 'Expresso',
    'DR': 'Expresso', 'DS': 'Expresso', 'ST': 'Expresso',
    'SV': 'Expresso', 'SY': 'Expresso', 'YF': 'Expresso',

    // Telegrama
    'MA': 'Telegrama', 'MB': 'Telegrama', 'MC': 'Telegrama',
    'ME': 'Telegrama', 'MF': 'Telegrama', 'MG': 'Telegrama',
    'MJ': 'Telegrama', 'MK': 'Telegrama', 'MM': 'Telegrama',
    'MN': 'Telegrama', 'MO': 'Telegrama', 'MP': 'Telegrama',
    'MT': 'Telegrama', 'MV': 'Telegrama', 'MW': 'Telegrama',
    'MY': 'Telegrama', 'MZ': 'Telegrama', 'NE': 'Telegrama',

    // Logística
    'FE': 'Logística', 'IA': 'Logística', 'IB': 'Cargo',
    'IC': 'Logística', 'ID': 'Logística', 'IE': 'Logística',
    'IH': 'Cargo', 'II': 'Logística', 'IK': 'Logística',
    'IM': 'Logística', 'IP': 'Logística', 'IR': 'Logística',
    'IS': 'Logística', 'IT': 'Logística', 'IU': 'Logística',
  };

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
      debugPrint('📄 Tamanho da resposta: ${response.body.length} caracteres');

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

  // Lógica de classificação robusta
  static String getPackageType(String trackingCode) {
    if (trackingCode.isEmpty || trackingCode.length < 2) {
      return 'Outros';
    }

    final prefix = trackingCode.substring(0, 2).toUpperCase();
    
    // 1. Tenta encontrar a sigla exata no mapa
    if (_prefixMap.containsKey(prefix)) {
      return _prefixMap[prefix]!;
    }

    // 2. Fallback por letra inicial se não estiver no mapa
    final firstLetter = prefix[0];
    
    switch (firstLetter) {
      case 'A': // Geralmente SEDEX ou PAC
      case 'D': // Geralmente SEDEX
      case 'O': // Geralmente SEDEX ou PAC
      case 'S': // Geralmente SEDEX
        if (prefix.startsWith('S')) return 'SEDEX';
        return 'Encomenda Nacional';
        
      case 'E': // Geralmente EMS
        return 'EMS Internacional';
        
      case 'L': // Geralmente Prime
      case 'C': // Geralmente Colis
      case 'U': // Geralmente Importação
      case 'V': // Geralmente Valor Declarado Int
      case 'R': // Pode ser registrado ou internacional
        return 'Internacional/Registrado';
        
      case 'P': // Geralmente PAC
        return 'PAC';
        
      case 'I': // Geralmente Internacional ou Integrada
        return 'Internacional';
        
      case 'B': // Remessas
      case 'J': // Registrados
        return 'Carta/Registrado';
        
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
