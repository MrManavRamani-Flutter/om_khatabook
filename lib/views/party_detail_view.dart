import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/party.dart';
import '../models/transaction_entry.dart';
import '../providers/khata_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/add_party_dialog.dart';
import '../widgets/add_transaction_dialog.dart';
import '../widgets/transaction_tile.dart';

class PartyDetailView extends StatefulWidget {
  final String partyId;
  final VoidCallback? onBack;

  const PartyDetailView({
    super.key,
    required this.partyId,
    this.onBack,
  });

  @override
  State<PartyDetailView> createState() => _PartyDetailViewState();
}

class _PartyDetailViewState extends State<PartyDetailView> {
  String _searchQuery = '';
  TransactionType? _typeFilter;

  void _addTransaction(Party party, TransactionType type) {
    showDialog(
      context: context,
      builder: (_) => AddTransactionDialog(
        party: party,
        initialType: type,
      ),
    );
  }

  void _copyReminderMessage(Party party, double balance, String groupName) {
    final isLene = balance > 0;
    final message = isLene
        ? 'Namaste ${party.name} ji, this is a friendly reminder from $groupName regarding pending balance of ${Formatters.currency(balance.abs())}. Kindly clear the balance at your earliest convenience. Thank you!'
        : 'Namaste ${party.name} ji, according to $groupName ledger records, we owe you ${Formatters.currency(balance.abs())}. Please verify and let us know. Thank you!';

    Clipboard.setData(ClipboardData(text: message));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Reminder message copied to clipboard!'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primary,
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  void _confirmDeleteParty(Party party) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Party?'),
        content: Text(
          'Are you sure you want to delete ${party.name}? All transaction history for this party will be deleted permanently.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gaveRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<KhataProvider>().deleteParty(party.id);
              if (widget.onBack != null) {
                widget.onBack!();
              } else {
                Navigator.of(context).pop();
              }
            },
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<KhataProvider>();
    final partyIndex =
        provider.parties.indexWhere((p) => p.id == widget.partyId);

    if (partyIndex == -1) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Party not found or was deleted.'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: widget.onBack ?? () => Navigator.of(context).pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    final party = provider.parties[partyIndex];
    final balance = provider.getPartyBalance(party.id);
    final totalGave = provider.getPartyTotalGave(party.id);
    final totalGot = provider.getPartyTotalGot(party.id);
    final allTransactions = provider.getPartyTransactions(party.id);

    final filteredTransactions = allTransactions.where((t) {
      if (_typeFilter != null && t.type != _typeFilter) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchDesc = t.description.toLowerCase().contains(q);
        final matchBill = t.billNumber.toLowerCase().contains(q);
        final matchAmt = t.amount.toString().contains(q);
        if (!matchDesc && !matchBill && !matchAmt) return false;
      }
      return true;
    }).toList();

    final isSettled = balance == 0;
    final isLene = balance > 0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // HEADER / TOP BAR
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
                ),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Back to Parties',
                  onPressed: widget.onBack ?? () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  foregroundColor: AppColors.primary,
                  radius: 20,
                  child: Text(
                    party.name.isNotEmpty ? party.name[0].toUpperCase() : 'P',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              party.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              party.type.displayName,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (party.phone.isNotEmpty || party.address.isNotEmpty)
                        Text(
                          [
                            if (party.phone.isNotEmpty) '📞 ${party.phone}',
                            if (party.address.isNotEmpty) '📍 ${party.address}',
                          ].join('   '),
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
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit Party Details',
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => AddPartyDialog(partyToEdit: party),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.message_outlined),
                  tooltip: 'Copy Reminder Message',
                  onPressed: () => _copyReminderMessage(
                      party, balance, provider.profile.groupName),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.gaveRed),
                  tooltip: 'Delete Party',
                  onPressed: () => _confirmDeleteParty(party),
                ),
              ],
            ),
          ),

          // SUMMARY BANNER & ACTION BUTTONS
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // BALANCE ROW CARD
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isSettled
                          ? Theme.of(context).dividerColor.withValues(alpha: 0.2)
                          : isLene
                              ? AppColors.gaveRed.withValues(alpha: 0.4)
                              : AppColors.gotGreen.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isSettled
                                    ? 'Account Settled (Chukte)'
                                    : isLene
                                        ? 'You Will Get (Lene Hai)'
                                        : 'You Will Give (Dene Hai)',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isSettled
                                      ? Colors.grey
                                      : isLene
                                          ? AppColors.gaveRed
                                          : AppColors.gotGreen,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                Formatters.currency(balance.abs()),
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: isSettled
                                      ? Colors.grey
                                      : isLene
                                          ? AppColors.gaveRed
                                          : AppColors.gotGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          height: 48,
                          width: 1,
                          color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                        ),
                        Expanded(
                          flex: 2,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Total Gave (Diye)',
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.grey),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  Formatters.currency(totalGave),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.gaveRed,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Total Got (Mile)',
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.grey),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  Formatters.currency(totalGot),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.gotGreen,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ACTION BUTTONS (GAVE / GOT)
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gaveRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        icon: const Icon(Icons.arrow_upward),
                        label: const Text(
                          'YOU GAVE ₹ (Maine Diye)',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () =>
                            _addTransaction(party, TransactionType.gave),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gotGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        icon: const Icon(Icons.arrow_downward),
                        label: const Text(
                          'YOU GOT ₹ (Mujhe Mile)',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () =>
                            _addTransaction(party, TransactionType.got),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // SEARCH & FILTER BAR
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search entries by description, bill, or amount...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          isDense: true,
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () =>
                                      setState(() => _searchQuery = ''),
                                )
                              : null,
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SegmentedButton<TransactionType?>(
                      segments: const [
                        ButtonSegment(value: null, label: Text('All')),
                        ButtonSegment(
                            value: TransactionType.gave, label: Text('Gave')),
                        ButtonSegment(
                            value: TransactionType.got, label: Text('Got')),
                      ],
                      selected: {_typeFilter},
                      onSelectionChanged: (val) {
                        setState(() => _typeFilter = val.first);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // TRANSACTIONS LIST
          Expanded(
            child: filteredTransactions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long_outlined,
                            size: 54,
                            color: Theme.of(context)
                                .dividerColor
                                .withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        const Text(
                          'No transactions yet for this party.',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Use "You Gave" or "You Got" above to add the first entry.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.color
                                ?.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: filteredTransactions.length,
                    itemBuilder: (context, index) {
                      final item = filteredTransactions[index];
                      return TransactionTile(
                        transaction: item,
                        party: party,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
