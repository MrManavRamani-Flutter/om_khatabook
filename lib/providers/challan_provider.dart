import 'package:flutter/material.dart';
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
  String? _selectedPartyId;
  PaymentOption? _paymentOptionFilter;
  String? _statusFilter; // 'all', 'paid', 'unpaid', 'pending', 'bounced'
  String _dateFilter = 'all'; // 'all', 'today', 'week', 'month'
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  ChallanProvider(this._storage);

  List<Party> get parties => List.unmodifiable(_parties);
  List<ChallanEntry> get challans => List.unmodifiable(_challans);
  bool get isDarkMode => _isDarkMode;
  bool get isLoading => _isLoading;

  String get searchQuery => _searchQuery;
  String? get selectedPartyId => _selectedPartyId;
  PaymentOption? get paymentOptionFilter => _paymentOptionFilter;
  String? get statusFilter => _statusFilter;
  String get dateFilter => _dateFilter;
  DateTime? get customStartDate => _customStartDate;
  DateTime? get customEndDate => _customEndDate;

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
    _selectedPartyId = partyId;
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
    notifyListeners();
  }

  void resetFilters() {
    _searchQuery = '';
    _selectedPartyId = null;
    _paymentOptionFilter = null;
    _statusFilter = null;
    _dateFilter = 'all';
    _customStartDate = null;
    _customEndDate = null;
    notifyListeners();
  }

  // --- FILTERED ENTRIES ---
  List<ChallanEntry> get filteredChallans {
    final now = DateTime.now();

    return _challans.where((item) {
      // Search
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

      // Party filter
      if (_selectedPartyId != null && _selectedPartyId!.isNotEmpty) {
        if (item.partyId != _selectedPartyId) return false;
      }

      // Payment option filter
      if (_paymentOptionFilter != null) {
        if (item.paymentOption != _paymentOptionFilter) return false;
      }

      // Status filter
      if (_statusFilter != null && _statusFilter != 'all') {
        if (_statusFilter == 'unpaid') {
          // Cash unpaid or Cheque pending/bounced
          if (!item.isPending && !item.hasWarning) return false;
        } else if (_statusFilter == 'paid') {
          // Cash paid or Cheque cleared
          final isCleared = item.paymentOption == PaymentOption.cash
              ? item.isCashPaid
              : item.chequeDetails?.status == ChequeStatus.cleared;
          if (!isCleared) return false;
        } else if (_statusFilter == 'bounced') {
          if (item.chequeDetails?.status != ChequeStatus.bounced) return false;
        }
      }

      // Date filter
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
      } else if (_dateFilter == 'custom' &&
          _customStartDate != null &&
          _customEndDate != null) {
        if (item.date.isBefore(_customStartDate!) ||
            item.date.isAfter(_customEndDate!.add(const Duration(days: 1)))) {
          return false;
        }
      }

      return true;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  // --- SUMMARY TOTALS ---
  double get totalChallanAmount =>
      _challans.fold(0.0, (sum, item) => sum + item.challanAmount);

  double get totalFinalAmount =>
      _challans.fold(0.0, (sum, item) => sum + item.finalAmount);

  double get totalGstAmount =>
      _challans.fold(0.0, (sum, item) => sum + item.gstAmount);

  double get totalUnpaidAmount {
    double sum = 0.0;
    for (var c in _challans) {
      if (c.paymentOption == PaymentOption.cash && !c.isCashPaid) {
        sum += c.finalAmount;
      } else if (c.paymentOption == PaymentOption.cheque &&
          c.chequeDetails?.status != ChequeStatus.cleared) {
        sum += c.finalAmount;
      }
    }
    return sum;
  }

  int get unpaidWarningCount =>
      _challans.where((c) => c.hasWarning).length;

  // --- CRUD: PARTIES ---
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
      // Also update partyName in existing challans
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

  Future<void> deleteParty(String partyId) async {
    _parties.removeWhere((p) => p.id == partyId);
    await _storage.saveParties(_parties);
    notifyListeners();
  }

  // --- CRUD: CHALLAN ENTRIES ---
  Future<ChallanEntry> addChallan({
    required DateTime date,
    required String challanNo,
    required String partyId,
    required String partyName,
    required double challanAmount,
    required double finalAmount,
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
      gstBillNo: gstBillNo.trim(),
      gstAmount: gstAmount,
      paymentOption: paymentOption,
      isCashPaid: isCashPaid,
      chequeDetails: chequeDetails,
      notes: notes.trim(),
      createdAt: DateTime.now(), // Hidden from UI, auto-stamped
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

  Future<void> deleteChallan(String id) async {
    _challans.removeWhere((c) => c.id == id);
    await _storage.saveChallans(_challans);
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
      // 1. CASH UNPAID -> Must be highlighted in warning/light-red!
      ChallanEntry(
        id: _uuid.v4(),
        date: now.subtract(const Duration(days: 1)),
        challanNo: 'CH-2026-101',
        partyId: p1.id,
        partyName: p1.name,
        challanAmount: 48000,
        finalAmount: 50400,
        gstBillNo: 'GST-2026-042',
        gstAmount: 2400,
        paymentOption: PaymentOption.cash,
        isCashPaid: false, // UNPAID CASH -> LIGHT RED HIGHLIGHT!
        notes: 'Delivery dispatched, cash payment pending upon verification',
        createdAt: now.subtract(const Duration(days: 1)),
      ),

      // 2. CASH PAID -> Normal green highlight
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
        isCashPaid: true, // PAID
        notes: 'Cash received in full at shop',
        createdAt: now.subtract(const Duration(days: 4)),
      ),

      // 3. CHEQUE PENDING
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

      // 4. CHEQUE CLEARED
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

