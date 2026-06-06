part of 'messaging_bloc.dart';

abstract class MessagingEvent extends Equatable {
  const MessagingEvent();
  @override
  List<Object?> get props => [];
}

class ContactsRequested extends MessagingEvent {
  const ContactsRequested();
}

class ConversationRequested extends MessagingEvent {
  final String withUserId;
  const ConversationRequested(this.withUserId);
  @override
  List<Object?> get props => [withUserId];
}

class MessageSent extends MessagingEvent {
  final String recipientId;
  final String content;
  const MessageSent({required this.recipientId, required this.content});
  @override
  List<Object?> get props => [recipientId, content];
}

class ConversationRefreshed extends MessagingEvent {
  final String withUserId;
  const ConversationRefreshed(this.withUserId);
  @override
  List<Object?> get props => [withUserId];
}

class IncomingMessageReceived extends MessagingEvent {
  final MessageEntity message;
  const IncomingMessageReceived(this.message);

  @override
  List<Object?> get props => [message];
}
