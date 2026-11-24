class Party {
  final String id;
  final String name;
  final String phone;
  final String address;
  final String gstNumber;
  final DateTime createdAt;
  final String createdBy;
  final String? lastModifiedBy;
  final DateTime? lastModifiedAt;
  final bool isDeleted;
  final DateTime? deletedAt;
  final String? deletedBy;

  Party({
    required this.id,
    required this.name,
    this.phone = '',
    this.address = '',
    this.gstNumber = '',
    required this.createdAt,
    this.createdBy = 'admin',
    this.lastModifiedBy,
    this.lastModifiedAt,
    this.isDeleted = false,
    this.deletedAt,
    this.deletedBy,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'gstNumber': gstNumber,
      'createdAt': createdAt.toIso8601String(),
      'createdBy': createdBy,
      'lastModifiedBy': lastModifiedBy,
      'lastModifiedAt': lastModifiedAt?.toIso8601String(),
      'isDeleted': isDeleted,
      'deletedAt': deletedAt?.toIso8601String(),
      'deletedBy': deletedBy,
    };
  }

  static DateTime _parseDate(dynamic val, {DateTime? fallback}) {
    if (val == null) return fallback ?? DateTime.now();
    if (val is DateTime) return val;
    if (val is num) {
      return DateTime.fromMillisecondsSinceEpoch(val.toInt());
    }
    final str = val.toString().trim();
    if (str.isEmpty) return fallback ?? DateTime.now();
    final parsed = DateTime.tryParse(str);
    if (parsed != null) return parsed;
    final dmyRegex = RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{4})');
    final match = dmyRegex.firstMatch(str);
    if (match != null) {
      final d = int.tryParse(match.group(1)!) ?? 1;
      final m = int.tryParse(match.group(2)!) ?? 1;
      final y = int.tryParse(match.group(3)!) ?? DateTime.now().year;
      return DateTime(y, m, d);
    }
    return fallback ?? DateTime.now();
  }

  factory Party.fromJson(Map<String, dynamic> json) {
    final rawName = (json['name'] ?? json['partyName'] ?? json['party_name'] ?? json['customerName'] ?? json['clientName'] ?? json['title'])?.toString().trim() ?? '';
    final rawId = json['id']?.toString().trim();
    final id = (rawId != null && rawId.isNotEmpty)
        ? rawId
        : 'party_${DateTime.now().millisecondsSinceEpoch}_${rawName.hashCode.abs()}';

    return Party(
      id: id,
      name: rawName,
      phone: (json['phone'] ?? json['mobile'] ?? json['contact'] ?? json['phoneNumber'])?.toString().trim() ?? '',
      address: (json['address'] ?? json['city'] ?? json['location'])?.toString().trim() ?? '',
      gstNumber: (json['gstNumber'] ?? json['gst_number'] ?? json['gstin'] ?? json['gst'])?.toString().trim() ?? '',
      createdAt: _parseDate(json['createdAt'] ?? json['created_at']),
      createdBy: (json['createdBy'] ?? json['created_by'])?.toString().trim() ?? 'system',
      lastModifiedBy: (json['lastModifiedBy'] ?? json['last_modified_by'])?.toString().trim(),
      lastModifiedAt: (json['lastModifiedAt'] ?? json['last_modified_at']) != null ? _parseDate(json['lastModifiedAt'] ?? json['last_modified_at']) : null,
      isDeleted: json['isDeleted'] == true || json['is_deleted'] == true || json['isDeleted']?.toString() == 'true',
      deletedAt: (json['deletedAt'] ?? json['deleted_at']) != null ? _parseDate(json['deletedAt'] ?? json['deleted_at']) : null,
      deletedBy: (json['deletedBy'] ?? json['deleted_by'])?.toString().trim(),
    );
  }

  Party copyWith({
    String? id,
    String? name,
    String? phone,
    String? address,
    String? gstNumber,
    String? createdBy,
    String? lastModifiedBy,
    DateTime? lastModifiedAt,
    bool? isDeleted,
    DateTime? deletedAt,
    String? deletedBy,
    bool clearDeletedAt = false,
  }) {
    return Party(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      gstNumber: gstNumber ?? this.gstNumber,
      createdAt: createdAt,
      createdBy: createdBy ?? this.createdBy,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      deletedBy: deletedBy ?? this.deletedBy,
    );
  }
}
