import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:previsao_do_tempo/models/weather.dart';
import 'package:previsao_do_tempo/services/cptec_client.dart';
import 'package:previsao_do_tempo/services/local_store.dart';
import 'package:previsao_do_tempo/services/weather_repository.dart';
import 'cptec_client_test.dart' show city, fixture;

// Simula uma falha ao gravar o histórico no dispositivo.
class FailingStore extends LocalStore {
  @override
  Future<void> save(List<Forecast> forecasts) async =>
      throw StateError('Disco indisponível');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Cada teste começa com um armazenamento vazio e separado dos demais.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'reabre cache após recriar repositório e identifica consulta offline',
    () async {
      var offline = false;
      CptecClient client() => CptecClient(
        client: MockClient((_) async {
          if (offline) throw http.ClientException('offline');
          return fixture('forecast');
        }),
      );
      final first = WeatherRepository(client: client(), store: LocalStore());
      await first.initialize();
      final live = await first.fetchForecast(city);
      expect(live.fromCache, isFalse);
      first.dispose();
      offline = true;
      // Recriar o repositório simula reabrir o app depois de perder a conexão.
      final second = WeatherRepository(client: client(), store: LocalStore());
      addTearDown(second.dispose);
      await second.initialize();
      final cached = await second.fetchForecast(city);
      expect(cached.fromCache, isTrue);
      expect(cached.notice, contains('conexão'));
      expect(cached.forecast.days, hasLength(4));
      expect(cached.forecast.fetchedAt, live.forecast.fetchedAt);
      expect(cached.forecast.updatedAt, live.forecast.updatedAt);
      await expectLater(
        second.fetchForecast(const City(id: '999', name: 'Outra', state: 'SP')),
        throwsA(isA<WeatherException>()),
      );
    },
  );

  test(
    'mantém no máximo oito cidades e move consulta repetida para o início',
    () async {
      final repository = WeatherRepository(
        client: CptecClient(
          client: MockClient((_) async => fixture('forecast')),
        ),
        store: LocalStore(),
      );
      addTearDown(repository.dispose);
      await repository.initialize();
      for (var id = 1; id <= 10; id++) {
        await repository.fetchForecast(
          City(id: '$id', name: 'Cidade $id', state: 'SP'),
        );
      }
      await repository.fetchForecast(
        const City(id: '5', name: 'Cidade 5', state: 'SP'),
      );
      expect(repository.recent, hasLength(8));
      expect(repository.recent.first.city.id, '5');
      expect(
        repository.recent.map((item) => item.city.id).toSet(),
        hasLength(8),
      );
      expect((await LocalStore().load()).first.city.id, '5');
    },
  );

  test('cache corrompido não impede consultas novas', () async {
    SharedPreferences.setMockInitialValues({LocalStore.key: 'corrompido'});
    final repository = WeatherRepository(
      client: CptecClient(client: MockClient((_) async => fixture('forecast'))),
      store: LocalStore(),
    );
    addTearDown(repository.dispose);
    await repository.initialize();
    expect(repository.storageNotice, isNotNull);
    expect(repository.recent, isEmpty);
    await repository.fetchForecast(city);
    expect(repository.storageNotice, isNull);
    expect(await LocalStore().load(), hasLength(1));
  });

  test(
    'falha ao persistir mantém previsão recebida e avisa o usuário',
    () async {
      final repository = WeatherRepository(
        client: CptecClient(
          client: MockClient((_) async => fixture('forecast')),
        ),
        store: FailingStore(),
      );
      addTearDown(repository.dispose);
      await repository.initialize();
      final result = await repository.fetchForecast(city);
      expect(result.forecast.days, hasLength(4));
      expect(result.fromCache, isFalse);
      expect(result.notice, contains('não foi possível salvá-la'));
    },
  );

  test('resposta válida sem previsão substitui o cache antigo', () async {
    var empty = false;
    final repository = WeatherRepository(
      client: CptecClient(
        client: MockClient(
          (_) async =>
              empty ? http.Response('<cidade/>', 200) : fixture('forecast'),
        ),
      ),
      store: LocalStore(),
    );
    addTearDown(repository.dispose);
    await repository.initialize();
    await repository.fetchForecast(city);
    empty = true;
    final result = await repository.fetchForecast(city);
    expect(result.fromCache, isFalse);
    expect(repository.cached('244')!.days, isEmpty);
  });
}
