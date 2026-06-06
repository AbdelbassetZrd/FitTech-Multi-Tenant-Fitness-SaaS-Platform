import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/fittech_theme.dart';
import '../../../../injection_container.dart';
import '../../domain/entities/contact_entity.dart';
import '../../domain/entities/message_entity.dart';
import '../bloc/messaging_bloc.dart';

class ChatScreen extends StatelessWidget {
  final ContactEntity contact;

  const ChatScreen({super.key, required this.contact});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<MessagingBloc>(
      create: (_) =>
          sl<MessagingBloc>()..add(ConversationRequested(contact.id)),
      child: _ChatView(contact: contact),
    );
  }
}

class _ChatView extends StatefulWidget {
  final ContactEntity contact;
  const _ChatView({required this.contact});

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _currentUserId;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    context
        .read<MessagingBloc>()
        .add(MessageSent(recipientId: widget.contact.id, content: text));
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: FitColors.green.withValues(alpha: 0.18),
              child: Text(
                widget.contact.name.isNotEmpty
                    ? widget.contact.name[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    color: FitColors.green, fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.contact.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    widget.contact.role.toUpperCase(),
                    style: const TextStyle(
                      color: FitColors.muted,
                      fontSize: 10,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: BlocConsumer<MessagingBloc, MessagingState>(
              listener: (context, state) {
                if (state.messages.isNotEmpty) _scrollToBottom();
                if (state.sendStatus == SendStatus.failure &&
                    state.sendError != null) {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(content: Text(state.sendError!)));
                }
              },
              builder: (context, state) {
                _currentUserId ??= _detectCurrentUserId(state.messages);
                if (state.conversationStatus == ConversationStatus.loading &&
                    state.messages.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(color: FitColors.green),
                  );
                }
                if (state.conversationStatus == ConversationStatus.failure &&
                    state.messages.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        state.conversationError ??
                            'Failed to load conversation.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  );
                }
                if (state.messages.isEmpty) {
                  return const Center(
                    child: Text(
                      'Start the conversation 👋',
                      style: TextStyle(color: FitColors.muted),
                    ),
                  );
                }
                final isBot = widget.contact.id == AppConstants.botContactId;
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  itemCount: state.messages.length,
                  itemBuilder: (_, i) {
                    final msg = state.messages[i];
                    final bool mine;
                    if (isBot) {
                      // In a bot conversation, anything not coming from the
                      // bot is from the current user (covers both server
                      // history rows and locally-appended optimistic ones).
                      mine = msg.senderId != AppConstants.botContactId;
                    } else {
                      mine = _currentUserId != null &&
                          msg.senderId == _currentUserId;
                    }
                    return _MessageBubble(message: msg, mine: mine);
                  },
                );
              },
            ),
          ),
          _Composer(
            controller: _controller,
            onSend: _send,
          ),
        ],
      ),
    );
  }

  /// Heuristic: when we send a message we know the sender_id from the response.
  /// Otherwise, infer from messages where senderId != contact.id.
  String? _detectCurrentUserId(List<MessageEntity> messages) {
    for (final m in messages) {
      if (m.senderId != widget.contact.id) return m.senderId;
      if (m.recipientId != widget.contact.id) return m.recipientId;
    }
    return null;
  }
}

class _MessageBubble extends StatelessWidget {
  final MessageEntity message;
  final bool mine;

  const _MessageBubble({required this.message, required this.mine});

  @override
  Widget build(BuildContext context) {
    final time =
        '${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}';
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: mine ? FitColors.green : const Color(0xFF202A42),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message.content,
              style: TextStyle(
                color:
                    mine ? Colors.white : Colors.white.withValues(alpha: 0.95),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(
                color: mine ? Colors.white70 : FitColors.muted,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const _Composer({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white),
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: const TextStyle(color: FitColors.muted),
                  filled: true,
                  fillColor: const Color(0xFF202A42),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            BlocBuilder<MessagingBloc, MessagingState>(
              buildWhen: (p, c) => p.sendStatus != c.sendStatus,
              builder: (context, state) {
                final loading = state.sendStatus == SendStatus.sending;
                return Material(
                  color: FitColors.green,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: loading ? null : onSend,
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: loading
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.send_rounded, color: Colors.white),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
