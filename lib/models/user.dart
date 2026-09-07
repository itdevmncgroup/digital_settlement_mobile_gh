class AppUser {
  final String id;
  final String employeeId;
  final String name;
  final String email;
  final String? unitId;
  final List<String> roles;

  AppUser({
    required this.id,
    required this.employeeId,
    required this.name,
    required this.email,
    this.unitId,
    required this.roles,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        employeeId: json['employeeId'] as String? ?? '',
        name: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        unitId: json['unitId'] as String?,
        roles: (json['roles'] as List?)?.map((r) => r.toString()).toList() ?? [],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'employeeId': employeeId,
        'name': name,
        'email': email,
        'unitId': unitId,
        'roles': roles,
      };

  bool hasAnyRole(List<String> anyOf) => roles.any((r) => anyOf.contains(r));
}
