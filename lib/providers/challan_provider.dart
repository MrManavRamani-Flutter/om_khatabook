import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/audit_log_entry.dart';
import '../models/challan_entry.dart';
import '../models/income_expense_entry.dart';
import '../models/party.dart';
import '../services/storage_service.dart';
import '../utils/formatters.dart';

enum BackupImportMode {
  merge, // Combine / Merge with existing data (preserves both, duplicates skipped)
  replace, // Clean overwrite / erase existing data
}

enum ChallanSortField {
  date('Date'),
  challanNo('Challan #');

  final String label;
  const ChallanSortField(this.label);
}

class ProfitLossCalculation {
  final List<IncomeExpenseEntry> expenses;
  final List<IncomeExpenseEntry> incomes;
  final double totalExpenses;
  final double totalIncome;
  final double netAmount;
  final bool isProfit;

  ProfitLossCalculation({
    required this.expenses,
    required this.incomes,
    required this.totalExpenses,
    required this.totalIncome,
    required this.netAmount,
    required this.isProfit,
  });
}

class BackupAnalysisResult {
  final bool isValid;
  final String? errorMessage;
  final List<ChallanEntry> challans;
  final List<Party> parties;
  final List<IncomeExpenseEntry> incomeExpenseEntries;
  final Map<String, dynamic>? branding;
  final bool isPartialOrLegacy;
  final int totalChallans;
  final int totalParties;

  BackupAnalysisResult({
    required this.isValid,
    this.errorMessage,
    this.challans = const [],
    this.parties = const [],
    this.incomeExpenseEntries = const [],
    this.branding,
    this.isPartialOrLegacy = false,
    this.totalChallans = 0,
    this.totalParties = 0,
  });
}

class BackupImportSummary {
  final bool success;
  final BackupImportMode mode;
  final int challansAdded;
  final int challansDuplicateSkipped;
  final int partiesAdded;
  final int partiesDuplicateSkipped;
  final int totalActiveChallans;
  final int totalActiveParties;
  final String message;

  BackupImportSummary({
    required this.success,
    required this.mode,
    this.challansAdded = 0,
    this.challansDuplicateSkipped = 0,
    this.partiesAdded = 0,
    this.partiesDuplicateSkipped = 0,
    this.totalActiveChallans = 0,
    this.totalActiveParties = 0,
    required this.message,
  });
}

class ChallanProvider extends ChangeNotifier {
  final StorageService _storage;
  final Uuid _uuid = const Uuid();

  List<Party> _parties = [];
  List<ChallanEntry> _challans = [];
  bool _isDarkMode = false;
  bool _isLoading = true;

  // Filter state
  String _searchQuery = '';
  Set<String> _selectedPartyIds = {}; // Supports multiple or single party selection
  PaymentOption? _paymentOptionFilter;
  String? _statusFilter; // 'all', 'paid', 'unpaid', 'pending', 'bounced'
  String _dateFilter = 'all'; // 'all', 'today', 'week', 'month', 'custom', 'monthly_picker'
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  int? _selectedMonth; // 1 - 12
  int? _selectedYear; // e.g. 2026

  // Sorting state (Field & Ascending vs Descending)
  ChallanSortField _sortField = ChallanSortField.date;
  bool _sortAscending = false; // For Date: false = Newest First, true = Oldest First. For Challan #: true = 1 to N, false = N to 1

  // View Mode (Table / Cards / Compact)
  LedgerViewMode _viewMode = LedgerViewMode.table;
  LedgerViewMode _partyViewMode = LedgerViewMode.table;

  // Text Casing Style (Uppercase default)
  TextCasingStyle _textCasingStyle = TextCasingStyle.uppercase;

  // App Branding & Profile Logos
  String _appLogoBase64 = '';
  String _profileLogoBase64 = '';
  String _companyName = 'OM Mavtar Group';
  String _companyTagline = 'Khata Book Desktop';
  String _adminName = 'OM Mavtar Admin';
  String _adminRole = 'Administrator';
  bool _isSidebarCollapsed = false;
  List<AuditLogEntry> _auditLogs = [];
  List<IncomeExpenseEntry> _incomeExpenseEntries = [];

  ChallanProvider(this._storage);

  List<Party> get parties => _parties.where((p) => !p.isDeleted).toList();
  List<Party> get deletedParties => _parties.where((p) => p.isDeleted).toList();
  List<ChallanEntry> get challans => _challans.where((c) => !c.isDeleted).toList();
  List<ChallanEntry> get deletedChallans => _challans.where((c) => c.isDeleted).toList();
  int get recycleBinCount => deletedChallans.length + deletedParties.length;
  List<AuditLogEntry> get auditLogs => List.unmodifiable(_auditLogs);

  bool get isDarkMode => _isDarkMode;
  bool get isLoading => _isLoading;

  String get searchQuery => _searchQuery;
  Set<String> get selectedPartyIds => Set.unmodifiable(_selectedPartyIds);
  String? get selectedSinglePartyId =>
      _selectedPartyIds.length == 1 ? _selectedPartyIds.first : null;

  PaymentOption? get paymentOptionFilter => _paymentOptionFilter;
  String? get statusFilter => _statusFilter;
  String get dateFilter => _dateFilter;
  DateTime? get customStartDate => _customStartDate;
  DateTime? get customEndDate => _customEndDate;
  int? get selectedMonth => _selectedMonth;
  int? get selectedYear => _selectedYear;
  ChallanSortField get sortField => _sortField;
  bool get sortAscending => _sortAscending;
  LedgerViewMode get viewMode => _viewMode;
  LedgerViewMode get partyViewMode => _partyViewMode;
  TextCasingStyle get textCasingStyle => _textCasingStyle;

  String get appLogoBase64 => _appLogoBase64;
  String get profileLogoBase64 => _profileLogoBase64;
  String get companyName => _companyName;
  String get companyTagline => _companyTagline;
  String get adminName => _adminName;
  String get adminRole => _adminRole;
  bool get isSidebarCollapsed => _isSidebarCollapsed;

  void toggleSidebar() {
    _isSidebarCollapsed = !_isSidebarCollapsed;
    _storage.setSidebarCollapsed(_isSidebarCollapsed);
    notifyListeners();
  }

  void setAppLogoBase64(String base64) {
    _appLogoBase64 = base64;
    _storage.setAppLogoBase64(base64);
    notifyListeners();
  }

  void setProfileLogoBase64(String base64) {
    _profileLogoBase64 = base64;
    _storage.setProfileLogoBase64(base64);
    notifyListeners();
  }

  void setCompanyBranding({
    required String name,
    required String tagline,
  }) {
    _companyName = name;
    _companyTagline = tagline;
    _storage.setCompanyName(name);
    _storage.setCompanyTagline(tagline);
    notifyListeners();
  }

  void setAdminProfile({
    required String name,
    required String role,
  }) {
    _adminName = name;
    _adminRole = role;
    _storage.setAdminName(name);
    _storage.setAdminRole(role);
    notifyListeners();
  }

  void setViewMode(LedgerViewMode mode) {
    if (_viewMode == mode) return;
    _viewMode = mode;
    _storage.setLedgerViewMode(mode.name);
    notifyListeners();
  }

  void setPartyViewMode(LedgerViewMode mode) {
    if (_partyViewMode == mode) return;
    _partyViewMode = mode;
    _storage.setPartyViewMode(mode.name);
    notifyListeners();
  }

  void setTextCasingStyle(TextCasingStyle style) {
    if (_textCasingStyle == style) return;
    _textCasingStyle = style;
    _storage.setTextCasingStyle(style.name);
    notifyListeners();
  }

  String formatCasedText(String text) => _textCasingStyle.apply(text);

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    _isDarkMode = _storage.isDarkMode;
    final savedMode = _storage.ledgerViewMode;
    _viewMode = LedgerViewMode.values.firstWhere(
      (e) => e.name == savedMode,
      orElse: () => LedgerViewMode.table,
    );

    final savedPartyMode = _storage.partyViewMode;
    _partyViewMode = LedgerViewMode.values.firstWhere(
      (e) => e.name == savedPartyMode,
      orElse: () => LedgerViewMode.table,
    );

    final savedCasing = _storage.textCasingStyle;
    _textCasingStyle = TextCasingStyle.values.firstWhere(
      (e) => e.name == savedCasing,
      orElse: () => TextCasingStyle.uppercase,
    );

    _appLogoBase64 = _storage.appLogoBase64;
    _profileLogoBase64 = _storage.profileLogoBase64;
    _companyName = _storage.companyName;
    _companyTagline = _storage.companyTagline;
    _adminName = _storage.adminName;
    _adminRole = _storage.adminRole;
    _isSidebarCollapsed = _storage.isSidebarCollapsed;

    _parties = await _storage.loadParties();
    _challans = await _storage.loadChallans();
    _challans.sort((a, b) => b.date.compareTo(a.date));
    _auditLogs = await _storage.loadAuditLogs();
    _incomeExpenseEntries = await _storage.loadIncomeExpenseEntries();

    if (!_storage.isCleanDataMigrated) {
      await _cleanAndSeedRealParties();
      await _storage.markCleanDataMigrated();
      await _storage.markFirstRunComplete();
    } else if (_storage.isFirstRun && _parties.isEmpty) {
      await _seedRealParties();
      await _storage.markFirstRunComplete();
    }

    _isLoading = false;
    notifyListeners();
  }

  // --- FILTER SETTERS ---
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSelectedPartyId(String? partyId) {
    if (partyId == null || partyId.isEmpty) {
      _selectedPartyIds.clear();
    } else {
      _selectedPartyIds = {partyId};
    }
    notifyListeners();
  }

  void togglePartySelection(String partyId) {
    if (_selectedPartyIds.contains(partyId)) {
      _selectedPartyIds.remove(partyId);
    } else {
      _selectedPartyIds.add(partyId);
    }
    notifyListeners();
  }

  void setSelectedPartyIds(Set<String> ids) {
    _selectedPartyIds = Set.from(ids);
    notifyListeners();
  }

  void clearPartySelection() {
    _selectedPartyIds.clear();
    notifyListeners();
  }

  void setPaymentOptionFilter(PaymentOption? option) {
    _paymentOptionFilter = option;
    notifyListeners();
  }

  void setStatusFilter(String? status) {
    _statusFilter = status;
    notifyListeners();
  }

  void setDateFilter(String filter, {DateTime? start, DateTime? end}) {
    _dateFilter = filter;
    _customStartDate = start;
    _customEndDate = end;
    if (filter != 'monthly_picker') {
      _selectedMonth = null;
      _selectedYear = null;
    }
    notifyListeners();
  }

  void setMonthlyFilter(int month, int year) {
    _dateFilter = 'monthly_picker';
    _selectedMonth = month;
    _selectedYear = year;
    _customStartDate = null;
    _customEndDate = null;
    notifyListeners();
  }

  void toggleSortOrder() {
    _sortAscending = !_sortAscending;
    notifyListeners();
  }

  void setSortField(ChallanSortField field) {
    if (_sortField == field) {
      _sortAscending = !_sortAscending;
    } else {
      _sortField = field;
      // When switching to Challan #, default to Ascending (1 to N). When switching to Date, default to Descending (Newest first).
      _sortAscending = field == ChallanSortField.challanNo;
    }
    notifyListeners();
  }

  void setSortOrder({required ChallanSortField field, required bool ascending}) {
    _sortField = field;
    _sortAscending = ascending;
    notifyListeners();
  }

  void setSortAscending(bool ascending) {
    _sortAscending = ascending;
    notifyListeners();
  }

  void resetFilters() {
    _searchQuery = '';
    _selectedPartyIds.clear();
    _paymentOptionFilter = null;
    _statusFilter = null;
    _dateFilter = 'all';
    _customStartDate = null;
    _customEndDate = null;
    _selectedMonth = null;
    _selectedYear = null;
    _sortField = ChallanSortField.date;
    _sortAscending = false;
    notifyListeners();
  }

  // --- FILTERED ENTRIES ---
  List<ChallanEntry> get filteredChallans {
    final now = DateTime.now();

    final result = challans.where((item) {
      // 1. Search Query
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchChallan = item.challanNo.toLowerCase().contains(q);
        final matchParty = item.partyName.toLowerCase().contains(q);
        final matchGst = item.gstBillNo.toLowerCase().contains(q);
        final matchChequeNo =
            item.chequeDetails?.chequeNo.toLowerCase().contains(q) ?? false;
        final matchBank =
            item.chequeDetails?.bankName.toLowerCase().contains(q) ?? false;

        if (!matchChallan &&
            !matchParty &&
            !matchGst &&
            !matchChequeNo &&
            !matchBank) {
          return false;
        }
      }

      // 2. Party Filter (All / Single / Multiple)
      if (_selectedPartyIds.isNotEmpty) {
        if (!_selectedPartyIds.contains(item.partyId)) {
          return false;
        }
      }

      // 3. Payment Option Filter
      if (_paymentOptionFilter != null) {
        if (item.paymentOption != _paymentOptionFilter) return false;
      }

      // 4. Status Filter
      if (_statusFilter != null && _statusFilter != 'all') {
        if (_statusFilter == 'unpaid') {
          if (!item.isPending && !item.hasWarning) return false;
        } else if (_statusFilter == 'overdue') {
          if (item.isFullyPaid || !item.isPaymentOverdue) return false;
        } else if (_statusFilter == 'paid') {
          if (!item.isFullyPaid) return false;
        } else if (_statusFilter == 'bounced') {
          if (item.chequeDetails?.status != ChequeStatus.bounced) return false;
        }
      }

      // 5. Date Filter
      if (_dateFilter == 'today') {
        if (item.date.year != now.year ||
            item.date.month != now.month ||
            item.date.day != now.day) {
          return false;
        }
      } else if (_dateFilter == 'week') {
        final sevenDaysAgo = now.subtract(const Duration(days: 7));
        if (item.date.isBefore(sevenDaysAgo)) return false;
      } else if (_dateFilter == 'month') {
        final thirtyDaysAgo = now.subtract(const Duration(days: 30));
        if (item.date.isBefore(thirtyDaysAgo)) return false;
      } else if (_dateFilter == 'monthly_picker' &&
          _selectedMonth != null &&
          _selectedYear != null) {
        if (item.date.month != _selectedMonth ||
            item.date.year != _selectedYear) {
          return false;
        }
      } else if (_dateFilter == 'custom' &&
          _customStartDate != null &&
          _customEndDate != null) {
        if (item.date.isBefore(_customStartDate!) ||
            item.date.isAfter(_customEndDate!.add(const Duration(days: 1)))) {
          return false;
        }
      }

      return true;
    }).toList();

    // 6. Sorting (Date or Challan #)
    if (_sortField == ChallanSortField.challanNo) {
      result.sort((a, b) => Formatters.compareChallanNumbers(
            a.challanNo,
            b.challanNo,
            ascending: _sortAscending,
          ));
    } else {
      result.sort((a, b) =>
          _sortAscending ? a.date.compareTo(b.date) : b.date.compareTo(a.date));
    }

    return result;
  }

  // --- FILTER SUMMARY DESCRIPTION ---
  String get activeFilterSummary {
    final List<String> parts = [];

    // Party description
    if (_selectedPartyIds.isEmpty) {
      parts.add('All Parties');
    } else if (_selectedPartyIds.length == 1) {
      final p = _parties.firstWhere((p) => p.id == _selectedPartyIds.first,
          orElse: () => Party(id: '', name: 'Selected Party', createdAt: DateTime.now()));
      parts.add('Party: ${p.name}');
    } else {
      parts.add('${_selectedPartyIds.length} Selected Parties');
    }

    // Date description
    if (_dateFilter == 'monthly_picker' && _selectedMonth != null && _selectedYear != null) {
      final date = DateTime(_selectedYear!, _selectedMonth!);
      parts.add('Month: ${DateFormat('MMMM yyyy').format(date)}');
    } else if (_dateFilter == 'today') {
      parts.add('Period: Today');
    } else if (_dateFilter == 'week') {
      parts.add('Period: Last 7 Days');
    } else if (_dateFilter == 'month') {
      parts.add('Period: Last 30 Days');
    } else if (_dateFilter == 'custom' && _customStartDate != null && _customEndDate != null) {
      parts.add(
          'Period: ${DateFormat('dd/MM/yy').format(_customStartDate!)} - ${DateFormat('dd/MM/yy').format(_customEndDate!)}');
    } else {
      parts.add('Period: All Time');
    }

    // Payment & Status
    if (_paymentOptionFilter != null) {
      parts.add('Mode: ${_paymentOptionFilter!.label}');
    }
    if (_statusFilter != null && _statusFilter != 'all') {
      if (_statusFilter == 'overdue') {
        parts.add('Status: OVERDUE 🚨');
      } else {
        parts.add('Status: ${_statusFilter!.toUpperCase()}');
      }
    }

    if (_sortField == ChallanSortField.challanNo) {
      parts.add('Sort: Challan # (${_sortAscending ? "1 → 9 (Asc)" : "9 → 1 (Desc)"})');
    } else {
      parts.add('Sort: Date (${_sortAscending ? "Oldest First (Asc)" : "Newest First (Desc)"})');
    }

    return parts.join(' • ');
  }

  // Available unique months from data (for month dropdown)
  List<DateTime> get availableMonths {
    final Set<String> seen = {};
    final List<DateTime> list = [];
    for (var c in _challans) {
      final key = '${c.date.year}-${c.date.month}';
      if (!seen.contains(key)) {
        seen.add(key);
        list.add(DateTime(c.date.year, c.date.month, 1));
      }
    }
    list.sort((a, b) => b.compareTo(a)); // Newest month first
    return list;
  }

  // --- SUMMARY TOTALS ---
  double get totalChallanAmount =>
      filteredChallans.fold(0.0, (sum, item) => sum + item.challanAmount);

  double get totalDiscountAmount =>
      filteredChallans.fold(0.0, (sum, item) => sum + item.discountAmount);

  double get totalFinalAmount =>
      filteredChallans.fold(0.0, (sum, item) => sum + item.finalAmount);

  double get totalPaidAmount =>
      filteredChallans.fold(0.0, (sum, item) => sum + item.paidAmount);

  double get totalGstAmount =>
      filteredChallans.fold(0.0, (sum, item) => sum + item.gstAmount);

  double get totalUnpaidAmount {
    double sum = 0.0;
    for (var c in filteredChallans) {
      if (c.paymentOption == PaymentOption.cash) {
        sum += c.remainingAmount;
      } else if (c.paymentOption == PaymentOption.cheque &&
          c.chequeDetails?.status != ChequeStatus.cleared) {
        sum += c.finalAmount;
      }
    }
    return sum;
  }

  double get totalReceivedAmount {
    double sum = 0.0;
    for (var c in filteredChallans) {
      if (c.paymentOption == PaymentOption.cash) {
        sum += c.paidAmount;
      } else if (c.paymentOption == PaymentOption.cheque &&
          c.chequeDetails?.status == ChequeStatus.cleared) {
        sum += c.finalAmount;
      }
    }
    return sum;
  }

  int get unpaidWarningCount =>
      filteredChallans.where((c) => c.hasWarning).length;

  /// Active overdue unpaid challans (due date passed and entry is not fully paid)
  List<ChallanEntry> get overdueChallans =>
      challans.where((c) => !c.isFullyPaid && c.isPaymentOverdue).toList();

  int get overdueCount => overdueChallans.length;

  double get overdueAmount {
    double sum = 0.0;
    for (var c in overdueChallans) {
      if (c.paymentOption == PaymentOption.cash) {
        sum += c.remainingAmount;
      } else if (c.paymentOption == PaymentOption.cheque &&
          c.chequeDetails?.status != ChequeStatus.cleared) {
        sum += c.finalAmount;
      }
    }
    return sum;
  }

  // --- PROFIT & LOSS / INCOME & EXPENSES ---
  List<IncomeExpenseEntry> get incomeExpenseEntries =>
      _incomeExpenseEntries.where((e) => !e.isDeleted).toList();

  List<IncomeExpenseEntry> get allExpenses =>
      incomeExpenseEntries.where((e) => e.isExpense).toList();

  List<IncomeExpenseEntry> get allCustomIncomes =>
      incomeExpenseEntries.where((e) => e.isIncome).toList();

  Future<void> addIncomeExpenseEntry(IncomeExpenseEntry entry) async {
    _incomeExpenseEntries.insert(0, entry);
    await _storage.saveIncomeExpenseEntries(_incomeExpenseEntries);
    await logAction(
      action: AuditAction.create,
      entityType: AuditEntityType.challan,
      entityId: entry.id,
      entityTitle: '${entry.type.name.toUpperCase()}: ${entry.particular}',
      performedBy: 'OM MAVTAR',
      userRole: 'MASTER',
      description: 'Added ${entry.type.name} entry: ${entry.particular} (${Formatters.currency(entry.amount)})',
    );
    notifyListeners();
  }

  Future<void> updateIncomeExpenseEntry(IncomeExpenseEntry updated) async {
    final idx = _incomeExpenseEntries.indexWhere((e) => e.id == updated.id);
    if (idx != -1) {
      _incomeExpenseEntries[idx] = updated;
      await _storage.saveIncomeExpenseEntries(_incomeExpenseEntries);
      await logAction(
        action: AuditAction.update,
        entityType: AuditEntityType.challan,
        entityId: updated.id,
        entityTitle: '${updated.type.name.toUpperCase()}: ${updated.particular}',
        performedBy: 'OM MAVTAR',
        userRole: 'MASTER',
        description: 'Updated ${updated.type.name} entry: ${updated.particular} (${Formatters.currency(updated.amount)})',
      );
      notifyListeners();
    }
  }

  Future<void> deleteIncomeExpenseEntry(String id) async {
    final idx = _incomeExpenseEntries.indexWhere((e) => e.id == id);
    if (idx != -1) {
      final removed = _incomeExpenseEntries[idx];
      _incomeExpenseEntries.removeAt(idx);
      await _storage.saveIncomeExpenseEntries(_incomeExpenseEntries);
      await logAction(
        action: AuditAction.permanentDelete,
        entityType: AuditEntityType.challan,
        entityId: removed.id,
        entityTitle: '${removed.type.name.toUpperCase()}: ${removed.particular}',
        performedBy: 'OM MAVTAR',
        userRole: 'MASTER',
        description: 'Deleted ${removed.type.name} entry: ${removed.particular}',
      );
      notifyListeners();
    }
  }

  /// All unique months formatted as 'yyyy-MM' present across challans & expense entries
  List<String> get availableProfitLossMonths {
    final Set<String> months = {};
    final now = DateTime.now();
    months.add('${now.year}-${now.month.toString().padLeft(2, '0')}');

    for (var c in challans) {
      months.add('${c.date.year}-${c.date.month.toString().padLeft(2, '0')}');
    }
    for (var e in incomeExpenseEntries) {
      months.add('${e.date.year}-${e.date.month.toString().padLeft(2, '0')}');
    }

    final list = months.toList();
    list.sort((a, b) => b.compareTo(a)); // Newest first
    return list;
  }

  ProfitLossCalculation computeProfitLoss({
    Set<String>? selectedMonthKeys,
    String searchQuery = '',
  }) {
    final cleanQuery = searchQuery.trim().toLowerCase();

    // 1. Filter Expenses
    final expList = <IncomeExpenseEntry>[];
    for (var e in allExpenses) {
      if (selectedMonthKeys != null && selectedMonthKeys.isNotEmpty) {
        final key = '${e.date.year}-${e.date.month.toString().padLeft(2, '0')}';
        if (!selectedMonthKeys.contains(key)) continue;
      }
      if (cleanQuery.isNotEmpty) {
        final matchesPart = e.particular.toLowerCase().contains(cleanQuery);
        final matchesCat = e.category.toLowerCase().contains(cleanQuery);
        if (!matchesPart && !matchesCat) continue;
      }
      expList.add(e);
    }
    expList.sort((a, b) => b.date.compareTo(a.date));

    // 2. Filter Incomes (Challan collections from parties + custom incomes)
    final partyMap = <String, double>{};
    for (var c in challans) {
      if (selectedMonthKeys != null && selectedMonthKeys.isNotEmpty) {
        final key = '${c.date.year}-${c.date.month.toString().padLeft(2, '0')}';
        if (!selectedMonthKeys.contains(key)) continue;
      }
      if (c.paidAmount > 0) {
        final pName = c.partyName.trim();
        partyMap[pName] = (partyMap[pName] ?? 0.0) + c.paidAmount;
      }
    }

    final incList = <IncomeExpenseEntry>[];
    partyMap.forEach((partyName, amt) {
      if (cleanQuery.isNotEmpty && !partyName.toLowerCase().contains(cleanQuery)) {
        return;
      }
      incList.add(IncomeExpenseEntry(
        id: 'party_inc_$partyName',
        type: EntryType.income,
        date: DateTime.now(),
        particular: partyName,
        amount: amt,
        category: 'Party Challan Collection',
        paymentMode: 'Ledger Collection',
        createdAt: DateTime.now(),
      ));
    });

    for (var e in allCustomIncomes) {
      if (selectedMonthKeys != null && selectedMonthKeys.isNotEmpty) {
        final key = '${e.date.year}-${e.date.month.toString().padLeft(2, '0')}';
        if (!selectedMonthKeys.contains(key)) continue;
      }
      if (cleanQuery.isNotEmpty) {
        final matchesPart = e.particular.toLowerCase().contains(cleanQuery);
        final matchesCat = e.category.toLowerCase().contains(cleanQuery);
        if (!matchesPart && !matchesCat) continue;
      }
      incList.add(e);
    }
    incList.sort((a, b) => b.amount.compareTo(a.amount));

    final totalExp = expList.fold(0.0, (sum, e) => sum + e.amount);
    final totalInc = incList.fold(0.0, (sum, e) => sum + e.amount);
    final net = totalInc - totalExp;

    return ProfitLossCalculation(
      expenses: expList,
      incomes: incList,
      totalExpenses: totalExp,
      totalIncome: totalInc,
      netAmount: net.abs(),
      isProfit: net >= 0,
    );
  }

  // --- AUDIT TRAIL & HISTORY LOGGING ---
  Future<void> addAuditLog(AuditLogEntry entry) async {
    _auditLogs.insert(0, entry);
    if (_auditLogs.length > 2000) {
      _auditLogs = _auditLogs.sublist(0, 2000);
    }
    await _storage.saveAuditLogs(_auditLogs);
    notifyListeners();
  }

  Future<void> logAction({
    required AuditAction action,
    required AuditEntityType entityType,
    required String entityId,
    required String entityTitle,
    String performedBy = 'OM MAVTAR',
    String userRole = 'MASTER',
    required String description,
    Map<String, dynamic> metadata = const {},
  }) async {
    final entry = AuditLogEntry(
      id: _uuid.v4(),
      timestamp: DateTime.now(),
      action: action,
      entityType: entityType,
      entityId: entityId,
      entityTitle: entityTitle,
      performedBy: performedBy,
      userRole: userRole,
      description: description,
      metadata: metadata,
    );
    await addAuditLog(entry);
  }

  Future<void> clearAuditLogs() async {
    _auditLogs.clear();
    await _storage.saveAuditLogs(_auditLogs);
    notifyListeners();
  }

  // --- CRUD & RECYCLE BIN: PARTIES ---
  Future<Party> addParty({
    required String name,
    String phone = '',
    String address = '',
    String gstNumber = '',
    String performedBy = 'OM MAVTAR',
    String userRole = 'MASTER',
  }) async {
    final party = Party(
      id: _uuid.v4(),
      name: name.trim(),
      phone: phone.trim(),
      address: address.trim(),
      gstNumber: gstNumber.trim(),
      createdAt: DateTime.now(),
      createdBy: performedBy,
    );
    _parties.add(party);
    await _storage.saveParties(_parties);

    await logAction(
      action: AuditAction.create,
      entityType: AuditEntityType.party,
      entityId: party.id,
      entityTitle: party.name,
      performedBy: performedBy,
      userRole: userRole,
      description: 'Registered new commercial party: ${party.name}',
    );

    notifyListeners();
    return party;
  }

  Future<void> updateParty(Party updated, {String performedBy = 'OM MAVTAR', String userRole = 'MASTER'}) async {
    final idx = _parties.indexWhere((p) => p.id == updated.id);
    if (idx != -1) {
      _parties[idx] = updated.copyWith(
        lastModifiedBy: performedBy,
        lastModifiedAt: DateTime.now(),
      );
      for (int i = 0; i < _challans.length; i++) {
        if (_challans[i].partyId == updated.id) {
          _challans[i] = _challans[i].copyWith(partyName: updated.name);
        }
      }
      await _storage.saveParties(_parties);
      await _storage.saveChallans(_challans);

      await logAction(
        action: AuditAction.update,
        entityType: AuditEntityType.party,
        entityId: updated.id,
        entityTitle: updated.name,
        performedBy: performedBy,
        userRole: userRole,
        description: 'Updated party profile details for ${updated.name}',
      );

      notifyListeners();
    }
  }

  Future<void> moveToBinParty(String partyId, {String performedBy = 'OM MAVTAR', String userRole = 'MASTER'}) async {
    final idx = _parties.indexWhere((p) => p.id == partyId);
    if (idx != -1) {
      final p = _parties[idx];
      _parties[idx] = p.copyWith(
        isDeleted: true,
        deletedAt: DateTime.now(),
        deletedBy: performedBy,
      );
      _selectedPartyIds.remove(partyId);
      await _storage.saveParties(_parties);

      await logAction(
        action: AuditAction.softDelete,
        entityType: AuditEntityType.party,
        entityId: p.id,
        entityTitle: p.name,
        performedBy: performedBy,
        userRole: userRole,
        description: 'Moved party ${p.name} to Recycle Bin',
      );

      notifyListeners();
    }
  }

  Future<void> restoreParty(String partyId, {String performedBy = 'OM MAVTAR', String userRole = 'MASTER'}) async {
    final idx = _parties.indexWhere((p) => p.id == partyId);
    if (idx != -1) {
      final p = _parties[idx];
      _parties[idx] = p.copyWith(
        isDeleted: false,
        clearDeletedAt: true,
      );
      await _storage.saveParties(_parties);

      await logAction(
        action: AuditAction.restore,
        entityType: AuditEntityType.party,
        entityId: p.id,
        entityTitle: p.name,
        performedBy: performedBy,
        userRole: userRole,
        description: 'Restored party ${p.name} from Recycle Bin to active directory',
      );

      notifyListeners();
    }
  }

  Future<void> deletePermanentlyParty(String partyId, {String performedBy = 'OM MAVTAR', String userRole = 'MASTER'}) async {
    final idx = _parties.indexWhere((p) => p.id == partyId);
    final partyName = idx != -1 ? _parties[idx].name : partyId;
    _parties.removeWhere((p) => p.id == partyId);
    _selectedPartyIds.remove(partyId);
    await _storage.saveParties(_parties);

    await logAction(
      action: AuditAction.permanentDelete,
      entityType: AuditEntityType.party,
      entityId: partyId,
      entityTitle: partyName,
      performedBy: performedBy,
      userRole: userRole,
      description: 'Permanently purged party record for $partyName from database',
    );

    notifyListeners();
  }

  /// Backward compatibility: Deleting a party moves it to the Recycle Bin
  Future<void> deleteParty(String partyId) => moveToBinParty(partyId);

  // --- CRUD & RECYCLE BIN: CHALLAN ENTRIES ---
  Future<ChallanEntry> addChallan({
    required DateTime date,
    required String challanNo,
    required String partyId,
    required String partyName,
    required double challanAmount,
    double discountAmount = 0.0,
    required double finalAmount,
    double? paidAmount,
    String gstBillNo = '',
    double gstAmount = 0.0,
    PaymentOption paymentOption = PaymentOption.cash,
    bool isCashPaid = true,
    ChequeDetails? chequeDetails,
    DateTime? paymentDueDate,
    String notes = '',
    String performedBy = 'OM MAVTAR',
    String userRole = 'MASTER',
  }) async {
    final entry = ChallanEntry(
      id: _uuid.v4(),
      date: date,
      challanNo: challanNo.trim(),
      partyId: partyId,
      partyName: partyName.trim(),
      challanAmount: challanAmount,
      discountAmount: discountAmount,
      finalAmount: finalAmount,
      paidAmount: paidAmount,
      gstBillNo: gstBillNo.trim(),
      gstAmount: gstAmount,
      paymentOption: paymentOption,
      isCashPaid: isCashPaid,
      chequeDetails: chequeDetails,
      paymentDueDate: paymentDueDate,
      notes: notes.trim(),
      createdAt: DateTime.now(),
      createdBy: performedBy,
    );

    _challans.insert(0, entry);
    await _storage.saveChallans(_challans);

    await logAction(
      action: AuditAction.create,
      entityType: AuditEntityType.challan,
      entityId: entry.id,
      entityTitle: 'Challan #${entry.challanNo} (${entry.partyName})',
      performedBy: performedBy,
      userRole: userRole,
      description: 'Created delivery challan #${entry.challanNo} for ${entry.partyName} (Final Amt: ₹${Formatters.currency(entry.finalAmount)})',
    );

    notifyListeners();
    return entry;
  }

  Future<void> updateChallan(ChallanEntry updated, {String performedBy = 'OM MAVTAR', String userRole = 'MASTER'}) async {
    final idx = _challans.indexWhere((c) => c.id == updated.id);
    if (idx != -1) {
      final stamped = updated.copyWith(
        lastModifiedBy: performedBy,
        lastModifiedAt: DateTime.now(),
      );
      _challans[idx] = stamped;
      await _storage.saveChallans(_challans);

      await logAction(
        action: AuditAction.update,
        entityType: AuditEntityType.challan,
        entityId: stamped.id,
        entityTitle: 'Challan #${stamped.challanNo} (${stamped.partyName})',
        performedBy: performedBy,
        userRole: userRole,
        description: 'Updated challan #${stamped.challanNo} details (Final Amt: ₹${Formatters.currency(stamped.finalAmount)})',
      );

      notifyListeners();
    }
  }

  Future<void> moveToBinChallan(String id, {String performedBy = 'OM MAVTAR', String userRole = 'MASTER'}) async {
    final idx = _challans.indexWhere((c) => c.id == id);
    if (idx != -1) {
      final c = _challans[idx];
      _challans[idx] = c.copyWith(
        isDeleted: true,
        deletedAt: DateTime.now(),
        deletedBy: performedBy,
      );
      await _storage.saveChallans(_challans);

      await logAction(
        action: AuditAction.softDelete,
        entityType: AuditEntityType.challan,
        entityId: c.id,
        entityTitle: 'Challan #${c.challanNo} (${c.partyName})',
        performedBy: performedBy,
        userRole: userRole,
        description: 'Moved challan #${c.challanNo} to Recycle Bin',
      );

      notifyListeners();
    }
  }

  Future<void> restoreChallan(String id, {String performedBy = 'OM MAVTAR', String userRole = 'MASTER'}) async {
    final idx = _challans.indexWhere((c) => c.id == id);
    if (idx != -1) {
      final c = _challans[idx];
      _challans[idx] = c.copyWith(
        isDeleted: false,
        clearDeletedAt: true,
      );
      await _storage.saveChallans(_challans);

      await logAction(
        action: AuditAction.restore,
        entityType: AuditEntityType.challan,
        entityId: c.id,
        entityTitle: 'Challan #${c.challanNo} (${c.partyName})',
        performedBy: performedBy,
        userRole: userRole,
        description: 'Restored challan #${c.challanNo} from Recycle Bin to active ledger',
      );

      notifyListeners();
    }
  }

  Future<void> deletePermanentlyChallan(String id, {String performedBy = 'OM MAVTAR', String userRole = 'MASTER'}) async {
    final idx = _challans.indexWhere((c) => c.id == id);
    final title = idx != -1 ? 'Challan #${_challans[idx].challanNo} (${_challans[idx].partyName})' : 'Challan ID $id';
    _challans.removeWhere((c) => c.id == id);
    await _storage.saveChallans(_challans);

    await logAction(
      action: AuditAction.permanentDelete,
      entityType: AuditEntityType.challan,
      entityId: id,
      entityTitle: title,
      performedBy: performedBy,
      userRole: userRole,
      description: 'Permanently purged challan record ($title) from database',
    );

    notifyListeners();
  }

  /// Backward compatibility: Deleting a challan moves it to the Recycle Bin
  Future<void> deleteChallan(String id) => moveToBinChallan(id);

  // --- EMPTY RECYCLE BIN ---
  Future<void> emptyRecycleBin({String performedBy = 'OM MAVTAR', String userRole = 'MASTER'}) async {
    final count = deletedChallans.length + deletedParties.length;
    _challans.removeWhere((c) => c.isDeleted);
    _parties.removeWhere((p) => p.isDeleted);
    await _storage.saveChallans(_challans);
    await _storage.saveParties(_parties);

    await logAction(
      action: AuditAction.permanentDelete,
      entityType: AuditEntityType.settings,
      entityId: 'recycle_bin',
      entityTitle: 'Recycle Bin',
      performedBy: performedBy,
      userRole: userRole,
      description: 'Emptied Recycle Bin: permanently purged $count soft-deleted records',
    );

    notifyListeners();
  }

  // --- THEME ---
  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    await _storage.setDarkMode(_isDarkMode);
    notifyListeners();
  }

  // --- BACKUP & RESTORE ---
  Future<String> exportBackup() async {
    return await _storage.saveBackupToDocuments();
  }

  Future<List<File>> getRecentBackupFiles() async {
    return await _storage.getRecentBackupFiles();
  }

  static bool isSameChallanContent(ChallanEntry a, ChallanEntry b) {
    final sameDate = a.date.year == b.date.year &&
        a.date.month == b.date.month &&
        a.date.day == b.date.day;
    if (!sameDate) return false;

    if (a.challanNo.trim().toUpperCase() != b.challanNo.trim().toUpperCase()) {
      return false;
    }

    if (a.partyName.trim().toUpperCase() != b.partyName.trim().toUpperCase()) {
      return false;
    }

    if ((a.finalAmount - b.finalAmount).abs() > 0.01) return false;
    if ((a.challanAmount - b.challanAmount).abs() > 0.01) return false;

    if (a.gstBillNo.trim().toUpperCase() != b.gstBillNo.trim().toUpperCase()) {
      return false;
    }
    if ((a.gstAmount - b.gstAmount).abs() > 0.01) return false;

    if (a.paymentOption != b.paymentOption) return false;
    if (a.isCashPaid != b.isCashPaid) return false;

    return true;
  }

  static bool isSamePartyContent(Party a, Party b) {
    return a.name.trim().toUpperCase() == b.name.trim().toUpperCase() &&
        a.phone.trim() == b.phone.trim() &&
        a.address.trim().toUpperCase() == b.address.trim().toUpperCase() &&
        a.gstNumber.trim().toUpperCase() == b.gstNumber.trim().toUpperCase();
  }

  BackupAnalysisResult analyzeBackupJson(String jsonString) {
    try {
      final trimmed = jsonString.trim();
      if (trimmed.isEmpty) {
        return BackupAnalysisResult(
          isValid: false,
          errorMessage: 'Backup content is empty.',
        );
      }
      final decoded = jsonDecode(trimmed);
      List<dynamic> rawChallans = [];
      List<dynamic> rawParties = [];
      List<dynamic> rawEntries = [];
      Map<String, dynamic>? brandingMap;
      bool isPartial = false;

      if (decoded is List) {
        isPartial = true;
        for (var item in decoded) {
          if (item is Map) {
            final m = Map<String, dynamic>.from(item);
            if (m.containsKey('challanNo') ||
                m.containsKey('challanAmount') ||
                m.containsKey('partyName')) {
              rawChallans.add(m);
            } else if (m.containsKey('name') || m.containsKey('gstNumber')) {
              rawParties.add(m);
            } else {
              rawChallans.add(m);
            }
          }
        }
      } else if (decoded is Map) {
        final map = Map<String, dynamic>.from(decoded);

        if (map['challans'] is List) {
          rawChallans = map['challans'] as List;
        } else if (map['transactions'] is List) {
          final txList = map['transactions'] as List;
          rawChallans = txList.map((tx) {
            if (tx is Map) {
              final m = Map<String, dynamic>.from(tx);
              final amt = (m['amount'] as num?)?.toDouble() ?? 0.0;
              return {
                'id': m['id'] ?? 'migrated_${DateTime.now().millisecondsSinceEpoch}',
                'challanNo': m['referenceNo'] ?? m['id'] ?? 'CH-LEGACY',
                'partyId': m['partyId'] ?? '',
                'partyName': m['partyName'] ?? 'Legacy Party',
                'date': m['date'] ?? DateTime.now().toIso8601String(),
                'challanAmount': amt,
                'hasGstBill': false,
                'gstRate': 0.0,
                'gstAmount': 0.0,
                'finalAmount': amt,
                'paidAmount': amt,
                'paymentOption': 'cash',
                'paymentStatus': 'paid',
                'notes': m['description'] ?? '',
                'createdAt': m['createdAt'] ?? DateTime.now().toIso8601String(),
                'createdBy': 'OM MAVTAR',
              };
            }
            return tx;
          }).toList();
          isPartial = true;
        } else if (map['entries'] is List) {
          rawChallans = map['entries'] as List;
          isPartial = true;
        } else if (map['records'] is List) {
          rawChallans = map['records'] as List;
          isPartial = true;
        } else if (map['data'] is List) {
          rawChallans = map['data'] as List;
          isPartial = true;
        }

        if (map['parties'] is List) {
          rawParties = map['parties'] as List;
        } else if (map['customers'] is List) {
          rawParties = map['customers'] as List;
          isPartial = true;
        } else if (map['clients'] is List) {
          rawParties = map['clients'] as List;
          isPartial = true;
        }

        if (map['branding'] is Map) {
          brandingMap = Map<String, dynamic>.from(map['branding'] as Map);
        } else if (map['settings'] is Map) {
          brandingMap = Map<String, dynamic>.from(map['settings'] as Map);
        } else if (map['profile'] is Map) {
          final p = Map<String, dynamic>.from(map['profile'] as Map);
          brandingMap = {
            'companyName': p['groupName'] ?? 'OM Mavtar Group',
            'adminName': p['ownerName'] ?? 'OM Mavtar Admin',
          };
        }

        if (map['incomeExpenseEntries'] is List) {
          rawEntries = map['incomeExpenseEntries'] as List;
        } else if (map['dayEntries'] is List) {
          final deList = map['dayEntries'] as List;
          rawEntries = deList.map((de) {
            if (de is Map) {
              final m = Map<String, dynamic>.from(de);
              final typeStr = (m['type'] as String?)?.toLowerCase() ?? 'expense';
              return {
                'id': m['id'] ?? 'de_${DateTime.now().millisecondsSinceEpoch}',
                'type': typeStr == 'income' ? 'income' : 'expense',
                'date': m['date'] ?? DateTime.now().toIso8601String(),
                'particular': m['description'] ?? m['particular'] ?? '',
                'amount': (m['amount'] as num?)?.toDouble() ?? 0.0,
                'category': m['category'] ?? (typeStr == 'income' ? 'Income' : 'Expense'),
                'paymentMode': m['paymentMode'] ?? 'Cash',
                'createdAt': m['createdAt'] ?? DateTime.now().toIso8601String(),
                'createdBy': 'OM MAVTAR',
              };
            }
            return de;
          }).toList();
        }
      } else {
        return BackupAnalysisResult(
          isValid: false,
          errorMessage: 'Unrecognized JSON data format. Expected JSON Object or Array.',
        );
      }

      final parsedChallans = <ChallanEntry>[];
      for (var item in rawChallans) {
        if (item is Map) {
          try {
            final c = ChallanEntry.fromJson(Map<String, dynamic>.from(item));
            parsedChallans.add(c);
          } catch (e) {
            debugPrint('Skipping malformed challan entry: $e');
          }
        }
      }

      final parsedParties = <Party>[];
      for (var item in rawParties) {
        if (item is Map) {
          try {
            final p = Party.fromJson(Map<String, dynamic>.from(item));
            parsedParties.add(p);
          } catch (e) {
            debugPrint('Skipping malformed party entry: $e');
          }
        }
      }

      if (parsedParties.isEmpty && parsedChallans.isNotEmpty) {
        final Set<String> seenNames = {};
        for (var c in parsedChallans) {
          final cleanName = c.partyName.trim();
          if (cleanName.isNotEmpty && !seenNames.contains(cleanName.toUpperCase())) {
            seenNames.add(cleanName.toUpperCase());
            final partyId = c.partyId.isNotEmpty ? c.partyId : 'party_${_uuid.v4()}';
            parsedParties.add(Party(
              id: partyId,
              name: cleanName,
              createdAt: DateTime.now(),
            ));
          }
        }
      }

      final parsedEntries = <IncomeExpenseEntry>[];
      for (var item in rawEntries) {
        if (item is Map) {
          try {
            parsedEntries.add(IncomeExpenseEntry.fromJson(Map<String, dynamic>.from(item)));
          } catch (_) {}
        }
      }

      if (parsedChallans.isEmpty && parsedParties.isEmpty && parsedEntries.isEmpty && brandingMap == null) {
        return BackupAnalysisResult(
          isValid: false,
          errorMessage: 'No challan records or parties could be identified in the provided file.',
        );
      }

      return BackupAnalysisResult(
        isValid: true,
        challans: parsedChallans,
        parties: parsedParties,
        incomeExpenseEntries: parsedEntries,
        branding: brandingMap,
        isPartialOrLegacy: isPartial,
        totalChallans: parsedChallans.length,
        totalParties: parsedParties.length,
      );
    } catch (e) {
      return BackupAnalysisResult(
        isValid: false,
        errorMessage: 'JSON parse error: $e',
      );
    }
  }

  Future<BackupImportSummary> importBackupWithStrategy({
    required String jsonString,
    required BackupImportMode mode,
    bool importBranding = true,
    String performedBy = 'OM MAVTAR',
  }) async {
    final analysis = analyzeBackupJson(jsonString);
    if (!analysis.isValid) {
      return BackupImportSummary(
        success: false,
        mode: mode,
        message: analysis.errorMessage ?? 'Invalid backup JSON data.',
      );
    }

    if (mode == BackupImportMode.replace) {
      // 1. CLEAN REPLACE (Overwrites database with backup data)
      final newParties = List<Party>.from(analysis.parties);
      final newChallans = <ChallanEntry>[];

      final partyMap = {for (var p in newParties) p.name.trim().toUpperCase(): p};
      for (var c in analysis.challans) {
        var resolvedPartyId = c.partyId;
        if (resolvedPartyId.isEmpty || !newParties.any((p) => p.id == resolvedPartyId)) {
          final existingP = partyMap[c.partyName.trim().toUpperCase()];
          if (existingP != null) {
            resolvedPartyId = existingP.id;
          } else if (c.partyName.trim().isNotEmpty) {
            final np = Party(
              id: 'party_${_uuid.v4()}',
              name: c.partyName.trim(),
              createdAt: DateTime.now(),
            );
            newParties.add(np);
            partyMap[np.name.trim().toUpperCase()] = np;
            resolvedPartyId = np.id;
          }
        }
        newChallans.add(c.copyWith(partyId: resolvedPartyId));
      }

      // Sort DESCENDING by date (newest/current date first)
      newChallans.sort((a, b) => b.date.compareTo(a.date));

      _parties = newParties;
      _challans = newChallans;
      _sortAscending = false;

      await _storage.saveParties(_parties);
      await _storage.saveChallans(_challans);
      _incomeExpenseEntries = List.from(analysis.incomeExpenseEntries);
      await _storage.saveIncomeExpenseEntries(_incomeExpenseEntries);

      if (importBranding && analysis.branding != null) {
        await _applyBranding(analysis.branding!);
      }

      addAuditLog(AuditLogEntry(
        id: _uuid.v4(),
        timestamp: DateTime.now(),
        action: AuditAction.settingsChange,
        entityType: AuditEntityType.settings,
        entityId: 'backup_restore_replace',
        entityTitle: 'Backup Restored (Clean Replace)',
        performedBy: performedBy,
        userRole: 'MASTER',
        description: 'Clean overwrite with backup: ${_challans.length} challans, ${_parties.length} parties loaded.',
      ));

      notifyListeners();

      return BackupImportSummary(
        success: true,
        mode: mode,
        challansAdded: _challans.length,
        partiesAdded: _parties.length,
        totalActiveChallans: _challans.length,
        totalActiveParties: _parties.length,
        message: 'Database replaced successfully with ${_challans.length} challans and ${_parties.length} parties.',
      );
    } else {
      // 2. COMBINE & MERGE WITH DEDUPLICATION AND COLLISION RESOLUTION
      int challansAdded = 0;
      int challansDuplicateSkipped = 0;
      int partiesAdded = 0;
      int partiesDuplicateSkipped = 0;

      final existingPartyById = {for (var p in _parties) p.id: p};
      final existingPartyByName = {for (var p in _parties) p.name.trim().toUpperCase(): p};
      final Map<String, String> partyIdRemap = {};

      for (var party in analysis.parties) {
        if (existingPartyById.containsKey(party.id)) {
          final existing = existingPartyById[party.id]!;
          if (isSamePartyContent(existing, party)) {
            partyIdRemap[party.id] = existing.id;
            partiesDuplicateSkipped++;
          } else {
            // ID matches but data is different -> Assign new primary ID to preserve both
            final newId = 'party_${_uuid.v4()}';
            final newParty = party.copyWith(id: newId);
            _parties.add(newParty);
            partyIdRemap[party.id] = newId;
            existingPartyById[newId] = newParty;
            existingPartyByName[newParty.name.trim().toUpperCase()] = newParty;
            partiesAdded++;
          }
        } else if (existingPartyByName.containsKey(party.name.trim().toUpperCase())) {
          final existing = existingPartyByName[party.name.trim().toUpperCase()]!;
          if (isSamePartyContent(existing, party)) {
            partyIdRemap[party.id] = existing.id;
            partiesDuplicateSkipped++;
          } else {
            final newId = 'party_${_uuid.v4()}';
            final newParty = party.copyWith(id: newId);
            _parties.add(newParty);
            partyIdRemap[party.id] = newId;
            existingPartyById[newId] = newParty;
            partiesAdded++;
          }
        } else {
          _parties.add(party);
          partyIdRemap[party.id] = party.id;
          existingPartyById[party.id] = party;
          existingPartyByName[party.name.trim().toUpperCase()] = party;
          partiesAdded++;
        }
      }

      // Merge Challans
      final existingChallanById = {for (var c in _challans) c.id: c};

      for (var c in analysis.challans) {
        var resolvedPartyId = partyIdRemap[c.partyId] ?? c.partyId;
        if (resolvedPartyId.isEmpty || !_parties.any((p) => p.id == resolvedPartyId)) {
          Party? p;
          final cleanPartyName = c.partyName.trim().toUpperCase();
          for (var item in _parties) {
            if (item.name.trim().toUpperCase() == cleanPartyName) {
              p = item;
              break;
            }
          }
          if (p != null) {
            resolvedPartyId = p.id;
          } else if (c.partyName.trim().isNotEmpty) {
            final newP = Party(
              id: 'party_${_uuid.v4()}',
              name: c.partyName.trim(),
              createdAt: DateTime.now(),
            );
            _parties.add(newP);
            resolvedPartyId = newP.id;
            partiesAdded++;
          }
        }
        c = c.copyWith(partyId: resolvedPartyId);

        // Deduplication & Collision checks
        if (existingChallanById.containsKey(c.id)) {
          final existing = existingChallanById[c.id]!;
          if (isSameChallanContent(existing, c)) {
            // Same ID and same data -> Duplicate! Do NOT duplicate!
            challansDuplicateSkipped++;
          } else {
            // Same ID but different data -> Generate NEW primary ID so old data is NOT removed!
            final newId = _uuid.v4();
            final newChallan = c.copyWith(id: newId);
            _challans.add(newChallan);
            existingChallanById[newId] = newChallan;
            challansAdded++;
          }
        } else {
          // Check if any existing challan already has the exact same content
          final duplicateExists = _challans.any((existing) => isSameChallanContent(existing, c));
          if (duplicateExists) {
            challansDuplicateSkipped++;
          } else {
            _challans.add(c);
            existingChallanById[c.id] = c;
            challansAdded++;
          }
        }
      }

      // Sort DESCENDING by date (newest/current date first)
      _challans.sort((a, b) => b.date.compareTo(a.date));
      _sortAscending = false;

      await _storage.saveParties(_parties);
      await _storage.saveChallans(_challans);
      // Merge income/expense entries without duplicates
      for (var entry in analysis.incomeExpenseEntries) {
        if (!_incomeExpenseEntries.any((e) => e.id == entry.id)) {
          _incomeExpenseEntries.add(entry);
        }
      }
      await _storage.saveIncomeExpenseEntries(_incomeExpenseEntries);

      if (importBranding && analysis.branding != null) {
        await _applyBranding(analysis.branding!);
      }

      addAuditLog(AuditLogEntry(
        id: _uuid.v4(),
        timestamp: DateTime.now(),
        action: AuditAction.settingsChange,
        entityType: AuditEntityType.settings,
        entityId: 'backup_restore_merge',
        entityTitle: 'Backup Merged (Combine)',
        performedBy: performedBy,
        userRole: 'MASTER',
        description: 'Merged backup: $challansAdded challans added, $challansDuplicateSkipped duplicates skipped. Total active: ${_challans.length}.',
      ));

      notifyListeners();

      return BackupImportSummary(
        success: true,
        mode: mode,
        challansAdded: challansAdded,
        challansDuplicateSkipped: challansDuplicateSkipped,
        partiesAdded: partiesAdded,
        partiesDuplicateSkipped: partiesDuplicateSkipped,
        totalActiveChallans: _challans.length,
        totalActiveParties: _parties.length,
        message: 'Merge complete: $challansAdded new challans added, $challansDuplicateSkipped duplicates skipped.',
      );
    }
  }

  Future<void> _applyBranding(Map<String, dynamic> b) async {
    if (b['companyName'] != null) {
      _companyName = b['companyName'] as String;
      await _storage.setCompanyName(_companyName);
    }
    if (b['companyTagline'] != null) {
      _companyTagline = b['companyTagline'] as String;
      await _storage.setCompanyTagline(_companyTagline);
    }
    if (b['adminName'] != null) {
      _adminName = b['adminName'] as String;
      await _storage.setAdminName(_adminName);
    }
    if (b['adminRole'] != null) {
      _adminRole = b['adminRole'] as String;
      await _storage.setAdminRole(_adminRole);
    }
    if (b['appLogoBase64'] != null) {
      _appLogoBase64 = b['appLogoBase64'] as String;
      await _storage.setAppLogoBase64(_appLogoBase64);
    }
    if (b['profileLogoBase64'] != null) {
      _profileLogoBase64 = b['profileLogoBase64'] as String;
      await _storage.setProfileLogoBase64(_profileLogoBase64);
    }
    if (b['textCasingStyle'] != null) {
      final savedCasing = b['textCasingStyle'] as String;
      _textCasingStyle = TextCasingStyle.values.firstWhere(
        (e) => e.name == savedCasing,
        orElse: () => TextCasingStyle.uppercase,
      );
      await _storage.setTextCasingStyle(savedCasing);
    }
    if (b['ledgerViewMode'] != null) {
      final savedMode = b['ledgerViewMode'] as String;
      _viewMode = LedgerViewMode.values.firstWhere(
        (e) => e.name == savedMode,
        orElse: () => LedgerViewMode.table,
      );
      await _storage.setLedgerViewMode(savedMode);
    }
    if (b['partyViewMode'] != null) {
      final savedMode = b['partyViewMode'] as String;
      _partyViewMode = LedgerViewMode.values.firstWhere(
        (e) => e.name == savedMode,
        orElse: () => LedgerViewMode.table,
      );
      await _storage.setPartyViewMode(savedMode);
    }
  }

  Future<bool> importBackup(String jsonString) async {
    final summary = await importBackupWithStrategy(
      jsonString: jsonString,
      mode: BackupImportMode.replace,
    );
    return summary.success;
  }

  // --- REAL REGISTERED PARTIES (FROM NOTEBOOK REGISTER) ---
  static const List<String> initialPartyNames = [
    'Manav Fab',
    'Swastik Creation',
    'Kamdar Silk Mills',
    'Heera Enterprise',
    'Radhe Mohan Silk Mills',
    'Chirag Creation',
    'Omkar Parag',
    'Guru Dharmesh Bhai',
    'Maya Silk Mills',
    'Paree Pratik',
    'Moti Mohan',
    'Shree Om Creation',
    'Pratham Trading',
    'Rakesh Corporation',
    'Varnika',
    'MRT Creation',
  ];

  Future<void> _seedRealParties() async {
    final now = DateTime.now();
    _parties = [];
    for (int i = 0; i < initialPartyNames.length; i++) {
      _parties.add(
        Party(
          id: _uuid.v4(),
          name: initialPartyNames[i],
          phone: '',
          address: '',
          gstNumber: '',
          createdAt: now.subtract(Duration(minutes: (initialPartyNames.length - i) * 5)),
        ),
      );
    }
    await _storage.saveParties(_parties);

    // Ledger starts completely clean with 0 dummy records
    _challans = [];
    await _storage.saveChallans(_challans);

    _viewMode = LedgerViewMode.table;
    await _storage.setLedgerViewMode(LedgerViewMode.table.name);
  }

  Future<void> _cleanAndSeedRealParties() async {
    // 1. Remove old dummy parties
    const dummyNames = {
      'ramesh patel & sons',
      'shreeji traders',
      'krishna textile mills',
    };
    _parties.removeWhere((p) => dummyNames.contains(p.name.trim().toLowerCase()));

    // 2. Remove old dummy challans
    const dummyChallans = {
      'ch-2026-101',
      'ch-2026-098',
      'ch-2026-092',
      'ch-2026-085',
    };
    _challans.removeWhere((c) => dummyChallans.contains(c.challanNo.trim().toLowerCase()));

    // 3. Ensure all 16 notebook parties exist in _parties
    final existingNames = _parties.map((p) => p.name.trim().toLowerCase()).toSet();
    final now = DateTime.now();
    final toAdd = <Party>[];
    for (int i = 0; i < initialPartyNames.length; i++) {
      final name = initialPartyNames[i];
      if (!existingNames.contains(name.toLowerCase())) {
        toAdd.add(
          Party(
            id: _uuid.v4(),
            name: name,
            phone: '',
            address: '',
            gstNumber: '',
            createdAt: now.subtract(Duration(minutes: (initialPartyNames.length - i) * 5)),
          ),
        );
      }
    }
    _parties.addAll(toAdd);

    // 4. Save clean data
    await _storage.saveParties(_parties);
    await _storage.saveChallans(_challans);

    // 5. Default view mode to table
    _viewMode = LedgerViewMode.table;
    await _storage.setLedgerViewMode(LedgerViewMode.table.name);
  }
}
