import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Cores compartilhadas entre as telas e o gráfico.
class AppColors {
  static const paper = Color(0xFFF5F7F5);
  static const ink = Color(0xFF183C3B);
  static const teal = Color(0xFF17655E);
  static const muted = Color(0xFF586F6B);
  static const border = Color(0xFFE0E7E2);
  static const minimum = Color(0xFF267AB3);
  static const maximum = Color(0xFFC36531);
}

// Usa vírgula decimal e mostra um traço quando o valor não foi informado.
String numberLabel(double? value) =>
    value == null ? '—' : NumberFormat('0.#', 'pt_BR').format(value);

// Acrescenta a unidade somente quando existe uma temperatura disponível.
String temperature(double? value) =>
    value == null ? '—' : '${numberLabel(value)} °C';

// Formata a data em português; cada tela pode escolher um formato diferente.
String dateLabel(DateTime? value, {String pattern = 'dd/MM/yyyy'}) =>
    value == null
    ? 'Data não informada'
    : DateFormat(pattern, 'pt_BR').format(value);

// Centraliza o conteúdo em telas largas e permite rolagem nas telas menores.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        // Permite puxar para atualizar mesmo quando o conteúdo cabe na tela.
        physics: const AlwaysScrollableScrollPhysics(),
        children: children,
      ),
    ),
  );
}

// Rodapé com a identificação da fonte dos dados.
class SourceFooter extends StatelessWidget {
  const SourceFooter({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(top: 28, bottom: 8),
    child: Column(
      children: [
        Text(
          'Fonte dos dados: CPTEC/INPE',
          style: TextStyle(
            color: AppColors.muted,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Previsão do tempo para cidades brasileiras',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    ),
  );
}

// Aviso usado para falhas de consulta, armazenamento ou dados desatualizados.
class NoticeCard extends StatelessWidget {
  const NoticeCard({
    super.key,
    required this.message,
    this.icon = Icons.info_outline,
    this.action,
  });
  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF3DC),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 21, color: const Color(0xFF79591A)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Color(0xFF654C1F)),
              ),
            ),
          ],
        ),
        if (action != null)
          Padding(padding: const EdgeInsets.only(top: 8), child: action),
      ],
    ),
  );
}

// Mensagem para telas sem resultados, com um botão de nova tentativa opcional.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 8),
    child: Column(
      children: [
        Icon(icon, size: 48, color: AppColors.teal),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted),
        ),
        if (action != null)
          Padding(padding: const EdgeInsets.only(top: 18), child: action),
      ],
    ),
  );
}
