import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/challan_entry.dart';
import '../models/party.dart';
import '../providers/auth_provider.dart';
import '../providers/challan_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/add_edit_challan_dialog.dart';
import '../widgets/add_edit_party_dialog.dart';
import '../widgets/app_snack_bar.dart';
import '../widgets/export_report_dialog.dart';
import '../widgets/invoice_preview_dialog.dart';
import '../widgets/password_confirmation_dialog.dart';
import '../widgets/view_challan_dialog.dart';

class PartyLedgerDetailView extends StatefulWidget {
  final String partyId;

  const PartyLedgerDetailView({super.key, required this.partyId});

  @override
  State<PartyLedgerDetailView> createState() => _PartyLedgerDetailViewState();
}

class _PartyLedgerDetailViewState extends State<PartyLedgerDetailView> {
  String _searchQuery = '';
  PaymentOption? _paymentOptionFilter;
  String? _statusFilter; // 'all', 'paid', 'unpaid', 'bounced'
  String _dateFilter = 'all'; // 'all', 'today', 'week', 'month', 'monthly_picker', 'custom'
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  int? _selectedMonth;
  int? _selectedYear;
  ChallanSortField _sortField = ChallanSortField.date;
  bool _sortAscending = false;

  void _openAddChallan(BuildContext context, Party party) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddEditChallanDialog(initialParty: party),
    );
  }

  void _openEditChallan(BuildContext context, ChallanEntry entry) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddEditChallanDialog(entryToEdit: entry),
    );
  }

  void _openViewChallan(BuildContext context, ChallanEntry entry) {
    showDialog(
      context: context,
      builder: (_) => ViewChallanDialog(entry: entry),
    );
  }

  void _openInvoiceDialog(BuildContext context, ChallanEntry entry) {
    final provider = context.read<ChallanProvider>();
    Party? party;
    try {
      party = provider.parties.firstWhere((p) => p.id == widget.partyId);
    } catch (_) {
      party = null;
    }

    showDialog(
      context: context,
      builder: (_) => InvoicePreviewDialog(
        entry: entry,
        party: party,
      ),
    );
  }

  void _openExportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => ExportReportDialog(initialPartyId: widget.partyId),
    );
  }

  void _openEditParty(BuildContext context, Party party) {
    showDialog(
      context: context,
      builder: (_) => AddEditPartyDialog(partyToEdit: party),
    );
  }

  void _showMonthPicker(BuildContext context, List<ChallanEntry> partyChallans) {
    final Set<String> seen = {};
    final List<DateTime> months = [];
    for (var c in partyChallans) {
      final key = '${c.date.year}-${c.date.month}';
      if (!seen.contains(key)) {
        seen.add(key);
        months.add(DateTime(c.date.year, c.date.month, 1));
      }
    }
    months.sort((a, b) => b.compareTo(a));

    if (months.isEmpty) {
      final now = DateTime.now();
      months.add(DateTime(now.year, now.month, 1));
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.calendar_month, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Select Ledger Month'),
          ],
        ),
        content: SizedBox(
          width: 320,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: months.length,
            itemBuilder: (context, i) {
              final m = months[i];
              final label = DateFormat('MMMM yyyy').format(m);
              final isCurrent =
                  _dateFilter == 'monthly_picker' &&
                  _selectedMonth == m.month &&
                  _selectedYear == m.year;

              return ListTile(
                leading: Icon(
                  isCurrent ? Icons.check_circle : Icons.calendar_today_outlined,
                  color: isCurrent ? AppColors.primary : Colors.grey,
                  size: 20,
                ),
                title: Text(
                  label,
                  style: TextStyle(
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    color: isCurrent ? AppColors.primary : null,
                  ),
                ),
                onTap: () {
                  setState(() {
                    _dateFilter = 'monthly_picker';
                    _selectedMonth = m.month;
                    _selectedYear = m.year;
                  });
                  Navigator.of(ctx).pop();
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _dateFilter = 'all';
                _selectedMonth = null;
                _selectedYear = null;
              });
              Navigator.of(ctx).pop();
            },
            child: const Text('Show All Months'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCustomDateRangePicker(BuildContext context) async {
    final now = DateTime.now();
    final initialStart = _customStartDate ?? now.subtract(const Duration(days: 30));
    final initialEnd = _customEndDate ?? now;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: DateTimeRange(
        start: initialStart.isBefore(DateTime(2020)) ? DateTime(2020) : initialStart,
        end: initialEnd.isAfter(DateTime(2035)) ? DateTime(2035) : initialEnd,
      ),
      helpText: 'Select Date Range (From - To)',
      cancelText: 'Cancel',
      confirmText: 'Apply Filter',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.primary,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dateFilter = 'custom';
        _customStartDate = picked.start;
        _customEndDate = picked.end;
        _selectedMonth = null;
        _selectedYear = null;
      });
    }
  }

  Future<void> _confirmDeleteChallan(BuildContext context, ChallanEntry entry) async {
    final confirmed = await promptPasswordConfirmation(
      context,
      title: 'Confirm Move to Recycle Bin',
      message: 'Enter password to move Challan #${entry.challanNo} to Recycle Bin.',
      actionLabel: 'Move to Bin',
      icon: Icons.delete_outline,
      iconColor: AppColors.warningText,
    );

    if (!confirmed || !context.mounted) return;

    context.read<ChallanProvider>().moveToBinChallan(entry.id);
    AppSnackBar.showRecycleBinSnackBar(
      context,
      message: 'Challan #${entry.challanNo} moved to Recycle Bin',
      onUndo: () => context.read<ChallanProvider>().restoreChallan(entry.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChallanProvider>();
    final auth = context.watch<AuthProvider>();

    // Retrieve the target party
    final partyList = provider.parties.where((p) => p.id == widget.partyId).toList();
    if (partyList.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Party Not Found'),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_off, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Party record does not exist or has been deleted.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to Parties Directory'),
              ),
            ],
          ),
        ),
      );
    }

    final party = partyList.first;

    // Filter ALL active challans belonging ONLY to this party
    final allPartyChallans =
        provider.challans.where((c) => c.partyId == party.id).toList();

    // Summary calculations for this party
    final totalChallanAmt =
        allPartyChallans.fold(0.0, (sum, c) => sum + c.challanAmount);
    final totalFinalAmt =
        allPartyChallans.fold(0.0, (sum, c) => sum + c.finalAmount);
    final totalGstAmt =
        allPartyChallans.fold(0.0, (sum, c) => sum + c.gstAmount);

    double totalUnpaid = 0.0;
    double totalReceived = 0.0;
    int unpaidCount = 0;
    for (var c in allPartyChallans) {
      if (c.paymentOption == PaymentOption.cash) {
        totalReceived += c.paidAmount;
        if (c.remainingAmount > 0.001) {
          totalUnpaid += c.remainingAmount;
          unpaidCount++;
        }
      } else {
        if (c.chequeDetails?.status == ChequeStatus.cleared) {
          totalReceived += c.finalAmount;
        } else {
          totalUnpaid += c.finalAmount;
          unpaidCount++;
        }
      }
    }

    // Apply local filters for this party
    final now = DateTime.now();
    final filtered = allPartyChallans.where((item) {
      // 1. Search Query
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchChallan = item.challanNo.toLowerCase().contains(q);
        final matchGst = item.gstBillNo.toLowerCase().contains(q);
        final matchNotes = item.notes.toLowerCase().contains(q);
        final matchChequeNo =
            item.chequeDetails?.chequeNo.toLowerCase().contains(q) ?? false;
        final matchBank =
            item.chequeDetails?.bankName.toLowerCase().contains(q) ?? false;

        if (!matchChallan &&
            !matchGst &&
            !matchNotes &&
            !matchChequeNo &&
            !matchBank) {
          return false;
        }
      }

      // 2. Payment Option Filter
      if (_paymentOptionFilter != null) {
        if (item.paymentOption != _paymentOptionFilter) return false;
      }

      // 3. Status Filter
      if (_statusFilter != null && _statusFilter != 'all') {
        if (_statusFilter == 'unpaid') {
          if (!item.isPending && !item.hasWarning) return false;
        } else if (_statusFilter == 'overdue') {
          if (item.isFullyPaid || !item.isPaymentOverdue) return false;
        } else if (_statusFilter == 'paid') {
          if (!item.isFullyPaid) return false;
        } else if (_statusFilter == 'bounced') {
          if (item.chequeDetails?.status != ChequeStatus.bounced) return false;
        }
      }

      // 4. Date Filter
      if (_dateFilter == 'today') {
        if (item.date.year != now.year ||
            item.date.month != now.month ||
            item.date.day != now.day) {
          return false;
        }
      } else if (_dateFilter == 'week') {
        final sevenDaysAgo = now.subtract(const Duration(days: 7));
        if (item.date.isBefore(sevenDaysAgo)) return false;
      } else if (_dateFilter == 'month') {
        final thirtyDaysAgo = now.subtract(const Duration(days: 30));
        if (item.date.isBefore(thirtyDaysAgo)) return false;
      } else if (_dateFilter == 'monthly_picker' &&
          _selectedMonth != null &&
          _selectedYear != null) {
        if (item.date.month != _selectedMonth ||
            item.date.year != _selectedYear) {
          return false;
        }
      } else if (_dateFilter == 'custom' &&
          _customStartDate != null &&
          _customEndDate != null) {
        final startBound = DateTime(_customStartDate!.year, _customStartDate!.month, _customStartDate!.day);
        final endBound = DateTime(_customEndDate!.year, _customEndDate!.month, _customEndDate!.day, 23, 59, 59, 999);
        if (item.date.isBefore(startBound) || item.date.isAfter(endBound)) {
          return false;
        }
      }

      return true;
    }).toList();

    // 5. Sort (Date or Challan #)
    if (_sortField == ChallanSortField.challanNo) {
      filtered.sort((a, b) => Formatters.compareChallanNumbers(
            a.challanNo,
            b.challanNo,
            ascending: _sortAscending,
          ));
    } else {
      filtered.sort((a, b) =>
          _sortAscending ? a.date.compareTo(b.date) : b.date.compareTo(a.date));
    }

    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to Parties Directory',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              provider.formatCasedText(party.name),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'Party Ledger • ${allPartyChallans.length} Entries',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.color
                    ?.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        actions: [
          if (auth.canExportReports)
            isMobile
                ? IconButton(
                    icon: Icon(Icons.picture_as_pdf, color: AppColors.primary),
                    tooltip: 'Export Party Ledger',
                    onPressed: () => _openExportDialog(context),
                  )
                : OutlinedButton.icon(
                    onPressed: () => _openExportDialog(context),
                    icon: Icon(Icons.picture_as_pdf, color: AppColors.primary, size: 18),
                    label: const Text('Export Party Ledger'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
          if (auth.canCreateChallan) ...[
            const SizedBox(width: 6),
            isMobile
                ? IconButton(
                    icon: Icon(Icons.add_circle, color: AppColors.primary),
                    tooltip: 'Add Challan',
                    onPressed: () => _openAddChallan(context, party),
                  )
                : ElevatedButton.icon(
                    onPressed: () => _openAddChallan(context, party),
                    icon: const Icon(Icons.add_circle, size: 18),
                    label: const Text('Add Challan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
          ],
          const SizedBox(width: 12),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 12 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // PARTY CONTACT & DETAILS CARD
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                      foregroundColor: AppColors.primary,
                      child: Text(
                        party.name.isNotEmpty ? party.name[0].toUpperCase() : 'P',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                provider.formatCasedText(party.name),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (party.gstNumber.isNotEmpty) ...[
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: AppColors.primary.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Text(
                                    'GSTIN: ${party.gstNumber}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 16,
                            runSpacing: 4,
                            children: [
                              if (party.phone.isNotEmpty)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.phone, size: 14, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(
                                      party.phone,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Theme.of(context).textTheme.bodySmall?.color,
                                      ),
                                    ),
                                  ],
                                ),
                              if (party.address.isNotEmpty)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.location_on, size: 14, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(
                                      party.address,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Theme.of(context).textTheme.bodySmall?.color,
                                      ),
                                    ),
                                  ],
                                ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.calendar_today, size: 13, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Registered: ${Formatters.date(party.createdAt)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.color
                                          ?.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _openEditParty(context, party),
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Edit Party Info'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 4 SUMMARY KPI CARDS FOR THIS PARTY
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 900;
                final isNarrow = constraints.maxWidth < 600;
                final crossCount = isWide ? 4 : 2;

                return GridView.count(
                  crossAxisCount: crossCount,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: isNarrow ? 10 : 14,
                  mainAxisSpacing: isNarrow ? 10 : 14,
                  childAspectRatio: isWide ? 1.7 : (isNarrow ? 1.55 : 2.2),
                  children: [
                    _buildKpiCard(
                      context,
                      title: 'TOTAL CHALLAN AMOUNT',
                      amount: Formatters.currency(totalChallanAmt),
                      icon: Icons.receipt_long,
                      color: AppColors.primary,
                      bgColor: AppColors.primary.withValues(alpha: 0.12),
                    ),
                    _buildKpiCard(
                      context,
                      title: 'TOTAL FINAL BILLED',
                      amount: Formatters.currency(totalFinalAmt),
                      subtitle: 'Received: ${Formatters.currency(totalReceived)}',
                      icon: Icons.account_balance_wallet,
                      color: const Color(0xFF0284C7),
                      bgColor: const Color(0xFFE0F2FE),
                    ),
                    _buildKpiCard(
                      context,
                      title: 'TOTAL GST BILLED',
                      amount: Formatters.currency(totalGstAmt),
                      icon: Icons.calculate,
                      color: const Color(0xFF7C3AED),
                      bgColor: const Color(0xFFEDE9FE),
                    ),
                    _buildKpiCard(
                      context,
                      title: 'PENDING / UNPAID DUES',
                      amount: Formatters.currency(totalUnpaid),
                      subtitle: '$unpaidCount Pending Action',
                      icon: Icons.warning_rounded,
                      color: AppColors.warningText,
                      bgColor: AppColors.warningBgLight,
                      isWarning: unpaidCount > 0,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            // PARTY OVERDUE PAYMENT WARNING BANNER
            Builder(builder: (context) {
              final partyOverdue = allPartyChallans.where((c) => !c.isFullyPaid && c.isPaymentOverdue).toList();
              if (partyOverdue.isEmpty) return const SizedBox.shrink();

              final overdueTotal = partyOverdue.fold(0.0, (s, c) => s + c.remainingAmount);
              final isDark = Theme.of(context).brightness == Brightness.dark;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF3B1E1E) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFEF4444), width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PAYMENT OVERDUE ALERT FOR THIS PARTY 🚨',
                            style: TextStyle(
                              fontSize: isMobile ? 12.5 : 14,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFDC2626),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${partyOverdue.length} challans past payment due date (${Formatters.currency(overdueTotal)}). Waiting for cash or cheque details.',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: () {
                        setState(() => _statusFilter = _statusFilter == 'overdue' ? 'all' : 'overdue');
                      },
                      child: Text(_statusFilter == 'overdue' ? 'Show All' : 'Filter Overdue'),
                    ),
                  ],
                ),
              );
            }),

            // PARTY-SPECIFIC FILTER TOOLBAR (ZERO HORIZONTAL SCROLL)
            Card(
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 12 : 16),
                child: Column(
                  children: [
                    // ROW 1: SEARCH & PAYMENT OPTION (RESPONSIVE)
                    if (isMobile) ...[
                      Builder(
                        builder: (ctx) {
                          int activeCount = 0;
                          if (_paymentOptionFilter != null) activeCount++;
                          if (_statusFilter != null && _statusFilter != 'all') activeCount++;
                          if (_dateFilter != 'all') activeCount++;
                          return Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  decoration: InputDecoration(
                                    hintText: 'Search Challan, GST, Notes...',
                                    prefixIcon: const Icon(Icons.search, size: 18),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                    suffixIcon: _searchQuery.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear, size: 16),
                                            onPressed: () => setState(() => _searchQuery = ''),
                                          )
                                        : null,
                                  ),
                                  controller: TextEditingController(text: _searchQuery)
                                    ..selection = TextSelection.fromPosition(
                                      TextPosition(offset: _searchQuery.length),
                                    ),
                                  onChanged: (val) => setState(() => _searchQuery = val),
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.tonalIcon(
                                onPressed: () => _showMobilePartyLedgerFilterSheet(context, allPartyChallans),
                                icon: const Icon(Icons.tune_rounded, size: 17),
                                label: Text(
                                  activeCount > 0 ? 'Filters ($activeCount)' : 'Filters',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                  backgroundColor: activeCount > 0
                                      ? AppColors.primary.withValues(alpha: 0.16)
                                      : null,
                                  foregroundColor: activeCount > 0 ? AppColors.primary : null,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                              if (activeCount > 0 || _searchQuery.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                IconButton.filledTonal(
                                  tooltip: 'Reset Filters',
                                  icon: const Icon(Icons.filter_alt_off, size: 18),
                                  onPressed: () {
                                    setState(() {
                                      _searchQuery = '';
                                      _paymentOptionFilter = null;
                                      _statusFilter = null;
                                      _dateFilter = 'all';
                                      _selectedMonth = null;
                                      _selectedYear = null;
                                      _customStartDate = null;
                                      _customEndDate = null;
                                      _sortField = ChallanSortField.date;
                                      _sortAscending = false;
                                    });
                                  },
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: 'Search Challan No, GST Bill, Cheque No, or Notes...',
                                prefixIcon: const Icon(Icons.search, size: 20),
                                isDense: true,
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18),
                                        onPressed: () => setState(() => _searchQuery = ''),
                                      )
                                    : null,
                              ),
                              controller: TextEditingController(text: _searchQuery)
                                ..selection = TextSelection.fromPosition(
                                  TextPosition(offset: _searchQuery.length),
                                ),
                              onChanged: (val) => setState(() => _searchQuery = val),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<PaymentOption?>(
                              initialValue: _paymentOptionFilter,
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
                              onChanged: (val) => setState(() => _paymentOptionFilter = val),
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton.filledTonal(
                            tooltip: 'Reset Filters',
                            icon: const Icon(Icons.filter_alt_off, size: 18),
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                                _paymentOptionFilter = null;
                                _statusFilter = null;
                                _dateFilter = 'all';
                                _selectedMonth = null;
                                _selectedYear = null;
                                _sortField = ChallanSortField.date;
                                _sortAscending = false;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                    if (!isMobile) ...[
                      const SizedBox(height: 12),

                      // ROW 2: STATUS, PERIOD, SORT (IN ZERO-SCROLL WRAP)
                      Wrap(
                      spacing: 8,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          'Status: ',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        _buildFilterChip('all', 'All', _statusFilter == null || _statusFilter == 'all', () {
                          setState(() => _statusFilter = 'all');
                        }),
                        _buildFilterChip('paid', 'Paid', _statusFilter == 'paid', () {
                          setState(() => _statusFilter = 'paid');
                        }, color: AppColors.successText),
                        _buildFilterChip('unpaid', 'Unpaid Warning', _statusFilter == 'unpaid', () {
                          setState(() => _statusFilter = 'unpaid');
                        }, color: AppColors.warningText),
                        if (allPartyChallans.any((c) => !c.isFullyPaid && c.isPaymentOverdue))
                          _buildFilterChip('overdue', 'Overdue 🚨', _statusFilter == 'overdue', () {
                            setState(() => _statusFilter = _statusFilter == 'overdue' ? 'all' : 'overdue');
                          }, color: const Color(0xFFDC2626)),
                        _buildFilterChip('bounced', 'Bounced', _statusFilter == 'bounced', () {
                          setState(() => _statusFilter = 'bounced');
                        }, color: AppColors.warningText),

                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Text('•', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                        ),

                        const Text(
                          'Period: ',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        _buildFilterChip('all', 'All Time', _dateFilter == 'all', () {
                          setState(() => _dateFilter = 'all');
                        }),
                        _buildFilterChip('today', 'Today', _dateFilter == 'today', () {
                          setState(() => _dateFilter = 'today');
                        }),
                        _buildFilterChip('week', 'Last 7 Days', _dateFilter == 'week', () {
                          setState(() => _dateFilter = 'week');
                        }),
                        _buildFilterChip('month', 'Last 30 Days', _dateFilter == 'month', () {
                          setState(() => _dateFilter = 'month');
                        }),

                        ActionChip(
                          avatar: Icon(Icons.calendar_month, size: 16, color: AppColors.primary),
                          label: Text(
                            _dateFilter == 'monthly_picker' && _selectedMonth != null
                                ? 'Month: ${DateFormat('MMM yyyy').format(DateTime(_selectedYear!, _selectedMonth!))}'
                                : 'Pick Month...',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: _dateFilter == 'monthly_picker'
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: _dateFilter == 'monthly_picker' ? AppColors.primary : null,
                            ),
                          ),
                          backgroundColor: _dateFilter == 'monthly_picker'
                              ? AppColors.primary.withValues(alpha: 0.15)
                              : null,
                          onPressed: () => _showMonthPicker(context, allPartyChallans),
                        ),

                        // CUSTOM DATE RANGE (FROM - TO)
                        ActionChip(
                          avatar: Icon(
                            Icons.date_range,
                            size: 16,
                            color: _dateFilter == 'custom' ? AppColors.primary : Colors.grey,
                          ),
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _dateFilter == 'custom' &&
                                        _customStartDate != null &&
                                        _customEndDate != null
                                    ? 'From: ${DateFormat('dd/MM/yy').format(_customStartDate!)} To: ${DateFormat('dd/MM/yy').format(_customEndDate!)}'
                                    : 'From - To Date...',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: _dateFilter == 'custom'
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: _dateFilter == 'custom' ? AppColors.primary : null,
                                ),
                              ),
                              if (_dateFilter == 'custom') ...[
                                const SizedBox(width: 4),
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      _dateFilter = 'all';
                                      _customStartDate = null;
                                      _customEndDate = null;
                                    });
                                  },
                                  child: Icon(Icons.close, size: 14, color: AppColors.primary),
                                ),
                              ],
                            ],
                          ),
                          backgroundColor: _dateFilter == 'custom'
                              ? AppColors.primary.withValues(alpha: 0.15)
                              : null,
                          onPressed: () => _showCustomDateRangePicker(context),
                        ),

                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Text('•', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                        ),

                        // DATE SORT TOGGLE
                        ActionChip(
                          avatar: Icon(
                            _sortField == ChallanSortField.date
                                ? (_sortAscending ? Icons.arrow_upward : Icons.arrow_downward)
                                : Icons.calendar_today,
                            size: 15,
                            color: _sortField == ChallanSortField.date ? AppColors.primary : Colors.grey,
                          ),
                          label: Text(
                            _sortField == ChallanSortField.date
                                ? (_sortAscending ? 'Date: Oldest ↑' : 'Date: Newest ↓')
                                : 'Date Wise',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: _sortField == ChallanSortField.date ? FontWeight.bold : FontWeight.normal,
                              color: _sortField == ChallanSortField.date ? AppColors.primary : null,
                            ),
                          ),
                          backgroundColor: _sortField == ChallanSortField.date
                              ? AppColors.primary.withValues(alpha: 0.15)
                              : null,
                          onPressed: () {
                            setState(() {
                              if (_sortField == ChallanSortField.date) {
                                _sortAscending = !_sortAscending;
                              } else {
                                _sortField = ChallanSortField.date;
                                _sortAscending = false;
                              }
                            });
                          },
                        ),

                        const SizedBox(width: 6),

                        // CHALLAN NO SORT TOGGLE
                        ActionChip(
                          avatar: Icon(
                            _sortField == ChallanSortField.challanNo
                                ? (_sortAscending ? Icons.arrow_upward : Icons.arrow_downward)
                                : Icons.tag,
                            size: 15,
                            color: _sortField == ChallanSortField.challanNo ? AppColors.primary : Colors.grey,
                          ),
                          label: Text(
                            _sortField == ChallanSortField.challanNo
                                ? (_sortAscending ? 'Challan #: 1→9 ↑' : 'Challan #: 9→1 ↓')
                                : 'Challan # Wise',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: _sortField == ChallanSortField.challanNo ? FontWeight.bold : FontWeight.normal,
                              color: _sortField == ChallanSortField.challanNo ? AppColors.primary : null,
                            ),
                          ),
                          backgroundColor: _sortField == ChallanSortField.challanNo
                              ? AppColors.primary.withValues(alpha: 0.15)
                              : null,
                          onPressed: () {
                            setState(() {
                              if (_sortField == ChallanSortField.challanNo) {
                                _sortAscending = !_sortAscending;
                              } else {
                                _sortField = ChallanSortField.challanNo;
                                _sortAscending = true;
                              }
                            });
                          },
                        ),
                      ],
                    ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // SUMMARY BANNER
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  Icon(Icons.filter_list, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Showing ${filtered.length} of ${allPartyChallans.length} challans for "${provider.formatCasedText(party.name)}"',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!isMobile && filtered.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    // WINDOWS EXPLORER STYLE VIEW MODE SWITCHER
                    _buildViewModeSwitcher(context, provider),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // LIST OF CHALLANS FOR THIS PARTY ONLY (TABLE / COMPACT / CARDS)
            if (filtered.isEmpty)
              Card(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: isMobile ? 32 : 48, horizontal: 20),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 52,
                          color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          allPartyChallans.isEmpty
                              ? 'No challan records found for ${provider.formatCasedText(party.name)}'
                              : 'No challans match the active filters',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          allPartyChallans.isEmpty
                              ? 'Tap "Add Challan" to create the first delivery challan for this party.'
                              : 'Adjust your search or tap the reset filter icon above.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                        if (auth.canCreateChallan) ...[
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _openAddChallan(context, party),
                            icon: const Icon(Icons.add),
                            label: const Text('Add Challan Entry'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              )
            else if (isMobile || provider.viewMode == LedgerViewMode.cards)
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final item = filtered[index];
                  return _buildChallanCard(context, item);
                },
              )
            else if (provider.viewMode == LedgerViewMode.compact)
              _buildCompactListView(context, filtered)
            else
              _buildExcelTableView(context, filtered),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(
    String key,
    String label,
    bool isSelected,
    VoidCallback onSelected, {
    Color? color,
  }) {
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
      onSelected: (_) => onSelected(),
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
        onTap: () => _openViewChallan(context, item),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(MediaQuery.of(context).size.width < 700 ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ROW 1: CHALLAN NO, DATE, STATUS BADGE, ACTIONS
              if (MediaQuery.of(context).size.width < 700) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
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
                                fontSize: 13.5,
                                color: hasWarning ? AppColors.warningText : AppColors.primary,
                              ),
                            ),
                          ),
                          if (item.designNo.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                item.designNo,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0284C7),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      icon: const Icon(Icons.more_vert, size: 20),
                      onSelected: (val) {
                        if (val == 'print') _openInvoiceDialog(context, item);
                        if (val == 'view') _openViewChallan(context, item);
                        if (val == 'edit') _openEditChallan(context, item);
                        if (val == 'delete') _confirmDeleteChallan(context, item);
                      },
                      itemBuilder: (ctx) => [
                        if (ctx.read<AuthProvider>().canPrintInvoice)
                          PopupMenuItem(
                            value: 'print',
                            child: Row(
                              children: [
                                Icon(Icons.receipt_long_outlined, size: 18, color: AppColors.primary),
                                const SizedBox(width: 10),
                                const Text('Print Tax Invoice (A4/A5)'),
                              ],
                            ),
                          ),
                        const PopupMenuItem(
                          value: 'view',
                          child: Row(
                            children: [
                              Icon(Icons.visibility_outlined, size: 18),
                              SizedBox(width: 10),
                              Text('View Full Details'),
                            ],
                          ),
                        ),
                        if (ctx.read<AuthProvider>().canEditChallan)
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined, size: 18),
                                SizedBox(width: 10),
                                Text('Edit Entry'),
                              ],
                            ),
                          ),
                        if (ctx.read<AuthProvider>().canDelete)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, size: 18, color: AppColors.warningText),
                                SizedBox(width: 10),
                                Text('Move to Recycle Bin', style: TextStyle(color: AppColors.warningText)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today, size: 13, color: Colors.grey),
                        const SizedBox(width: 5),
                        Text(
                          Formatters.date(item.date),
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                        ),
                      ],
                    ),
                    _buildStatusBadge(item),
                  ],
                ),
              ] else
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
                    if (context.watch<AuthProvider>().canPrintInvoice)
                      IconButton(
                        icon: Icon(Icons.receipt_long_outlined, size: 18, color: AppColors.primary),
                        tooltip: 'Print Tax Invoice (A4/A5)',
                        onPressed: () => _openInvoiceDialog(context, item),
                      ),
                    IconButton(
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      tooltip: 'View Full Details',
                      onPressed: () => _openViewChallan(context, item),
                    ),
                    if (context.watch<AuthProvider>().canEditChallan)
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        tooltip: 'Edit Entry',
                        onPressed: () => _openEditChallan(context, item),
                      ),
                    if (context.watch<AuthProvider>().canDelete)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.warningText),
                        tooltip: 'Delete Entry',
                        onPressed: () => _confirmDeleteChallan(context, item),
                      ),
                  ],
                ),
              const SizedBox(height: 12),

              // ROW 2: AMOUNTS
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'NOTES & REMARKS',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.notes.isNotEmpty ? item.notes : 'No extra notes provided',
                          style: TextStyle(
                            fontSize: 13,
                            color: item.notes.isNotEmpty
                                ? Theme.of(context).textTheme.bodySmall?.color
                                : Colors.grey,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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

  Widget _buildViewModeSwitcher(BuildContext context, ChallanProvider provider) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildViewModeButton(
            context,
            mode: LedgerViewMode.table,
            current: provider.viewMode,
            icon: Icons.table_chart_outlined,
            label: 'Excel Table',
            tooltip: 'Excel Grid View (Dense rows, view many records at once)',
            onTap: () => provider.setViewMode(LedgerViewMode.table),
          ),
          _buildViewModeButton(
            context,
            mode: LedgerViewMode.compact,
            current: provider.viewMode,
            icon: Icons.view_list_rounded,
            label: 'Compact',
            tooltip: 'Compact List View',
            onTap: () => provider.setViewMode(LedgerViewMode.compact),
          ),
          _buildViewModeButton(
            context,
            mode: LedgerViewMode.cards,
            current: provider.viewMode,
            icon: Icons.view_agenda_outlined,
            label: 'Cards',
            tooltip: 'Large Cards View',
            onTap: () => provider.setViewMode(LedgerViewMode.cards),
          ),
        ],
      ),
    );
  }

  Widget _buildViewModeButton(
    BuildContext context, {
    required LedgerViewMode mode,
    required LedgerViewMode current,
    required IconData icon,
    required String label,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    final isSelected = mode == current;
    final primaryColor = AppColors.primary;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected ? Theme.of(context).cardColor : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? primaryColor : Theme.of(context).textTheme.bodySmall?.color,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? primaryColor : Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExcelTableView(BuildContext context, List<ChallanEntry> entries) {
    final provider = context.watch<ChallanProvider>();
    final sumChallan = entries.fold(0.0, (s, c) => s + c.challanAmount);
    final sumDiscount = entries.fold(0.0, (s, c) => s + c.discountAmount);
    final sumGst = entries.fold(0.0, (s, c) => s + c.gstAmount);
    final sumFinal = entries.fold(0.0, (s, c) => s + c.finalAmount);
    final sumPaid = entries.fold(0.0, (s, c) => s + c.paidAmount);
    final sumDue = entries.fold(0.0, (s, c) => s + (c.paymentOption == PaymentOption.cash ? c.remainingAmount : (c.chequeDetails?.status != ChequeStatus.cleared ? c.finalAmount : 0.0)));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final tableCard = Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
          // EXCEL TABLE HEADER ROW
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 26, child: Text('#', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                SizedBox(
                  width: 72,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        if (_sortField == ChallanSortField.date) {
                          _sortAscending = !_sortAscending;
                        } else {
                          _sortField = ChallanSortField.date;
                          _sortAscending = false;
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'DATE',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: _sortField == ChallanSortField.date ? AppColors.primary : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          _sortField == ChallanSortField.date
                              ? (_sortAscending ? Icons.arrow_upward : Icons.arrow_downward)
                              : Icons.unfold_more,
                          size: 13,
                          color: _sortField == ChallanSortField.date ? AppColors.primary : const Color(0xFF64748B).withValues(alpha: 0.5),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: 75,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        if (_sortField == ChallanSortField.challanNo) {
                          _sortAscending = !_sortAscending;
                        } else {
                          _sortField = ChallanSortField.challanNo;
                          _sortAscending = true;
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'CHALLAN #',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: _sortField == ChallanSortField.challanNo ? AppColors.primary : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          _sortField == ChallanSortField.challanNo
                              ? (_sortAscending ? Icons.arrow_upward : Icons.arrow_downward)
                              : Icons.unfold_more,
                          size: 13,
                          color: _sortField == ChallanSortField.challanNo ? AppColors.primary : const Color(0xFF64748B).withValues(alpha: 0.5),
                        ),
                      ],
                    ),
                  ),
                ),
                const Expanded(flex: 3, child: Text('NOTES / REMARKS', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                const Expanded(flex: 2, child: Align(alignment: Alignment.centerRight, child: Text('CHALLAN AMT', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B))))),
                const Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: Padding(padding: EdgeInsets.only(left: 8), child: Text('GST BILL & AMT', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))))),
                const Expanded(flex: 1, child: Align(alignment: Alignment.centerLeft, child: Padding(padding: EdgeInsets.only(left: 4), child: Text('DESIGN', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))))),
                const Expanded(flex: 1, child: Align(alignment: Alignment.centerRight, child: Text('DISC.', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B))))),
                const Expanded(flex: 2, child: Align(alignment: Alignment.centerRight, child: Text('FINAL AMT', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B))))),
                const Expanded(flex: 2, child: Align(alignment: Alignment.centerRight, child: Text('PAID / RECVD', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B))))),
                const Expanded(flex: 2, child: Align(alignment: Alignment.centerRight, child: Text('BALANCE DUE', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B))))),
                const SizedBox(width: 80, child: Center(child: Text('STATUS', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B))))),
                const SizedBox(width: 88, child: Center(child: Text('ACTIONS', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B))))),
              ],
            ),
          ),

          // DATA ROWS
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: entries.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              thickness: 1,
              color: Theme.of(context).dividerColor.withValues(alpha: 0.12),
            ),
            itemBuilder: (context, index) {
              final item = entries[index];
              final isCash = item.paymentOption == PaymentOption.cash;
              final isUnpaidCash = isCash && !item.isCashPaid && !item.isPartiallyPaid;
              final isPartialCash = isCash && item.isPartiallyPaid;
              final isBounced = !isCash && item.chequeDetails?.status == ChequeStatus.bounced;
              final hasWarning = isUnpaidCash || isBounced;

              Color rowBg;
              if (hasWarning) {
                rowBg = provider.getEffectiveWarningBgColor(isDark);
              } else if (isPartialCash) {
                rowBg = provider.getEffectivePartialBgColor(isDark);
              } else {
                rowBg = index.isEven
                    ? Theme.of(context).cardColor
                    : (isDark ? const Color(0xFF1E293B).withValues(alpha: 0.4) : const Color(0xFFF8FAFC));
              }

              final dueAmt = isCash ? item.remainingAmount : (item.chequeDetails?.status != ChequeStatus.cleared ? item.finalAmount : 0.0);

              return Material(
                color: rowBg,
                child: InkWell(
                  onTap: () => _openViewChallan(context, item),
                  hoverColor: AppColors.primary.withValues(alpha: 0.06),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    child: Row(
                      children: [
                        // #
                        SizedBox(
                          width: 26,
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                        // DATE
                        SizedBox(
                          width: 72,
                          child: Text(
                            Formatters.shortDate(item.date),
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500),
                          ),
                        ),
                        // CHALLAN NO
                        SizedBox(
                          width: 75,
                          child: Text(
                            item.challanNo,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: hasWarning ? AppColors.warningText : AppColors.primary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // NOTES / REMARKS
                        Expanded(
                          flex: 3,
                          child: Text(
                            item.notes.isNotEmpty ? item.notes : 'No remarks',
                            style: TextStyle(
                              fontSize: 12,
                              color: item.notes.isNotEmpty ? null : Colors.grey,
                              fontStyle: item.notes.isNotEmpty ? FontStyle.normal : FontStyle.italic,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // CHALLAN AMT
                        Expanded(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              Formatters.currency(item.challanAmount),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ),
                        // GST BILL & AMT
                        Expanded(
                          flex: 2,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text(
                              item.gstBillNo.isNotEmpty
                                  ? '${item.gstBillNo} (${Formatters.currency(item.gstAmount)})'
                                  : '-',
                              style: TextStyle(
                                fontSize: 11,
                                color: item.gstBillNo.isNotEmpty ? null : Colors.grey,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        // DESIGN NO.
                        Expanded(
                          flex: 1,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Text(
                                item.designNo.isNotEmpty ? item.designNo : '-',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: item.designNo.isNotEmpty
                                      ? (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7))
                                      : Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.4),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                        // DISCOUNT
                        Expanded(
                          flex: 1,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              item.discountAmount > 0
                                  ? Formatters.currency(item.discountAmount)
                                  : '-',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: item.discountAmount > 0
                                    ? (isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706))
                                    : Colors.grey,
                              ),
                            ),
                          ),
                        ),
                        // FINAL AMT
                        Expanded(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              Formatters.currency(item.finalAmount),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: hasWarning
                                    ? provider.getEffectiveWarningTextColor(isDark)
                                    : (isPartialCash ? provider.getEffectivePartialTextColor(isDark) : provider.primaryColor),
                              ),
                            ),
                          ),
                        ),
                        // PAID / RECVD
                        Expanded(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              Formatters.currency(item.paidAmount),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: item.isFullyPaid ? provider.getEffectiveSuccessTextColor(isDark) : provider.getEffectivePartialTextColor(isDark),
                              ),
                            ),
                          ),
                        ),
                        // BALANCE DUE
                        Expanded(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  dueAmt > 0 ? Formatters.currency(dueAmt) : '-',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: dueAmt > 0
                                        ? (item.isPaymentOverdue ? const Color(0xFFDC2626) : provider.getEffectiveWarningTextColor(isDark))
                                        : Colors.grey,
                                  ),
                                ),
                                if (!item.isFullyPaid && item.paymentDueDate != null)
                                  Container(
                                    margin: const EdgeInsets.only(top: 2),
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: item.isPaymentOverdue
                                          ? const Color(0xFFDC2626).withValues(alpha: 0.15)
                                          : (item.daysUntilPaymentDue == 0 || item.daysUntilPaymentDue == 1
                                              ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                                              : AppColors.primary.withValues(alpha: 0.1)),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      item.paymentDueCountdownText,
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: item.isPaymentOverdue
                                            ? const Color(0xFFDC2626)
                                            : (item.daysUntilPaymentDue == 0 || item.daysUntilPaymentDue == 1
                                                ? const Color(0xFFD97706)
                                                : AppColors.primary),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        // STATUS
                        SizedBox(
                          width: 80,
                          child: Center(
                            child: _buildStatusBadge(item, compact: true),
                          ),
                        ),
                        // ACTIONS
                        SizedBox(
                          width: 88,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (context.watch<AuthProvider>().canPrintInvoice)
                                _buildActionIcon(
                                  icon: Icons.receipt_long_outlined,
                                  tooltip: 'Print Tax Invoice (A4/A5)',
                                  color: AppColors.primary,
                                  onTap: () => _openInvoiceDialog(context, item),
                                ),
                              const SizedBox(width: 2),
                              _buildActionIcon(
                                icon: Icons.visibility_outlined,
                                tooltip: 'View Full Details',
                                color: Theme.of(context).textTheme.bodySmall?.color,
                                onTap: () => _openViewChallan(context, item),
                              ),
                              if (context.watch<AuthProvider>().canEditChallan) ...[
                                const SizedBox(width: 2),
                                _buildActionIcon(
                                  icon: Icons.edit_outlined,
                                  tooltip: 'Edit Entry',
                                  color: AppColors.primary,
                                  onTap: () => _openEditChallan(context, item),
                                ),
                              ],
                              if (context.watch<AuthProvider>().canDelete) ...[
                                const SizedBox(width: 2),
                                _buildActionIcon(
                                  icon: Icons.delete_outline,
                                  tooltip: 'Move to Bin',
                                  color: AppColors.warningText,
                                  onTap: () => _confirmDeleteChallan(context, item),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // EXCEL TOTAL FOOTER ROW
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.35),
                  width: 2.0,
                ),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 173,
                  child: Text(
                    'TOTAL (${entries.length} Entries)',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                ),
                const Expanded(flex: 3, child: SizedBox()),
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      Formatters.currency(sumChallan),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        Formatters.currency(sumGst),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
                // DESIGN NO. (empty in totals)
                const Expanded(flex: 1, child: SizedBox()),
                // DISCOUNT TOTAL
                Expanded(
                  flex: 1,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      sumDiscount > 0 ? Formatters.currency(sumDiscount) : '-',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: sumDiscount > 0
                            ? (isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706))
                            : Colors.grey,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      Formatters.currency(sumFinal),
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      Formatters.currency(sumPaid),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.successText),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      Formatters.currency(sumDue),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: sumDue > 0 ? AppColors.warningText : Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 168),
              ],
            ),
          ),
        ],
      ),
    );

    if (constraints.maxWidth < 900) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 900,
          child: tableCard,
        ),
      );
    }

    return SizedBox(
      width: constraints.maxWidth,
      child: tableCard,
    );
      },
    );
  }

  Widget _buildCompactListView(BuildContext context, List<ChallanEntry> entries) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final item = entries[index];
        final isCash = item.paymentOption == PaymentOption.cash;
        final isUnpaidCash = isCash && !item.isCashPaid && !item.isPartiallyPaid;
        final isPartialCash = isCash && item.isPartiallyPaid;
        final isBounced = !isCash && item.chequeDetails?.status == ChequeStatus.bounced;
        final hasWarning = isUnpaidCash || isBounced;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final dueAmt = isCash ? item.remainingAmount : (item.chequeDetails?.status != ChequeStatus.cleared ? item.finalAmount : 0.0);

        final rowBg = hasWarning
            ? (isDark ? const Color(0xFF3B1E1E) : const Color(0xFFFEF2F2))
            : (isPartialCash
                ? (isDark ? const Color(0xFF332707) : const Color(0xFFFFFDF5))
                : Theme.of(context).cardColor);

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          decoration: BoxDecoration(
            color: rowBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: hasWarning
                  ? AppColors.warningBorder
                  : (isPartialCash ? const Color(0xFFFDE68A) : Theme.of(context).dividerColor.withValues(alpha: 0.2)),
              width: hasWarning || isPartialCash ? 1.5 : 1.0,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _openViewChallan(context, item),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: hasWarning
                            ? AppColors.warningText.withValues(alpha: 0.15)
                            : AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '#${item.challanNo}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: hasWarning ? AppColors.warningText : AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      Formatters.shortDate(item.date),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.notes.isNotEmpty ? item.notes : 'Challan #${item.challanNo}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusBadge(item, compact: true),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          Formatters.currency(item.finalAmount),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: hasWarning ? AppColors.warningText : AppColors.primary,
                          ),
                        ),
                        if (dueAmt > 0)
                          Text(
                            'Due: ${Formatters.currency(dueAmt)}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFB45309),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (context.watch<AuthProvider>().canPrintInvoice)
                          _buildActionIcon(
                            icon: Icons.receipt_long_outlined,
                            tooltip: 'Print Tax Invoice (A4/A5)',
                            color: AppColors.primary,
                            onTap: () => _openInvoiceDialog(context, item),
                          ),
                        const SizedBox(width: 2),
                        _buildActionIcon(
                          icon: Icons.visibility_outlined,
                          tooltip: 'View Full Details',
                          color: Theme.of(context).textTheme.bodySmall?.color,
                          onTap: () => _openViewChallan(context, item),
                        ),
                        if (context.watch<AuthProvider>().canEditChallan) ...[
                          const SizedBox(width: 2),
                          _buildActionIcon(
                            icon: Icons.edit_outlined,
                            tooltip: 'Edit Entry',
                            color: AppColors.primary,
                            onTap: () => _openEditChallan(context, item),
                          ),
                        ],
                        if (context.watch<AuthProvider>().canDelete) ...[
                          const SizedBox(width: 2),
                          _buildActionIcon(
                            icon: Icons.delete_outline,
                            tooltip: 'Move to Bin',
                            color: AppColors.warningText,
                            onTap: () => _confirmDeleteChallan(context, item),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionIcon({
    required IconData icon,
    required String tooltip,
    Color? color,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(icon, size: 15, color: color),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(ChallanEntry item, {bool compact = false}) {
    final provider = context.watch<ChallanProvider>();
    if (item.paymentOption == PaymentOption.cash) {
      if (item.isPartiallyPaid) {
        return Container(
          padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: compact ? 2 : 3),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: provider.partialColor.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.pie_chart, size: 11, color: provider.partialColor),
              const SizedBox(width: 4),
              Text(
                compact
                    ? 'PARTIAL'
                    : 'PARTIAL: PAID ${Formatters.currency(item.paidAmount)} • DUE ${Formatters.currency(item.remainingAmount)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: provider.partialColor,
                ),
              ),
            ],
          ),
        );
      } else if (item.isCashPaid) {
        return Container(
          padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: compact ? 2 : 3),
          decoration: BoxDecoration(
            color: provider.successColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: provider.successColor.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check, size: 11, color: provider.successColor),
              const SizedBox(width: 3),
              Text(
                compact ? 'PAID' : 'CASH PAID',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: provider.successColor,
                ),
              ),
            ],
          ),
        );
      } else {
        final isOverdue = item.isPaymentOverdue;
        return Container(
          padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: compact ? 2 : 3),
          decoration: BoxDecoration(
            color: isOverdue ? const Color(0xFFDC2626) : provider.warningColor,
            borderRadius: BorderRadius.circular(5),
            border: isOverdue ? Border.all(color: const Color(0xFFFCA5A5), width: 1) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isOverdue ? Icons.error_outline : Icons.warning_amber_rounded, size: 11, color: Colors.white),
              const SizedBox(width: 3),
              Text(
                isOverdue
                    ? (compact ? 'OVERDUE' : 'OVERDUE (${item.daysUntilPaymentDue!.abs()}d)')
                    : (compact ? 'UNPAID' : 'UNPAID CASH'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
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
      String label;

      switch (status) {
        case ChequeStatus.cleared:
          bg = AppColors.successBgLight;
          text = AppColors.successText;
          border = AppColors.successBorder;
          icon = Icons.check_circle;
          label = compact ? 'CLEARED' : 'CHEQUE: CLEARED';
          break;
        case ChequeStatus.bounced:
          bg = AppColors.warningText;
          text = Colors.white;
          border = AppColors.warningBorder;
          icon = Icons.cancel;
          label = compact ? 'BOUNCED' : 'CHEQUE: BOUNCED';
          break;
        case ChequeStatus.pending:
          bg = AppColors.pendingBgLight;
          text = AppColors.pendingText;
          border = AppColors.pendingBorder;
          icon = Icons.hourglass_top;
          label = compact ? 'PENDING' : 'CHEQUE: PENDING CLEARANCE';
          break;
      }

      return Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: compact ? 2 : 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: text),
            const SizedBox(width: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
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

  void _showMobilePartyLedgerFilterSheet(
    BuildContext context,
    List<ChallanEntry> allPartyChallans,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollController) {
            return StatefulBuilder(
              builder: (ctx, setSheetState) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.tune_rounded, color: AppColors.primary, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'Filter & Sort Challans',
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _paymentOptionFilter = null;
                                _statusFilter = null;
                                _dateFilter = 'all';
                                _selectedMonth = null;
                                _selectedYear = null;
                                _customStartDate = null;
                                _customEndDate = null;
                                _sortField = ChallanSortField.date;
                                _sortAscending = false;
                              });
                              setSheetState(() {});
                            },
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Reset All'),
                          ),
                        ],
                      ),
                      const Divider(),
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          children: [
                            const SizedBox(height: 8),
                            const Text(
                              'Payment Mode',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<PaymentOption?>(
                              initialValue: _paymentOptionFilter,
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
                              onChanged: (val) {
                                setState(() => _paymentOptionFilter = val);
                                setSheetState(() {});
                              },
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Status',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildFilterChip('all', 'All', _statusFilter == null || _statusFilter == 'all', () {
                                  setState(() => _statusFilter = 'all');
                                  setSheetState(() {});
                                }),
                                _buildFilterChip('paid', 'Paid', _statusFilter == 'paid', () {
                                  setState(() => _statusFilter = 'paid');
                                  setSheetState(() {});
                                }, color: AppColors.successText),
                                _buildFilterChip('unpaid', 'Unpaid Warning', _statusFilter == 'unpaid', () {
                                  setState(() => _statusFilter = 'unpaid');
                                  setSheetState(() {});
                                }, color: AppColors.warningText),
                                if (allPartyChallans.any((c) => !c.isFullyPaid && c.isPaymentOverdue))
                                  _buildFilterChip(
                                    'overdue',
                                    'Overdue (${allPartyChallans.where((c) => !c.isFullyPaid && c.isPaymentOverdue).length})',
                                    _statusFilter == 'overdue',
                                    () {
                                      setState(() => _statusFilter = 'overdue');
                                      setSheetState(() {});
                                    },
                                    color: const Color(0xFFDC2626),
                                  ),
                                _buildFilterChip('bounced', 'Bounced', _statusFilter == 'bounced', () {
                                  setState(() => _statusFilter = 'bounced');
                                  setSheetState(() {});
                                }, color: AppColors.warningText),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Period & Date Range',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildFilterChip('all', 'All Time', _dateFilter == 'all', () {
                                  setState(() => _dateFilter = 'all');
                                  setSheetState(() {});
                                }),
                                _buildFilterChip('today', 'Today', _dateFilter == 'today', () {
                                  setState(() => _dateFilter = 'today');
                                  setSheetState(() {});
                                }),
                                _buildFilterChip('week', 'Last 7 Days', _dateFilter == 'week', () {
                                  setState(() => _dateFilter = 'week');
                                  setSheetState(() {});
                                }),
                                _buildFilterChip('month', 'Last 30 Days', _dateFilter == 'month', () {
                                  setState(() => _dateFilter = 'month');
                                  setSheetState(() {});
                                }),
                                ActionChip(
                                  avatar: Icon(Icons.calendar_month, size: 16, color: AppColors.primary),
                                  label: Text(
                                    _dateFilter == 'monthly_picker' && _selectedMonth != null
                                        ? 'Month: ${DateFormat('MMM yyyy').format(DateTime(_selectedYear!, _selectedMonth!))}'
                                        : 'Pick Month...',
                                  ),
                                  backgroundColor: _dateFilter == 'monthly_picker'
                                      ? AppColors.primary.withValues(alpha: 0.15)
                                      : null,
                                  onPressed: () {
                                    Navigator.of(sheetCtx).pop();
                                    _showMonthPicker(context, allPartyChallans);
                                  },
                                ),
                                ActionChip(
                                  avatar: Icon(
                                    Icons.date_range,
                                    size: 16,
                                    color: _dateFilter == 'custom' ? AppColors.primary : Colors.grey,
                                  ),
                                  label: Text(
                                    _dateFilter == 'custom' && _customStartDate != null && _customEndDate != null
                                        ? 'From: ${DateFormat('dd/MM/yy').format(_customStartDate!)} To: ${DateFormat('dd/MM/yy').format(_customEndDate!)}'
                                        : 'From - To Date...',
                                  ),
                                  backgroundColor: _dateFilter == 'custom'
                                      ? AppColors.primary.withValues(alpha: 0.15)
                                      : null,
                                  onPressed: () {
                                    Navigator.of(sheetCtx).pop();
                                    _showCustomDateRangePicker(context);
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Sort Order',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ActionChip(
                                  avatar: Icon(
                                    _sortField == ChallanSortField.date
                                        ? (_sortAscending ? Icons.arrow_upward : Icons.arrow_downward)
                                        : Icons.calendar_today,
                                    size: 15,
                                    color: _sortField == ChallanSortField.date ? AppColors.primary : Colors.grey,
                                  ),
                                  label: Text(
                                    _sortField == ChallanSortField.date
                                        ? (_sortAscending ? 'Date: Oldest' : 'Date: Newest')
                                        : 'Date Wise',
                                  ),
                                  backgroundColor: _sortField == ChallanSortField.date
                                      ? AppColors.primary.withValues(alpha: 0.15)
                                      : null,
                                  onPressed: () {
                                    setState(() {
                                      if (_sortField == ChallanSortField.date) {
                                        _sortAscending = !_sortAscending;
                                      } else {
                                        _sortField = ChallanSortField.date;
                                        _sortAscending = false;
                                      }
                                    });
                                    setSheetState(() {});
                                  },
                                ),
                                ActionChip(
                                  avatar: Icon(
                                    _sortField == ChallanSortField.challanNo
                                        ? (_sortAscending ? Icons.arrow_upward : Icons.arrow_downward)
                                        : Icons.tag,
                                    size: 15,
                                    color: _sortField == ChallanSortField.challanNo ? AppColors.primary : Colors.grey,
                                  ),
                                  label: Text(
                                    _sortField == ChallanSortField.challanNo
                                        ? (_sortAscending ? 'Challan #: 1-9' : 'Challan #: 9-1')
                                        : 'Challan # Wise',
                                  ),
                                  backgroundColor: _sortField == ChallanSortField.challanNo
                                      ? AppColors.primary.withValues(alpha: 0.15)
                                      : null,
                                  onPressed: () {
                                    setState(() {
                                      if (_sortField == ChallanSortField.challanNo) {
                                        _sortAscending = !_sortAscending;
                                      } else {
                                        _sortField = ChallanSortField.challanNo;
                                        _sortAscending = true;
                                      }
                                    });
                                    setSheetState(() {});
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => Navigator.of(sheetCtx).pop(),
                          child: const Text('Apply Filters', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

