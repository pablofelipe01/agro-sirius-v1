import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/siembra.dart';

class SiembraCard extends StatelessWidget {
  final Siembra siembra;
  final VoidCallback onNueva;

  const SiembraCard({
    super.key,
    required this.siembra,
    required this.onNueva,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  'Siembra Registrada',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'ID: ${siembra.id}',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: Colors.grey[600],
                  ),
                ),
                const Divider(height: 32),
                _buildInfoRow('Fecha:',
                    DateFormat('dd/MM/yyyy HH:mm').format(siembra.fecha)),
                _buildInfoRow(
                    'Cultivo:', '${siembra.cultivo} - ${siembra.variedad}'),
                _buildInfoRow(
                    'Ubicación:', '${siembra.lote}, ${siembra.sector}'),
                _buildInfoRow('Hectáreas:', '${siembra.hectareas} ha'),
                if (siembra.gpsLat != null && siembra.gpsLon != null)
                  _buildInfoRow('GPS:',
                      '${siembra.gpsLat!.toStringAsFixed(4)}, ${siembra.gpsLon!.toStringAsFixed(4)}'),
                if (siembra.notas != null && siembra.notas!.isNotEmpty)
                  _buildInfoRow('Notas:', siembra.notas!),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: onNueva,
                      icon: const Icon(Icons.add),
                      label: const Text('Nueva Siembra'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}
