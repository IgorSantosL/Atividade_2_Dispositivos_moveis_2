import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../models/weather.dart';

// Leva a mensagem de erro da consulta até a tela que vai exibi-la.
class WeatherException implements Exception {
  const WeatherException(this.message);
  final String message;

  @override
  String toString() => message;
}

// Faz as requisições ao CPTEC e transforma as respostas XML em objetos.
class CptecClient {
  CptecClient({http.Client? client, this.timeout = const Duration(seconds: 15)})
    : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;
  static const host = 'servicos.cptec.inpe.br';

  // Consulta as cidades pelo nome, enviando o parâmetro city sem acentos.
  Future<List<City>> searchCities(String query) async {
    final term = normalizeCity(query);
    if (term.isEmpty) return [];
    final root = await _get(
      Uri.https(host, '/XML/listaCidades', {'city': term}),
      'cidades',
    );
    final nodes = root.findElements('cidade').toList();
    // O código como chave evita repetir uma cidade na lista de resultados.
    final cities = <String, City>{};
    for (final node in nodes) {
      final id = _field(node, 'id');
      final name = _field(node, 'nome');
      // Sem identificador e nome, o resultado não pode ser selecionado.
      if (!RegExp(r'^\d+$').hasMatch(id) ||
          (int.tryParse(id) ?? 0) <= 0 ||
          name.isEmpty) {
        continue;
      }
      cities[id] = City(id: id, name: name, state: _field(node, 'uf'));
    }
    if (nodes.isNotEmpty && cities.isEmpty) throw _invalidResponse;
    return cities.values.toList();
  }

  // Busca a previsão de quatro dias usando o código da cidade selecionada.
  Future<Forecast> fetchForecast(City city) async {
    if (!RegExp(r'^\d+$').hasMatch(city.id) ||
        (int.tryParse(city.id) ?? 0) <= 0) {
      throw const WeatherException('O identificador desta cidade é inválido.');
    }
    final root = await _get(
      Uri.https(host, '/XML/cidade/${city.id}/previsao.xml'),
      'cidade',
    );
    if (root.getElement('erro') != null) throw _invalidResponse;
    // Mantém todos os dias retornados, inclusive com campos ausentes.
    final days = root.findElements('previsao').map((node) {
      final uv = _number(_field(node, 'iuv'));
      return ForecastDay(
        date: _date(_field(node, 'dia')),
        conditionCode: _field(node, 'tempo'),
        minimum: _number(_field(node, 'minima')),
        maximum: _number(_field(node, 'maxima')),
        uvIndex: uv != null && uv >= 0 ? uv : null,
      );
    }).toList();
    return Forecast(
      // O ID é sempre o da busca; não é inferido pelo nome ou pela UF.
      city: City(
        id: city.id,
        name: _field(root, 'nome').isEmpty ? city.name : _field(root, 'nome'),
        state: _field(root, 'uf').isEmpty ? city.state : _field(root, 'uf'),
      ),
      days: days,
      updatedAt: _date(_field(root, 'atualizacao')),
      fetchedAt: DateTime.now(),
    );
  }

  // Confere o status HTTP e a estrutura do XML antes de ler seus campos.
  Future<XmlElement> _get(Uri uri, String expectedRoot) async {
    try {
      final response = await _client.get(uri).timeout(timeout);
      if (response.statusCode != 200) {
        throw const WeatherException(
          'O serviço do CPTEC/INPE está indisponível. Tente novamente mais tarde.',
        );
      }
      final document = XmlDocument.parse(decodeXml(response));
      if (document.rootElement.name.local != expectedRoot ||
          document.rootElement.getElement('erro') != null ||
          document.rootElement.getElement('error') != null) {
        throw _invalidResponse;
      }
      return document.rootElement;
    } on TimeoutException {
      throw const WeatherException(
        'A consulta demorou demais. Verifique sua conexão e tente novamente.',
      );
    } on http.ClientException {
      throw const WeatherException(
        'Não foi possível conectar ao CPTEC/INPE. Verifique sua conexão e tente novamente.',
      );
    } on FormatException {
      throw _invalidResponse;
    } on XmlException {
      throw _invalidResponse;
    } on WeatherException {
      rethrow;
    } on Exception {
      // Falhas de certificado também podem chegar fora de ClientException.
      throw const WeatherException(
        'Não foi possível estabelecer uma conexão segura com o CPTEC/INPE. '
        'Tente novamente mais tarde.',
      );
    }
  }

  // Usa a codificação indicada no XML para preservar os acentos dos nomes.
  static String decodeXml(http.Response response) {
    final bytes = response.bodyBytes;
    final prefix = latin1.decode(bytes.take(200).toList()).toLowerCase();
    final contentType = response.headers['content-type']?.toLowerCase() ?? '';
    final declaration = RegExp(
      '''encoding\\s*=\\s*["']([^"']+)["']''',
    ).firstMatch(prefix)?.group(1);
    // Se o XML não indicar a codificação, consulta o cabeçalho da resposta.
    final encoding = declaration ?? contentType;
    if (encoding.contains('iso-8859-1') || encoding.contains('latin1')) {
      return latin1.decode(bytes);
    }
    return utf8.decode(bytes);
  }

  // Remove acentos e espaços repetidos antes de enviar o nome ao serviço.
  static String normalizeCity(String input) {
    const source = 'áàâãäåéèêëíìîïóòôõöúùûüçñ';
    const target = 'aaaaaaeeeeiiiiooooouuuucn';
    var text = input.trim().toLowerCase();
    for (var i = 0; i < source.length; i++) {
      text = text.replaceAll(source[i], target[i]);
    }
    return text
        .replaceAll(RegExp(r'[\u0300-\u036f]'), '')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  // Retorna texto vazio quando a tag não existe, evitando erro na leitura.
  static String _field(XmlElement node, String name) =>
      node.getElement(name)?.innerText.trim() ?? '';

  // Aceita ponto ou vírgula decimal e descarta valores inválidos.
  static double? _number(String text) {
    final value = double.tryParse(text.replaceAll(',', '.'));
    return value != null && value.isFinite ? value : null;
  }

  // O serviço envia as datas no formato ano-mês-dia.
  static DateTime? _date(String text) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) return null;
    final value = DateTime.tryParse(text);
    // DateTime ajusta datas como 31/02; a comparação impede aceitar esse ajuste.
    return value?.toIso8601String().substring(0, 10) == text ? value : null;
  }

  static const _invalidResponse = WeatherException(
    'O CPTEC/INPE retornou uma resposta inválida. Tente novamente mais tarde.',
  );

  // Libera as conexões quando o cliente não for mais utilizado.
  void close() => _client.close();
}
