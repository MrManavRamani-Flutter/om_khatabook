import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/challan_entry.dart';
import '../models/party.dart';
import '../services/storage_service.dart';

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

  // Sorting state (Date Ascending vs Descending)
  bool _sortAscending = false; // false = Newest First (Desc), true = Oldest First (Asc)

  ChallanProvider(this._storage);

  List<Party> get parties => _parties.where((p) => !p.isDeleted).toList();
  List<Party> get deletedParties => _parties.where((p) => p.isDeleted).toList();
  List<ChallanEntry> get challans => _challans.where((c) => !c.isDeleted).toList();
  List<ChallanEntry> get deletedChallans => _challans.where((c) => c.isDeleted).toList();
  int get recycleBinCount => deletedChallans.length + deletedParties.length;

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
  bool get sortAscending => _sortAscending;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    _isDarkMode = _storage.isDarkMode;
    _parties = await _storage.loadParties();
    _challans = await _storage.loadChallans();

    if (_storage.isFirstRun && _parties.isEmpty) {
      await _seedInitialData();
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

    // 6. Date Sorting (Ascending vs Descending)
    result.sort((a, b) =>
        _sortAscending ? a.date.compareTo(b.date) : b.date.compareTo(a.date));

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
      parts.add('Status: ${_statusFilter!.toUpperCase()}');
    }

    parts.add('Sort: ${_sortAscending ? "Oldest First (Asc)" : "Newest First (Desc)"}');

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

  double get totalFinalAmount =>
      filteredChallans.fold(0.0, (sum, item) => sum + item.finalAmount);

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

  // --- CRUD & RECYCLE BIN: PARTIES ---
  Future<Party> addParty({
    required String name,
    String phone = '',
    String address = '',
    String gstNumber = '',
  }) async {
    final party = Party(
      id: _uuid.v4(),
      name: name.trim(),
      phone: phone.trim(),
      address: address.trim(),
      gstNumber: gstNumber.trim(),
      createdAt: DateTime.now(),
    );
    _parties.add(party);
    await _storage.saveParties(_parties);
    notifyListeners();
    return party;
  }

  Future<void> updateParty(Party updated) async {
    final idx = _parties.indexWhere((p) => p.id == updated.id);
    if (idx != -1) {
      _parties[idx] = updated;
      for (int i = 0; i < _challans.length; i++) {
        if (_challans[i].partyId == updated.id) {
          _challans[i] = _challans[i].copyWith(partyName: updated.name);
        }
      }
      await _storage.saveParties(_parties);
      await _storage.saveChallans(_challans);
      notifyListeners();
    }
  }

  Future<void> moveToBinParty(String partyId) async {
    final idx = _parties.indexWhere((p) => p.id == partyId);
    if (idx != -1) {
      _parties[idx] = _parties[idx].copyWith(
        isDeleted: true,
        deletedAt: DateTime.now(),
      );
      _selectedPartyIds.remove(partyId);
      await _storage.saveParties(_parties);
      notifyListeners();
    }
  }

  Future<void> restoreParty(String partyId) async {
    final idx = _parties.indexWhere((p) => p.id == partyId);
    if (idx != -1) {
      _parties[idx] = _parties[idx].copyWith(
        isDeleted: false,
        clearDeletedAt: true,
      );
      await _storage.saveParties(_parties);
      notifyListeners();
    }
  }

  Future<void> deletePermanentlyParty(String partyId) async {
    _parties.removeWhere((p) => p.id == partyId);
    _selectedPartyIds.remove(partyId);
    await _storage.saveParties(_parties);
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
    required double finalAmount,
    double? paidAmount,
    String gstBillNo = '',
    double gstAmount = 0.0,
    required PaymentOption paymentOption,
    bool isCashPaid = true,
    ChequeDetails? chequeDetails,
    String notes = '',
  }) async {
    final entry = ChallanEntry(
      id: _uuid.v4(),
      date: date,
      challanNo: challanNo.trim(),
      partyId: partyId,
      partyName: partyName.trim(),
      challanAmount: challanAmount,
      finalAmount: finalAmount,
      paidAmount: paidAmount,
      gstBillNo: gstBillNo.trim(),
      gstAmount: gstAmount,
      paymentOption: paymentOption,
      isCashPaid: isCashPaid,
      chequeDetails: chequeDetails,
      notes: notes.trim(),
      createdAt: DateTime.now(),
    );

    _challans.insert(0, entry);
    await _storage.saveChallans(_challans);
    notifyListeners();
    return entry;
  }

  Future<void> updateChallan(ChallanEntry updated) async {
    final idx = _challans.indexWhere((c) => c.id == updated.id);
    if (idx != -1) {
      _challans[idx] = updated;
      await _storage.saveChallans(_challans);
      notifyListeners();
    }
  }

  Future<void> moveToBinChallan(String id) async {
    final idx = _challans.indexWhere((c) => c.id == id);
    if (idx != -1) {
      _challans[idx] = _challans[idx].copyWith(
        isDeleted: true,
        deletedAt: DateTime.now(),
      );
      await _storage.saveChallans(_challans);
      notifyListeners();
    }
  }

  Future<void> restoreChallan(String id) async {
    final idx = _challans.indexWhere((c) => c.id == id);
    if (idx != -1) {
      _challans[idx] = _challans[idx].copyWith(
        isDeleted: false,
        clearDeletedAt: true,
      );
      await _storage.saveChallans(_challans);
      notifyListeners();
    }
  }

  Future<void> deletePermanentlyChallan(String id) async {
    _challans.removeWhere((c) => c.id == id);
    await _storage.saveChallans(_challans);
    notifyListeners();
  }

  /// Backward compatibility: Deleting a challan moves it to the Recycle Bin
  Future<void> deleteChallan(String id) => moveToBinChallan(id);

  // --- EMPTY RECYCLE BIN ---
  Future<void> emptyRecycleBin() async {
    _challans.removeWhere((c) => c.isDeleted);
    _parties.removeWhere((p) => p.isDeleted);
    await _storage.saveChallans(_challans);
    await _storage.saveParties(_parties);
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

  Future<bool> importBackup(String jsonString) async {
    final ok = await _storage.importBackupJson(jsonString);
    if (ok) {
      _parties = await _storage.loadParties();
      _challans = await _storage.loadChallans();
      notifyListeners();
    }
    return ok;
  }

  // --- INITIAL SEED DATA ---
  Future<void> _seedInitialData() async {
    final p1 = Party(
      id: _uuid.v4(),
      name: 'Ramesh Patel & Sons',
      phone: '98250 12345',
      address: 'Ring Road, Surat',
      gstNumber: '24AAAAA0000A1Z5',
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
    );

    final p2 = Party(
      id: _uuid.v4(),
      name: 'Shreeji Traders',
      phone: '98980 54321',
      address: 'Kalupur, Ahmedabad',
      gstNumber: '24BBBBB1111B2Z8',
      createdAt: DateTime.now().subtract(const Duration(days: 20)),
    );

    final p3 = Party(
      id: _uuid.v4(),
      name: 'Krishna Textile Mills',
      phone: '94260 77889',
      address: 'Varachha, Surat',
      gstNumber: '24CCCCC2222C3Z1',
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
    );

    _parties = [p1, p2, p3];
    await _storage.saveParties(_parties);

    final now = DateTime.now();

    _challans = [
      ChallanEntry(
        id: _uuid.v4(),
        date: now.subtract(const Duration(days: 1)),
        challanNo: 'CH-2026-101',
        partyId: p1.id,
        partyName: p1.name,
        challanAmount: 48000,
        finalAmount: 50400,
        paidAmount: 20000,
        gstBillNo: 'GST-2026-042',
        gstAmount: 2400,
        paymentOption: PaymentOption.cash,
        isCashPaid: false,
        notes: 'Delivery dispatched, partial advance cash received ₹20,000, balance ₹30,400 pending',
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      ChallanEntry(
        id: _uuid.v4(),
        date: now.subtract(const Duration(days: 4)),
        challanNo: 'CH-2026-098',
        partyId: p2.id,
        partyName: p2.name,
        challanAmount: 25000,
        finalAmount: 26250,
        gstBillNo: 'GST-2026-039',
        gstAmount: 1250,
        paymentOption: PaymentOption.cash,
        isCashPaid: true,
        notes: 'Cash received in full at shop',
        createdAt: now.subtract(const Duration(days: 4)),
      ),
      ChallanEntry(
        id: _uuid.v4(),
        date: now.subtract(const Duration(days: 6)),
        challanNo: 'CH-2026-092',
        partyId: p3.id,
        partyName: p3.name,
        challanAmount: 75000,
        finalAmount: 78750,
        gstBillNo: 'GST-2026-035',
        gstAmount: 3750,
        paymentOption: PaymentOption.cheque,
        isCashPaid: false,
        chequeDetails: ChequeDetails(
          chequeNo: '408912',
          chequeDate: now.add(const Duration(days: 2)),
          bankName: 'HDFC Bank',
          chequeAmount: 78750,
          status: ChequeStatus.pending,
        ),
        notes: 'Cheque deposited in account, awaiting clearance',
        createdAt: now.subtract(const Duration(days: 6)),
      ),
      ChallanEntry(
        id: _uuid.v4(),
        date: now.subtract(const Duration(days: 12)),
        challanNo: 'CH-2026-085',
        partyId: p1.id,
        partyName: p1.name,
        challanAmount: 120000,
        finalAmount: 126000,
        gstBillNo: 'GST-2026-028',
        gstAmount: 6000,
        paymentOption: PaymentOption.cheque,
        isCashPaid: false,
        chequeDetails: ChequeDetails(
          chequeNo: '112233',
          chequeDate: now.subtract(const Duration(days: 10)),
          bankName: 'State Bank of India',
          chequeAmount: 126000,
          status: ChequeStatus.cleared,
        ),
        notes: 'Cleared on 28th October',
        createdAt: now.subtract(const Duration(days: 12)),
      ),
    ];
    await _storage.saveChallans(_challans);
  }
}
