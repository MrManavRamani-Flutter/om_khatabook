import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_user.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

class UserManagementDialog extends StatefulWidget {
  final int initialTabIndex;

  const UserManagementDialog({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<UserManagementDialog> createState() => _UserManagementDialogState();
}

class _UserManagementDialogState extends State<UserManagementDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedRoleId = AppRole.managerId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openAddUserDialog(BuildContext context, AuthProvider auth) {
    final usernameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final displayNameCtrl = TextEditingController();

    // Use visible roles for role selection (Admin cannot assign Developer role)
    final visibleRoles = auth.visibleRoles;
    String selectedRoleId = visibleRoles.any((r) => r.id == AppRole.clerkId)
        ? AppRole.clerkId
        : visibleRoles.first.id;
    String? errorText;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Row(
            children: [
              Icon(Icons.person_add_outlined, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Create New Authorized User'),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (errorText != null) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).brightness == Brightness.dark
                          ? AppColors.warningBgDark
                          : AppColors.warningBgLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      errorText!,
                      style: const TextStyle(
                          color: AppColors.warningText, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: usernameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Username *',
                    hintText: 'e.g. accountant_surat',
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password *',
                    hintText: 'Minimum 6 characters',
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: displayNameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Full Display Name',
                    hintText: 'e.g. Ramesh Bhai (Accountant)',
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Assign System Role & Permissions:',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: selectedRoleId,
                  decoration: InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  items: visibleRoles.map((r) {
                    return DropdownMenuItem<String>(
                      value: r.id,
                      child: Text('${r.name} (${r.id.toUpperCase()})'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setModalState(() => selectedRoleId = val);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final u = usernameCtrl.text.trim();
                final p = passwordCtrl.text.trim();
                final d = displayNameCtrl.text.trim();

                if (u.isEmpty || p.isEmpty) {
                  setModalState(
                      () => errorText = 'Username and password are required.');
                  return;
                }
                if (p.length < 6) {
                  setModalState(() =>
                      errorText = 'Password must be at least 6 characters.');
                  return;
                }

                final ok = await auth.addUser(
                  username: u,
                  password: p,
                  displayName: d.isNotEmpty ? d : u,
                  roleId: selectedRoleId,
                );

                if (!ok) {
                  setModalState(() =>
                      errorText = 'Username "$u" already exists. Choose another.');
                  return;
                }

                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'User "$u" added successfully with role [${auth.roleNameFor(selectedRoleId)}]'),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                }
              },
              child: const Text('Create User'),
            ),
          ],
        ),
      ),
    );
  }

  void _openAddRoleDialog(BuildContext context, AuthProvider auth) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String copyFromRoleId = AppRole.clerkId;
    String? errorText;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Row(
            children: [
              Icon(Icons.add_moderator_outlined, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Create New System Role'),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (errorText != null) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).brightness == Brightness.dark
                          ? AppColors.warningBgDark
                          : AppColors.warningBgLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      errorText!,
                      style: const TextStyle(
                          color: AppColors.warningText, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Role Title / Name *',
                    hintText: 'e.g. Store Auditor, Inventory Supervisor',
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText:
                        'e.g. Overseas delivery challans and customer balance',
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Copy Initial Baseline Permissions From:',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: copyFromRoleId,
                  decoration: InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  items: auth.visibleRoles.map((r) {
                    return DropdownMenuItem<String>(
                      value: r.id,
                      child: Text('Template: ${r.name}'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setModalState(() => copyFromRoleId = val);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final roleName = nameCtrl.text.trim();
                final roleDesc = descCtrl.text.trim();

                if (roleName.isEmpty) {
                  setModalState(
                      () => errorText = 'Please provide a role name.');
                  return;
                }

                // Check for duplicate name
                if (auth.allRoles.any((r) =>
                    r.name.trim().toLowerCase() ==
                    roleName.trim().toLowerCase())) {
                  setModalState(
                      () => errorText = 'A role named "$roleName" already exists.');
                  return;
                }

                final newRole = await auth.createCustomRole(
                  name: roleName,
                  description: roleDesc,
                  copyFromRoleId: copyFromRoleId,
                );

                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                  setState(() {
                    _selectedRoleId = newRole.id;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'New role "${newRole.name}" created and saved to database.'),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                }
              },
              child: const Text('Create Role'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteRole(
      BuildContext context, AuthProvider auth, AppRole role) {
    // Check if any users are currently assigned to this role
    final assignedUsers =
        auth.users.where((u) => u.roleId == role.id).toList();

    if (assignedUsers.isNotEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.warningText),
              SizedBox(width: 8),
              Text('Cannot Delete Role'),
            ],
          ),
          content: Text(
            'The role "${role.name}" is currently assigned to ${assignedUsers.length} user(s):\n\n${assignedUsers.map((u) => '• ${u.displayName} (@${u.username})').join('\n')}\n\nPlease reassign these users to another role before deleting this role.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.delete_outline, color: AppColors.warningText),
            const SizedBox(width: 8),
            Text('Delete Role "${role.name}"?'),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete custom role "${role.name}"?\nThis role and its permissions will be removed from the database.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warningText,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final ok = await auth.deleteCustomRole(role.id);
              if (ok) {
                setState(() {
                  _selectedRoleId = auth.visibleRoles.first.id;
                });
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Custom role "${role.name}" deleted.'),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete Role'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteUser(
      BuildContext context, AuthProvider auth, AppUser user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.delete_outline, color: AppColors.warningText),
            const SizedBox(width: 8),
            Text('Delete User "${user.username}"?'),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete authorized account "${user.displayName}"?\nThis action will be recorded in the audit trail.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warningText,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final ok = await auth.deleteUser(user.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok
                        ? 'User "${user.username}" deleted.'
                        : 'Cannot delete primary admin/developer account or current active session.'),
                    backgroundColor:
                        ok ? AppColors.primary : AppColors.warningText,
                  ),
                );
              }
            },
            child: const Text('Delete User'),
          ),
        ],
      ),
    );
  }

  void _confirmResetPermissions(
      BuildContext context, AuthProvider auth, String roleId, String roleName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.restore, color: AppColors.primary),
            const SizedBox(width: 8),
            Text('Reset $roleName Permissions?'),
          ],
        ),
        content: Text(
          'Restore factory default permissions for "$roleName"? Custom toggles will be overwritten and saved to the database.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await auth.resetRolePermissionsForId(roleId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Permissions for $roleName reset to system defaults.'),
                    backgroundColor: AppColors.primary,
                  ),
                );
              }
            },
            child: const Text('Reset to Defaults'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    // Visible users & roles filtered dynamically: Admin cannot view developer accounts/roles
    final visibleUsers = auth.visibleUsers;
    final visibleRoles = auth.visibleRoles;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Safety fallback: ensure selected role is visible
    if (!visibleRoles.any((r) => r.id == _selectedRoleId)) {
      _selectedRoleId = visibleRoles.first.id;
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 740),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER ROW
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            auth.isDeveloper
                                ? Icons.code
                                : Icons.admin_panel_settings,
                            color: auth.isDeveloper
                                ? const Color(0xFF7C3AED)
                                : AppColors.primary,
                            size: 26,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            auth.isDeveloper
                                ? 'Developer & Dynamic RBAC Management'
                                : 'User Authentication & Dynamic RBAC Roles',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Manage system operators, create custom roles, and configure dynamic database permissions',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.color
                              ?.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // TAB BAR
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: AppColors.primary,
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor:
                      isDark ? Colors.white70 : Colors.black87,
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: [
                    Tab(
                      icon: const Icon(Icons.people_alt_outlined, size: 18),
                      text: '👥 Authorized Users (${visibleUsers.length})',
                    ),
                    Tab(
                      icon: const Icon(Icons.shield_outlined, size: 18),
                      text:
                          '🛡️ Dynamic Role Permissions (${visibleRoles.length} Roles)',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // TAB VIEWS
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // TAB 1: USERS ROSTER
                    _buildUsersTab(context, auth, visibleUsers),

                    // TAB 2: DYNAMIC PERMISSIONS MATRIX
                    _buildDynamicPermissionsTab(context, auth, isDark),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- TAB 1: USERS ROSTER ---
  Widget _buildUsersTab(
      BuildContext context, AuthProvider auth, List<AppUser> users) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Active System Accounts',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            if (auth.canManageUsers)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add User'),
                onPressed: () => _openAddUserDialog(context, auth),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // ROLE OVERVIEW SUMMARY
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border:
                Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              if (auth.isDeveloper) ...[
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('💻 Developer',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF7C3AED))),
                      Text('Master supervision & dev tools',
                          style: TextStyle(fontSize: 10.5, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('👑 Admin',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary)),
                    Text('Full master control, user manager & purge',
                        style: TextStyle(fontSize: 10.5, color: Colors.grey)),
                  ],
                ),
              ),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('💼 Manager',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0284C7))),
                    Text('Commercial operations, audits & bin restore',
                        style: TextStyle(fontSize: 10.5, color: Colors.grey)),
                  ],
                ),
              ),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('📝 Clerk',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF059669))),
                    Text('Data entry & viewing (customizable perms)',
                        style: TextStyle(fontSize: 10.5, color: Colors.grey)),
                  ],
                ),
              ),
              if (auth.customRoles.isNotEmpty) ...[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('🏷️ Custom (${auth.customRoles.length})',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFD97706))),
                      const Text('User-defined roles with dynamic matrix',
                          style: TextStyle(fontSize: 10.5, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // USERS LIST
        Expanded(
          child: ListView.separated(
            itemCount: users.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final u = users[index];
              final isCurrent = auth.currentUser?.id == u.id;
              final isDefaultAdmin = u.username == 'admin';
              final isDefaultDev = u.username == 'developer';

              Color roleColor;
              IconData roleIcon;

              if (u.roleId == AppRole.developerId) {
                roleColor = const Color(0xFF7C3AED);
                roleIcon = Icons.code;
              } else if (u.roleId == AppRole.adminId) {
                roleColor = AppColors.primary;
                roleIcon = Icons.admin_panel_settings;
              } else if (u.roleId == AppRole.managerId) {
                roleColor = const Color(0xFF0284C7);
                roleIcon = Icons.business_center;
              } else if (u.roleId == AppRole.clerkId) {
                roleColor = const Color(0xFF059669);
                roleIcon = Icons.edit_note;
              } else {
                roleColor = const Color(0xFFD97706);
                roleIcon = Icons.badge_outlined;
              }

              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isCurrent
                        ? AppColors.primary
                        : Theme.of(context).dividerColor.withValues(alpha: 0.2),
                    width: isCurrent ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: roleColor.withValues(alpha: 0.15),
                      child: Icon(
                        roleIcon,
                        size: 18,
                        color: roleColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                u.displayName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: roleColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  auth.roleNameFor(u.roleId),
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: roleColor,
                                  ),
                                ),
                              ),
                              if (isCurrent) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? AppColors.successBgDark
                                        : AppColors.successBgLight,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'ACTIVE SESSION',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.successText,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '@${u.username} • Created: ${Formatters.shortDate(u.createdAt)}${u.lastLogin != null ? ' • Last Login: ${Formatters.shortDate(u.lastLogin!)}' : ''}',
                            style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.color),
                          ),
                        ],
                      ),
                    ),
                    if (auth.canManageUsers &&
                        !isDefaultAdmin &&
                        !isDefaultDev &&
                        !isCurrent &&
                        (auth.isDeveloper ||
                            u.roleId != AppRole.developerId))
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            size: 18, color: AppColors.warningText),
                        tooltip: 'Delete User Account',
                        onPressed: () => _confirmDeleteUser(context, auth, u),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // --- TAB 2: DYNAMIC PERMISSIONS MATRIX ---
  Widget _buildDynamicPermissionsTab(
      BuildContext context, AuthProvider auth, bool isDark) {
    final visibleRoles = auth.visibleRoles;
    final currentRoleObj = visibleRoles.firstWhere(
      (r) => r.id == _selectedRoleId,
      orElse: () => visibleRoles.first,
    );
    final permissions = auth.permissionsForId(currentRoleObj.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ROLE SELECTOR & ACTION BAR
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: visibleRoles.map((role) {
                    final isSelected = _selectedRoleId == role.id;
                    Color chipColor;
                    if (role.isDeveloper) {
                      chipColor = const Color(0xFF7C3AED);
                    } else if (role.isAdmin) {
                      chipColor = AppColors.primary;
                    } else if (role.isManager) {
                      chipColor = const Color(0xFF0284C7);
                    } else if (role.isClerk) {
                      chipColor = const Color(0xFF059669);
                    } else {
                      chipColor = const Color(0xFFD97706);
                    }

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(role.isBuiltIn
                            ? '${role.name} (${role.id.toUpperCase()})'
                            : '🏷️ ${role.name}'),
                        selected: isSelected,
                        selectedColor: chipColor.withValues(alpha: 0.18),
                        labelStyle: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? chipColor : null,
                          fontSize: 12.5,
                        ),
                        onSelected: (val) {
                          if (val) {
                            setState(() => _selectedRoleId = role.id);
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ADD NEW ROLE BUTTON (Admin or Developer can add a new role)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add New Role',
                      style: TextStyle(fontSize: 12)),
                  onPressed: () => _openAddRoleDialog(context, auth),
                ),
                const SizedBox(width: 6),
                if (currentRoleObj.isBuiltIn) ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Reset Defaults',
                        style: TextStyle(fontSize: 12)),
                    onPressed: () => _confirmResetPermissions(context, auth,
                        currentRoleObj.id, currentRoleObj.name),
                  ),
                ] else ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.warningText,
                      side: const BorderSide(color: AppColors.warningText),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Delete Role',
                        style: TextStyle(fontSize: 12)),
                    onPressed: () =>
                        _confirmDeleteRole(context, auth, currentRoleObj),
                  ),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),

        // BANNER
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Configuring dynamic permissions for "${currentRoleObj.name}". All switches save instantly to database and update active user permissions.',
                  style: const TextStyle(fontSize: 11.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // SCROLLABLE PERMISSIONS LIST
        Expanded(
          child: ListView(
            children: [
              _buildCategoryHeader(
                  '📦 Commercial Delivery Challans & Invoicing'),
              _buildPermissionTile(
                title: 'Create Delivery Challans',
                description:
                    'Allow operator to add and record new delivery challan vouchers',
                icon: Icons.note_add_outlined,
                value: permissions.canCreateChallan,
                onChanged: (val) => _updatePermission(
                  auth,
                  currentRoleObj,
                  permissions.copyWith(canCreateChallan: val),
                  'Create Delivery Challans',
                ),
              ),
              _buildPermissionTile(
                title: 'Edit Delivery Challans',
                description:
                    'Allow operator to modify challan amounts, dates, notes, and statuses',
                icon: Icons.edit_note_outlined,
                value: permissions.canEditChallan,
                onChanged: (val) => _updatePermission(
                  auth,
                  currentRoleObj,
                  permissions.copyWith(canEditChallan: val),
                  'Edit Delivery Challans',
                ),
              ),
              _buildPermissionTile(
                title: 'Delete Challans (Soft Delete to Bin)',
                description:
                    'Allow moving challans to Recycle Bin (can be restored later)',
                icon: Icons.delete_sweep_outlined,
                value: permissions.canDeleteChallan,
                isDanger: true,
                onChanged: (val) => _updatePermission(
                  auth,
                  currentRoleObj,
                  permissions.copyWith(canDeleteChallan: val),
                  'Soft Delete Challans',
                ),
              ),
              _buildPermissionTile(
                title: 'Print Tax Invoices (A4/A5)',
                description:
                    'Allow generating and printing commercial GST Tax Invoices',
                icon: Icons.print_outlined,
                value: permissions.canPrintInvoice,
                onChanged: (val) => _updatePermission(
                  auth,
                  currentRoleObj,
                  permissions.copyWith(canPrintInvoice: val),
                  'Print Tax Invoices',
                ),
              ),

              const SizedBox(height: 10),
              _buildCategoryHeader(
                  '♻️ Two-Stage Recycle Bin & Data Protection'),
              _buildPermissionTile(
                title: 'Restore Challans from Recycle Bin',
                description:
                    'Allow recovering soft-deleted challans back to active ledger',
                icon: Icons.restore_from_trash_outlined,
                value: permissions.canRestoreChallan,
                onChanged: (val) => _updatePermission(
                  auth,
                  currentRoleObj,
                  permissions.copyWith(canRestoreChallan: val),
                  'Restore from Recycle Bin',
                ),
              ),
              _buildPermissionTile(
                title: 'Permanent Purge Recycle Bin',
                description:
                    'Irrevocably erase soft-deleted vouchers from disk permanently',
                icon: Icons.delete_forever_outlined,
                value: permissions.canPurgeRecycleBin,
                isDanger: true,
                onChanged: (val) => _updatePermission(
                  auth,
                  currentRoleObj,
                  permissions.copyWith(canPurgeRecycleBin: val),
                  'Permanent Purge Recycle Bin',
                ),
              ),

              const SizedBox(height: 10),
              _buildCategoryHeader(
                  '👥 Commercial Counterparties & Financial Reports'),
              _buildPermissionTile(
                title: 'Register & Manage Parties',
                description:
                    'Allow creating new buyer/seller parties and modifying phone numbers',
                icon: Icons.business_outlined,
                value: permissions.canManageParties,
                onChanged: (val) => _updatePermission(
                  auth,
                  currentRoleObj,
                  permissions.copyWith(canManageParties: val),
                  'Manage Parties',
                ),
              ),
              _buildPermissionTile(
                title: 'Export Reports (PDF / Excel .xlsx)',
                description:
                    'Allow downloading accounting reports and party balance sheets',
                icon: Icons.file_download_outlined,
                value: permissions.canExportReports,
                onChanged: (val) => _updatePermission(
                  auth,
                  currentRoleObj,
                  permissions.copyWith(canExportReports: val),
                  'Export Reports',
                ),
              ),

              const SizedBox(height: 10),
              _buildCategoryHeader('🛡️ Audit Trail & Regulatory Compliance'),
              _buildPermissionTile(
                title: 'View System Audit Trail Logs',
                description:
                    'Allow inspecting modification history logs, user logins, and timestamps',
                icon: Icons.history_edu_outlined,
                value: permissions.canViewAuditLogs,
                onChanged: (val) => _updatePermission(
                  auth,
                  currentRoleObj,
                  permissions.copyWith(canViewAuditLogs: val),
                  'View Audit Logs',
                ),
              ),
              _buildPermissionTile(
                title: 'Clear Audit Trail History',
                description:
                    'Allow erasing historical modification logs from database',
                icon: Icons.cleaning_services_outlined,
                value: permissions.canClearAuditLogs,
                isDanger: true,
                onChanged: (val) => _updatePermission(
                  auth,
                  currentRoleObj,
                  permissions.copyWith(canClearAuditLogs: val),
                  'Clear Audit Trail History',
                ),
              ),

              const SizedBox(height: 10),
              _buildCategoryHeader(
                  '⚙️ System Administration & Master Control'),
              _buildPermissionTile(
                title: 'Manage Users & Role Permissions',
                description:
                    'Allow adding/deleting users and dynamically altering role permissions',
                icon: Icons.admin_panel_settings_outlined,
                value: permissions.canManageUsers,
                isLockedForAdmin: currentRoleObj.isAdmin || currentRoleObj.isDeveloper,
                onChanged: (val) => _updatePermission(
                  auth,
                  currentRoleObj,
                  permissions.copyWith(canManageUsers: val),
                  'Manage Users & Role Permissions',
                ),
              ),
              _buildPermissionTile(
                title: 'Modify Company Branding & Settings',
                description:
                    'Allow altering company name, tagline, app logos, and typography',
                icon: Icons.tune_outlined,
                value: permissions.canManageSettings,
                onChanged: (val) => _updatePermission(
                  auth,
                  currentRoleObj,
                  permissions.copyWith(canManageSettings: val),
                  'Modify Company Branding',
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6, left: 4),
      child: Text(
        title,
        style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
      ),
    );
  }

  Widget _buildPermissionTile({
    required String title,
    required String description,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool isDanger = false,
    bool isLockedForAdmin = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(icon,
              size: 20,
              color: isDanger ? AppColors.warningText : AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    if (isLockedForAdmin) ...[
                      const SizedBox(width: 6),
                      const Tooltip(
                        message:
                            'Safety Lock: User management cannot be revoked from this role to prevent system lockout',
                        child: Icon(Icons.lock, size: 13, color: Colors.grey),
                      ),
                    ],
                  ],
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.color
                        ?.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbImage: null,
            activeThumbColor:
                isDanger ? AppColors.warningText : AppColors.primary,
            onChanged: isLockedForAdmin ? null : onChanged,
          ),
        ],
      ),
    );
  }

  Future<void> _updatePermission(
    AuthProvider auth,
    AppRole role,
    RolePermissions updated,
    String permissionName,
  ) async {
    await auth.updateRolePermissionsForId(role.id, updated);
    if (mounted) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 1400),
          content: Text(
            'Saved: "$permissionName" updated for ${role.name}',
          ),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }
}
