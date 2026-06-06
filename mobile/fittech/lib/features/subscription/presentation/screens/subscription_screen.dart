import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/fittech_theme.dart';
import '../../../../core/network/api_client.dart';
import '../../../../injection_container.dart';

class _Plan {
  final int id;
  final String name;
  final String planType;
  final double price;
  final int timesPerWeek;
  final int? durationDays;
  final int? sessionCount;
  final String description;
  final bool isFeatured;

  const _Plan({
    required this.id,
    required this.name,
    required this.planType,
    required this.price,
    required this.timesPerWeek,
    required this.durationDays,
    required this.sessionCount,
    required this.description,
    required this.isFeatured,
  });

  factory _Plan.fromJson(Map<String, dynamic> json) {
    return _Plan(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] ?? 'Gym Access').toString(),
      planType: (json['plan_type'] ?? 'monthly').toString(),
      price: double.tryParse((json['price'] ?? '0').toString()) ?? 0,
      timesPerWeek: (json['times_per_week'] as num?)?.toInt() ?? 0,
      durationDays: (json['duration_days'] as num?)?.toInt(),
      sessionCount: (json['session_count'] as num?)?.toInt(),
      description: (json['description'] ?? '').toString(),
      isFeatured: (json['is_featured'] ?? false) as bool,
    );
  }

  String get displayPrice {
    if (price == price.roundToDouble()) {
      return price.toStringAsFixed(0);
    }
    return price.toStringAsFixed(2);
  }

  String get billingSuffix {
    switch (planType) {
      case 'annual':
        return '/year';
      case 'per_session':
        return '/pack';
      case 'free_trial':
        return '/trial';
      default:
        return '/month';
    }
  }

  String get accessSummary {
    switch (planType) {
      case 'annual':
        return '${durationDays ?? 365}-day unlimited gym access';
      case 'per_session':
        return '${sessionCount ?? 0} gym sessions included';
      case 'free_trial':
        return '${durationDays ?? 1}-day free trial';
      default:
        return '${durationDays ?? 30}-day gym access';
    }
  }

  String get checkoutSubtitle {
    if (description.isNotEmpty) {
      return description;
    }
    return accessSummary;
  }

  List<String> get highlights {
    final items = <String>[accessSummary];
    if (timesPerWeek > 0) {
      items.add('$timesPerWeek gym visits per week');
    }
    if (description.isNotEmpty) {
      items.add(description);
    }
    return items;
  }
}

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final ApiClient _apiClient = sl<ApiClient>();

  bool _isLoading = true;
  String? _error;
  List<_Plan> _plans = const [];
  int? _selectedPlanId;

  _Plan? get _selected {
    if (_plans.isEmpty) {
      return null;
    }
    return _plans.firstWhere(
      (plan) => plan.id == _selectedPlanId,
      orElse: () => _plans.first,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final json = await _apiClient.get(
        AppConstants.subscriptionPlans,
        requiresAuth: false,
      );
      final data = json['data'];
      final plans = data is List
          ? data
              .whereType<Map>()
              .map((item) => _Plan.fromJson(Map<String, dynamic>.from(item)))
              .toList()
          : <_Plan>[];

      setState(() {
        _plans = plans;
        _selectedPlanId = plans.isNotEmpty
            ? plans
                .firstWhere(
                  (plan) => plan.isFeatured,
                  orElse: () => plans.first,
                )
                .id
            : null;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Unable to load gym access plans.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;

    return Scaffold(
      body: FitBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    _iconBtn(
                      Icons.arrow_back_ios_new,
                      () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        'GYM ACCESS PLANS',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    _iconBtn(Icons.refresh, _loadPlans),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: FitColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.local_offer_outlined,
                          color: FitColors.green, size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Live plans from admin',
                          style: TextStyle(
                            color: FitColors.label,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(child: _buildBody()),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  children: [
                    const Text(
                      'SELECT A PLAN TO CONTINUE TO CHECKOUT.',
                      style: TextStyle(
                        color: FitColors.hint,
                        fontSize: 10,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FitPrimaryButton(
                      label: selected == null
                          ? 'NO PLAN AVAILABLE'
                          : 'CONTINUE WITH ${selected.name.toUpperCase()}',
                      onPressed: selected == null
                          ? null
                          : () => Navigator.pushNamed(
                                context,
                                '/checkout',
                                arguments: {
                                  'planId': selected.id,
                                  'planName': selected.name,
                                  'price': selected.displayPrice,
                                  'currency': 'DZD',
                                  'planDescription': selected.checkoutSubtitle,
                                  'billingSuffix': selected.billingSuffix,
                                  'planType': selected.planType,
                                  'durationDays': selected.durationDays,
                                  'sessionCount': selected.sessionCount,
                                  'timesPerWeek': selected.timesPerWeek,
                                },
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

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: FitColors.green),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off_rounded,
                  color: FitColors.hint, size: 42),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
              const SizedBox(height: 14),
              FitPrimaryButton(label: 'TRY AGAIN', onPressed: _loadPlans),
            ],
          ),
        ),
      );
    }

    if (_plans.isEmpty) {
      return const Center(
        child: Text(
          'No active gym plans found.',
          style: TextStyle(color: Colors.white, fontSize: 15),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: _plans
            .map(
              (plan) => _PlanCard(
                plan: plan,
                isSelected: _selectedPlanId == plan.id,
                onTap: () => setState(() => _selectedPlanId = plan.id),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: FitColors.surface,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, color: FitColors.label, size: 18),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final _Plan plan;
  final bool isSelected;
  final VoidCallback onTap;

  const _PlanCard({
    required this.plan,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: FitColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? FitColors.green : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: FitColors.green.withValues(alpha: 0.15),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (plan.isFeatured)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: const BoxDecoration(
                  color: FitColors.green,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: const Center(
                  child: Text(
                    'FEATURED PLAN',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          plan.name,
                          style: TextStyle(
                            color: plan.isFeatured
                                ? FitColors.green
                                : FitColors.label,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              isSelected ? FitColors.green : Colors.transparent,
                          border: Border.all(
                            color:
                                isSelected ? FitColors.green : FitColors.hint,
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 13)
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${plan.displayPrice} DZD',
                        style: TextStyle(
                          color:
                              plan.isFeatured ? FitColors.green : Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4, left: 6),
                        child: Text(
                          plan.billingSuffix,
                          style: const TextStyle(
                            color: FitColors.label,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...plan.highlights.map(
                    (feature) => Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(
                              Icons.check_circle_outline,
                              color: FitColors.green,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              feature,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
