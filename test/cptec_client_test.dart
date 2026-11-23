import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:previsao_do_tempo/models/weather.dart';
import 'package:previsao_do_tempo/models/weather_condition.dart';
import 'package:previsao_do_tempo/services/cptec_client.dart';

const city = City(id: '244', name: 'São Paulo', state: 'SP');

// Usa os XMLs salvos para testar as respostas sem depender da internet.
http.Response fixture(String name) => http.Response.bytes(
  File('test/fixtures/$name.xml').readAsBytesSync(),
  200,
  headers: {'content-type': 'text/xml; charset=ISO-8859-1'},
);

void main() {
  test(
    'busca remove acentos e mantém os IDs e as UFs do XML Latin-1',
    () async {
      final api = CptecClient(
        client: MockClient((request) async {
          expect(request.url.scheme, 'https');
          expect(request.url.path, '/XML/listaCidades');
          expect(request.url.queryParameters, {'city': 'sao paulo'});
          return fixture('cities');
        }),
      );
      addTearDown(api.close);
      final cities = await api.searchCities('  SÃO   PAULO  ');
      expect(cities.map((city) => city.id), ['244', '5019', '5020', '5021']);
      expect(cities[1].name, 'São Paulo das Missões');
      expect(cities[1].state, 'RS');
    },
  );

  test(
    'usa o ID selecionado no endpoint de quatro dias e lê todos os dias',
    () async {
      final api = CptecClient(
        client: MockClient((request) async {
          expect(request.url.path, '/XML/cidade/244/previsao.xml');
          return fixture('forecast');
        }),
      );
      addTearDown(api.close);
      final forecast = await api.fetchForecast(city);
      expect(forecast.city.id, '244');
      expect(forecast.days, hasLength(4));
      expect(forecast.updatedAt, DateTime(2026, 11, 22));
      expect(forecast.days.first.date, DateTime(2026, 11, 23));
      expect(forecast.days.first.maximum, 27);
      expect(forecast.days.first.minimum, 22);
      expect(forecast.days.first.uvIndex, 0);
      expect(forecast.days.last.conditionCode, 'pn');
    },
  );

  test(
    'não trunca dias extras nem inventa valores para campos ausentes',
    () async {
      final api = CptecClient(
        client: MockClient(
          (_) async => http.Response('''
      <cidade><previsao><dia>2026-02-31</dia><minima>NaN</minima>
      <maxima>Infinity</maxima><iuv>-1</iuv></previsao>
      <previsao><minima>-2</minima><maxima>3,5</maxima><iuv>7,2</iuv></previsao>
      <previsao/><previsao/><previsao/></cidade>''', 200),
        ),
      );
      addTearDown(api.close);
      final forecast = await api.fetchForecast(city);
      expect(forecast.days, hasLength(5));
      expect(forecast.updatedAt, isNull);
      expect(forecast.city.name, 'São Paulo');
      expect(forecast.days.first.date, isNull);
      expect(forecast.days.first.minimum, isNull);
      expect(forecast.days.first.maximum, isNull);
      expect(forecast.days.first.uvIndex, isNull);
      expect(forecast.days[1].minimum, -2);
      expect(forecast.days[1].maximum, 3.5);
      expect(forecast.days[1].uvIndex, 7.2);
    },
  );

  test('distingue uma busca vazia e uma previsão indisponível', () async {
    final api = CptecClient(
      client: MockClient(
        (request) async => http.Response(
          request.url.path.endsWith('listaCidades')
              ? '<cidades/>'
              : '<cidade/>',
          200,
        ),
      ),
    );
    addTearDown(api.close);
    expect(await api.searchCities('inexistente'), isEmpty);
    expect((await api.fetchForecast(city)).days, isEmpty);
  });

  test(
    'descarta cidades sem ID válido e preserva cidade com UF ausente',
    () async {
      final api = CptecClient(
        client: MockClient(
          (_) async => http.Response('''
      <cidades><cidade><nome>A</nome></cidade>
      <cidade><id>123</id><nome>B</nome></cidade></cidades>''', 200),
        ),
      );
      addTearDown(api.close);
      final cities = await api.searchCities('a');
      expect(cities.single.id, '123');
      expect(cities.single.state, isEmpty);
    },
  );

  test('respeita declaração UTF-8 mesmo com cabeçalho incorreto', () {
    final response = http.Response.bytes(
      utf8.encode(
        '<?xml version="1.0" encoding="UTF-8"?><cidade>São Luís</cidade>',
      ),
      200,
      headers: {'content-type': 'text/xml; charset=ISO-8859-1'},
    );
    expect(CptecClient.decodeXml(response), contains('São Luís'));
  });

  // Simula respostas que não podem ser interpretadas como uma lista de cidades.
  for (final body in [
    '<html>manutenção</html>',
    '<cidades>',
    '',
    '<cidades><cidade><nome>Sem código</nome></cidade></cidades>',
  ]) {
    test('informa resposta inválida: $body', () async {
      final api = CptecClient(
        client: MockClient((_) async => http.Response(body, 200)),
      );
      addTearDown(api.close);
      await expectLater(
        api.searchCities('abc'),
        throwsA(
          isA<WeatherException>().having(
            (error) => error.message,
            'message',
            contains('inválida'),
          ),
        ),
      );
    });
  }

  test('informa indisponibilidade HTTP', () async {
    final api = CptecClient(
      client: MockClient((_) async => http.Response('', 503)),
    );
    addTearDown(api.close);
    await expectLater(
      api.fetchForecast(city),
      throwsA(
        isA<WeatherException>().having(
          (error) => error.message,
          'message',
          contains('indisponível'),
        ),
      ),
    );
  });

  test('trata falha de conexão', () async {
    final api = CptecClient(
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    addTearDown(api.close);
    await expectLater(
      api.fetchForecast(city),
      throwsA(
        isA<WeatherException>().having(
          (error) => error.message,
          'message',
          contains('conexão'),
        ),
      ),
    );
  });

  test('trata falha TLS sem encerrar a consulta inesperadamente', () async {
    final api = CptecClient(
      client: MockClient(
        (_) async => throw const HandshakeException('Falha TLS'),
      ),
    );
    addTearDown(api.close);
    await expectLater(
      api.fetchForecast(city),
      throwsA(
        isA<WeatherException>().having(
          (error) => error.message,
          'message',
          contains('conexão segura'),
        ),
      ),
    );
  });

  test('limita o tempo de espera', () async {
    // Mantém a resposta pendente até o tempo de espera da consulta acabar.
    final pending = Completer<http.Response>();
    final api = CptecClient(
      client: MockClient((_) => pending.future),
      timeout: const Duration(milliseconds: 5),
    );
    addTearDown(api.close);
    await expectLater(
      api.fetchForecast(city),
      throwsA(
        isA<WeatherException>().having(
          (error) => error.message,
          'message',
          contains('demorou'),
        ),
      ),
    );
    pending.complete(http.Response('<cidade/>', 200));
  });

  test(
    'mapeia as 40 siglas oficiais e oferece descrição para desconhecidas',
    () {
      expect(WeatherCondition.descriptions.length, 40);
      expect(
        WeatherCondition.fromCode('PNT').description,
        'Pancadas de chuva à noite',
      );
      expect(
        WeatherCondition.fromCode('xyz').description,
        'Condição não informada',
      );
      expect(
        WeatherCondition.fromCode('').description,
        'Condição não informada',
      );
    },
  );
}
