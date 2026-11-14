import 'app_user.dart';

/// Configurable, dynamic permission matrix for a user role.
/// Structured cleanly across the 5 core operational dimensions:
/// 1. 👁️ View (Challans, Parties, Reports, Invoices)
/// 2. ➕ Add (Challans, Parties, Users)
/// 3. ✏️ Edit (Challans, Parties, Users, Settings)
/// 4. 🗑️ Delete (Soft-delete, Restore, Purge bin, Deactivate users, Permanent DB delete)
/// 5. 📜 Log (Audit trail inspection, Record modification history, Clear logs)
class RolePermissions {
  final String roleId;
  final UserRole role;

  // 1. 👁️ VIEW PERMISSIONS
  final bool canViewChallans;
  final bool canViewParties;
  final bool canViewReports;
  final bool canPrintInvoice;

  // 2. ➕ ADD / CREATE PERMISSIONS
  final bool canCreateChallan;
  final bool canManageParties; // Create counterparties
  final bool canAddUsers; // Manager & Admin & Developer can add users

  // 3. ✏️ EDIT / UPDATE PERMISSIONS
  final bool canEditChallan;
  final bool canEditUsers; // Manager & Admin & Developer can update users
  final bool canManageSettings; // Modify branding & company profile

  // 4. 🗑️ DELETE & RECOVERY PERMISSIONS
  final bool canDeleteChallan; // Soft delete challan to bin
  final bool canRestoreChallan; // Restore challan from bin
  final bool canPurgeRecycleBin; // Permanent erase vouchers
  final bool canDeleteUsers; // Soft delete / deactivate user (Manager = false, Admin = true)
  final bool canPermanentDeleteUsers; // Irrevocably purge user from DB (Developer ONLY)

  // 5. 📜 LOG & AUDIT TRAIL PERMISSIONS
  final bool canViewAuditLogs; // Inspect modification history & user actions
  final bool canClearAuditLogs; // Erase audit trail logs (Developer only)

  RolePermissions({
    String? roleId,
    UserRole? role,
    // View
    this.canViewChallans = true,
    this.canViewParties = true,
    this.canViewReports = true,
    this.canPrintInvoice = true,
    // Add
    this.canCreateChallan = true,
    this.canManageParties = true,
    this.canAddUsers = false,
    // Edit
    this.canEditChallan = true,
    this.canEditUsers = false,
    this.canManageSettings = false,
    // Delete
    this.canDeleteChallan = true,
    this.canRestoreChallan = true,
    this.canPurgeRecycleBin = false,
    this.canDeleteUsers = false,
    this.canPermanentDeleteUsers = false,
    // Log
    this.canViewAuditLogs = true,
    this.canClearAuditLogs = false,
    bool? canManageUsers,
  })  : roleId = roleId ?? role?.name ?? 'clerk',
        role = role ?? roleFromId(roleId ?? 'clerk');

  /// Backwards-compatibility getter for general user management
  bool get canManageUsers => canAddUsers || canEditUsers || canDeleteUsers;
  bool get canExportReports => canViewReports;

  static UserRole roleFromId(String id) {
    return UserRole.values.firstWhere(
      (r) => r.name == id,
      orElse: () => UserRole.custom,
    );
  }

  Map<String, dynamic> toJson() => {
        'role': roleId,
        'roleId': roleId,
        // View
        'canViewChallans': canViewChallans,
        'canViewParties': canViewParties,
        'canViewReports': canViewReports,
        'canPrintInvoice': canPrintInvoice,
        // Add
        'canCreateChallan': canCreateChallan,
        'canManageParties': canManageParties,
        'canAddUsers': canAddUsers,
        // Edit
        'canEditChallan': canEditChallan,
        'canEditUsers': canEditUsers,
        'canManageSettings': canManageSettings,
        // Delete
        'canDeleteChallan': canDeleteChallan,
        'canRestoreChallan': canRestoreChallan,
        'canPurgeRecycleBin': canPurgeRecycleBin,
        'canDeleteUsers': canDeleteUsers,
        'canPermanentDeleteUsers': canPermanentDeleteUsers,
        // Log
        'canViewAuditLogs': canViewAuditLogs,
        'canClearAuditLogs': canClearAuditLogs,
      };

  factory RolePermissions.fromJson(Map<String, dynamic> json) {
    final rawRole = (json['roleId'] ?? json['role'] ?? 'clerk') as String;
    final defaults = RolePermissions.defaultForId(rawRole);

    return RolePermissions(
      roleId: rawRole,
      canViewChallans: json['canViewChallans'] as bool? ?? defaults.canViewChallans,
      canViewParties: json['canViewParties'] as bool? ?? defaults.canViewParties,
      canViewReports: json['canViewReports'] as bool? ?? defaults.canViewReports,
      canPrintInvoice: json['canPrintInvoice'] as bool? ?? defaults.canPrintInvoice,
      canCreateChallan: json['canCreateChallan'] as bool? ?? defaults.canCreateChallan,
      canManageParties: json['canManageParties'] as bool? ?? defaults.canManageParties,
      canAddUsers: json['canAddUsers'] as bool? ?? defaults.canAddUsers,
      canEditChallan: json['canEditChallan'] as bool? ?? defaults.canEditChallan,
      canEditUsers: json['canEditUsers'] as bool? ?? defaults.canEditUsers,
      canManageSettings: json['canManageSettings'] as bool? ?? defaults.canManageSettings,
      canDeleteChallan: json['canDeleteChallan'] as bool? ?? defaults.canDeleteChallan,
      canRestoreChallan: json['canRestoreChallan'] as bool? ?? defaults.canRestoreChallan,
      canPurgeRecycleBin: json['canPurgeRecycleBin'] as bool? ?? defaults.canPurgeRecycleBin,
      canDeleteUsers: json['canDeleteUsers'] as bool? ?? defaults.canDeleteUsers,
      canPermanentDeleteUsers: json['canPermanentDeleteUsers'] as bool? ?? defaults.canPermanentDeleteUsers,
      canViewAuditLogs: json['canViewAuditLogs'] as bool? ?? defaults.canViewAuditLogs,
      canClearAuditLogs: json['canClearAuditLogs'] as bool? ?? defaults.canClearAuditLogs,
    );
  }

  RolePermissions copyWith({
    String? roleId,
    UserRole? role,
    bool? canViewChallans,
    bool? canViewParties,
    bool? canViewReports,
    bool? canPrintInvoice,
    bool? canCreateChallan,
    bool? canManageParties,
    bool? canAddUsers,
    bool? canEditChallan,
    bool? canEditUsers,
    bool? canManageSettings,
    bool? canDeleteChallan,
    bool? canRestoreChallan,
    bool? canPurgeRecycleBin,
    bool? canDeleteUsers,
    bool? canPermanentDeleteUsers,
    bool? canViewAuditLogs,
    bool? canClearAuditLogs,
    bool? canManageUsers,
  }) {
    final effectiveRoleId = roleId ?? (role != null ? role.name : this.roleId);
    return RolePermissions(
      roleId: effectiveRoleId,
      role: role ?? roleFromId(effectiveRoleId),
      canViewChallans: canViewChallans ?? this.canViewChallans,
      canViewParties: canViewParties ?? this.canViewParties,
      canViewReports: canViewReports ?? this.canViewReports,
      canPrintInvoice: canPrintInvoice ?? this.canPrintInvoice,
      canCreateChallan: canCreateChallan ?? this.canCreateChallan,
      canManageParties: canManageParties ?? this.canManageParties,
      canAddUsers: canAddUsers ?? (canManageUsers ?? this.canAddUsers),
      canEditChallan: canEditChallan ?? this.canEditChallan,
      canEditUsers: canEditUsers ?? (canManageUsers ?? this.canEditUsers),
      canManageSettings: canManageSettings ?? this.canManageSettings,
      canDeleteChallan: canDeleteChallan ?? this.canDeleteChallan,
      canRestoreChallan: canRestoreChallan ?? this.canRestoreChallan,
      canPurgeRecycleBin: canPurgeRecycleBin ?? this.canPurgeRecycleBin,
      canDeleteUsers: canDeleteUsers ?? (canManageUsers ?? this.canDeleteUsers),
      canPermanentDeleteUsers: canPermanentDeleteUsers ?? this.canPermanentDeleteUsers,
      canViewAuditLogs: canViewAuditLogs ?? this.canViewAuditLogs,
      canClearAuditLogs: canClearAuditLogs ?? this.canClearAuditLogs,
    );
  }

  static RolePermissions defaultFor(UserRole role) => defaultForId(role.name);

  static RolePermissions defaultForId(String roleId) {
    switch (roleId) {
      case 'developer':
        return RolePermissions(
          roleId: 'developer',
          role: UserRole.developer,
          // View
          canViewChallans: true,
          canViewParties: true,
          canViewReports: true,
          canPrintInvoice: true,
          // Add
          canCreateChallan: true,
          canManageParties: true,
          canAddUsers: true,
          // Edit
          canEditChallan: true,
          canEditUsers: true,
          canManageSettings: true,
          // Delete
          canDeleteChallan: true,
          canRestoreChallan: true,
          canPurgeRecycleBin: true,
          canDeleteUsers: true,
          canPermanentDeleteUsers: true, // Only Developer has permanent delete
          // Log
          canViewAuditLogs: true,
          canClearAuditLogs: true,
        );

      case 'admin':
        return RolePermissions(
          roleId: 'admin',
          role: UserRole.admin,
          // View
          canViewChallans: true,
          canViewParties: true,
          canViewReports: true,
          canPrintInvoice: true,
          // Add
          canCreateChallan: true,
          canManageParties: true,
          canAddUsers: true,
          // Edit
          canEditChallan: true,
          canEditUsers: true,
          canManageSettings: true,
          // Delete
          canDeleteChallan: true,
          canRestoreChallan: true,
          canPurgeRecycleBin: true,
          canDeleteUsers: true, // Soft-delete only (Developer purges)
          canPermanentDeleteUsers: false, // Admin CANNOT permanently delete
          // Log (Developer exclusively views & audits by default)
          canViewAuditLogs: false,
          canClearAuditLogs: false,
        );

      case 'manager':
        return RolePermissions(
          roleId: 'manager',
          role: UserRole.manager,
          // View
          canViewChallans: true,
          canViewParties: true,
          canViewReports: true,
          canPrintInvoice: true,
          // Add
          canCreateChallan: true,
          canManageParties: true,
          canAddUsers: true, // Manager can add user
          // Edit
          canEditChallan: true,
          canEditUsers: true, // Manager can update user
          canManageSettings: false,
          // Delete: Manager has NO delete rights on users!
          canDeleteChallan: true,
          canRestoreChallan: true,
          canPurgeRecycleBin: false,
          canDeleteUsers: false, // Manager CANNOT delete users
          canPermanentDeleteUsers: false,
          // Log
          canViewAuditLogs: false, // Developer & Admin primarily manage logs
          canClearAuditLogs: false,
        );

      case 'clerk':
        return RolePermissions(
          roleId: 'clerk',
          role: UserRole.clerk,
          // View
          canViewChallans: true,
          canViewParties: false,
          canViewReports: true,
          canPrintInvoice: true,
          // Add
          canCreateChallan: true,
          canManageParties: false,
          canAddUsers: false,
          // Edit
          canEditChallan: true,
          canEditUsers: false,
          canManageSettings: false,
          // Delete
          canDeleteChallan: false,
          canRestoreChallan: false,
          canPurgeRecycleBin: false,
          canDeleteUsers: false,
          canPermanentDeleteUsers: false,
          // Log
          canViewAuditLogs: false,
          canClearAuditLogs: false,
        );

      default:
        // Default template for custom roles
        return RolePermissions(
          roleId: roleId,
          role: roleFromId(roleId),
          canViewChallans: true,
          canViewParties: true,
          canViewReports: true,
          canPrintInvoice: true,
          canCreateChallan: true,
          canManageParties: false,
          canAddUsers: false,
          canEditChallan: true,
          canEditUsers: false,
          canManageSettings: false,
          canDeleteChallan: false,
          canRestoreChallan: false,
          canPurgeRecycleBin: false,
          canDeleteUsers: false,
          canPermanentDeleteUsers: false,
          canViewAuditLogs: false,
          canClearAuditLogs: false,
        );
    }
  }
}
