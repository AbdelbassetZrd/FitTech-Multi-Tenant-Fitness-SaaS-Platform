import 'package:flutter/material.dart';
import '../../../../core/network/coach_api_client.dart';
import '../../../../core/network/api_paths.dart';
import '../../../../core/theme/app_colors.dart';

class PasswordResetConfirmScreen extends StatefulWidget {
  const PasswordResetConfirmScreen({this.email});

  final String? email;

  @override
  State<PasswordResetConfirmScreen> createState() =>
      _PasswordResetConfirmScreenState();
}

class _PasswordResetConfirmScreenState
    extends State<PasswordResetConfirmScreen> {
  final _tokenController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _api = CoachApiClient();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _tokenController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_tokenController.text.trim().isEmpty) {
      _show('Reset token is required.');
      return;
    }
    if (_passwordController.text.length < 8) {
      _show('New password must be at least 8 characters.');
      return;
    }
    if (_passwordController.text != _confirmController.text) {
      _show('Passwords do not match.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final response = await _api.post(
        ApiPaths.resetPasswordConfirm,
        body: {
          'token': _tokenController.text.trim(),
          'new_password': _passwordController.text,
        },
      );
      if (!mounted) return;
      _show(response['message']?.toString() ?? 'Password reset successfully.');
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      _show(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _show(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Reset')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            const Text(
              'Set a new password',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
            ),
            if (widget.email != null) ...[
              const SizedBox(height: 6),
              Text(
                'Requested for ${widget.email}',
                style: const TextStyle(color: AppColors.muted),
              ),
            ],
            const SizedBox(height: 24),
            TextField(
              controller: _tokenController,
              decoration: const InputDecoration(
                labelText: 'Reset token',
                prefixIcon: Icon(Icons.vpn_key_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm password',
                prefixIcon: Icon(Icons.lock_reset_outlined),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('RESET PASSWORD'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
