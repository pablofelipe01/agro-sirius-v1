import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/meshtastic_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  LoraRegion _selectedRegion = LoraRegion.unset;
  bool _isApplying = false;

  @override
  void initState() {
    super.initState();
    _loadSavedRegion();
  }

  Future<void> _loadSavedRegion() async {
    final service = Provider.of<MeshtasticService>(context, listen: false);
    final savedRegion = await service.getSavedLoraRegion();
    setState(() {
      _selectedRegion = savedRegion;
    });
  }

  Future<void> _applyConfiguration() async {
    setState(() => _isApplying = true);

    final service = Provider.of<MeshtasticService>(context, listen: false);
    final success = await service.setLoraRegion(_selectedRegion);

    setState(() => _isApplying = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'Configuracion aplicada: ${_selectedRegion.displayName}'
              : 'Error aplicando configuracion'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _disconnectDevice() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desconectar'),
        content: const Text('Deseas desconectar el dispositivo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Desconectar'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final service = Provider.of<MeshtasticService>(context, listen: false);
      await service.disconnect();
    }
  }

  Future<void> _changeDevice() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cambiar Nodo'),
        content: const Text(
            'Esto desconectara el dispositivo actual y te llevara a seleccionar uno nuevo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final service = Provider.of<MeshtasticService>(context, listen: false);
      await service.disconnect(clearDevice: true);

      if (mounted) {
        // Navegar a la pantalla de seleccion de dispositivo
        Navigator.of(context).pushNamedAndRemoveUntil('/select-device', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<MeshtasticService>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Seccion: Informacion del Nodo
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        service.isConnected
                            ? Icons.bluetooth_connected
                            : Icons.bluetooth_disabled,
                        color: service.isConnected ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Dispositivo Conectado',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const Divider(),
                  _buildInfoRow('Nombre', service.connectedDeviceName ?? 'No conectado'),
                  _buildInfoRow('MAC', service.connectedDeviceMac ?? '-'),
                  _buildInfoRow(
                    'Estado',
                    service.statusMessage,
                    valueColor: service.isConnected ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(height: 16),
                  if (service.isConnected)
                    OutlinedButton.icon(
                      onPressed: _disconnectDevice,
                      icon: const Icon(Icons.bluetooth_disabled),
                      label: const Text('Desconectar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Seccion: Configuracion LoRa
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.settings_input_antenna, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        'Configuracion LoRa',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const Divider(),
                  const Text(
                    'Region',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  InputDecorator(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<LoraRegion>(
                        value: _selectedRegion,
                        isExpanded: true,
                        items: LoraRegion.values.map((region) {
                          return DropdownMenuItem(
                            value: region,
                            child: Text(region.displayName),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _selectedRegion = value!);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: service.isConnected && !_isApplying
                          ? _applyConfiguration
                          : null,
                      icon: _isApplying
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: Text(_isApplying ? 'Aplicando...' : 'Aplicar Configuracion'),
                    ),
                  ),
                  if (!service.isConnected)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Conecta un dispositivo para aplicar la configuracion',
                        style: TextStyle(color: Colors.orange, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Seccion: Acciones
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.build, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        'Acciones',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const Divider(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _changeDevice,
                      icon: const Icon(Icons.bluetooth_searching),
                      label: const Text('Cambiar Nodo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Info de version
          Center(
            child: Text(
              'AgroSirius v1.0.2',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
