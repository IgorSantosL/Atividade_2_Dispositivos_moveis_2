import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:previsao_do_tempo/app.dart';
import 'package:previsao_do_tempo/services/cptec_client.dart';
import 'package:previsao_do_tempo/services/local_store.dart';
import 'package:previsao_do_tempo/services/weather_repository.dart';

import 'cptec_client_test.dart' show fixture;

// Ative com --dart-define=CAPTURE_SCREENSHOTS=true para atualizar as imagens.
const captureScreenshots = bool.fromEnvironment('CAPTURE_SCREENSHOTS');
const captureKey = Key('screenshot-boundary');

// Salva a tela renderizada como PNG na pasta de capturas do README.
Future<void> capture(WidgetTester tester, String name) async {
  if (!captureScreenshots) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(captureKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('docs/screenshots/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> loadFonts() async {
  // Carrega as fontes do SDK para que as capturas tenham os textos e ícones do app.
  final config = jsonDecode(
    File('.dart_tool/package_config.json').readAsStringSync(),
  );
  final package = (config['packages'] as List).firstWhere(
    (p) => p['name'] == 'flutter',
  );
  final root = Directory.fromUri(
    Uri.parse(package['rootUri'] as String),
  ).parent.parent;
  final fonts = '${root.path}/bin/cache/artifacts/material_fonts';
  final roboto = FontLoader('Roboto');
  for (final name in ['regular', 'medium', 'bold', 'black']) {
    roboto.addFont(
      Future.value(
        ByteData.sublistView(File('$fonts/roboto-$name.ttf').readAsBytesSync()),
      ),
    );
  }
  await roboto.load();
  await (FontLoader('MaterialIcons')..addFont(
        Future.value(
          ByteData.sublistView(
            File('$fonts/materialicons-regular.otf').readAsBytesSync(),
          ),
        ),
      ))
      .load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
    if (captureScreenshots) await loadFonts();
  });
  // Limpa o histórico antes de cada teste de interface.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // Abre o app com o tamanho de tela e as respostas HTTP definidos pelo teste.
  Future<WeatherRepository> launch(
    WidgetTester tester,
    Future<http.Response> Function(http.Request) handler, {
    Size size = const Size(430, 1120),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = WeatherRepository(
      client: CptecClient(client: MockClient(handler)),
      store: LocalStore(),
    );
    await repository.initialize();
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: WeatherApp(repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    return repository;
  }

  // Preenche o campo e aciona a busca como na interação do usuário.
  Future<void> search(WidgetTester tester, [String text = 'São Paulo']) async {
    await tester.enterText(find.byKey(const Key('city-search')), text);
    await tester.pump();
    await tester.tap(find.text('Buscar cidade'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'busca, navega, atualiza, desenha gráfico e consulta cache offline',
    (tester) async {
      var offline = false;
      var forecastRequests = 0;
      await launch(tester, (request) async {
        if (offline) throw http.ClientException('offline');
        if (request.url.path.endsWith('listaCidades')) return fixture('cities');
        forecastRequests++;
        return fixture('forecast');
      });
      tester.view.physicalSize = const Size(430, 800);
      await tester.pumpAndSettle();
      await capture(tester, '01-inicio');
      tester.view.physicalSize = const Size(430, 1120);
      await tester.pumpAndSettle();
      await search(tester);
      expect(find.text('4 cidades encontradas'), findsOneWidget);
      await capture(tester, '02-busca');
      await tester.tap(find.widgetWithText(ListTile, 'São Paulo'));
      await tester.pumpAndSettle();
      expect(find.text('São Paulo, SP'), findsOneWidget);
      expect(find.text('4 dias'), findsOneWidget);
      expect(find.text('Atualização do serviço: 22/11/2026'), findsOneWidget);
      await capture(tester, '03-previsao');
      await tester.tap(find.byTooltip('Atualizar previsão'));
      await tester.pumpAndSettle();
      expect(forecastRequests, 2);
      await tester.tap(find.text('Ver gráfico de temperaturas'));
      await tester.pumpAndSettle();
      expect(find.text('Temperatura em °C'), findsOneWidget);
      expect(find.text('Os números de cada dia'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture(tester, '04-grafico');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      offline = true;
      await tester.tap(find.byTooltip('Atualizar previsão'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Exibindo a consulta salva'), findsOneWidget);
      await capture(tester, '05-offline');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Limpar busca'));
      await tester.pumpAndSettle();
      expect(find.text('Últimas consultas'), findsOneWidget);
      expect(find.text('SP • Consulta salva'), findsOneWidget);
    },
  );

  testWidgets('distingue entrada vazia, nenhum resultado e erro HTTP', (
    tester,
  ) async {
    var failed = false;
    await launch(
      tester,
      (_) async =>
          failed ? http.Response('', 503) : http.Response('<cidades/>', 200),
    );
    await tester.tap(find.text('Buscar cidade'));
    await tester.pumpAndSettle();
    expect(
      find.text('Digite o nome de uma cidade para pesquisar.'),
      findsOneWidget,
    );
    await search(tester, 'xyz');
    expect(find.text('Nenhuma cidade encontrada'), findsOneWidget);
    failed = true;
    await search(tester);
    expect(find.textContaining('indisponível'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
  });

  testWidgets('exibe carregamento e ignora a resposta de uma busca antiga', (
    tester,
  ) async {
    final pending = Completer<http.Response>();
    await launch(
      tester,
      (request) => request.url.queryParameters['city'] == 'antiga'
          ? pending.future
          : Future.value(fixture('cities')),
    );
    await tester.enterText(find.byType(TextField), 'antiga');
    await tester.tap(find.text('Buscar cidade'));
    await tester.pump();
    expect(find.text('Buscando cidades…'), findsOneWidget);
    await search(tester);
    pending.complete(http.Response('<cidades/>', 200));
    await tester.pumpAndSettle();
    expect(find.text('4 cidades encontradas'), findsOneWidget);
    expect(find.text('Nenhuma cidade encontrada'), findsNothing);
  });

  testWidgets('informa ausência de previsão e permite tentar novamente', (
    tester,
  ) async {
    await launch(
      tester,
      (request) async => request.url.path.endsWith('listaCidades')
          ? fixture('cities')
          : http.Response('<cidade/>', 200),
    );
    await search(tester);
    await tester.tap(find.widgetWithText(ListTile, 'São Paulo'));
    await tester.pumpAndSettle();
    expect(find.text('Sem previsão disponível'), findsOneWidget);
    expect(find.text('Consultar novamente'), findsOneWidget);
    expect(find.text('Ver gráfico de temperaturas'), findsNothing);
  });

  testWidgets('campos ausentes e gráfico sem números não encerram o app', (
    tester,
  ) async {
    await launch(
      tester,
      (request) async => request.url.path.endsWith('listaCidades')
          ? fixture('cities')
          : http.Response('<cidade><previsao/></cidade>', 200),
    );
    await search(tester);
    await tester.tap(find.widgetWithText(ListTile, 'São Paulo'));
    await tester.pumpAndSettle();
    expect(find.text('Condição não informada'), findsOneWidget);
    expect(find.text('IUV não informado'), findsOneWidget);
    await tester.tap(find.text('Ver gráfico de temperaturas'));
    await tester.pumpAndSettle();
    expect(find.text('Sem temperaturas disponíveis'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('gráfico com um ponto, temperaturas negativas e lacunas', (
    tester,
  ) async {
    await launch(
      tester,
      (request) async => request.url.path.endsWith('listaCidades')
          ? fixture('cities')
          : http.Response('''<cidade>
      <previsao><minima>-4</minima></previsao>
      <previsao/><previsao><maxima>0</maxima></previsao></cidade>''', 200),
    );
    await search(tester);
    await tester.tap(find.widgetWithText(ListTile, 'São Paulo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver gráfico de temperaturas'));
    await tester.pumpAndSettle();
    expect(find.text('Temperatura em °C'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('layout cabe em tela estreita e com texto ampliado', (
    tester,
  ) async {
    await launch(
      tester,
      (request) async => request.url.path.endsWith('listaCidades')
          ? fixture('cities')
          : fixture('forecast'),
      size: const Size(320, 740),
    );
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.byKey(const Key('city-search')),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(find.byKey(const Key('city-search')), 'São Paulo');
    await tester.pump();
    await tester.ensureVisible(find.text('Buscar cidade'));
    await tester.tap(find.text('Buscar cidade'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.widgetWithText(ListTile, 'São Paulo'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.widgetWithText(ListTile, 'São Paulo'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Ver gráfico de temperaturas'));
    await tester.tap(find.text('Ver gráfico de temperaturas'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
