import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/fittech_theme.dart';
import '../../../../injection_container.dart';
import '../../domain/entities/contact_entity.dart';
import '../bloc/messaging_bloc.dart';
import 'chat_screen.dart';

class MessagingScreen extends StatelessWidget {
  const MessagingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<MessagingBloc>(
      create: (_) => sl<MessagingBloc>()..add(const ContactsRequested()),
      child: const _MessagingView(),
    );
  }
}

class _MessagingView extends StatefulWidget {
  const _MessagingView();

  @override
  State<_MessagingView> createState() => _MessagingViewState();
}

class _MessagingViewState extends State<_MessagingView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    // Filter contacts in real-time based on search query
    // Filtering is done in the _SearchTab builder in real-time
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Messaging',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: FitColors.green,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: FitColors.muted,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
          tabs: const [
            Tab(text: 'Recent'),
            Tab(text: 'Search'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Recent Chats Tab
          _RecentChatsTab(),
          // Search Tab
          _SearchTab(searchController: _searchController),
        ],
      ),
    );
  }
}

class _RecentChatsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MessagingBloc, MessagingState>(
      builder: (context, state) {
        if (state.contactsStatus == ContactsStatus.loading ||
            state.contactsStatus == ContactsStatus.initial) {
          return const Center(
            child: CircularProgressIndicator(color: FitColors.green),
          );
        }
        if (state.contactsStatus == ContactsStatus.failure) {
          return _ErrorView(
            message: state.contactsError ?? 'Failed to load contacts.',
            onRetry: () =>
                context.read<MessagingBloc>().add(const ContactsRequested()),
          );
        }
        // Filter to coaches and admins (members chat only with staff/AI).
        // Show only contacts with existing messages
        final visible = state.contacts
            .where((c) =>
                (c.role == 'coach' || c.role == 'admin' || c.role == 'bot') &&
                c.lastMessage != null &&
                c.lastMessage!.isNotEmpty)
            .toList();

        if (visible.isEmpty) {
          return RefreshIndicator(
            color: FitColors.green,
            onRefresh: () async {
              context.read<MessagingBloc>().add(const ContactsRequested());
            },
            child: ListView(
              children: const [
                SizedBox(height: 80),
                Center(
                  child: Text(
                    'No recent conversations yet.\nStart a conversation from Search!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: FitColors.muted),
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          color: FitColors.green,
          onRefresh: () async {
            context.read<MessagingBloc>().add(const ContactsRequested());
          },
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: visible.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _ContactTile(contact: visible[i]),
          ),
        );
      },
    );
  }
}

class _SearchTab extends StatefulWidget {
  final TextEditingController searchController;
  const _SearchTab({required this.searchController});

  @override
  State<_SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<_SearchTab> {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    widget.searchController.addListener(_updateSearch);
  }

  @override
  void dispose() {
    widget.searchController.removeListener(_updateSearch);
    super.dispose();
  }

  void _updateSearch() {
    setState(() {
      _searchQuery = widget.searchController.text.trim().toLowerCase();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MessagingBloc, MessagingState>(
      builder: (context, state) {
        if (state.contactsStatus == ContactsStatus.loading ||
            state.contactsStatus == ContactsStatus.initial) {
          return Column(
            children: [
              _SearchBar(controller: widget.searchController),
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: FitColors.green),
                ),
              ),
            ],
          );
        }

        // Filter to coaches and admins (members chat only with staff/AI).
        var allContacts = state.contacts
            .where((c) =>
                c.role == 'coach' || c.role == 'admin' || c.role == 'bot')
            .toList();

        // Filter by search query
        List<ContactEntity> filtered = [];
        if (_searchQuery.isEmpty) {
          // Show all available contacts
          filtered = allContacts;
        } else {
          // Filter by name or email matching search query
          filtered = allContacts
              .where((c) =>
                  c.name.toLowerCase().contains(_searchQuery) ||
                  c.email.toLowerCase().contains(_searchQuery))
              .toList();
        }

        return Column(
          children: [
            _SearchBar(controller: widget.searchController),
            Expanded(
              child: _searchQuery.isEmpty && filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'Start typing to search for contacts',
                        style: TextStyle(color: FitColors.muted),
                      ),
                    )
                  : filtered.isEmpty
                      ? Center(
                          child: Text(
                            'No contacts found matching "$_searchQuery"',
                            style: const TextStyle(color: FitColors.muted),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) =>
                              _ContactTile(contact: filtered[i]),
                        ),
            ),
          ],
        );
      },
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  const _SearchBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search contacts...',
          hintStyle: const TextStyle(color: FitColors.muted),
          prefixIcon: const Icon(Icons.search, color: FitColors.muted),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: FitColors.muted),
                  onPressed: () {
                    controller.clear();
                  },
                )
              : null,
          filled: true,
          fillColor: const Color(0xFF202A42),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final ContactEntity contact;
  const _ContactTile({required this.contact});

  @override
  Widget build(BuildContext context) {
    final initial =
        contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?';
    final unread = contact.hasUnread;
    final preview = contact.lastMessage;
    final timeLabel = _formatTimestamp(contact.lastMessageAt);

    return Material(
      color: unread
          ? FitColors.green.withValues(alpha: 0.10)
          : const Color(0xFF202A42),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChatScreen(contact: contact),
            ),
          );
          if (context.mounted) {
            context.read<MessagingBloc>().add(const ContactsRequested());
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: FitColors.green.withValues(alpha: 0.18),
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: FitColors.green,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (unread)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        constraints: const BoxConstraints(minWidth: 18),
                        decoration: BoxDecoration(
                          color: FitColors.green,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: const Color(0xFF1A1A2E),
                            width: 2,
                          ),
                        ),
                        child: Text(
                          contact.unreadCount > 99
                              ? '99+'
                              : '${contact.unreadCount}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            contact.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight:
                                  unread ? FontWeight.w900 : FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (timeLabel != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            timeLabel,
                            style: TextStyle(
                              color: unread ? FitColors.green : FitColors.muted,
                              fontSize: 11,
                              fontWeight:
                                  unread ? FontWeight.w800 : FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      preview != null && preview.isNotEmpty
                          ? (contact.lastFromMe ? 'You: $preview' : preview)
                          : contact.role.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: unread ? Colors.white : FitColors.muted,
                        fontSize: preview == null ? 11 : 13,
                        letterSpacing: preview == null ? 1.0 : 0,
                        fontWeight: unread
                            ? FontWeight.w800
                            : (preview == null
                                ? FontWeight.w700
                                : FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String? _formatTimestamp(DateTime? dt) {
    if (dt == null) return null;
    final local = dt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(local.year, local.month, local.day);
    final diffDays = today.difference(that).inDays;
    if (diffDays == 0) {
      final h = local.hour.toString().padLeft(2, '0');
      final m = local.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    if (diffDays == 1) return 'Yesterday';
    if (diffDays < 7) {
      const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return names[local.weekday - 1];
    }
    final dd = local.day.toString().padLeft(2, '0');
    final mm = local.month.toString().padLeft(2, '0');
    return '$dd/$mm';
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: FitColors.muted, size: 36),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: FitColors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
