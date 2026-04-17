class TopUpRequest {
  final String id;
  final String userId;
  final double amount;
  final String screenshotUrl;
  final String status; // 'pending' | 'approved' | 'rejected'
  final String? adminNote;
  final DateTime createdAt;
  final DateTime? reviewedAt;

  // Joined from public.users — populated in admin view
  final String? userName;
  final String? userEmail;

  const TopUpRequest({
    required this.id,
    required this.userId,
    required this.amount,
    required this.screenshotUrl,
    required this.status,
    this.adminNote,
    required this.createdAt,
    this.reviewedAt,
    this.userName,
    this.userEmail,
  });

  factory TopUpRequest.fromMap(Map<String, dynamic> map) {
    return TopUpRequest(
      id: map['id'] ?? '',
      userId: map['user_id'] ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(),
      screenshotUrl: map['screenshot_url'] ?? '',
      status: map['status'] ?? 'pending',
      adminNote: map['admin_note'],
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'].toString())
          : DateTime.now(),
      reviewedAt: map['reviewed_at'] != null
          ? DateTime.parse(map['reviewed_at'].toString())
          : null,
      userName: map['user_name'],
      userEmail: map['user_email'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'amount': amount,
      'screenshot_url': screenshotUrl,
      'status': status,
      'admin_note': adminNote,
      'created_at': createdAt.toIso8601String(),
      'reviewed_at': reviewedAt?.toIso8601String(),
    };
  }

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      default:
        return status;
    }
  }
}
