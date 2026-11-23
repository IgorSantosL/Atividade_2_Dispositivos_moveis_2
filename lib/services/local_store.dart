import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/weather.dart';

// Grava e recupera as últimas consultas no armazenamento do dispositivo.
class LocalStore {
  static const key = 'horizonte.forecasts.v1';

  // Lê o JSON salvo e transforma cada registro em uma previsão.
  Future<List<Forecast>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(key);
    // Na primeira execução ainda não existe histórico.
    if (raw == null) return [];
    final data = jsonDecode(raw) as Map<String, dynamic>;
    // A versão identifica o formato dos dados armazenados.
    if (data['version'] != 1) {
      throw const FormatException('Cache incompatível.');
    }
    return (data['forecasts'] as List)
        .map((item) => Forecast.fromJson(item as Map<String, dynamic>))
        .take(8)
        .toList();
  }

  // Salva até oito consultas em uma única chave do SharedPreferences.
  Future<void> save(List<Forecast> forecasts) async {
    final preferences = await SharedPreferences.getInstance();
    final success = await preferences.setString(
      key,
      jsonEncode({
        'version': 1,
        'forecasts': forecasts.take(8).map((item) => item.toJson()).toList(),
      }),
    );
    if (!success) throw StateError('Não foi possível salvar os dados.');
  }
}
