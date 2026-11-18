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
    final str = val.toString().trim();
    if (str.isEmpty) return fallback ?? DateTime.now();
    return DateTime.tryParse(str) ?? (fallback ?? DateTime.now());
  }

  factory Party.fromJson(Map<String, dynamic> json) {
    final rawName = json['name']?.toString().trim() ?? json['partyName']?.toString().trim() ?? '';
    final rawId = json['id']?.toString().trim();
    final id = (rawId != null && rawId.isNotEmpty)
        ? rawId
        : 'party_${DateTime.now().millisecondsSinceEpoch}_${rawName.hashCode.abs()}';

    return Party(
      id: id,
      name: rawName,
      phone: json['phone']?.toString().trim() ?? json['contact']?.toString().trim() ?? '',
      address: json['address']?.toString().trim() ?? json['city']?.toString().trim() ?? '',
      gstNumber: json['gstNumber']?.toString().trim() ?? json['gstin']?.toString().trim() ?? '',
      createdAt: _parseDate(json['createdAt']),
      createdBy: json['createdBy']?.toString().trim() ?? 'system',
      lastModifiedBy: json['lastModifiedBy']?.toString().trim(),
      lastModifiedAt: json['lastModifiedAt'] != null ? _parseDate(json['lastModifiedAt']) : null,
      isDeleted: json['isDeleted'] == true || json['isDeleted']?.toString() == 'true',
      deletedAt: json['deletedAt'] != null ? _parseDate(json['deletedAt']) : null,
      deletedBy: json['deletedBy']?.toString().trim(),
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
