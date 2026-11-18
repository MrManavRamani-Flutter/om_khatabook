import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/challan_provider.dart';
import '../theme/app_theme.dart';

class ImportBackupDialog extends StatefulWidget {
  const ImportBackupDialog({super.key});

  @override
  State<ImportBackupDialog> createState() => _ImportBackupDialogState();
}

class _ImportBackupDialogState extends State<ImportBackupDialog> {
  final TextEditingController _textController = TextEditingController();
  BackupImportMode _selectedMode = BackupImportMode.merge; // Recommended default
  bool _importBranding = true;
  bool _isLoading = false;
  List<File> _recentFiles = [];
  File? _selectedFile;
  BackupAnalysisResult? _analysis;

  @override
  void initState() {
    super.initState();
    _loadRecentBackupFiles();
    _textController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentBackupFiles() async {
    final provider = context.read<ChallanProvider>();
    final files = await provider.getRecentBackupFiles();
    if (mounted) {
      setState(() {
        _recentFiles = files;
      });
    }
  }

  void _onTextChanged() {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _analysis = null;
      });
      return;
    }
    final provider = context.read<ChallanProvider>();
    final result = provider.analyzeBackupJson(text);
    setState(() {
      _analysis = result;
    });
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      _textController.text = data.text!;
      _selectedFile = null;
    }
  }

  Future<void> _onFileSelected(File? file) async {
    if (file == null) return;
    setState(() {
      _selectedFile = file;
    });
    try {
      final content = await file.readAsString();
      _textController.text = content;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not read backup file: $e'),
            backgroundColor: AppColors.warningText,
          ),
        );
      }
    }
  }

  Future<void> _handleImport() async {
    if (_analysis == null || !_analysis!.isValid) return;

    setState(() => _isLoading = true);

    final provider = context.read<ChallanProvider>();
    final summary = await provider.importBackupWithStrategy(
      jsonString: _textController.text,
      mode: _selectedMode,
      importBranding: _importBranding,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    Navigator.of(context).pop();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            Icon(
              summary.success ? Icons.check_circle : Icons.error_outline,
              color: summary.success ? AppColors.successText : AppColors.warningText,
              size: 26,
            ),
            const SizedBox(width: 10),
            Text(
              summary.success ? 'Import Complete' : 'Import Failed',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              summary.message,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(ctx).dividerColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Strategy: ${summary.mode == BackupImportMode.merge ? "Combine & Merge" : "Clean Overwrite (Replace)"}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text('• Active Challans: ${summary.totalActiveChallans}'),
                  Text('• Active Parties: ${summary.totalActiveParties}'),
                  if (summary.mode == BackupImportMode.merge) ...[
                    Text('• New Challans Added: ${summary.challansAdded}'),
                    Text('• Duplicates Skipped: ${summary.challansDuplicateSkipped}'),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth > 640 ? 580.0 : screenWidth * 0.92;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.settings_backup_restore, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Restore & Import Backup',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 2),
                Text(
                  'Recover records or merge backup data seamlessly',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              // RECENT EXPORTED BACKUP FILES DROPDOWN (IF ANY)
              if (_recentFiles.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Theme.of(context).dividerColor.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.folder_open, size: 16, color: AppColors.primary),
                          SizedBox(width: 6),
                          Text(
                            'Quick Select Recent Backup File (Documents):',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<File>(
                          value: _selectedFile,
                          isExpanded: true,
                          hint: const Text('Select an exported backup file...', style: TextStyle(fontSize: 12)),
                          items: _recentFiles.map((f) {
                            final name = f.uri.pathSegments.last;
                            final stat = f.statSync();
                            final sizeKb = (stat.size / 1024).toStringAsFixed(1);
                            return DropdownMenuItem<File>(
                              value: f,
                              child: Text(
                                '$name ($sizeKb KB)',
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: _onFileSelected,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // JSON INPUT TEXTAREA WITH QUICK ACTIONS
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Backup JSON Data:',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.content_paste, size: 14),
                        label: const Text('Paste JSON', style: TextStyle(fontSize: 11.5)),
                        onPressed: _pasteFromClipboard,
                      ),
                      if (_textController.text.isNotEmpty)
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            visualDensity: VisualDensity.compact,
                            foregroundColor: Colors.grey,
                          ),
                          onPressed: () {
                            _textController.clear();
                            setState(() {
                              _selectedFile = null;
                            });
                          },
                          child: const Text('Clear', style: TextStyle(fontSize: 11.5)),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _textController,
                maxLines: 5,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  hintText: '{\n  "app": "OM Mavtar Group Khata Book",\n  "challans": [ ... ],\n  "parties": [ ... ]\n}',
                  hintStyle: const TextStyle(fontSize: 11, color: Colors.grey),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),

              // LIVE INSPECTION / ANALYSIS CARD
              if (_analysis != null) ...[
                const SizedBox(height: 12),
                if (_analysis!.isValid) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _analysis!.isPartialOrLegacy
                          ? (isDark ? const Color(0xFF2A2000) : const Color(0xFFFFFBEB))
                          : (isDark ? const Color(0xFF0F291E) : const Color(0xFFECFDF5)),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _analysis!.isPartialOrLegacy
                            ? const Color(0xFFF59E0B)
                            : AppColors.successText,
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _analysis!.isPartialOrLegacy
                                  ? Icons.auto_fix_high
                                  : Icons.check_circle,
                              color: _analysis!.isPartialOrLegacy
                                  ? const Color(0xFFF59E0B)
                                  : AppColors.successText,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _analysis!.isPartialOrLegacy
                                  ? 'Partial / Loose Structure (Auto-Recovered)'
                                  : 'Valid Backup Package Detected',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _analysis!.isPartialOrLegacy
                                    ? const Color(0xFFB45309)
                                    : AppColors.successText,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 10,
                          runSpacing: 6,
                          children: [
                            _buildInfoChip(Icons.receipt_long, '${_analysis!.totalChallans} Challan Records'),
                            _buildInfoChip(Icons.people, '${_analysis!.totalParties} Parties'),
                            if (_analysis!.branding != null)
                              _buildInfoChip(Icons.palette, 'Includes Branding & Settings'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF331515) : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.warningText),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.warningText, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _analysis!.errorMessage ?? 'Invalid format.',
                            style: const TextStyle(fontSize: 12, color: AppColors.warningText),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],

              // STRATEGY SELECTION SECTION (USER KO PUCHNA HAI)
              if (_analysis != null && _analysis!.isValid) ...[
                const SizedBox(height: 16),
                const Text(
                  'Choose Import Strategy (बैकअप कैसे इम्पोर्ट करना है?):',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                // OPTION 1: COMBINE & MERGE (RECOMMENDED)
                _buildStrategyCard(
                  context,
                  mode: BackupImportMode.merge,
                  title: 'Combine & Merge with Existing Data (Recommended)',
                  hindiSubtitle: 'डेटा कम्बाइन / मर्ज करें',
                  description:
                      'Purana data safe rahega. Duplicate records skip honge aur agar kisi record ka data different hai to usko nayi primary ID dekar preserve kiya jayega.',
                  icon: Icons.call_merge,
                  isRecommended: true,
                ),
                const SizedBox(height: 8),

                // OPTION 2: REPLACE / CLEAN OVERWRITE
                _buildStrategyCard(
                  context,
                  mode: BackupImportMode.replace,
                  title: 'Replace Everything (Clean Overwrite)',
                  hindiSubtitle: 'पुराना डेटा डिलीट करके नया डेटा सेट करें',
                  description:
                      '⚠️ Warning: Purana sara data remove ho jayega aur backup file ka naya data clean install hoga.',
                  icon: Icons.delete_sweep,
                  isDanger: true,
                ),

                const SizedBox(height: 8),
                if (_analysis!.branding != null)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: _importBranding,
                    activeColor: AppColors.primary,
                    title: const Text(
                      'Import company branding, logo & text casing preferences',
                      style: TextStyle(fontSize: 12),
                    ),
                    onChanged: (val) => setState(() => _importBranding = val ?? true),
                  ),
              ],
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: _selectedMode == BackupImportMode.replace
                ? AppColors.warningText
                : AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
          icon: _isLoading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Icon(_selectedMode == BackupImportMode.replace ? Icons.restore_page : Icons.merge, size: 18),
          label: Text(
            _isLoading
                ? 'Importing...'
                : (_selectedMode == BackupImportMode.replace ? 'Clean Overwrite' : 'Merge Data'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          onPressed: (_analysis != null && _analysis!.isValid && !_isLoading)
              ? _handleImport
              : null,
        ),
      ],
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildStrategyCard(
    BuildContext context, {
    required BackupImportMode mode,
    required String title,
    required String hindiSubtitle,
    required String description,
    required IconData icon,
    bool isRecommended = false,
    bool isDanger = false,
  }) {
    final isSelected = _selectedMode == mode;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color borderColor;
    if (isSelected) {
      borderColor = isDanger ? AppColors.warningText : AppColors.primary;
    } else {
      borderColor = Theme.of(context).dividerColor.withValues(alpha: 0.25);
    }

    return InkWell(
      onTap: () => setState(() => _selectedMode = mode),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDanger
                  ? (isDark ? const Color(0xFF331515) : const Color(0xFFFEF2F2))
                  : (isDark ? const Color(0xFF0D251D) : const Color(0xFFF0FDF4)))
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 2),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? (isDanger ? AppColors.warningText : AppColors.primary)
                      : Colors.grey,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDanger ? AppColors.warningText : AppColors.primary,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? (isDanger ? AppColors.warningText : AppColors.primary)
                                : null,
                          ),
                        ),
                      ),
                      if (isRecommended) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'RECOMMENDED',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hindiSubtitle,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDanger ? AppColors.warningText : AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.85),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
