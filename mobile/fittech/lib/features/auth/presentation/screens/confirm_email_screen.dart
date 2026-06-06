import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/fittech_theme.dart';
import '../bloc/verify_email_bloc.dart';

class ConfirmEmailScreen extends StatefulWidget {
  const ConfirmEmailScreen({super.key});

  @override
  State<ConfirmEmailScreen> createState() => _ConfirmEmailScreenState();
}

class _ConfirmEmailScreenState extends State<ConfirmEmailScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _otpRequested = false;

  // The email passed from login/register/forgot-password
  String _email = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      _email = (args['email'] as String?) ?? '';
    }
    if (!_otpRequested && _email.isNotEmpty) {
      _otpRequested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context
            .read<VerifyEmailBloc>()
            .add(VerifyEmailResendRequested(email: _email));
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _otp => _controllers.map((c) => c.text).join();

  bool get _allFilled => _otp.length == 6;

  void _onChanged(String value, int index) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    setState(() {});
  }

  void _onBackspace(int index) {
    if (_controllers[index].text.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  void _submit(BuildContext context) {
    if (!_allFilled) return;
    context.read<VerifyEmailBloc>().add(
          VerifyEmailSubmitted(email: _email, code: _otp),
        );
  }

  void _resend(BuildContext context) {
    if (_email.isEmpty) return;
    context
        .read<VerifyEmailBloc>()
        .add(VerifyEmailResendRequested(email: _email));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<VerifyEmailBloc, VerifyEmailState>(
      listener: (context, state) {
        if (state is VerifyEmailSuccess) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text('Email verified successfully. Please log in.'),
                backgroundColor: Colors.green,
              ),
            );
          Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
        }
        if (state is VerifyEmailResendSuccess) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text('OTP sent to your email.'),
                backgroundColor: Colors.green,
              ),
            );
        }
        if (state is VerifyEmailFailureState) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.redAccent,
              ),
            );
        }
      },
      builder: (context, state) {
        final isLoading = state is VerifyEmailLoading;
        final isResending = state is VerifyEmailResending;
        final timerSecs = state is VerifyEmailTimerRunning ? state.seconds : 0;
        final canResend = timerSecs == 0 && !isLoading && !isResending;

        return Scaffold(
          body: FitBackground(
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 24),
                    const FitBackButton(),
                    const SizedBox(height: 48),

                    // ── Icon ──────────────────────────────────────────────
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: FitColors.green.withValues(alpha: 0.12),
                        border: Border.all(
                          color: FitColors.green.withValues(alpha: 0.5),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: FitColors.green.withValues(alpha: 0.25),
                            blurRadius: 28,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.mark_email_unread_outlined,
                          color: FitColors.green,
                          size: 42,
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    RichText(
                      textAlign: TextAlign.center,
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                        children: [
                          TextSpan(
                            text: 'CHECK YOUR\n',
                            style: TextStyle(color: Colors.white),
                          ),
                          TextSpan(
                            text: 'EMAIL',
                            style: TextStyle(color: FitColors.green),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: const TextStyle(
                          color: FitColors.label,
                          fontSize: 14,
                          height: 1.6,
                        ),
                        children: [
                          const TextSpan(text: 'We sent a 6-digit OTP to\n'),
                          TextSpan(
                            text: _email.isEmpty ? 'your email' : _email,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),
                    const FitLabel('VERIFICATION CODE'),
                    const SizedBox(height: 16),

                    // ── OTP boxes ─────────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(6, (i) {
                        return SizedBox(
                          width: 46,
                          height: 56,
                          child: KeyboardListener(
                            focusNode: FocusNode(skipTraversal: true),
                            onKeyEvent: (event) {
                              if (event is KeyDownEvent &&
                                  event.logicalKey ==
                                      LogicalKeyboardKey.backspace) {
                                _onBackspace(i);
                              }
                            },
                            child: TextField(
                              controller: _controllers[i],
                              focusNode: _focusNodes[i],
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              maxLength: 1,
                              enabled: !isLoading,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                              onChanged: (v) => _onChanged(v, i),
                              decoration: InputDecoration(
                                counterText: '',
                                filled: true,
                                fillColor: FitColors.surface,
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color:
                                        FitColors.hint.withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: FitColors.green,
                                    width: 2,
                                  ),
                                ),
                                disabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color:
                                        FitColors.hint.withValues(alpha: 0.15),
                                    width: 1,
                                  ),
                                ),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 16),

                    // ── Timer / Resend ────────────────────────────────────
                    if (isResending)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: FitColors.green,
                          strokeWidth: 2,
                        ),
                      )
                    else if (timerSecs > 0)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.timer_outlined,
                              color: FitColors.hint, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Resend code in '
                            '${(timerSecs ~/ 60).toString().padLeft(2, '0')}:'
                            '${(timerSecs % 60).toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              color: FitColors.muted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      )
                    else
                      GestureDetector(
                        onTap: canResend ? () => _resend(context) : null,
                        child: Text.rich(
                          TextSpan(
                            style: const TextStyle(
                                fontSize: 14, color: FitColors.muted),
                            children: [
                              const TextSpan(
                                  text: "Didn't receive the code?  "),
                              TextSpan(
                                text: 'Resend',
                                style: TextStyle(
                                  color: canResend
                                      ? FitColors.green
                                      : FitColors.hint,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 36),

                    // ── Verify Button ─────────────────────────────────────
                    AnimatedOpacity(
                      opacity: _allFilled ? 1.0 : 0.45,
                      duration: const Duration(milliseconds: 200),
                      child: FitPrimaryButton(
                        label: 'VERIFY EMAIL',
                        isLoading: isLoading,
                        onPressed: _allFilled ? () => _submit(context) : null,
                      ),
                    ),

                    const SizedBox(height: 20),

                    GestureDetector(
                      onTap: () => Navigator.popUntil(
                        context,
                        ModalRoute.withName('/login'),
                      ),
                      child: const Text(
                        'Use a different email',
                        style: TextStyle(
                          color: FitColors.hint,
                          fontSize: 13,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),

                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
