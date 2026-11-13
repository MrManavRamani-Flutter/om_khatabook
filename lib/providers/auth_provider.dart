import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/app_user.dart';
import '../models/audit_log_entry.dart';
import '../services/storage_service.dart';

class AuthProvider extends ChangeNotifier {
  final StorageService _storage;
  final Uuid _uuid = const Uuid();

  List<AppUser> _users = [];
  AppUser? _currentUser;
  bool _isLoading = true;

  // Callback to log audit events
  void Function(AuditLogEntry entry)? onAuditLog;

  AuthProvider(this._storage);

  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  AppUser? get currentUser => _currentUser;
  List<AppUser> get users => List.unmodifiable(_users);

  UserRole get currentRole => _currentUser?.role ?? UserRole.clerk;
  bool get isAdmin => currentRole == UserRole.admin;
  bool get isManager => currentRole == UserRole.manager;
  bool get isClerk => currentRole == UserRole.clerk;

  // Permission shortcuts
  bool get canDelete => currentRole.canDeleteEntries;
  bool get canPurgeRecycleBin => currentRole.canPurgeRecycleBin;
  bool get canManageUsers => currentRole.canManageUsers;
  bool get canManageSettings => currentRole.canManageSettings;
  bool get canViewAuditLogs => currentRole.canViewAuditLogs;
  bool get canClearAuditLogs => currentRole.canClearAuditLogs;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    _users = await _storage.loadUsers();

    // Seed default users if first time
    if (_users.isEmpty) {
      _users = [
        AppUser(
          id: 'user_admin_default',
          username: 'admin',
          password: 'admin123',
          displayName: 'Administrator (OM Mavtar)',
          role: UserRole.admin,
          email: 'admin@ommavtar.com',
          phone: '+91 98250 12345',
          createdAt: DateTime.now(),
        ),
        AppUser(
          id: 'user_manager_default',
          username: 'manager',
          password: 'manager123',
          displayName: 'Branch Commercial Manager',
          role: UserRole.manager,
          email: 'manager@ommavtar.com',
          phone: '+91 98250 22334',
          createdAt: DateTime.now(),
        ),
        AppUser(
          id: 'user_clerk_default',
          username: 'clerk',
          password: 'clerk123',
          displayName: 'Accountant / Entry Clerk',
          role: UserRole.clerk,
          email: 'accounts@ommavtar.com',
          phone: '+91 98250 33445',
          createdAt: DateTime.now(),
        ),
      ];
      await _storage.saveUsers(_users);
    }

    // Try to restore existing active session
    final savedUser = await _storage.loadActiveSessionUser();
    if (savedUser != null) {
      // Verify user still exists and is active
      final matched = _users.where((u) => u.id == savedUser.id && u.isActive).toList();
      if (matched.isNotEmpty) {
        _currentUser = matched.first;
      } else {
        await _storage.saveActiveSessionUser(null);
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Authenticate with username and password
  Future<bool> login(String username, String password, {bool rememberMe = true}) async {
    final cleanUsername = username.trim().toLowerCase();
    final cleanPassword = password.trim();

    final matched = _users.where(
      (u) =>
          u.username.trim().toLowerCase() == cleanUsername &&
          u.password == cleanPassword &&
          u.isActive,
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
      description: 'User ${updated.username} (${updated.role.label}) logged in successfully',
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

  /// Add new user (Admin only)
  Future<bool> addUser({
    required String username,
    required String password,
    required String displayName,
    required UserRole role,
    String email = '',
    String phone = '',
  }) async {
    final cleanUsername = username.trim().toLowerCase();
    if (_users.any((u) => u.username.trim().toLowerCase() == cleanUsername)) {
      return false; // username already taken
    }

    final newUser = AppUser(
      id: _uuid.v4(),
      username: cleanUsername,
      password: password.trim(),
      displayName: displayName.trim().isNotEmpty ? displayName.trim() : username.trim(),
      role: role,
      email: email.trim(),
      phone: phone.trim(),
      createdAt: DateTime.now(),
    );

    _users.add(newUser);
    await _storage.saveUsers(_users);

    _logEvent(
      action: AuditAction.create,
      entityType: AuditEntityType.auth,
      entityId: newUser.id,
      entityTitle: newUser.displayName,
      description: 'Created new user account: ${newUser.username} with role ${newUser.role.label}',
    );

    notifyListeners();
    return true;
  }

  /// Update existing user
  Future<void> updateUser(AppUser updated) async {
    final idx = _users.indexWhere((u) => u.id == updated.id);
    if (idx != -1) {
      _users[idx] = updated;
      await _storage.saveUsers(_users);

      if (_currentUser?.id == updated.id) {
        _currentUser = updated;
        await _storage.saveActiveSessionUser(updated);
      }

      _logEvent(
        action: AuditAction.update,
        entityType: AuditEntityType.auth,
        entityId: updated.id,
        entityTitle: updated.displayName,
        description: 'Updated user account: ${updated.username} (${updated.role.label})',
      );

      notifyListeners();
    }
  }

  /// Delete user (cannot delete default admin)
  Future<bool> deleteUser(String userId) async {
    if (userId == 'user_admin_default' || _currentUser?.id == userId) {
      return false; // cannot delete default admin or self
    }

    final target = _users.firstWhere((u) => u.id == userId);
    _users.removeWhere((u) => u.id == userId);
    await _storage.saveUsers(_users);

    _logEvent(
      action: AuditAction.permanentDelete,
      entityType: AuditEntityType.auth,
      entityId: userId,
      entityTitle: target.displayName,
      description: 'Deleted user account: ${target.username}',
    );

    notifyListeners();
    return true;
  }

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
        userRole: _currentUser?.role.name.toUpperCase() ?? 'ADMIN',
        description: description,
      );
      onAuditLog!(entry);
    }
  }
}
