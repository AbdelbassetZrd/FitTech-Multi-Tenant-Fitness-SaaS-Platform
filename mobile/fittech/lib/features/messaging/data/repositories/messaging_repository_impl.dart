import 'package:dartz/dartz.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/contact_entity.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/repositories/messaging_repository.dart';
import '../datasources/messaging_remote_datasource.dart';

class MessagingRepositoryImpl implements MessagingRepository {
  final MessagingRemoteDataSource remoteDataSource;

  MessagingRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<ContactEntity>>> getContacts() async {
    try {
      final contacts = await remoteDataSource.getContacts();
      return Right(contacts);
    } on UnauthorizedException catch (e) {
      return Left(UnauthorizedFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on AppException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<ContactEntity>>> getContactsOverview() async {
    try {
      final results = await Future.wait([
        remoteDataSource.getContactsResponse(),
        remoteDataSource.getInbox(),
      ]);
      final contactsResponse = results[0] as ContactsResponse;
      final inbox = results[1] as List<MessageEntity>;
      final currentUserId = contactsResponse.currentUserId;

      // Index latest message + unread count per peer id.
      final latest = <String, MessageEntity>{};
      final unread = <String, int>{};

      for (final msg in inbox) {
        final peerId =
            msg.senderId == currentUserId ? msg.recipientId : msg.senderId;
        final existing = latest[peerId];
        if (existing == null || msg.createdAt.isAfter(existing.createdAt)) {
          latest[peerId] = msg;
        }
        if (msg.recipientId == currentUserId && !msg.isRead) {
          unread[peerId] = (unread[peerId] ?? 0) + 1;
        }
      }

      final enriched = contactsResponse.contacts.map<ContactEntity>((c) {
        final last = latest[c.id];
        if (last == null) return c;
        return c.copyWith(
          lastMessage: last.content,
          lastMessageAt: last.createdAt,
          lastFromMe: last.senderId == currentUserId,
          unreadCount: unread[c.id] ?? 0,
        );
      }).toList();

      // Sort: most recent on top; contacts with no messages keep their
      // original order at the bottom.
      enriched.sort((a, b) {
        final ta = a.lastMessageAt;
        final tb = b.lastMessageAt;
        if (ta == null && tb == null) return 0;
        if (ta == null) return 1;
        if (tb == null) return -1;
        return tb.compareTo(ta);
      });

      return Right(enriched);
    } on UnauthorizedException catch (e) {
      return Left(UnauthorizedFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on AppException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<MessageEntity>>> getConversation({
    required String withUserId,
  }) async {
    try {
      final messages =
          await remoteDataSource.getConversation(withUserId: withUserId);
      return Right(messages);
    } on UnauthorizedException catch (e) {
      return Left(UnauthorizedFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on AppException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, MessageEntity>> sendMessage({
    required String recipientId,
    required String content,
  }) async {
    try {
      final message = await remoteDataSource.sendMessage(
        recipientId: recipientId,
        content: content,
      );
      return Right(message);
    } on ValidationException catch (e) {
      return Left(ValidationFailure(e.message, errors: e.errors));
    } on UnauthorizedException catch (e) {
      return Left(UnauthorizedFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on AppException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<MessageEntity>>> getBotHistory() async {
    try {
      final messages = await remoteDataSource.getBotHistory();
      return Right(messages);
    } on UnauthorizedException catch (e) {
      return Left(UnauthorizedFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on AppException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, MessageEntity>> sendBotMessage({
    required String content,
  }) async {
    try {
      final reply = await remoteDataSource.sendBotMessage(content: content);
      return Right(reply);
    } on ValidationException catch (e) {
      return Left(ValidationFailure(e.message, errors: e.errors));
    } on UnauthorizedException catch (e) {
      return Left(UnauthorizedFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on AppException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> markAsRead(int messageId) async {
    try {
      await remoteDataSource.markAsRead(messageId);
      return const Right(null);
    } on AppException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Stream<MessageEntity> watchConversation({required String withUserId}) {
    return remoteDataSource.watchConversation(withUserId: withUserId);
  }

  @override
  Future<void> closeConversationWatcher() {
    return remoteDataSource.closeConversationWatcher();
  }
}
