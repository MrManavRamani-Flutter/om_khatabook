import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/challan_entry.dart';
import '../models/party.dart';
import '../providers/challan_provider.dart';
import '../theme/app_theme.dart';

class RecycleBinView extends StatefulWidget {
  const RecycleBinView({super.key});

  @override
  State<RecycleBinView> createState() => _RecycleBinViewState();
}

class _RecycleBinViewState extends State<RecycleBinView> {
  final NumberFormat _currencyFormat =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');
  final DateFormat _dateTimeFormat = DateFormat('dd MMM yyyy, hh:mm a');

  void _confirmEmptyBin() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warningText),
            SizedBox(width: 8),
            Text('Empty Recycle Bin?'),
          ],
        ),
        content: const Text(
          'Are you sure you want to permanently delete all items in the Recycle Bin?\n\n'
          'This action is permanent and IRREVERSIBLE. Once deleted, this data cannot be recovered from any backup or archive.',
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
            onPressed: () async {
              Navigator.of(ctx).pop();
              await context.read<ChallanProvider>().emptyRecycleBin();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Recycle Bin emptied permanently.'),
                    backgroundColor: AppColors.primaryDark,
                  ),
                );
              }
            },
            child: const Text('Empty Permanently'),
          ),
        ],
      ),
    );
  }

  void _confirmPermanentDeleteChallan(ChallanEntry challan) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Challan Permanently?'),
        content: Text(
          'Are you sure you want to permanently erase Challan #${challan.challanNo} (${challan.partyName})?\n\n'
          'This record will be destroyed and cannot be recovered.',
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
            onPressed: () async {
              Navigator.of(ctx).pop();
              await context
                  .read<ChallanProvider>()
                  .deletePermanentlyChallan(challan.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Challan #${challan.challanNo} permanently deleted.'),
                    backgroundColor: Colors.red.shade800,
                  ),
                );
              }
            },
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }

  void _confirmPermanentDeleteParty(Party party) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Party Permanently?'),
        content: Text(
          'Are you sure you want to permanently erase "${party.name}"?\n\n'
          'This party record will be destroyed and cannot be recovered.',
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
            onPressed: () async {
              Navigator.of(ctx).pop();
              await context
                  .read<ChallanProvider>()
                  .deletePermanentlyParty(party.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Party "${party.name}" permanently deleted.'),
                    backgroundColor: Colors.red.shade800,
                  ),
                );
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
    final provider = context.watch<ChallanProvider>();
    final deletedChallans = provider.deletedChallans;
    final deletedParties = provider.deletedParties;
    final totalDeleted = deletedChallans.length + deletedParties.length;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Recycle Bin',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              Text(
                'Safely recover deleted items or permanently purge them',
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
            if (totalDeleted > 0)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.warningText,
                    side: const BorderSide(color: AppColors.warningText),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  icon: const Icon(Icons.delete_forever, size: 18),
                  label: const Text(
                    'Empty Recycle Bin',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: _confirmEmptyBin,
                ),
              ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.receipt_long, size: 18),
                    const SizedBox(width: 8),
                    Text('Deleted Challans (${deletedChallans.length})'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.people, size: 18),
                    const SizedBox(width: 8),
                    Text('Deleted Parties (${deletedParties.length})'),
                  ],
                ),
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // TAB 1: DELETED CHALLANS
            _buildDeletedChallansTab(context, provider, deletedChallans),

            // TAB 2: DELETED PARTIES
            _buildDeletedPartiesTab(context, provider, deletedParties),
          ],
        ),
      ),
    );
  }

  Widget _buildDeletedChallansTab(
    BuildContext context,
    ChallanProvider provider,
    List<ChallanEntry> challans,
  ) {
    if (challans.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.delete_outline,
              size: 64,
              color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'Recycle Bin is Empty',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'No deleted challan records found. Deleted entries will appear here.',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          color: Theme.of(context).cardColor,
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${challans.length} deleted challan(s). Restoring will return the entry to the main ledger.',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: challans.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final c = challans[index];
              final deletedTime = c.deletedAt != null
                  ? _dateTimeFormat.format(c.deletedAt!)
                  : 'Recently';

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color:
                        Theme.of(context).dividerColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.receipt_outlined,
                            color: Colors.grey, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Challan #${c.challanNo}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Deleted',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Party: ${c.partyName} • Date: ${_dateFormat.format(c.date)}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context).textTheme.bodySmall?.color,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Amount: ${_currencyFormat.format(c.finalAmount)} • Deleted: $deletedTime',
                              style: TextStyle(
                                fontSize: 11,
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
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                            ),
                            icon: const Icon(Icons.restore_from_trash, size: 16),
                            label: const Text('Restore'),
                            onPressed: () async {
                              await provider.restoreChallan(c.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Challan #${c.challanNo} restored successfully.'),
                                  ),
                                );
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.delete_forever,
                                color: AppColors.warningText, size: 20),
                            tooltip: 'Delete Permanently',
                            onPressed: () =>
                                _confirmPermanentDeleteChallan(c),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDeletedPartiesTab(
    BuildContext context,
    ChallanProvider provider,
    List<Party> parties,
  ) {
    if (parties.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Deleted Parties',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'All party records are active and present in the Parties Directory.',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          color: Theme.of(context).cardColor,
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${parties.length} deleted party record(s). Restoring will return the party to the active directory.',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: parties.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final p = parties[index];
              final deletedTime = p.deletedAt != null
                  ? _dateTimeFormat.format(p.deletedAt!)
                  : 'Recently';

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color:
                        Theme.of(context).dividerColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.person_off_outlined,
                            color: Colors.grey, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  p.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Deleted',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              [
                                if (p.phone.isNotEmpty) 'Phone: ${p.phone}',
                                if (p.gstNumber.isNotEmpty) 'GST: ${p.gstNumber}',
                                if (p.address.isNotEmpty) 'Address: ${p.address}',
                              ].join(' • '),
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context).textTheme.bodySmall?.color,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Deleted: $deletedTime',
                              style: TextStyle(
                                fontSize: 11,
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
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                            ),
                            icon: const Icon(Icons.restore_from_trash, size: 16),
                            label: const Text('Restore'),
                            onPressed: () async {
                              await provider.restoreParty(p.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content:
                                        Text('${p.name} restored successfully.'),
                                  ),
                                );
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.delete_forever,
                                color: AppColors.warningText, size: 20),
                            tooltip: 'Delete Permanently',
                            onPressed: () =>
                                _confirmPermanentDeleteParty(p),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
