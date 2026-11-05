import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/party.dart';
import '../models/transaction_entry.dart';
import '../providers/khata_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'add_transaction_dialog.dart';

class TransactionTile extends StatelessWidget {
  final TransactionEntry transaction;
  final Party party;

  const TransactionTile({
    super.key,
    required this.transaction,
    required this.party,
  });

  void _showDeleteConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Entry?'),
        content: Text(
          'Are you sure you want to delete this ${transaction.type.label} of ${Formatters.currency(transaction.amount)}?',
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
              context.read<KhataProvider>().deleteTransaction(transaction.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _editTransaction(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AddTransactionDialog(
        party: party,
        transactionToEdit: transaction,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isGave = transaction.type == TransactionType.gave;
    final color = isGave ? AppColors.gaveRed : AppColors.gotGreen;
    final bgColor = isGave ? AppColors.gaveRedLight : AppColors.gotGreenLight;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // BADGE ICON
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isGave ? Icons.arrow_upward : Icons.arrow_downward,
                color: color,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),

            // DETAILS
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        isGave ? 'YOU GAVE (Diye)' : 'YOU GOT (Mile)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .dividerColor
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          transaction.paymentMode.displayName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                      ),
                      if (transaction.billNumber.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Bill: ${transaction.billNumber}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (transaction.description.isNotEmpty)
                    Text(
                      transaction.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 4),
                  Text(
                    Formatters.dateTime(transaction.date),
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

            // AMOUNT & ACTIONS
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  (isGave ? '-' : '+') + Formatters.currency(transaction.amount),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz, size: 18),
                  tooltip: 'Actions',
                  onSelected: (val) {
                    if (val == 'edit') {
                      _editTransaction(context);
                    } else if (val == 'delete') {
                      _showDeleteConfirm(context);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 16),
                          SizedBox(width: 8),
                          Text('Edit Entry'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 16, color: AppColors.gaveRed),
                          SizedBox(width: 8),
                          Text('Delete Entry',
                              style: TextStyle(color: AppColors.gaveRed)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
