import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/app_user.dart';
import '../models/audit_log_entry.dart';
import '../services/storage_service.dart';

class AuthProvider extends ChangeNotifier {
  final StorageService _storage;
  final Uuid _uuid = const Uuid();

  List<AppUser> _users = [];
  List<AppRole> _customRoles = [];
  Map<String, RolePermissions> _rolePermissions = {};
  AppUser? _currentUser;
  bool _isLoading = true;

  // Callback to log audit events
  void Function(AuditLogEntry entry)? onAuditLog;

  AuthProvider(this._storage);

  static const String defaultUsername = 'OMMAVTAR36';
  static const String defaultPassword = 'OMMAVTAR36';

  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  AppUser? get currentUser => _currentUser;
  List<AppUser> get users => List.unmodifiable(_users);
  List<AppRole> get customRoles => List.unmodifiable(_customRoles);

  String get currentRoleId => _currentUser?.roleId ?? 'admin';
  UserRole get currentRole => _currentUser?.role ?? UserRole.admin;

  /// Full access granted for logged in operator
  bool get isDeveloper => true;
  bool get isAdmin => true;
  bool get isManager => true;
  bool get isClerk => true;

  /// All roles registered in the system (built-in + user-defined custom roles)
  List<AppRole> get allRoles => [
        AppRole.developer,
        AppRole.admin,
        AppRole.manager,
        AppRole.clerk,
        ..._customRoles,
      ];

  /// List of roles visible to the currently authenticated operator:
  /// - Developer can view ALL roles (including Developer).
  /// - Administrator CANNOT view the Developer role ("admin can not view developer role view").
  List<AppRole> get visibleRoles {
    if (isDeveloper) {
      return List.unmodifiable(allRoles);
    }
    // Admin and other roles cannot see Developer role
    return List.unmodifiable(allRoles.where((r) => !r.isDeveloper).toList());
  }

  /// List of users visible to the currently authenticated operator:
  /// - Developer sees ALL users (including soft-deleted and blocked accounts for master audit/purge).
  /// - Administrator sees non-deleted users, excluding Developer accounts ("admin can not view developer role view").
  /// - Manager sees non-deleted users, excluding Developer accounts.
  List<AppUser> get visibleUsers {
    if (isDeveloper) {
      return List.unmodifiable(_users);
    }
    // Filter out Developer accounts and soft-deleted accounts for Admin/Manager
    return List.unmodifiable(
      _users
          .where((u) =>
              !u.isDeleted &&
              u.role != UserRole.developer &&
              u.roleId != AppRole.developerId)
          .toList(),
    );
  }

  /// Dynamic Role Permissions (configured by Admin / Developer & persisted in database)
  RolePermissions get currentPermissions => permissionsForId(currentRoleId);

  RolePermissions permissionsForId(String roleId) {
    return _rolePermissions[roleId] ?? RolePermissions.defaultForId(roleId);
  }

  RolePermissions permissionsFor(UserRole role) => permissionsForId(role.name);

  // 1. 👁️ View - Unrestricted
  bool get canViewChallans => true;
  bool get canViewParties => true;
  bool get canViewReports => true;
  bool get canExportReports => true;
  bool get canPrintInvoice => true;

  // 2. ➕ Add - Unrestricted
  bool get canCreateChallan => true;
  bool get canManageParties => true;
  bool get canAddUsers => true;

  // 3. ✏️ Edit - Unrestricted
  bool get canEditChallan => true;
  bool get canEditUsers => true;
  bool get canManageSettings => true;

  // 4. 🗑️ Delete & Recovery - Unrestricted
  bool get canDelete => true;
  bool get canDeleteChallan => true;
  bool get canRestoreFromBin => true;
  bool get canPurgeRecycleBin => true;
  bool get canDeleteUsers => true;
  bool get canPermanentDeleteUsers => true;
  bool get canBlockUsers => true;

  // 5. 📜 Log & Audit - Unrestricted
  bool get canViewAuditLogs => true;
  bool get canClearAuditLogs => true;

  bool get canManageUsers => true;
  bool get canManagePermissions => true;

  String roleNameFor(String roleId) {
    final matched = allRoles.where((r) => r.id == roleId).toList();
    if (matched.isNotEmpty) {
      return matched.first.name.toUpperCase();
    }
    return roleId.toUpperCase();
  }

  String get currentRoleLabel {
    final matched = allRoles.where((r) => r.id == currentRoleId).toList();
    if (matched.isNotEmpty) {
      return matched.first.name;
    }
    return currentRole.label;
  }

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    _users = await _storage.loadUsers();
    _customRoles = await _storage.loadCustomRoles();
    _rolePermissions = await _storage.loadRolePermissions();

    // Ensure built-in role permissions are initialized in database
    bool permsUpdated = false;
    for (final role in AppRole.defaultRoles) {
      if (!_rolePermissions.containsKey(role.id)) {
        _rolePermissions[role.id] = RolePermissions.defaultForId(role.id);
        permsUpdated = true;
      }
    }
    if (permsUpdated) {
      await _storage.saveRolePermissions(_rolePermissions);
    }

    // Seed default users if first time
    if (_users.isEmpty) {
      _users = [
        AppUser(
          id: 'user_developer_default',
          username: 'developer',
          password: 'developer123',
          displayName: 'System Developer (Master Access)',
          roleId: AppRole.developerId,
          role: UserRole.developer,
          email: 'developer@ommavtar.com',
          phone: '+91 98250 99999',
          createdAt: DateTime.now(),
          createdBy: 'system',
        ),
        AppUser(
          id: 'user_admin_default',
          username: 'admin',
          password: 'admin123',
          displayName: 'Administrator (OM Mavtar)',
          roleId: AppRole.adminId,
          role: UserRole.admin,
          email: 'admin@ommavtar.com',
          phone: '+91 98250 12345',
          createdAt: DateTime.now(),
          createdBy: 'system',
        ),
        AppUser(
          id: 'user_manager_default',
          username: 'manager',
          password: 'manager123',
          displayName: 'Branch Commercial Manager',
          roleId: AppRole.managerId,
          role: UserRole.manager,
          email: 'manager@ommavtar.com',
          phone: '+91 98250 22334',
          createdAt: DateTime.now(),
          createdBy: 'system',
        ),
        AppUser(
          id: 'user_clerk_default',
          username: 'clerk',
          password: 'clerk123',
          displayName: 'Accountant / Entry Clerk',
          roleId: AppRole.clerkId,
          role: UserRole.clerk,
          email: 'accounts@ommavtar.com',
          phone: '+91 98250 33445',
          createdAt: DateTime.now(),
          createdBy: 'system',
        ),
      ];
      await _storage.saveUsers(_users);
    } else {
      // Ensure developer account exists if upgrading from an older version
      if (!_users.any((u) => u.username == 'developer')) {
        _users.insert(
          0,
          AppUser(
            id: 'user_developer_default',
            username: 'developer',
            password: 'developer123',
            displayName: 'System Developer (Master Access)',
            roleId: AppRole.developerId,
            role: UserRole.developer,
            email: 'developer@ommavtar.com',
            phone: '+91 98250 99999',
            createdAt: DateTime.now(),
            createdBy: 'system',
          ),
        );
        await _storage.saveUsers(_users);
      }
    }

    // Ensure OMMAVTAR36 default master account exists
    if (!_users.any((u) => u.username.toUpperCase() == 'OMMAVTAR36')) {
      _users.insert(
        0,
        AppUser(
          id: 'user_ommavtar36',
          username: 'OMMAVTAR36',
          password: 'OMMAVTAR36',
          displayName: 'OM Mavtar Group',
          roleId: AppRole.adminId,
          role: UserRole.admin,
          email: 'ommavtar36@ommavtar.com',
          phone: '+91 98250 12345',
          createdAt: DateTime.now(),
          createdBy: 'system',
        ),
      );
      await _storage.saveUsers(_users);
    }

    // Try to restore existing active session
    final savedUser = await _storage.loadActiveSessionUser();
    if (savedUser != null) {
      final matched =
          _users.where((u) => (u.id == savedUser.id || u.username.toUpperCase() == savedUser.username.toUpperCase()) && u.isActive).toList();
      if (matched.isNotEmpty && !matched.first.isDeleted && !matched.first.isBlocked) {
        _currentUser = matched.first;
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Authenticate with username and password
  Future<bool> login(String username, String password,
      {bool rememberMe = true}) async {
    final cleanUsername = username.trim().toUpperCase();
    final cleanPassword = password.trim();

    // 1. Direct validation for default master credentials OMMAVTAR36 / OMMAVTAR36
    if (cleanUsername == 'OMMAVTAR36' && cleanPassword == 'OMMAVTAR36') {
      var user = _users.firstWhere(
        (u) => u.username.toUpperCase() == 'OMMAVTAR36',
        orElse: () => AppUser(
          id: 'user_ommavtar36',
          username: 'OMMAVTAR36',
          password: 'OMMAVTAR36',
          displayName: 'OM Mavtar Group',
          roleId: AppRole.adminId,
          role: UserRole.admin,
          createdAt: DateTime.now(),
          createdBy: 'system',
        ),
      );
      final updated = user.copyWith(lastLogin: DateTime.now());
      final idx = _users.indexWhere((u) => u.id == user.id);
      if (idx != -1) {
        _users[idx] = updated;
        await _storage.saveUsers(_users);
      }
      _currentUser = updated;
      if (rememberMe) {
        await _storage.saveActiveSessionUser(updated);
      }
      _logEvent(
        action: AuditAction.login,
        entityType: AuditEntityType.auth,
        entityId: updated.id,
        entityTitle: updated.displayName,
        description: 'Master Operator ${updated.username} logged in successfully',
      );
      notifyListeners();
      return true;
    }

    // 2. Also allow other existing registered users
    final matched = _users.where(
      (u) =>
          u.username.trim().toUpperCase() == cleanUsername &&
          u.password == cleanPassword &&
          u.isActive &&
          !u.isDeleted &&
          !u.isBlocked,
    ).toList();

    if (matched.isEmpty) {
      return false;
    }

    final user = matched.first;
    final updated = user.copyWith(lastLogin: DateTime.now());

    final idx = _users.indexWhere((u) => u.id == user.id);
    if (idx != -1) {
      _users[idx] = updated;
      await _storage.saveUsers(_users);
    }

    _currentUser = updated;
    if (rememberMe) {
      await _storage.saveActiveSessionUser(updated);
    }

    _logEvent(
      action: AuditAction.login,
      entityType: AuditEntityType.auth,
      entityId: updated.id,
      entityTitle: updated.displayName,
      description:
          'User ${updated.username} logged in successfully',
    );

    notifyListeners();
    return true;
  }

  /// Logout current active session
  Future<void> logout() async {
    if (_currentUser != null) {
      _logEvent(
        action: AuditAction.logout,
        entityType: AuditEntityType.auth,
        entityId: _currentUser!.id,
        entityTitle: _currentUser!.displayName,
        description: 'User ${_currentUser!.username} logged out',
      );
    }

    _currentUser = null;
    await _storage.saveActiveSessionUser(null);
    notifyListeners();
  }

  /// Add new authorized user (Manager, Admin, Developer)
  Future<bool> addUser({
    required String username,
    required String password,
    required String displayName,
    String? roleId,
    UserRole? role,
    String email = '',
    String phone = '',
  }) async {
    final cleanUsername = username.trim().toLowerCase();
    if (_users.any((u) => u.username.trim().toLowerCase() == cleanUsername)) {
      return false; // username already taken
    }

    final effectiveRoleId = roleId ?? role?.name ?? 'clerk';

    // Security check: non-developers CANNOT create developer accounts
    if (effectiveRoleId == AppRole.developerId && !isDeveloper) {
      return false;
    }

    final operator = _currentUser?.username ?? 'admin';

    final newUser = AppUser(
      id: _uuid.v4(),
      username: cleanUsername,
      password: password.trim(),
      displayName:
          displayName.trim().isNotEmpty ? displayName.trim() : username.trim(),
      roleId: effectiveRoleId,
      role: RolePermissions.roleFromId(effectiveRoleId),
      email: email.trim(),
      phone: phone.trim(),
      createdAt: DateTime.now(),
      createdBy: operator,
    );

    _users.add(newUser);
    await _storage.saveUsers(_users);

    _logEvent(
      action: AuditAction.create,
      entityType: AuditEntityType.auth,
      entityId: newUser.id,
      entityTitle: newUser.displayName,
      description:
          'Created new user account: ${newUser.username} with role [${roleNameFor(effectiveRoleId)}] by @$operator',
    );

    notifyListeners();
    return true;
  }

  /// Update existing user (Manager, Admin, Developer)
  Future<void> updateUser(AppUser updated) async {
    final idx = _users.indexWhere((u) => u.id == updated.id);
    if (idx != -1) {
      // Non-developer cannot elevate any user to developer
      if (updated.roleId == AppRole.developerId && !isDeveloper) {
        return;
      }

      final operator = _currentUser?.username ?? 'admin';
      final stamped = updated.copyWith(
        updatedBy: operator,
        updatedAt: DateTime.now(),
      );

      _users[idx] = stamped;
      await _storage.saveUsers(_users);

      if (_currentUser?.id == updated.id) {
        _currentUser = stamped;
        await _storage.saveActiveSessionUser(stamped);
      }

      _logEvent(
        action: AuditAction.update,
        entityType: AuditEntityType.auth,
        entityId: stamped.id,
        entityTitle: stamped.displayName,
        description:
            'Updated user account: ${stamped.username} [${roleNameFor(stamped.roleId)}] by @$operator',
      );

      notifyListeners();
    }
  }

  /// Soft Delete User (Admin or Developer)
  /// User is NOT removed from database: preserves audit record until Developer purges
  Future<bool> deleteUser(String userId) async {
    if (userId == 'user_admin_default' ||
        userId == 'user_developer_default' ||
        _currentUser?.id == userId) {
      return false; // cannot delete default accounts or active session
    }

    // Manager CANNOT delete users!
    if (!canDeleteUsers) {
      return false;
    }

    final target = _users.firstWhere((u) => u.id == userId);

    // Non-developer cannot delete developer accounts
    if (target.roleId == AppRole.developerId && !isDeveloper) {
      return false;
    }

    final operator = _currentUser?.username ?? 'admin';
    final idx = _users.indexWhere((u) => u.id == userId);
    if (idx != -1) {
      _users[idx] = target.copyWith(
        isDeleted: true,
        deletedAt: DateTime.now(),
        deletedBy: operator,
      );
      await _storage.saveUsers(_users);

      _logEvent(
        action: AuditAction.softDelete,
        entityType: AuditEntityType.auth,
        entityId: userId,
        entityTitle: target.displayName,
        description:
            'Soft-deleted user account: ${target.username} by @$operator (preserved in database for Developer audit)',
      );

      notifyListeners();
      return true;
    }
    return false;
  }

  /// Restore a soft-deleted user (Admin or Developer)
  Future<bool> restoreUser(String userId) async {
    final idx = _users.indexWhere((u) => u.id == userId);
    if (idx != -1) {
      final target = _users[idx];
      _users[idx] = target.copyWith(
        isDeleted: false,
        deletedAt: null,
        deletedBy: null,
      );
      await _storage.saveUsers(_users);

      final operator = _currentUser?.username ?? 'admin';
      _logEvent(
        action: AuditAction.restore,
        entityType: AuditEntityType.auth,
        entityId: userId,
        entityTitle: target.displayName,
        description: 'Restored user account: ${target.username} by @$operator',
      );

      notifyListeners();
      return true;
    }
    return false;
  }

  /// Developer Master Right: Permanently purge user from database
  Future<bool> permanentDeleteUser(String userId) async {
    if (!isDeveloper) {
      return false; // Only DEVELOPER has final delete right!
    }

    if (userId == 'user_admin_default' ||
        userId == 'user_developer_default' ||
        _currentUser?.id == userId) {
      return false; // cannot delete root accounts or self
    }

    final target = _users.firstWhere((u) => u.id == userId);
    _users.removeWhere((u) => u.id == userId);
    await _storage.saveUsers(_users);

    final operator = _currentUser?.username ?? 'developer';
    _logEvent(
      action: AuditAction.permanentDelete,
      entityType: AuditEntityType.auth,
      entityId: userId,
      entityTitle: target.displayName,
      description:
          'DEVELOPER @$operator permanently purged user "${target.username}" from database',
    );

    notifyListeners();
    return true;
  }

  /// Developer Master Right: Block or unblock a user from logging in
  Future<bool> toggleBlockUser(String userId) async {
    if (!isDeveloper) {
      return false; // Only DEVELOPER has block rights!
    }

    if (userId == 'user_admin_default' ||
        userId == 'user_developer_default' ||
        _currentUser?.id == userId) {
      return false; // cannot block root accounts or self
    }

    final idx = _users.indexWhere((u) => u.id == userId);
    if (idx != -1) {
      final target = _users[idx];
      final newBlockStatus = !target.isBlocked;
      final operator = _currentUser?.username ?? 'developer';

      _users[idx] = target.copyWith(
        isBlocked: newBlockStatus,
        blockedAt: newBlockStatus ? DateTime.now() : null,
        blockedBy: newBlockStatus ? operator : null,
      );
      await _storage.saveUsers(_users);

      _logEvent(
        action: AuditAction.update,
        entityType: AuditEntityType.auth,
        entityId: userId,
        entityTitle: target.displayName,
        description:
            'DEVELOPER ${newBlockStatus ? 'BLOCKED' : 'UNBLOCKED'} user "${target.username}"',
      );

      notifyListeners();
      return true;
    }
    return false;
  }

  /// Create a new custom role (Admin or Developer can add a new role)
  Future<AppRole> createCustomRole({
    required String name,
    String description = '',
    String copyFromRoleId = 'clerk',
  }) async {
    if (!canManagePermissions) {
      throw StateError('Permission denied: Only Developer and Admin can create custom roles.');
    }

    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw ArgumentError('Role name cannot be empty');
    }

    final roleId =
        'role_${cleanName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_')}_${DateTime.now().millisecondsSinceEpoch % 10000}';
    final newRole = AppRole(
      id: roleId,
      name: cleanName,
      description: description.trim(),
      isBuiltIn: false,
    );

    // Baseline permissions copied from chosen template
    final template = permissionsForId(copyFromRoleId);
    final initialPermissions = template.copyWith(roleId: roleId);

    _customRoles.add(newRole);
    _rolePermissions[roleId] = initialPermissions;

    await _storage.saveCustomRoles(_customRoles);
    await _storage.saveRolePermissions(_rolePermissions);

    _logEvent(
      action: AuditAction.create,
      entityType: AuditEntityType.settings,
      entityId: roleId,
      entityTitle: 'Role: $cleanName',
      description:
          'Created new role "$cleanName" modeled from template [$copyFromRoleId] by @${_currentUser?.username ?? 'admin'}',
    );

    notifyListeners();
    return newRole;
  }

  /// Delete a custom role (built-in roles cannot be deleted)
  Future<bool> deleteCustomRole(String roleId) async {
    if (!canManagePermissions) {
      return false;
    }

    final roleIndex = _customRoles.indexWhere((r) => r.id == roleId);
    if (roleIndex == -1) return false;

    // Check if any user currently has this role
    final hasAssignedUsers = _users.any((u) => u.roleId == roleId);
    if (hasAssignedUsers) {
      return false; // Cannot delete role while users are assigned to it
    }

    final deleted = _customRoles.removeAt(roleIndex);
    _rolePermissions.remove(roleId);

    await _storage.saveCustomRoles(_customRoles);
    await _storage.saveRolePermissions(_rolePermissions);

    _logEvent(
      action: AuditAction.permanentDelete,
      entityType: AuditEntityType.settings,
      entityId: roleId,
      entityTitle: 'Role: ${deleted.name}',
      description: 'Deleted custom role "${deleted.name}" by @${_currentUser?.username ?? 'admin'}',
    );

    notifyListeners();
    return true;
  }

  /// Dynamically update permissions for a role identifier
  Future<void> updateRolePermissionsForId(
      String roleId, RolePermissions newPermissions) async {
    if (!canManagePermissions) {
      throw StateError('Permission denied: Only Developer and Admin can modify dynamic permissions.');
    }

    // Safety check: Admin & Developer always maintain canManageUsers
    RolePermissions safePermissions = newPermissions;
    if (roleId == AppRole.adminId || roleId == AppRole.developerId) {
      if (!safePermissions.canManageUsers) {
        safePermissions = safePermissions.copyWith(
          canAddUsers: true,
          canEditUsers: true,
          canDeleteUsers: true,
        );
      }
    }

    _rolePermissions[roleId] = safePermissions;
    await _storage.saveRolePermissions(_rolePermissions);

    _logEvent(
      action: AuditAction.update,
      entityType: AuditEntityType.settings,
      entityId: 'rbac_$roleId',
      entityTitle: 'RBAC Permissions: ${roleNameFor(roleId)}',
      description:
          'Dynamically updated permissions for role [${roleNameFor(roleId)}] by @${_currentUser?.username ?? 'admin'}',
    );

    notifyListeners();
  }

  /// Backwards-compatible helper for UserRole enum
  Future<void> updateRolePermissions(
          UserRole role, RolePermissions newPermissions) =>
      updateRolePermissionsForId(role.name, newPermissions);

  /// Reset permissions for a role to factory defaults
  Future<void> resetRolePermissionsForId(String roleId) async {
    if (!canManagePermissions) {
      return;
    }

    _rolePermissions[roleId] = RolePermissions.defaultForId(roleId);
    await _storage.saveRolePermissions(_rolePermissions);

    _logEvent(
      action: AuditAction.update,
      entityType: AuditEntityType.settings,
      entityId: 'rbac_$roleId',
      entityTitle: 'RBAC Permissions: ${roleNameFor(roleId)}',
      description:
          'Reset permissions for role [${roleNameFor(roleId)}] to factory defaults by @${_currentUser?.username ?? 'admin'}',
    );

    notifyListeners();
  }

  /// Backwards-compatible helper for UserRole enum
  Future<void> resetRolePermissions(UserRole role) =>
      resetRolePermissionsForId(role.name);

  void _logEvent({
    required AuditAction action,
    required AuditEntityType entityType,
    required String entityId,
    required String entityTitle,
    required String description,
  }) {
    if (onAuditLog != null) {
      final entry = AuditLogEntry(
        id: _uuid.v4(),
        timestamp: DateTime.now(),
        action: action,
        entityType: entityType,
        entityId: entityId,
        entityTitle: entityTitle,
        performedBy: _currentUser?.username ?? 'system',
        userRole: _currentUser != null
            ? roleNameFor(_currentUser!.roleId)
            : 'OPERATOR',
        description: description,
      );
      onAuditLog!(entry);
    }
  }
}
