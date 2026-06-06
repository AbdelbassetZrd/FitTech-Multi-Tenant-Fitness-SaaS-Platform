import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/token_storage.dart';
import '../models/contact_model.dart';
import '../models/message_model.dart';

class ContactsResponse {
  final String? currentUserId;
  final List<ContactModel> contacts;
  const ContactsResponse({
    required this.currentUserId,
    required this.contacts,
  });
}

abstract class MessagingRemoteDataSource {
  Future<List<ContactModel>> getContacts();
  Future<ContactsResponse> getContactsResponse();
  Future<List<MessageModel>> getConversation({required String withUserId});
  Future<List<MessageModel>> getInbox();
  Future<MessageModel> sendMessage({
    required String recipientId,
    required String content,
  });
  Future<void> markAsRead(int messageId);

  /// Fetch the FitTech AI bot conversation history for the current member.
  Future<List<MessageModel>> getBotHistory();

  /// Send a message to the FitTech AI bot. Returns the bot's reply as a
  /// [MessageModel] (the user's own message is not echoed by the server, the
  /// caller is expected to append it locally).
  Future<MessageModel> sendBotMessage({required String content});

  /// Open a live stream for a direct conversation.
  Stream<MessageModel> watchConversation({required String withUserId});

  /// Close any active live conversation socket.
  Future<void> closeConversationWatcher();
}

class MessagingRemoteDataSourceImpl implements MessagingRemoteDataSource {
  final ApiClient apiClient;
  final TokenStorage tokenStorage;
  WebSocket? _conversationSocket;
  StreamController<MessageModel>? _conversationController;

  MessagingRemoteDataSourceImpl({
    required this.apiClient,
    required this.tokenStorage,
  });

  @override
  Future<List<ContactModel>> getContacts() async {
    final response = await getContactsResponse();
    return response.contacts;
  }

  @override
  Future<ContactsResponse> getContactsResponse() async {
    final response = await apiClient.authGet(AppConstants.messagingContacts);
    final raw = response['contacts'];
    final currentUserId = response['current_user_id']?.toString();
    final contacts = <ContactModel>[];
    if (raw is List) {
      for (final entry in raw.whereType<Map>()) {
        contacts.add(
          ContactModel.fromJson(Map<String, dynamic>.from(entry)),
        );
      }
    }
    return ContactsResponse(
      currentUserId: currentUserId,
      contacts: contacts,
    );
  }

  @override
  Future<List<MessageModel>> getConversation({
    required String withUserId,
  }) async {
    final response = await apiClient.authGet(
      AppConstants.messagingInbox,
      queryParams: {'with_user': withUserId},
    );
    return _parseMessages(response);
  }

  @override
  Future<List<MessageModel>> getInbox() async {
    final response = await apiClient.authGet(AppConstants.messagingInbox);
    return _parseMessages(response);
  }

  List<MessageModel> _parseMessages(Map<String, dynamic> response) {
    final raw = response['results'] ?? response['data'] ?? response['messages'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => MessageModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  }

  @override
  Future<MessageModel> sendMessage({
    required String recipientId,
    required String content,
  }) async {
    final response = await apiClient.authPost(
      AppConstants.messagingSend,
      body: {'recipient_id': recipientId, 'content': content},
    );
    return MessageModel.fromJson(response);
  }

  @override
  Future<void> markAsRead(int messageId) async {
    // PATCH not exposed in ApiClient; reuse authPost with custom client would
    // require additional plumbing. For now, the conversation endpoint already
    // marks inbound messages as read server-side.
  }

  @override
  Future<List<MessageModel>> getBotHistory() async {
    final response = await apiClient.authGet(AppConstants.messagingBotHistory);
    final raw = response['messages'];
    if (raw is! List) return const [];
    final out = <MessageModel>[];
    for (final entry in raw.whereType<Map>()) {
      final m = Map<String, dynamic>.from(entry);
      final isBot = m['is_bot'] == true || m['role'] == 'assistant';
      out.add(MessageModel(
        id: _stableHashId(m['id']?.toString() ?? ''),
        senderId: isBot
            ? AppConstants.botContactId
            : (m['sender_id']?.toString() ?? ''),
        senderName: m['sender_name']?.toString() ?? '',
        recipientId: isBot
            ? (m['sender_id']?.toString() ?? '')
            : AppConstants.botContactId,
        recipientName: '',
        content: m['content']?.toString() ?? '',
        isRead: true,
        createdAt: DateTime.tryParse(m['created_at']?.toString() ?? '') ??
            DateTime.now(),
      ));
    }
    return out;
  }

  @override
  Future<MessageModel> sendBotMessage({required String content}) async {
    final response = await apiClient.authPost(
      AppConstants.messagingBotChat,
      body: {'message': content},
    );
    final reply = response['reply']?.toString() ?? '';
    final createdAt =
        DateTime.tryParse(response['created_at']?.toString() ?? '') ??
            DateTime.now();
    return MessageModel(
      id: createdAt.microsecondsSinceEpoch & 0x7fffffff,
      senderId: AppConstants.botContactId,
      senderName: 'FitTech AI 🤖',
      recipientId: '',
      recipientName: '',
      content: reply,
      isRead: true,
      createdAt: createdAt,
    );
  }

  /// Best-effort positive 31-bit id from a string. Used only because the
  /// MessageEntity contract requires an int while bot history rows use UUIDs.
  int _stableHashId(String input) {
    if (input.isEmpty) {
      return DateTime.now().microsecondsSinceEpoch & 0x7fffffff;
    }
    var hash = 0;
    for (final code in input.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    return hash;
  }

  @override
  Stream<MessageModel> watchConversation({required String withUserId}) {
    unawaited(closeConversationWatcher());
    final controller = StreamController<MessageModel>.broadcast();
    _conversationController = controller;

    () async {
      try {
        final token = await tokenStorage.getAccessToken();
        if (token == null || token.isEmpty) {
          await controller.close();
          return;
        }

        final base = Uri.parse(AppConstants.baseUrl);
        final wsScheme = base.scheme == 'https' ? 'wss' : 'ws';
        final wsUri = Uri(
          scheme: wsScheme,
          host: base.host,
          port: base.hasPort ? base.port : null,
          path: '/ws/chat/$withUserId/',
          queryParameters: {'token': token},
        );

        final socket = await WebSocket.connect(wsUri.toString());
        _conversationSocket = socket;

        socket.listen(
          (frame) {
            try {
              final payload = jsonDecode(frame.toString());
              if (payload is! Map<String, dynamic>) return;
              if (payload['sender_id']?.toString() == 'system') return;

              // WS payload uses `message`; REST model expects `content`.
              final normalized = <String, dynamic>{
                ...payload,
                'content': payload['message'],
                'is_read': payload['is_read'] ?? true,
                'id': payload['id'] ??
                    ((payload['created_at']?.toString().hashCode ?? 0) &
                        0x7fffffff),
              };
              controller.add(MessageModel.fromJson(normalized));
            } catch (_) {
              // Ignore malformed/non-JSON frames.
            }
          },
          onError: (_) {},
          onDone: () {
            if (!controller.isClosed) {
              controller.close();
            }
          },
          cancelOnError: false,
        );
      } catch (_) {
        if (!controller.isClosed) {
          controller.close();
        }
      }
    }();

    return controller.stream;
  }

  @override
  Future<void> closeConversationWatcher() async {
    try {
      await _conversationSocket?.close();
    } catch (_) {
      // No-op: best-effort cleanup.
    }
    _conversationSocket = null;
    await _conversationController?.close();
    _conversationController = null;
  }
}
