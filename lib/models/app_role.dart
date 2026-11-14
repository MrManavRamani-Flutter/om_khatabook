/// Commercial application role definition.
/// Supports both built-in system roles (Developer, Admin, Manager, Clerk)
/// and dynamically created custom roles (e.g. Accountant, Auditor, Supervisor).
class AppRole {
  final String id;
  final String name;
  final String description;
  final bool isBuiltIn;

  const AppRole({
    required this.id,
    required this.name,
    this.description = '',
    this.isBuiltIn = false,
  });

  bool get isDeveloper => id == developerId;
  bool get isAdmin => id == adminId;
  bool get isManager => id == managerId;
  bool get isClerk => id == clerkId;

  static const String developerId = 'developer';
  static const String adminId = 'admin';
  static const String managerId = 'manager';
  static const String clerkId = 'clerk';

  static const AppRole developer = AppRole(
    id: developerId,
    name: 'Developer',
    description: 'Supreme master access: full system configuration, developer tools & supervision',
    isBuiltIn: true,
  );

  static const AppRole admin = AppRole(
    id: adminId,
    name: 'Administrator',
    description: 'Full operational access: manage roles, users, challans, parties & audit',
    isBuiltIn: true,
  );

  static const AppRole manager = AppRole(
    id: managerId,
    name: 'Branch Manager',
    description: 'Commercial access: create, edit, view, reports, restore (cannot purge or edit users)',
    isBuiltIn: true,
  );

  static const AppRole clerk = AppRole(
    id: clerkId,
    name: 'Accountant / Clerk',
    description: 'Data entry access: create, edit, view challans & parties, export reports',
    isBuiltIn: true,
  );

  static List<AppRole> get defaultRoles => const [
        developer,
        admin,
        manager,
        clerk,
      ];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'isBuiltIn': isBuiltIn,
      };

  factory AppRole.fromJson(Map<String, dynamic> json) {
    return AppRole(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      isBuiltIn: json['isBuiltIn'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppRole && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
