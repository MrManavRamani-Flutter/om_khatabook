import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/challan_entry.dart';
import '../providers/auth_provider.dart';
import '../providers/challan_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/branding_dialogs.dart';
import '../widgets/import_backup_dialog.dart';
import '../widgets/password_confirmation_dialog.dart';

class SettingsView extends StatefulWidget {
  final int initialCategoryIndex;

  const SettingsView({
    super.key,
    this.initialCategoryIndex = 0,
  });

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late int _selectedCategoryIndex;

  late final TextEditingController _companyNameController;
  late final TextEditingController _companyTaglineController;
  late final TextEditingController _manualLogoPathController;
  late final TextEditingController _adminNameController;
  late final TextEditingController _adminRoleController;
  late final TextEditingController _manualAvatarPathController;

  @override
  void initState() {
    super.initState();
    _selectedCategoryIndex = widget.initialCategoryIndex.clamp(0, 1);

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

  // --- BACKUP & RESTORE ACTIONS ---

  Future<void> _revealFileInExplorer(String path) async {
    try {
      if (Platform.isMacOS) {
        await Process.run('open', ['-R', path]);
      } else if (Platform.isWindows) {
        await Process.run('explorer.exe', ['/select,', path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [File(path).parent.path]);
      }
    } catch (e) {
      debugPrint('Error revealing file: $e');
    }
  }

  Future<void> _exportBackup(BuildContext context) async {
    try {
      final path = await context.read<ChallanProvider>().exportBackup();
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.successText),
                SizedBox(width: 8),
                Text('Backup Exported Successfully!'),
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
                  'You can upload this exact .json file in "Restore Data" to recover or merge records at any time.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              OutlinedButton.icon(
                icon: const Icon(Icons.folder_open, size: 16),
                label: const Text('Show in Folder / Finder'),
                onPressed: () => _revealFileInExplorer(path),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
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
    showDialog(
      context: context,
      builder: (_) => const ImportBackupDialog(),
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
            child: const Text('Reset Data'),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to sign out from OM Mavtar Group Khata Book?'),
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
            onPressed: () {
              Navigator.of(ctx).pop();
              auth.logout();
            },
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context, AuthProvider auth) {
    final oldController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    bool obscureOld = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    String? localError;
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> submit() async {
              setDialogState(() {
                localError = null;
                isSubmitting = true;
              });

              final result = await auth.updatePassword(
                oldPassword: oldController.text,
                newPassword: newController.text,
                confirmPassword: confirmController.text,
              );

              if (!ctx.mounted) return;

              if (result.success) {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text(result.message)),
                      ],
                    ),
                    backgroundColor: AppColors.primary,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } else {
                setDialogState(() {
                  localError = result.message;
                  isSubmitting = false;
                });
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.lock_reset, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Change Password',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Master Operator: OM MAVTAR (OMMAVTAR36)',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    if (localError != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: AppColors.warningBgLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.warningText.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: AppColors.warningText, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                localError!,
                                style: const TextStyle(
                                  color: AppColors.warningText,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    // Current / Old Password
                    const Text('Current (Old) Password', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: oldController,
                      obscureText: obscureOld,
                      decoration: InputDecoration(
                        hintText: 'Enter current password (Default: OMMAVTAR36)',
                        prefixIcon: const Icon(Icons.key, size: 18),
                        suffixIcon: IconButton(
                          icon: Icon(obscureOld ? Icons.visibility_off : Icons.visibility, size: 18),
                          onPressed: () => setDialogState(() => obscureOld = !obscureOld),
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // New Password
                    const Text('New Password', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: newController,
                      obscureText: obscureNew,
                      decoration: InputDecoration(
                        hintText: 'Enter at least 4 characters',
                        prefixIcon: const Icon(Icons.lock_outline, size: 18),
                        suffixIcon: IconButton(
                          icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility, size: 18),
                          onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Confirm New Password
                    const Text('Confirm New Password', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: confirmController,
                      obscureText: obscureConfirm,
                      decoration: InputDecoration(
                        hintText: 'Re-enter new password to confirm',
                        prefixIcon: const Icon(Icons.check_circle_outline, size: 18),
                        suffixIcon: IconButton(
                          icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility, size: 18),
                          onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  ),
                  icon: isSubmitting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.save, size: 16),
                  label: Text(isSubmitting ? 'Updating...' : 'Update Password'),
                  onPressed: isSubmitting ? null : submit,
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- MAIN BUILD METHOD ---

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChallanProvider>();
    final auth = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    final categories = <Map<String, dynamic>>[
      {
        'id': 0,
        'title': 'Appearance & Branding',
        'subtitle': 'Company logo, theme & typography',
        'icon': Icons.palette_outlined,
      },
      {
        'id': 1,
        'title': 'Backup & Data Safety',
        'subtitle': 'JSON exports, restore & database',
        'icon': Icons.backup_outlined,
      },
    ];

    if (isMobile) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            // TOP MOBILE CATEGORY SELECTOR
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
                  ),
                ),
              ),
              child: Row(
                children: categories.map((cat) {
                  final catId = cat['id'] as int;
                  final isSelected = _selectedCategoryIndex == catId;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: InkWell(
                        onTap: () => setState(() => _selectedCategoryIndex = catId),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : Theme.of(context).dividerColor.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                cat['icon'] as IconData,
                                size: 18,
                                color: isSelected ? AppColors.primary : Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  cat['title'] as String,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected ? AppColors.primary : null,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // CONTENT
            Expanded(
              child: _buildSelectedCategoryContent(context, auth, provider, isDark),
            ),
          ],
        ),
      );
    }

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
                      const Row(
                        children: [
                          Icon(
                            Icons.tune_rounded,
                            color: AppColors.primary,
                            size: 22,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Settings',
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
                        'Appearance, branding & data safety',
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
                      final catId = cat['id'] as int;
                      final isSelected = _selectedCategoryIndex == catId;

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
                          onTap: () {
                            setState(() => _selectedCategoryIndex = catId);
                          },
                        ),
                      );
                    },
                  ),
                ),

                // FOOTER: CURRENT COMPANY BRAND
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
                      const CircleAvatar(
                        radius: 14,
                        backgroundColor: AppColors.primary,
                        child: Icon(
                          Icons.storefront,
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
                              provider.companyName,
                              style: const TextStyle(
                                  fontSize: 11.5, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              provider.companyTagline,
                              style: const TextStyle(
                                fontSize: 9.5,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
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
        return _buildAppearanceAndBrandingPage(context, provider, auth, isDark);
      case 1:
        return _buildBackupAndDatabasePage(context, provider, auth, isDark);
      default:
        return _buildAppearanceAndBrandingPage(context, provider, auth, isDark);
    }
  }

  // ===========================================================================
  // CATEGORY 0: APPEARANCE & COMPANY BRANDING (INLINE VERTICAL CONFIGURATION)
  // ===========================================================================
  Widget _buildAppearanceAndBrandingPage(
    BuildContext context,
    ChallanProvider provider,
    AuthProvider auth,
    bool isDark,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 14 : 24),
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
            'Manage company branding, logo, profile, and preferences.',
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

          // 3.1. THEME COLOR COMBINATIONS & STATUS COLORS
          _buildThemeColorCombinationAndStatusCard(context, provider, isDark),
          const SizedBox(height: 20),

          // 4. TEXT CASING & TYPOGRAPHY
          _buildTextCasingCard(context, provider, isDark),
          const SizedBox(height: 20),

          // 5. OPERATOR SESSION & SECURITY LOGOUT
          _buildLogoutCard(context, auth, isDark),
        ],
      ),
    );
  }

  Widget _buildLogoutCard(
    BuildContext context,
    AuthProvider auth,
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Operator Session & Security',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.account_circle, size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Master Operator: OMMAVTAR36 (OM MAVTAR)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Protected by master password (Default: OMMAVTAR36).',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.bedtime_outlined, size: 16, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Auto-Logout on Sleep / Inactive',
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                              ),
                              Text(
                                'Logs out automatically when system sleeps or is idle',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      DropdownButton<int>(
                        value: auth.sessionTimeoutMinutes,
                        underline: const SizedBox(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                        items: const [
                          DropdownMenuItem(value: 0, child: Text('On Sleep (Immediate)')),
                          DropdownMenuItem(value: 5, child: Text('5 Minutes')),
                          DropdownMenuItem(value: 15, child: Text('15 Minutes')),
                          DropdownMenuItem(value: 30, child: Text('30 Minutes')),
                          DropdownMenuItem(value: -1, child: Text('Never')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            auth.setSessionTimeoutMinutes(val);
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary, width: 1.5),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.lock_reset, size: 18),
                  label: const Text('Change Password', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () => _showChangePasswordDialog(context, auth),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warningText,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Sign Out / Logout', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () => _confirmLogout(context, auth),
                ),
              ],
            ),
          ],
        ),
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
                        'Applied to invoices, reports, and header.',
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
                          'Upload PNG, JPG, or WEBP logo.',
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
                onPressed: () async {
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

                  final confirmed = await promptPasswordConfirmation(
                    context,
                    title: 'Confirm Update Branding',
                    message: 'Enter password to confirm updating company branding to "$name".',
                    actionLabel: 'Save Branding',
                    icon: Icons.branding_watermark,
                    iconColor: AppColors.primary,
                  );
                  if (!confirmed || !context.mounted) return;

                  provider.setCompanyBranding(name: name, tagline: tagline);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Company branding saved successfully!'),
                        backgroundColor: AppColors.primary,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
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
                        'Business Owner & Operator Profile',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Displayed on sidebar and audit logs.',
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
                              hasCustomPhoto ? 'Custom Profile Photo' : 'Default Initials',
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
                                hasCustomPhoto ? 'Active' : 'Auto Generated',
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
                          'Upload photo or avatar.',
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
                                        content: Text('Profile avatar updated successfully!'),
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

            // INLINE FORM FIELDS (NAME & DESIGNATION)
            Text(
              'Profile Credentials',
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
                labelText: 'Operator / Owner Full Name *',
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
                labelText: 'Designation / Title',
                hintText: 'e.g. Owner / Administrator',
                prefixIcon: const Icon(Icons.badge_outlined, size: 20),
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
                onPressed: () async {
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

                  final confirmed = await promptPasswordConfirmation(
                    context,
                    title: 'Confirm Update Profile',
                    message: 'Enter password to confirm updating operator profile to "$name".',
                    actionLabel: 'Save Profile',
                    icon: Icons.person_outline,
                    iconColor: AppColors.primary,
                  );
                  if (!confirmed || !context.mounted) return;

                  provider.setAdminProfile(
                    name: name,
                    role: role.isNotEmpty ? role : 'Administrator',
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Profile updated successfully!'),
                        backgroundColor: AppColors.primary,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
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
                'High-contrast dark mode theme',
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

  Widget _buildThemeColorCombinationAndStatusCard(
    BuildContext context,
    ChallanProvider provider,
    bool isDark,
  ) {
    final presets = <({String name, Color primary, String label})>[
      (name: 'Teal', primary: const Color(0xFF0F766E), label: 'Teal Classic (ડીફોલ્ટ)'),
      (name: 'Royal Blue', primary: const Color(0xFF1D4ED8), label: 'Royal Blue (રોયલ બ્લુ)'),
      (name: 'Indigo', primary: const Color(0xFF4F46E5), label: 'Indigo Violet (ઈન્ડિગો)'),
      (name: 'Emerald', primary: const Color(0xFF059669), label: 'Emerald Forest (લીલો)'),
      (name: 'Crimson', primary: const Color(0xFFBE123C), label: 'Ruby Crimson (લાલ)'),
      (name: 'Slate', primary: const Color(0xFF334155), label: 'Slate Gray (સ્લેટ)'),
      (name: 'Amber', primary: const Color(0xFFD97706), label: 'Golden Amber (એમ્બર)'),
      (name: 'Cyan', primary: const Color(0xFF0891B2), label: 'Ocean Cyan (સિયાન)'),
    ];

    final successOptions = <({Color color, String name})>[
      (color: const Color(0xFF16A34A), name: 'Emerald Green'),
      (color: const Color(0xFF15803D), name: 'Deep Forest'),
      (color: const Color(0xFF0D9488), name: 'Teal Green'),
      (color: const Color(0xFF0284C7), name: 'Sky Blue'),
    ];

    final partialOptions = <({Color color, String name})>[
      (color: const Color(0xFFD97706), name: 'Vibrant Amber'),
      (color: const Color(0xFFEA580C), name: 'Warm Orange'),
      (color: const Color(0xFFCA8A04), name: 'Golden Yellow'),
      (color: const Color(0xFF92400E), name: 'Ochre Bronze'),
    ];

    final warningOptions = <({Color color, String name})>[
      (color: const Color(0xFFE11D48), name: 'Rose Red'),
      (color: const Color(0xFFDC2626), name: 'Vivid Crimson'),
      (color: const Color(0xFFF97316), name: 'Coral Orange'),
      (color: const Color(0xFF9F1239), name: 'Deep Ruby'),
    ];

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
                Icon(Icons.color_lens_outlined, color: provider.primaryColor, size: 22),
                const SizedBox(width: 10),
                const Text(
                  'Theme Color Combinations & Status Management',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Customize full app color theme, high-contrast text, and ledger status badges.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 18),

            // 1. PRESET COLOR COMBINATIONS
            const Text(
              'Theme Palette Combinations (એપ થીમ પેલેટ્સ)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: presets.map((p) {
                final isSelected = provider.primaryColor.toARGB32() == p.primary.toARGB32();
                return InkWell(
                  onTap: () => provider.setThemePreset(p.name, p.primary),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? p.primary.withValues(alpha: 0.15) : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? p.primary : Theme.of(context).dividerColor.withValues(alpha: 0.2),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: p.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          p.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? p.primary : null,
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.check_circle, size: 14, color: p.primary),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 22),
            const Divider(height: 1),
            const SizedBox(height: 18),

            // 2. STATUS COLOR CUSTOMIZATION
            const Text(
              'Ledger Status Colors (સ્ટેટસ કલર મેનેજમેન્ટ)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // A. Success / Paid Color
            Row(
              children: [
                const SizedBox(
                  width: 130,
                  child: Text(
                    'Fully Paid (પેઇડ):',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                Wrap(
                  spacing: 8,
                  children: successOptions.map((opt) {
                    final isSel = provider.successColor.toARGB32() == opt.color.toARGB32();
                    return Tooltip(
                      message: opt.name,
                      child: InkWell(
                        onTap: () => provider.setSuccessColor(opt.color),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: opt.color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSel ? Colors.white : Colors.transparent,
                              width: 2.5,
                            ),
                            boxShadow: isSel ? [BoxShadow(color: opt.color.withValues(alpha: 0.6), blurRadius: 6)] : null,
                          ),
                          child: isSel ? const Icon(Icons.check, size: 15, color: Colors.white) : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // B. Partially Paid Color
            Row(
              children: [
                const SizedBox(
                  width: 130,
                  child: Text(
                    'Partially Paid (પાર્શિયલ):',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                Wrap(
                  spacing: 8,
                  children: partialOptions.map((opt) {
                    final isSel = provider.partialColor.toARGB32() == opt.color.toARGB32();
                    return Tooltip(
                      message: opt.name,
                      child: InkWell(
                        onTap: () => provider.setPartialColor(opt.color),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: opt.color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSel ? Colors.white : Colors.transparent,
                              width: 2.5,
                            ),
                            boxShadow: isSel ? [BoxShadow(color: opt.color.withValues(alpha: 0.6), blurRadius: 6)] : null,
                          ),
                          child: isSel ? const Icon(Icons.check, size: 15, color: Colors.white) : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // C. Warning / Unpaid Color
            Row(
              children: [
                const SizedBox(
                  width: 130,
                  child: Text(
                    'Unpaid Due (અનપેઇડ):',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                Wrap(
                  spacing: 8,
                  children: warningOptions.map((opt) {
                    final isSel = provider.warningColor.toARGB32() == opt.color.toARGB32();
                    return Tooltip(
                      message: opt.name,
                      child: InkWell(
                        onTap: () => provider.setWarningColor(opt.color),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: opt.color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSel ? Colors.white : Colors.transparent,
                              width: 2.5,
                            ),
                            boxShadow: isSel ? [BoxShadow(color: opt.color.withValues(alpha: 0.6), blurRadius: 6)] : null,
                          ),
                          child: isSel ? const Icon(Icons.check, size: 15, color: Colors.white) : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),

            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // 3. EYE COMFORT: HIGH CONTRAST TEXT
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Enhanced High-Contrast Text (આંખો માટે હાઈ-કોન્ટ્રાસ્ટ)',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'Numbers and warning text will have crisp, high-luminance contrast against dark backgrounds, preventing eye strain.',
                style: TextStyle(fontSize: 11.5, color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7)),
              ),
              value: provider.isHighContrast,
              onChanged: (val) => provider.setHighContrast(val),
              secondary: Icon(Icons.visibility, color: provider.primaryColor),
            ),

            const SizedBox(height: 14),

            // 4. LIVE INTERACTIVE PREVIEW
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Live Preview (ચલાન લુક એન્ડ ફીલ):',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Active Theme: ${provider.themePreset}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: provider.primaryColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: provider.successColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: provider.successColor.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          '✓ PAID',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: provider.getEffectiveSuccessTextColor(isDark)),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: provider.partialColor.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          '◐ PARTIAL',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: provider.getEffectivePartialTextColor(isDark)),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: provider.warningColor,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Text(
                          '⚠ UNPAID DUE',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: provider.getEffectiveWarningBgColor(isDark),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: provider.warningColor.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          'Final: ₹ 57,200',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: provider.getEffectiveWarningTextColor(isDark),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
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
              'Automatic text formatting for entries',
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
  // CATEGORY 1: BACKUP & DATABASE (INLINE VERTICAL CONFIGURATION)
  // ===========================================================================
  Widget _buildBackupAndDatabasePage(
    BuildContext context,
    ChallanProvider provider,
    AuthProvider auth,
    bool isDark,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 14 : 24),
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
            'Database stats, JSON backups, and restore.',
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
                  if (isMobile) ...[
                    _buildStatItem(
                      context,
                      'Active Challans',
                      '${provider.challans.length}',
                      Icons.receipt_long,
                    ),
                    const SizedBox(height: 10),
                    _buildStatItem(
                      context,
                      'Registered Parties',
                      '${provider.parties.length}',
                      Icons.people,
                    ),
                    const SizedBox(height: 10),
                    _buildStatItem(
                      context,
                      'Recycle Bin Items',
                      '${provider.recycleBinCount}',
                      Icons.delete_outline,
                      color: provider.recycleBinCount > 0 ? AppColors.warningText : null,
                    ),
                  ] else ...[
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
                      ],
                    ),
                  ],
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
                    'Records are stored locally. Export JSON snapshot anytime.',
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
                        label: const Text('Export Backup (JSON)'),
                        onPressed: () => _exportBackup(context),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.upload, size: 18),
                        label: const Text('Restore Data'),
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
