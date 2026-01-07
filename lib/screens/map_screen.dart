import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

class MapScreen extends StatefulWidget {
  final String packageLocation; // Ex: "Curitiba / PR"
  final String userLocation;    // Ex: "São Paulo / SP"

  const MapScreen({
    super.key,
    required this.packageLocation,
    required this.userLocation,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  LatLng? _startPoint;
  LatLng? _endPoint;
  bool _isLoading = true;
  String _error = '';
  double _distanceKm = 0.0;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _loadCoordinates();
  }

  Future<void> _loadCoordinates() async {
    try {
      // 1. Buscar coordenadas (Geocoding)
      final start = await _getCoordinates(widget.packageLocation);
      final end = await _getCoordinates(widget.userLocation);

      if (start != null && end != null) {
        setState(() {
          _startPoint = start;
          _endPoint = end;
          // 2. Calcular Distância (Linha reta aproximada)
          const distance = Distance();
          _distanceKm = distance.as(LengthUnit.Kilometer, start, end);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Não foi possível encontrar uma das localizações.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Erro de conexão: $e';
        _isLoading = false;
      });
    }
  }

  // Usa a API gratuita Nominatim do OpenStreetMap
  Future<LatLng?> _getCoordinates(String query) async {
    // Limpeza básica da string para melhorar a busca
    final cleanQuery = query
        .replaceAll('Unidade de Tratamento em ', '')
        .replaceAll('Unidade de Distribuição em ', '')
        .replaceAll('Objeto postado em ', '')
        .trim();

    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$cleanQuery&format=json&limit=1');

    // O Nominatim exige um User-Agent válido
    final response = await http.get(url, headers: {
      'User-Agent': 'RastreioDex/1.0 (com.agiomartinez.rastreiodex)'
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List && data.isNotEmpty) {
        final lat = double.parse(data[0]['lat']);
        final lon = double.parse(data[0]['lon']);
        return LatLng(lat, lon);
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Distância Estimada')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(child: Text(_error, style: const TextStyle(color: Colors.red)))
              : Column(
                  children: [
                    // --- Informação da Distância ---
                    Container(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildLocationInfo('Pacote', widget.packageLocation, Icons.local_shipping),
                          Column(
                            children: [
                              Text(
                                '${_distanceKm.toStringAsFixed(0)} km',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 20),
                              ),
                              const Text('Distância', style: TextStyle(fontSize: 10)),
                            ],
                          ),
                          _buildLocationInfo('Você', widget.userLocation, Icons.person_pin_circle),
                        ],
                      ),
                    ),
                    
                    // --- O Mapa ---
                    Expanded(
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCameraFit: CameraFit.bounds(
                            bounds: LatLngBounds(_startPoint!, _endPoint!),
                            padding: const EdgeInsets.all(50),
                          ),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.agiomartinez.rastreiodex',
                          ),
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: [_startPoint!, _endPoint!],
                                strokeWidth: 4,
                                color: Colors.blue,
                                // CORREÇÃO AQUI: isDotted substituído por pattern
                                pattern: const StrokePattern.dotted(),
                              ),
                            ],
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: _startPoint!,
                                width: 80,
                                height: 80,
                                child: const Icon(Icons.local_shipping,
                                    color: Colors.blue, size: 40),
                              ),
                              Marker(
                                point: _endPoint!,
                                width: 80,
                                height: 80,
                                child: const Icon(Icons.person_pin_circle,
                                    color: Colors.red, size: 40),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildLocationInfo(String label, String city, IconData icon) {
    // Pega apenas a cidade (antes da barra ou vírgula)
    final shortCity = city.split('/')[0].split(',')[0].trim();
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).primaryColor),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        Text(shortCity, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
