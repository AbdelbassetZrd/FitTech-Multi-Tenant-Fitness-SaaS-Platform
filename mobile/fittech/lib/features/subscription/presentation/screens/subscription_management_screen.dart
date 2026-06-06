import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../../core/errors/failures.dart';
import '../../data/repositories/subscription_repository_impl.dart';
import '../../domain/entities/subscription_entity.dart';
import '../../../../injection_container.dart';
import '../../../../core/fittech_theme.dart';

class SubscriptionManagementScreen extends StatefulWidget {
  final UserEntity? user;

  const SubscriptionManagementScreen({
    super.key,
    this.user,
  });

  @override
  State<SubscriptionManagementScreen> createState() =>
      _SubscriptionManagementScreenState();
}

class _SubscriptionManagementScreenState
    extends State<SubscriptionManagementScreen> {
  late final SubscriptionRepository _subscriptionRepository;
  WebViewController? _webViewController;

  /// True when webview_flutter has a native platform implementation available
  /// (Android / iOS). False on desktop (Linux, Windows, macOS) and web.
  bool get _canUseWebView => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  List<SubscriptionPlanEntity> plans = [];
  SubscriptionStatusEntity? subscriptionStatus;
  bool isLoadingPlans = false;
  bool isLoadingStatus = false;
  String? selectedCheckoutUrl;
  String? selectedTransactionId;
  int? selectedPaymentId;

  @override
  void initState() {
    super.initState();
    _subscriptionRepository = sl<SubscriptionRepository>();
    _loadPlans();
    _checkSubscriptionStatus();
    if (_canUseWebView) {
      _initializeWebView();
    }
  }

  void _initializeWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            debugPrint('Page started: $url');
          },
          onPageFinished: (String url) {
            debugPrint('Page finished: $url');
            // Check if redirected to success page
            if (url.contains('payment-success')) {
              _handlePaymentSuccess(url);
            } else if (url.contains('payment-failure')) {
              _handlePaymentFailure(url);
            }
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('Web error: ${error.description}');
          },
        ),
      );
  }

  Future<void> _loadPlans() async {
    setState(() => isLoadingPlans = true);
    final result = await _subscriptionRepository.getSubscriptionPlans();

    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${failure.message}')),
        );
      },
      (loadedPlans) {
        setState(() {
          plans = loadedPlans;
          isLoadingPlans = false;
        });
      },
    );
  }

  Future<void> _checkSubscriptionStatus() async {
    setState(() => isLoadingStatus = true);
    final result = await _subscriptionRepository.checkSubscriptionStatus();

    result.fold(
      (failure) {
        debugPrint('Error checking status: ${failure.message}');
        setState(() => isLoadingStatus = false);
        if (failure is UnauthorizedFailure || failure is TokenExpiredFailure) {
          if (mounted) {
            context.read<AuthBloc>().add(const AuthLoggedOut());
            Navigator.pushReplacementNamed(context, '/login');
          }
        }
      },
      (status) {
        setState(() {
          subscriptionStatus = status;
          isLoadingStatus = false;
        });
      },
    );
  }

  Future<void> _initiatePayment(int planId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    final result =
        await _subscriptionRepository.initiateChargilyPayment(planId);

    if (mounted) {
      Navigator.pop(context); // Close loading dialog
    }

    result.fold(
      (failure) {
        if (mounted) {
          if (failure is UnauthorizedFailure ||
              failure is TokenExpiredFailure) {
            context.read<AuthBloc>().add(const AuthLoggedOut());
            Navigator.pushReplacementNamed(context, '/login');
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${failure.message}')),
          );
        }
      },
      (payment) {
        setState(() {
          selectedCheckoutUrl = payment.checkoutUrl;
          selectedTransactionId = payment.transactionId;
          selectedPaymentId = payment.paymentId;
        });

        if (mounted) {
          _openPaymentWebView(payment.checkoutUrl);
        }
      },
    );
  }

  void _openPaymentWebView(String checkoutUrl) {
    if (_canUseWebView && _webViewController != null) {
      // Mobile: show in-app WebView dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          child: Column(
            children: [
              AppBar(
                title: const Text('Complete Payment'),
                automaticallyImplyLeading: true,
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Expanded(
                child: WebViewWidget(
                  controller: _webViewController!,
                ),
              ),
            ],
          ),
        ),
      );

      _webViewController!.loadRequest(Uri.parse(checkoutUrl));
    } else {
      // Desktop / Web: open in external system browser
      _openInExternalBrowser(checkoutUrl);
    }
  }

  Future<void> _openInExternalBrowser(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      // Show a dialog telling the user to complete payment in their browser
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Complete Payment'),
            content: const Text(
              'The checkout page has been opened in your browser. '
              'After completing the payment, return here and tap '
              '"I\'ve Completed Payment" to verify.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  if (selectedTransactionId != null &&
                      selectedPaymentId != null) {
                    _verifyPayment(selectedTransactionId!, selectedPaymentId!);
                  } else {
                    _checkSubscriptionStatus();
                  }
                },
                child: const Text("I've Completed Payment"),
              ),
            ],
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open the checkout page.'),
          ),
        );
      }
    }
  }

  void _handlePaymentSuccess(String url) {
    // transaction_id is stored from the initiate step.
    // payment_id comes from the redirect URL query param.
    final uri = Uri.parse(url);
    final paymentIdStr = uri.queryParameters['payment_id'];
    final transactionId = selectedTransactionId;
    final paymentId =
        (paymentIdStr != null ? int.tryParse(paymentIdStr) : null) ??
            selectedPaymentId;

    if (transactionId != null && paymentId != null) {
      _verifyPayment(transactionId, paymentId);
    }
  }

  void _handlePaymentFailure(String url) {
    Navigator.pop(context); // Close webview
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Payment failed. Please try again.'),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _verifyPayment(String transactionId, int paymentId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    final result = await _subscriptionRepository.verifyChargilyPayment(
      transactionId: transactionId,
      paymentId: paymentId,
    );

    if (mounted) {
      Navigator.pop(context); // Close loading dialog
      Navigator.pop(context); // Close webview
    }

    result.fold(
      (failure) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${failure.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      (status) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Payment successful! Your subscription is now active.'),
              backgroundColor: Colors.green,
            ),
          );
          _checkSubscriptionStatus();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveSubscription =
        subscriptionStatus?.hasActiveSubscription ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Subscription'),
        centerTitle: true,
      ),
      body: FitBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Section
              if (isLoadingStatus)
                const Center(child: CircularProgressIndicator())
              else if (hasActiveSubscription)
                _buildActiveSubscriptionCard()
              else
                _buildNoSubscriptionCard(),

              const SizedBox(height: 32),

              // Available Plans Section
              Text(
                'Available Plans',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),

              if (isLoadingPlans)
                const Center(child: CircularProgressIndicator())
              else if (plans.isEmpty)
                Center(
                  child: Text(
                    'No plans available',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: plans.length,
                  itemBuilder: (context, index) {
                    final plan = plans[index];
                    return _buildPlanCard(plan);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveSubscriptionCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 12),
                Text(
                  'Active Subscription',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (subscriptionStatus?.subscription != null) ...[
              _buildSubscriptionDetailRow(
                'Plan',
                subscriptionStatus!.subscription!.plan.name,
              ),
              _buildSubscriptionDetailRow(
                'Status',
                subscriptionStatus!.subscription!.status.toUpperCase(),
              ),
              _buildSubscriptionDetailRow(
                'Start Date',
                subscriptionStatus!.subscription!.startDate,
              ),
              if (subscriptionStatus!.subscription!.endDate != null)
                _buildSubscriptionDetailRow(
                  'Expiry Date',
                  subscriptionStatus!.subscription!.endDate!,
                ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // TODO: Add functionality for managing subscription (pause, cancel, etc.)
                },
                child: const Text('Manage Subscription'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoSubscriptionCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.orange),
              const SizedBox(width: 12),
              Text(
                'No Active Subscription',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a plan below to get started and unlock premium features.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(SubscriptionPlanEntity plan) {
    final isFeatured = plan.isFeatured;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: isFeatured ? 4 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isFeatured
                ? Theme.of(context).primaryColor
                : Colors.transparent,
            width: isFeatured ? 2 : 0,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Featured badge
              if (isFeatured)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Featured',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const SizedBox(height: 12),

              // Plan name and price
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.name,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        if (plan.description != null)
                          Text(
                            plan.description!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${plan.price.toStringAsFixed(0)} DA',
                          textAlign: TextAlign.end,
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                        ),
                        Text(
                          _planPeriodLabel(plan.planType),
                          textAlign: TextAlign.end,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Plan details
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  if (plan.durationDays != null)
                    _buildPlanDetailChip(
                      '${plan.durationDays} days',
                    ),
                  if (plan.sessionCount != null)
                    _buildPlanDetailChip(
                      '${plan.sessionCount} sessions',
                    ),
                  _buildPlanDetailChip(
                    '${plan.timesPerWeek}/week',
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Subscribe button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _initiatePayment(plan.id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isFeatured
                        ? Theme.of(context).primaryColor
                        : Colors.grey[700],
                  ),
                  child: const Text(
                    'Subscribe Now',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _planPeriodLabel(String planType) {
    switch (planType) {
      case 'monthly':
        return '/ month';
      case 'annual':
        return '/ year';
      case 'per_session':
        return '/ session';
      case 'free_trial':
        return 'free trial';
      default:
        return '';
    }
  }

  Widget _buildPlanDetailChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}
