import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'services/cptec_client.dart';
import 'services/local_store.dart';
import 'services/weather_repository.dart';

Future<void> main() async {
  // Prepara o Flutter para acessar os plugins antes de abrir a primeira tela.
  WidgetsFlutterBinding.ensureInitialized();
  // Carrega os nomes de dias e meses usados na formatação das datas.
  await initializeDateFormatting('pt_BR');
  final repository = WeatherRepository(
    client: CptecClient(),
    store: LocalStore(),
  );
  // Recupera o histórico para exibi-lo assim que o aplicativo abrir.
  await repository.initialize();
  runApp(WeatherApp(repository: repository));
}
