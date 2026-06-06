import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/fittech_theme.dart';
import '../bloc/register_bloc.dart';

const String baseUrl = 'http://127.0.0.1:8000';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _password2Ctrl = TextEditingController();

  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _agreed = false;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _password2Ctrl.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    if (!_agreed) {
      _snack(context, 'Please accept the Terms of Service.', Colors.orange);
      return;
    }
    if (_passwordCtrl.text != _password2Ctrl.text) {
      _snack(context, 'Passwords do not match.', Colors.redAccent);
      return;
    }
    final firstName = _firstNameCtrl.text.trim();
    final lastName = _lastNameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final password2 = _password2Ctrl.text;

    if (firstName.isEmpty ||
        lastName.isEmpty ||
        email.isEmpty ||
        phone.isEmpty ||
        password.isEmpty) {
      _snack(context, 'Please fill in all fields.', Colors.orange);
      return;
    }

    context.read<RegisterBloc>().add(
          RegisterSubmitted(
            email: email,
            password: password,
            password2: password2,
            firstName: firstName,
            lastName: lastName,
            phone: phone,
          ),
        );
  }

  void _snack(BuildContext context, String msg, Color color) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: color),
      );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RegisterBloc, RegisterState>(
      listener: (context, state) {
        if (state is RegisterSuccess) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/confirm-email',
            (r) => false,
            arguments: {'email': _emailCtrl.text.trim()},
          );
        }
        if (state is RegisterFailure) {
          _snack(context, state.message, Colors.redAccent);
        }
      },
      builder: (context, state) {
        final isLoading = state is RegisterLoading;
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
                    const SizedBox(height: 28),
                    const FitLogo(size: 72),
                    const SizedBox(height: 16),
                    const FitBadge(),
                    const SizedBox(height: 16),

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
                            text: 'CREATE\n',
                            style: TextStyle(color: Colors.white),
                          ),
                          TextSpan(
                            text: 'ACCOUNT',
                            style: TextStyle(color: FitColors.green),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),
                    const Text(
                      'Start your premium fitness journey today.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: FitColors.label, fontSize: 14, height: 1.5),
                    ),
                    const SizedBox(height: 24),

                    // ── First + Last name ─────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const FitLabel('FIRST NAME'),
                              const SizedBox(height: 8),
                              FitInputField(
                                controller: _firstNameCtrl,
                                hint: 'John',
                                prefixIcon: Icons.person_outline,
                                keyboardType: TextInputType.name,
                                enabled: !isLoading,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const FitLabel('LAST NAME'),
                              const SizedBox(height: 8),
                              FitInputField(
                                controller: _lastNameCtrl,
                                hint: 'Doe',
                                prefixIcon: Icons.person_outline,
                                keyboardType: TextInputType.name,
                                enabled: !isLoading,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    const FitLabel('PHONE NUMBER'),
                    const SizedBox(height: 8),
                    FitInputField(
                      controller: _phoneCtrl,
                      hint: '+213 5XX XXX XXX',
                      prefixIcon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      enabled: !isLoading,
                    ),

                    const SizedBox(height: 16),
                    const FitLabel('EMAIL ADDRESS'),
                    const SizedBox(height: 8),
                    FitInputField(
                      controller: _emailCtrl,
                      hint: 'name@example.com',
                      prefixIcon: Icons.mail_outline,
                      keyboardType: TextInputType.emailAddress,
                      enabled: !isLoading,
                    ),

                    const SizedBox(height: 16),
                    const FitLabel('PASSWORD'),
                    const SizedBox(height: 8),
                    FitInputField(
                      controller: _passwordCtrl,
                      hint: '••••••••',
                      prefixIcon: Icons.lock_outline,
                      obscure: _obscure1,
                      enabled: !isLoading,
                      suffixIcon: GestureDetector(
                        onTap: () => setState(() => _obscure1 = !_obscure1),
                        child: Icon(
                          _obscure1
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: FitColors.hint,
                          size: 20,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    const FitLabel('CONFIRM PASSWORD'),
                    const SizedBox(height: 8),
                    FitInputField(
                      controller: _password2Ctrl,
                      hint: '••••••••',
                      prefixIcon: Icons.lock_outline,
                      obscure: _obscure2,
                      enabled: !isLoading,
                      suffixIcon: GestureDetector(
                        onTap: () => setState(() => _obscure2 = !_obscure2),
                        child: Icon(
                          _obscure2
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: FitColors.hint,
                          size: 20,
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ── Terms checkbox ────────────────────────────────────
                    GestureDetector(
                      onTap: isLoading
                          ? null
                          : () => setState(() => _agreed = !_agreed),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: _agreed
                                  ? FitColors.green
                                  : Colors.transparent,
                              border: Border.all(
                                color:
                                    _agreed ? FitColors.green : FitColors.hint,
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: _agreed
                                ? const Icon(Icons.check,
                                    color: Colors.white, size: 13)
                                : null,
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text.rich(
                              TextSpan(
                                style: TextStyle(
                                    color: FitColors.muted, fontSize: 12),
                                children: [
                                  TextSpan(text: 'I agree to the '),
                                  TextSpan(
                                    text: 'Terms of Service',
                                    style: TextStyle(
                                      color: FitColors.green,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  TextSpan(text: ' and '),
                                  TextSpan(
                                    text: 'Privacy Policy',
                                    style: TextStyle(
                                      color: FitColors.green,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    FitPrimaryButton(
                      label: 'CREATE ACCOUNT',
                      isLoading: isLoading,
                      onPressed: () => _submit(context),
                    ),

                    const SizedBox(height: 24),

                    GestureDetector(
                      onTap: isLoading ? null : () => Navigator.pop(context),
                      child: RichText(
                        text: const TextSpan(
                          style:
                              TextStyle(fontSize: 14, color: FitColors.muted),
                          children: [
                            TextSpan(text: 'Already have an account?  '),
                            TextSpan(
                              text: 'Log In',
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
