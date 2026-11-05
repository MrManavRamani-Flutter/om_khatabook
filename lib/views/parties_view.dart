import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/party.dart';
import '../models/transaction_entry.dart';
import '../providers/khata_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/add_party_dialog.dart';
import '../widgets/add_transaction_dialog.dart';

class PartiesView extends StatefulWidget {
  final Function(String partyId)? onSelectParty;

  const PartiesView({super.key, this.onSelectParty});

  @override
  State<PartiesView> createState() => _PartiesViewState();
}

class _PartiesViewState extends State<PartiesView> {
  String _searchQuery = '';
  String _filter = 'all'; // all, get, give, settled, customer, supplier, member
  String _sortBy = 'balance_desc'; // balance_desc, name_asc, recent

  void _openAddParty() {
    showDialog(
      context: context,
      builder: (_) => const AddPartyDialog(),
    );
  }

  void _quickAddTransaction(Party party, TransactionType type) {
    showDialog(
      context: context,
      builder: (_) => AddTransactionDialog(
        party: party,
        initialType: type,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<KhataProvider>();
    final allParties = provider.parties;

    // Filter
    final filtered = allParties.where((party) {
      final bal = provider.getPartyBalance(party.id);

      if (_filter == 'get' && bal <= 0) return false;
      if (_filter == 'give' && bal >= 0) return false;
      if (_filter == 'settled' && bal != 0) return false;
      if (_filter == 'customer' && party.type != PartyType.customer) return false;
      if (_filter == 'supplier' && party.type != PartyType.supplier) return false;
      if (_filter == 'member' && party.type != PartyType.member) return false;

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchName = party.name.toLowerCase().contains(q);
        final matchPhone = party.phone.toLowerCase().contains(q);
        final matchAddress = party.address.toLowerCase().contains(q);
        if (!matchName && !matchPhone && !matchAddress) return false;
      }
      return true;
    }).toList();

    // Sort
    filtered.sort((a, b) {
      if (_sortBy == 'name_asc') {
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      } else if (_sortBy == 'recent') {
        final dateA = provider.getPartyLastTransactionDate(a.id) ?? a.createdAt;
        final dateB = provider.getPartyLastTransactionDate(b.id) ?? b.createdAt;
        return dateB.compareTo(dateA);
      } else {
        // balance_desc
        final balA = provider.getPartyBalance(a.id).abs();
        final balB = provider.getPartyBalance(b.id).abs();
        return balB.compareTo(balA);
      }
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TOP HEADER
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Khata Directory (Parties)',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage customers, suppliers, and members ledger accounts',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.color
                            ?.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _openAddParty,
                  icon: const Icon(Icons.person_add),
                  label: const Text('Add New Party'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // SEARCH & CONTROLS ROW
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by party name, phone, or address...',
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
                const SizedBox(width: 14),
                DropdownButtonHideUnderline(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: DropdownButton<String>(
                      value: _sortBy,
                      icon: const Icon(Icons.sort, size: 18),
                      items: const [
                        DropdownMenuItem(
                            value: 'balance_desc',
                            child: Text('Sort: Highest Balance')),
                        DropdownMenuItem(
                            value: 'name_asc', child: Text('Sort: Name (A-Z)')),
                        DropdownMenuItem(
                            value: 'recent',
                            child: Text('Sort: Recently Active')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _sortBy = val);
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // FILTER CHIPS
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('all', 'All (${allParties.length})'),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'get',
                    'You\'ll Get (${allParties.where((p) => provider.getPartyBalance(p.id) > 0).length})',
                    color: AppColors.gaveRed,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'give',
                    'You\'ll Give (${allParties.where((p) => provider.getPartyBalance(p.id) < 0).length})',
                    color: AppColors.gotGreen,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip('settled', 'Settled'),
                  const SizedBox(width: 8),
                  _buildFilterChip('customer', 'Customers'),
                  const SizedBox(width: 8),
                  _buildFilterChip('supplier', 'Suppliers'),
                  const SizedBox(width: 8),
                  _buildFilterChip('member', 'Members'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // PARTIES LIST
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person_search_outlined,
                            size: 60,
                            color: Theme.of(context)
                                .dividerColor
                                .withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No parties match the selected filter',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _openAddParty,
                            icon: const Icon(Icons.add),
                            label: const Text('Add New Party'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final party = filtered[index];
                        final balance = provider.getPartyBalance(party.id);
                        final lastDate =
                            provider.getPartyLastTransactionDate(party.id);
                        final isSettled = balance == 0;
                        final isLene = balance > 0;

                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(context)
                                  .dividerColor
                                  .withValues(alpha: 0.2),
                            ),
                          ),
                          child: InkWell(
                            onTap: () {
                              if (widget.onSelectParty != null) {
                                widget.onSelectParty!(party.id);
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  // INITIAL AVATAR
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: isSettled
                                        ? Colors.grey.withValues(alpha: 0.15)
                                        : isLene
                                            ? AppColors.gaveRedLight
                                            : AppColors.gotGreenLight,
                                    foregroundColor: isSettled
                                        ? Colors.grey
                                        : isLene
                                            ? AppColors.gaveRed
                                            : AppColors.gotGreen,
                                    child: Text(
                                      party.name.isNotEmpty
                                          ? party.name[0].toUpperCase()
                                          : 'P',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),

                                  // PARTY INFO
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                party.name,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary
                                                    .withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                party.type.displayName,
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: AppColors.primary,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            if (party.phone.isNotEmpty)
                                              Text(
                                                party.phone,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.color,
                                                ),
                                              ),
                                            if (party.phone.isNotEmpty &&
                                                party.address.isNotEmpty)
                                              const Text(' • '),
                                            if (party.address.isNotEmpty)
                                              Text(
                                                party.address,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.color
                                                      ?.withValues(alpha: 0.7),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          lastDate != null
                                              ? 'Last entry: ${Formatters.date(lastDate)}'
                                              : 'Created: ${Formatters.date(party.createdAt)}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.color
                                                ?.withValues(alpha: 0.6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // BALANCE STATUS
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        isSettled
                                            ? 'Settled (Chukte)'
                                            : isLene
                                                ? 'You\'ll Get (Lene)'
                                                : 'You\'ll Give (Dene)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: isSettled
                                              ? Colors.grey
                                              : isLene
                                                  ? AppColors.gaveRed
                                                  : AppColors.gotGreen,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        Formatters.currency(balance.abs()),
                                        style: TextStyle(
                                          fontSize: 18,
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
                                  const SizedBox(width: 16),

                                  // QUICK ACTION BUTTONS
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton.filledTonal(
                                        tooltip: 'Quick Gave (Diye)',
                                        icon: const Icon(Icons.arrow_upward,
                                            size: 18, color: AppColors.gaveRed),
                                        onPressed: () => _quickAddTransaction(
                                            party, TransactionType.gave),
                                      ),
                                      const SizedBox(width: 6),
                                      IconButton.filledTonal(
                                        tooltip: 'Quick Got (Mile)',
                                        icon: const Icon(Icons.arrow_downward,
                                            size: 18, color: AppColors.gotGreen),
                                        onPressed: () => _quickAddTransaction(
                                            party, TransactionType.got),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.chevron_right,
                                          color: Colors.grey),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, {Color? color}) {
    final isSelected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: (color ?? AppColors.primary).withValues(alpha: 0.2),
      labelStyle: TextStyle(
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? (color ?? AppColors.primary) : null,
      ),
      onSelected: (_) => setState(() => _filter = value),
    );
  }
}
