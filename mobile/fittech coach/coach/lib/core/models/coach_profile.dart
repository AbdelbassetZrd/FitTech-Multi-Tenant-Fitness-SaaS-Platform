class CoachProfile {
  const CoachProfile({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.photoUrl,
    required this.speciality,
    required this.bio,
    required this.yearsOfExperience,
    required this.isActive,
    required this.isAvailable,
  });

  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String phone;
  final String? photoUrl;
  final String speciality;
  final String bio;
  final int yearsOfExperience;
  final bool isActive;
  final bool isAvailable;

  factory CoachProfile.fromJson(Map<String, dynamic> json) {
    return CoachProfile(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      photoUrl: json['photo']?.toString(),
      speciality: json['specialities']?.toString() ?? 'other',
      bio: json['bio']?.toString() ?? '',
      yearsOfExperience: (json['years_of_experience'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] == true,
      isAvailable: json['is_available'] != false,
    );
  }

  String get fullName => '$firstName $lastName'.trim();

  String get initials {
    final chars = <String>[];
    if (firstName.isNotEmpty) chars.add(firstName[0]);
    if (lastName.isNotEmpty) chars.add(lastName[0]);
    return chars.join().toUpperCase();
  }

  String get specialityLabel {
    switch (speciality) {
      case 'crossfit':
        return 'CrossFit Coach';
      case 'cardio':
        return 'Cardio Specialist';
      case 'strength':
        return 'Strength Coach';
      case 'yoga':
        return 'Yoga Coach';
      default:
        return speciality.replaceAll('_', ' ').toUpperCase();
    }
  }
}
