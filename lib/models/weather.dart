// Dados da cidade retornada na busca do CPTEC.
class City {
  const City({required this.id, required this.name, required this.state});

  final String id;
  final String name;
  final String state;

  String get label => state.isEmpty ? name : '$name, $state';

  // Converte os dados para o formato usado no histórico local.
  Map<String, Object?> toJson() => {'id': id, 'name': name, 'state': state};

  // Recria a cidade salva e confere se ela tem um código válido para consulta.
  factory City.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final name = json['name'] as String;
    if (!RegExp(r'^\d+$').hasMatch(id) || int.parse(id) <= 0 || name.isEmpty) {
      throw const FormatException('Cidade salva inválida.');
    }
    return City(id: id, name: name, state: json['state'] as String? ?? '');
  }
}

// Previsão de um dia. Os campos opcionais podem vir vazios no serviço.
class ForecastDay {
  const ForecastDay({
    this.date,
    this.conditionCode = '',
    this.minimum,
    this.maximum,
    this.uvIndex,
  });

  final DateTime? date;
  final String conditionCode;
  final double? minimum;
  final double? maximum;
  final double? uvIndex;

  // Salva as datas como texto para que possam ser gravadas no JSON.
  Map<String, Object?> toJson() => {
    'date': date?.toIso8601String(),
    'condition': conditionCode,
    'minimum': minimum,
    'maximum': maximum,
    'uv': uvIndex,
  };

  // Recupera as datas e os números da previsão armazenada.
  factory ForecastDay.fromJson(Map<String, dynamic> json) => ForecastDay(
    date: DateTime.tryParse(json['date'] as String? ?? ''),
    conditionCode: json['condition'] as String? ?? '',
    minimum: (json['minimum'] as num?)?.toDouble(),
    maximum: (json['maximum'] as num?)?.toDouble(),
    uvIndex: (json['uv'] as num?)?.toDouble(),
  );
}

// Reúne a cidade, os dias previstos e as datas de atualização e consulta.
class Forecast {
  Forecast({
    required this.city,
    required List<ForecastDay> days,
    required this.fetchedAt,
    this.updatedAt,
  }) : days = List.unmodifiable(days);

  final City city;
  final List<ForecastDay> days;
  // Data de atualização informada pelo CPTEC no XML.
  final DateTime? updatedAt;
  // Horário em que o aplicativo recebeu a resposta.
  final DateTime fetchedAt;

  // Inclui a cidade e todos os dias ao salvar uma consulta.
  Map<String, Object?> toJson() => {
    'city': city.toJson(),
    'days': days.map((day) => day.toJson()).toList(),
    'updatedAt': updatedAt?.toIso8601String(),
    'fetchedAt': fetchedAt.toIso8601String(),
  };

  // Reconstrói a consulta completa a partir do histórico local.
  factory Forecast.fromJson(Map<String, dynamic> json) => Forecast(
    city: City.fromJson(json['city'] as Map<String, dynamic>),
    days: (json['days'] as List)
        .map((day) => ForecastDay.fromJson(day as Map<String, dynamic>))
        .toList(),
    updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    fetchedAt: DateTime.parse(json['fetchedAt'] as String),
  );
}
