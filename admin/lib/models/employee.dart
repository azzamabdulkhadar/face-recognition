/// An employee record returned by the backend.
class Employee {
  final int id;
  final String name;
  final String? email;
  final String? createdAt;

  const Employee({
    required this.id,
    required this.name,
    this.email,
    this.createdAt,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }
}
