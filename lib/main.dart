import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'services/meshtastic_service.dart';
import 'screens/siembra_screen.dart';
import 'screens/historial_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => MeshtasticService(),
      child: const AgroSiriusApp(),
    ),
  );
}

class AgroSiriusApp extends StatelessWidget {
  const AgroSiriusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agro Sirius',
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
      ),
      home: const StartupScreen(),
      routes: {
        '/select-device': (context) => const DeviceSelectionScreen(),
        '/main': (context) => const MainScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

// ============ STARTUP SCREEN ============

class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  String _statusText = 'Iniciando...';

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // Solicitar permisos
    setState(() => _statusText = 'Solicitando permisos...');
    await _requestPermissions();

    if (!mounted) return;

    // Verificar si hay dispositivo guardado
    setState(() => _statusText = 'Verificando dispositivo...');
    final service = Provider.of<MeshtasticService>(context, listen: false);
    final savedAddress = await service.getSavedDeviceAddress();

    if (savedAddress != null) {
      // Intentar reconectar
      setState(() => _statusText = 'Conectando...');
      final connected = await service.reconnectToSavedDevice();

      if (mounted) {
        if (connected) {
          Navigator.of(context).pushReplacementNamed('/main');
        } else {
          // No se pudo conectar, ir a seleccion
          Navigator.of(context).pushReplacementNamed('/select-device');
        }
      }
    } else {
      // No hay dispositivo guardado, ir a seleccion
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/select-device');
      }
    }
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green[50],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.agriculture, size: 80, color: Colors.green[700]),
            const SizedBox(height: 24),
            Text(
              'Agro Sirius',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.green[800],
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              _statusText,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

// ============ DEVICE SELECTION SCREEN ============

class DeviceSelectionScreen extends StatefulWidget {
  const DeviceSelectionScreen({super.key});

  @override
  State<DeviceSelectionScreen> createState() => _DeviceSelectionScreenState();
}

class _DeviceSelectionScreenState extends State<DeviceSelectionScreen> {
  final List<ScannedDevice> _devices = [];
  bool _isScanning = false;
  StreamSubscription<ScannedDevice>? _scanSubscription;

  @override
  void initState() {
    super.initState();
    _startScanning();
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    super.dispose();
  }

  void _startScanning() {
    setState(() {
      _devices.clear();
      _isScanning = true;
    });

    final service = Provider.of<MeshtasticService>(context, listen: false);
    _scanSubscription = service.scanDevices().listen(
      (device) {
        setState(() {
          final exists = _devices.any((d) => d.address == device.address);
          if (!exists) {
            _devices.add(device);
          }
        });
      },
      onDone: () {
        if (mounted) {
          setState(() => _isScanning = false);
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() => _isScanning = false);
        }
      },
    );
  }

  Future<void> _selectDevice(ScannedDevice device) async {
    final service = Provider.of<MeshtasticService>(context, listen: false);

    // Mostrar dialogo de conexion
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text('Conectando a ${device.name}...'),
          ],
        ),
      ),
    );

    final connected = await service.connectToDevice(device);

    if (mounted) {
      Navigator.of(context).pop(); // Cerrar dialogo

      if (connected) {
        Navigator.of(context).pushReplacementNamed('/main');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error conectando a ${device.name}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar Dispositivo'),
        actions: [
          if (_isScanning)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _startScanning,
              tooltip: 'Escanear',
            ),
        ],
      ),
      body: Column(
        children: [
          // Status bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: _isScanning ? Colors.blue[50] : Colors.grey[100],
            child: Row(
              children: [
                Icon(
                  _isScanning ? Icons.bluetooth_searching : Icons.bluetooth,
                  color: _isScanning ? Colors.blue : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  _isScanning
                      ? 'Buscando dispositivos Meshtastic...'
                      : 'Toca un dispositivo para conectar',
                  style: TextStyle(
                    color: _isScanning ? Colors.blue[800] : Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),

          // Lista de dispositivos
          Expanded(
            child: _devices.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bluetooth_disabled,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isScanning
                              ? 'Buscando dispositivos...'
                              : 'No se encontraron dispositivos',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        if (!_isScanning) ...[
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _startScanning,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Buscar de nuevo'),
                          ),
                        ],
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _devices.length,
                    itemBuilder: (context, index) {
                      final device = _devices[index];
                      return ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.green,
                          child: Icon(Icons.bluetooth, color: Colors.white),
                        ),
                        title: Text(device.name),
                        subtitle: Text(
                          device.address,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _selectDevice(device),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ============ MAIN SCREEN ============

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const SiembraScreen(),
    const HistorialScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<MeshtasticService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agro Sirius'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Icon(
                  service.isConnected
                      ? Icons.bluetooth_connected
                      : Icons.bluetooth_disabled,
                  color: service.isConnected ? Colors.green : Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  service.isConnected ? 'OK' : 'OFF',
                  style: TextStyle(
                    fontSize: 12,
                    color: service.isConnected ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.agriculture),
            label: 'Siembra',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Historial',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Ajustes',
          ),
        ],
      ),
    );
  }
}
