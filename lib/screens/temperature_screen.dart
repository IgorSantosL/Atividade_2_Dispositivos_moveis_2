import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/weather.dart';
import '../services/weather_repository.dart';
import '../widgets/common.dart';

// Usa a mesma previsão da tela anterior para montar o gráfico e a tabela.
class TemperatureScreen extends StatelessWidget {
  const TemperatureScreen({super.key, required this.result});
  final ForecastResult result;

  @override
  Widget build(BuildContext context) {
    final forecast = result.forecast;
    // Desconsidera campos vazios ao calcular a escala do gráfico.
    final values = forecast.days
        .expand((day) => [day.minimum, day.maximum])
        .whereType<double>()
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Temperaturas')),
      body: SafeArea(
        child: PageBody(
          children: [
            const Text(
              'UM OLHAR SOBRE OS DIAS',
              style: TextStyle(
                color: AppColors.teal,
                letterSpacing: 1.6,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              forecast.city.label,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Acompanhe a variação das mínimas e máximas.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 24),
            if (result.fromCache)
              NoticeCard(
                icon: Icons.offline_pin_outlined,
                message:
                    'Gráfico da consulta salva em '
                    '${dateLabel(forecast.fetchedAt, pattern: 'dd/MM/yyyy HH:mm')}. '
                    'Os dados podem estar desatualizados.',
              ),
            if (values.isEmpty)
              const EmptyState(
                icon: Icons.show_chart_rounded,
                title: 'Sem temperaturas disponíveis',
                message:
                    'O serviço não informou temperaturas para gerar o gráfico.',
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 22, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Text(
                          'Temperatura em °C',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Wrap(
                        spacing: 22,
                        runSpacing: 8,
                        children: [
                          _Legend(label: 'Máxima', color: AppColors.maximum),
                          _Legend(label: 'Mínima', color: AppColors.minimum),
                        ],
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        height: 250,
                        child: Semantics(
                          label:
                              'Gráfico de temperaturas mínimas e máximas. Os valores também estão na tabela abaixo.',
                          child: _Chart(days: forecast.days, values: values),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Toque nos pontos para ver os valores.',
                        style: TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 28),
            Text(
              'Os números de cada dia',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    const _TableRow(
                      date: 'Data',
                      minimum: 'Mínima',
                      maximum: 'Máxima',
                      header: true,
                    ),
                    const Divider(height: 26),
                    for (var i = 0; i < forecast.days.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: _TableRow(
                          date: forecast.days[i].date == null
                              ? 'Dia ${i + 1}*'
                              : dateLabel(
                                  forecast.days[i].date,
                                  pattern: 'dd/MM',
                                ),
                          minimum: temperature(forecast.days[i].minimum),
                          maximum: temperature(forecast.days[i].maximum),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '“—” indica temperatura não informada. Valores ausentes não são tratados como zero.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            if (forecast.days.any((day) => day.date == null))
              const Text(
                '* Data não informada pelo serviço; mantida a ordem de retorno.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            const SizedBox(height: 18),
            Text(
              'Atualização do serviço: ${dateLabel(forecast.updatedAt)}',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SourceFooter(),
          ],
        ),
      ),
    );
  }
}

// Desenha uma linha para as máximas e outra para as mínimas.
class _Chart extends StatelessWidget {
  const _Chart({required this.days, required this.values});
  final List<ForecastDay> days;
  final List<double> values;

  @override
  Widget build(BuildContext context) {
    // Deixa uma margem nas extremidades e arredonda a escala de cinco em cinco.
    final minimum = ((values.reduce(math.min) - 2) / 5).floor() * 5.0;
    final maximum = ((values.reduce(math.max) + 2) / 5).ceil() * 5.0;
    return LineChart(
      LineChartData(
        // A margem lateral mantém os pontos das extremidades dentro da área.
        minX: -.15,
        maxX: math.max(days.length - 1, .15).toDouble() + .15,
        minY: minimum,
        maxY: maximum,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: math.max(5, (maximum - minimum) / 5).toDouble(),
          getDrawingHorizontalLine: (_) => const FlLine(
            color: AppColors.border,
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: math.max(5, (maximum - minimum) / 5).toDouble(),
              getTitlesWidget: (value, meta) => Text(
                '${numberLabel(value)}°',
                style: const TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: 1,
              getTitlesWidget: (value, meta) {
                // Cada posição inteira corresponde a um dia da lista.
                final i = value.round();
                if ((value - i).abs() > .01 || i < 0 || i >= days.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    days[i].date == null
                        ? 'Dia ${i + 1}'
                        : dateLabel(days[i].date, pattern: 'dd/MM'),
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        // Exibe a temperatura ao tocar em um ponto do gráfico.
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.ink,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (spots) => spots
                .map(
                  (spot) => LineTooltipItem(
                    '${spot.barIndex == 0 ? 'Máxima' : 'Mínima'}: ${temperature(spot.y)}',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        lineBarsData: [
          _line(true, AppColors.maximum),
          _line(false, AppColors.minimum),
        ],
      ),
      duration: Duration.zero,
    );
  }

  // high seleciona as máximas; false seleciona as mínimas.
  // nullSpot deixa uma lacuna quando o serviço não informa a temperatura.
  LineChartBarData _line(bool high, Color color) => LineChartBarData(
    spots: [
      for (var i = 0; i < days.length; i++)
        (high ? days[i].maximum : days[i].minimum) == null
            ? FlSpot.nullSpot
            : FlSpot(i.toDouble(), (high ? days[i].maximum : days[i].minimum)!),
    ],
    color: color,
    barWidth: 3,
    isCurved: false,
    dotData: const FlDotData(show: true),
    belowBarData: BarAreaData(show: false),
  );
}

// Identifica a cor de cada linha na legenda.
class _Legend extends StatelessWidget {
  const _Legend({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 16,
        height: 4,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      const SizedBox(width: 7),
      Text(label, style: const TextStyle(fontSize: 12)),
    ],
  );
}

// Mantém as colunas de data, mínima e máxima alinhadas na tabela.
class _TableRow extends StatelessWidget {
  const _TableRow({
    required this.date,
    required this.minimum,
    required this.maximum,
    this.header = false,
  });
  final String date;
  final String minimum;
  final String maximum;
  final bool header;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          date,
          style: TextStyle(
            fontWeight: header ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
      Expanded(
        child: Text(
          minimum,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.minimum,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      Expanded(
        child: Text(
          maximum,
          textAlign: TextAlign.right,
          style: const TextStyle(
            color: AppColors.maximum,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );
}
