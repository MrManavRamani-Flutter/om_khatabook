import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/party.dart';
import '../models/transaction_entry.dart';
import '../providers/khata_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/add_party_dialog.dart';
import '../widgets/add_transaction_dialog.dart';
import '../widgets/summary_card.dart';

class DashboardView extends StatelessWidget {
  final Function(String partyId)? onSelectParty;
  final VoidCallback? onNavigateToParties;
  final VoidCallback? onNavigateToDayBook;

  const DashboardView({
    super.key,
    this.onSelectParty,
    this.onNavigateToParties,
    this.onNavigateToDayBook,
  });

  void _showAddParty(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const AddPartyDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<KhataProvider>();
    final profile = provider.profile;
    final totalReceivable = provider.totalReceivable;
    final totalPayable = provider.totalPayable;
    final netBalance = provider.netBalance;
    final parties = provider.parties;
    final allTransactions = provider.transactions.toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    // Top pending parties (those who owe the most)
    final topReceivableParties = parties
        .where((p) => provider.getPartyBalance(p.id) > 0)
        .toList()
      ..sort((a, b) => provider
          .getPartyBalance(b.id)
          .compareTo(provider.getPartyBalance(a.id)));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // WELCOME BANNER
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primaryDark, AppColors.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                '🕉️ Om Mavtar Group',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              Formatters.date(DateTime.now()),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          profile.groupName,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Desktop Digital Ledger (Khata Book) • Fast, Secure & Offline-Ready',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showAddParty(context),
                    icon: const Icon(Icons.add_circle, color: AppColors.primary),
                    label: const Text(
                      'Add New Party',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 3 SUMMARY CARDS
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 800;
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: isWide ? 3 : 1,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: isWide ? 2.3 : 3.0,
                  children: [
                    SummaryCard(
                      title: 'YOU\'LL GET (LENE HAI)',
                      subtitle: 'Pending from ${parties.where((p) => provider.getPartyBalance(p.id) > 0).length} parties',
                      amount: Formatters.currency(totalReceivable),
                      icon: Icons.arrow_upward_rounded,
                      color: AppColors.gaveRed,
                      backgroundColor: AppColors.gaveRedLight,
                      onTap: onNavigateToParties,
                    ),
                    SummaryCard(
                      title: 'YOU\'LL GIVE (DENE HAI)',
                      subtitle: 'Payable to ${parties.where((p) => provider.getPartyBalance(p.id) < 0).length} parties',
                      amount: Formatters.currency(totalPayable),
                      icon: Icons.arrow_downward_rounded,
                      color: AppColors.gotGreen,
                      backgroundColor: AppColors.gotGreenLight,
                      onTap: onNavigateToParties,
                    ),
                    SummaryCard(
                      title: 'NET LEDGER BALANCE',
                      subtitle: '${parties.length} Total Registered Parties',
                      amount: Formatters.currency(netBalance),
                      icon: Icons.account_balance_wallet_rounded,
                      color: netBalance >= 0
                          ? AppColors.primary
                          : AppColors.gaveRed,
                      backgroundColor:
                          AppColors.primary.withValues(alpha: 0.15),
                      onTap: onNavigateToParties,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 28),

            // 2 COLUMNS: TOP PENDING & RECENT TRANSACTIONS
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 900;
                final leftWidget = _buildTopReceivables(
                    context, provider, topReceivableParties);
                final rightWidget =
                    _buildRecentTransactions(context, provider, allTransactions);

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: leftWidget),
                      const SizedBox(width: 20),
                      Expanded(flex: 6, child: rightWidget),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      leftWidget,
                      const SizedBox(height: 20),
                      rightWidget,
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopReceivables(
    BuildContext context,
    KhataProvider provider,
    List<Party> topParties,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Highest Pending (Lene Hai)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: onNavigateToParties,
                  child: const Text('View All Parties →'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (topParties.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(
                  child: Text(
                    'No pending receivables! All accounts settled.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ...topParties.take(5).map((party) {
                final bal = provider.getPartyBalance(party.id);
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Theme.of(context)
                          .dividerColor
                          .withValues(alpha: 0.15),
                    ),
                  ),
                  child: InkWell(
                    onTap: () {
                      if (onSelectParty != null) onSelectParty!(party.id);
                    },
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.gaveRedLight,
                          foregroundColor: AppColors.gaveRed,
                          child: Text(
                            party.name.isNotEmpty
                                ? party.name[0].toUpperCase()
                                : 'P',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                party.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (party.phone.isNotEmpty)
                                Text(
                                  party.phone,
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              Formatters.currency(bal),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.gaveRed,
                              ),
                            ),
                            const Text(
                              'Pending',
                              style: TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.arrow_downward,
                              size: 18, color: AppColors.gotGreen),
                          tooltip: 'Record Payment (Got ₹)',
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => AddTransactionDialog(
                                party: party,
                                initialType: TransactionType.got,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTransactions(
    BuildContext context,
    KhataProvider provider,
    List<TransactionEntry> transactions,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Transactions',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Total: ${transactions.length}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (transactions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(
                  child: Text(
                    'No transactions recorded yet.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ...transactions.take(6).map((t) {
                final party = provider.parties.firstWhere(
                  (p) => p.id == t.partyId,
                  orElse: () => Party(
                      id: '',
                      name: 'Unknown Party',
                      phone: '',
                      createdAt: DateTime.now()),
                );
                final isGave = t.type == TransactionType.gave;
                final color = isGave ? AppColors.gaveRed : AppColors.gotGreen;

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Theme.of(context)
                          .dividerColor
                          .withValues(alpha: 0.15),
                    ),
                  ),
                  child: InkWell(
                    onTap: () {
                      if (onSelectParty != null && party.id.isNotEmpty) {
                        onSelectParty!(party.id);
                      }
                    },
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isGave
                                ? AppColors.gaveRedLight
                                : AppColors.gotGreenLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            isGave
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            color: color,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                party.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Row(
                                children: [
                                  Text(
                                    Formatters.date(t.date),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.color
                                          ?.withValues(alpha: 0.6),
                                    ),
                                  ),
                                  if (t.description.isNotEmpty) ...[
                                    const Text(' • '),
                                    Flexible(
                                      child: Text(
                                        t.description,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.color
                                              ?.withValues(alpha: 0.7),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        Text(
                          (isGave ? '-' : '+') + Formatters.currency(t.amount),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
