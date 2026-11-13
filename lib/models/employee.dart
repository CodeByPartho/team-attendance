/// An employee on the team.
///
/// New fields are all optional in JSON so records saved by v1.0 (name and
/// role only) still load. [archived] employees keep their full history but
/// no longer appear in the today register.
class Employee {
  const Employee({
    required this.id,
    required this.name,
    required this.role,
    this.phone = '',
    this.email = '',
    this.joinDate,
    this.department = '',
    this.hourlyRate = 0,
    this.employmentType = 'Full-time',
    this.archived = false,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['id'] as String,
      name: json['name'] as String,
      role: json['role'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      joinDate: json['joinDate'] as String?,
      department: json['department'] as String? ?? '',
      hourlyRate: (json['hourlyRate'] as num?)?.toDouble() ?? 0,
      employmentType: json['employmentType'] as String? ?? 'Full-time',
      archived: json['archived'] as bool? ?? false,
    );
  }

  final String id;
  final String name;
  final String role;
  final String phone;
  final String email;

  /// Join date as a `yyyy-MM-dd` string, null when not set.
  final String? joinDate;
  final String department;

  /// Hourly pay rate in the team currency, 0 when not set.
  final double hourlyRate;

  /// For example Full-time, Part-time or Contract.
  final String employmentType;

  /// Archived employees keep history but leave the today register.
  final bool archived;

  Employee copyWith({
    String? name,
    String? role,
    String? phone,
    String? email,
    String? joinDate,
    String? department,
    double? hourlyRate,
    String? employmentType,
    bool? archived,
  }) {
    return Employee(
      id: id,
      name: name ?? this.name,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      joinDate: joinDate ?? this.joinDate,
      department: department ?? this.department,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      employmentType: employmentType ?? this.employmentType,
      archived: archived ?? this.archived,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role,
        'phone': phone,
        'email': email,
        'joinDate': joinDate,
        'department': department,
        'hourlyRate': hourlyRate,
        'employmentType': employmentType,
        'archived': archived,
      };
}
