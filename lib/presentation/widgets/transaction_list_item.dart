import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/repositories/transaction_repository.dart';

class TransactionListItem extends StatelessWidget {
  final TransactionWithCategory item;
  final VoidCallback? onTap;

  const TransactionListItem({
    super.key,
    required this.item,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tx = item.transaction;
    final isIncome = tx.type == 'income';
    final amountColor = isIncome ? AppColors.incomeText : AppColors.expenseText;
    final prefix = isIncome ? '+ ' : '- ';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          // Icon Container
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isIncome ? AppColors.incomeBg : AppColors.expenseBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              color: amountColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          // Title & Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      DateFormatter.toHumanDate(tx.transactionDate),
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '• ${item.category.name}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (tx.receiptImagePath != null) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.receipt_long_rounded, size: 13, color: AppColors.brandPrimary),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Amount
          Text(
            '$prefix${CurrencyFormatter.format(tx.amount)}',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: amountColor,
            ),
          ),
        ],
      ),
    );
  }
}
