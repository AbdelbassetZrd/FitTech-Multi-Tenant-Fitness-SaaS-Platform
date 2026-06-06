import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/fittech_theme.dart';
import '../bloc/login_bloc.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) return;
    context.read<LoginBloc>().add(
          LoginSubmitted(email: email, password: password),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LoginBloc, LoginState>(
      listener: (context, state) {
        if (state is LoginSuccess) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/home',
            (r) => false,
          );
        }
        if (state is LoginFailure) {
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
        final isLoading = state is LoginLoading;
        return Scaffold(
          body: FitBackground(
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 48),
                    const FitLogo(),
                    const SizedBox(height: 20),
                    const FitBadge(),
                    const SizedBox(height: 18),

                    // ── Headline ─────────────────────────────────────────
                    RichText(
                      textAlign: TextAlign.center,
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                        children: [
                          TextSpan(
                            text: 'JOIN THE ',
                            style: TextStyle(color: Colors.white),
                          ),
                          TextSpan(
                            text: 'GRIND',
                            style: TextStyle(color: FitColors.green),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    const Text(
                      'Master your fitness journey with FitTech.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: FitColors.label,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── Email ────────────────────────────────────────────
                    const FitLabel('EMAIL ADDRESS'),
                    const SizedBox(height: 8),
                    FitInputField(
                      controller: _emailCtrl,
                      hint: 'name@example.com',
                      prefixIcon: Icons.mail_outline,
                      keyboardType: TextInputType.emailAddress,
                      enabled: !isLoading,
                    ),

                    const SizedBox(height: 20),

                    // ── Password ─────────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const FitLabel('PASSWORD'),
                        GestureDetector(
                          onTap: isLoading
                              ? null
                              : () => Navigator.pushNamed(
                                    context,
                                    '/forgot-password',
                                  ),
                          child: const Text(
                            'Forgot?',
                            style: TextStyle(
                              color: FitColors.green,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    FitInputField(
                      controller: _passwordCtrl,
                      hint: '••••••••',
                      prefixIcon: Icons.lock_outline,
                      obscure: _obscure,
                      enabled: !isLoading,
                      suffixIcon: GestureDetector(
                        onTap: () => setState(() => _obscure = !_obscure),
                        child: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: FitColors.hint,
                          size: 20,
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Log In ───────────────────────────────────────────
                    FitPrimaryButton(
                      label: 'LOG IN',
                      isLoading: isLoading,
                      onPressed: () => _submit(context),
                    ),

                    const SizedBox(height: 12),

                    // ── Google ───────────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black87,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GoogleLogo(),
                            SizedBox(width: 10),
                            Text(
                              'Continue with Google',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Register link ─────────────────────────────────────
                    GestureDetector(
                      onTap: isLoading
                          ? null
                          : () => Navigator.pushNamed(context, '/register'),
                      child: RichText(
                        text: const TextSpan(
                          style:
                              TextStyle(fontSize: 14, color: FitColors.muted),
                          children: [
                            TextSpan(text: "Don't have an account?  "),
                            TextSpan(
                              text: 'Create Account',
                              style: TextStyle(
                                color: FitColors.green,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),
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
