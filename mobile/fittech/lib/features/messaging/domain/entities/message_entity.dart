import 'package:equatable/equatable.dart';

class MessageEntity extends Equatable {
  final int id;
  final String senderId;
  final String senderName;
  final String recipientId;
  final String recipientName;
  final String content;
  final bool isRead;
  final DateTime createdAt;

  const MessageEntity({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.recipientId,
    required this.recipientName,
    required this.content,
    required this.isRead,
    required this.createdAt,
  });

  @override
  List<Object?> get props =>
      [id, senderId, recipientId, content, isRead, createdAt];
}
