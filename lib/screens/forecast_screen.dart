import 'package:flutter/material.dart';

import '../models/weather.dart';
import '../models/weather_condition.dart';
import '../services/cptec_client.dart';
import '../services/weather_repository.dart';
import '../widgets/common.dart';
import 'temperature_screen.dart';

// Mostra a previsão da cidade selecionada e permite atualizar os dados.
class ForecastScreen extends StatefulWidget {
  const ForecastScreen({
    super.key,
    required this.city,
    required this.repository,
  });
  final City city;
  final WeatherRepository repository;

  @override
  State<ForecastScreen> createState() => _ForecastScreenState();
}

class _ForecastScreenState extends State<ForecastScreen> {
  ForecastResult? _result;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Mostra o cache enquanto tenta buscar uma previsão atualizada.
    final cached = widget.repository.cached(widget.city.id);
    if (cached != null) _result = ForecastResult(cached, fromCache: true);
    _load();
  }

  // Usado tanto pelo botão de atualizar quanto pelo gesto de puxar a tela.
  Future<void> _load() async {
    // Evita iniciar duas atualizações ao mesmo tempo.
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.repository.fetchForecast(widget.city);
      // A consulta pode terminar depois que o usuário voltou para a busca.
      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
      });
    } on WeatherException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final forecast = _result?.forecast;
    final today = DateUtils.dateOnly(DateTime.now());
    final datedDays =
        forecast?.days.where((day) => day.date != null).toList() ?? [];
    // O aviso de previsão antiga aparece quando todos os dias já passaram.
    final expired =
        datedDays.isNotEmpty &&
        datedDays.every((day) => day.date!.isBefore(today));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Previsão do tempo'),
        actions: [
          IconButton(
            tooltip: 'Atualizar previsão',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: PageBody(
            children: [
              const Text(
                'SEU DESTINO',
                style: TextStyle(
                  color: AppColors.teal,
                  letterSpacing: 2,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                forecast?.city.label ?? widget.city.label,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              Text(
                forecast == null
                    ? 'Consultando os próximos dias…'
                    : 'Atualização do serviço: ${dateLabel(forecast.updatedAt)}',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 20),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 20),
                  child: Column(
                    children: [
                      LinearProgressIndicator(),
                      SizedBox(height: 8),
                      Text('Atualizando previsão…'),
                    ],
                  ),
                ),
              if (_result?.fromCache == true)
                NoticeCard(
                  icon: Icons.offline_pin_outlined,
                  message:
                      'Exibindo a consulta salva em '
                      '${dateLabel(forecast!.fetchedAt, pattern: 'dd/MM/yyyy HH:mm')}. '
                      'Esses dados podem estar desatualizados.'
                      '${_result?.notice == null ? '' : '\n${_result!.notice}'}',
                )
              else if (_result?.notice != null)
                NoticeCard(message: _result!.notice!),
              if (expired)
                const NoticeCard(
                  icon: Icons.event_busy_outlined,
                  message:
                      'As datas desta previsão já passaram. Atualize para consultar novos dados.',
                ),
              if (_error != null)
                EmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Não foi possível carregar',
                  message: _error!,
                  action: FilledButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Tentar novamente'),
                  ),
                ),
              if (forecast != null) ...[
                if (forecast.days.isEmpty)
                  EmptyState(
                    icon: Icons.event_busy_outlined,
                    title: 'Sem previsão disponível',
                    message:
                        'O CPTEC/INPE ainda não disponibilizou a previsão para esta cidade.',
                    action: OutlinedButton(
                      onPressed: _loading ? null : _load,
                      child: const Text('Consultar novamente'),
                    ),
                  )
                else ...[
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => TemperatureScreen(result: _result!),
                      ),
                    ),
                    icon: const Icon(Icons.show_chart_rounded),
                    label: const Text('Ver gráfico de temperaturas'),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Dia a dia',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      Text(
                        '${forecast.days.length} ${forecast.days.length == 1 ? 'dia' : 'dias'}',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  for (final day in forecast.days) _DayCard(day: day),
                  const SizedBox(height: 4),
                  Text(
                    'Consulta realizada em ${dateLabel(forecast.fetchedAt, pattern: 'dd/MM/yyyy HH:mm')}.',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  const Text(
                    'Temperaturas previstas em graus Celsius. “—” indica dado não informado.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
              ],
              const SourceFooter(),
            ],
          ),
        ),
      ),
    );
  }
}

// Apresenta a data, a condição, as temperaturas e o IUV de um dia.
class _DayCard extends StatelessWidget {
  const _DayCard({required this.day});
  final ForecastDay day;

  @override
  Widget build(BuildContext context) {
    final condition = WeatherCondition.fromCode(day.conditionCode);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dateLabel(day.date, pattern: 'EEEE, dd/MM/yyyy'),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: condition.color.withValues(alpha: .09),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      condition.icon,
                      color: condition.color,
                      size: 30,
                      semanticLabel: condition.description,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      condition.description,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 18,
                runSpacing: 10,
                children: [
                  _Temperature(
                    label: 'Mínima',
                    value: day.minimum,
                    color: AppColors.minimum,
                    icon: Icons.south_rounded,
                  ),
                  _Temperature(
                    label: 'Máxima',
                    value: day.maximum,
                    color: AppColors.maximum,
                    icon: Icons.north_rounded,
                  ),
                  Text(
                    day.uvIndex == null
                        ? 'IUV não informado'
                        : 'IUV ${numberLabel(day.uvIndex)}',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Combina a seta de mínima ou máxima com o valor em graus Celsius.
class _Temperature extends StatelessWidget {
  const _Temperature({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });
  final String label;
  final double? value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: color, size: 16),
      const SizedBox(width: 4),
      Text(
        '$label ${temperature(value)}',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    ],
  );
}
