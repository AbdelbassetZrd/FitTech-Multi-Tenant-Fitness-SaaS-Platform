part of 'messaging_bloc.dart';

enum ContactsStatus { initial, loading, success, failure }

enum ConversationStatus { initial, loading, success, failure }

enum SendStatus { idle, sending, success, failure }

class MessagingState extends Equatable {
  final ContactsStatus contactsStatus;
  final List<ContactEntity> contacts;
  final String? contactsError;

  final ConversationStatus conversationStatus;
  final List<MessageEntity> messages;
  final String? conversationError;
  final String? activeContactId;

  final SendStatus sendStatus;
  final String? sendError;

  const MessagingState({
    this.contactsStatus = ContactsStatus.initial,
    this.contacts = const [],
    this.contactsError,
    this.conversationStatus = ConversationStatus.initial,
    this.messages = const [],
    this.conversationError,
    this.activeContactId,
    this.sendStatus = SendStatus.idle,
    this.sendError,
  });

  MessagingState copyWith({
    ContactsStatus? contactsStatus,
    List<ContactEntity>? contacts,
    String? contactsError,
    ConversationStatus? conversationStatus,
    List<MessageEntity>? messages,
    String? conversationError,
    String? activeContactId,
    SendStatus? sendStatus,
    String? sendError,
  }) {
    return MessagingState(
      contactsStatus: contactsStatus ?? this.contactsStatus,
      contacts: contacts ?? this.contacts,
      contactsError: contactsError,
      conversationStatus: conversationStatus ?? this.conversationStatus,
      messages: messages ?? this.messages,
      conversationError: conversationError,
      activeContactId: activeContactId ?? this.activeContactId,
      sendStatus: sendStatus ?? this.sendStatus,
      sendError: sendError,
    );
  }

  @override
  List<Object?> get props => [
        contactsStatus,
        contacts,
        contactsError,
        conversationStatus,
        messages,
        conversationError,
        activeContactId,
        sendStatus,
        sendError,
      ];
}
