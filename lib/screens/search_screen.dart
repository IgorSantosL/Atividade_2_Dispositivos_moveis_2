import 'package:flutter/material.dart';

import '../models/weather.dart';
import '../services/cptec_client.dart';
import '../services/weather_repository.dart';
import '../widgets/common.dart';
import 'forecast_screen.dart';

// Tela inicial com a busca de cidades e o histórico de consultas.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.repository});
  final WeatherRepository repository;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _search = TextEditingController();
  List<City> _cities = [];
  bool _loading = false;
  // Diferencia a tela inicial de uma busca que terminou sem resultados.
  bool _searched = false;
  String? _error;
  int _request = 0;

  // Valida o texto digitado e consulta as cidades correspondentes.
  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final query = _search.text.trim();
    final request = ++_request;
    if (query.isEmpty) {
      setState(() {
        _loading = false;
        _searched = false;
        _cities = [];
        _error = 'Digite o nome de uma cidade para pesquisar.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _searched = true;
      _error = null;
      _cities = [];
    });
    try {
      final cities = await widget.repository.searchCities(query);
      // Ignora a resposta se a tela foi fechada ou o texto da busca mudou.
      if (!mounted || request != _request) return;
      setState(() {
        _cities = cities;
        _loading = false;
      });
    } on WeatherException catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  void _clearResults() {
    // Invalida a pesquisa anterior quando o usuário altera ou limpa o campo.
    ++_request;
    setState(() {
      _cities = [];
      _searched = false;
      _loading = false;
      _error = null;
    });
  }

  // Passa a cidade escolhida e o mesmo repositório para a tela de previsão.
  void _open(City city) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ForecastScreen(city: city, repository: widget.repository),
    ),
  );

  @override
  void dispose() {
    // Libera o controlador do campo quando a tela é removida.
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wb_sunny_rounded, color: AppColors.teal),
          SizedBox(width: 10),
          Text(
            'horizonte',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -.5),
          ),
        ],
      ),
    ),
    body: SafeArea(
      // Refaz a lista de consultas quando o repositório atualiza o histórico.
      child: ListenableBuilder(
        listenable: widget.repository,
        builder: (context, _) => PageBody(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.teal,
                borderRadius: BorderRadius.circular(26),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Expanded(
                        child: Text(
                          'PREVISÃO DO TEMPO',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFFCAE5D7),
                            letterSpacing: 2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.wb_sunny_rounded,
                        color: Color(0xFFF5CD78),
                        size: 38,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'O tempo, no\nseu caminho.',
                    style: Theme.of(
                      context,
                    ).textTheme.headlineLarge?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Consulte os próximos dias e planeje\nseu dia com mais tranquilidade.',
                    style: TextStyle(color: Color(0xFFD6EAE1), height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Para onde vamos?',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            const Text(
              'Encontre uma cidade brasileira.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('city-search'),
              controller: _search,
              textInputAction: TextInputAction.search,
              textCapitalization: TextCapitalization.words,
              onSubmitted: (_) => _submit(),
              onChanged: (_) => _clearResults(),
              decoration: InputDecoration(
                labelText: 'Nome da cidade',
                hintText: 'Ex.: São Paulo',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpar busca',
                        onPressed: () {
                          _search.clear();
                          _clearResults();
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loading ? null : _submit,
              icon: const Icon(Icons.search_rounded, size: 20),
              label: const Text('Buscar cidade'),
            ),
            const SizedBox(height: 24),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Buscando cidades…'),
                  ],
                ),
              ),
            if (_error != null)
              NoticeCard(
                message: _error!,
                icon: Icons.wifi_off_rounded,
                action: _searched
                    ? TextButton(
                        onPressed: _submit,
                        child: const Text('Tentar novamente'),
                      )
                    : null,
              ),
            if (_searched && !_loading && _error == null) ...[
              if (_cities.isEmpty)
                const EmptyState(
                  icon: Icons.location_off_outlined,
                  title: 'Nenhuma cidade encontrada',
                  message:
                      'Confira a grafia ou tente apenas o início do nome da cidade.',
                )
              else ...[
                Text(
                  '${_cities.length} ${_cities.length == 1 ? 'cidade encontrada' : 'cidades encontradas'}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                for (final city in _cities) _cityTile(city),
              ],
            ],
            if (widget.repository.storageNotice != null)
              NoticeCard(message: widget.repository.storageNotice!),
            if (widget.repository.recent.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Últimas consultas',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              const Text(
                'Reabra os dados salvos, mesmo sem conexão.',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 14),
              for (final saved in widget.repository.recent)
                _cityTile(saved.city, saved: true),
            ] else if (!_searched && _error == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.bookmark_border_rounded, color: AppColors.teal),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Suas consultas ficam salvas aqui para você acessar depois.',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ),
                  ],
                ),
              ),
            const SourceFooter(),
          ],
        ),
      ),
    ),
  );

  // Reutiliza o cartão para os resultados da busca e as consultas salvas.
  Widget _cityTile(City city, {bool saved = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFEDF3ED),
          child: Icon(
            saved ? Icons.history_rounded : Icons.location_on_outlined,
            color: AppColors.teal,
            size: 22,
          ),
        ),
        title: Text(
          city.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          saved
              ? '${city.state.isEmpty ? 'UF não informada' : city.state} • Consulta salva'
              : city.state.isEmpty
              ? 'UF não informada'
              : city.state,
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 15,
          color: AppColors.muted,
        ),
        onTap: () => _open(city),
      ),
    ),
  );
}
