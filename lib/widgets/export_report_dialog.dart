import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/challan_entry.dart';
import '../models/party.dart';
import '../providers/challan_provider.dart';
import '../services/export_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

enum ExportFormat { pdf, excel }
enum PartyScope { all, single, multiple }
enum DateScope { currentFilter, allTime, specificMonth, customRange }

class ExportReportDialog extends StatefulWidget {
  final String? initialPartyId;

  const ExportReportDialog({super.key, this.initialPartyId});

  @override
  State<ExportReportDialog> createState() => _ExportReportDialogState();
}

class _ExportReportDialogState extends State<ExportReportDialog> {
  ExportFormat _format = ExportFormat.pdf;
  PartyScope _partyScope = PartyScope.all;
  String? _selectedSinglePartyId;
  final Set<String> _selectedPartyIds = {};

  DateScope _dateScope = DateScope.currentFilter;
  late DateTime _selectedMonth;
  DateTime _customStartDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _customEndDate = DateTime.now();

  bool _sortAscending = false;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);

    if (widget.initialPartyId != null) {
      _partyScope = PartyScope.single;
      _selectedSinglePartyId = widget.initialPartyId;
    } else {
      final provider = context.read<ChallanProvider>();
      if (provider.selectedPartyIds.isNotEmpty) {
        if (provider.selectedPartyIds.length == 1) {
          _partyScope = PartyScope.single;
          _selectedSinglePartyId = provider.selectedPartyIds.first;
        } else {
          _partyScope = PartyScope.multiple;
          _selectedPartyIds.addAll(provider.selectedPartyIds);
        }
      }
    }
  }

  List<ChallanEntry> _computeEntriesToExport(ChallanProvider provider) {
    if (_dateScope == DateScope.currentFilter && _partyScope == PartyScope.all && provider.selectedPartyIds.isEmpty) {
      return List.from(provider.filteredChallans);
    }

    final all = provider.challans;

    final filtered = all.where((c) {
      // Party filter
      if (_partyScope == PartyScope.single && _selectedSinglePartyId != null) {
        if (c.partyId != _selectedSinglePartyId) return false;
      } else if (_partyScope == PartyScope.multiple && _selectedPartyIds.isNotEmpty) {
        if (!_selectedPartyIds.contains(c.partyId)) return false;
      }

      // Date filter
      if (_dateScope == DateScope.specificMonth) {
        if (c.date.month != _selectedMonth.month || c.date.year != _selectedMonth.year) {
          return false;
        }
      } else if (_dateScope == DateScope.customRange) {
        if (c.date.isBefore(_customStartDate) ||
            c.date.isAfter(_customEndDate.add(const Duration(days: 1)))) {
          return false;
        }
      } else if (_dateScope == DateScope.currentFilter) {
        // Use current screen date filter logic
        if (provider.dateFilter == 'today') {
          final now = DateTime.now();
          if (c.date.year != now.year || c.date.month != now.month || c.date.day != now.day) {
            return false;
          }
        } else if (provider.dateFilter == 'week') {
          if (c.date.isBefore(DateTime.now().subtract(const Duration(days: 7)))) return false;
        } else if (provider.dateFilter == 'month') {
          if (c.date.isBefore(DateTime.now().subtract(const Duration(days: 30)))) return false;
        }
      }

      return true;
    }).toList();

    filtered.sort((a, b) =>
        _sortAscending ? a.date.compareTo(b.date) : b.date.compareTo(a.date));

    return filtered;
  }

  String _getFilterDescription(ChallanProvider provider) {
    final List<String> parts = [];

    // Party
    if (_partyScope == PartyScope.all) {
      parts.add('All Parties');
    } else if (_partyScope == PartyScope.single && _selectedSinglePartyId != null) {
      final p = provider.parties.firstWhere(
        (e) => e.id == _selectedSinglePartyId,
        orElse: () => Party(id: '', name: 'Selected Party', createdAt: DateTime.now()),
      );
      parts.add('Party: ${p.name}');
    } else if (_partyScope == PartyScope.multiple) {
      parts.add('${_selectedPartyIds.length} Selected Parties');
    }

    // Date
    if (_dateScope == DateScope.specificMonth) {
      parts.add('Month: ${DateFormat('MMMM yyyy').format(_selectedMonth)}');
    } else if (_dateScope == DateScope.allTime) {
      parts.add('Period: All Time');
    } else if (_dateScope == DateScope.customRange) {
      parts.add('Period: ${Formatters.shortDate(_customStartDate)} - ${Formatters.shortDate(_customEndDate)}');
    } else {
      parts.add('Period: Current Filtered View');
    }

    parts.add('Sort: ${_sortAscending ? "Oldest First" : "Newest First"}');
    return parts.join(' • ');
  }

  Future<void> _exportPdf(BuildContext context, bool previewOnly) async {
    final provider = context.read<ChallanProvider>();
    final entries = _computeEntriesToExport(provider);

    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No records match the selected export criteria.')),
      );
      return;
    }

    setState(() => _isGenerating = true);
    final summary = _getFilterDescription(provider);
    final messenger = ScaffoldMessenger.of(context);

    try {
      if (previewOnly) {
        await ExportService.printOrPreviewPdf(
          entries: entries,
          filterSummary: summary,
          sortAscending: _sortAscending,
        );
      } else {
        final path = await ExportService.savePdfToDocuments(
          entries: entries,
          filterSummary: summary,
          sortAscending: _sortAscending,
        );
        if (mounted) {
          _showFileSavedDialog('PDF Report Saved!', path);
        }
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Export error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _exportExcel(BuildContext context) async {
    final provider = context.read<ChallanProvider>();
    final entries = _computeEntriesToExport(provider);

    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No records match the selected export criteria.')),
      );
      return;
    }

    setState(() => _isGenerating = true);
    final summary = _getFilterDescription(provider);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final path = await ExportService.generateAndSaveExcel(
        entries: entries,
        filterSummary: summary,
        sortAscending: _sortAscending,
      );
      if (mounted) {
        _showFileSavedDialog('Excel (.xlsx) Report Saved!', path);
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Excel export error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _showFileSavedDialog(String title, String path) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: AppColors.successText),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('File saved successfully to your computer:'),
            const SizedBox(height: 8),
            SelectableText(
              path,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 12),
            const Text(
              'You can open this document in Excel, Numbers, or any PDF viewer.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy File Path'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: path));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('File path copied to clipboard!')),
              );
            },
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChallanProvider>();
    final parties = provider.parties;
    final entries = _computeEntriesToExport(provider);
    final sumFinal = entries.fold(0.0, (s, c) => s + c.finalAmount);
    final sumUnpaid = entries
        .where((c) => c.hasWarning)
        .fold(0.0, (s, c) => s + c.finalAmount);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 820),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Generate PDF & Excel Reports',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Customized party-wise, monthly, or all-time report generator',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 20),

              // SCROLLABLE CONFIGURATION
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. CHOOSE FORMAT
                      const Text(
                        '1. Choose Export Format',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<ExportFormat>(
                        segments: const [
                          ButtonSegment(
                            value: ExportFormat.pdf,
                            label: Text('PDF Document (.pdf)'),
                            icon: Icon(Icons.picture_as_pdf),
                          ),
                          ButtonSegment(
                            value: ExportFormat.excel,
                            label: Text('Excel Spreadsheet (.xlsx)'),
                            icon: Icon(Icons.table_chart),
                          ),
                        ],
                        selected: {_format},
                        onSelectionChanged: (val) {
                          setState(() => _format = val.first);
                        },
                      ),
                      const SizedBox(height: 20),

                      // 2. PARTY SCOPE
                      const Text(
                        '2. Party Scope (Party-Wise Filter)',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ChoiceChip(
                            label: const Text('All Parties'),
                            selected: _partyScope == PartyScope.all,
                            onSelected: (_) => setState(() => _partyScope = PartyScope.all),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Single Party'),
                            selected: _partyScope == PartyScope.single,
                            onSelected: (_) {
                              setState(() {
                                _partyScope = PartyScope.single;
                                if (_selectedSinglePartyId == null && parties.isNotEmpty) {
                                  _selectedSinglePartyId = parties.first.id;
                                }
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: Text('Multiple Parties (${_selectedPartyIds.length})'),
                            selected: _partyScope == PartyScope.multiple,
                            onSelected: (_) => setState(() => _partyScope = PartyScope.multiple),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // SUB-SELECTION FOR SINGLE OR MULTIPLE PARTIES
                      if (_partyScope == PartyScope.single) ...[
                        DropdownButtonFormField<String>(
                          initialValue: _selectedSinglePartyId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Select Party for Report',
                            prefixIcon: Icon(Icons.person, size: 18),
                          ),
                          items: parties.map((p) {
                            return DropdownMenuItem(
                              value: p.id,
                              child: Text(p.name, overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (val) => setState(() => _selectedSinglePartyId = val),
                        ),
                      ] else if (_partyScope == PartyScope.multiple) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Select Parties to Include:',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  Row(
                                    children: [
                                      TextButton(
                                        onPressed: () {
                                          setState(() {
                                            _selectedPartyIds.addAll(parties.map((p) => p.id));
                                          });
                                        },
                                        child: const Text('Select All', style: TextStyle(fontSize: 12)),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          setState(() => _selectedPartyIds.clear());
                                        },
                                        child: const Text('Clear', style: TextStyle(fontSize: 12)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const Divider(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: parties.map((p) {
                                  final isChecked = _selectedPartyIds.contains(p.id);
                                  return FilterChip(
                                    label: Text(p.name),
                                    selected: isChecked,
                                    onSelected: (val) {
                                      setState(() {
                                        if (val) {
                                          _selectedPartyIds.add(p.id);
                                        } else {
                                          _selectedPartyIds.remove(p.id);
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),

                      // 3. PERIOD & DATE SCOPE
                      const Text(
                        '3. Date & Period Filter (Monthly / Range)',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Current Filtered View'),
                            selected: _dateScope == DateScope.currentFilter,
                            onSelected: (_) => setState(() => _dateScope = DateScope.currentFilter),
                          ),
                          ChoiceChip(
                            label: const Text('🗓️ Specific Month (Monthly Report)'),
                            selected: _dateScope == DateScope.specificMonth,
                            onSelected: (_) => setState(() => _dateScope = DateScope.specificMonth),
                          ),
                          ChoiceChip(
                            label: const Text('All Over Data (All Time)'),
                            selected: _dateScope == DateScope.allTime,
                            onSelected: (_) => setState(() => _dateScope = DateScope.allTime),
                          ),
                          ChoiceChip(
                            label: const Text('Custom Date Range'),
                            selected: _dateScope == DateScope.customRange,
                            onSelected: (_) => setState(() => _dateScope = DateScope.customRange),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // SUB-SELECTION FOR MONTH OR CUSTOM RANGE
                      if (_dateScope == DateScope.specificMonth) ...[
                        Row(
                          children: [
                            const Icon(Icons.calendar_month, color: AppColors.primary, size: 20),
                            const SizedBox(width: 8),
                            const Text('Select Month:', style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(width: 12),
                            DropdownButton<int>(
                              value: _selectedMonth.month,
                              items: List.generate(12, (index) {
                                final m = index + 1;
                                return DropdownMenuItem(
                                  value: m,
                                  child: Text(DateFormat('MMMM').format(DateTime(2026, m))),
                                );
                              }),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedMonth = DateTime(_selectedMonth.year, val, 1);
                                  });
                                }
                              },
                            ),
                            const SizedBox(width: 16),
                            const Text('Year:', style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(width: 12),
                            DropdownButton<int>(
                              value: _selectedMonth.year,
                              items: [2024, 2025, 2026, 2027].map((y) {
                                return DropdownMenuItem(value: y, child: Text('$y'));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedMonth = DateTime(val, _selectedMonth.month, 1);
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ] else if (_dateScope == DateScope.customRange) ...[
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  final p = await showDatePicker(
                                    context: context,
                                    initialDate: _customStartDate,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2035),
                                  );
                                  if (p != null) setState(() => _customStartDate = p);
                                },
                                child: InputDecorator(
                                  decoration: const InputDecoration(labelText: 'From Date'),
                                  child: Text(Formatters.date(_customStartDate)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  final p = await showDatePicker(
                                    context: context,
                                    initialDate: _customEndDate,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2035),
                                  );
                                  if (p != null) setState(() => _customEndDate = p);
                                },
                                child: InputDecorator(
                                  decoration: const InputDecoration(labelText: 'To Date'),
                                  child: Text(Formatters.date(_customEndDate)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 20),

                      // 4. SORT ORDER
                      const Text(
                        '4. Sort Order',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ChoiceChip(
                            label: const Text('↓ Newest Date First (Desc)'),
                            selected: !_sortAscending,
                            onSelected: (_) => setState(() => _sortAscending = false),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('↑ Oldest Date First (Asc)'),
                            selected: _sortAscending,
                            onSelected: (_) => setState(() => _sortAscending = true),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // LIVE DATA PREVIEW BOX
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.analytics_outlined, color: AppColors.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${entries.length} Records Selected to Export',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  Text(
                                    'Total Value: ${Formatters.currency(sumFinal)} • Unpaid: ${Formatters.currency(sumUnpaid)}',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ACTION BUTTONS
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  if (_isGenerating)
                    const Row(
                      children: [
                        SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 10),
                        Text('Generating file...', style: TextStyle(fontSize: 13)),
                      ],
                    )
                  else if (_format == ExportFormat.pdf)
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _exportPdf(context, true),
                          icon: const Icon(Icons.print, size: 18),
                          label: const Text('Preview / Print PDF'),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: () => _exportPdf(context, false),
                          icon: const Icon(Icons.download, size: 18),
                          label: const Text('Save PDF to Documents'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: () => _exportExcel(context),
                      icon: const Icon(Icons.table_chart, size: 18),
                      label: const Text('Generate & Save Excel (.xlsx)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF15803D), // Forest Excel green
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
}
