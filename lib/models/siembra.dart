import 'package:intl/intl.dart';

class Siembra {
  final String id;
  final DateTime fecha;
  final String cultivo;
  final String variedad;
  final String lote;
  final String sector;
  final double? gpsLat;
  final double? gpsLon;
  final String? notas;
  final String status; // 'pendiente', 'confirmado', 'error'

  Siembra({
    required this.id,
    required this.fecha,
    required this.cultivo,
    required this.variedad,
    required this.lote,
    required this.sector,
    this.gpsLat,
    this.gpsLon,
    this.notas,
    this.status = 'pendiente',
  });

  // Generar mensaje mesh en formato: SIEMBRA|fecha|hora|cultivo|variedad|lote|sector|hectareas|gps|notas
  // Nota: hectareas se envia como "0" para compatibilidad con Gateway (fincas preconstruidas)
  String toMeshMessage() {
    final dateStr = DateFormat('yyyy-MM-dd').format(fecha);
    final timeStr = DateFormat('HH:mm').format(fecha);
    final gpsStr = (gpsLat != null && gpsLon != null)
        ? '$gpsLat,$gpsLon'
        : 'sin-gps';
    final notasStr = notas?.isNotEmpty == true ? notas! : 'sin-notas';

    return 'SIEMBRA|$dateStr|$timeStr|$cultivo|$variedad|$lote|$sector|0|$gpsStr|$notasStr';
  }

  // Parsear respuesta del Gateway: SIEMBRA_OK|ID-xxx|mensaje
  static Siembra? fromGatewayResponse(String response, Siembra original) {
    if (!response.startsWith('SIEMBRA_OK|')) return null;

    final parts = response.split('|');
    if (parts.length < 2) return null;

    return Siembra(
      id: parts[1], // ID generado por Gateway
      fecha: original.fecha,
      cultivo: original.cultivo,
      variedad: original.variedad,
      lote: original.lote,
      sector: original.sector,
      gpsLat: original.gpsLat,
      gpsLon: original.gpsLon,
      notas: original.notas,
      status: 'confirmado',
    );
  }
}
