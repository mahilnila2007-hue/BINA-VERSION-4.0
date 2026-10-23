/// Represents a physiotherapy patient undergoing home recovery.
class Patient {
  final String id;
  final String name;
  final String therapistId;
  final int age;
  final String language;
  final String condition;
  final DateTime admittedDate;

  const Patient({
    required this.id,
    required this.name,
    required this.therapistId,
    required this.age,
    this.language = 'en',
    required this.condition,
    required this.admittedDate,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'therapistId': therapistId,
        'age': age,
        'language': language,
        'condition': condition,
        'admittedDate': admittedDate.toIso8601String(),
      };

  factory Patient.fromJson(Map<String, dynamic> json) => Patient(
        id: json['id'] as String,
        name: json['name'] as String,
        therapistId: json['therapistId'] as String,
        age: json['age'] as int,
        language: (json['language'] as String?) ?? 'en',
        condition: json['condition'] as String,
        admittedDate: DateTime.parse(json['admittedDate'] as String),
      );
}
