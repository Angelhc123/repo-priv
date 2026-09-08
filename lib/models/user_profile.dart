class UserProfile {
  final int age;
  final String level; // 'beginner', 'intermediate', 'advanced', 'competitive'
  final bool useMockData;

  UserProfile({
    required this.age,
    required this.level,
    required this.useMockData,
  });

  UserProfile copyWith({
    int? age,
    String? level,
    bool? useMockData,
  }) {
    return UserProfile(
      age: age ?? this.age,
      level: level ?? this.level,
      useMockData: useMockData ?? this.useMockData,
    );
  }

  Map<String, dynamic> toJson() => {
        'age': age,
        'level': level,
        'useMockData': useMockData,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        age: json['age'] as int? ?? 22,
        level: json['level'] as String? ?? 'beginner',
        useMockData: json['useMockData'] as bool? ?? false,
      );

  factory UserProfile.defaultProfile() => UserProfile(
        age: 22,
        level: 'beginner',
        useMockData: false,
      );
}
