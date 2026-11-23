import 'dart:io';
import 'package:previsao_do_tempo/services/cptec_client.dart';

// Execute com dart run tool/check_service.dart para consultar o serviço real.
Future<void> main() async {
  final api = CptecClient();
  try {
    final cities = await api.searchCities('São Paulo');
    if (cities.isEmpty) throw StateError('A busca não retornou cidades.');
    // Consulta a primeira cidade encontrada e imprime a previsão no terminal.
    final forecast = await api.fetchForecast(cities.first);
    stdout.writeln('Cidade: ${forecast.city.label} (ID ${forecast.city.id})');
    stdout.writeln('Atualização: ${forecast.updatedAt}');
    stdout.writeln('Dias retornados: ${forecast.days.length}');
    for (final day in forecast.days) {
      stdout.writeln(
        '${day.date}: ${day.minimum} a ${day.maximum} °C; ${day.conditionCode}; IUV ${day.uvIndex}',
      );
    }
  } catch (error) {
    stderr.writeln(error);
    // Retorna um código de falha para quem executar este arquivo pelo terminal.
    exitCode = 1;
  } finally {
    api.close();
  }
}
