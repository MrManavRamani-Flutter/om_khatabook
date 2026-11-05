import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/party.dart';
import '../models/transaction_entry.dart';
import '../models/day_entry.dart';
import '../models/group_profile.dart';
import '../services/storage_service.dart';

class KhataProvider extends ChangeNotifier {
  final StorageService _storage;
  final Uuid _uuid = const Uuid();

  List<Party> _parties = [];
  List<TransactionEntry> _transactions = [];
  List<DayEntry> _dayEntries = [];
  GroupProfile _profile = GroupProfile();
  bool _isDarkMode = false;
  bool _isLoading = true;

  KhataProvider(this._storage);

  List<Party> get parties => List.unmodifiable(_parties);
  List<TransactionEntry> get transactions => List.unmodifiable(_transactions);
  List<DayEntry> get dayEntries => List.unmodifiable(_dayEntries);
  GroupProfile get profile => _profile;
  bool get isDarkMode => _isDarkMode;
  bool get isLoading => _isLoading;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    _isDarkMode = _storage.isDarkMode;
    _profile = await _storage.loadProfile();
    _parties = await _storage.loadParties();
    _transactions = await _storage.loadTransactions();
    _dayEntries = await _storage.loadDayEntries();

    if (_storage.isFirstRun && _parties.isEmpty) {
      await _seedSampleData();
      await _storage.markFirstRunComplete();
    }

    _isLoading = false;
    notifyListeners();
  }

  // --- THEME ---
  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    await _storage.setDarkMode(_isDarkMode);
    notifyListeners();
  }

  // --- FINANCIAL CALCULATIONS ---
  double getPartyBalance(String partyId) {
    final party = _parties.firstWhere(
      (p) => p.id == partyId,
      orElse: () => Party(id: '', name: '', phone: '', createdAt: DateTime.now()),
    );
    if (party.id.isEmpty) return 0.0;

    double balance = party.openingBalance;
    final pTrans = _transactions.where((t) => t.partyId == partyId);

    for (var t in pTrans) {
      if (t.type == TransactionType.gave) {
        balance += t.amount;
      } else {
        balance -= t.amount;
      }
    }
    return balance;
  }

  double getPartyTotalGave(String partyId) {
    return _transactions
        .where((t) => t.partyId == partyId && t.type == TransactionType.gave)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double getPartyTotalGot(String partyId) {
    return _transactions
        .where((t) => t.partyId == partyId && t.type == TransactionType.got)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  List<TransactionEntry> getPartyTransactions(String partyId) {
    final list = _transactions.where((t) => t.partyId == partyId).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  DateTime? getPartyLastTransactionDate(String partyId) {
    final list = getPartyTransactions(partyId);
    return list.isNotEmpty ? list.first.date : null;
  }

  double get totalReceivable {
    double sum = 0.0;
    for (var party in _parties) {
      final bal = getPartyBalance(party.id);
      if (bal > 0) sum += bal;
    }
    return sum;
  }

  double get totalPayable {
    double sum = 0.0;
    for (var party in _parties) {
      final bal = getPartyBalance(party.id);
      if (bal < 0) sum += bal.abs();
    }
    return sum;
  }

  double get netBalance => totalReceivable - totalPayable;

  // --- PARTIES ACTIONS ---
  Future<Party> addParty({
    required String name,
    required String phone,
    String address = '',
    PartyType type = PartyType.customer,
    double openingBalance = 0.0,
    String notes = '',
  }) async {
    final party = Party(
      id: _uuid.v4(),
      name: name.trim(),
      phone: phone.trim(),
      address: address.trim(),
      type: type,
      openingBalance: openingBalance,
      createdAt: DateTime.now(),
      notes: notes.trim(),
    );
    _parties.add(party);
    await _storage.saveParties(_parties);
    notifyListeners();
    return party;
  }

  Future<void> updateParty(Party party) async {
    final index = _parties.indexWhere((p) => p.id == party.id);
    if (index != -1) {
      _parties[index] = party;
      await _storage.saveParties(_parties);
      notifyListeners();
    }
  }

  Future<void> deleteParty(String partyId) async {
    _parties.removeWhere((p) => p.id == partyId);
    _transactions.removeWhere((t) => t.partyId == partyId);
    await _storage.saveParties(_parties);
    await _storage.saveTransactions(_transactions);
    notifyListeners();
  }

  // --- TRANSACTIONS ACTIONS ---
  Future<TransactionEntry> addTransaction({
    required String partyId,
    required double amount,
    required TransactionType type,
    PaymentMode paymentMode = PaymentMode.cash,
    required DateTime date,
    String description = '',
    String billNumber = '',
  }) async {
    final entry = TransactionEntry(
      id: _uuid.v4(),
      partyId: partyId,
      amount: amount,
      type: type,
      paymentMode: paymentMode,
      date: date,
      description: description.trim(),
      billNumber: billNumber.trim(),
      createdAt: DateTime.now(),
    );
    _transactions.add(entry);
    await _storage.saveTransactions(_transactions);
    notifyListeners();
    return entry;
  }

  Future<void> updateTransaction(TransactionEntry entry) async {
    final index = _transactions.indexWhere((t) => t.id == entry.id);
    if (index != -1) {
      _transactions[index] = entry;
      await _storage.saveTransactions(_transactions);
      notifyListeners();
    }
  }

  Future<void> deleteTransaction(String transactionId) async {
    _transactions.removeWhere((t) => t.id == transactionId);
    await _storage.saveTransactions(_transactions);
    notifyListeners();
  }

  // --- DAY ENTRIES ACTIONS (ROJMEL) ---
  Future<DayEntry> addDayEntry({
    required String title,
    required double amount,
    required DayEntryType type,
    String category = 'General',
    required DateTime date,
    String note = '',
  }) async {
    final entry = DayEntry(
      id: _uuid.v4(),
      title: title.trim(),
      amount: amount,
      type: type,
      category: category,
      date: date,
      note: note.trim(),
      createdAt: DateTime.now(),
    );
    _dayEntries.add(entry);
    await _storage.saveDayEntries(_dayEntries);
    notifyListeners();
    return entry;
  }

  Future<void> deleteDayEntry(String id) async {
    _dayEntries.removeWhere((e) => e.id == id);
    await _storage.saveDayEntries(_dayEntries);
    notifyListeners();
  }

  // --- PROFILE ---
  Future<void> updateProfile(GroupProfile newProfile) async {
    _profile = newProfile;
    await _storage.saveProfile(_profile);
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
      _transactions = await _storage.loadTransactions();
      _dayEntries = await _storage.loadDayEntries();
      _profile = await _storage.loadProfile();
      notifyListeners();
    }
    return ok;
  }

  Future<void> resetToSampleData() async {
    await _storage.clearAllData();
    await _seedSampleData();
    notifyListeners();
  }

  // --- PRESET INITIAL SAMPLE DATA ---
  Future<void> _seedSampleData() async {
    _profile = GroupProfile(
      groupName: 'OM Mavtar Group',
      ownerName: 'Manav Ramani',
      phoneNumber: '+91 98765 43210',
      address: 'Ahmedabad / Surat, Gujarat',
      upiId: 'ommavtar@upi',
      currencySymbol: '₹',
    );
    await _storage.saveProfile(_profile);

    final now = DateTime.now();

    final p1 = Party(
      id: _uuid.v4(),
      name: 'Ramesh Patel',
      phone: '98250 12345',
      address: 'Ring Road, Surat',
      type: PartyType.customer,
      openingBalance: 0,
      createdAt: now.subtract(const Duration(days: 20)),
      notes: 'Regular textile customer',
    );

    final p2 = Party(
      id: _uuid.v4(),
      name: 'Shreeji Traders (Mahesh Bhai)',
      phone: '98980 54321',
      address: 'Kalupur, Ahmedabad',
      type: PartyType.supplier,
      openingBalance: 0,
      createdAt: now.subtract(const Duration(days: 15)),
      notes: 'Raw material vendor',
    );

    final p3 = Party(
      id: _uuid.v4(),
      name: 'Pravin Bhai Shah',
      phone: '94260 77889',
      address: 'Varachha, Surat',
      type: PartyType.member,
      openingBalance: 0,
      createdAt: now.subtract(const Duration(days: 30)),
      notes: 'OM Mavtar Group Member',
    );

    _parties = [p1, p2, p3];
    await _storage.saveParties(_parties);

    _transactions = [
      TransactionEntry(
        id: _uuid.v4(),
        partyId: p1.id,
        amount: 25000,
        type: TransactionType.gave, // Gave goods on credit
        paymentMode: PaymentMode.cash,
        date: now.subtract(const Duration(days: 10)),
        description: 'Cotton fabric shipment #A42',
        billNumber: 'INV-1021',
        createdAt: now.subtract(const Duration(days: 10)),
      ),
      TransactionEntry(
        id: _uuid.v4(),
        partyId: p1.id,
        amount: 10000,
        type: TransactionType.got, // Received payment
        paymentMode: PaymentMode.upi,
        date: now.subtract(const Duration(days: 3)),
        description: 'UPI payment via GPay',
        billNumber: '',
        createdAt: now.subtract(const Duration(days: 3)),
      ),
      TransactionEntry(
        id: _uuid.v4(),
        partyId: p2.id,
        amount: 50000,
        type: TransactionType.got, // Supplier provided materials
        paymentMode: PaymentMode.bankTransfer,
        date: now.subtract(const Duration(days: 7)),
        description: 'Thread and packaging supply',
        billNumber: 'BILL-889',
        createdAt: now.subtract(const Duration(days: 7)),
      ),
      TransactionEntry(
        id: _uuid.v4(),
        partyId: p2.id,
        amount: 35000,
        type: TransactionType.gave, // Paid to supplier
        paymentMode: PaymentMode.bankTransfer,
        date: now.subtract(const Duration(days: 2)),
        description: 'NEFT transfer to Shreeji bank',
        billNumber: '',
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      TransactionEntry(
        id: _uuid.v4(),
        partyId: p3.id,
        amount: 15000,
        type: TransactionType.gave, // Group fund advance
        paymentMode: PaymentMode.cash,
        date: now.subtract(const Duration(days: 5)),
        description: 'Festival community event advance',
        billNumber: '',
        createdAt: now.subtract(const Duration(days: 5)),
      ),
    ];
    await _storage.saveTransactions(_transactions);

    _dayEntries = [
      DayEntry(
        id: _uuid.v4(),
        title: 'Office Chai & Refreshments',
        amount: 320,
        type: DayEntryType.expense,
        category: 'Refreshment',
        date: now,
        note: 'Staff refreshments',
        createdAt: now,
      ),
      DayEntry(
        id: _uuid.v4(),
        title: 'Scrap Packing Material Sale',
        amount: 1450,
        type: DayEntryType.income,
        category: 'Misc Income',
        date: now,
        note: 'Old cartons sold for cash',
        createdAt: now,
      ),
    ];
    await _storage.saveDayEntries(_dayEntries);
  }
}
