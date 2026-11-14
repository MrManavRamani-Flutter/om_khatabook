import 'app_user.dart';

/// Configurable, dynamic permission matrix for a user role.
/// All permissions are stored in the database and can be dynamically
/// adjusted by the Administrator at runtime.
class RolePermissions {
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

  const RolePermissions({
    required this.role,
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
  });

  Map<String, dynamic> toJson() => {
        'role': role.name,
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
    final role = UserRole.values.firstWhere(
      (r) => r.name == json['role'],
      orElse: () => UserRole.clerk,
    );
    final defaults = RolePermissions.defaultFor(role);

    return RolePermissions(
      role: role,
      canCreateChallan: json['canCreateChallan'] as bool? ?? defaults.canCreateChallan,
      canEditChallan: json['canEditChallan'] as bool? ?? defaults.canEditChallan,
      canDeleteChallan: json['canDeleteChallan'] as bool? ?? defaults.canDeleteChallan,
      canRestoreChallan: json['canRestoreChallan'] as bool? ?? defaults.canRestoreChallan,
      canPurgeRecycleBin: json['canPurgeRecycleBin'] as bool? ?? defaults.canPurgeRecycleBin,
      canManageParties: json['canManageParties'] as bool? ?? defaults.canManageParties,
      canExportReports: json['canExportReports'] as bool? ?? defaults.canExportReports,
      canPrintInvoice: json['canPrintInvoice'] as bool? ?? defaults.canPrintInvoice,
      canViewAuditLogs: json['canViewAuditLogs'] as bool? ?? defaults.canViewAuditLogs,
      canClearAuditLogs: json['canClearAuditLogs'] as bool? ?? defaults.canClearAuditLogs,
      canManageUsers: json['canManageUsers'] as bool? ?? defaults.canManageUsers,
      canManageSettings: json['canManageSettings'] as bool? ?? defaults.canManageSettings,
    );
  }

  RolePermissions copyWith({
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
    return RolePermissions(
      role: role,
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

  /// System default preset for a given role
  static RolePermissions defaultFor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return const RolePermissions(
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
      case UserRole.manager:
        return const RolePermissions(
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
      case UserRole.clerk:
        return const RolePermissions(
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
    }
  }
}

