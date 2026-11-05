import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/challan_entry.dart';
import '../models/party.dart';
import '../providers/challan_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/add_edit_challan_dialog.dart';
import '../widgets/add_edit_party_dialog.dart';
import '../widgets/export_report_dialog.dart';
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
  String _dateFilter = 'all'; // 'all', 'today', 'week', 'month', 'monthly_picker'
  int? _selectedMonth;
  int? _selectedYear;
  bool _sortAscending = false;

  void _openAddChallan(BuildContext context, Party party) {
    showDialog(
      context: context,
      builder: (_) => AddEditChallanDialog(initialParty: party),
    );
  }

  void _openEditChallan(BuildContext context, ChallanEntry entry) {
    showDialog(
      context: context,
      builder: (_) => AddEditChallanDialog(entryToEdit: entry),
    );
  }

  void _openViewChallan(BuildContext context, ChallanEntry entry) {
    showDialog(
      context: context,
      builder: (_) => ViewChallanDialog(entry: entry),
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
        title: const Row(
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

  void _confirmDeleteChallan(BuildContext context, ChallanEntry entry) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Move to Recycle Bin?'),
        content: Text(
          'Challan #${entry.challanNo} will be moved to the Recycle Bin. You can restore it anytime or delete it permanently from the bin.',
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
      }

      return true;
    }).toList();

    // 5. Date Sort
    filtered.sort((a, b) =>
        _sortAscending ? a.date.compareTo(b.date) : b.date.compareTo(a.date));

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
              party.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'Party Ledger • ${allPartyChallans.length} Total Entries Recorded',
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
          OutlinedButton.icon(
            onPressed: () => _openExportDialog(context),
            icon: const Icon(Icons.picture_as_pdf, color: AppColors.primary, size: 18),
            label: const Text('Export Party Ledger'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _openAddChallan(context, party),
            icon: const Icon(Icons.add_circle, size: 18),
            label: const Text('Add Challan'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
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
                                party.name,
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
                                    style: const TextStyle(
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

            // PARTY-SPECIFIC FILTER TOOLBAR (ZERO HORIZONTAL SCROLL)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // ROW 1: SEARCH & PAYMENT OPTION
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
                              _sortAscending = false;
                            });
                          },
                        ),
                      ],
                    ),
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
                          avatar: const Icon(Icons.calendar_month, size: 16, color: AppColors.primary),
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

                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Text('•', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                        ),

                        ActionChip(
                          avatar: Icon(
                            _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          label: Text(
                            _sortAscending ? 'Date: Oldest First ↑' : 'Date: Newest First ↓',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                          onPressed: () {
                            setState(() => _sortAscending = !_sortAscending);
                          },
                        ),
                      ],
                    ),
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
                  const Icon(Icons.filter_list, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Showing ${filtered.length} of ${allPartyChallans.length} challans for "${party.name}"',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // LIST OF CHALLANS FOR THIS PARTY ONLY
            if (filtered.isEmpty)
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
                        Text(
                          allPartyChallans.isEmpty
                              ? 'No challan records found for ${party.name}'
                              : 'No challans match the active filters',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          allPartyChallans.isEmpty
                              ? 'Click "Add Challan" to create the first delivery challan for this party.'
                              : 'Adjust your search or click the reset filter icon above.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _openAddChallan(context, party),
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
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final item = filtered[index];
                  return _buildChallanCard(context, item);
                },
              ),
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
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ROW 1: CHALLAN NO, DATE, STATUS BADGE, ACTIONS
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
                    onPressed: () => _openViewChallan(context, item),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    tooltip: 'Edit Entry',
                    onPressed: () => _openEditChallan(context, item),
                  ),
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
}

