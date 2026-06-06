import 'package:flutter/material.dart';
import '../../../../core/network/coach_api_client.dart';
import '../../../../core/network/api_paths.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/panel.dart';
import '../../../../core/models/coach_profile.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen();

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _api = CoachApiClient();
  final _profileFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bioController = TextEditingController();
  final _experienceController = TextEditingController();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();

  bool _isAvailable = true;
  bool _isLoading = true;
  bool _savingProfile = false;
  bool _savingPassword = false;
  CoachProfile? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    _experienceController.dispose();
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final response = await _api.get(ApiPaths.profile, requiresAuth: true);
      final profile = CoachProfile.fromJson(response);
      _firstNameController.text = profile.firstName;
      _lastNameController.text = profile.lastName;
      _phoneController.text = profile.phone;
      _bioController.text = profile.bio;
      _experienceController.text = profile.yearsOfExperience.toString();
      _isAvailable = profile.isAvailable;
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_profileFormKey.currentState!.validate()) return;
    setState(() => _savingProfile = true);
    try {
      final response = await _api.patch(
        ApiPaths.profileUpdate,
        requiresAuth: true,
        body: {
          'first_name': _firstNameController.text.trim(),
          'last_name': _lastNameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'bio': _bioController.text.trim(),
          'years_of_experience':
              int.tryParse(_experienceController.text.trim()) ?? 0,
          'is_available': _isAvailable,
        },
      );
      if (!mounted) return;
      setState(() => _profile = CoachProfile.fromJson(response));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _changePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;
    setState(() => _savingPassword = true);
    try {
      final response = await _api.post(
        ApiPaths.passwordChange,
        requiresAuth: true,
        body: {
          'old_password': _oldPasswordController.text,
          'new_password': _newPasswordController.text,
        },
      );
      _oldPasswordController.clear();
      _newPasswordController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response['message']?.toString() ?? 'Password changed.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Coach Profile')),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.green),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_profile != null) _buildHeroCard(_profile!),
                const SizedBox(height: 16),
                Form(
                  key: _profileFormKey,
                  child: Panel(
                    title: 'Profile Details',
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _firstNameController,
                                decoration: const InputDecoration(
                                  labelText: 'First name',
                                ),
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                    ? 'Required'
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _lastNameController,
                                decoration: const InputDecoration(
                                  labelText: 'Last name',
                                ),
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                    ? 'Required'
                                    : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          enabled: false,
                          initialValue: _profile?.email ?? '',
                          decoration: const InputDecoration(labelText: 'Email'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _phoneController,
                          decoration: const InputDecoration(labelText: 'Phone'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _experienceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Years of experience',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _bioController,
                          maxLines: 4,
                          decoration: const InputDecoration(labelText: 'Bio'),
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          activeThumbColor: AppColors.green,
                          value: _isAvailable,
                          onChanged: (value) =>
                              setState(() => _isAvailable = value),
                          title: const Text('Available for sessions'),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _savingProfile ? null : _saveProfile,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.green,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: _savingProfile
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('SAVE PROFILE'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Form(
                  key: _passwordFormKey,
                  child: Panel(
                    title: 'Change Password',
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _oldPasswordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Old password',
                          ),
                          validator: (value) => value == null || value.isEmpty
                              ? 'Required'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _newPasswordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'New password',
                          ),
                          validator: (value) =>
                              value == null || value.length < 8
                              ? 'Minimum 8 characters'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _savingPassword ? null : _changePassword,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: AppColors.green),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: _savingPassword
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('UPDATE PASSWORD'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeroCard(CoachProfile profile) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF111B2F), Color(0xFF16243C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: AppColors.green.withValues(alpha: 0.15),
            child: Text(
              profile.initials,
              style: const TextStyle(
                color: AppColors.green,
                fontWeight: FontWeight.w900,
                fontSize: 24,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            profile.fullName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            profile.specialityLabel,
            style: const TextStyle(
              color: AppColors.green,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
