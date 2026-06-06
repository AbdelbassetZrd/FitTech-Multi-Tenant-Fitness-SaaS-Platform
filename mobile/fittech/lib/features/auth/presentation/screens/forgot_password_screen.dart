import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/fittech_theme.dart';
import '../bloc/verify_email_bloc.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return;
    context.read<VerifyEmailBloc>().add(
          VerifyEmailResendRequested(email: email),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<VerifyEmailBloc, VerifyEmailState>(
      listener: (context, state) {
        if (state is VerifyEmailResendSuccess) {
          Navigator.pushNamed(
            context,
            '/confirm-email',
            arguments: {'email': _emailCtrl.text.trim()},
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
        final isLoading = state is VerifyEmailResending;
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
                        color: FitColors.green.withOpacity(0.12),
                        border: Border.all(
                          color: FitColors.green.withOpacity(0.5),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: FitColors.green.withOpacity(0.2),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.lock_reset_rounded,
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
                            text: 'FORGOT\n',
                            style: TextStyle(color: Colors.white),
                          ),
                          TextSpan(
                            text: 'PASSWORD?',
                            style: TextStyle(color: FitColors.green),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    const Text(
                      "No worries! Enter your email and we'll send you a reset link.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: FitColors.label,
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),

                    const SizedBox(height: 40),

                    const FitLabel('EMAIL ADDRESS'),
                    const SizedBox(height: 8),
                    FitInputField(
                      controller: _emailCtrl,
                      hint: 'name@example.com',
                      prefixIcon: Icons.mail_outline,
                      keyboardType: TextInputType.emailAddress,
                      enabled: !isLoading,
                    ),

                    const SizedBox(height: 28),

                    FitPrimaryButton(
                      label: 'SEND RESET LINK',
                      isLoading: isLoading,
                      onPressed: () => _submit(context),
                    ),

                    const SizedBox(height: 32),

                    Row(
                      children: [
                        const Expanded(
                          child: Divider(color: FitColors.hint, thickness: 0.5),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'or',
                            style:
                                TextStyle(color: FitColors.hint, fontSize: 13),
                          ),
                        ),
                        const Expanded(
                          child: Divider(color: FitColors.hint, thickness: 0.5),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    GestureDetector(
                      onTap: () => Navigator.popUntil(
                        context,
                        ModalRoute.withName('/login'),
                      ),
                      child: Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: FitColors.hint.withOpacity(0.4),
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Text(
                            'BACK TO LOGIN',
                            style: TextStyle(
                              color: FitColors.label,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),
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
