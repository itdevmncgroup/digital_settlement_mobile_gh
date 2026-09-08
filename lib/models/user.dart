class AppUser {
  final String id;
  final String employeeId;
  final String name;
  final String email;
  final String? unitId;
  final List<String> roles;
  final List<String> permissions;
  // HEAD_POD/DEPT_HEAD/DIV_HEAD/BOD/... - the approval-chain Position, distinct
  // from Role. Null for a user who holds no approval position.
  final String? positionCode;

  AppUser({
    required this.id,
    required this.employeeId,
    required this.name,
    required this.email,
    this.unitId,
    required this.roles,
    required this.permissions,
    this.positionCode,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        employeeId: json['employeeId'] as String? ?? '',
        name: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        unitId: json['unitId'] as String?,
        roles: (json['roles'] as List?)?.map((r) => r.toString()).toList() ?? [],
        permissions: (json['permissions'] as List?)?.map((p) => p.toString()).toList() ?? [],
        positionCode: (json['position'] as Map<String, dynamic>?)?['code'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'employeeId': employeeId,
        'name': name,
        'email': email,
        'unitId': unitId,
        'roles': roles,
        'permissions': permissions,
        'position': positionCode != null ? {'code': positionCode} : null,
      };

  bool hasAnyRole(List<String> anyOf) => roles.any((r) => anyOf.contains(r));
  bool hasAnyPermission(List<String> anyOf) => permissions.any((p) => anyOf.contains(p));
}
