enum UserRole {
  admin('Administrator', 'Full system access: create, edit, delete, restore, purge, users & audit'),
  manager('Branch Manager', 'Commercial access: create, edit, view, reports, restore (cannot purge or edit users)'),
  clerk('Accountant / Clerk', 'Data entry access: create, edit, view challans & parties, export reports');

  final String label;
  final String description;
  const UserRole(this.label, this.description);

  bool get canDeleteEntries => this == UserRole.admin || this == UserRole.manager;
  bool get canPurgeRecycleBin => this == UserRole.admin;
  bool get canManageUsers => this == UserRole.admin;
  bool get canManageSettings => this == UserRole.admin;
  bool get canViewAuditLogs => this == UserRole.admin || this == UserRole.manager;
  bool get canClearAuditLogs => this == UserRole.admin;
}

class AppUser {
  final String id;
  final String username;
  final String password;
  final String displayName;
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
    required this.role,
    this.email = '',
    this.phone = '',
    required this.createdAt,
    this.lastLogin,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'password': password,
      'displayName': displayName,
      'role': role.name,
      'email': email,
      'phone': phone,
      'createdAt': createdAt.toIso8601String(),
      'lastLogin': lastLogin?.toIso8601String(),
      'isActive': isActive,
    };
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      username: json['username'] as String,
      password: json['password'] as String,
      displayName: json['displayName'] as String? ?? json['username'] as String,
      role: UserRole.values.firstWhere(
        (r) => r.name == json['role'],
        orElse: () => UserRole.clerk,
      ),
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
    UserRole? role,
    String? email,
    String? phone,
    DateTime? lastLogin,
    bool? isActive,
  }) {
    return AppUser(
      id: id,
      username: username ?? this.username,
      password: password ?? this.password,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      createdAt: createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      isActive: isActive ?? this.isActive,
    );
  }
}
