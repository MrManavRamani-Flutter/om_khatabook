import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/income_expense_entry.dart';
import '../models/ledger_category_item.dart';
import '../providers/challan_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/add_edit_ledger_item_dialog.dart';

class LedgerCategoriesView extends StatefulWidget {
  const LedgerCategoriesView({super.key});

  @override
  State<LedgerCategoriesView> createState() => _LedgerCategoriesViewState();
}

class _LedgerCategoriesViewState extends State<LedgerCategoriesView> {
  String _searchQuery = '';
  EntryType _selectedTab = EntryType.expense;

  void _openAddItem(BuildContext context, EntryType type) {
    showDialog(
      context: context,
      builder: (_) => AddEditLedgerItemDialog(defaultType: type),
    );
  }

  void _openEditItem(BuildContext context, LedgerCategoryItem item) {
    showDialog(
      context: context,
      builder: (_) => AddEditLedgerItemDialog(itemToEdit: item),
    );
  }

  Future<void> _confirmDeleteItem(BuildContext context, LedgerCategoryItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete Category Item?'),
        content: Text('Are you sure you want to remove "${item.name}" from presets? Existing ledger records will not be affected.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      context.read<ChallanProvider>().deleteLedgerCategoryItem(item.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Item "${item.name}" deleted.'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _confirmResetDefaults(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Reset to Default Presets?'),
        content: const Text('This will reset your ledger category items to the initial business defaults.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Reset Defaults'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<ChallanProvider>().resetDefaultLedgerCategoryItems();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reset to default ledger categories.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChallanProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 768;

    final expenseItems = provider.expenseCategoryItems;
    final incomeItems = provider.incomeCategoryItems;

    final currentItems = _selectedTab == EntryType.expense ? expenseItems : incomeItems;

    final filtered = currentItems.where((item) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return item.name.toLowerCase().contains(q) || item.category.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TOP HEADER
            _buildHeader(context, provider, isMobile, expenseItems.length, incomeItems.length),
            const SizedBox(height: 16),

            // SEARCH & TAB TOOLBAR
            _buildToolbar(context, isDark, isMobile, expenseItems.length, incomeItems.length),
            const SizedBox(height: 16),

            // ITEMS LIST / GRID
            Expanded(
              child: filtered.isEmpty
                  ? _buildEmptyState(context, isDark)
                  : _buildItemsList(context, filtered, isDark, isMobile),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ChallanProvider provider,
    bool isMobile,
    int totalExpenses,
    int totalIncomes,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.category_rounded, color: AppColors.primary, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Ledger Categories',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${totalExpenses + totalIncomes} Presets',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Pre-configured items for 1-click Expense and Income ledger entries',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ),
        if (!isMobile) ...[
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFE11D48),
              side: const BorderSide(color: Color(0xFFE11D48)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Expense Item', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => _openAddItem(context, EntryType.expense),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Income Item', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => _openAddItem(context, EntryType.income),
          ),
          const SizedBox(width: 6),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'More options',
            onSelected: (val) {
              if (val == 'reset') {
                _confirmResetDefaults(context);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'reset',
                child: Row(
                  children: [
                    Icon(Icons.restart_alt, size: 18),
                    SizedBox(width: 8),
                    Text('Restore Default Presets'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildToolbar(
    BuildContext context,
    bool isDark,
    bool isMobile,
    int totalExpenses,
    int totalIncomes,
  ) {
    return Column(
      children: [
        if (isMobile) ...[
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFE11D48),
                    side: const BorderSide(color: Color(0xFFE11D48)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('+ Expense Item', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () => _openAddItem(context, EntryType.expense),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('+ Income Item', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () => _openAddItem(context, EntryType.income),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            // SEARCH FIELD
            Expanded(
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search items by title or category group...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => setState(() => _searchQuery = ''),
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // TABS (EXPENSES / INCOME)
            SegmentedButton<EntryType>(
              segments: [
                ButtonSegment(
                  value: EntryType.expense,
                  label: Text('Expenses ($totalExpenses)'),
                  icon: const Icon(Icons.arrow_upward_rounded, size: 16, color: Color(0xFFE11D48)),
                ),
                ButtonSegment(
                  value: EntryType.income,
                  label: Text('Income ($totalIncomes)'),
                  icon: const Icon(Icons.arrow_downward_rounded, size: 16, color: Color(0xFF059669)),
                ),
              ],
              selected: {_selectedTab},
              onSelectionChanged: (newSet) {
                setState(() => _selectedTab = newSet.first);
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildItemsList(
    BuildContext context,
    List<LedgerCategoryItem> items,
    bool isDark,
    bool isMobile,
  ) {
    if (isMobile) {
      return ListView.separated(
        itemCount: items.length,
        separatorBuilder: (ctx, _) => const SizedBox(height: 8),
        itemBuilder: (ctx, idx) => _buildItemCard(ctx, items[idx], isDark),
      );
    }

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final crossAxisCount = constraints.maxWidth > 1100
            ? 3
            : (constraints.maxWidth > 700 ? 2 : 1);

        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 110,
          ),
          itemCount: items.length,
          itemBuilder: (ctx, idx) => _buildItemCard(ctx, items[idx], isDark),
        );
      },
    );
  }

  Widget _buildItemCard(BuildContext context, LedgerCategoryItem item, bool isDark) {
    final isExpense = item.isExpense;
    final accentColor = isExpense ? const Color(0xFFE11D48) : const Color(0xFF059669);

    return Card(
      elevation: isDark ? 0 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isExpense ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                color: accentColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade300,
                          ),
                        ),
                        child: Text(
                          item.category,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                      ),
                      if (item.defaultAmount > 0) ...[
                        const SizedBox(width: 6),
                        Text(
                          '(${Formatters.currency(item.defaultAmount)})',
                          style: TextStyle(
                            fontSize: 11,
                            color: accentColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              tooltip: 'Edit item',
              onPressed: () => _openEditItem(context, item),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFE11D48)),
              tooltip: 'Delete item',
              onPressed: () => _confirmDeleteItem(context, item),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.category_outlined,
            size: 48,
            color: Colors.grey.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            _searchQuery.isNotEmpty ? 'No items match "$_searchQuery"' : 'No items registered in this category',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try a different search term or add a new item.'
                : 'Add preset items to speed up your daily ledger entries.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.add, size: 18),
            label: Text('Add ${_selectedTab == EntryType.expense ? "Expense" : "Income"} Item'),
            onPressed: () => _openAddItem(context, _selectedTab),
          ),
        ],
      ),
    );
  }
}

