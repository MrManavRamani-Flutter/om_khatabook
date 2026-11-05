enum PartyType {
  customer,
  supplier,
  member;

  String get displayName {
    switch (this) {
      case PartyType.customer:
        return 'Customer (Grahak)';
      case PartyType.supplier:
        return 'Supplier (Vyapari)';
      case PartyType.member:
        return 'Group Member';
    }
  }
}

class Party {
  final String id;
  final String name;
  final String phone;
  final String address;
  final PartyType type;
  final double openingBalance; // positive = they owe you, negative = you owe them
  final DateTime createdAt;
  final String notes;

  Party({
    required this.id,
    required this.name,
    required this.phone,
    this.address = '',
    this.type = PartyType.customer,
    this.openingBalance = 0.0,
    required this.createdAt,
    this.notes = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'type': type.name,
      'openingBalance': openingBalance,
      'createdAt': createdAt.toIso8601String(),
      'notes': notes,
    };
  }

  factory Party.fromJson(Map<String, dynamic> json) {
    return Party(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String? ?? '',
      address: json['address'] as String? ?? '',
      type: PartyType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => PartyType.customer,
      ),
      openingBalance: (json['openingBalance'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      notes: json['notes'] as String? ?? '',
    );
  }

  Party copyWith({
    String? name,
    String? phone,
    String? address,
    PartyType? type,
    double? openingBalance,
    String? notes,
  }) {
    return Party(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      type: type ?? this.type,
      openingBalance: openingBalance ?? this.openingBalance,
      createdAt: createdAt,
      notes: notes ?? this.notes,
    );
  }
}
