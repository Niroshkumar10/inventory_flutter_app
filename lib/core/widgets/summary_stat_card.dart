import 'package:flutter/material.dart';

/// Shared summary-stat widget used across Bills, Dues & Borrowing, Cash Book,
/// and the Billing summary section. Generalizes what used to be three
/// near-identical private widgets (`_SummaryChip`, `_Chip`, `_NetChip`).
///
/// Two shapes are offered:
/// - [SummaryStatCard.chip]: compact inline label/value pair (no
///   background/border) — matches the original bare-text look used in the
///   filter-bar summary rows.
/// - [SummaryStatCard.card]: a bordered/background card with an optional
///   icon — used where the stat needs more visual weight (e.g. the Billing
///   page's Total Sales / Outstanding pair).
class SummaryStatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData? icon;
  final bool _isCard;

  const SummaryStatCard.chip({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    this.icon,
  }) : _isCard = false;

  const SummaryStatCard.card({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    this.icon,
  }) : _isCard = true;

  @override
  Widget build(BuildContext context) {
    return _isCard ? _buildCard(context) : _buildChip(context);
  }

  Widget _buildChip(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: color.withValues(alpha: 0.8)),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
        Text(
          value,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color),
        ),
      ],
    );
  }

  Widget _buildCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? color.withValues(alpha: 0.12) : color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // FittedBox shrinks the digits to fit rather than truncating with
          // an ellipsis — large totals must always read in full.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}
