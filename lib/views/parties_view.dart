import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/challan_entry.dart';
import '../models/party.dart';
import '../providers/challan_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/add_edit_party_dialog.dart';
import 'party_ledger_detail_view.dart';

class PartiesView extends StatefulWidget {
  const PartiesView({super.key});

  @override
  State<PartiesView> createState() => _PartiesViewState();
}

class _PartiesViewState extends State<PartiesView> {
  String _searchQuery = '';

  void _openAddParty(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const AddEditPartyDialog(),
    );
  }

  void _openEditParty(BuildContext context, Party party) {
    showDialog(
      context: context,
      builder: (_) => AddEditPartyDialog(partyToEdit: party),
    );
  }

  void _confirmDelete(BuildContext context, Party party) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Move Party to Recycle Bin?'),
        content: Text(
          'Are you sure you want to move ${party.name} to the Recycle Bin? Existing challans linked to this party will remain preserved, and you can restore or permanently delete this party anytime from the Recycle Bin.',
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
              context.read<ChallanProvider>().moveToBinParty(party.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${party.name} moved to Recycle Bin'),
                  action: SnackBarAction(
                    label: 'Undo',
                    textColor: Colors.amberAccent,
                    onPressed: () {
                      context.read<ChallanProvider>().restoreParty(party.id);
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
    final allParties = provider.parties;
    final challans = provider.challans;

    final filtered = allParties.where((p) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchName = p.name.toLowerCase().contains(q);
        final matchPhone = p.phone.toLowerCase().contains(q);
        final matchAddress = p.address.toLowerCase().contains(q);
        final matchGst = p.gstNumber.toLowerCase().contains(q);
        if (!matchName && !matchPhone && !matchAddress && !matchGst) return false;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Parties Directory',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pre-add and manage registered parties, contact info, and GST numbers',
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
                  onPressed: () => _openAddParty(context),
                  icon: const Icon(Icons.person_add, size: 20),
                  label: const Text('Add New Party'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // SEARCH BAR
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search party by name, phone, city, or GSTIN...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ACTION BAR: SHOWING COUNT & VIEW SWITCHER
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.people,
                    size: 16,
                    color: AppColors.primary.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _searchQuery.isNotEmpty
                          ? 'Search results for "$_searchQuery" (${filtered.length} parties)'
                          : 'Showing: All Registered Parties (${filtered.length} total)',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildViewModeSwitcher(context, provider),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // LIST OF PARTIES (TABLE / COMPACT / CARDS)
            if (filtered.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 56,
                          color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No parties found',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Click "Add New Party" above to pre-register your business parties.',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (provider.partyViewMode == LedgerViewMode.table)
              _buildExcelTableView(context, filtered, challans, provider)
            else if (provider.partyViewMode == LedgerViewMode.compact)
              _buildCompactListView(context, filtered, challans, provider)
            else
              _buildCardsView(context, filtered, challans, provider),
          ],
        ),
      ),
    );
  }

  // --- WINDOWS EXPLORER-STYLE VIEW MODE SWITCHER ---
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
            current: provider.partyViewMode,
            icon: Icons.table_chart_outlined,
            label: 'Excel Table',
            tooltip: 'Excel Grid View (Dense rows, view all parties at once)',
            onTap: () => provider.setPartyViewMode(LedgerViewMode.table),
          ),
          _buildViewModeButton(
            context,
            mode: LedgerViewMode.compact,
            current: provider.partyViewMode,
            icon: Icons.view_list_rounded,
            label: 'Compact',
            tooltip: 'Compact List View',
            onTap: () => provider.setPartyViewMode(LedgerViewMode.compact),
          ),
          _buildViewModeButton(
            context,
            mode: LedgerViewMode.cards,
            current: provider.partyViewMode,
            icon: Icons.view_agenda_outlined,
            label: 'Cards',
            tooltip: 'Large Cards View',
            onTap: () => provider.setPartyViewMode(LedgerViewMode.cards),
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
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected ? primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected
                    ? Colors.white
                    : Theme.of(context).textTheme.bodySmall?.color,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 1. EXCEL TABLE DENSE GRID VIEW ---
  Widget _buildExcelTableView(
    BuildContext context,
    List<Party> parties,
    List<ChallanEntry> challans,
    ChallanProvider provider,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalBilledGrand = parties.fold(0.0, (sum, p) {
      final pChallans = challans.where((c) => c.partyId == p.id);
      return sum + pChallans.fold(0.0, (s, c) => s + c.finalAmount);
    });
    final totalDueGrand = parties.fold(0.0, (sum, p) {
      final pChallans = challans.where((c) => c.partyId == p.id);
      return sum +
          pChallans.fold(
              0.0,
              (s, c) =>
                  s +
                  (c.paymentOption == PaymentOption.cash
                      ? c.remainingAmount
                      : (c.chequeDetails?.status != ChequeStatus.cleared
                          ? c.finalAmount
                          : 0.0)));
    });

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.25),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // TABLE HEADER
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 44,
                  child: Center(
                    child: Text(
                      '#',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    'PARTY NAME',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'CONTACT / PHONE',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'CITY / ADDRESS',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'GSTIN',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'TOTAL BILLED',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'BALANCE DUE',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                  ),
                ),
                SizedBox(
                  width: 75,
                  child: Center(
                    child: Text(
                      'CHALLANS',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                  ),
                ),
                SizedBox(
                  width: 85,
                  child: Center(
                    child: Text(
                      'ACTIONS',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // DATA ROWS
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: parties.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              thickness: 1,
              color: Theme.of(context).dividerColor.withValues(alpha: 0.12),
            ),
            itemBuilder: (context, index) {
              final party = parties[index];
              final partyChallans = challans.where((c) => c.partyId == party.id).toList();
              final totalBilled = partyChallans.fold(0.0, (sum, c) => sum + c.finalAmount);
              final totalDue = partyChallans.fold(
                0.0,
                (sum, c) =>
                    sum +
                    (c.paymentOption == PaymentOption.cash
                        ? c.remainingAmount
                        : (c.chequeDetails?.status != ChequeStatus.cleared ? c.finalAmount : 0.0)),
              );

              final hasDue = totalDue > 0;
              final isAlternate = index % 2 == 1;

              Color rowBg;
              if (hasDue) {
                rowBg = isDark ? const Color(0xFF2A1705) : const Color(0xFFFFFBEB);
              } else if (isAlternate) {
                rowBg = isDark
                    ? Colors.white.withValues(alpha: 0.02)
                    : const Color(0xFFF8FAFC);
              } else {
                rowBg = Colors.transparent;
              }

              return Material(
                color: rowBg,
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PartyLedgerDetailView(partyId: party.id),
                      ),
                    );
                  },
                  hoverColor: AppColors.primary.withValues(alpha: 0.07),
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        // #
                        SizedBox(
                          width: 44,
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                            ),
                          ),
                        ),
                        // PARTY NAME
                        Expanded(
                          flex: 4,
                          child: Text(
                            provider.formatCasedText(party.name),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        // CONTACT / PHONE
                        Expanded(
                          flex: 3,
                          child: Text(
                            party.phone.isNotEmpty ? party.phone : '-',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: party.phone.isNotEmpty
                                  ? Theme.of(context).textTheme.bodyMedium?.color
                                  : Colors.grey,
                            ),
                          ),
                        ),
                        // CITY / ADDRESS
                        Expanded(
                          flex: 3,
                          child: Text(
                            party.address.isNotEmpty ? provider.formatCasedText(party.address) : '-',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: party.address.isNotEmpty
                                  ? Theme.of(context).textTheme.bodyMedium?.color
                                  : Colors.grey,
                            ),
                          ),
                        ),
                        // GSTIN
                        Expanded(
                          flex: 3,
                          child: Text(
                            party.gstNumber.isNotEmpty ? party.gstNumber : '-',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: party.gstNumber.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
                              color: party.gstNumber.isNotEmpty ? AppColors.primary : Colors.grey,
                            ),
                          ),
                        ),
                        // TOTAL BILLED
                        Expanded(
                          flex: 3,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              totalBilled > 0 ? Formatters.currency(totalBilled) : '-',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        // BALANCE DUE
                        Expanded(
                          flex: 3,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              totalDue > 0 ? Formatters.currency(totalDue) : '-',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: totalDue > 0 ? AppColors.warningText : Colors.grey,
                              ),
                            ),
                          ),
                        ),
                        // CHALLANS
                        SizedBox(
                          width: 75,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: partyChallans.isNotEmpty
                                    ? AppColors.primary.withValues(alpha: 0.12)
                                    : Theme.of(context).dividerColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${partyChallans.length}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: partyChallans.isNotEmpty ? AppColors.primary : Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // ACTIONS
                        SizedBox(
                          width: 85,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildActionIcon(
                                icon: Icons.visibility_outlined,
                                tooltip: 'Open Party Ledger',
                                color: Theme.of(context).textTheme.bodySmall?.color,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => PartyLedgerDetailView(partyId: party.id),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 2),
                              _buildActionIcon(
                                icon: Icons.edit_outlined,
                                tooltip: 'Edit Party Details',
                                color: AppColors.primary,
                                onTap: () => _openEditParty(context, party),
                              ),
                              const SizedBox(width: 2),
                              _buildActionIcon(
                                icon: Icons.delete_outline,
                                tooltip: 'Move to Bin',
                                color: AppColors.warningText,
                                onTap: () => _confirmDelete(context, party),
                              ),
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
                  width: 44,
                  child: Center(
                    child: Text(
                      'TOTAL',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 13,
                  child: Text(
                    '${parties.length} Registered Parties',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      Formatters.currency(totalBilledGrand),
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      Formatters.currency(totalDueGrand),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: totalDueGrand > 0 ? AppColors.warningText : AppColors.successText,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 160), // spacing for Challans & Actions
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 2. COMPACT LIST VIEW ---
  Widget _buildCompactListView(
    BuildContext context,
    List<Party> parties,
    List<ChallanEntry> challans,
    ChallanProvider provider,
  ) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: parties.length,
      separatorBuilder: (context, index) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final party = parties[index];
        final partyChallans = challans.where((c) => c.partyId == party.id).toList();
        final totalBilled = partyChallans.fold(0.0, (sum, c) => sum + c.finalAmount);
        final totalDue = partyChallans.fold(
          0.0,
          (sum, c) =>
              sum +
              (c.paymentOption == PaymentOption.cash
                  ? c.remainingAmount
                  : (c.chequeDetails?.status != ChequeStatus.cleared ? c.finalAmount : 0.0)),
        );

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: totalDue > 0
                  ? AppColors.warningBorder
                  : Theme.of(context).dividerColor.withValues(alpha: 0.2),
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PartyLedgerDetailView(partyId: party.id),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    foregroundColor: AppColors.primary,
                    child: Text(
                      party.name.isNotEmpty ? party.name[0].toUpperCase() : 'P',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          provider.formatCasedText(party.name),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          children: [
                            if (party.phone.isNotEmpty) ...[
                              Text('📞 ${party.phone}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              const SizedBox(width: 8),
                            ],
                            if (party.address.isNotEmpty) ...[
                              Text('📍 ${provider.formatCasedText(party.address)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              const SizedBox(width: 8),
                            ],
                            if (party.gstNumber.isNotEmpty)
                              Text('GST: ${party.gstNumber}', style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        Formatters.currency(totalBilled),
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        totalDue > 0 ? 'Due: ${Formatters.currency(totalDue)}' : '${partyChallans.length} Challans • Settled',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: totalDue > 0 ? AppColors.warningText : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  _buildActionIcon(
                    icon: Icons.edit_outlined,
                    tooltip: 'Edit Party',
                    color: AppColors.primary,
                    onTap: () => _openEditParty(context, party),
                  ),
                  _buildActionIcon(
                    icon: Icons.delete_outline,
                    tooltip: 'Move to Bin',
                    color: AppColors.warningText,
                    onTap: () => _confirmDelete(context, party),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --- 3. CARDS VIEW (LARGE CARDS) ---
  Widget _buildCardsView(
    BuildContext context,
    List<Party> parties,
    List<ChallanEntry> challans,
    ChallanProvider provider,
  ) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: parties.length,
      itemBuilder: (context, index) {
        final party = parties[index];
        final partyChallans = challans.where((c) => c.partyId == party.id).toList();
        final totalBilled = partyChallans.fold(0.0, (sum, c) => sum + c.finalAmount);
        final totalDue = partyChallans.fold(
          0.0,
          (sum, c) =>
              sum +
              (c.paymentOption == PaymentOption.cash
                  ? c.remainingAmount
                  : (c.chequeDetails?.status != ChequeStatus.cleared ? c.finalAmount : 0.0)),
        );

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PartyLedgerDetailView(partyId: party.id),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                      foregroundColor: AppColors.primary,
                      child: Text(
                        party.name.isNotEmpty ? party.name[0].toUpperCase() : 'P',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            provider.formatCasedText(party.name),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (party.phone.isNotEmpty)
                                Text(
                                  '📞 ${party.phone}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).textTheme.bodySmall?.color,
                                  ),
                                ),
                              if (party.address.isNotEmpty)
                                Text(
                                  '📍 ${provider.formatCasedText(party.address)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                                  ),
                                ),
                              if (party.gstNumber.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
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
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          Formatters.currency(totalBilled),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          totalDue > 0
                              ? '${partyChallans.length} Challans • Due: ${Formatters.currency(totalDue)}'
                              : '${partyChallans.length} Challans • Settled',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: totalDue > 0 ? AppColors.warningText : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: 'Edit Party',
                      onPressed: () => _openEditParty(context, party),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.warningText),
                      tooltip: 'Delete Party',
                      onPressed: () => _confirmDelete(context, party),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: AppColors.primary,
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
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}
