import 'package:flutter/material.dart';

import '../../../../core/fittech_theme.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../../injection_container.dart';

class _PayMethod {
  final String id;
  final String label;
  final IconData icon;
  const _PayMethod(this.id, this.label, this.icon);
}

const List<_PayMethod> _methods = [
  _PayMethod('card', 'CREDIT CARD', Icons.credit_card),
  _PayMethod('paypal', 'PAYPAL', Icons.account_balance_wallet_outlined),
  _PayMethod('cib', 'CIB / DAHABEYA', Icons.account_balance_outlined),
  _PayMethod('baridi', 'BARIDIMOB', Icons.qr_code_2_outlined),
];

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final TokenStorage _storage = sl<TokenStorage>();

  String _currency = 'DZD';
  String _payMethod = 'card';

  // Route arguments
  int? _planId;
  String _planName = 'Elite Membership';
  String _price = '8,500';
  String _planDescription = '1 Month Access + Personal Trainer';
  String _billingSuffix = '/month';
  String _planType = 'monthly';
  int? _durationDays;
  int? _sessionCount;
  int _timesPerWeek = 0;
  bool _argsRead = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_argsRead) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map) {
        _planId = args['planId'] as int?;
        _planName = (args['planName'] as String?) ?? _planName;
        _price = (args['price'] as String?) ?? _price;
        _currency = (args['currency'] as String?) ?? _currency;
        _planDescription =
            (args['planDescription'] as String?) ?? _planDescription;
        _billingSuffix = (args['billingSuffix'] as String?) ?? _billingSuffix;
        _planType = (args['planType'] as String?) ?? _planType;
        _durationDays = args['durationDays'] as int?;
        _sessionCount = args['sessionCount'] as int?;
        _timesPerWeek = (args['timesPerWeek'] as int?) ?? _timesPerWeek;
      }
      _argsRead = true;
    }
  }

  Future<void> _completePayment() async {
    final activatedAt = DateTime.now();
    DateTime? renewAt;

    switch (_planType) {
      case 'annual':
        renewAt = activatedAt.add(Duration(days: _durationDays ?? 365));
        break;
      case 'free_trial':
        renewAt = activatedAt.add(Duration(days: _durationDays ?? 1));
        break;
      case 'per_session':
        renewAt = null;
        break;
      default:
        renewAt = activatedAt.add(Duration(days: _durationDays ?? 30));
        break;
    }

    await _storage.saveSubscription({
      'planId': _planId,
      'planName': _planName,
      'price': _price,
      'currency': _currency,
      'planDescription': _planDescription,
      'billingSuffix': _billingSuffix,
      'planType': _planType,
      'durationDays': _durationDays,
      'sessionCount': _sessionCount,
      'timesPerWeek': _timesPerWeek,
      'activatedAt': activatedAt.toIso8601String(),
      'renewAt': renewAt?.toIso8601String(),
      'status': 'active',
    });

    if (!mounted) {
      return;
    }

    _showSuccessDialog();
  }

  void _openPaySheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PaymentFormSheet(
        method: _payMethod,
        onConfirm: () {
          Navigator.pop(context); // close sheet
          _completePayment();
        },
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF1E2235),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: FitColors.green.withOpacity(0.15),
                  border: Border.all(color: FitColors.green, width: 2),
                ),
                child:
                    const Icon(Icons.check, color: FitColors.green, size: 36),
              ),
              const SizedBox(height: 20),
              const Text(
                'PAYMENT\nSUCCESSFUL!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Welcome to FitTech Premium.\nYour journey starts now!',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: FitColors.label, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 24),
              FitPrimaryButton(
                label: 'OPEN DASHBOARD',
                onPressed: () => Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/subscription-dashboard',
                  (route) => route.settings.name == '/home',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FitBackground(
        child: SafeArea(
          child: Column(
            children: [
              // ── App Bar ───────────────────────────────────────────────
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: FitColors.surface,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new,
                            color: Colors.white, size: 16),
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'CHECKOUT',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 36),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Currency ───────────────────────────────────────
                      Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: FitColors.surface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              flex: 3,
                              child: Padding(
                                padding: EdgeInsets.only(left: 14),
                                child: Text(
                                  'SELECT CURRENCY',
                                  style: TextStyle(
                                      color: FitColors.hint,
                                      fontSize: 11,
                                      letterSpacing: 0.8),
                                ),
                              ),
                            ),
                            ...['DZD', 'USD'].map((c) {
                              final active = c == _currency;
                              return GestureDetector(
                                onTap: () => setState(() => _currency = c),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  margin: const EdgeInsets.all(5),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: active
                                        ? FitColors.green
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: Text(
                                    c,
                                    style: TextStyle(
                                      color: active
                                          ? Colors.white
                                          : FitColors.label,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── Order summary ──────────────────────────────────
                      const Text(
                        'ORDER SUMMARY',
                        style: TextStyle(
                          color: FitColors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: FitColors.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF8B0000),
                                    Color(0xFF1A1A2E),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: const Icon(Icons.fitness_center,
                                  color: FitColors.green, size: 28),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$_planName Membership',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _planDescription,
                                    style: TextStyle(
                                        color: FitColors.label, fontSize: 11),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Text(
                                        _price,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _currency,
                                        style: const TextStyle(
                                            color: FitColors.label,
                                            fontSize: 13),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _billingSuffix,
                                        style: const TextStyle(
                                            color: FitColors.hint,
                                            fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── Payment method ─────────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'PAYMENT METHOD',
                            style: TextStyle(
                              color: FitColors.green,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.4,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: FitColors.surface,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: FitColors.hint.withOpacity(0.4)),
                            ),
                            child: const Text(
                              'ENCRYPTED',
                              style: TextStyle(
                                  color: FitColors.label,
                                  fontSize: 10,
                                  letterSpacing: 1),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 2.1,
                        children: _methods.map((m) {
                          final active = _payMethod == m.id;
                          return GestureDetector(
                            onTap: () => setState(() => _payMethod = m.id),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              decoration: BoxDecoration(
                                color: FitColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: active
                                      ? FitColors.green
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(m.icon,
                                      color: active
                                          ? FitColors.green
                                          : FitColors.label,
                                      size: 24),
                                  const SizedBox(height: 6),
                                  Text(
                                    m.label,
                                    style: TextStyle(
                                      color: active
                                          ? FitColors.green
                                          : FitColors.label,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 20),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shield_outlined,
                              color: FitColors.hint, size: 20),
                          SizedBox(width: 16),
                          Icon(Icons.lock_outline,
                              color: FitColors.hint, size: 20),
                          SizedBox(width: 16),
                          Icon(Icons.verified_user_outlined,
                              color: FitColors.hint, size: 20),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // ── Total + Pay ───────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                decoration: BoxDecoration(
                  color: FitColors.surface.withOpacity(0.9),
                  border: Border(
                    top: BorderSide(
                        color: FitColors.hint.withOpacity(0.2), width: 1),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'TOTAL AMOUNT',
                              style: TextStyle(
                                  color: FitColors.label,
                                  fontSize: 11,
                                  letterSpacing: 0.8),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _price,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: 4, left: 6),
                                  child: Text(
                                    _currency,
                                    style: const TextStyle(
                                        color: FitColors.label, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Text(
                          'Including VAT &\nService Fees',
                          textAlign: TextAlign.right,
                          style: TextStyle(color: FitColors.hint, fontSize: 10),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _openPaySheet,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: FitColors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'PAY NOW',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.bolt, size: 20),
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
      ),
    );
  }
}

// ─── Payment form bottom sheet ────────────────────────────────────────────────
class _PaymentFormSheet extends StatelessWidget {
  final String method;
  final VoidCallback onConfirm;

  const _PaymentFormSheet({
    required this.method,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: FitColors.hint.withOpacity(0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollCtrl,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Icon(_iconFor(method),
                            color: FitColors.green, size: 22),
                        const SizedBox(width: 10),
                        Text(
                          _titleFor(method),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _subtitleFor(method),
                      style:
                          const TextStyle(color: FitColors.label, fontSize: 13),
                    ),
                    const SizedBox(height: 24),

                    // Fields
                    ..._fields(method),

                    const SizedBox(height: 28),

                    FitPrimaryButton(
                      label: 'CONFIRM PAYMENT',
                      onPressed: onConfirm,
                    ),

                    const SizedBox(height: 12),
                    const Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_outline,
                              size: 13, color: FitColors.hint),
                          SizedBox(width: 5),
                          Text(
                            'Your payment is secured and encrypted',
                            style:
                                TextStyle(color: FitColors.hint, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String m) {
    switch (m) {
      case 'paypal':
        return Icons.account_balance_wallet_outlined;
      case 'cib':
        return Icons.account_balance_outlined;
      case 'baridi':
        return Icons.qr_code_2_outlined;
      default:
        return Icons.credit_card;
    }
  }

  String _titleFor(String m) {
    switch (m) {
      case 'paypal':
        return 'Pay with PayPal';
      case 'cib':
        return 'CIB / Dahabeya';
      case 'baridi':
        return 'BaridiMob';
      default:
        return 'Credit Card';
    }
  }

  String _subtitleFor(String m) {
    switch (m) {
      case 'paypal':
        return 'Enter your PayPal email to continue';
      case 'baridi':
        return 'Enter your BaridiMob phone number';
      default:
        return 'Enter your card details below';
    }
  }

  List<Widget> _fields(String m) {
    switch (m) {
      case 'paypal':
        return [
          _label('PAYPAL EMAIL'),
          const SizedBox(height: 8),
          _field('yourname@paypal.com', Icons.mail_outline,
              type: TextInputType.emailAddress),
        ];
      case 'baridi':
        return [
          _label('PHONE NUMBER'),
          const SizedBox(height: 8),
          _field('05XX XXX XXX', Icons.phone_outlined,
              type: TextInputType.phone),
          const SizedBox(height: 16),
          _label('BARIDIMOB PIN'),
          const SizedBox(height: 8),
          _field('••••••', Icons.lock_outline,
              obscure: true, type: TextInputType.number),
        ];
      default:
        return [
          _label('CARDHOLDER NAME'),
          const SizedBox(height: 8),
          _field('JOHN DOE', Icons.person_outline),
          const SizedBox(height: 16),
          _label('CARD NUMBER'),
          const SizedBox(height: 8),
          _field('0000 0000 0000 0000', Icons.credit_card,
              type: TextInputType.number),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('EXPIRY DATE'),
                    const SizedBox(height: 8),
                    _field('MM/YY', Icons.date_range_outlined,
                        type: TextInputType.number),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('CVV'),
                    const SizedBox(height: 8),
                    _field('•••', Icons.shield_outlined,
                        obscure: true, type: TextInputType.number),
                  ],
                ),
              ),
            ],
          ),
        ];
    }
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          color: FitColors.label,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.4,
        ),
      );

  Widget _field(
    String hint,
    IconData icon, {
    bool obscure = false,
    TextInputType type = TextInputType.text,
  }) =>
      Container(
        decoration: BoxDecoration(
          color: FitColors.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: TextField(
          obscureText: obscure,
          keyboardType: type,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: FitColors.hint,
              fontSize: obscure ? 18 : 14,
              letterSpacing: obscure ? 3 : 0,
            ),
            prefixIcon: Icon(icon, color: FitColors.hint, size: 18),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      );
}
