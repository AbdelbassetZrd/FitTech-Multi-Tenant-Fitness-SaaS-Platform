import 'package:flutter/material.dart';
import '../../../../core/network/coach_api_client.dart';
import '../../../../core/network/api_paths.dart';
import '../../../../core/storage/session_store.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/panel.dart';
import '../../../../core/models/coach_profile.dart';
import '../../../../core/models/coach_session.dart';
import '../widgets/coach_sidebar.dart';
import '../widgets/coach_hero_card.dart';
import '../widgets/metric_card.dart';
import '../widgets/session_summary_card.dart';
import '../widgets/attendance_panel.dart';
import '../widgets/stat_row.dart';
import '../widgets/warning_row.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../widgets/messaging_view.dart';

enum CoachTab { schedule, messaging, profile }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen();

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _api = CoachApiClient();

  bool _isLoading = true;
  bool _isSubmittingAttendance = false;
  String? _error;

  CoachProfile? _profile;
  List<CoachSession> _sessions = const [];
  List<CoachSessionStat> _stats = const [];
  CoachEarnings? _earnings;
  List<AbsenceWarning> _warnings = const [];
  CoachTab _currentTab = CoachTab.schedule;

  int? _selectedSessionId;
  final Set<String> _selectedMemberIds = <String>{};

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final profileJson = await _api.get(ApiPaths.profile, requiresAuth: true);
      final sessionsJson = await _api.get(
        ApiPaths.coachSessions,
        requiresAuth: true,
      );
      final statsJson = await _api.get(ApiPaths.coachStats, requiresAuth: true);
      final earningsJson = await _api.get(
        ApiPaths.coachEarnings,
        requiresAuth: true,
      );
      final warningsJson = await _api.get(
        ApiPaths.absenceWarnings,
        requiresAuth: true,
      );

      final sessions =
          (sessionsJson['data'] ?? sessionsJson as dynamic) as List<dynamic>;
      final stats =
          (statsJson['data'] ?? statsJson as dynamic) as List<dynamic>;
      final warnings =
          (warningsJson['data'] ?? warningsJson as dynamic) as List<dynamic>;

      final sessionModels = sessions
          .whereType<Map>()
          .map((item) => CoachSession.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      final statModels = stats
          .whereType<Map>()
          .map(
            (item) =>
                CoachSessionStat.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
      final warningModels = warnings
          .whereType<Map>()
          .map(
            (item) => AbsenceWarning.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();

      if (!mounted) return;
      setState(() {
        _profile = CoachProfile.fromJson(profileJson);
        _sessions = sessionModels;
        _stats = statModels;
        _earnings = CoachEarnings.fromJson(earningsJson);
        _warnings = warningModels;
        _selectedSessionId = _pickDefaultSession(sessionModels)?.id;
        _selectedMemberIds
          ..clear()
          ..addAll(_defaultSelectedIds(_pickDefaultSession(sessionModels)));
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  CoachSession? _pickDefaultSession(List<CoachSession> sessions) {
    if (sessions.isEmpty) return null;
    final today = DateTime.now();
    for (final session in sessions) {
      if (isSameDay(session.date, today)) return session;
    }
    return sessions.first;
  }

  Set<String> _defaultSelectedIds(CoachSession? session) {
    if (session == null || session.attendanceMarked) return <String>{};
    return session.confirmedBookings.map((booking) => booking.memberId).toSet();
  }

  CoachSession? get _selectedSession {
    if (_selectedSessionId == null) return null;
    for (final session in _sessions) {
      if (session.id == _selectedSessionId) return session;
    }
    return null;
  }

  int get _todaySessionsCount => _sessions
      .where((session) => isSameDay(session.date, DateTime.now()))
      .length;

  int get _todayMembersCount => _sessions
      .where((session) => isSameDay(session.date, DateTime.now()))
      .fold<int>(0, (sum, session) => sum + session.confirmedCount);

  Future<void> _submitAttendance() async {
    final session = _selectedSession;
    if (session == null || session.attendanceMarked) return;
    setState(() => _isSubmittingAttendance = true);
    try {
      final response = await _api.post(
        ApiPaths.attendance(session.id),
        requiresAuth: true,
        body: {'present_member_ids': _selectedMemberIds.toList()},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response['detail']?.toString() ?? 'Attendance marked.'),
        ),
      );
      await _loadDashboard();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
      setState(() => _isSubmittingAttendance = false);
    }
  }

  Future<void> _openProfile() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
    await _loadDashboard();
  }

  Future<void> _logout() async {
    await SessionStore.clear();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  bool _canValidate(CoachSession session) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(
      session.date.year,
      session.date.month,
      session.date.day,
    );
    return !session.attendanceMarked && !date.isAfter(today);
  }

  String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString();
    return '$d/$m/$y';
  }

  String _formatTime(String value) {
    final parts = value.split(':');
    if (parts.length < 2) return value;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts[1];
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final display = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '${display.toString().padLeft(2, '0')}:$minute $suffix';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF09101D), Color(0xFF101A2E), Color(0xFF0A1220)],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.green),
                )
              : _error != null
              ? ErrorView(message: _error!, onRetry: _loadDashboard)
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 900;
                    return Row(
                      children: [
                        CoachSidebar(
                          profile: _profile!,
                          currentTab: _currentTab,
                          expanded: wide,
                          onSelectTab: (tab) =>
                              setState(() => _currentTab = tab),
                          onOpenProfile: _openProfile,
                          onOpenCourses: () {
                            Navigator.of(context).pushNamed('/courses');
                          },
                          onLogout: _logout,
                        ),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            child: KeyedSubtree(
                              key: ValueKey(_currentTab),
                              child: _buildCurrentTab(context, wide),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildCurrentTab(BuildContext context, bool wide) {
    switch (_currentTab) {
      case CoachTab.messaging:
        return MessagingViewWidget(profile: _profile!, wide: wide);
      case CoachTab.profile:
        return _buildProfileTab();
      case CoachTab.schedule:
        return RefreshIndicator(
          color: AppColors.green,
          onRefresh: _loadDashboard,
          child: _buildScheduleTab(),
        );
    }
  }

  Widget _buildScheduleTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        CoachHeroCard(profile: _profile!, onProfileTap: _openProfile),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: MetricCard(
                title: 'Today\'s Sessions',
                value: '$_todaySessionsCount',
                icon: Icons.calendar_today_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MetricCard(
                title: 'Members Today',
                value: '$_todayMembersCount',
                icon: Icons.people_outline,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: MetricCard(
                title: 'Monthly Earnings',
                value:
                    '${_earnings?.totalEarnings.toStringAsFixed(0) ?? '0'} DA',
                icon: Icons.payments_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MetricCard(
                title: 'Warnings',
                value: '${_warnings.length}',
                icon: Icons.warning_amber_rounded,
                accent: _warnings.isEmpty
                    ? AppColors.green
                    : const Color(0xFFF59E0B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const SectionTitle('Today & Upcoming Sessions'),
        const SizedBox(height: 10),
        SizedBox(
          height: 170,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _sessions.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final session = _sessions[index];
              final selected = session.id == _selectedSessionId;
              return SessionSummaryCard(
                session: session,
                selected: selected,
                formatDate: _formatDate,
                formatTime: _formatTime,
                onTap: () {
                  setState(() {
                    _selectedSessionId = session.id;
                    _selectedMemberIds
                      ..clear()
                      ..addAll(_defaultSelectedIds(session));
                  });
                },
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        if (_selectedSession != null)
          AttendancePanel(
            session: _selectedSession!,
            canValidate: _canValidate(_selectedSession!),
            selectedMemberIds: _selectedMemberIds,
            isSubmitting: _isSubmittingAttendance,
            formatDate: _formatDate,
            formatTime: _formatTime,
            onToggleMember: (memberId, selected) {
              setState(() {
                if (selected) {
                  _selectedMemberIds.add(memberId);
                } else {
                  _selectedMemberIds.remove(memberId);
                }
              });
            },
            onMarkAll: () {
              setState(() {
                _selectedMemberIds
                  ..clear()
                  ..addAll(
                    _selectedSession!.confirmedBookings.map(
                      (booking) => booking.memberId,
                    ),
                  );
              });
            },
            onClear: () => setState(_selectedMemberIds.clear),
            onSubmit: _submitAttendance,
          ),
        const SizedBox(height: 20),
        const SectionTitle('Performance Snapshot'),
        const SizedBox(height: 10),
        ..._stats
            .take(4)
            .map(
              (stat) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: StatRow(stat: stat, formatDate: _formatDate),
              ),
            ),
        if (_warnings.isNotEmpty) ...[
          const SizedBox(height: 20),
          const SectionTitle('Absence Warnings'),
          const SizedBox(height: 10),
          ..._warnings
              .take(5)
              .map(
                (warning) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: WarningRow(warning: warning),
                ),
              ),
        ],
      ],
    );
  }

  Widget _buildProfileTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        CoachHeroCard(profile: _profile!, onProfileTap: _openProfile),
        const SizedBox(height: 18),
        Panel(
          title: 'Coach Profile',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ProfileInfoChip(label: 'Email', value: _profile!.email),
                  ProfileInfoChip(
                    label: 'Phone',
                    value: _profile!.phone.isEmpty
                        ? 'Not set'
                        : _profile!.phone,
                  ),
                  ProfileInfoChip(
                    label: 'Speciality',
                    value: _profile!.specialityLabel,
                  ),
                  ProfileInfoChip(
                    label: 'Experience',
                    value: '${_profile!.yearsOfExperience} years',
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'Bio',
                style: TextStyle(
                  color: AppColors.green,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _profile!.bio.isEmpty ? 'No bio added yet.' : _profile!.bio,
                style: const TextStyle(color: Colors.white, height: 1.5),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  FilledButton(
                    onPressed: _openProfile,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.green,
                    ),
                    child: const Text('OPEN FULL PROFILE'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: _logout,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('LOG OUT'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class ProfileInfoChip extends StatelessWidget {
  const ProfileInfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1628),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
