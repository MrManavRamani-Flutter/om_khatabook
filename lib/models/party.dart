class Party {
  final String id;
  final String name;
  final String phone;
  final String address;
  final String gstNumber;
  final DateTime createdAt;
  final bool isDeleted;
  final DateTime? deletedAt;

  Party({
    required this.id,
    required this.name,
    this.phone = '',
    this.address = '',
    this.gstNumber = '',
    required this.createdAt,
    this.isDeleted = false,
    this.deletedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'gstNumber': gstNumber,
      'createdAt': createdAt.toIso8601String(),
      'isDeleted': isDeleted,
      'deletedAt': deletedAt?.toIso8601String(),
    };
  }

  factory Party.fromJson(Map<String, dynamic> json) {
    return Party(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String? ?? '',
      address: json['address'] as String? ?? '',
      gstNumber: json['gstNumber'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      isDeleted: json['isDeleted'] as bool? ?? false,
      deletedAt: json['deletedAt'] != null
          ? DateTime.parse(json['deletedAt'] as String)
          : null,
    );
  }

  Party copyWith({
    String? name,
    String? phone,
    String? address,
    String? gstNumber,
    bool? isDeleted,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Party(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      gstNumber: gstNumber ?? this.gstNumber,
      createdAt: createdAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }
}
