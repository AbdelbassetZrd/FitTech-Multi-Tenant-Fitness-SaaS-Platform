import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/contact_entity.dart';
import '../entities/message_entity.dart';

abstract class MessagingRepository {
  Future<Either<Failure, List<ContactEntity>>> getContacts();

  /// Like [getContacts] but enriches each contact with the latest message
  /// preview, timestamp and unread counter, and sorts the list with the most
  /// recent conversations on top (Instagram-style inbox).
  Future<Either<Failure, List<ContactEntity>>> getContactsOverview();

  Future<Either<Failure, List<MessageEntity>>> getConversation({
    required String withUserId,
  });

  Future<Either<Failure, MessageEntity>> sendMessage({
    required String recipientId,
    required String content,
  });

  Future<Either<Failure, void>> markAsRead(int messageId);

  /// FitTech AI bot history.
  Future<Either<Failure, List<MessageEntity>>> getBotHistory();

  /// Send a message to the FitTech AI bot. Returns the bot reply only — the
  /// caller is responsible for appending the user's own message locally.
  Future<Either<Failure, MessageEntity>> sendBotMessage({
    required String content,
  });

  /// Live conversation messages via websocket.
  Stream<MessageEntity> watchConversation({required String withUserId});

  /// Close the active live conversation subscription/socket.
  Future<void> closeConversationWatcher();
}
