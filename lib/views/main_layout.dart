import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/challan_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/add_edit_challan_dialog.dart';
import '../widgets/add_edit_party_dialog.dart';
import '../widgets/branding_dialogs.dart';
import 'challan_list_view.dart';
import 'net_profit_loss_view.dart';
import 'parties_view.dart';
import 'recycle_bin_view.dart';
import 'settings_view.dart';
import 'summary_reports_view.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  int _settingsCategoryIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final auth = context.read<AuthProvider>();
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      auth.onAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      auth.onAppResumed();
    }
  }

  void _navigateToSettings({int categoryIndex = 0}) {
    setState(() {
      _selectedIndex = 5;
      _settingsCategoryIndex = categoryIndex;
    });
  }

  void _openAddChallan(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AddEditChallanDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChallanProvider>();
    final auth = context.watch<AuthProvider>();
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

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
        contentBody = const NetProfitLossView();
        break;
      case 3:
        contentBody = const SummaryReportsView();
        break;
      case 4:
        contentBody = const RecycleBinView();
        break;
      case 5:
        contentBody = SettingsView(
          key: ValueKey('settings_category_$_settingsCategoryIndex'),
          initialCategoryIndex: _settingsCategoryIndex,
        );
        break;
      default:
        contentBody = const ChallanListView();
    }

    final warningCount = provider.unpaidWarningCount;
    final recycleBinCount = provider.recycleBinCount;
    final isCollapsed = provider.isSidebarCollapsed;

    // Mobile layout with drawer & bottom navigation bar
    if (isMobile) {
      final navIndex = _selectedIndex == 5 ? 4 : (_selectedIndex < 4 ? _selectedIndex : 0);
      return Scaffold(
        appBar: AppBar(
          elevation: 0,
          leading: Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
          titleSpacing: 0,
          title: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  'assets/logo/app_logo.png',
                  width: 26,
                  height: 26,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.account_balance_wallet, size: 22, color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  provider.companyName,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          actions: [
            if (_selectedIndex == 0)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: provider.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.add, size: 15),
                  label: const Text('New', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () => _openAddChallan(context),
                ),
              )
            else if (_selectedIndex == 1)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: provider.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.person_add_alt_1, size: 15),
                  label: const Text('New', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => const AddEditPartyDialog(),
                    );
                  },
                ),
              ),
            if (warningCount > 0)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: InkWell(
                  onTap: () {
                    setState(() => _selectedIndex = 0);
                    provider.setStatusFilter(provider.statusFilter == 'overdue' ? null : 'overdue');
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE11D48).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE11D48).withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFE11D48)),
                        const SizedBox(width: 4),
                        Text(
                          '$warningCount Due',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFE11D48)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            IconButton(
              icon: Icon(
                Theme.of(context).brightness == Brightness.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                size: 20,
              ),
              tooltip: 'Theme',
              onPressed: () => provider.toggleTheme(),
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined, size: 20),
              tooltip: 'Settings',
              onPressed: () => _navigateToSettings(categoryIndex: 0),
            ),
          ],
        ),
        drawer: Drawer(
          child: _buildSidebarContent(
            context: context,
            provider: provider,
            auth: auth,
            isCollapsed: false,
            warningCount: warningCount,
            recycleBinCount: recycleBinCount,
            isDrawer: true,
          ),
        ),
        body: contentBody,
        bottomNavigationBar: NavigationBar(
          selectedIndex: navIndex,
          onDestinationSelected: (idx) {
            setState(() {
              if (idx == 4) {
                _selectedIndex = 5;
              } else {
                _selectedIndex = idx;
              }
            });
          },
          height: 64,
          destinations: [
            NavigationDestination(
              icon: warningCount > 0
                  ? Badge(
                      label: Text('$warningCount'),
                      backgroundColor: const Color(0xFFE11D48),
                      child: const Icon(Icons.receipt_long_outlined),
                    )
                  : const Icon(Icons.receipt_long_outlined),
              selectedIcon: const Icon(Icons.receipt_long),
              label: 'Challans',
            ),
            const NavigationDestination(
              icon: Icon(Icons.people_alt_outlined),
              selectedIcon: Icon(Icons.people_alt),
              label: 'Parties',
            ),
            const NavigationDestination(
              icon: Icon(Icons.analytics_outlined),
              selectedIcon: Icon(Icons.analytics),
              label: 'P & L',
            ),
            const NavigationDestination(
              icon: Icon(Icons.assessment_outlined),
              selectedIcon: Icon(Icons.assessment),
              label: 'Reports',
            ),
            const NavigationDestination(
              icon: Icon(Icons.tune_outlined),
              selectedIcon: Icon(Icons.tune),
              label: 'Settings',
            ),
          ],
        ),
      );
    }

    // Desktop & Tablet Layout with animated collapsible sidebar
    return Scaffold(
      body: Row(
        children: [
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
            child: _buildSidebarContent(
              context: context,
              provider: provider,
              auth: auth,
              isCollapsed: isCollapsed,
              warningCount: warningCount,
              recycleBinCount: recycleBinCount,
              isDrawer: false,
            ),
          ),
          Expanded(child: contentBody),
        ],
      ),
    );
  }

  Widget _buildSidebarContent({
    required BuildContext context,
    required ChallanProvider provider,
    required AuthProvider auth,
    required bool isCollapsed,
    required int warningCount,
    required int recycleBinCount,
    required bool isDrawer,
  }) {
    final userName = provider.adminName.isNotEmpty ? provider.adminName : 'OM Mavtar Admin';

    return Column(
      children: [
        // TOP HEADER: LOGO & PROFILE
        isCollapsed
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    Tooltip(
                      message: '$userName (Click to customize Profile & Logo)',
                      child: AppLogoWidget(
                        size: 40,
                        showEditBadge: true,
                        onTap: () => _navigateToSettings(categoryIndex: 0),
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
                    Tooltip(
                      message: 'Click to customize Profile & Logo',
                      child: AppLogoWidget(
                        size: 42,
                        showEditBadge: true,
                        onTap: () => _navigateToSettings(categoryIndex: 0),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: () => _navigateToSettings(categoryIndex: 0),
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
                    if (!isDrawer)
                      IconButton(
                        icon: const Icon(Icons.menu_open, size: 20),
                        tooltip: 'Collapse Sidebar',
                        onPressed: () => provider.toggleSidebar(),
                      ),
                  ],
                ),
              ),
        const Divider(height: 1),
        const SizedBox(height: 8),

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
                isDrawer: isDrawer,
              ),
              _buildNavItem(
                index: 1,
                icon: Icons.people_outline,
                activeIcon: Icons.people,
                label: 'Parties Directory',
                badge: '${provider.parties.length}',
                isCollapsed: isCollapsed,
                isDrawer: isDrawer,
              ),
              _buildNavItem(
                index: 2,
                icon: Icons.analytics_outlined,
                activeIcon: Icons.analytics,
                label: 'Net Profit - Loss',
                isCollapsed: isCollapsed,
                isDrawer: isDrawer,
              ),
              _buildNavItem(
                index: 3,
                icon: Icons.bar_chart_outlined,
                activeIcon: Icons.bar_chart,
                label: 'Financial Reports',
                isCollapsed: isCollapsed,
                isDrawer: isDrawer,
              ),
              _buildNavItem(
                index: 4,
                icon: Icons.delete_outline,
                activeIcon: Icons.delete,
                label: 'Recycle Bin',
                badge: recycleBinCount > 0 ? '$recycleBinCount' : null,
                isWarningBadge: false,
                isCollapsed: isCollapsed,
                isDrawer: isDrawer,
              ),
              _buildNavItem(
                index: 5,
                icon: Icons.settings_outlined,
                activeIcon: Icons.settings,
                label: 'Settings',
                isCollapsed: isCollapsed,
                isDrawer: isDrawer,
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
                    onPressed: () {
                      if (isDrawer) Navigator.of(context).pop();
                      _openAddChallan(context);
                    },
                  ),
                ),
        ),

        const Divider(height: 1),

        // FOOTER: PROFILE DETAILS (CLICKABLE TO OPEN SETTINGS PROFILE SECTION)
        isCollapsed
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Tooltip(
                  message: '$userName (Click to customize Profile in Settings)',
                  child: IconButton(
                    icon: const Icon(Icons.tune_outlined, size: 20),
                    tooltip: 'Settings & Profile',
                    onPressed: () => _navigateToSettings(categoryIndex: 0),
                  ),
                ),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: InkWell(
                  onTap: () {
                    if (isDrawer) Navigator.of(context).pop();
                    _navigateToSettings(categoryIndex: 0);
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).dividerColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Theme.of(context).dividerColor.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.business_outlined, size: 18, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                provider.companyName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                userName,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.color
                                      ?.withValues(alpha: 0.75),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 11,
                          color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ],
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
    bool isDrawer = false,
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
                setState(() => _selectedIndex = index);
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
            if (isDrawer) Navigator.of(context).pop();
            setState(() => _selectedIndex = index);
          },
        ),
      ),
    );
  }
}
