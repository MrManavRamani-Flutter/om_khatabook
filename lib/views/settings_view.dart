import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_user.dart';
import '../models/challan_entry.dart';
import '../providers/auth_provider.dart';
import '../providers/challan_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/branding_dialogs.dart';

class SettingsView extends StatefulWidget {
  final int initialCategoryIndex;
  final String? initialRoleId;

  const SettingsView({
    super.key,
    this.initialCategoryIndex = 0,
    this.initialRoleId,
  });

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late int _selectedCategoryIndex;
  late String _selectedRoleId;

  late final TextEditingController _companyNameController;
  late final TextEditingController _companyTaglineController;
  late final TextEditingController _manualLogoPathController;
  late final TextEditingController _adminNameController;
  late final TextEditingController _adminRoleController;
  late final TextEditingController _manualAvatarPathController;

  @override
  void initState() {
    super.initState();
    _selectedCategoryIndex = widget.initialCategoryIndex.clamp(0, 3);
    _selectedRoleId = widget.initialRoleId ?? AppRole.managerId;

    final provider = context.read<ChallanProvider>();
    _companyNameController = TextEditingController(text: provider.companyName);
    _companyTaglineController = TextEditingController(text: provider.companyTagline);
    _manualLogoPathController = TextEditingController();
    _adminNameController = TextEditingController(text: provider.adminName);
    _adminRoleController = TextEditingController(text: provider.adminRole);
    _manualAvatarPathController = TextEditingController();
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _companyTaglineController.dispose();
    _manualLogoPathController.dispose();
    _adminNameController.dispose();
    _adminRoleController.dispose();
    _manualAvatarPathController.dispose();
    super.dispose();
  }

  // --- DIALOGS FOR USER & ROLE ACTIONS ---

  void _openAddUserDialog(BuildContext context, AuthProvider auth) {
    final usernameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final displayNameCtrl = TextEditingController();

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

  void _openEditUserDialog(
      BuildContext context, AuthProvider auth, AppUser user) {
    final displayNameCtrl = TextEditingController(text: user.displayName);
    final passwordCtrl = TextEditingController();
    String selectedRoleId = user.roleId;
    String? errorText;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Row(
            children: [
              const Icon(Icons.edit_outlined, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Edit User: @${user.username}'),
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
                  controller: displayNameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Display Name *',
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
                    labelText: 'Reset Password (Leave blank to keep current)',
                    hintText: 'Minimum 6 characters',
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Role & Permissions Profile:',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: auth.visibleRoles.any((r) => r.id == selectedRoleId)
                      ? selectedRoleId
                      : auth.visibleRoles.first.id,
                  decoration: InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  items: auth.visibleRoles.map((r) {
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
                final d = displayNameCtrl.text.trim();
                final p = passwordCtrl.text.trim();
                if (d.isEmpty) {
                  setModalState(
                      () => errorText = 'Display name cannot be empty.');
                  return;
                }
                if (p.isNotEmpty && p.length < 6) {
                  setModalState(() =>
                      errorText = 'Password must be at least 6 characters.');
                  return;
                }

                await auth.updateUser(
                  user.copyWith(
                    displayName: d,
                    password: p.isNotEmpty ? p : user.password,
                    roleId: selectedRoleId,
                    role: RolePermissions.roleFromId(selectedRoleId),
                  ),
                );

                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text('User @${user.username} updated successfully.'),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                }
              },
              child: const Text('Save Changes'),
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
            Text('Soft-Delete User "${user.username}"?'),
          ],
        ),
        content: Text(
          'Are you sure you want to deactivate authorized user "${user.displayName}" (@${user.username})?\n\n'
          '🔒 Data Preservation Guarantee:\n'
          'The account is soft-deleted and will NOT be erased from the database. '
          'Records are safely preserved for Developer audit and can only be permanently purged by Developer.',
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
                        ? 'User "${user.username}" soft-deleted (preserved in database).'
                        : 'Cannot delete primary root account or current active session.'),
                    backgroundColor:
                        ok ? AppColors.primary : AppColors.warningText,
                  ),
                );
              }
            },
            child: const Text('Deactivate / Soft Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmPermanentPurgeUser(
      BuildContext context, AuthProvider auth, AppUser user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red),
            SizedBox(width: 8),
            Text('Permanent Purge from DB?'),
          ],
        ),
        content: Text(
          '⚠️ DEVELOPER EXCLUSIVE ACTION:\n\n'
          'Are you sure you want to permanently erase user account "${user.displayName}" (@${user.username}) from the database?\n\n'
          'This action is irreversible and permanently removes the record from storage.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final ok = await auth.permanentDeleteUser(user.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok
                        ? 'User "${user.username}" permanently purged from database.'
                        : 'Could not purge user.'),
                    backgroundColor: ok ? Colors.red : AppColors.warningText,
                  ),
                );
              }
            },
            child: const Text('Permanent DB Purge'),
          ),
        ],
      ),
    );
  }

  void _confirmRestoreUser(
      BuildContext context, AuthProvider auth, AppUser user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.restore, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Restore User Account?'),
          ],
        ),
        content: Text(
          'Restore previously deactivated account "${user.displayName}" (@${user.username}) back to active status?',
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
              final ok = await auth.restoreUser(user.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok
                        ? 'User "${user.username}" restored to active status.'
                        : 'Could not restore user.'),
                    backgroundColor: AppColors.primary,
                  ),
                );
              }
            },
            child: const Text('Restore User'),
          ),
        ],
      ),
    );
  }

  void _confirmToggleBlockUser(
      BuildContext context, AuthProvider auth, AppUser user) {
    final willBlock = !user.isBlocked;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(willBlock ? Icons.block : Icons.lock_open,
                color: willBlock ? AppColors.warningText : AppColors.primary),
            const SizedBox(width: 8),
            Text('${willBlock ? 'Block' : 'Unblock'} User "${user.username}"?'),
          ],
        ),
        content: Text(
          willBlock
              ? 'Are you sure you want to block "${user.displayName}" (@${user.username}) from logging in? They will be denied entry until Developer unblocks them.'
              : 'Are you sure you want to unblock "${user.displayName}" (@${user.username})? They will be allowed to log in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: willBlock ? AppColors.warningText : AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final ok = await auth.toggleBlockUser(user.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok
                        ? 'User "${user.username}" ${willBlock ? 'blocked' : 'unblocked'}.'
                        : 'Could not toggle block status.'),
                    backgroundColor:
                        willBlock ? AppColors.warningText : AppColors.primary,
                  ),
                );
              }
            },
            child: Text(willBlock ? 'Block User' : 'Unblock User'),
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

  // --- BACKUP & RESTORE DIALOGS ---

  Future<void> _exportBackup(BuildContext context) async {
    try {
      final path = await context.read<ChallanProvider>().exportBackup();
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.successText),
                SizedBox(width: 8),
                Text('Backup Exported!'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Data backup JSON file saved successfully:'),
                const SizedBox(height: 8),
                SelectableText(
                  path,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 12),
                const Text(
                  'You can copy this file to an external drive or keep it safe on your PC/Mac.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  void _showImportDialog(BuildContext context) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore from Backup JSON'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Paste your backup JSON content below:'),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText: '{\n  "app": "OM Mavtar Group Khata Book",\n  ...\n}',
                ),
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
              final val = textController.text.trim();
              if (val.isEmpty) return;
              final provider = context.read<ChallanProvider>();
              final messenger = ScaffoldMessenger.of(context);
              final nav = Navigator.of(ctx);
              final ok = await provider.importBackup(val);
              nav.pop();
              messenger.showSnackBar(
                SnackBar(
                  content: Text(ok
                      ? 'Backup restored successfully!'
                      : 'Invalid backup JSON data format.'),
                  backgroundColor:
                      ok ? AppColors.primary : AppColors.warningText,
                ),
              );
            },
            child: const Text('Restore Data'),
          ),
        ],
      ),
    );
  }

  void _showResetConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset to Sample Data?'),
        content: const Text(
          'This will restore default sample parties and challan records for OM Mavtar Group.',
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
              await context.read<ChallanProvider>().initialize();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sample data reloaded.')),
                );
              }
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  // --- MAIN BUILD METHOD ---

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChallanProvider>();
    final auth = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final visibleRoles = auth.visibleRoles;
    if (!visibleRoles.any((r) => r.id == _selectedRoleId)) {
      _selectedRoleId = visibleRoles.first.id;
    }

    // Categories list for vertical sidebar navigation
    final categories = [
      {
        'title': 'Role Permissions (RBAC)',
        'subtitle': '5-Pillar dynamic capability matrix',
        'icon': Icons.shield_outlined,
        'badge': '${visibleRoles.length} Roles',
      },
      {
        'title': 'Authorized Users',
        'subtitle': 'Manage operator accounts & credentials',
        'icon': Icons.people_alt_outlined,
        'badge': '${auth.visibleUsers.length} Users',
      },
      {
        'title': 'Appearance & Branding',
        'subtitle': 'Company logo, theme & typography',
        'icon': Icons.palette_outlined,
      },
      {
        'title': 'Backup & Data Safety',
        'subtitle': 'JSON exports, restore & database',
        'icon': Icons.backup_outlined,
      },
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LEFT VERTICAL NAVIGATION SUB-SIDEBAR (WIDTH: 260px)
          Container(
            width: 260,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              border: Border(
                right: BorderSide(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // HEADER
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            auth.isDeveloper ? Icons.code : Icons.tune_rounded,
                            color: auth.isDeveloper
                                ? const Color(0xFF7C3AED)
                                : AppColors.primary,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Settings & RBAC',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'System administration & preferences',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.color
                              ?.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // VERTICAL CATEGORY NAV TILES
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    itemCount: categories.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final cat = categories[index];
                      final isSelected = _selectedCategoryIndex == index;

                      return Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: isSelected
                              ? Border.all(color: AppColors.primary.withValues(alpha: 0.3))
                              : null,
                        ),
                        child: ListTile(
                          dense: true,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          leading: Icon(
                            cat['icon'] as IconData,
                            size: 20,
                            color: isSelected ? AppColors.primary : Colors.grey,
                          ),
                          title: Text(
                            cat['title'] as String,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? AppColors.primary : null,
                            ),
                          ),
                          subtitle: Text(
                            cat['subtitle'] as String,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.color
                                  ?.withValues(alpha: 0.7),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: cat['badge'] != null
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primary
                                        : Colors.grey.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    cat['badge'] as String,
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? Colors.white : null,
                                    ),
                                  ),
                                )
                              : null,
                          onTap: () {
                            setState(() => _selectedCategoryIndex = index);
                          },
                        ),
                      );
                    },
                  ),
                ),

                // FOOTER: CURRENT OPERATOR BADGE
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: auth.isDeveloper
                            ? const Color(0xFF7C3AED)
                            : AppColors.primary,
                        child: Icon(
                          auth.isDeveloper ? Icons.code : Icons.person,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              auth.currentUser?.displayName ?? 'Admin',
                              style: const TextStyle(
                                  fontSize: 11.5, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              auth.roleNameFor(auth.currentRoleId),
                              style: TextStyle(
                                fontSize: 9.5,
                                color: auth.isDeveloper
                                    ? const Color(0xFF7C3AED)
                                    : AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // RIGHT MAIN CONTENT AREA
          Expanded(
            child: _buildSelectedCategoryContent(context, auth, provider, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedCategoryContent(
    BuildContext context,
    AuthProvider auth,
    ChallanProvider provider,
    bool isDark,
  ) {
    switch (_selectedCategoryIndex) {
      case 0:
        return _buildRolePermissionsPage(context, auth, isDark);
      case 1:
        return _buildAuthorizedUsersPage(context, auth, isDark);
      case 2:
        return _buildAppearanceAndBrandingPage(context, provider, isDark);
      case 3:
        return _buildBackupAndDatabasePage(context, provider, auth, isDark);
      default:
        return _buildRolePermissionsPage(context, auth, isDark);
    }
  }

  // ===========================================================================
  // CATEGORY 0: ROLE PERMISSIONS (RBAC) - 100% VERTICAL MASTER-DETAIL
  // ===========================================================================
  Widget _buildRolePermissionsPage(
    BuildContext context,
    AuthProvider auth,
    bool isDark,
  ) {
    final visibleRoles = auth.visibleRoles;
    final currentRoleObj = visibleRoles.firstWhere(
      (r) => r.id == _selectedRoleId,
      orElse: () => visibleRoles.first,
    );
    final permissions = auth.permissionsForId(currentRoleObj.id);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // VERTICAL ROLES SELECTION LIST (WIDTH: 270px)
        Container(
          width: 270,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor.withValues(alpha: 0.5),
            border: Border(
              right: BorderSide(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'SYSTEM ROLES',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      '${visibleRoles.length} Available',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // VERTICAL LIST OF ROLES (NO HORIZONTAL CHIPS!)
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: visibleRoles.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final role = visibleRoles[index];
                    final isSelected = _selectedRoleId == role.id;

                    Color roleColor;
                    IconData roleIcon;
                    String roleTag;

                    if (role.isDeveloper) {
                      roleColor = const Color(0xFF7C3AED);
                      roleIcon = Icons.code;
                      roleTag = 'DEVELOPER';
                    } else if (role.isAdmin) {
                      roleColor = AppColors.primary;
                      roleIcon = Icons.admin_panel_settings;
                      roleTag = 'ADMIN';
                    } else if (role.isManager) {
                      roleColor = const Color(0xFF0284C7);
                      roleIcon = Icons.business_center;
                      roleTag = 'MANAGER';
                    } else if (role.isClerk) {
                      roleColor = const Color(0xFF059669);
                      roleIcon = Icons.edit_note;
                      roleTag = 'CLERK';
                    } else {
                      roleColor = const Color(0xFFD97706);
                      roleIcon = Icons.badge_outlined;
                      roleTag = 'CUSTOM';
                    }

                    return Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? roleColor.withValues(alpha: isDark ? 0.2 : 0.08)
                            : Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? roleColor
                              : Theme.of(context)
                                  .dividerColor
                                  .withValues(alpha: 0.2),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          setState(() => _selectedRoleId = role.id);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: roleColor.withValues(alpha: 0.15),
                                child: Icon(roleIcon, size: 16, color: roleColor),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      role.name,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w600,
                                        color: isSelected ? roleColor : null,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      role.description.isNotEmpty
                                          ? role.description
                                          : 'System operational role',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.color
                                            ?.withValues(alpha: 0.7),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: roleColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  roleTag,
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.bold,
                                    color: roleColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // BOTTOM ACTION BUTTONS (VERTICAL & CLEAR)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add New System Role',
                            style: TextStyle(fontSize: 12)),
                        onPressed: () => _openAddRoleDialog(context, auth),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (currentRoleObj.isBuiltIn) ...[
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.refresh, size: 16),
                          label: Text('Reset ${currentRoleObj.name} Defaults',
                              style: const TextStyle(fontSize: 11)),
                          onPressed: () => _confirmResetPermissions(
                              context,
                              auth,
                              currentRoleObj.id,
                              currentRoleObj.name),
                        ),
                      ),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.warningText,
                            side: const BorderSide(color: AppColors.warningText),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.delete_outline, size: 16),
                          label: Text('Delete "${currentRoleObj.name}"',
                              style: const TextStyle(fontSize: 11)),
                          onPressed: () =>
                              _confirmDeleteRole(context, auth, currentRoleObj),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        // RIGHT PERMISSIONS MATRIX (EXPANDED & SCROLLABLE)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.shield_outlined,
                          size: 20, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Configuring Dynamic Permissions for: ${currentRoleObj.name}',
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              'Switches save automatically to local database and update active user capabilities in real time.',
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
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 5 CORE PILLARS PERMISSION LIST
                Expanded(
                  child: ListView(
                    children: [
                      // 1. 👁️ VIEW PERMISSIONS
                      _buildCategoryHeader(
                          '👁️ 1. VIEW PERMISSIONS (Ledgers, Reports & Invoicing)'),
                      _buildPermissionTile(
                        title: 'View Delivery Challans & Ledger',
                        description:
                            'Allow operator to inspect delivery challans, balances, and payment statuses',
                        icon: Icons.receipt_long_outlined,
                        value: permissions.canViewChallans,
                        onChanged: (val) => _updatePermission(
                          auth,
                          currentRoleObj,
                          permissions.copyWith(canViewChallans: val),
                          'View Delivery Challans',
                        ),
                      ),
                      _buildPermissionTile(
                        title: 'View Counterparties Directory',
                        description:
                            'Allow operator to search and view customer profiles, phone numbers, and ledgers',
                        icon: Icons.people_outline,
                        value: permissions.canViewParties,
                        onChanged: (val) => _updatePermission(
                          auth,
                          currentRoleObj,
                          permissions.copyWith(canViewParties: val),
                          'View Counterparties Directory',
                        ),
                      ),
                      _buildPermissionTile(
                        title: 'View Financial Summary Reports',
                        description:
                            'Allow viewing aggregate turnover cards, pending dues, and monthly charts',
                        icon: Icons.bar_chart_outlined,
                        value: permissions.canViewReports,
                        onChanged: (val) => _updatePermission(
                          auth,
                          currentRoleObj,
                          permissions.copyWith(canViewReports: val),
                          'View Financial Reports',
                        ),
                      ),
                      _buildPermissionTile(
                        title: 'Print Commercial Tax Invoices (A4/A5)',
                        description:
                            'Allow generating single-page commercial GST Tax Invoices and thermal slips',
                        icon: Icons.print_outlined,
                        value: permissions.canPrintInvoice,
                        onChanged: (val) => _updatePermission(
                          auth,
                          currentRoleObj,
                          permissions.copyWith(canPrintInvoice: val),
                          'Print Tax Invoices',
                        ),
                      ),

                      const SizedBox(height: 14),
                      // 2. ➕ ADD / CREATE PERMISSIONS
                      _buildCategoryHeader(
                          '➕ 2. ADD / CREATE PERMISSIONS (Challans, Parties & Users)'),
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
                        title: 'Register Counterparties',
                        description:
                            'Allow registering new buyer and seller party accounts in the directory',
                        icon: Icons.person_add_alt_1_outlined,
                        value: permissions.canManageParties,
                        onChanged: (val) => _updatePermission(
                          auth,
                          currentRoleObj,
                          permissions.copyWith(canManageParties: val),
                          'Register Counterparties',
                        ),
                      ),
                      _buildPermissionTile(
                        title: 'Add / Create Authorized Users',
                        description:
                            'Allow creating new authorized system operator accounts (Manager, Admin, Developer)',
                        icon: Icons.group_add_outlined,
                        value: permissions.canAddUsers,
                        isLockedForAdmin: currentRoleObj.isAdmin || currentRoleObj.isDeveloper,
                        onChanged: (val) => _updatePermission(
                          auth,
                          currentRoleObj,
                          permissions.copyWith(canAddUsers: val),
                          'Add Authorized Users',
                        ),
                      ),

                      const SizedBox(height: 14),
                      // 3. ✏️ EDIT / UPDATE PERMISSIONS
                      _buildCategoryHeader(
                          '✏️ 3. EDIT / UPDATE PERMISSIONS (Challans, Users & Branding)'),
                      _buildPermissionTile(
                        title: 'Edit Delivery Challans',
                        description:
                            'Allow operator to modify voucher amounts, dates, notes, and payment statuses',
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
                        title: 'Update Authorized Users & Roles',
                        description:
                            'Allow updating user display names, passwords, and assigned roles',
                        icon: Icons.manage_accounts_outlined,
                        value: permissions.canEditUsers,
                        isLockedForAdmin: currentRoleObj.isAdmin || currentRoleObj.isDeveloper,
                        onChanged: (val) => _updatePermission(
                          auth,
                          currentRoleObj,
                          permissions.copyWith(canEditUsers: val),
                          'Update Authorized Users',
                        ),
                      ),
                      _buildPermissionTile(
                        title: 'Modify Company Branding & Settings',
                        description:
                            'Allow altering company name, tagline, app logos, and typography profile',
                        icon: Icons.tune_outlined,
                        value: permissions.canManageSettings,
                        onChanged: (val) => _updatePermission(
                          auth,
                          currentRoleObj,
                          permissions.copyWith(canManageSettings: val),
                          'Modify Company Branding',
                        ),
                      ),

                      const SizedBox(height: 14),
                      // 4. 🗑️ DELETE & DATA RECOVERY PERMISSIONS
                      _buildCategoryHeader(
                          '🗑️ 4. DELETE & RECOVERY PERMISSIONS (Soft Delete, Recycle Bin & DB Purge)'),
                      _buildPermissionTile(
                        title: 'Soft-Delete Challans (Move to Recycle Bin)',
                        description:
                            'Allow moving challans to Recycle Bin (can be recovered later)',
                        icon: Icons.delete_sweep_outlined,
                        value: permissions.canDeleteChallan,
                        isDanger: true,
                        onChanged: (val) => _updatePermission(
                          auth,
                          currentRoleObj,
                          permissions.copyWith(canDeleteChallan: val),
                          'Soft-Delete Challans',
                        ),
                      ),
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
                          'Restore Challans',
                        ),
                      ),
                      _buildPermissionTile(
                        title: 'Permanently Purge Recycle Bin Vouchers',
                        description:
                            'Irrevocably erase soft-deleted vouchers from storage permanently',
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
                      _buildPermissionTile(
                        title: 'Deactivate / Soft-Delete Users',
                        description:
                            'Soft-delete user accounts (Manager = false, Admin = true; record remains preserved in database)',
                        icon: Icons.person_remove_outlined,
                        value: permissions.canDeleteUsers,
                        isDanger: true,
                        onChanged: (val) => _updatePermission(
                          auth,
                          currentRoleObj,
                          permissions.copyWith(canDeleteUsers: val),
                          'Deactivate / Soft-Delete Users',
                        ),
                      ),
                      _buildPermissionTile(
                        title: 'Permanent Erase Users from Database (Developer Only)',
                        description:
                            'Irrevocably purge user records permanently from database storage',
                        icon: Icons.highlight_off_outlined,
                        value: permissions.canPermanentDeleteUsers,
                        isDanger: true,
                        isLockedForAdmin: !currentRoleObj.isDeveloper,
                        onChanged: (val) => _updatePermission(
                          auth,
                          currentRoleObj,
                          permissions.copyWith(canPermanentDeleteUsers: val),
                          'Permanent Erase Users from DB',
                        ),
                      ),

                      const SizedBox(height: 14),
                      // 5. 📜 AUDIT TRAIL & LOG PERMISSIONS
                      _buildCategoryHeader(
                          '📜 5. AUDIT TRAIL & LOG PERMISSIONS (Supervision & Compliance)'),
                      _buildPermissionTile(
                        title: 'View System Audit Trail Logs & Record History',
                        description:
                            'Developer supervised: view modification history, timestamps, and who changed/added records',
                        icon: Icons.history_edu_outlined,
                        value: permissions.canViewAuditLogs,
                        onChanged: (val) => _updatePermission(
                          auth,
                          currentRoleObj,
                          permissions.copyWith(canViewAuditLogs: val),
                          'View Audit Trail Logs',
                        ),
                      ),
                      _buildPermissionTile(
                        title: 'Clear Audit Trail History (Developer Only)',
                        description:
                            'Irrevocably erase historical audit logs from database storage',
                        icon: Icons.cleaning_services_outlined,
                        value: permissions.canClearAuditLogs,
                        isDanger: true,
                        isLockedForAdmin: !currentRoleObj.isDeveloper,
                        onChanged: (val) => _updatePermission(
                          auth,
                          currentRoleObj,
                          permissions.copyWith(canClearAuditLogs: val),
                          'Clear Audit Trail History',
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // CATEGORY 1: AUTHORIZED USERS ROSTER - 100% FULL SCREEN VERTICAL CARDS
  // ===========================================================================
  Widget _buildAuthorizedUsersPage(
    BuildContext context,
    AuthProvider auth,
    bool isDark,
  ) {
    final users = auth.visibleUsers;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // TOP ACTION BAR
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Authorized System Accounts',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Manage operator credentials, access states, and role assignments',
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
              if (auth.canAddUsers)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.person_add_alt_1, size: 18),
                  label: const Text('Add Authorized User',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () => _openAddUserDialog(context, auth),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // SUMMARY ROLE BREAKDOWN CARD
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
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
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF7C3AED))),
                        Text('Full master supervision, audit & DB purge',
                            style: TextStyle(fontSize: 10, color: Colors.grey)),
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
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary)),
                      Text('Add/edit users & soft-deactivate (no final purge)',
                          style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                ),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('💼 Manager',
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0284C7))),
                      Text('Add & edit users (NO delete rights permitted)',
                          style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                ),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('📝 Clerk',
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF059669))),
                      Text('Data entry & viewing (customizable perms)',
                          style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // USERS ROSTER VERTICAL LIST
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isCurrent
                          ? AppColors.primary
                          : u.isDeleted
                              ? AppColors.warningText.withValues(alpha: 0.5)
                              : Theme.of(context)
                                  .dividerColor
                                  .withValues(alpha: 0.2),
                      width: isCurrent ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: roleColor.withValues(alpha: 0.15),
                        child: Icon(roleIcon, size: 20, color: roleColor),
                      ),
                      const SizedBox(width: 14),
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
                                      fontSize: 14),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
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
                                        horizontal: 6, vertical: 2),
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
                                if (u.isBlocked) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.warningBgDark,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'BLOCKED',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                                if (u.isDeleted) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'DELETED (IN DB)',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.deepOrange,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '@${u.username} • Created by @${u.createdBy} on ${Formatters.shortDate(u.createdAt)}'
                              '${u.updatedBy != null ? ' • Modified by @${u.updatedBy}' : ''}'
                              '${u.deletedBy != null && u.isDeleted ? ' • Soft-deleted by @${u.deletedBy}' : ''}'
                              '${u.blockedBy != null && u.isBlocked ? ' • Blocked by @${u.blockedBy}' : ''}'
                              '${u.lastLogin != null ? ' • Last Login: ${Formatters.shortDate(u.lastLogin!)}' : ''}',
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

                      // ROW ACTIONS
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (u.isDeleted) ...[
                            if (auth.isDeveloper) ...[
                              IconButton(
                                icon: const Icon(Icons.restore_from_trash,
                                    size: 20, color: AppColors.primary),
                                tooltip: 'Restore User Account',
                                onPressed: () =>
                                    _confirmRestoreUser(context, auth, u),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_forever,
                                    size: 20, color: Colors.red),
                                tooltip:
                                    'Irrevocable Permanent DB Purge (Developer Only)',
                                onPressed: () =>
                                    _confirmPermanentPurgeUser(context, auth, u),
                              ),
                            ],
                          ] else ...[
                            if (auth.isDeveloper &&
                                !isDefaultDev &&
                                !isDefaultAdmin &&
                                !isCurrent) ...[
                              IconButton(
                                icon: Icon(
                                  u.isBlocked ? Icons.lock_open : Icons.block,
                                  size: 19,
                                  color: u.isBlocked
                                      ? AppColors.successText
                                      : AppColors.warningText,
                                ),
                                tooltip: u.isBlocked
                                    ? 'Unblock User'
                                    : 'Block User (Developer Only)',
                                onPressed: () =>
                                    _confirmToggleBlockUser(context, auth, u),
                              ),
                            ],
                            if (auth.canEditUsers &&
                                (!isDefaultDev || auth.isDeveloper)) ...[
                              IconButton(
                                icon: const Icon(Icons.edit_outlined,
                                    size: 19, color: AppColors.primary),
                                tooltip: 'Edit User & Credentials',
                                onPressed: () =>
                                    _openEditUserDialog(context, auth, u),
                              ),
                            ],
                            if (auth.canDeleteUsers &&
                                !isDefaultAdmin &&
                                !isDefaultDev &&
                                !isCurrent &&
                                (u.roleId != AppRole.developerId ||
                                    auth.isDeveloper)) ...[
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    size: 19, color: AppColors.warningText),
                                tooltip:
                                    'Deactivate / Soft-Delete User (Preserves in DB)',
                                onPressed: () =>
                                    _confirmDeleteUser(context, auth, u),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // CATEGORY 2: APPEARANCE & COMPANY BRANDING (100% INLINE, NO POPUP DIALOGS)
  // ===========================================================================
  Widget _buildAppearanceAndBrandingPage(
    BuildContext context,
    ChallanProvider provider,
    bool isDark,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Appearance & Company Branding',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Manage official company branding, logo, operator credentials, and visual display preferences directly inline.',
            style: TextStyle(
              fontSize: 12.5,
              color: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.color
                  ?.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 22),

          // 1. COMPANY BRAND IDENTITY & OFFICIAL LOGO (INLINE)
          _buildCompanyBrandingCard(context, provider, isDark),
          const SizedBox(height: 20),

          // 2. OPERATOR / ADMIN PROFILE & AVATAR (INLINE)
          _buildAdminProfileCard(context, provider, isDark),
          const SizedBox(height: 20),

          // 3. DISPLAY THEME MODE
          _buildThemeModeCard(context, provider, isDark),
          const SizedBox(height: 20),

          // 4. TEXT CASING & TYPOGRAPHY
          _buildTextCasingCard(context, provider, isDark),
        ],
      ),
    );
  }

  Widget _buildCompanyBrandingCard(
    BuildContext context,
    ChallanProvider provider,
    bool isDark,
  ) {
    final hasCustomLogo = provider.appLogoBase64.isNotEmpty;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: isDark ? 0 : 1,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.business_center, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Company Brand Identity & Official Logo',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Updates the navigation header, summary reports, and printed GST commercial tax invoices.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(height: 1),
            const SizedBox(height: 18),

            // INLINE LOGO PREVIEW & UPLOAD
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const AppLogoWidget(
                    size: 64,
                    borderRadius: 14,
                    showEditBadge: false,
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              hasCustomLogo ? 'Custom Brand Logo' : 'Default OM Mavtar Logo',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: hasCustomLogo
                                    ? AppColors.primary.withValues(alpha: 0.15)
                                    : Colors.grey.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                hasCustomLogo ? 'Active' : 'Built-in Asset',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: hasCustomLogo ? AppColors.primary : Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Upload a PNG, JPG, or WEBP image file directly from your computer.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              ),
                              icon: const Icon(Icons.file_upload_outlined, size: 17),
                              label: const Text('Change Brand Logo...'),
                              onPressed: () async {
                                final b64 = await BrandingDialogs.pickImageAsBase64();
                                if (b64 != null && b64.isNotEmpty) {
                                  provider.setAppLogoBase64(b64);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Company brand logo updated successfully!'),
                                        backgroundColor: AppColors.primary,
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                            if (hasCustomLogo)
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                ),
                                icon: const Icon(Icons.restore, size: 16),
                                label: const Text('Reset to Default Logo'),
                                onPressed: () {
                                  provider.setAppLogoBase64('');
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Brand logo reset to default OM Mavtar Group logo.'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // OPTIONAL MANUAL FILE PATH
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _manualLogoPathController,
                    decoration: InputDecoration(
                      labelText: 'Or Local Logo File Path',
                      hintText: '/path/to/logo.png',
                      isDense: true,
                      prefixIcon: const Icon(Icons.folder_open, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    final p = _manualLogoPathController.text.trim();
                    if (p.isNotEmpty) {
                      try {
                        final file = File(p);
                        if (await file.exists()) {
                          final bytes = await file.readAsBytes();
                          provider.setAppLogoBase64(base64Encode(bytes));
                          _manualLogoPathController.clear();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Loaded and saved logo from file path!'),
                                backgroundColor: AppColors.primary,
                              ),
                            );
                          }
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('File does not exist at specified path.')),
                            );
                          }
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error loading file: $e')),
                          );
                        }
                      }
                    }
                  },
                  child: const Text('Load File'),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // INLINE FORM FIELDS (COMPANY NAME & TAGLINE)
            Text(
              'Company Details',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _companyNameController,
              decoration: InputDecoration(
                labelText: 'Company / Business Legal Name *',
                hintText: 'e.g. OM Mavtar Group',
                prefixIcon: const Icon(Icons.storefront_outlined, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _companyTaglineController,
              decoration: InputDecoration(
                labelText: 'Business Tagline / Subtitle',
                hintText: 'e.g. Khata Book Desktop & Mobile',
                prefixIcon: const Icon(Icons.subtitles_outlined, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 18),

            // SAVE BRANDING BUTTON
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Save Company Branding', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  final name = _companyNameController.text.trim();
                  final tagline = _companyTaglineController.text.trim();
                  if (name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Company name cannot be blank.'),
                        backgroundColor: AppColors.warningText,
                      ),
                    );
                    return;
                  }
                  provider.setCompanyBranding(name: name, tagline: tagline);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Company branding saved successfully!'),
                      backgroundColor: AppColors.primary,
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminProfileCard(
    BuildContext context,
    ChallanProvider provider,
    bool isDark,
  ) {
    final hasCustomPhoto = provider.profileLogoBase64.isNotEmpty;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: isDark ? 0 : 1,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.person_pin_circle_outlined, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Administrator & Operator Profile',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Shown at the bottom of the navigation sidebar and recorded in system audit logs.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(height: 1),
            const SizedBox(height: 18),

            // INLINE AVATAR PREVIEW & UPLOAD
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const ProfileAvatarWidget(
                    radius: 32,
                    showEditBadge: false,
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              hasCustomPhoto ? 'Custom Avatar Photo' : 'Default Initials Avatar',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: hasCustomPhoto
                                    ? AppColors.primary.withValues(alpha: 0.15)
                                    : Colors.grey.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                hasCustomPhoto ? 'Photo Uploaded' : 'Letter Avatar',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: hasCustomPhoto ? AppColors.primary : Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Upload your own personal portrait photo or operator profile picture.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              ),
                              icon: const Icon(Icons.add_a_photo_outlined, size: 17),
                              label: const Text('Change Avatar Photo...'),
                              onPressed: () async {
                                final b64 = await BrandingDialogs.pickImageAsBase64();
                                if (b64 != null && b64.isNotEmpty) {
                                  provider.setProfileLogoBase64(b64);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Operator profile avatar updated successfully!'),
                                        backgroundColor: AppColors.primary,
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                            if (hasCustomPhoto)
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                ),
                                icon: const Icon(Icons.restore, size: 16),
                                label: const Text('Reset to Initial Letter'),
                                onPressed: () {
                                  provider.setProfileLogoBase64('');
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Avatar reset to initial letter.'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // OPTIONAL MANUAL FILE PATH
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _manualAvatarPathController,
                    decoration: InputDecoration(
                      labelText: 'Or Local Avatar File Path',
                      hintText: '/path/to/my_photo.jpg',
                      isDense: true,
                      prefixIcon: const Icon(Icons.image_search, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    final p = _manualAvatarPathController.text.trim();
                    if (p.isNotEmpty) {
                      try {
                        final file = File(p);
                        if (await file.exists()) {
                          final bytes = await file.readAsBytes();
                          provider.setProfileLogoBase64(base64Encode(bytes));
                          _manualAvatarPathController.clear();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Loaded and saved profile avatar from file path!'),
                                backgroundColor: AppColors.primary,
                              ),
                            );
                          }
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('File does not exist at specified path.')),
                            );
                          }
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error loading file: $e')),
                          );
                        }
                      }
                    }
                  },
                  child: const Text('Load Photo'),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // INLINE FORM FIELDS (NAME & DESIGNATION ROLE)
            Text(
              'Operator Credentials',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _adminNameController,
              decoration: InputDecoration(
                labelText: 'Administrator / Operator Full Name *',
                hintText: 'e.g. Manav Ramani',
                prefixIcon: const Icon(Icons.person_outline, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _adminRoleController,
              decoration: InputDecoration(
                labelText: 'Designation / Display Role Label *',
                hintText: 'e.g. SYSTEM DEVELOPER / ADMIN',
                prefixIcon: const Icon(Icons.shield_outlined, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 18),

            // SAVE PROFILE BUTTON
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Save Profile Changes', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  final name = _adminNameController.text.trim();
                  final role = _adminRoleController.text.trim();
                  if (name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Operator name cannot be blank.'),
                        backgroundColor: AppColors.warningText,
                      ),
                    );
                    return;
                  }
                  provider.setAdminProfile(
                    name: name,
                    role: role.isNotEmpty ? role : 'Administrator',
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Operator profile updated successfully!'),
                      backgroundColor: AppColors.primary,
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeModeCard(
    BuildContext context,
    ChallanProvider provider,
    bool isDark,
  ) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: isDark ? 0 : 1,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.palette_outlined, color: AppColors.primary),
                SizedBox(width: 10),
                Text(
                  'Display Theme Mode',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Dark Mode Theme'),
              subtitle: const Text(
                'Optimized high-contrast dark theme for long working hours on Desktop',
              ),
              value: provider.isDarkMode,
              onChanged: (_) => provider.toggleTheme(),
              secondary: Icon(
                provider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextCasingCard(
    BuildContext context,
    ChallanProvider provider,
    bool isDark,
  ) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: isDark ? 0 : 1,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.text_fields_rounded, color: AppColors.primary, size: 20),
                SizedBox(width: 8),
                Text(
                  'Text Casing & Typography (Data Entry)',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Choose how party names, challans, and entry details format automatically',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 14),
            ...TextCasingStyle.values.map((style) {
              final isSelected = provider.textCasingStyle == style;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.08)
                      : Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : Theme.of(context).dividerColor.withValues(alpha: 0.25),
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => provider.setTextCasingStyle(style),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: isSelected ? AppColors.primary : Colors.grey,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    style.label,
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                      fontSize: 13,
                                      color: isSelected ? AppColors.primary : null,
                                    ),
                                  ),
                                  if (style == TextCasingStyle.uppercase) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'Default',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                style.example,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // CATEGORY 3: BACKUP & DATABASE
  // ===========================================================================
  Widget _buildBackupAndDatabasePage(
    BuildContext context,
    ChallanProvider provider,
    AuthProvider auth,
    bool isDark,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Database & Data Safety',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Inspect local database statistics, create JSON backups, and restore archived records',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.color
                  ?.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 20),

          // DATABASE OVERVIEW
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.storage_outlined, color: AppColors.primary),
                      SizedBox(width: 10),
                      Text(
                        'Database Records Overview',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatItem(
                          context,
                          'Active Challans',
                          '${provider.challans.length}',
                          Icons.receipt_long,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _buildStatItem(
                          context,
                          'Registered Parties',
                          '${provider.parties.length}',
                          Icons.people,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _buildStatItem(
                          context,
                          'Recycle Bin Items',
                          '${provider.recycleBinCount}',
                          Icons.delete_outline,
                          color: provider.recycleBinCount > 0 ? AppColors.warningText : null,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _buildStatItem(
                          context,
                          'Audit History Logs',
                          '${provider.auditLogs.length}',
                          Icons.history_edu,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // BACKUP ACTIONS
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.backup_outlined, color: AppColors.primary),
                      SizedBox(width: 10),
                      Text(
                        'Data Backup & Safekeeping',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'All your commercial ledger records are stored locally and encrypted. You can export a full JSON snapshot anytime for offsite archiving.',
                    style: TextStyle(fontSize: 12.5, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.download, size: 18),
                        label: const Text('Export JSON Backup File'),
                        onPressed: () => _exportBackup(context),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.upload, size: 18),
                        label: const Text('Restore from Backup JSON'),
                        onPressed: () => _showImportDialog(context),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.warningText,
                          side: const BorderSide(color: AppColors.warningBorder),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.restart_alt, size: 18),
                        label: const Text('Reset to Sample Data'),
                        onPressed: () => _showResetConfirm(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- HELPER WIDGETS ---

  Widget _buildCategoryHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6, left: 4),
      child: Text(
        title,
        style: const TextStyle(
            fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.grey),
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
                            'Restricted: This capability flag is strictly locked for this role category.',
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

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    Color? color,
  }) {
    final effectiveColor = color ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).dividerColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: effectiveColor.withValues(alpha: 0.12),
            child: Icon(icon, size: 18, color: effectiveColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.color
                        ?.withValues(alpha: 0.7),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
