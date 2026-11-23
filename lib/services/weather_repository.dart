import 'package:flutter/foundation.dart';
import '../models/weather.dart';
import 'cptec_client.dart';
import 'local_store.dart';

// Informa se a previsão veio do serviço ou do cache e se há algum aviso.
class ForecastResult {
  const ForecastResult(this.forecast, {this.fromCache = false, this.notice});
  final Forecast forecast;
  final bool fromCache;
  final String? notice;
}

// Coordena as consultas ao serviço e a atualização do histórico local.
class WeatherRepository extends ChangeNotifier {
  WeatherRepository({required this.client, required this.store});
  final CptecClient client;
  final LocalStore store;
  List<Forecast> _recent = [];
  String? storageNotice;

  List<Forecast> get recent => List.unmodifiable(_recent);

  // Recupera o histórico ao abrir o app. Uma falha aqui não bloqueia a busca.
  Future<void> initialize() async {
    try {
      _recent = await store.load();
    } catch (_) {
      storageNotice =
          'Não foi possível recuperar as consultas salvas. '
          'Você pode continuar pesquisando normalmente.';
    }
  }

  // Procura uma consulta salva pelo código da cidade.
  Forecast? cached(String id) {
    for (final forecast in _recent) {
      if (forecast.city.id == id) return forecast;
    }
    return null;
  }

  Future<List<City>> searchCities(String query) => client.searchCities(query);

  Future<ForecastResult> fetchForecast(City city) async {
    late final Forecast forecast;
    try {
      forecast = await client.fetchForecast(city);
    } on WeatherException catch (error) {
      // Em caso de falha, só aproveita o cache da mesma cidade.
      final saved = cached(city.id);
      if (saved == null) rethrow;
      return ForecastResult(saved, fromCache: true, notice: error.message);
    }
    // Coloca a consulta no início e remove a versão anterior dessa cidade.
    _recent = [
      forecast,
      ..._recent.where((item) => item.city.id != city.id),
    ].take(8).toList();
    String? notice;
    try {
      await store.save(_recent);
      storageNotice = null;
    } catch (_) {
      // A previsão recebida continua disponível mesmo se a gravação falhar.
      notice =
          'Previsão recebida, mas não foi possível salvá-la no dispositivo.';
      storageNotice = notice;
    }
    // A tela de busca acompanha essa mudança para atualizar o histórico.
    notifyListeners();
    return ForecastResult(forecast, notice: notice);
  }

  @override
  void dispose() {
    client.close();
    super.dispose();
  }
}
