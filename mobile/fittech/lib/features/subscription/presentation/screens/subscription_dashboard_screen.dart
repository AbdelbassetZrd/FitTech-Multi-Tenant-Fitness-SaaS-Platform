import 'package:flutter/material.dart';

import '../../../../core/fittech_theme.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../../injection_container.dart';
import '../../../subscription/data/datasources/subscription_remote_datasource.dart';

class SubscriptionDashboardScreen extends StatefulWidget {
  const SubscriptionDashboardScreen({super.key});

  @override
  State<SubscriptionDashboardScreen> createState() =>
      _SubscriptionDashboardScreenState();
}

class _SubscriptionDashboardScreenState
    extends State<SubscriptionDashboardScreen> {
  final TokenStorage _storage = sl<TokenStorage>();
  final SubscriptionRemoteDataSource _remote =
      sl<SubscriptionRemoteDataSource>();

  Map<String, dynamic>? _subscription;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSubscription();
  }

  Future<void> _loadSubscription() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final entity = await _remote.getMySubscription();
      final plan = entity.plan;

      // Map backend fields to the keys the dashboard widgets read.
      String billingSuffix;
      switch (plan.planType) {
        case 'annual':
          billingSuffix = '/ year';
          break;
        case 'per_session':
          billingSuffix = '/ session';
          break;
        case 'free_trial':
          billingSuffix = 'free trial';
          break;
        default:
          billingSuffix = '/ month';
      }

      final map = <String, dynamic>{
        'planId': plan.id,
        'planName': plan.name,
        'price': plan.price.toStringAsFixed(0),
        'currency': 'DA',
        'planDescription': plan.description ?? '',
        'billingSuffix': billingSuffix,
        'planType': plan.planType,
        'durationDays': plan.durationDays,
        'sessionCount': plan.sessionCount,
        'timesPerWeek': plan.timesPerWeek,
        'activatedAt': entity.startDate,
        'renewAt': entity.endDate,
        'status': entity.status,
      };

      await _storage.saveSubscription(map);

      if (!mounted) return;
      setState(() {
        _subscription = map;
        _isLoading = false;
      });
    } catch (e) {
      // If 404, user has no active subscription — show empty state.
      final msg = e.toString();
      final isNotFound = msg.contains('404') ||
          msg.toLowerCase().contains('no active subscription');

      final cached = await _storage.getSubscription();
      if (!mounted) return;
      setState(() {
        _subscription = cached;
        _error = isNotFound ? null : msg;
        _isLoading = false;
      });
    }
  }

  String _stringValue(String key, [String fallback = '—']) {
    final value = _subscription?[key];
    if (value == null) {
      return fallback;
    }
    final text = value.toString();
    return text.isEmpty ? fallback : text;
  }

  int? _intValue(String key) {
    final value = _subscription?[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '');
  }

  DateTime? _dateValue(String key) {
    final value = _subscription?[key]?.toString();
    if (value == null || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return '—';
    }
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day/$month/${local.year}';
  }

  String _durationLabel() {
    final planType = _stringValue('planType', 'monthly');
    final durationDays = _intValue('durationDays');
    final sessionCount = _intValue('sessionCount');

    switch (planType) {
      case 'annual':
        return '${durationDays ?? 365} days';
      case 'per_session':
        return '${sessionCount ?? 0} sessions';
      case 'free_trial':
        return '${durationDays ?? 1} day trial';
      default:
        return '${durationDays ?? 30} days';
    }
  }

  String _timeLeftLabel() {
    final renewAt = _dateValue('renewAt');
    if (renewAt == null) {
      final sessions = _intValue('sessionCount');
      return sessions == null
          ? 'Renewal unavailable'
          : '$sessions sessions left';
    }

    final difference = renewAt.difference(DateTime.now());
    if (difference.isNegative) {
      return 'Renew now';
    }

    final days = difference.inDays;
    final hours = difference.inHours % 24;
    if (days > 0) {
      return '$days days left';
    }
    if (hours > 0) {
      return '$hours hours left';
    }
    return 'Less than 1 hour left';
  }

  void _goToProfile() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/profile',
      (route) => route.settings.name == '/home',
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _goToProfile();
        }
      },
      child: Scaffold(
        body: FitBackground(
          child: SafeArea(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: FitColors.green),
                  )
                : _error != null
                    ? _ErrorState(
                        message: _error!,
                        onRetry: _loadSubscription,
                      )
                    : _subscription == null
                        ? _EmptySubscriptionState(onBrowsePlans: () {
                            Navigator.pushReplacementNamed(
                                context, '/subscription');
                          })
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    _DashboardBackButton(onTap: _goToProfile),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Text(
                                        'SUBSCRIPTION DASHBOARD',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: _loadSubscription,
                                      icon: const Icon(
                                        Icons.refresh,
                                        color: FitColors.label,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: FitColors.surface,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: FitColors.green
                                          .withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: FitColors.green
                                              .withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: const Text(
                                          'ACTIVE PLAN',
                                          style: TextStyle(
                                            color: FitColors.green,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        _stringValue(
                                            'planName', 'Subscription'),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 28,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _stringValue('planDescription',
                                            'Your plan is active.'),
                                        style: const TextStyle(
                                          color: FitColors.label,
                                          fontSize: 14,
                                          height: 1.5,
                                        ),
                                      ),
                                      const SizedBox(height: 18),
                                      Row(
                                        children: [
                                          Text(
                                            '${_stringValue('price')} ${_stringValue('currency')}',
                                            style: const TextStyle(
                                              color: FitColors.green,
                                              fontSize: 24,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _stringValue(
                                                'billingSuffix', '/month'),
                                            style: const TextStyle(
                                              color: FitColors.hint,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _MetricCard(
                                        title: 'Duration',
                                        value: _durationLabel(),
                                        icon: Icons.calendar_month_outlined,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _MetricCard(
                                        title: 'Time Left',
                                        value: _timeLeftLabel(),
                                        icon: Icons.timelapse_outlined,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _MetricCard(
                                        title: 'Activated',
                                        value: _formatDate(
                                            _dateValue('activatedAt')),
                                        icon: Icons.play_circle_outline,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _MetricCard(
                                        title: 'Renewal',
                                        value:
                                            _formatDate(_dateValue('renewAt')),
                                        icon: Icons.update_outlined,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: FitColors.surface,
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'ACCESS DETAILS',
                                        style: TextStyle(
                                          color: FitColors.green,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      _DetailRow(
                                        label: 'Plan type',
                                        value:
                                            _stringValue('planType', 'monthly')
                                                .replaceAll('_', ' '),
                                      ),
                                      _DetailRow(
                                        label: 'Gym visits / week',
                                        value:
                                            '${_intValue('timesPerWeek') ?? 0}',
                                      ),
                                      _DetailRow(
                                        label: 'Status',
                                        value: 'Active',
                                      ),
                                      if (_intValue('sessionCount') != null)
                                        _DetailRow(
                                          label: 'Sessions included',
                                          value: '${_intValue('sessionCount')}',
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 18),
                                FitPrimaryButton(
                                  label: 'CHANGE OR RENEW PLAN',
                                  onPressed: () => Navigator.pushNamed(
                                    context,
                                    '/subscription',
                                  ),
                                ),
                              ],
                            ),
                          ),
          ),
        ),
      ),
    );
  }
}

class _DashboardBackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _DashboardBackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: FitColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.arrow_back_ios_new,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FitColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: FitColors.green, size: 20),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: FitColors.label,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: FitColors.muted,
                fontSize: 14,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 52),
            const SizedBox(height: 14),
            const Text(
              'Something went wrong',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: FitColors.label,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            FitPrimaryButton(label: 'RETRY', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}

class _EmptySubscriptionState extends StatelessWidget {
  final VoidCallback onBrowsePlans;

  const _EmptySubscriptionState({required this.onBrowsePlans});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.workspace_premium_outlined,
              color: FitColors.hint,
              size: 52,
            ),
            const SizedBox(height: 14),
            const Text(
              'No active subscription yet.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Choose a plan and complete payment to see your active subscription dashboard here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: FitColors.label,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            FitPrimaryButton(
              label: 'BROWSE PLANS',
              onPressed: onBrowsePlans,
            ),
          ],
        ),
      ),
    );
  }
}
