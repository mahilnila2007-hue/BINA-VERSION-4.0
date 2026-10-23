/// User profile model for ReHabRep.
/// Single-user patient-focused profile.
class UserProfile {
  final String id;
  final String name;
  final String email;
  final int? age;
  final bool voiceCoachingEnabled;
  final bool hapticFeedbackEnabled;
  final bool isFrontCamera;
  final DateTime createdAt;

  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    this.age,
    this.voiceCoachingEnabled = true,
    this.hapticFeedbackEnabled = true,
    this.isFrontCamera = true,
    required this.createdAt,
  });

  UserProfile copyWith({
    String? id,
    String? name,
    String? email,
    int? age,
    bool? voiceCoachingEnabled,
    bool? hapticFeedbackEnabled,
    bool? isFrontCamera,
    DateTime? createdAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      age: age ?? this.age,
      voiceCoachingEnabled: voiceCoachingEnabled ?? this.voiceCoachingEnabled,
      hapticFeedbackEnabled:
          hapticFeedbackEnabled ?? this.hapticFeedbackEnabled,
      isFrontCamera: isFrontCamera ?? this.isFrontCamera,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'age': age,
        'voiceCoachingEnabled': voiceCoachingEnabled,
        'hapticFeedbackEnabled': hapticFeedbackEnabled,
        'isFrontCamera': isFrontCamera,
        'createdAt': createdAt.toIso8601String(),
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        age: json['age'] as int?,
        voiceCoachingEnabled:
            (json['voiceCoachingEnabled'] as bool?) ?? true,
        hapticFeedbackEnabled:
            (json['hapticFeedbackEnabled'] as bool?) ?? true,
        isFrontCamera: (json['isFrontCamera'] as bool?) ?? true,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
      );
}
