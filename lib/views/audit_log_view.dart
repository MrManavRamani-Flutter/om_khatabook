import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/audit_log_entry.dart';
import '../providers/auth_provider.dart';
import '../providers/challan_provider.dart';
import '../services/export_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

class AuditLogView extends StatefulWidget {
  const AuditLogView({super.key});

  @override
  State<AuditLogView> createState() => _AuditLogViewState();
}

class _AuditLogViewState extends State<AuditLogView> {
  String _searchQuery = '';
  AuditAction? _selectedAction;
  AuditEntityType? _selectedEntityType;
  bool _isExporting = false;

  Future<void> _exportToExcel(List<AuditLogEntry> logs) async {
    if (logs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No audit log entries to export.')),
      );
      return;
    }

    setState(() => _isExporting = true);
    try {
      final path = await ExportService.exportAuditLogsToExcel(logs: logs);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text('Audit log exported to:\n$path')),
              ],
            ),
            backgroundColor: AppColors.successText,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: AppColors.warningText,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _showClearConfirm(BuildContext context, ChallanProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warningText),
            SizedBox(width: 8),
            Text('Clear All Audit Logs?'),
          ],
        ),
        content: const Text(
          'Are you sure you want to permanently clear all audit trail records? This action cannot be undone.',
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
            onPressed: () {
              Navigator.of(ctx).pop();
              provider.clearAuditLogs();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All audit logs cleared successfully.'),
                  backgroundColor: AppColors.warningText,
                ),
              );
            },
            child: const Text('Clear All Forever'),
          ),
        ],
      ),
    );
  }

  void _showLogDetail(BuildContext context, AuditLogEntry log) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            _buildActionIconBadge(log.action),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                log.action.label,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailItem('Timestamp', Formatters.dateTime(log.timestamp)),
              _buildDetailItem('Entity Type', log.entityType.label),
              _buildDetailItem('Entity / Title', log.entityTitle),
              _buildDetailItem('Performed By', '${log.performedBy} [${log.userRole}]'),
              const Divider(height: 20),
              const Text('Description:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 4),
              Text(log.description, style: const TextStyle(fontSize: 13.5, height: 1.4)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChallanProvider>();
    final auth = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final allLogs = provider.auditLogs;

    // Filter logs
    final filteredLogs = allLogs.where((l) {
      if (_selectedAction != null && l.action != _selectedAction) return false;
      if (_selectedEntityType != null && l.entityType != _selectedEntityType) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchDesc = l.description.toLowerCase().contains(q);
        final matchTitle = l.entityTitle.toLowerCase().contains(q);
        final matchUser = l.performedBy.toLowerCase().contains(q);
        if (!matchDesc && !matchTitle && !matchUser) return false;
      }
      return true;
    }).toList();

    // Summary calculations
    final totalCreates = allLogs.where((l) => l.action == AuditAction.create).length;
    final totalUpdates = allLogs.where((l) => l.action == AuditAction.update).length;
    final totalDeletes = allLogs.where((l) => l.action == AuditAction.softDelete || l.action == AuditAction.permanentDelete).length;
    final totalLogins = allLogs.where((l) => l.action == AuditAction.login).length;

    return Scaffold(
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
                      'Audit Trail & History Log',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tamper-evident record of all commercial challans, parties, exports, and login sessions',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        side: BorderSide(color: Theme.of(context).dividerColor),
                      ),
                      icon: _isExporting
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.file_download_outlined, size: 18),
                      label: const Text('Export Excel (.xlsx)'),
                      onPressed: _isExporting ? null : () => _exportToExcel(filteredLogs),
                    ),
                    if (auth.canClearAuditLogs) ...[
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? AppColors.warningBgDark : AppColors.warningBgLight,
                          foregroundColor: AppColors.warningText,
                          elevation: 0,
                          side: const BorderSide(color: AppColors.warningBorder),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        ),
                        icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                        label: const Text('Clear Logs'),
                        onPressed: allLogs.isEmpty ? null : () => _showClearConfirm(context, provider),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),

            // KPI CARDS
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildKpiCard(context, 'Total Events', '${allLogs.length}', Icons.history, AppColors.primary),
                _buildKpiCard(context, 'Created', '$totalCreates', Icons.add_circle_outline, AppColors.successText),
                _buildKpiCard(context, 'Modified', '$totalUpdates', Icons.edit_note, const Color(0xFF0284C7)),
                _buildKpiCard(context, 'Deleted / Purged', '$totalDeletes', Icons.delete_outline, AppColors.warningText),
                _buildKpiCard(context, 'Logins', '$totalLogins', Icons.login, const Color(0xFF7C3AED)),
              ],
            ),
            const SizedBox(height: 18),

            // SEARCH & FILTER TOOLBAR
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Search audit records by description, party name, challan #, or user...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onChanged: (val) => setState(() => _searchQuery = val.trim()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Entity Filter
                      DropdownButton<AuditEntityType?>(
                        value: _selectedEntityType,
                        hint: const Text('Entity: All'),
                        isDense: true,
                        underline: const SizedBox(),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All Entities')),
                          ...AuditEntityType.values.map(
                            (e) => DropdownMenuItem(value: e, child: Text(e.label)),
                          ),
                        ],
                        onChanged: (val) => setState(() => _selectedEntityType = val),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Action Filter Chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildActionFilterChip('All Actions', null),
                      _buildActionFilterChip('Created', AuditAction.create),
                      _buildActionFilterChip('Updated', AuditAction.update),
                      _buildActionFilterChip('Moved to Bin', AuditAction.softDelete),
                      _buildActionFilterChip('Restored', AuditAction.restore),
                      _buildActionFilterChip('Purged', AuditAction.permanentDelete),
                      _buildActionFilterChip('Logins', AuditAction.login),
                      _buildActionFilterChip('Exports', AuditAction.exportReport),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // AUDIT LOG LIST
            Expanded(
              child: filteredLogs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history_toggle_off, size: 54, color: Theme.of(context).dividerColor),
                          const SizedBox(height: 12),
                          const Text(
                            'No audit logs match current filters',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Actions taken in the system will be automatically recorded here.',
                            style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: filteredLogs.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final log = filteredLogs[index];
                        return _buildLogCard(context, log, isDark);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogCard(BuildContext context, AuditLogEntry log, bool isDark) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _showLogDetail(context, log),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              _buildActionIconBadge(log.action),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          log.entityTitle.isNotEmpty ? log.entityTitle : log.entityType.label,
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            log.entityType.label,
                            style: TextStyle(fontSize: 10, color: Theme.of(context).textTheme.bodySmall?.color),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      log.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      '${log.performedBy} [${log.userRole}]',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    Formatters.dateTime(log.timestamp),
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionFilterChip(String label, AuditAction? action) {
    final isSelected = _selectedAction == action;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 11.5)),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedAction = action),
      selectedColor: AppColors.primary.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? AppColors.primary : null,
      ),
    );
  }

  Widget _buildActionIconBadge(AuditAction action) {
    IconData icon;
    Color color;

    switch (action) {
      case AuditAction.create:
        icon = Icons.add_circle;
        color = AppColors.successText;
        break;
      case AuditAction.update:
        icon = Icons.edit;
        color = const Color(0xFF0284C7);
        break;
      case AuditAction.softDelete:
        icon = Icons.delete_outline;
        color = const Color(0xFFD97706);
        break;
      case AuditAction.restore:
        icon = Icons.restore;
        color = AppColors.successText;
        break;
      case AuditAction.permanentDelete:
        icon = Icons.delete_forever;
        color = AppColors.warningText;
        break;
      case AuditAction.login:
        icon = Icons.login;
        color = const Color(0xFF7C3AED);
        break;
      case AuditAction.logout:
        icon = Icons.logout;
        color = Colors.grey;
        break;
      case AuditAction.exportReport:
      case AuditAction.taxInvoicePrint:
        icon = Icons.file_download;
        color = AppColors.primary;
        break;
      case AuditAction.settingsChange:
        icon = Icons.settings;
        color = const Color(0xFF475569);
        break;
    }

    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }

  Widget _buildKpiCard(BuildContext context, String label, String value, IconData icon, Color color) {
    return Container(
      width: 175,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
