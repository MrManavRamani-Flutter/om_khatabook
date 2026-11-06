import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/challan_entry.dart';
import '../providers/challan_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/branding_dialogs.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChallanProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Settings & Preferences',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Configure app appearance and manage local data backups',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.color
                    ?.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),

            // THEME SETTINGS
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.palette_outlined, color: AppColors.primary),
                        SizedBox(width: 10),
                        Text(
                          'Appearance & Theme',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
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
                    Divider(
                      height: 28,
                      thickness: 1,
                      color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                    ),
                    const Row(
                      children: [
                        Icon(Icons.text_fields_rounded, color: AppColors.primary, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Text Casing & Typography (Data Entry)',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Choose how party names, challans, and entry details appear and format automatically',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 12),
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
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
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
                                                fontSize: 13.5,
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
                                                    fontSize: 10,
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
                                            fontSize: 12,
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
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // APP BRANDING & PROFILE LOGOS CARD
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.branding_watermark_outlined, color: AppColors.primary),
                        SizedBox(width: 10),
                        Text(
                          'App Branding & Profile Identity',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Customize the company logo, business name, and admin avatar. Stored automatically in JSON backups.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // APP LOGO SECTION
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(context).dividerColor.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    AppLogoWidget(
                                      size: 48,
                                      showEditBadge: true,
                                      onTap: () => BrandingDialogs.showAppBrandingDialog(context),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            provider.companyName,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            provider.companyTagline,
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.color
                                                  ?.withValues(alpha: 0.7),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.edit, size: 16),
                                    label: const Text('Edit App Logo & Name'),
                                    onPressed: () => BrandingDialogs.showAppBrandingDialog(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // PROFILE LOGO SECTION
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(context).dividerColor.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    ProfileAvatarWidget(
                                      radius: 24,
                                      showEditBadge: true,
                                      onTap: () => BrandingDialogs.showProfileDialog(context),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            provider.adminName,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            provider.adminRole,
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.color
                                                  ?.withValues(alpha: 0.7),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.badge, size: 16),
                                    label: const Text('Edit Profile & Avatar'),
                                    onPressed: () => BrandingDialogs.showProfileDialog(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // DATA STATS & RECYCLE BIN CARD
            Card(
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
                          'Database Overview',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatItem(
                            context,
                            'Registered Parties',
                            '${provider.parties.length}',
                            Icons.people,
                          ),
                        ),
                        const SizedBox(width: 16),
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
                ),
              ),
            ),
            const SizedBox(height: 20),

            // DATA BACKUP & RESTORE
            Card(
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
                          'Data Backup & Safety',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'All your ledger data is stored 100% locally on your computer. You can export a JSON backup anytime for safekeeping.',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _exportBackup(context),
                          icon: const Icon(Icons.download),
                          label: const Text('Export Backup (JSON)'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _showImportDialog(context),
                          icon: const Icon(Icons.upload),
                          label: const Text('Restore from Backup'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _showResetConfirm(context),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reload Sample Data'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // ABOUT / METADATA
            Center(
              child: Column(
                children: [
                  Text(
                    'OM Mavtar Group Khata Book v2.0.0',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Desktop Digital Ledger (macOS & Windows 10/11 Compatible) • English UI',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.color
                          ?.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: effectiveColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: effectiveColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: effectiveColor,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.textTheme.bodySmall?.color,
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
