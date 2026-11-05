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
            const SizedBox(height: 16),

            // LIST OF PARTIES
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
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final party = filtered[index];
                  final partyChallans =
                      challans.where((c) => c.partyId == party.id).toList();
                  final totalBilled = partyChallans.fold(
                      0.0, (sum, c) => sum + c.finalAmount);
                  final totalDue = partyChallans.fold(
                      0.0,
                      (sum, c) =>
                          sum +
                          (c.paymentOption == PaymentOption.cash
                              ? c.remainingAmount
                              : (c.chequeDetails?.status != ChequeStatus.cleared
                                  ? c.finalAmount
                                  : 0.0)));

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
                              builder: (_) =>
                                  PartyLedgerDetailView(partyId: party.id),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor:
                                    AppColors.primary.withValues(alpha: 0.12),
                                foregroundColor: AppColors.primary,
                                child: Text(
                                  party.name.isNotEmpty
                                      ? party.name[0].toUpperCase()
                                      : 'P',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 18),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      party.name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        if (party.phone.isNotEmpty)
                                          Text(
                                            '📞 ${party.phone}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.color,
                                            ),
                                          ),
                                        if (party.address.isNotEmpty)
                                          Text(
                                            '📍 ${party.address}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.color
                                                  ?.withValues(alpha: 0.7),
                                            ),
                                          ),
                                        if (party.gstNumber.isNotEmpty)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary
                                                  .withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(4),
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
                                      color: totalDue > 0
                                          ? AppColors.warningText
                                          : Colors.grey,
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
                                icon: const Icon(Icons.delete_outline,
                                    size: 18, color: AppColors.warningText),
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
              ),
          ],
        ),
      ),
    );
  }
}
