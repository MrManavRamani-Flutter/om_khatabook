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
    final isCollapsed = provider.isSidebarCollapsed;

    return Scaffold(
      body: Row(
        children: [
          // DESKTOP SIDEBAR (COLLAPSIBLE ANIMATED DRAWER)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            width: isCollapsed ? 74 : 260,
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
                // TOP HEADER: LOGO & PROFILE (CLICKING TOP-LEFT ICON OPENS PROFILE)
                isCollapsed
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Column(
                          children: [
                            Tooltip(
                              message: 'OM Mavtar Admin (Click to edit Profile & Logo)',
                              child: AppLogoWidget(
                                size: 40,
                                showEditBadge: true,
                                onTap: () => BrandingDialogs.showProfileDialog(context),
                              ),
                            ),
                            const SizedBox(height: 10),
                            IconButton(
                              icon: const Icon(Icons.menu, size: 20),
                              tooltip: 'Expand Sidebar',
                              onPressed: () => provider.toggleSidebar(),
                            ),
                          ],
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.fromLTRB(14, 16, 8, 14),
                        child: Row(
                          children: [
                            // TOP LEFT ICON: CLICK OPENS PROFILE DIALOG
                            Tooltip(
                              message: 'Click to edit Profile & Logo',
                              child: AppLogoWidget(
                                size: 42,
                                showEditBadge: true,
                                onTap: () => BrandingDialogs.showProfileDialog(context),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: InkWell(
                                onTap: () => BrandingDialogs.showAppBrandingDialog(context),
                                borderRadius: BorderRadius.circular(6),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        provider.companyName,
                                        style: const TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: -0.2,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        provider.companyTagline,
                                        style: TextStyle(
                                          fontSize: 10.5,
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
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.menu_open, size: 20),
                              tooltip: 'Collapse Sidebar',
                              onPressed: () => provider.toggleSidebar(),
                            ),
                          ],
                        ),
                      ),
                const Divider(height: 1),
                const SizedBox(height: 10),

                // NAV MENU ITEMS
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 8 : 12),
                    children: [
                      _buildNavItem(
                        index: 0,
                        icon: Icons.receipt_long_outlined,
                        activeIcon: Icons.receipt_long,
                        label: 'Challan Ledger',
                        badge: warningCount > 0 ? '$warningCount Alert' : '${provider.challans.length}',
                        isWarningBadge: warningCount > 0,
                        isCollapsed: isCollapsed,
                      ),
                      _buildNavItem(
                        index: 1,
                        icon: Icons.people_outline,
                        activeIcon: Icons.people,
                        label: 'Parties Directory',
                        badge: '${provider.parties.length}',
                        isCollapsed: isCollapsed,
                      ),
                      _buildNavItem(
                        index: 2,
                        icon: Icons.bar_chart_outlined,
                        activeIcon: Icons.bar_chart,
                        label: 'Financial Reports',
                        isCollapsed: isCollapsed,
                      ),
                      _buildNavItem(
                        index: 3,
                        icon: Icons.delete_outline,
                        activeIcon: Icons.delete,
                        label: 'Recycle Bin',
                        badge: recycleBinCount > 0 ? '$recycleBinCount' : null,
                        isWarningBadge: false,
                        isCollapsed: isCollapsed,
                      ),
                      _buildNavItem(
                        index: 4,
                        icon: Icons.settings_outlined,
                        activeIcon: Icons.settings,
                        label: 'Settings & Backup',
                        isCollapsed: isCollapsed,
                      ),
                    ],
                  ),
                ),

                // PRIMARY ACTION BUTTON IN SIDEBAR
                Padding(
                  padding: EdgeInsets.all(isCollapsed ? 8 : 14),
                  child: isCollapsed
                      ? Tooltip(
                          message: 'New Challan Entry',
                          child: IconButton.filled(
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.all(12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.add, size: 20),
                            onPressed: () => _openAddChallan(context),
                          ),
                        )
                      : SizedBox(
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

                // FOOTER: USER & THEME TOGGLE
                isCollapsed
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          children: [
                            Tooltip(
                              message: 'OM Mavtar Admin (Click to edit)',
                              child: ProfileAvatarWidget(
                                radius: 17,
                                showEditBadge: true,
                                onTap: () => BrandingDialogs.showProfileDialog(context),
                              ),
                            ),
                            const SizedBox(height: 8),
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
                      )
                    : Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          children: [
                            InkWell(
                              onTap: () => BrandingDialogs.showProfileDialog(context),
                              borderRadius: BorderRadius.circular(20),
                              child: Row(
                                children: [
                                  ProfileAvatarWidget(
                                    radius: 17,
                                    showEditBadge: true,
                                    onTap: () => BrandingDialogs.showProfileDialog(context),
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
    bool isCollapsed = false,
  }) {
    final isSelected = _selectedIndex == index;

    if (isCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Tooltip(
          message: label,
          child: Material(
            color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                setState(() {
                  _selectedIndex = index;
                });
              },
              child: SizedBox(
                height: 44,
                child: Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        isSelected ? activeIcon : icon,
                        color: isSelected
                            ? AppColors.primary
                            : Theme.of(context).iconTheme.color?.withValues(alpha: 0.7),
                        size: 22,
                      ),
                      if (badge != null)
                        Positioned(
                          top: -3,
                          right: -5,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isWarningBadge ? AppColors.warningText : AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

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
