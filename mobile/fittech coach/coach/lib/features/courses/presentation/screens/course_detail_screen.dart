import 'package:flutter/material.dart';
import '../../../../core/network/coach_api_client.dart';
import '../../../../core/network/api_paths.dart';
import '../../../../core/theme/app_colors.dart';

class CourseDetailScreen extends StatefulWidget {
  final int courseId;
  const CourseDetailScreen({super.key, required this.courseId});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  final _api = CoachApiClient();
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _course;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.get(
        ApiPaths.coachCourseDetail(widget.courseId),
        requiresAuth: true,
      );
      // Handle both direct map and nested data structure
      final data = (res['data'] ?? res) as dynamic;
      final courseMap = data is Map<String, dynamic>
          ? data
          : data is Map
          ? Map<String, dynamic>.from(data)
          : {};
      setState(() {
        _course = (courseMap as Map<String, dynamic>?) ?? {};
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _openSession(int sessionId) {
    final sessions = (_course?['sessions'] as List<dynamic>?) ?? [];
    final session = sessions.firstWhere(
      (s) => s['id'] == sessionId,
      orElse: () => null,
    );

    Navigator.of(context).pushNamed(
      '/sessions/attendance',
      arguments: {
        'sessionId': sessionId,
        'bookings': session?['bookings'] ?? [],
      },
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_course?['name'] ?? 'Course Detail'),
        backgroundColor: const Color(0xFF09101D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF09101D), Color(0xFF101A2E), Color(0xFF0A1220)],
          ),
        ),
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.green),
              )
            : (_error != null)
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, color: AppColors.green, size: 60),
                    const SizedBox(height: 16),
                    Text('Error: $_error', textAlign: TextAlign.center),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Course Header Card
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF1A2437), Color(0xFF131D31)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _course?['name'] ?? 'Course',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if ((_course?['description'] ?? '').isNotEmpty)
                            Text(
                              _course!['description'],
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _InfoChip(
                                  icon: Icons.calendar_today_outlined,
                                  label: _course?['day'] ?? 'Mon',
                                  value: '${_course?['time'] ?? '10:00'}',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _InfoChip(
                                  icon: Icons.people_outline,
                                  label: 'Max Members',
                                  value: '${_course?['max_members'] ?? '0'}',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Sessions Section
                    const Text(
                      'SESSIONS',
                      style: TextStyle(
                        color: AppColors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Builder(
                      builder: (context) {
                        final sessions =
                            (_course?['sessions'] as List<dynamic>?) ?? [];
                        if (sessions.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 32),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.event_busy_outlined,
                                    color: AppColors.muted,
                                    size: 40,
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'No sessions yet',
                                    style: TextStyle(color: AppColors.muted),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: sessions.length,
                          itemBuilder: (context, index) {
                            final s = sessions[index];
                            final bookings =
                                (s['bookings'] as List<dynamic>?) ?? [];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: GestureDetector(
                                onTap: () => _openSession(s['id']),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.card,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: AppColors.green.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: AppColors.green.withValues(
                                            alpha: 0.15,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.event_note_outlined,
                                          color: AppColors.green,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _formatDate(s['date'] ?? ''),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${s['time'] ?? ''} • ${bookings.length} booking${bookings.length != 1 ? 's' : ''}',
                                              style: const TextStyle(
                                                color: AppColors.muted,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.arrow_forward_ios,
                                        color: AppColors.green.withValues(
                                          alpha: 0.6,
                                        ),
                                        size: 14,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.green, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(color: AppColors.muted, fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
