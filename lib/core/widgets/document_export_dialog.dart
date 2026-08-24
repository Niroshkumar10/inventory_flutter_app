import 'package:flutter/material.dart';

/// Single "Download" entry point for a one-record document (a bill invoice,
/// a ledger receipt/voucher) — mirrors the Reports section's "Export
/// Report" dialog (icon+title+subtitle rows for PDF / Excel / WhatsApp)
/// so every export surface in the app looks and behaves the same way.
///
/// WhatsApp sharing is always PDF-only, regardless of the document type —
/// callers must implement [onWhatsApp] by generating a PDF and sharing that
/// file, never plain text or the Excel file.
Future<void> showDocumentExportDialog({
  required BuildContext context,
  required String title,
  String subtitle = 'Select an option',
  required Future<void> Function() onPdf,
  required Future<void> Function() onExcel,
  required Future<void> Function() onWhatsApp,
}) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;

  return showDialog(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 20, color: colorScheme.onSurface),
                  onPressed: () => Navigator.pop(dialogContext),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            _DocumentExportOption(
              icon: Icons.picture_as_pdf,
              title: 'PDF Document',
              subtitle: 'Best for printing & sharing',
              color: Colors.red,
              onTap: () {
                Navigator.pop(dialogContext);
                onPdf();
              },
            ),
            const SizedBox(height: 16),
            _DocumentExportOption(
              icon: Icons.table_chart,
              title: 'Excel Spreadsheet',
              subtitle: 'Best for record-keeping',
              color: Colors.green,
              onTap: () {
                Navigator.pop(dialogContext);
                onExcel();
              },
            ),
            const SizedBox(height: 16),
            _DocumentExportOption(
              icon: Icons.chat,
              title: 'Share via WhatsApp',
              subtitle: 'Sends a PDF copy',
              color: const Color(0xFF25D366),
              onTap: () {
                Navigator.pop(dialogContext);
                onWhatsApp();
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(dialogContext),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DocumentExportOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _DocumentExportOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      borderRadius: BorderRadius.circular(12),
      color: isDark ? colorScheme.surfaceContainerHighest : Colors.grey[50],
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.outline),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colorScheme.onSurface.withValues(alpha: 0.4)),
            ],
          ),
        ),
      ),
    );
  }
}
