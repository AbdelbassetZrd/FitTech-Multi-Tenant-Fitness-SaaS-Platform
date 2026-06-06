class MessagingContact {
  const MessagingContact({
    required this.id,
    required this.name,
    required this.role,
    required this.email,
  });

  final String id;
  final String name;
  final String role;
  final String email;

  factory MessagingContact.fromJson(Map<String, dynamic> json) {
    return MessagingContact(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
    );
  }
}

class MessagingMessage {
  const MessagingMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.recipientId,
    required this.content,
    required this.createdAt,
  });

  final int id;
  final String senderId;
  final String senderName;
  final String recipientId;
  final String content;
  final DateTime createdAt;

  factory MessagingMessage.fromJson(Map<String, dynamic> json) {
    return MessagingMessage(
      id: (json['id'] as num?)?.toInt() ?? 0,
      senderId: json['sender_id']?.toString() ?? '',
      senderName: json['sender_name']?.toString() ?? '',
      recipientId: json['recipient_id']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
