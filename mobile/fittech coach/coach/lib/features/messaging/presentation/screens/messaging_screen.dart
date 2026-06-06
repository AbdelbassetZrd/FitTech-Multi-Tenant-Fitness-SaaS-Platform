import 'package:flutter/material.dart';
import '../../../../core/models/coach_profile.dart';
import '../../../../core/network/coach_api_client.dart';
import '../../../../core/network/api_paths.dart';
import '../../../../core/theme/app_colors.dart';

class MessagingScreen extends StatefulWidget {
  const MessagingScreen({required this.profile, required this.wide});

  final CoachProfile profile;
  final bool wide;

  @override
  State<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen> {
  final _api = CoachApiClient();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  String _searchQuery = '';

  bool _loadingContacts = true;
  bool _loadingMessages = false;
  bool _sendingMessage = false;
  String? _contactsError;
  String? _messagesError;

  String _currentUserId = '';
  List<Map<String, dynamic>> _contacts = [];
  Map<String, dynamic>? _selectedContact;
  List<Map<String, dynamic>> _messages = [];

  /// On narrow screens, whether we are showing the chat panel vs contacts list.
  bool _showingChat = false;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ── Data loading ────────────────────────────────────────────────────────────

  Future<void> _loadContacts() async {
    setState(() {
      _loadingContacts = true;
      _contactsError = null;
    });
    try {
      final res = await _api.get(
        ApiPaths.messagingContacts,
        requiresAuth: true,
      );
      final contacts = (res['contacts'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((c) => Map<String, dynamic>.from(c))
          .toList();
      if (!mounted) return;
      setState(() {
        _currentUserId = res['current_user_id']?.toString() ?? '';
        _contacts = contacts;
        _loadingContacts = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _contactsError = e.toString().replaceFirst('Exception: ', '');
        _loadingContacts = false;
      });
    }
  }

  Future<void> _selectContact(Map<String, dynamic> contact) async {
    setState(() {
      _selectedContact = contact;
      _messages = [];
      _loadingMessages = true;
      _messagesError = null;
      if (!widget.wide) _showingChat = true;
    });
    await _loadMessages(contact['id'].toString());
  }

  Future<void> _loadMessages(String contactId) async {
    try {
      final res = await _api.get(
        '${ApiPaths.messagingInbox}?with_user=$contactId',
        requiresAuth: true,
      );
      final messages = (res['results'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _loadingMessages = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messagesError = e.toString().replaceFirst('Exception: ', '');
        _loadingMessages = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    final contact = _selectedContact;
    if (content.isEmpty || contact == null || _sendingMessage) return;

    setState(() => _sendingMessage = true);
    _messageController.clear();

    try {
      final res = await _api.post(
        ApiPaths.messagingSend,
        requiresAuth: true,
        body: {
          'recipient_id': contact['id'].toString(),
          'content': content,
        },
      );
      if (!mounted) return;
      setState(() {
        _messages = [..._messages, Map<String, dynamic>.from(res)];
        _sendingMessage = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => _sendingMessage = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final hour = dt.hour;
      final min = dt.minute.toString().padLeft(2, '0');
      final suffix = hour >= 12 ? 'PM' : 'AM';
      final h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      return '${h.toString().padLeft(2, '0')}:$min $suffix';
    } catch (_) {
      return '';
    }
  }

  String _avatarInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    if (name.isNotEmpty) return name[0].toUpperCase();
    return '?';
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'member':
        return const Color(0xFF3B82F6);
      case 'admin':
        return const Color(0xFFF59E0B);
      case 'bot':
        return AppColors.green;
      default:
        return AppColors.muted;
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (widget.wide) {
      return Row(
        children: [
          SizedBox(width: 280, child: _buildContactsList()),
          Container(width: 1, color: Colors.white.withValues(alpha: 0.06)),
          Expanded(child: _buildChatArea()),
        ],
      );
    }

    // Narrow: show either contacts list or chat
    if (_showingChat && _selectedContact != null) {
      return _buildChatArea();
    }
    return _buildContactsList();
  }

  // ── Contacts list ────────────────────────────────────────────────────────────

  Widget _buildContactsList() {
    return Container(
      color: const Color(0xFF0B1220),
      child: Column(
        children: [
          _buildContactsHeader(),
          _buildSearchBar(),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.06)),
          Expanded(child: _buildContactsBody()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        onChanged: (value) => setState(() => _searchQuery = value.trim().toLowerCase()),
        decoration: InputDecoration(
          hintText: 'Search contacts…',
          hintStyle: TextStyle(
            color: AppColors.muted.withValues(alpha: 0.6),
            fontSize: 13,
          ),
          prefixIcon: const Icon(Icons.search, color: AppColors.muted, size: 18),
          suffixIcon: _searchQuery.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                  child: const Icon(Icons.close, color: AppColors.muted, size: 16),
                )
              : null,
          filled: true,
          fillColor: const Color(0xFF121B2E),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.green),
          ),
        ),
      ),
    );
  }

  Widget _buildContactsHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 14),
      child: Row(
        children: [
          const Icon(Icons.chat_bubble_outline, color: AppColors.green, size: 20),
          const SizedBox(width: 10),
          const Text(
            'Messages',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.muted, size: 20),
            onPressed: _loadContacts,
            tooltip: 'Refresh contacts',
          ),
        ],
      ),
    );
  }

  Widget _buildContactsBody() {
    if (_loadingContacts) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.green),
      );
    }
    if (_contactsError != null) {
      return _buildErrorState(_contactsError!, _loadContacts);
    }
    if (_contacts.isEmpty) {
      return _buildEmptyState(
        'No contacts available',
        Icons.people_outline,
      );
    }
    final filtered = _searchQuery.isEmpty
        ? _contacts
        : _contacts.where((c) {
            final name = (c['name']?.toString() ?? '').toLowerCase();
            return name.contains(_searchQuery);
          }).toList();

    if (filtered.isEmpty) {
      return _buildEmptyState(
        'No contacts match\n"${_searchController.text.trim()}"',
        Icons.search_off,
      );
    }
    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final contact = filtered[index];
        final isSelected = _selectedContact?['id'] == contact['id'];
        return _buildContactTile(contact, isSelected);
      },
    );
  }

  Widget _buildContactTile(Map<String, dynamic> contact, bool isSelected) {
    final name = contact['name']?.toString() ?? 'Unknown';
    final role = contact['role']?.toString() ?? 'member';
    final isBot = role == 'bot';
    final roleColor = _roleColor(role);

    return InkWell(
      onTap: () => _selectContact(contact),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.green.withValues(alpha: 0.08)
              : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isSelected ? AppColors.green : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: roleColor.withValues(alpha: 0.15),
                border: Border.all(
                  color: isSelected
                      ? roleColor.withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: Center(
                child: isBot
                    ? const Text('🤖', style: TextStyle(fontSize: 20))
                    : Text(
                        _avatarInitials(name),
                        style: TextStyle(
                          color: roleColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFFCBD5E1),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    role.toUpperCase(),
                    style: TextStyle(
                      color: roleColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isSelected
                  ? AppColors.green.withValues(alpha: 0.7)
                  : Colors.white.withValues(alpha: 0.15),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  // ── Chat area ────────────────────────────────────────────────────────────────

  Widget _buildChatArea() {
    if (_selectedContact == null) {
      return _buildNoChatSelected();
    }
    return Column(
      children: [
        _buildChatHeader(),
        Expanded(child: _buildMessagesList()),
        _buildMessageInput(),
      ],
    );
  }

  Widget _buildNoChatSelected() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.forum_outlined,
            color: AppColors.muted.withValues(alpha: 0.25),
            size: 72,
          ),
          const SizedBox(height: 16),
          const Text(
            'Select a contact\nto start messaging',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 15,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildChatHeader() {
    final contact = _selectedContact!;
    final name = contact['name']?.toString() ?? 'Unknown';
    final role = contact['role']?.toString() ?? '';
    final roleColor = _roleColor(role);

    return Container(
      padding: EdgeInsets.fromLTRB(widget.wide ? 20 : 4, 14, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          if (!widget.wide)
            IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 18,
              ),
              onPressed: () => setState(() => _showingChat = false),
            ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: roleColor.withValues(alpha: 0.15),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Center(
              child: role == 'bot'
                  ? const Text('🤖', style: TextStyle(fontSize: 18))
                  : Text(
                      _avatarInitials(name),
                      style: TextStyle(
                        color: roleColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  role.toUpperCase(),
                  style: TextStyle(
                    color: roleColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.muted, size: 20),
            onPressed: () =>
                _loadMessages(contact['id'].toString()),
            tooltip: 'Refresh messages',
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    if (_loadingMessages) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.green),
      );
    }
    if (_messagesError != null) {
      return _buildErrorState(
        _messagesError!,
        () => _loadMessages(_selectedContact!['id'].toString()),
      );
    }
    if (_messages.isEmpty) {
      return _buildEmptyState(
        'No messages yet.\nSay hello to get started!',
        Icons.chat_bubble_outline,
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final isMine =
            msg['sender_id']?.toString() == _currentUserId;
        return _buildMessageBubble(msg, isMine);
      },
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isMine) {
    final content = msg['content']?.toString() ?? '';
    final time = _formatTime(msg['created_at']?.toString() ?? '');
    final senderName = msg['sender_name']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine)
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: 8, bottom: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.green.withValues(alpha: 0.15),
              ),
              child: Center(
                child: Text(
                  _avatarInitials(senderName),
                  style: const TextStyle(
                    color: AppColors.green,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: isMine
                    ? AppColors.green.withValues(alpha: 0.18)
                    : const Color(0xFF131D31),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMine ? 16 : 4),
                  bottomRight: Radius.circular(isMine ? 4 : 16),
                ),
                border: Border.all(
                  color: isMine
                      ? AppColors.green.withValues(alpha: 0.25)
                      : Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: Column(
                crossAxisAlignment: isMine
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (!isMine)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        senderName,
                        style: const TextStyle(
                          color: AppColors.green,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  Text(
                    content,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    time,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Write a message…',
                hintStyle: TextStyle(
                  color: AppColors.muted.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
                filled: true,
                fillColor: const Color(0xFF121B2E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.green),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
              ),
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.newline,
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _sendMessage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _sendingMessage
                    ? AppColors.green.withValues(alpha: 0.5)
                    : AppColors.green,
              ),
              child: _sendingMessage
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Utility widgets ──────────────────────────────────────────────────────────

  Widget _buildErrorState(String message, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppColors.muted, size: 48),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.green,
                side: const BorderSide(color: AppColors.green),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: AppColors.muted.withValues(alpha: 0.25),
            size: 56,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 14,
              height: 1.55,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
