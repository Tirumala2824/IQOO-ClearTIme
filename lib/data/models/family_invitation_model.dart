enum InvitationStatus {
  active,
  used,
  expired,
  revoked;

  static InvitationStatus fromString(String value) {
    switch (value.toUpperCase()) {
      case 'ACTIVE':
        return InvitationStatus.active;
      case 'USED':
        return InvitationStatus.used;
      case 'EXPIRED':
        return InvitationStatus.expired;
      case 'REVOKED':
        return InvitationStatus.revoked;
      default:
        return InvitationStatus.active;
    }
  }

  String toDbString() {
    switch (this) {
      case InvitationStatus.active:
        return 'ACTIVE';
      case InvitationStatus.used:
        return 'USED';
      case InvitationStatus.expired:
        return 'EXPIRED';
      case InvitationStatus.revoked:
        return 'REVOKED';
    }
  }
}

class FamilyInvitation {
  final String id;
  final String familyId;
  final String createdBy;
  final String invitationCode;
  final String qrPayload;
  final DateTime expiresAt;
  final int maxUses;
  final int usedCount;
  final InvitationStatus status;
  final DateTime createdAt;

  const FamilyInvitation({
    required this.id,
    required this.familyId,
    required this.createdBy,
    required this.invitationCode,
    required this.qrPayload,
    required this.expiresAt,
    this.maxUses = 1,
    this.usedCount = 0,
    this.status = InvitationStatus.active,
    required this.createdAt,
  });

  bool get isValid =>
      status == InvitationStatus.active &&
      DateTime.now().isBefore(expiresAt) &&
      usedCount < maxUses;

  factory FamilyInvitation.fromJson(Map<String, dynamic> json) {
    return FamilyInvitation(
      id: json['id'] as String,
      familyId: json['family_id'] as String,
      createdBy: json['created_by'] as String,
      invitationCode: json['invitation_code'] as String,
      qrPayload:
          json['qr_payload'] as String? ?? json['invitation_code'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      maxUses: json['max_uses'] as int? ?? 1,
      usedCount: json['used_count'] as int? ?? 0,
      status:
          InvitationStatus.fromString(json['status'] as String? ?? 'ACTIVE'),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'family_id': familyId,
      'created_by': createdBy,
      'invitation_code': invitationCode,
      'qr_payload': qrPayload,
      'expires_at': expiresAt.toIso8601String(),
      'max_uses': maxUses,
      'used_count': usedCount,
      'status': status.toDbString(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}
