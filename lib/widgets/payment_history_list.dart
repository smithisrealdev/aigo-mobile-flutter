import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/billing_models.dart';
import '../services/billing_service.dart';

const Color _brandBlue = Color(0xFF1A5EFF);

/// List of payment history records.
class PaymentHistoryList extends ConsumerWidget {
  const PaymentHistoryList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(paymentHistoryProvider);

    return historyAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: _brandBlue)),
      error: (e, _) => Center(
        child: Text('Failed to load payment history',
            style: GoogleFonts.dmSans(fontSize: 13, color: Colors.grey)),
      ),
      data: (records) {
        if (records.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.receipt_long,
                      size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text('No payment history yet',
                      style: GoogleFonts.dmSans(
                          fontSize: 14, color: Colors.grey.shade600)),
                ],
              ),
            ),
          );
        }
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: records.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) => _PaymentRow(record: records[i]),
        );
      },
    );
  }
}

class _PaymentRow extends StatelessWidget {
  final PaymentRecord record;

  const _PaymentRow({required this.record});

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (record.status.toLowerCase()) {
      'paid' => Colors.green,
      'pending' => Colors.orange,
      'failed' => Colors.red,
      _ => Colors.grey,
    };

    final date = record.createdAt != null
        ? DateTime.tryParse(record.createdAt!)
        : null;
    final dateStr = date != null
        ? '${date.day}/${date.month}/${date.year}'
        : '';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(
        record.description ?? 'Payment',
        style: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF1A1A2E)),
      ),
      subtitle: Text(
        dateStr,
        style: GoogleFonts.dmSans(fontSize: 12, color: Colors.grey.shade600),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${record.currency} ${record.amount.toStringAsFixed(2)}',
            style: GoogleFonts.dmSans(
                fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              record.status,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
      onTap: record.stripeInvoiceUrl != null
          ? () => launchUrl(Uri.parse(record.stripeInvoiceUrl!),
              mode: LaunchMode.externalApplication)
          : null,
    );
  }
}

/// Standalone screen for payment history.
class PaymentHistoryScreen extends StatelessWidget {
  const PaymentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('Payment History',
            style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w700, color: const Color(0xFF1A1A2E))),
        iconTheme: const IconThemeData(color: Color(0xFF1A1A2E)),
      ),
      body: const PaymentHistoryList(),
    );
  }
}
