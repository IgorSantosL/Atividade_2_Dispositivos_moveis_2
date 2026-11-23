import 'package:flutter/material.dart';

// Associa cada condição do tempo a uma descrição, um ícone e uma cor.
class WeatherCondition {
  const WeatherCondition(this.description, this.icon, this.color);

  final String description;
  final IconData icon;
  final Color color;

  static const sun = Color(0xFFB86A08);
  static const cloud = Color(0xFF627887);
  static const rain = Color(0xFF2977AE);

  // Fonte: tabela de siglas em https://servicos.cptec.inpe.br/XML/
  // Os textos abreviados da tabela estão escritos por extenso.
  static const descriptions = <String, String>{
    'ec': 'Encoberto com chuvas isoladas',
    'ci': 'Chuvas isoladas',
    'c': 'Chuva',
    'in': 'Instável',
    'pp': 'Possibilidade de pancadas de chuva',
    'cm': 'Chuva pela manhã',
    'cn': 'Chuva à noite',
    'pt': 'Pancadas de chuva à tarde',
    'pm': 'Pancadas de chuva pela manhã',
    'np': 'Nublado e pancadas de chuva',
    'pc': 'Pancadas de chuva',
    'pn': 'Parcialmente nublado',
    'cv': 'Chuvisco',
    'ch': 'Chuvoso',
    't': 'Tempestade',
    'ps': 'Predomínio de sol',
    'e': 'Encoberto',
    'n': 'Nublado',
    'cl': 'Céu claro',
    'nv': 'Nevoeiro',
    'g': 'Geada',
    'ne': 'Neve',
    'nd': 'Condição não definida',
    'pnt': 'Pancadas de chuva à noite',
    'psc': 'Possibilidade de chuva',
    'pcm': 'Possibilidade de chuva pela manhã',
    'pct': 'Possibilidade de chuva à tarde',
    'pcn': 'Possibilidade de chuva à noite',
    'npt': 'Nublado com pancadas à tarde',
    'npn': 'Nublado com pancadas à noite',
    'ncn': 'Nublado com possibilidade de chuva à noite',
    'nct': 'Nublado com possibilidade de chuva à tarde',
    'ncm': 'Nublado com possibilidade de chuva pela manhã',
    'npm': 'Nublado com pancadas pela manhã',
    'npp': 'Nublado com possibilidade de chuva',
    'vn': 'Variação de nebulosidade',
    'ct': 'Chuva à tarde',
    'ppn': 'Possibilidade de pancadas de chuva à noite',
    'ppt': 'Possibilidade de pancadas de chuva à tarde',
    'ppm': 'Possibilidade de pancadas de chuva pela manhã',
  };

  // Converte a sigla do XML para a informação apresentada nos cartões.
  factory WeatherCondition.fromCode(String value) {
    final code = value.trim().toLowerCase();
    final description = descriptions[code];
    // Usa um ícone neutro quando a condição não veio definida no serviço.
    if (description == null || code == 'nd') {
      return WeatherCondition(
        description ?? 'Condição não informada',
        Icons.help_outline_rounded,
        cloud,
      );
    }
    if ({'ps', 'cl'}.contains(code)) {
      return WeatherCondition(description, Icons.wb_sunny_rounded, sun);
    }
    if ({'pn', 'vn'}.contains(code)) {
      return WeatherCondition(description, Icons.wb_cloudy_rounded, sun);
    }
    if ({'n', 'e'}.contains(code)) {
      return WeatherCondition(description, Icons.cloud_rounded, cloud);
    }
    if (code == 'nv') {
      return WeatherCondition(description, Icons.foggy, cloud);
    }
    if ({'ne', 'g'}.contains(code)) {
      return WeatherCondition(description, Icons.ac_unit_rounded, rain);
    }
    if (code == 't') {
      return WeatherCondition(description, Icons.thunderstorm_rounded, rain);
    }
    // Usa a gota para chuva, possibilidade de chuva e tempo instável.
    return WeatherCondition(description, Icons.water_drop_rounded, rain);
  }
}
