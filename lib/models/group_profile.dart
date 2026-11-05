class GroupProfile {
  final String groupName;
  final String ownerName;
  final String phoneNumber;
  final String address;
  final String upiId;
  final String currencySymbol;

  GroupProfile({
    this.groupName = 'OM Mavtar Group',
    this.ownerName = 'Admin',
    this.phoneNumber = '',
    this.address = '',
    this.upiId = '',
    this.currencySymbol = '₹',
  });

  Map<String, dynamic> toJson() {
    return {
      'groupName': groupName,
      'ownerName': ownerName,
      'phoneNumber': phoneNumber,
      'address': address,
      'upiId': upiId,
      'currencySymbol': currencySymbol,
    };
  }

  factory GroupProfile.fromJson(Map<String, dynamic> json) {
    return GroupProfile(
      groupName: json['groupName'] as String? ?? 'OM Mavtar Group',
      ownerName: json['ownerName'] as String? ?? 'Admin',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      address: json['address'] as String? ?? '',
      upiId: json['upiId'] as String? ?? '',
      currencySymbol: json['currencySymbol'] as String? ?? '₹',
    );
  }

  GroupProfile copyWith({
    String? groupName,
    String? ownerName,
    String? phoneNumber,
    String? address,
    String? upiId,
    String? currencySymbol,
  }) {
    return GroupProfile(
      groupName: groupName ?? this.groupName,
      ownerName: ownerName ?? this.ownerName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      address: address ?? this.address,
      upiId: upiId ?? this.upiId,
      currencySymbol: currencySymbol ?? this.currencySymbol,
    );
  }
}
