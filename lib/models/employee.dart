/// An employee on the team.
class Employee {
  const Employee({
    required this.id,
    required this.name,
    required this.role,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['id'] as String,
      name: json['name'] as String,
      role: json['role'] as String,
    );
  }

  final String id;
  final String name;
  final String role;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'role': role};
}
