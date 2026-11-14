export 'app_role.dart';
export 'role_permissions.dart';

enum UserRole {
  developer('Developer', 'Supreme master access: full system configuration, developer tools & supervision'),
  admin('Administrator', 'Full operational access: manage roles, users, challans, parties & audit'),
  manager('Branch Manager', 'Commercial access: create, edit, view, reports, restore (cannot purge or edit users)'),
  clerk('Accountant / Clerk', 'Data entry access: create, edit, view challans & parties, export reports'),
  custom('Custom Role', 'Dynamic user-defined role with custom permissions');

  final String label;
  final String description;
  const UserRole(this.label, this.description);

  bool get canDeleteEntries =>
      this == UserRole.developer || this == UserRole.admin || this == UserRole.manager;
  bool get canPurgeRecycleBin =>
      this == UserRole.developer || this == UserRole.admin;
  bool get canManageUsers =>
      this == UserRole.developer || this == UserRole.admin;
  bool get canManageSettings =>
      this == UserRole.developer || this == UserRole.admin;
  bool get canViewAuditLogs =>
      this == UserRole.developer || this == UserRole.admin || this == UserRole.manager;
  bool get canClearAuditLogs =>
      this == UserRole.developer || this == UserRole.admin;
}

class AppUser {
  final String id;
  final String username;
  final String password;
  final String displayName;
  final String roleId;
  final UserRole role;
  final String email;
  final String phone;
  final DateTime createdAt;
  final DateTime? lastLogin;
  final bool isActive;

  AppUser({
    required this.id,
    required this.username,
    required this.password,
    required this.displayName,
    String? roleId,
    UserRole? role,
    this.email = '',
    this.phone = '',
    required this.createdAt,
    this.lastLogin,
    this.isActive = true,
  })  : roleId = roleId ?? role?.name ?? 'clerk',
        role = role ?? _roleFromId(roleId ?? 'clerk');

  static UserRole _roleFromId(String id) {
    return UserRole.values.firstWhere(
      (r) => r.name == id,
      orElse: () => UserRole.custom,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'password': password,
      'displayName': displayName,
      'role': roleId,
      'roleId': roleId,
      'email': email,
      'phone': phone,
      'createdAt': createdAt.toIso8601String(),
      'lastLogin': lastLogin?.toIso8601String(),
      'isActive': isActive,
    };
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final rawRole = (json['roleId'] ?? json['role'] ?? 'clerk') as String;
    final userRole = _roleFromId(rawRole);

    return AppUser(
      id: json['id'] as String,
      username: json['username'] as String,
      password: json['password'] as String,
      displayName: json['displayName'] as String? ?? json['username'] as String,
      roleId: rawRole,
      role: userRole,
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      lastLogin: json['lastLogin'] != null
          ? DateTime.parse(json['lastLogin'] as String)
          : null,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  AppUser copyWith({
    String? username,
    String? password,
    String? displayName,
    String? roleId,
    UserRole? role,
    String? email,
    String? phone,
    DateTime? lastLogin,
    bool? isActive,
  }) {
    final effectiveRoleId = roleId ?? (role != null ? role.name : this.roleId);
    return AppUser(
      id: id,
      username: username ?? this.username,
      password: password ?? this.password,
      displayName: displayName ?? this.displayName,
      roleId: effectiveRoleId,
      role: role ?? _roleFromId(effectiveRoleId),
      email: email ?? this.email,
      phone: phone ?? this.phone,
      createdAt: createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      isActive: isActive ?? this.isActive,
    );
  }
}
