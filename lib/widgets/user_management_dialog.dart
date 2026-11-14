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
  UserRole _selectedRoleForPermissions = UserRole.manager;

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
    UserRole selectedRole = UserRole.clerk;
    String? errorText;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                      style: const TextStyle(color: AppColors.warningText, fontSize: 12),
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
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: displayNameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Full Display Name',
                    hintText: 'e.g. Ramesh Bhai (Accountant)',
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Assign System Role & Permissions:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                DropdownButtonFormField<UserRole>(
                  initialValue: selectedRole,
                  decoration: InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: UserRole.values.map((r) {
                    return DropdownMenuItem(
                      value: r,
                      child: Text('${r.label} (${r.name.toUpperCase()})'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setModalState(() => selectedRole = val);
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
                  setModalState(() => errorText = 'Username and password are required.');
                  return;
                }
                if (p.length < 6) {
                  setModalState(() => errorText = 'Password must be at least 6 characters.');
                  return;
                }

                final ok = await auth.addUser(
                  username: u,
                  password: p,
                  displayName: d.isNotEmpty ? d : u,
                  role: selectedRole,
                );

                if (!ok) {
                  setModalState(() => errorText = 'Username "$u" already exists. Choose another.');
                  return;
                }

                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('User "$u" added successfully with role ${selectedRole.label}'),
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

  void _confirmDeleteUser(BuildContext context, AuthProvider auth, AppUser user) {
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
                        : 'Cannot delete primary admin account or current active session.'),
                    backgroundColor: ok ? AppColors.primary : AppColors.warningText,
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

  void _confirmResetPermissions(BuildContext context, AuthProvider auth, UserRole role) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.restore, color: AppColors.primary),
            const SizedBox(width: 8),
            Text('Reset ${role.label} Permissions?'),
          ],
        ),
        content: Text(
          'Restore factory default permissions for "${role.label}"? Custom toggles will be overwritten and saved to the database.',
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
              await auth.resetRolePermissions(role);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Permissions for ${role.label} reset to system defaults.'),
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
    final users = auth.users;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER ROW
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'User Accounts & Dynamic RBAC Permissions',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Manage authorized users and dynamically configure database-persisted permissions',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // TAB BAR
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: isDark ? Colors.grey[400] : Colors.grey[700],
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.people_outline, size: 18),
                          const SizedBox(width: 8),
                          Text('Authorized Users (${users.length})'),
                        ],
                      ),
                    ),
                    const Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.security, size: 18),
                          SizedBox(width: 8),
                          Text('Dynamic Role Permissions (Database)'),
                        ],
                      ),
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
                    _buildUsersTab(context, auth, users),

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
  Widget _buildUsersTab(BuildContext context, AuthProvider auth, List<AppUser> users) {
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
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
          ),
          child: const Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('👑 Admin',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    Text('Full master control, user manager & purge',
                        style: TextStyle(fontSize: 10.5, color: Colors.grey)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('💼 Manager',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                    Text('Commercial operations, audits & bin restore',
                        style: TextStyle(fontSize: 10.5, color: Colors.grey)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('📝 Clerk',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                    Text('Data entry & viewing (customizable perms)',
                        style: TextStyle(fontSize: 10.5, color: Colors.grey)),
                  ],
                ),
              ),
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
              final isDefaultAdmin = u.id == 'user_admin_default';

              Color roleColor;
              switch (u.role) {
                case UserRole.admin:
                  roleColor = AppColors.primary;
                  break;
                case UserRole.manager:
                  roleColor = const Color(0xFF0284C7);
                  break;
                case UserRole.clerk:
                  roleColor = const Color(0xFF059669);
                  break;
              }

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                        u.role == UserRole.admin
                            ? Icons.admin_panel_settings
                            : (u.role == UserRole.manager
                                ? Icons.business_center
                                : Icons.edit_note),
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
                                    fontWeight: FontWeight.bold, fontSize: 13.5),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: roleColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  u.role.name.toUpperCase(),
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
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).brightness == Brightness.dark
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
                                color: Theme.of(context).textTheme.bodySmall?.color),
                          ),
                        ],
                      ),
                    ),
                    if (auth.canManageUsers && !isDefaultAdmin && !isCurrent)
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
    final permissions = auth.permissionsFor(_selectedRoleForPermissions);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ROLE SELECTOR & ACTION BAR
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Wrap(
              spacing: 8,
              children: UserRole.values.map((role) {
                final isSelected = _selectedRoleForPermissions == role;
                Color chipColor;
                switch (role) {
                  case UserRole.admin:
                    chipColor = AppColors.primary;
                    break;
                  case UserRole.manager:
                    chipColor = const Color(0xFF0284C7);
                    break;
                  case UserRole.clerk:
                    chipColor = const Color(0xFF059669);
                    break;
                }

                return ChoiceChip(
                  label: Text('${role.label} (${role.name.toUpperCase()})'),
                  selected: isSelected,
                  selectedColor: chipColor.withValues(alpha: 0.18),
                  labelStyle: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? chipColor : null,
                    fontSize: 12.5,
                  ),
                  onSelected: (val) {
                    if (val) {
                      setState(() => _selectedRoleForPermissions = role);
                    }
                  },
                );
              }).toList(),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Reset to Defaults', style: TextStyle(fontSize: 12)),
              onPressed: () =>
                  _confirmResetPermissions(context, auth, _selectedRoleForPermissions),
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
            border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Configuring dynamic permissions for "${_selectedRoleForPermissions.label}". All switches save instantly to database and update active user permissions.',
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
              _buildCategoryHeader('📦 Commercial Delivery Challans & Invoicing'),
              _buildPermissionTile(
                title: 'Create Delivery Challans',
                description: 'Allow operator to add and record new delivery challan vouchers',
                icon: Icons.note_add_outlined,
                value: permissions.canCreateChallan,
                onChanged: (val) => _updatePermission(
                  auth,
                  permissions.copyWith(canCreateChallan: val),
                  'Create Delivery Challans',
                ),
              ),
              _buildPermissionTile(
                title: 'Edit Delivery Challans',
                description: 'Allow operator to modify challan amounts, dates, notes, and statuses',
                icon: Icons.edit_note_outlined,
                value: permissions.canEditChallan,
                onChanged: (val) => _updatePermission(
                  auth,
                  permissions.copyWith(canEditChallan: val),
                  'Edit Delivery Challans',
                ),
              ),
              _buildPermissionTile(
                title: 'Delete Challans (Soft Delete to Bin)',
                description: 'Allow moving challans to Recycle Bin (can be restored later)',
                icon: Icons.delete_outline,
                value: permissions.canDeleteChallan,
                onChanged: (val) => _updatePermission(
                  auth,
                  permissions.copyWith(canDeleteChallan: val),
                  'Delete Challans',
                ),
              ),
              _buildPermissionTile(
                title: 'Print Single-Page GST Tax Invoices',
                description: 'Allow generating formal printable A4 and A5 commercial GST invoices',
                icon: Icons.receipt_long_outlined,
                value: permissions.canPrintInvoice,
                onChanged: (val) => _updatePermission(
                  auth,
                  permissions.copyWith(canPrintInvoice: val),
                  'Print GST Tax Invoices',
                ),
              ),

              const SizedBox(height: 10),
              _buildCategoryHeader('🗑️ Recycle Bin & Irrevocable Purging'),
              _buildPermissionTile(
                title: 'Restore from Recycle Bin',
                description: 'Allow recovering deleted challans and parties back to active ledger',
                icon: Icons.restore_from_trash_outlined,
                value: permissions.canRestoreChallan,
                onChanged: (val) => _updatePermission(
                  auth,
                  permissions.copyWith(canRestoreChallan: val),
                  'Restore from Recycle Bin',
                ),
              ),
              _buildPermissionTile(
                title: 'Permanently Purge Recycle Bin',
                description: 'Allow irrevocable deletion of soft-deleted items from database',
                icon: Icons.delete_forever_outlined,
                value: permissions.canPurgeRecycleBin,
                isDanger: true,
                onChanged: (val) => _updatePermission(
                  auth,
                  permissions.copyWith(canPurgeRecycleBin: val),
                  'Permanently Purge Recycle Bin',
                ),
              ),

              const SizedBox(height: 10),
              _buildCategoryHeader('🏢 Commercial Parties Directory'),
              _buildPermissionTile(
                title: 'Manage Parties Directory',
                description: 'Allow adding, editing, or deleting registered commercial party entities',
                icon: Icons.business_outlined,
                value: permissions.canManageParties,
                onChanged: (val) => _updatePermission(
                  auth,
                  permissions.copyWith(canManageParties: val),
                  'Manage Parties Directory',
                ),
              ),

              const SizedBox(height: 10),
              _buildCategoryHeader('📊 Reports & Audit Trail'),
              _buildPermissionTile(
                title: 'Export Financial Reports (Excel & PDF)',
                description: 'Allow generating and saving PDF statements and Excel .xlsx sheets',
                icon: Icons.file_download_outlined,
                value: permissions.canExportReports,
                onChanged: (val) => _updatePermission(
                  auth,
                  permissions.copyWith(canExportReports: val),
                  'Export Financial Reports',
                ),
              ),
              _buildPermissionTile(
                title: 'View Tamper-Evident Audit Trail Log',
                description: 'Allow accessing complete history log of creates, edits, and logins',
                icon: Icons.history_outlined,
                value: permissions.canViewAuditLogs,
                onChanged: (val) => _updatePermission(
                  auth,
                  permissions.copyWith(canViewAuditLogs: val),
                  'View Audit Trail Log',
                ),
              ),
              _buildPermissionTile(
                title: 'Clear Audit Trail History',
                description: 'Allow purging audit history logs from the database',
                icon: Icons.delete_sweep_outlined,
                value: permissions.canClearAuditLogs,
                isDanger: true,
                onChanged: (val) => _updatePermission(
                  auth,
                  permissions.copyWith(canClearAuditLogs: val),
                  'Clear Audit Trail History',
                ),
              ),

              const SizedBox(height: 10),
              _buildCategoryHeader('⚙️ System Administration & Master Control'),
              _buildPermissionTile(
                title: 'Manage Users & Role Permissions',
                description: 'Allow adding/deleting users and dynamically altering role permissions',
                icon: Icons.admin_panel_settings_outlined,
                value: permissions.canManageUsers,
                isLockedForAdmin: _selectedRoleForPermissions == UserRole.admin,
                onChanged: (val) => _updatePermission(
                  auth,
                  permissions.copyWith(canManageUsers: val),
                  'Manage Users & Role Permissions',
                ),
              ),
              _buildPermissionTile(
                title: 'Modify Company Branding & Settings',
                description: 'Allow altering company name, tagline, app logos, and typography',
                icon: Icons.tune_outlined,
                value: permissions.canManageSettings,
                onChanged: (val) => _updatePermission(
                  auth,
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
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
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
          Icon(icon, size: 20, color: isDanger ? AppColors.warningText : AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    if (isLockedForAdmin) ...[
                      const SizedBox(width: 6),
                      const Tooltip(
                        message: 'Admin must maintain user management to prevent accidental lockout',
                        child: Icon(Icons.lock, size: 13, color: Colors.grey),
                      ),
                    ],
                  ],
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbImage: null,
            activeThumbColor: isDanger ? AppColors.warningText : AppColors.primary,
            onChanged: isLockedForAdmin ? null : onChanged,
          ),
        ],
      ),
    );
  }

  Future<void> _updatePermission(
    AuthProvider auth,
    RolePermissions updated,
    String permissionName,
  ) async {
    await auth.updateRolePermissions(_selectedRoleForPermissions, updated);
    if (mounted) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 1400),
          content: Text(
            'Saved: "$permissionName" updated for ${_selectedRoleForPermissions.label}',
          ),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }
}
