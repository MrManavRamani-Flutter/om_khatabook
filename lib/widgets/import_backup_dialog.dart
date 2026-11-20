import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
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
  bool _isPickingFile = false;
  List<File> _recentFiles = [];
  File? _selectedFile;
  String? _selectedFileName;
  String? _selectedFileSize;
  String? _selectedFilePath;
  String? _fileError;
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

  Future<void> _pickBackupFile() async {
    setState(() {
      _isPickingFile = true;
      _fileError = null;
    });

    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['json'],
        dialogTitle: 'Select OM Mavtar Backup JSON File',
      );

      if (picked != null) {
        String? content;

        if (picked.path != null) {
          final file = File(picked.path!);
          if (await file.exists()) {
            content = await file.readAsString();
            _selectedFile = file;
          }
        }

        if (content == null || content.isEmpty) {
          try {
            final bytes = await picked.readAsBytes();
            if (bytes.isNotEmpty) {
              content = utf8.decode(bytes);
            }
          } catch (e) {
            debugPrint('Failed reading bytes: $e');
          }
        }

        if (content != null && content.trim().isNotEmpty) {
          final fileLength = picked.lengthSync() ?? (await picked.length()) ?? 0;
          setState(() {
            _selectedFileName = picked.name;
            _selectedFileSize = (fileLength / 1024).toStringAsFixed(1);
            _selectedFilePath = picked.path;
            _textController.text = content!;
            _fileError = null;
          });
        } else {
          setState(() {
            _fileError = 'Selected backup file is empty or could not be read.';
          });
        }
      }
    } catch (e) {
      debugPrint('FilePicker error: $e');
      // Native macOS fallback in case sandbox or plugin issue occurs
      if (Platform.isMacOS) {
        try {
          final res = await Process.run('osascript', [
            '-e',
            'POSIX path of (choose file of type {"json"} with prompt "Select OM Mavtar Backup JSON File")',
          ]);
          if (res.exitCode == 0) {
            final p = res.stdout.toString().trim();
            if (p.isNotEmpty) {
              final file = File(p);
              if (await file.exists()) {
                final content = await file.readAsString();
                final stat = await file.stat();
                setState(() {
                  _selectedFileName = file.uri.pathSegments.last;
                  _selectedFileSize = (stat.size / 1024).toStringAsFixed(1);
                  _selectedFilePath = p;
                  _selectedFile = file;
                  _textController.text = content;
                  _fileError = null;
                });
                return;
              }
            }
          }
        } catch (_) {}
      }
      setState(() {
        _fileError = 'Error selecting file: $e';
      });
    } finally {
      if (mounted) setState(() => _isPickingFile = false);
    }
  }

  void _clearSelectedFile() {
    setState(() {
      _selectedFile = null;
      _selectedFileName = null;
      _selectedFileSize = null;
      _selectedFilePath = null;
      _fileError = null;
      _textController.clear();
      _analysis = null;
    });
  }

  Future<void> _onRecentFileSelected(File? file) async {
    if (file == null) return;
    try {
      final content = await file.readAsString();
      final stat = await file.stat();
      setState(() {
        _selectedFile = file;
        _selectedFileName = file.uri.pathSegments.last;
        _selectedFileSize = (stat.size / 1024).toStringAsFixed(1);
        _selectedFilePath = file.path;
        _textController.text = content;
        _fileError = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _fileError = 'Could not read backup file: $e';
        });
      }
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      setState(() {
        _selectedFile = null;
        _selectedFileName = 'Pasted_Clipboard_Data.json';
        _selectedFileSize = (data.text!.length / 1024).toStringAsFixed(1);
        _selectedFilePath = null;
        _textController.text = data.text!;
        _fileError = null;
      });
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
                    'Strategy: ${summary.mode == BackupImportMode.merge ? "Combine & Merge" : "Clean Overwrite"}',
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
    final dialogWidth = screenWidth > 640 ? 590.0 : screenWidth * 0.94;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
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
                  'Upload an exported backup file to restore or merge records',
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

              // 1. FILE UPLOAD BOX (PRIMARY INTERACTION)
              if (_selectedFileName == null) ...[
                // DROP/CLICK UPLOAD AREA
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: isDark ? 0.08 : 0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.upload_file_rounded,
                          size: 34,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Upload Backup JSON File',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Browse and upload the exact .json file exported from OM Mavtar Group Khata Book.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 1,
                        ),
                        icon: _isPickingFile
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.folder_open_rounded, size: 20),
                        label: Text(
                          _isPickingFile ? 'Selecting File...' : 'Browse & Upload JSON File',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        onPressed: _isPickingFile ? null : _pickBackupFile,
                      ),
                    ],
                  ),
                ),

                // QUICK SELECT FROM RECENT EXPORTED FILES (IF ANY)
                if (_recentFiles.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                            Icon(Icons.history, size: 16, color: AppColors.primary),
                            SizedBox(width: 6),
                            Text(
                              'Or Select Recent Export (Documents Folder):',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<File>(
                            value: _selectedFile,
                            isExpanded: true,
                            hint: const Text('Choose recently exported backup...', style: TextStyle(fontSize: 12)),
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
                            onChanged: _onRecentFileSelected,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ] else ...[
                // 2. SELECTED FILE SUMMARY CARD (LOADED SUCCESSFULLY)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: isDark ? 0.12 : 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.insert_drive_file_rounded,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedFileName ?? 'Backup File',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'File Size: ${_selectedFileSize ?? "0"} KB • JSON Backup Ready',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.75),
                              ),
                            ),
                            if (_selectedFilePath != null && _selectedFilePath!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                _selectedFilePath!,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                  fontFamily: 'monospace',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                                  ),
                                  icon: const Icon(Icons.folder_open, size: 14),
                                  label: const Text('Change File', style: TextStyle(fontSize: 11)),
                                  onPressed: _pickBackupFile,
                                ),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    foregroundColor: AppColors.warningText,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    side: BorderSide(color: AppColors.warningText.withValues(alpha: 0.5)),
                                  ),
                                  icon: const Icon(Icons.close, size: 14),
                                  label: const Text('Remove', style: TextStyle(fontSize: 11)),
                                  onPressed: _clearSelectedFile,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ERROR BANNER
              if (_fileError != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF331515) : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.warningText.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.warningText, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _fileError!,
                          style: const TextStyle(fontSize: 12, color: AppColors.warningText),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // 2. LIVE FILE ANALYSIS BREAKDOWN
              if (_analysis != null) ...[
                const SizedBox(height: 14),
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
                                  : 'Valid Backup Package Ready',
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

              // 3. STRATEGY SELECTION SECTION
              if (_analysis != null && _analysis!.isValid) ...[
                const SizedBox(height: 16),
                const Text(
                  'Choose Import Strategy:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                // OPTION 1: COMBINE & MERGE (RECOMMENDED)
                _buildStrategyCard(
                  context,
                  mode: BackupImportMode.merge,
                  title: 'Combine & Merge with Existing Data (Recommended)',
                  subtitle: 'Safe Non-Destructive Data Merge',
                  description:
                      'Existing data stays completely safe. Duplicate records are skipped automatically, and records with unique data are safely merged.',
                  icon: Icons.call_merge,
                  isRecommended: true,
                ),
                const SizedBox(height: 8),

                // OPTION 2: REPLACE / CLEAN OVERWRITE
                _buildStrategyCard(
                  context,
                  mode: BackupImportMode.replace,
                  title: 'Replace Everything (Clean Overwrite)',
                  subtitle: 'Complete Database Overwrite',
                  description:
                      'Warning: Replaces all existing records with the entries from the backup file.',
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

              // 4. OPTIONAL ADVANCED COLLAPSIBLE RAW JSON (FOR COPY-PASTE BACKUP)
              const SizedBox(height: 10),
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text(
                    'Optional: Paste or View Raw JSON Content',
                    style: TextStyle(fontSize: 11.5, color: Colors.grey),
                  ),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(Icons.content_paste, size: 14),
                          label: const Text('Paste from Clipboard', style: TextStyle(fontSize: 11.5)),
                          onPressed: _pasteFromClipboard,
                        ),
                        if (_textController.text.isNotEmpty)
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              visualDensity: VisualDensity.compact,
                              foregroundColor: Colors.grey,
                            ),
                            onPressed: _clearSelectedFile,
                            child: const Text('Clear', style: TextStyle(fontSize: 11.5)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _textController,
                      maxLines: 4,
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                      decoration: InputDecoration(
                        hintText: 'Raw JSON backup content preview...',
                        hintStyle: const TextStyle(fontSize: 11, color: Colors.grey),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.all(10),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
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
    required String subtitle,
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
            const SizedBox(width: 8),
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
                    subtitle,
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
