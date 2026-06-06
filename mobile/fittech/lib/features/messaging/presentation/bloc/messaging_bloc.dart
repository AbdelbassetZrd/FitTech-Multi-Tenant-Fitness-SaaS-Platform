import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/contact_entity.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/repositories/messaging_repository.dart';

part 'messaging_event.dart';
part 'messaging_state.dart';

class MessagingBloc extends Bloc<MessagingEvent, MessagingState> {
  final MessagingRepository repository;
  StreamSubscription<MessageEntity>? _conversationSubscription;

  MessagingBloc({required this.repository}) : super(const MessagingState()) {
    on<ContactsRequested>(_onContactsRequested);
    on<ConversationRequested>(_onConversationRequested);
    on<ConversationRefreshed>(_onConversationRefreshed);
    on<MessageSent>(_onMessageSent);
    on<IncomingMessageReceived>(_onIncomingMessageReceived);
  }

  Future<void> _onContactsRequested(
    ContactsRequested event,
    Emitter<MessagingState> emit,
  ) async {
    emit(state.copyWith(
      contactsStatus: ContactsStatus.loading,
      contactsError: null,
    ));
    final result = await repository.getContactsOverview();
    result.fold(
      (failure) => emit(state.copyWith(
        contactsStatus: ContactsStatus.failure,
        contactsError: failure.message,
      )),
      (contacts) => emit(state.copyWith(
        contactsStatus: ContactsStatus.success,
        contacts: contacts,
      )),
    );
  }

  bool _isBot(String id) => id == AppConstants.botContactId;

  Future<void> _onConversationRequested(
    ConversationRequested event,
    Emitter<MessagingState> emit,
  ) async {
    await _conversationSubscription?.cancel();
    _conversationSubscription = null;
    await repository.closeConversationWatcher();

    emit(state.copyWith(
      conversationStatus: ConversationStatus.loading,
      messages: const [],
      activeContactId: event.withUserId,
      conversationError: null,
    ));
    final result = _isBot(event.withUserId)
        ? await repository.getBotHistory()
        : await repository.getConversation(withUserId: event.withUserId);
    result.fold(
      (failure) => emit(state.copyWith(
        conversationStatus: ConversationStatus.failure,
        conversationError: failure.message,
      )),
      (messages) => emit(state.copyWith(
        conversationStatus: ConversationStatus.success,
        messages: messages,
      )),
    );

    if (!_isBot(event.withUserId)) {
      _conversationSubscription = repository
          .watchConversation(withUserId: event.withUserId)
          .listen((message) {
        add(IncomingMessageReceived(message));
      });
    }
  }

  Future<void> _onConversationRefreshed(
    ConversationRefreshed event,
    Emitter<MessagingState> emit,
  ) async {
    final result = _isBot(event.withUserId)
        ? await repository.getBotHistory()
        : await repository.getConversation(withUserId: event.withUserId);
    result.fold(
      (_) {},
      (messages) => emit(state.copyWith(
        conversationStatus: ConversationStatus.success,
        messages: messages,
      )),
    );
  }

  Future<void> _onMessageSent(
    MessageSent event,
    Emitter<MessagingState> emit,
  ) async {
    if (_isBot(event.recipientId)) {
      // Optimistically append the user's own message so it appears instantly.
      final now = DateTime.now();
      final myMessage = MessageEntity(
        id: now.microsecondsSinceEpoch & 0x7fffffff,
        senderId: state.activeContactId == AppConstants.botContactId
            ? '__me__'
            : '__me__',
        senderName: 'You',
        recipientId: AppConstants.botContactId,
        recipientName: 'FitTech AI 🤖',
        content: event.content,
        isRead: true,
        createdAt: now,
      );
      emit(state.copyWith(
        sendStatus: SendStatus.sending,
        sendError: null,
        messages: List<MessageEntity>.from(state.messages)..add(myMessage),
      ));

      final result = await repository.sendBotMessage(content: event.content);
      result.fold(
        (failure) {
          emit(state.copyWith(
            sendStatus: SendStatus.failure,
            sendError: failure.message,
          ));
        },
        (reply) {
          emit(state.copyWith(
            sendStatus: SendStatus.success,
            messages: List<MessageEntity>.from(state.messages)..add(reply),
          ));
        },
      );
      return;
    }

    emit(state.copyWith(sendStatus: SendStatus.sending, sendError: null));
    final result = await repository.sendMessage(
      recipientId: event.recipientId,
      content: event.content,
    );
    await result.fold(
      (failure) async {
        emit(state.copyWith(
          sendStatus: SendStatus.failure,
          sendError: failure.message,
        ));
      },
      (message) async {
        // Guard against duplicates: the backend WS broadcast may have already
        // delivered this message through IncomingMessageReceived before the
        // REST response arrived (race condition on fast networks).
        final alreadyPresent = state.messages.any(
          (m) =>
              (m.id != 0 && message.id != 0 && m.id == message.id) ||
              (m.senderId == message.senderId &&
                  m.content == message.content &&
                  message.createdAt.difference(m.createdAt).inMilliseconds.abs() <
                      5000),
        );
        final updated = alreadyPresent
            ? state.messages
            : (List<MessageEntity>.from(state.messages)..add(message));
        emit(state.copyWith(
          sendStatus: SendStatus.success,
          messages: updated,
        ));
      },
    );
  }

  void _onIncomingMessageReceived(
    IncomingMessageReceived event,
    Emitter<MessagingState> emit,
  ) {
    final msg = event.message;
    // Primary dedup: match by DB id when both sides have a real id.
    // Fallback: match by sender + content + timestamp (handles the race where
    // the WS echo arrives before or after the REST response is processed).
    final exists = state.messages.any(
      (m) =>
          (m.id != 0 && msg.id != 0 && m.id == msg.id) ||
          (m.senderId == msg.senderId &&
              m.content == msg.content &&
              msg.createdAt.difference(m.createdAt).inMilliseconds.abs() <
                  5000),
    );
    if (exists) return;
    emit(state.copyWith(
      conversationStatus: ConversationStatus.success,
      messages: List<MessageEntity>.from(state.messages)..add(msg),
    ));
  }

  @override
  Future<void> close() async {
    await _conversationSubscription?.cancel();
    await repository.closeConversationWatcher();
    return super.close();
  }
}
