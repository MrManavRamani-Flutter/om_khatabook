import 'app_user.dart';

/// Configurable, dynamic permission matrix for a user role.
/// All permissions are stored in the database and can be dynamically
/// adjusted by the Administrator or Developer at runtime.
class RolePermissions {
  final String roleId;
  final UserRole role;

  // Challan management
  final bool canCreateChallan;
  final bool canEditChallan;
  final bool canDeleteChallan;

  // Recycle bin operations
  final bool canRestoreChallan;
  final bool canPurgeRecycleBin;

  // Party directory
  final bool canManageParties;

  // Reporting & Invoicing
  final bool canExportReports;
  final bool canPrintInvoice;

  // Audit trail
  final bool canViewAuditLogs;
  final bool canClearAuditLogs;

  // Administration & Settings
  final bool canManageUsers;
  final bool canManageSettings;

  RolePermissions({
    String? roleId,
    UserRole? role,
    this.canCreateChallan = true,
    this.canEditChallan = true,
    this.canDeleteChallan = true,
    this.canRestoreChallan = true,
    this.canPurgeRecycleBin = false,
    this.canManageParties = true,
    this.canExportReports = true,
    this.canPrintInvoice = true,
    this.canViewAuditLogs = true,
    this.canClearAuditLogs = false,
    this.canManageUsers = false,
    this.canManageSettings = false,
  })  : roleId = roleId ?? role?.name ?? 'clerk',
        role = role ?? roleFromId(roleId ?? 'clerk');

  static UserRole roleFromId(String id) {
    return UserRole.values.firstWhere(
      (r) => r.name == id,
      orElse: () => UserRole.custom,
    );
  }

  Map<String, dynamic> toJson() => {
        'role': roleId,
        'roleId': roleId,
        'canCreateChallan': canCreateChallan,
        'canEditChallan': canEditChallan,
        'canDeleteChallan': canDeleteChallan,
        'canRestoreChallan': canRestoreChallan,
        'canPurgeRecycleBin': canPurgeRecycleBin,
        'canManageParties': canManageParties,
        'canExportReports': canExportReports,
        'canPrintInvoice': canPrintInvoice,
        'canViewAuditLogs': canViewAuditLogs,
        'canClearAuditLogs': canClearAuditLogs,
        'canManageUsers': canManageUsers,
        'canManageSettings': canManageSettings,
      };

  factory RolePermissions.fromJson(Map<String, dynamic> json) {
    final rawRole = (json['roleId'] ?? json['role'] ?? 'clerk') as String;
    final defaults = RolePermissions.defaultForId(rawRole);

    return RolePermissions(
      roleId: rawRole,
      canCreateChallan:
          json['canCreateChallan'] as bool? ?? defaults.canCreateChallan,
      canEditChallan:
          json['canEditChallan'] as bool? ?? defaults.canEditChallan,
      canDeleteChallan:
          json['canDeleteChallan'] as bool? ?? defaults.canDeleteChallan,
      canRestoreChallan:
          json['canRestoreChallan'] as bool? ?? defaults.canRestoreChallan,
      canPurgeRecycleBin:
          json['canPurgeRecycleBin'] as bool? ?? defaults.canPurgeRecycleBin,
      canManageParties:
          json['canManageParties'] as bool? ?? defaults.canManageParties,
      canExportReports:
          json['canExportReports'] as bool? ?? defaults.canExportReports,
      canPrintInvoice:
          json['canPrintInvoice'] as bool? ?? defaults.canPrintInvoice,
      canViewAuditLogs:
          json['canViewAuditLogs'] as bool? ?? defaults.canViewAuditLogs,
      canClearAuditLogs:
          json['canClearAuditLogs'] as bool? ?? defaults.canClearAuditLogs,
      canManageUsers:
          json['canManageUsers'] as bool? ?? defaults.canManageUsers,
      canManageSettings:
          json['canManageSettings'] as bool? ?? defaults.canManageSettings,
    );
  }

  RolePermissions copyWith({
    String? roleId,
    UserRole? role,
    bool? canCreateChallan,
    bool? canEditChallan,
    bool? canDeleteChallan,
    bool? canRestoreChallan,
    bool? canPurgeRecycleBin,
    bool? canManageParties,
    bool? canExportReports,
    bool? canPrintInvoice,
    bool? canViewAuditLogs,
    bool? canClearAuditLogs,
    bool? canManageUsers,
    bool? canManageSettings,
  }) {
    final effectiveRoleId = roleId ?? (role != null ? role.name : this.roleId);
    return RolePermissions(
      roleId: effectiveRoleId,
      role: role ?? roleFromId(effectiveRoleId),
      canCreateChallan: canCreateChallan ?? this.canCreateChallan,
      canEditChallan: canEditChallan ?? this.canEditChallan,
      canDeleteChallan: canDeleteChallan ?? this.canDeleteChallan,
      canRestoreChallan: canRestoreChallan ?? this.canRestoreChallan,
      canPurgeRecycleBin: canPurgeRecycleBin ?? this.canPurgeRecycleBin,
      canManageParties: canManageParties ?? this.canManageParties,
      canExportReports: canExportReports ?? this.canExportReports,
      canPrintInvoice: canPrintInvoice ?? this.canPrintInvoice,
      canViewAuditLogs: canViewAuditLogs ?? this.canViewAuditLogs,
      canClearAuditLogs: canClearAuditLogs ?? this.canClearAuditLogs,
      canManageUsers: canManageUsers ?? this.canManageUsers,
      canManageSettings: canManageSettings ?? this.canManageSettings,
    );
  }

  /// System default preset for a given UserRole enum
  static RolePermissions defaultFor(UserRole role) => defaultForId(role.name);

  /// System default preset for any role identifier
  static RolePermissions defaultForId(String roleId) {
    switch (roleId) {
      case 'developer':
        return RolePermissions(
          roleId: 'developer',
          role: UserRole.developer,
          canCreateChallan: true,
          canEditChallan: true,
          canDeleteChallan: true,
          canRestoreChallan: true,
          canPurgeRecycleBin: true,
          canManageParties: true,
          canExportReports: true,
          canPrintInvoice: true,
          canViewAuditLogs: true,
          canClearAuditLogs: true,
          canManageUsers: true,
          canManageSettings: true,
        );
      case 'admin':
        return RolePermissions(
          roleId: 'admin',
          role: UserRole.admin,
          canCreateChallan: true,
          canEditChallan: true,
          canDeleteChallan: true,
          canRestoreChallan: true,
          canPurgeRecycleBin: true,
          canManageParties: true,
          canExportReports: true,
          canPrintInvoice: true,
          canViewAuditLogs: true,
          canClearAuditLogs: true,
          canManageUsers: true,
          canManageSettings: true,
        );
      case 'manager':
        return RolePermissions(
          roleId: 'manager',
          role: UserRole.manager,
          canCreateChallan: true,
          canEditChallan: true,
          canDeleteChallan: true,
          canRestoreChallan: true,
          canPurgeRecycleBin: false,
          canManageParties: true,
          canExportReports: true,
          canPrintInvoice: true,
          canViewAuditLogs: true,
          canClearAuditLogs: false,
          canManageUsers: false,
          canManageSettings: false,
        );
      case 'clerk':
        return RolePermissions(
          roleId: 'clerk',
          role: UserRole.clerk,
          canCreateChallan: true,
          canEditChallan: true,
          canDeleteChallan: false,
          canRestoreChallan: false,
          canPurgeRecycleBin: false,
          canManageParties: false,
          canExportReports: true,
          canPrintInvoice: true,
          canViewAuditLogs: false,
          canClearAuditLogs: false,
          canManageUsers: false,
          canManageSettings: false,
        );
      default:
        // Default template for user-defined custom roles
        return RolePermissions(
          roleId: roleId,
          role: roleFromId(roleId),
          canCreateChallan: true,
          canEditChallan: true,
          canDeleteChallan: false,
          canRestoreChallan: false,
          canPurgeRecycleBin: false,
          canManageParties: false,
          canExportReports: true,
          canPrintInvoice: true,
          canViewAuditLogs: false,
          canClearAuditLogs: false,
          canManageUsers: false,
          canManageSettings: false,
        );
    }
  }
}
