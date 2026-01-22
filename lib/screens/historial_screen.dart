import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/siembra.dart';
import '../services/siembra_storage.dart';

class HistorialScreen extends StatefulWidget {
  const HistorialScreen({super.key});

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  List<Siembra> _siembras = [];
  bool _cargando = true;
  String _filtro = 'todos'; // 'todos', 'hoy', 'semana'

  @override
  void initState() {
    super.initState();
    _cargarSiembras();
  }

  Future<void> _cargarSiembras() async {
    setState(() => _cargando = true);

    List<Siembra> siembras;

    switch (_filtro) {
      case 'hoy':
        siembras = await SiembraStorage.obtenerSiembrasHoy();
        break;
      case 'semana':
        final hace7Dias = DateTime.now().subtract(const Duration(days: 7));
        siembras = await SiembraStorage.obtenerSiembrasPorFecha(desde: hace7Dias);
        break;
      default:
        siembras = await SiembraStorage.obtenerSiembras();
    }

    setState(() {
      _siembras = siembras;
      _cargando = false;
    });
  }

  Future<void> _confirmarLimpiarHistorial() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpiar Historial'),
        content: const Text(
            'Esto eliminara todos los registros del historial local. Esta accion no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar Todo'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await SiembraStorage.limpiarHistorial();
      _cargarSiembras();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Historial eliminado'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _mostrarDetalle(Siembra siembra) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _DetallesSiembra(siembra: siembra),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filtros
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Text('Filtrar:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFiltroChip('Todos', 'todos'),
                      const SizedBox(width: 8),
                      _buildFiltroChip('Hoy', 'hoy'),
                      const SizedBox(width: 8),
                      _buildFiltroChip('Ultima semana', 'semana'),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: _siembras.isEmpty ? null : _confirmarLimpiarHistorial,
                tooltip: 'Limpiar historial',
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Contenido
        Expanded(
          child: _cargando
              ? const Center(child: CircularProgressIndicator())
              : _siembras.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _cargarSiembras,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _siembras.length,
                        itemBuilder: (context, index) {
                          return _buildSiembraItem(_siembras[index]);
                        },
                      ),
                    ),
        ),

        // Contador
        Container(
          padding: const EdgeInsets.all(8),
          color: Colors.grey[100],
          child: Text(
            '${_siembras.length} registro${_siembras.length == 1 ? '' : 's'}',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildFiltroChip(String label, String valor) {
    final seleccionado = _filtro == valor;
    return FilterChip(
      label: Text(label),
      selected: seleccionado,
      onSelected: (selected) {
        setState(() => _filtro = valor);
        _cargarSiembras();
      },
      selectedColor: Colors.green[100],
      checkmarkColor: Colors.green[800],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No hay registros',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _filtro == 'todos'
                ? 'Las siembras confirmadas apareceran aqui'
                : 'No hay siembras en este periodo',
            style: TextStyle(color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSiembraItem(Siembra siembra) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green[100],
          child: Icon(Icons.agriculture, color: Colors.green[700]),
        ),
        title: Text(
          '${siembra.cultivo} - ${siembra.variedad}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${siembra.lote}, ${siembra.sector}'),
            Text(
              DateFormat('dd/MM/yyyy HH:mm').format(siembra.fecha),
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              siembra.status == 'confirmado'
                  ? Icons.check_circle
                  : Icons.pending,
              color: siembra.status == 'confirmado' ? Colors.green : Colors.orange,
              size: 20,
            ),
            const SizedBox(height: 4),
            const Icon(Icons.chevron_right, size: 16),
          ],
        ),
        onTap: () => _mostrarDetalle(siembra),
        isThreeLine: true,
      ),
    );
  }
}

// Widget para mostrar detalles de una siembra
class _DetallesSiembra extends StatelessWidget {
  final Siembra siembra;

  const _DetallesSiembra({required this.siembra});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.agriculture, color: Colors.green[700], size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${siembra.cultivo} - ${siembra.variedad}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'ID: ${siembra.id}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: siembra.status == 'confirmado'
                      ? Colors.green[100]
                      : Colors.orange[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  siembra.status == 'confirmado' ? 'Confirmado' : 'Pendiente',
                  style: TextStyle(
                    color: siembra.status == 'confirmado'
                        ? Colors.green[800]
                        : Colors.orange[800],
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 32),

          // Detalles
          _buildDetalleRow(Icons.calendar_today, 'Fecha',
              DateFormat('dd/MM/yyyy HH:mm').format(siembra.fecha)),
          _buildDetalleRow(Icons.location_on, 'Ubicacion',
              '${siembra.lote}, ${siembra.sector}'),
          if (siembra.gpsLat != null && siembra.gpsLon != null)
            _buildDetalleRow(Icons.gps_fixed, 'GPS',
                '${siembra.gpsLat!.toStringAsFixed(4)}, ${siembra.gpsLon!.toStringAsFixed(4)}'),
          if (siembra.notas != null && siembra.notas!.isNotEmpty)
            _buildDetalleRow(Icons.note, 'Notas', siembra.notas!),

          const SizedBox(height: 24),

          // Boton cerrar
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetalleRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(fontSize: 15),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
