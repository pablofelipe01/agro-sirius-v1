import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:meshtastic_flutter/meshtastic_flutter.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Modelo para dispositivos escaneados
class ScannedDevice {
  final String name;
  final String address;
  final BluetoothDevice rawDevice;

  ScannedDevice({
    required this.name,
    required this.address,
    required this.rawDevice,
  });
}

// Estados de conexion
enum ConnectionStatus {
  disconnected,
  scanning,
  connecting,
  connected,
  error,
}

// Regiones LoRa soportadas
enum LoraRegion {
  unset('UNSET', 'Sin configurar'),
  us('US', '915 MHz'),
  eu433('EU_433', '433 MHz'),
  eu868('EU_868', '868 MHz'),
  cn('CN', '470 MHz'),
  jp('JP', '920 MHz'),
  anz('ANZ', '915 MHz'),
  kr('KR', '920 MHz'),
  tw('TW', '923 MHz'),
  ru('RU', '868 MHz'),
  in_('IN', '865 MHz'),
  nz865('NZ_865', '865 MHz'),
  th('TH', '920 MHz'),
  ua433('UA_433', '433 MHz'),
  ua868('UA_868', '868 MHz'),
  my433('MY_433', '433 MHz'),
  my919('MY_919', '919 MHz'),
  sg923('SG_923', '923 MHz'),
  lora24('LORA_24', '2.4 GHz');

  final String code;
  final String frequency;

  const LoraRegion(this.code, this.frequency);

  String get displayName => '$code ($frequency)';

  static LoraRegion fromCode(String code) {
    return LoraRegion.values.firstWhere(
      (r) => r.code == code,
      orElse: () => LoraRegion.unset,
    );
  }
}

// Keys para SharedPreferences
const String _savedDeviceAddressKey = 'saved_device_address';
const String _savedDeviceNameKey = 'saved_device_name';
const String _loraRegionKey = 'lora_region';
const String _gatewayNodeIdKey = 'gateway_node_id';

// ID del Gateway por defecto (Mission Pack)
const int defaultGatewayNodeId = 0x9ea29bc4;

class MeshtasticService extends ChangeNotifier {
  MeshtasticClient? _client;
  BluetoothDevice? _connectedDevice;
  StreamSubscription? _packetSubscription;
  StreamSubscription? _connectionSubscription;

  // Estado de conexion
  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;
  String _statusMessage = 'Desconectado';
  String? _connectedDeviceName;
  String? _connectedDeviceMac;

  // Stream para respuestas de siembra del Gateway
  final _siembraResponseController = StreamController<String>.broadcast();
  Stream<String> get siembraResponseStream => _siembraResponseController.stream;

  // Getters
  MeshtasticClient? get client => _client;
  bool get isConnected => _connectionStatus == ConnectionStatus.connected;
  ConnectionStatus get connectionStatus => _connectionStatus;
  String get statusMessage => _statusMessage;
  String? get connectedDeviceName => _connectedDeviceName;
  String? get connectedDeviceMac => _connectedDeviceMac;

  // Actualizar estado
  void _updateStatus(ConnectionStatus status, String message) {
    _connectionStatus = status;
    _statusMessage = message;
    notifyListeners();
  }

  // ============ PERSISTENCIA ============

  Future<String?> getSavedDeviceAddress() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_savedDeviceAddressKey);
  }

  Future<String?> getSavedDeviceName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_savedDeviceNameKey);
  }

  Future<void> saveDeviceInfo(String address, String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_savedDeviceAddressKey, address);
    await prefs.setString(_savedDeviceNameKey, name);
  }

  Future<void> clearSavedDevice() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_savedDeviceAddressKey);
    await prefs.remove(_savedDeviceNameKey);
  }

  Future<LoraRegion> getSavedLoraRegion() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_loraRegionKey);
    return code != null ? LoraRegion.fromCode(code) : LoraRegion.unset;
  }

  Future<void> saveLoraRegion(LoraRegion region) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_loraRegionKey, region.code);
  }

  Future<int> getSavedGatewayNodeId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_gatewayNodeIdKey) ?? defaultGatewayNodeId;
  }

  Future<void> saveGatewayNodeId(int nodeId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_gatewayNodeIdKey, nodeId);
  }

  // Convertir string hex (!9ea29bc4) a int
  static int? parseNodeId(String input) {
    String cleaned = input.trim().toLowerCase();
    // Remover prefijo ! si existe
    if (cleaned.startsWith('!')) {
      cleaned = cleaned.substring(1);
    }
    // Remover prefijo 0x si existe
    if (cleaned.startsWith('0x')) {
      cleaned = cleaned.substring(2);
    }
    return int.tryParse(cleaned, radix: 16);
  }

  // Convertir int a string hex con formato !xxxxxxxx
  static String formatNodeId(int nodeId) {
    return '!${nodeId.toRadixString(16).padLeft(8, '0')}';
  }

  // ============ ESCANEO DE DISPOSITIVOS ============

  Future<void> _ensureClientInitialized() async {
    if (_client == null) {
      _client = MeshtasticClient();
      await _client!.initialize();
    }
  }

  Stream<ScannedDevice> scanDevices() async* {
    try {
      _updateStatus(ConnectionStatus.scanning, 'Buscando dispositivos...');
      await _ensureClientInitialized();

      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 6));

      await for (final results in FlutterBluePlus.scanResults) {
        for (var r in results) {
          // Filtrar dispositivos Meshtastic/T1000
          if (r.device.platformName.isNotEmpty &&
              (r.device.platformName.contains('Meshtastic') ||
               r.device.platformName.contains('T1000') ||
               r.device.platformName.contains('T-Echo') ||
               r.device.platformName.contains('RAK'))) {
            yield ScannedDevice(
              name: r.device.platformName,
              address: r.device.remoteId.toString(),
              rawDevice: r.device,
            );
          }
        }
      }

      await FlutterBluePlus.stopScan();
      _updateStatus(ConnectionStatus.disconnected, 'Escaneo completado');
    } catch (e) {
      await FlutterBluePlus.stopScan();
      _updateStatus(ConnectionStatus.error, 'Error escaneando: ${e.toString()}');
    }
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    _updateStatus(ConnectionStatus.disconnected, 'Escaneo detenido');
  }

  // ============ CONEXION ============

  Future<bool> connectToDevice(ScannedDevice device) async {
    try {
      _updateStatus(ConnectionStatus.connecting, 'Conectando a ${device.name}...');
      await _ensureClientInitialized();

      // Escuchar cambios de conexion
      _connectionSubscription = _client!.connectionStream.listen((status) {
        final stateStr = status.state.toString().toLowerCase();
        if (stateStr.contains('connected') && !stateStr.contains('dis')) {
          _updateStatus(ConnectionStatus.connected, 'Conectado a ${device.name}');
          _applyInitialConfig();
        } else if (stateStr.contains('disconnect')) {
          _updateStatus(ConnectionStatus.disconnected, 'Desconectado');
        }
      });

      // Escuchar paquetes entrantes
      _packetSubscription = _client!.packetStream.listen((packet) {
        debugPrint('📦 Paquete recibido: isTextMessage=${packet.isTextMessage}');
        debugPrint('📦 Paquete from: ${packet.from}, to: ${packet.to}');
        if (packet.isTextMessage) {
          debugPrint('📦 Es mensaje de texto, procesando...');
          _handleIncomingMessage(packet);
        } else {
          // Intentar procesar de todas formas si tiene texto
          final text = packet.textMessage;
          if (text != null && text.isNotEmpty) {
            debugPrint('📦 Tiene textMessage aunque isTextMessage=false: $text');
            _handleIncomingMessage(packet);
          }
        }
      });

      // Conectar al dispositivo
      await _client!.connectToDevice(device.rawDevice);

      // Guardar info del dispositivo
      _connectedDeviceName = device.name;
      _connectedDeviceMac = device.address;
      _connectedDevice = device.rawDevice;
      await saveDeviceInfo(device.address, device.name);

      return true;
    } catch (e) {
      _updateStatus(ConnectionStatus.error, 'Error: ${e.toString()}');
      return false;
    }
  }

  Future<bool> reconnectToSavedDevice() async {
    final savedAddress = await getSavedDeviceAddress();
    final savedName = await getSavedDeviceName();

    if (savedAddress == null) return false;

    try {
      _updateStatus(ConnectionStatus.connecting, 'Reconectando a $savedName...');
      await _ensureClientInitialized();

      // Buscar el dispositivo guardado
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));

      BluetoothDevice? targetDevice;

      await for (final results in FlutterBluePlus.scanResults) {
        for (var r in results) {
          if (r.device.remoteId.toString() == savedAddress) {
            targetDevice = r.device;
            break;
          }
        }
        if (targetDevice != null) break;
      }

      await FlutterBluePlus.stopScan();

      if (targetDevice != null) {
        final scannedDevice = ScannedDevice(
          name: savedName ?? 'Dispositivo',
          address: savedAddress,
          rawDevice: targetDevice,
        );
        return await connectToDevice(scannedDevice);
      } else {
        _updateStatus(ConnectionStatus.error, 'No se encontro el dispositivo guardado');
        return false;
      }
    } catch (e) {
      _updateStatus(ConnectionStatus.error, 'Error reconectando: ${e.toString()}');
      return false;
    }
  }

  // ============ CONFIGURACION LORA ============

  Future<void> _applyInitialConfig() async {
    final savedRegion = await getSavedLoraRegion();
    if (savedRegion != LoraRegion.unset) {
      await setLoraRegion(savedRegion);
    }
  }

  Future<bool> setLoraRegion(LoraRegion region) async {
    if (!isConnected || _client == null) {
      return false;
    }

    try {
      // Guardar configuracion localmente
      await saveLoraRegion(region);
      debugPrint('Region LoRa configurada: ${region.displayName}');
      return true;
    } catch (e) {
      debugPrint('Error configurando region LoRa: $e');
      return false;
    }
  }

  // ============ MENSAJES ============

  void _handleIncomingMessage(MeshPacketWrapper packet) {
    try {
      final text = packet.textMessage ?? '';
      debugPrint('📨 Mensaje recibido: "$text"');
      debugPrint('📨 From: ${packet.from}, To: ${packet.to}');

      // Solo procesar respuestas de siembra del Gateway
      if (text.startsWith('SIEMBRA_OK|') || text.startsWith('SIEMBRA_ERROR|')) {
        debugPrint('✅ Respuesta de siembra detectada, enviando a stream');
        _siembraResponseController.add(text);
      } else {
        debugPrint('ℹ️ Mensaje ignorado (no es respuesta de siembra): $text');
      }
    } catch (e) {
      debugPrint('❌ Error procesando mensaje: $e');
    }
  }

  Future<bool> sendSiembra(String siembraMessage) async {
    if (_client == null || !isConnected) return false;

    try {
      final payload = utf8.encode(siembraMessage);

      if (payload.length > 237) {
        throw Exception('Mensaje de siembra muy largo');
      }

      // Obtener el ID del Gateway destino
      final gatewayNodeId = await getSavedGatewayNodeId();

      // Enviar al Gateway especifico (no broadcast)
      await _client!.sendTextMessage(
        siembraMessage,
        destinationId: gatewayNodeId,
        channel: 0,
      );

      debugPrint('Siembra enviada a ${formatNodeId(gatewayNodeId)}: $siembraMessage');
      return true;
    } catch (e) {
      debugPrint('Error enviando siembra: $e');
      return false;
    }
  }

  // ============ GPS ============

  Future<Map<String, double>?> getGPSLocation() async {
    if (_client == null || !isConnected) return null;

    try {
      final myNodeInfo = _client!.myNodeInfo;
      if (myNodeInfo != null) {
        final myNode = _client!.nodes[myNodeInfo.myNodeNum];
        if (myNode != null) {
          final lat = myNode.latitude;
          final lon = myNode.longitude;
          if (lat != null && lon != null && lat != 0 && lon != 0) {
            return {'lat': lat, 'lon': lon};
          }
        }
      }
    } catch (e) {
      debugPrint('Error obteniendo GPS: $e');
    }
    return null;
  }

  // ============ RECONECTAR ============

  Future<bool> reconnect() async {
    if (_connectedDevice == null) return false;

    try {
      debugPrint('🔄 Reconectando al dispositivo...');
      _updateStatus(ConnectionStatus.connecting, 'Reconectando...');

      // Desconectar
      await _packetSubscription?.cancel();
      await _connectionSubscription?.cancel();
      await _client?.disconnect();

      // Esperar un momento
      await Future.delayed(const Duration(seconds: 2));

      // Reconectar
      final device = _connectedDevice!;
      final scannedDevice = ScannedDevice(
        name: _connectedDeviceName ?? 'Dispositivo',
        address: _connectedDeviceMac ?? '',
        rawDevice: device,
      );

      return await connectToDevice(scannedDevice);
    } catch (e) {
      debugPrint('❌ Error reconectando: $e');
      _updateStatus(ConnectionStatus.error, 'Error reconectando');
      return false;
    }
  }

  // ============ DESCONEXION ============

  Future<void> disconnect({bool clearDevice = false}) async {
    await _packetSubscription?.cancel();
    await _connectionSubscription?.cancel();
    await _client?.disconnect();

    _connectedDevice = null;
    _connectedDeviceName = null;
    _connectedDeviceMac = null;

    if (clearDevice) {
      await clearSavedDevice();
    }

    _updateStatus(ConnectionStatus.disconnected, 'Desconectado');
  }

  @override
  void dispose() {
    _packetSubscription?.cancel();
    _connectionSubscription?.cancel();
    _siembraResponseController.close();
    super.dispose();
  }
}
