class CoachSession {
  const CoachSession({
    required this.id,
    required this.courseId,
    required this.courseName,
    required this.coachName,
    required this.date,
    required this.time,
    required this.day,
    required this.isCancelled,
    required this.notes,
    required this.confirmedCount,
    required this.waitingCount,
    required this.isFull,
    required this.maxMembers,
    required this.salle,
    required this.durationTime,
    required this.attendanceMarked,
    required this.bookings,
  });

  final int id;
  final int courseId;
  final String courseName;
  final String coachName;
  final DateTime date;
  final String time;
  final String day;
  final bool isCancelled;
  final String notes;
  final int confirmedCount;
  final int waitingCount;
  final bool isFull;
  final int maxMembers;
  final String salle;
  final int durationTime;
  final bool attendanceMarked;
  final List<CoachBooking> bookings;

  factory CoachSession.fromJson(Map<String, dynamic> json) {
    final bookings = (json['bookings'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => CoachBooking.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    return CoachSession(
      id: (json['id'] as num?)?.toInt() ?? 0,
      courseId: (json['course_id'] as num?)?.toInt() ?? 0,
      courseName: json['course_name']?.toString() ?? '',
      coachName: json['coach_name']?.toString() ?? '',
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      time: json['time']?.toString() ?? '00:00:00',
      day: json['day']?.toString() ?? '',
      isCancelled: json['is_cancelled'] == true,
      notes: json['notes']?.toString() ?? '',
      confirmedCount: (json['confirmed_count'] as num?)?.toInt() ?? 0,
      waitingCount: (json['waiting_count'] as num?)?.toInt() ?? 0,
      isFull: json['is_full'] == true,
      maxMembers: (json['max_members'] as num?)?.toInt() ?? 0,
      salle: json['salle']?.toString() ?? 'Gym Room',
      durationTime: (json['duration_time'] as num?)?.toInt() ?? 60,
      attendanceMarked: json['attendance_marked'] == true,
      bookings: bookings,
    );
  }

  List<CoachBooking> get confirmedBookings =>
      bookings.where((booking) => booking.status == 'confirmed').toList();

  List<CoachBooking> get waitingBookings =>
      bookings.where((booking) => booking.status == 'waiting').toList();

  String get statusLabel {
    if (attendanceMarked) return 'VALIDATED';
    if (isSameDay(date, DateTime.now())) return 'HAPPENING NOW';
    return 'UPCOMING';
  }
}

class CoachBooking {
  const CoachBooking({
    required this.id,
    required this.sessionId,
    required this.memberId,
    required this.memberName,
    required this.memberEmail,
    required this.status,
  });

  final int id;
  final int sessionId;
  final String memberId;
  final String memberName;
  final String memberEmail;
  final String status;

  factory CoachBooking.fromJson(Map<String, dynamic> json) {
    return CoachBooking(
      id: (json['id'] as num?)?.toInt() ?? 0,
      sessionId: (json['session'] as num?)?.toInt() ?? 0,
      memberId: json['member']?.toString() ?? '',
      memberName: json['member_name']?.toString() ?? 'Member',
      memberEmail: json['member_email']?.toString() ?? '',
      status: json['status']?.toString() ?? 'waiting',
    );
  }
}

class CoachSessionStat {
  const CoachSessionStat({
    required this.sessionId,
    required this.courseName,
    required this.date,
    required this.attendanceRatePercent,
  });

  final int sessionId;
  final String courseName;
  final DateTime date;
  final int attendanceRatePercent;

  factory CoachSessionStat.fromJson(Map<String, dynamic> json) {
    return CoachSessionStat(
      sessionId: (json['session_id'] as num?)?.toInt() ?? 0,
      courseName: json['course_name']?.toString() ?? '',
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      attendanceRatePercent:
          (json['attendance_rate_percent'] as num?)?.toInt() ?? 0,
    );
  }
}

class CoachEarnings {
  const CoachEarnings({required this.month, required this.totalEarnings});

  final String month;
  final double totalEarnings;

  factory CoachEarnings.fromJson(Map<String, dynamic> json) {
    return CoachEarnings(
      month: json['month']?.toString() ?? '',
      totalEarnings: (json['total_earnings'] as num?)?.toDouble() ?? 0,
    );
  }
}

class AbsenceWarning {
  const AbsenceWarning({required this.courseName, required this.sessionDate});

  final String courseName;
  final String sessionDate;

  factory AbsenceWarning.fromJson(Map<String, dynamic> json) {
    return AbsenceWarning(
      courseName: json['course_name']?.toString() ?? '',
      sessionDate: json['session_date']?.toString() ?? '',
    );
  }
}

bool isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
