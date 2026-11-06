import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/challan_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/add_edit_challan_dialog.dart';
import '../widgets/branding_dialogs.dart';
import 'challan_list_view.dart';
import 'parties_view.dart';
import 'recycle_bin_view.dart';
import 'settings_view.dart';
import 'summary_reports_view.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;

  void _openAddChallan(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const AddEditChallanDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChallanProvider>();

    if (provider.isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Loading OM Mavtar Group Khata Book...',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    Widget contentBody;
    switch (_selectedIndex) {
      case 0:
        contentBody = const ChallanListView();
        break;
      case 1:
        contentBody = const PartiesView();
        break;
      case 2:
        contentBody = const SummaryReportsView();
        break;
      case 3:
        contentBody = const RecycleBinView();
        break;
      case 4:
        contentBody = const SettingsView();
        break;
      default:
        contentBody = const ChallanListView();
    }

    final warningCount = provider.unpaidWarningCount;
    final recycleBinCount = provider.recycleBinCount;

    return Scaffold(
      body: Row(
        children: [
          // DESKTOP SIDEBAR
          Container(
            width: 260,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: Border(
                right: BorderSide(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              children: [
                // LOGO / BRANDING (CLICKABLE TO EDIT)
                InkWell(
                  onTap: () => BrandingDialogs.showAppBrandingDialog(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                    child: Row(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: provider.appLogoBase64.isNotEmpty
                                    ? Image.memory(
                                        base64Decode(provider.appLogoBase64),
                                        width: 44,
                                        height: 44,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Image.asset(
                                          'assets/logo/app_logo.png',
                                          width: 44,
                                          height: 44,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : Image.asset(
                                        'assets/logo/app_logo.png',
                                        width: 44,
                                        height: 44,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Container(
                                          color: AppColors.primary,
                                          child: const Center(
                                            child: Icon(Icons.account_balance_wallet,
                                                color: Colors.white, size: 24),
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                            Positioned(
                              bottom: -2,
                              right: -2,
                              child: Container(
                                padding: const EdgeInsets.all(2.5),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.primary, width: 1),
                                ),
                                child: const Icon(Icons.edit, size: 9, color: AppColors.primary),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                provider.companyName,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.2,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                provider.companyTagline,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
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
                  ),
                ),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // NAV MENU
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      _buildNavItem(
                        index: 0,
                        icon: Icons.receipt_long_outlined,
                        activeIcon: Icons.receipt_long,
                        label: 'Challan Ledger',
                        badge: warningCount > 0 ? '$warningCount Alert' : '${provider.challans.length}',
                        isWarningBadge: warningCount > 0,
                      ),
                      _buildNavItem(
                        index: 1,
                        icon: Icons.people_outline,
                        activeIcon: Icons.people,
                        label: 'Parties Directory',
                        badge: '${provider.parties.length}',
                      ),
                      _buildNavItem(
                        index: 2,
                        icon: Icons.bar_chart_outlined,
                        activeIcon: Icons.bar_chart,
                        label: 'Financial Reports',
                      ),
                      _buildNavItem(
                        index: 3,
                        icon: Icons.delete_outline,
                        activeIcon: Icons.delete,
                        label: 'Recycle Bin',
                        badge: recycleBinCount > 0 ? '$recycleBinCount' : null,
                        isWarningBadge: false,
                      ),
                      _buildNavItem(
                        index: 4,
                        icon: Icons.settings_outlined,
                        activeIcon: Icons.settings,
                        label: 'Settings & Backup',
                      ),
                    ],
                  ),
                ),

                // PRIMARY ACTION BUTTON IN SIDEBAR
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text(
                        'New Challan Entry',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => _openAddChallan(context),
                    ),
                  ),
                ),

                const Divider(height: 1),

                // FOOTER: USER & THEME TOGGLE (CLICKABLE TO EDIT PROFILE)
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () => BrandingDialogs.showProfileDialog(context),
                        borderRadius: BorderRadius.circular(20),
                        child: Row(
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                CircleAvatar(
                                  radius: 17,
                                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                                  foregroundColor: AppColors.primary,
                                  backgroundImage: provider.profileLogoBase64.isNotEmpty
                                      ? MemoryImage(base64Decode(provider.profileLogoBase64))
                                      : null,
                                  child: provider.profileLogoBase64.isEmpty
                                      ? Text(
                                          provider.adminName.isNotEmpty
                                              ? provider.adminName[0].toUpperCase()
                                              : 'O',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        )
                                      : null,
                                ),
                                Positioned(
                                  bottom: -1,
                                  right: -1,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).cardColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: AppColors.primary, width: 0.8),
                                    ),
                                    child: const Icon(Icons.edit, size: 7, color: AppColors.primary),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 110,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    provider.adminName,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    provider.adminRole,
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.color
                                          ?.withValues(alpha: 0.65),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(
                          provider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                          size: 18,
                        ),
                        tooltip: 'Toggle Theme',
                        onPressed: () => provider.toggleTheme(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // CONTENT
          Expanded(child: contentBody),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    String? badge,
    bool isWarningBadge = false,
  }) {
    final isSelected = _selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: isSelected ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: ListTile(
          dense: true,
          leading: Icon(
            isSelected ? activeIcon : icon,
            color: isSelected
                ? AppColors.primary
                : Theme.of(context).iconTheme.color?.withValues(alpha: 0.7),
            size: 20,
          ),
          title: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected
                  ? AppColors.primary
                  : Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
          trailing: badge != null
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: isWarningBadge
                        ? AppColors.warningText
                        : isSelected
                            ? AppColors.primary
                            : Theme.of(context).dividerColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: (isWarningBadge || isSelected)
                          ? Colors.white
                          : Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                )
              : null,
          onTap: () {
            setState(() {
              _selectedIndex = index;
            });
          },
        ),
      ),
    );
  }
}
