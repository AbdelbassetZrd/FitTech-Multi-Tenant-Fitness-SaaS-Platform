import 'package:equatable/equatable.dart';

class ContactEntity extends Equatable {
  final String id;
  final String name;
  final String role; // 'coach' | 'admin' | 'member' | 'bot'
  final String email;

  /// Last message exchanged with this contact (any direction). May be null
  /// if no conversation has happened yet.
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final bool lastFromMe;
  final int unreadCount;

  const ContactEntity({
    required this.id,
    required this.name,
    required this.role,
    required this.email,
    this.lastMessage,
    this.lastMessageAt,
    this.lastFromMe = false,
    this.unreadCount = 0,
  });

  ContactEntity copyWith({
    String? lastMessage,
    DateTime? lastMessageAt,
    bool? lastFromMe,
    int? unreadCount,
  }) {
    return ContactEntity(
      id: id,
      name: name,
      role: role,
      email: email,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastFromMe: lastFromMe ?? this.lastFromMe,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  bool get hasUnread => unreadCount > 0;

  @override
  List<Object?> get props => [
        id,
        name,
        role,
        email,
        lastMessage,
        lastMessageAt,
        lastFromMe,
        unreadCount,
      ];
}
