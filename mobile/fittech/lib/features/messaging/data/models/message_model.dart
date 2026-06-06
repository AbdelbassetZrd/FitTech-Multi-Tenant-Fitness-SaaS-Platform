import '../../domain/entities/message_entity.dart';

class MessageModel extends MessageEntity {
  const MessageModel({
    required super.id,
    required super.senderId,
    required super.senderName,
    required super.recipientId,
    required super.recipientName,
    required super.content,
    required super.isRead,
    required super.createdAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      senderId: json['sender_id']?.toString() ?? '',
      senderName: json['sender_name']?.toString() ?? '',
      recipientId: json['recipient_id']?.toString() ?? '',
      recipientName: json['recipient_name']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      isRead: json['is_read'] == true,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
