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

  // Soft delete and deactivation tracking
  final bool isDeleted;
  final DateTime? deletedAt;
  final String? deletedBy;

  // Developer block status (Blocked users cannot login)
  final bool isBlocked;
  final DateTime? blockedAt;
  final String? blockedBy;

  // Record audit metadata
  final String createdBy;
  final String? updatedBy;
  final DateTime? updatedAt;

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
    this.isDeleted = false,
    this.deletedAt,
    this.deletedBy,
    this.isBlocked = false,
    this.blockedAt,
    this.blockedBy,
    this.createdBy = 'system',
    this.updatedBy,
    this.updatedAt,
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
      'isDeleted': isDeleted,
      'deletedAt': deletedAt?.toIso8601String(),
      'deletedBy': deletedBy,
      'isBlocked': isBlocked,
      'blockedAt': blockedAt?.toIso8601String(),
      'blockedBy': blockedBy,
      'createdBy': createdBy,
      'updatedBy': updatedBy,
      'updatedAt': updatedAt?.toIso8601String(),
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
      isDeleted: json['isDeleted'] as bool? ?? false,
      deletedAt: json['deletedAt'] != null
          ? DateTime.parse(json['deletedAt'] as String)
          : null,
      deletedBy: json['deletedBy'] as String?,
      isBlocked: json['isBlocked'] as bool? ?? false,
      blockedAt: json['blockedAt'] != null
          ? DateTime.parse(json['blockedAt'] as String)
          : null,
      blockedBy: json['blockedBy'] as String?,
      createdBy: json['createdBy'] as String? ?? 'system',
      updatedBy: json['updatedBy'] as String?,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
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
    bool? isDeleted,
    DateTime? deletedAt,
    String? deletedBy,
    bool? isBlocked,
    DateTime? blockedAt,
    String? blockedBy,
    String? createdBy,
    String? updatedBy,
    DateTime? updatedAt,
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
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      deletedBy: deletedBy ?? this.deletedBy,
      isBlocked: isBlocked ?? this.isBlocked,
      blockedAt: blockedAt ?? this.blockedAt,
      blockedBy: blockedBy ?? this.blockedBy,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
