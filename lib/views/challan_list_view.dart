import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/challan_entry.dart';
import '../providers/challan_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/add_edit_challan_dialog.dart';
import '../widgets/export_report_dialog.dart';
import '../widgets/view_challan_dialog.dart';

class ChallanListView extends StatelessWidget {
  const ChallanListView({super.key});

  void _openAddDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const AddEditChallanDialog(),
    );
  }

  void _openViewDialog(BuildContext context, ChallanEntry entry) {
    showDialog(
      context: context,
      builder: (_) => ViewChallanDialog(entry: entry),
    );
  }

  void _openEditDialog(BuildContext context, ChallanEntry entry) {
    showDialog(
      context: context,
      builder: (_) => AddEditChallanDialog(entryToEdit: entry),
    );
  }

  void _openExportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const ExportReportDialog(),
    );
  }

  void _showMultiPartyDialog(BuildContext context, ChallanProvider provider) {
    final parties = provider.parties;
    final selectedIds = Set<String>.from(provider.selectedPartyIds);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Select Multiple Parties'),
          content: SizedBox(
            width: 480,
            height: 380,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${selectedIds.length} of ${parties.length} Selected'),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            setDialogState(() {
                              selectedIds.addAll(parties.map((p) => p.id));
                            });
                          },
                          child: const Text('Select All'),
                        ),
                        TextButton(
                          onPressed: () {
                            setDialogState(() {
                              selectedIds.clear();
                            });
                          },
                          child: const Text('Clear All'),
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    itemCount: parties.length,
                    itemBuilder: (ctx, index) {
                      final p = parties[index];
                      final isChecked = selectedIds.contains(p.id);
                      return CheckboxListTile(
                        dense: true,
                        title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(p.phone.isNotEmpty ? p.phone : p.address),
                        value: isChecked,
                        onChanged: (val) {
                          setDialogState(() {
                            if (val == true) {
                              selectedIds.add(p.id);
                            } else {
                              selectedIds.remove(p.id);
                            }
                          });
                        },
                      );
                    },
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
              onPressed: () {
                provider.setSelectedPartyIds(selectedIds);
                Navigator.of(ctx).pop();
              },
              child: const Text('Apply Filter'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMonthPicker(BuildContext context, ChallanProvider provider) {
    int selectedMonth = provider.selectedMonth ?? DateTime.now().month;
    int selectedYear = provider.selectedYear ?? DateTime.now().year;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Filter by Month & Year'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select Month:'),
              const SizedBox(height: 6),
              DropdownButtonFormField<int>(
                initialValue: selectedMonth,
                decoration: const InputDecoration(isDense: true),
                items: List.generate(12, (index) {
                  final m = index + 1;
                  return DropdownMenuItem(
                    value: m,
                    child: Text(DateFormat('MMMM').format(DateTime(2026, m))),
                  );
                }),
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedMonth = val);
                },
              ),
              const SizedBox(height: 14),
              const Text('Select Year:'),
              const SizedBox(height: 6),
              DropdownButtonFormField<int>(
                initialValue: selectedYear,
                decoration: const InputDecoration(isDense: true),
                items: [2024, 2025, 2026, 2027].map((y) {
                  return DropdownMenuItem(value: y, child: Text('$y'));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedYear = val);
                },
              ),
            ],
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
              onPressed: () {
                provider.setMonthlyFilter(selectedMonth, selectedYear);
                Navigator.of(ctx).pop();
              },
              child: const Text('Apply Month Filter'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, ChallanEntry entry) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Move to Recycle Bin?'),
        content: Text(
          'Challan #${entry.challanNo} (${entry.partyName}) will be moved to the Recycle Bin. You can restore it anytime or delete it permanently from the bin.',
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
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<ChallanProvider>().moveToBinChallan(entry.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Challan #${entry.challanNo} moved to Recycle Bin'),
                  action: SnackBarAction(
                    label: 'Undo',
                    textColor: Colors.amberAccent,
                    onPressed: () {
                      context.read<ChallanProvider>().restoreChallan(entry.id);
                    },
                  ),
                ),
              );
            },
            child: const Text('Move to Bin'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChallanProvider>();
    final entries = provider.filteredChallans;
    final parties = provider.parties;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TOP HEADER WITH PRIMARY ACTIONS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Challan & Billing Ledger',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Manage challan entries, GST billing, cash clearance, and cheque tracking',
                        style: TextStyle(
                          fontSize: 13,
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
                const SizedBox(width: 16),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _openExportDialog(context),
                      icon: const Icon(Icons.picture_as_pdf, color: AppColors.primary, size: 18),
                      label: const Text('Generate PDF / Excel'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        side: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: () => _openAddDialog(context),
                      icon: const Icon(Icons.add_circle, size: 20),
                      label: const Text('Add Challan Entry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 4 SUMMARY KPI CARDS
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 900;
                final crossCount = isWide ? 4 : 2;

                return GridView.count(
                  crossAxisCount: crossCount,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: isWide ? 1.7 : 2.2,
                  children: [
                    _buildKpiCard(
                      context,
                      title: 'TOTAL CHALLAN AMOUNT',
                      amount: Formatters.currency(provider.totalChallanAmount),
                      icon: Icons.receipt_long,
                      color: AppColors.primary,
                      bgColor: AppColors.primary.withValues(alpha: 0.12),
                    ),
                    _buildKpiCard(
                      context,
                      title: 'TOTAL FINAL AMOUNT',
                      amount: Formatters.currency(provider.totalFinalAmount),
                      icon: Icons.account_balance_wallet,
                      color: const Color(0xFF0284C7),
                      bgColor: const Color(0xFFE0F2FE),
                    ),
                    _buildKpiCard(
                      context,
                      title: 'TOTAL GST AMOUNT',
                      amount: Formatters.currency(provider.totalGstAmount),
                      icon: Icons.calculate,
                      color: const Color(0xFF7C3AED),
                      bgColor: const Color(0xFFEDE9FE),
                    ),
                    _buildKpiCard(
                      context,
                      title: 'UNPAID / WARNING',
                      amount: Formatters.currency(provider.totalUnpaidAmount),
                      subtitle: '${provider.unpaidWarningCount} Pending Action',
                      icon: Icons.warning_rounded,
                      color: AppColors.warningText,
                      bgColor: AppColors.warningBgLight,
                      isWarning: provider.unpaidWarningCount > 0,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),

            // FILTERS & SEARCH TOOLBAR
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // ROW 1: SEARCH, PARTY DROPDOWN, MULTI-PARTY BUTTON, PAYMENT OPTION, RESET
                    Row(
                      children: [
                        // SEARCH
                        Expanded(
                          flex: 4,
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Search by Challan No, Party, GST Bill, or Cheque...',
                              prefixIcon: const Icon(Icons.search, size: 20),
                              isDense: true,
                              suffixIcon: provider.searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () => provider.setSearchQuery(''),
                                    )
                                  : null,
                            ),
                            controller: TextEditingController(text: provider.searchQuery)
                              ..selection = TextSelection.fromPosition(
                                TextPosition(offset: provider.searchQuery.length),
                              ),
                            onChanged: (val) => provider.setSearchQuery(val),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // PARTY DROPDOWN (SINGLE / ALL)
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String?>(
                            initialValue: provider.selectedSinglePartyId,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: provider.selectedPartyIds.length > 1
                                  ? '${provider.selectedPartyIds.length} Parties Selected'
                                  : 'Party Filter',
                              isDense: true,
                              prefixIcon: const Icon(Icons.business, size: 18),
                            ),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('All Parties')),
                              ...parties.map((p) => DropdownMenuItem(
                                    value: p.id,
                                    child: Text(p.name, overflow: TextOverflow.ellipsis),
                                  )),
                            ],
                            onChanged: (val) => provider.setSelectedPartyId(val),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // MULTI-PARTY SELECTION BUTTON
                        OutlinedButton.icon(
                          onPressed: () => _showMultiPartyDialog(context, provider),
                          icon: const Icon(Icons.checklist, size: 16),
                          label: Text(
                            provider.selectedPartyIds.length > 1
                                ? '${provider.selectedPartyIds.length} Selected'
                                : 'Multi-Party',
                            style: const TextStyle(fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                            side: BorderSide(
                              color: provider.selectedPartyIds.length > 1
                                  ? AppColors.primary
                                  : Theme.of(context).dividerColor.withValues(alpha: 0.3),
                            ),
                            backgroundColor: provider.selectedPartyIds.length > 1
                                ? AppColors.primary.withValues(alpha: 0.1)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),

                        // PAYMENT OPTION FILTER
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<PaymentOption?>(
                            initialValue: provider.paymentOptionFilter,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Payment Option',
                              isDense: true,
                            ),
                            items: const [
                              DropdownMenuItem(value: null, child: Text('All Modes')),
                              DropdownMenuItem(value: PaymentOption.cash, child: Text('Cash Only')),
                              DropdownMenuItem(value: PaymentOption.cheque, child: Text('Cheque Only')),
                            ],
                            onChanged: (val) => provider.setPaymentOptionFilter(val),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // RESET FILTERS
                        IconButton.filledTonal(
                          tooltip: 'Reset All Filters',
                          icon: const Icon(Icons.filter_alt_off, size: 18),
                          onPressed: () => provider.resetFilters(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ROW 2: STATUS FILTER, PERIOD FILTER, MONTH PICKER, SORT ASC/DESC (NO HORIZONTAL SCROLL)
                    Wrap(
                      spacing: 8,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // STATUS CHIPS
                        const Text(
                          'Status: ',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        _buildStatusChip(context, provider, 'all', 'All'),
                        _buildStatusChip(context, provider, 'paid', 'Paid', color: AppColors.successText),
                        _buildStatusChip(context, provider, 'unpaid', 'Unpaid Warning', color: AppColors.warningText),
                        _buildStatusChip(context, provider, 'bounced', 'Bounced', color: AppColors.warningText),

                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Text('•', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                        ),

                        // PERIOD CHIPS
                        const Text(
                          'Period: ',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        _buildDateChip(context, provider, 'all', 'All Time'),
                        _buildDateChip(context, provider, 'today', 'Today'),
                        _buildDateChip(context, provider, 'week', 'Last 7 Days'),
                        _buildDateChip(context, provider, 'month', 'Last 30 Days'),

                        // DEDICATED MONTH PICKER BUTTON
                        ActionChip(
                          avatar: const Icon(Icons.calendar_month, size: 16, color: AppColors.primary),
                          label: Text(
                            provider.dateFilter == 'monthly_picker' && provider.selectedMonth != null
                                ? 'Month: ${DateFormat('MMM yyyy').format(DateTime(provider.selectedYear!, provider.selectedMonth!))}'
                                : 'Pick Month...',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: provider.dateFilter == 'monthly_picker'
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: provider.dateFilter == 'monthly_picker' ? AppColors.primary : null,
                            ),
                          ),
                          backgroundColor: provider.dateFilter == 'monthly_picker'
                              ? AppColors.primary.withValues(alpha: 0.15)
                              : null,
                          onPressed: () => _showMonthPicker(context, provider),
                        ),

                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Text('•', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                        ),

                        // DATE SORT TOGGLE
                        ActionChip(
                          avatar: Icon(
                            provider.sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          label: Text(
                            provider.sortAscending ? 'Date: Oldest First ↑' : 'Date: Newest First ↓',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                          onPressed: () => provider.toggleSortOrder(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ACTIVE FILTER BANNER (IF FILTER APPLIED)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.filter_list, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Showing: ${provider.activeFilterSummary} (${entries.length} records)',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: () => _openExportDialog(context),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.download_rounded, size: 15, color: AppColors.primary),
                        SizedBox(width: 4),
                        Text(
                          'Export This View',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // LEDGER RECORDS LIST
            if (entries.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 56,
                          color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No Challan entries match the active filters',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Adjust your search, clear filters, or click "Add Challan Entry".',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _openAddDialog(context),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Challan Entry'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final item = entries[index];
                  return _buildChallanCard(context, item);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChallanCard(BuildContext context, ChallanEntry item) {
    final isCash = item.paymentOption == PaymentOption.cash;
    final isUnpaidCash = isCash && !item.isCashPaid && !item.isPartiallyPaid;
    final isPartialCash = isCash && item.isPartiallyPaid;
    final isBouncedCheque = !isCash && item.chequeDetails?.status == ChequeStatus.bounced;
    final hasWarning = isUnpaidCash || isBouncedCheque;

    final cardBgColor = hasWarning
        ? (Theme.of(context).brightness == Brightness.dark
            ? AppColors.warningBgDark
            : AppColors.warningBgLight)
        : (isPartialCash
            ? (Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF2E2205)
                : const Color(0xFFFFFDF5))
            : Theme.of(context).cardColor);

    final borderColor = hasWarning
        ? (Theme.of(context).brightness == Brightness.dark
            ? AppColors.warningBorderDark
            : AppColors.warningBorder)
        : (isPartialCash
            ? const Color(0xFFFDE68A)
            : Theme.of(context).dividerColor.withValues(alpha: 0.2));

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
          width: hasWarning || isPartialCash ? 1.8 : 1.0,
        ),
        boxShadow: hasWarning
            ? [
                BoxShadow(
                  color: AppColors.warningBorder.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : (isPartialCash
                ? [
                    BoxShadow(
                      color: const Color(0xFFFDE68A).withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null),
      ),
      child: InkWell(
        onTap: () => _openViewDialog(context, item),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ROW 1: CHALLAN NO, DATE, WARNING / STATUS BADGE, ACTIONS
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: hasWarning
                                ? AppColors.warningText.withValues(alpha: 0.15)
                                : AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '# ${item.challanNo}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: hasWarning ? AppColors.warningText : AppColors.primary,
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                            const SizedBox(width: 6),
                            Text(
                              Formatters.date(item.date),
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ],
                        ),
                        _buildStatusBadge(item),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    tooltip: 'View Full Details',
                    onPressed: () => _openViewDialog(context, item),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    tooltip: 'Edit Entry',
                    onPressed: () => _openEditDialog(context, item),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.warningText),
                    tooltip: 'Delete Entry',
                    onPressed: () => _confirmDelete(context, item),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ROW 2: PARTY NAME & AMOUNTS
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PARTY',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.partyName,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (item.notes.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            item.notes,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.8),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'CHALLAN AMT',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          Formatters.currency(item.challanAmount),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'GST BILL & AMT',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.gstBillNo.isNotEmpty
                              ? '${item.gstBillNo} (${Formatters.currency(item.gstAmount)})'
                              : 'No GST Bill',
                          style: TextStyle(
                            fontSize: 13,
                            color: item.gstBillNo.isNotEmpty ? null : Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'FINAL AMOUNT',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          Formatters.currency(item.finalAmount),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: hasWarning
                                ? AppColors.warningText
                                : (item.isPartiallyPaid ? const Color(0xFFB45309) : AppColors.primary),
                          ),
                        ),
                        if (item.isPartiallyPaid) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Paid: ${Formatters.currency(item.paidAmount)} • Due: ${Formatters.currency(item.remainingAmount)}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFB45309),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              if (!isCash && item.chequeDetails != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance, size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        'Cheque No: ${item.chequeDetails!.chequeNo} • Bank: ${item.chequeDetails!.bankName} • Date: ${Formatters.date(item.chequeDetails!.chequeDate)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(ChallanEntry item) {
    if (item.paymentOption == PaymentOption.cash) {
      if (item.isPartiallyPaid) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.pie_chart, size: 12, color: Color(0xFFB45309)),
              const SizedBox(width: 4),
              Text(
                'PARTIAL: PAID ${Formatters.currency(item.paidAmount)} • DUE ${Formatters.currency(item.remainingAmount)}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF92400E),
                ),
              ),
            ],
          ),
        );
      } else if (item.isCashPaid) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.successBgLight,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.successBorder),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check, size: 12, color: AppColors.successText),
              SizedBox(width: 4),
              Text(
                'CASH PAID',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.successText,
                ),
              ),
            ],
          ),
        );
      } else {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.warningText,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber_rounded, size: 13, color: Colors.white),
              SizedBox(width: 4),
              Text(
                'UNPAID CASH',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        );
      }
    } else {
      final status = item.chequeDetails?.status ?? ChequeStatus.pending;
      Color bg;
      Color text;
      Color border;
      IconData icon;

      switch (status) {
        case ChequeStatus.cleared:
          bg = AppColors.successBgLight;
          text = AppColors.successText;
          border = AppColors.successBorder;
          icon = Icons.check_circle;
          break;
        case ChequeStatus.bounced:
          bg = AppColors.warningText;
          text = Colors.white;
          border = AppColors.warningBorder;
          icon = Icons.cancel;
          break;
        case ChequeStatus.pending:
          bg = AppColors.pendingBgLight;
          text = AppColors.pendingText;
          border = AppColors.pendingBorder;
          icon = Icons.hourglass_top;
          break;
      }

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: text),
            const SizedBox(width: 4),
            Text(
              'CHEQUE: ${status.label.toUpperCase()}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: text,
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildKpiCard(
    BuildContext context, {
    required String title,
    required String amount,
    String? subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
    bool isWarning = false,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isWarning ? AppColors.warningBorder : color.withValues(alpha: 0.25),
          width: isWarning ? 1.8 : 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isWarning ? AppColors.warningText : Colors.grey,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                amount,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isWarning ? AppColors.warningText : Colors.grey,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context, ChallanProvider provider, String value, String label, {Color? color}) {
    final isSelected = (provider.statusFilter ?? 'all') == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      showCheckmark: false,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? (color ?? AppColors.primary) : null,
      ),
      selectedColor: (color ?? AppColors.primary).withValues(alpha: 0.15),
      onSelected: (_) => provider.setStatusFilter(value == 'all' ? null : value),
    );
  }

  Widget _buildDateChip(BuildContext context, ChallanProvider provider, String value, String label) {
    final isSelected = provider.dateFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      showCheckmark: false,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      selectedColor: AppColors.primary.withValues(alpha: 0.15),
      onSelected: (_) => provider.setDateFilter(value),
    );
  }
}
