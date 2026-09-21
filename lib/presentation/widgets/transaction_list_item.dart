import 'dart:io';
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

  void _showDetailDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _TransactionDetailDialog(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tx = item.transaction;
    final isIncome = tx.type == 'income';
    final amountColor = isIncome ? AppColors.incomeText : AppColors.expenseText;
    final prefix = isIncome ? '+ ' : '- ';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap ?? () => _showDetailDialog(context),
          child: Padding(
            padding: const EdgeInsets.all(12),
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
                      Builder(
                        builder: (context) {
                          final isBackdated = !DateUtils.isSameDay(tx.transactionDate, tx.createdAt);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      isBackdated
                                          ? 'Tanggal: ${DateFormatter.toHumanDate(tx.transactionDate)} • Dicatat: ${DateFormatter.toHumanDate(tx.createdAt)}'
                                          : DateFormatter.toHumanDate(tx.transactionDate),
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.textSecondary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (!isBackdated) ...[
                                    const SizedBox(width: 4),
                                    const Text(
                                      '•',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        item.category.name,
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          color: AppColors.textSecondary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (isBackdated || tx.receiptImagePath != null) ...[
                                const SizedBox(height: 2),
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 6,
                                  runSpacing: 2,
                                  children: [
                                    if (isBackdated)
                                      Text(
                                        item.category.name,
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    if (isBackdated)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: AppColors.warningBg,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            'Mundur',
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.warningText,
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (tx.receiptImagePath != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: AppColors.blueLight,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.photo_camera_rounded, size: 10, color: AppColors.brandPrimary),
                                              SizedBox(width: 3),
                                              Text(
                                                'Ada Nota',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.brandPrimary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Amount
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 110),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      '$prefix${CurrencyFormatter.format(tx.amount)}',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: amountColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TransactionDetailDialog extends StatelessWidget {
  final TransactionWithCategory item;

  const _TransactionDetailDialog({required this.item});

  @override
  Widget build(BuildContext context) {
    final tx = item.transaction;
    final isIncome = tx.type == 'income';
    final amountColor = isIncome ? AppColors.incomeText : AppColors.expenseText;
    final isBackdated = !DateUtils.isSameDay(tx.transactionDate, tx.createdAt);
    final hasReceipt = tx.receiptImagePath != null && tx.receiptImagePath!.isNotEmpty;
    final receiptFile = hasReceipt ? File(tx.receiptImagePath!) : null;
    final fileExists = receiptFile != null && receiptFile.existsSync();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              // Header Dialog
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isIncome ? AppColors.incomeBg : AppColors.expenseBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          isIncome ? 'PEMASUKAN KAS' : 'PENGELUARAN KAS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: amountColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Title & Amount
              Text(
                tx.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '${isIncome ? '+' : '-'}${CurrencyFormatter.format(tx.amount)}',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: amountColor,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Divider(color: AppColors.borderSubtle),
              const SizedBox(height: 10),

              // Metadata: Tanggal & Kategori
              if (isBackdated) ...[
                _buildDetailRow(
                  icon: Icons.calendar_today_rounded,
                  label: 'Tanggal Transaksi',
                  value: DateFormatter.toHumanDateTime(tx.transactionDate),
                ),
                const SizedBox(height: 8),
                _buildDetailRow(
                  icon: Icons.schedule_rounded,
                  label: 'Waktu Pencatatan',
                  value: DateFormatter.toHumanDateTime(tx.createdAt),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.warningBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.history_rounded, size: 14, color: AppColors.warningText),
                      const SizedBox(width: 6),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: const Text(
                            'Pencatatan Kas Mundur (Backdated)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.warningText,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                _buildDetailRow(
                  icon: Icons.calendar_today_rounded,
                  label: 'Tanggal',
                  value: DateFormatter.toHumanDateTime(tx.transactionDate),
                ),
              ],
              const SizedBox(height: 8),
              _buildDetailRow(
                icon: Icons.category_rounded,
                label: 'Kategori',
                value: item.category.name,
              ),

              if (tx.description != null && tx.description!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildDetailRow(
                  icon: Icons.notes_rounded,
                  label: 'Keterangan',
                  value: tx.description!.trim(),
                ),
              ],

              const SizedBox(height: 14),
              const Divider(color: AppColors.borderSubtle),
              const SizedBox(height: 10),

              // Bukti Foto Nota
              Row(
                children: [
                  const Icon(Icons.receipt_long_rounded, size: 18, color: AppColors.brandPrimary),
                  const SizedBox(width: 6),
                  const Text(
                    'Bukti Foto Nota',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  const Spacer(),
                  if (fileExists)
                    const Text(
                      'Ketuk untuk perbesar',
                      style: TextStyle(fontSize: 10.5, color: AppColors.brandPrimary),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              if (fileExists)
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => Dialog(
                        backgroundColor: Colors.transparent,
                        insetPadding: const EdgeInsets.all(12),
                        child: Stack(
                          alignment: Alignment.topRight,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: InteractiveViewer(
                                maxScale: 4.0,
                                child: Image.file(
                                  receiptFile,
                                  cacheWidth: 1600,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: CircleAvatar(
                                backgroundColor: Colors.black.withValues(alpha: 0.6),
                                radius: 18,
                                child: IconButton(
                                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                                  onPressed: () => Navigator.of(ctx).pop(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        Image.file(
                          receiptFile,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          cacheWidth: 800,
                        ),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          color: Colors.black.withValues(alpha: 0.5),
                          child: const Text(
                            'Lihat Foto Layar Penuh',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (hasReceipt)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.slateTag,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.attach_file_rounded, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Foto tersimpan: ${tx.receiptImagePath}',
                          style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.slateTag,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Tidak ada foto nota terlampir pada transaksi ini.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),

              ],
            ),
          ),
        ),
        Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                  minimumSize: const Size.fromHeight(42),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Tutup'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 280 || label == 'Keterangan';
        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 15, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '$label: ',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Padding(
                padding: const EdgeInsets.only(left: 23),
                child: Text(
                  value,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
              ),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 15, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              '$label: ',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
            ),
          ],
        );
      },
    );
  }
}
