import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/challan_entry.dart';
import '../providers/challan_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/add_edit_challan_dialog.dart';
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

  void _confirmDelete(BuildContext context, ChallanEntry entry) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Challan Entry?'),
        content: Text(
          'Are you sure you want to delete Challan #${entry.challanNo} (${entry.partyName})?',
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
              context.read<ChallanProvider>().deleteChallan(entry.id);
            },
            child: const Text('Delete'),
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
            // TOP HEADER
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
                    Row(
                      children: [
                        // SEARCH
                        Expanded(
                          flex: 4,
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Search by Challan No, Party, GST Bill, or Cheque No...',
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

                        // PARTY FILTER DROPDOWN
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String?>(
                            initialValue: provider.selectedPartyId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Party Filter',
                              isDense: true,
                              prefixIcon: Icon(Icons.business, size: 18),
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

                    // SECOND ROW: STATUS & DATE CHIPS
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          const Text(
                            'Status: ',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                          ),
                          _buildStatusChip(context, provider, 'all', 'All'),
                          const SizedBox(width: 6),
                          _buildStatusChip(context, provider, 'paid', 'Paid / Cleared', color: AppColors.successText),
                          const SizedBox(width: 6),
                          _buildStatusChip(context, provider, 'unpaid', '⚠️ Unpaid Warning', color: AppColors.warningText),
                          const SizedBox(width: 6),
                          _buildStatusChip(context, provider, 'bounced', '❌ Bounced', color: AppColors.warningText),

                          const SizedBox(width: 24),

                          const Text(
                            'Period: ',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                          ),
                          _buildDateChip(context, provider, 'all', 'All Time'),
                          const SizedBox(width: 6),
                          _buildDateChip(context, provider, 'today', 'Today'),
                          const SizedBox(width: 6),
                          _buildDateChip(context, provider, 'week', 'Last 7 Days'),
                          const SizedBox(width: 6),
                          _buildDateChip(context, provider, 'month', 'Last 30 Days'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

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
    final isUnpaidCash = isCash && !item.isCashPaid;
    final isBouncedCheque = !isCash && item.chequeDetails?.status == ChequeStatus.bounced;
    final hasWarning = isUnpaidCash || isBouncedCheque;

    // Card background color:
    // If unpaid cash or bounced cheque -> Highlighted in light-red!
    final cardBgColor = hasWarning
        ? (Theme.of(context).brightness == Brightness.dark
            ? AppColors.warningBgDark
            : AppColors.warningBgLight)
        : Theme.of(context).cardColor;

    final borderColor = hasWarning
        ? (Theme.of(context).brightness == Brightness.dark
            ? AppColors.warningBorderDark
            : AppColors.warningBorder)
        : Theme.of(context).dividerColor.withValues(alpha: 0.2);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: hasWarning ? 1.8 : 1.0),
        boxShadow: hasWarning
            ? [
                BoxShadow(
                  color: AppColors.warningBorder.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
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
                children: [
                  // CHALLAN NUMBER BADGE
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
                  const SizedBox(width: 12),

                  // DATE
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        Formatters.date(item.date),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),

                  // STATUS BADGE (HIGHLIGHTED IF UNPAID CASH!)
                  _buildStatusBadge(item),

                  const Spacer(),

                  // ACTION BUTTONS
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
                  // PARTY NAME
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

                  // CHALLAN AMOUNT
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

                  // GST BILL NO & GST AMOUNT
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

                  // FINAL AMOUNT
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
                            color: hasWarning ? AppColors.warningText : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // IF CHEQUE: SHOW CHEQUE DETAILS SUB-BAR
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
      if (item.isCashPaid) {
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
        // UNPAID CASH -> WARNING HIGHLIGHT BADGE!
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.warningText,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber_rounded, size: 12, color: Colors.white),
              SizedBox(width: 4),
              Text(
                '⚠️ UNPAID CASH',
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
      // CHEQUE STATUS
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
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      selectedColor: AppColors.primary.withValues(alpha: 0.15),
      onSelected: (_) => provider.setDateFilter(value),
    );
  }
}
