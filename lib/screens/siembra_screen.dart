import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/meshtastic_service.dart';
import '../models/siembra.dart';
import '../widgets/siembra_card.dart';

class SiembraScreen extends StatefulWidget {
  const SiembraScreen({super.key});

  @override
  State<SiembraScreen> createState() => _SiembraScreenState();
}

class _SiembraScreenState extends State<SiembraScreen> {
  // Opciones de cultivo
  final Map<String, List<String>> _cultivoVariedades = {
    'Café': ['Balanceado', 'Frutal', 'Fuerte'],
    'Cacao': ['Criollo', 'Forastero', 'Trinitario'],
    'Cítricos': ['Naranja Valencia', 'Limón Tahití', 'Mandarina'],
  };

  // Lotes y Sectores
  final List<String> _lotes = List.generate(10, (i) => 'Lote ${i + 1}');
  final List<String> _sectores = [
    'Sector A',
    'Sector B',
    'Sector C',
    'Sector D',
    'Sector E',
    'Sector F',
    'Sector G',
    'Sector H',
    'Sector I',
    'Sector J'
  ];

  // Valores seleccionados
  String _cultivoSeleccionado = 'Café';
  String _variedadSeleccionada = 'Balanceado';
  String _loteSeleccionado = 'Lote 1';
  String _sectorSeleccionado = 'Sector A';

  final TextEditingController _notasController = TextEditingController();

  Siembra? _ultimaSiembra;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();

    // Escuchar respuestas del Gateway
    final service = Provider.of<MeshtasticService>(context, listen: false);
    service.siembraResponseStream.listen((response) {
      if (_ultimaSiembra != null) {
        final siembraConfirmada =
            Siembra.fromGatewayResponse(response, _ultimaSiembra!);
        if (siembraConfirmada != null) {
          setState(() {
            _ultimaSiembra = siembraConfirmada;
            _enviando = false;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Siembra registrada: ${siembraConfirmada.id}'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      }
    });
  }

  Future<void> _registrarSiembra() async {
    setState(() {
      _enviando = true;
    });

    final service = Provider.of<MeshtasticService>(context, listen: false);

    // Obtener GPS del T1000-E
    final gps = await service.getGPSLocation();

    // Crear registro de siembra
    final siembra = Siembra(
      id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
      fecha: DateTime.now(),
      cultivo: _cultivoSeleccionado,
      variedad: _variedadSeleccionada,
      lote: _loteSeleccionado,
      sector: _sectorSeleccionado,
      gpsLat: gps?['lat'],
      gpsLon: gps?['lon'],
      notas: _notasController.text.trim().isEmpty
          ? null
          : _notasController.text.trim(),
    );

    // Enviar vía mesh
    final enviado = await service.sendSiembra(siembra.toMeshMessage());

    if (enviado) {
      setState(() {
        _ultimaSiembra = siembra;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Siembra enviada al Gateway, esperando confirmación...'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } else {
      setState(() {
        _enviando = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error enviando siembra'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _nuevaSiembra() {
    setState(() {
      _ultimaSiembra = null;
      _notasController.clear();
      _enviando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<MeshtasticService>(context);

    if (!service.isConnected) {
      return const Center(
        child: Text('No conectado a dispositivo Meshtastic'),
      );
    }

    if (_ultimaSiembra != null && _ultimaSiembra!.status == 'confirmado') {
      return SiembraCard(
        siembra: _ultimaSiembra!,
        onNueva: _nuevaSiembra,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Nueva Siembra',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),

          // Cultivo Principal
          const Text('Cultivo Principal',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          InputDecorator(
            decoration: const InputDecoration(border: OutlineInputBorder()),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _cultivoSeleccionado,
                isExpanded: true,
                isDense: true,
                items: _cultivoVariedades.keys.map((cultivo) {
                  return DropdownMenuItem(value: cultivo, child: Text(cultivo));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _cultivoSeleccionado = value!;
                    _variedadSeleccionada = _cultivoVariedades[value]!.first;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Variedad
          const Text('Variedad',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          InputDecorator(
            decoration: const InputDecoration(border: OutlineInputBorder()),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _variedadSeleccionada,
                isExpanded: true,
                isDense: true,
                items: _cultivoVariedades[_cultivoSeleccionado]!.map((variedad) {
                  return DropdownMenuItem(value: variedad, child: Text(variedad));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _variedadSeleccionada = value!;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Lote
          const Text('Lote', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          InputDecorator(
            decoration: const InputDecoration(border: OutlineInputBorder()),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _loteSeleccionado,
                isExpanded: true,
                isDense: true,
                items: _lotes.map((lote) {
                  return DropdownMenuItem(value: lote, child: Text(lote));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _loteSeleccionado = value!;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Sector
          const Text('Sector', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          InputDecorator(
            decoration: const InputDecoration(border: OutlineInputBorder()),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _sectorSeleccionado,
                isExpanded: true,
                isDense: true,
                items: _sectores.map((sector) {
                  return DropdownMenuItem(value: sector, child: Text(sector));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _sectorSeleccionado = value!;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          // GPS Status
          FutureBuilder<Map<String, double>?>(
            future: service.getGPSLocation(),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data != null) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    border: Border.all(color: Colors.green),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.green),
                      const SizedBox(width: 8),
                      Text(
                        'GPS: ${snapshot.data!['lat']!.toStringAsFixed(4)}, ${snapshot.data!['lon']!.toStringAsFixed(4)}',
                        style: TextStyle(color: Colors.green[800]),
                      ),
                    ],
                  ),
                );
              }
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  border: Border.all(color: Colors.orange),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_off, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text('GPS no disponible',
                        style: TextStyle(color: Colors.orange[800])),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Notas
          const Text('Notas (opcional)',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _notasController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Observaciones adicionales...',
            ),
            maxLines: 3,
            maxLength: 100,
          ),
          const SizedBox(height: 24),

          // Botón Registrar
          ElevatedButton.icon(
            onPressed: _enviando ? null : _registrarSiembra,
            icon: _enviando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.agriculture),
            label: Text(_enviando ? 'Enviando...' : 'Registrar Siembra'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _notasController.dispose();
    super.dispose();
  }
}
