enum AuditAction {
  create('Created'),
  update('Updated'),
  softDelete('Moved to Bin'),
  restore('Restored'),
  permanentDelete('Purged Forever'),
  login('User Login'),
  logout('User Logout'),
  exportReport('Exported Report'),
  taxInvoicePrint('Printed Tax Invoice'),
  settingsChange('Settings Modified');

  final String label;
  const AuditAction(this.label);
}

enum AuditEntityType {
  challan('Challan Entry'),
  party('Commercial Party'),
  auth('User & Session'),
  settings('System Settings'),
  report('Commercial Report');

  final String label;
  const AuditEntityType(this.label);
}

class AuditLogEntry {
  final String id;
  final DateTime timestamp;
  final AuditAction action;
  final AuditEntityType entityType;
  final String entityId;
  final String entityTitle;
  final String performedBy; // username
  final String userRole; // MASTER
  final String description;
  final Map<String, dynamic> metadata;

  AuditLogEntry({
    required this.id,
    required this.timestamp,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.entityTitle,
    String? performedBy,
    String? userRole,
    required this.description,
    this.metadata = const {},
  })  : performedBy = 'OM MAVTAR',
        userRole = 'MASTER';

  AuditLogEntry copyWith({
    String? id,
    DateTime? timestamp,
    AuditAction? action,
    AuditEntityType? entityType,
    String? entityId,
    String? entityTitle,
    String? performedBy,
    String? userRole,
    String? description,
    Map<String, dynamic>? metadata,
  }) {
    return AuditLogEntry(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      action: action ?? this.action,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      entityTitle: entityTitle ?? this.entityTitle,
      performedBy: performedBy ?? this.performedBy,
      userRole: userRole ?? this.userRole,
      description: description ?? this.description,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'action': action.name,
      'entityType': entityType.name,
      'entityId': entityId,
      'entityTitle': entityTitle,
      'performedBy': performedBy,
      'userRole': userRole,
      'description': description,
      'metadata': metadata,
    };
  }

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) {
    return AuditLogEntry(
      id: json['id'] as String,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      action: AuditAction.values.firstWhere(
        (a) => a.name == json['action'],
        orElse: () => AuditAction.update,
      ),
      entityType: AuditEntityType.values.firstWhere(
        (e) => e.name == json['entityType'],
        orElse: () => AuditEntityType.challan,
      ),
      entityId: json['entityId'] as String? ?? '',
      entityTitle: json['entityTitle'] as String? ?? '',
      performedBy: 'OM MAVTAR',
      userRole: 'MASTER',
      description: json['description'] as String? ?? '',
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
    );
  }
}

