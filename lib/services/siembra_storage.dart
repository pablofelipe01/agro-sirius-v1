import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/siembra.dart';

const String _siembrasKey = 'siembras_historial';

class SiembraStorage {
  // Guardar una siembra confirmada
  static Future<void> guardarSiembra(Siembra siembra) async {
    final siembras = await obtenerSiembras();

    // Evitar duplicados por ID
    final existe = siembras.any((s) => s.id == siembra.id);
    if (!existe) {
      siembras.insert(0, siembra); // Agregar al inicio (mas reciente primero)
      await _guardarLista(siembras);
    }
  }

  // Obtener todas las siembras guardadas
  static Future<List<Siembra>> obtenerSiembras() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_siembrasKey);

    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList
          .map((item) => Siembra.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Obtener siembras filtradas por fecha
  static Future<List<Siembra>> obtenerSiembrasPorFecha({
    DateTime? desde,
    DateTime? hasta,
  }) async {
    final siembras = await obtenerSiembras();

    return siembras.where((s) {
      if (desde != null && s.fecha.isBefore(desde)) return false;
      if (hasta != null && s.fecha.isAfter(hasta)) return false;
      return true;
    }).toList();
  }

  // Obtener siembras de hoy
  static Future<List<Siembra>> obtenerSiembrasHoy() async {
    final hoy = DateTime.now();
    final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);
    final finHoy = inicioHoy.add(const Duration(days: 1));

    return obtenerSiembrasPorFecha(desde: inicioHoy, hasta: finHoy);
  }

  // Eliminar una siembra por ID
  static Future<void> eliminarSiembra(String id) async {
    final siembras = await obtenerSiembras();
    siembras.removeWhere((s) => s.id == id);
    await _guardarLista(siembras);
  }

  // Limpiar todo el historial
  static Future<void> limpiarHistorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_siembrasKey);
  }

  // Obtener cantidad de siembras
  static Future<int> contarSiembras() async {
    final siembras = await obtenerSiembras();
    return siembras.length;
  }

  // Guardar lista completa
  static Future<void> _guardarLista(List<Siembra> siembras) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = siembras.map((s) => s.toJson()).toList();
    await prefs.setString(_siembrasKey, json.encode(jsonList));
  }
}
