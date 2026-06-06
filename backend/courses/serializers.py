from rest_framework import serializers
from .models import Course, Session, Booking, AttendanceRecord, AbsenceWarning, Salle


# ── Salle ─────────────────────────────────────────────────────────────────────

class SalleSerializer(serializers.ModelSerializer):
    class Meta:
        model = Salle
        fields = ['id', 'name', 'capacity']


class SalleCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Salle
        fields = ['id', 'name', 'capacity']


# ── Booking ───────────────────────────────────────────────────────────────────

class BookingSerializer(serializers.ModelSerializer):
    member_name = serializers.SerializerMethodField()
    member_email = serializers.SerializerMethodField()

    class Meta:
        model = Booking
        fields = ['id', 'session', 'member', 'member_name', 'member_email', 'status', 'created_at']
        read_only_fields = ['status', 'created_at']

    def get_member_name(self, obj):
        return obj.member.get_full_name()

    def get_member_email(self, obj):
        return obj.member.email


# ── Session ───────────────────────────────────────────────────────────────────

class SessionSerializer(serializers.ModelSerializer):
    course_name = serializers.ReadOnlyField(source='course.name')
    coach_name = serializers.SerializerMethodField()
    confirmed_count = serializers.ReadOnlyField()
    waiting_count = serializers.ReadOnlyField()
    is_full = serializers.ReadOnlyField()
    max_members = serializers.ReadOnlyField(source='course.max_members')
    salle = serializers.SerializerMethodField()

    class Meta:
        model = Session
        fields = [
            'id', 'course', 'course_name', 'coach_name',
            'date', 'is_cancelled', 'notes',
            'confirmed_count', 'waiting_count', 'is_full', 'max_members', 'salle', 'duration_time'
        ]

    def get_coach_name(self, obj):
        return obj.course.coach.get_full_name()

    def get_salle(self, obj):
        return obj.salle_fk.name if obj.salle_fk else None


class SessionDetailSerializer(SessionSerializer):
    """Admin view — includes the full bookings list."""
    bookings = BookingSerializer(many=True, read_only=True)

    class Meta(SessionSerializer.Meta):
        fields = SessionSerializer.Meta.fields + ['bookings']


class SessionCreateSerializer(serializers.ModelSerializer):
    """Used by admin to create a session."""
    class Meta:
        model = Session
        fields = ['id', 'course', 'salle_fk', 'date', 'duration_time', 'notes']

    def validate(self, data):
        course = data['course']
        date = data['date']
        duration = data.get('duration_time', 60)
        
        room = data.get('salle_fk')
        if not room:
            return data
            
        from datetime import datetime, timedelta
        start_dt = datetime.combine(date, course.time)
        end_dt = start_dt + timedelta(minutes=duration)
        
        overlapping = Session.objects.filter(
            salle_fk=room,
            date=date,
            is_cancelled=False
        )
        for other_sess in overlapping:
            o_start = datetime.combine(date, other_sess.course.time)
            o_end = o_start + timedelta(minutes=other_sess.duration_time)
            
            if max(start_dt, o_start) < min(end_dt, o_end):
                raise serializers.ValidationError({
                    "date": f"Room {room.name} is booked from {o_start.time()} to {o_end.time()}"
                })
        return data


# ── Course ────────────────────────────────────────────────────────────────────

class CourseSerializer(serializers.ModelSerializer):
    coach_name = serializers.SerializerMethodField()
    created_by_name = serializers.SerializerMethodField()
    sessions_count = serializers.SerializerMethodField()
    salle_name = serializers.SerializerMethodField()

    class Meta:
        model = Course
        fields = [
            'id', 'name',
            'coach', 'coach_name',
            'time', 'day', 'salle', 'salle_name',
            'max_members',
            'number_of_sessions', 'sessions_count',
            'session_price',
            'created_by', 'created_by_name',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['created_by', 'created_at', 'updated_at']

    def get_coach_name(self, obj):
        return obj.coach.get_full_name()

    def get_created_by_name(self, obj):
        if obj.created_by:
            return obj.created_by.get_full_name()
        return None

    def get_sessions_count(self, obj):
        return obj.sessions.count()

    def get_salle_name(self, obj):
        return obj.salle.name if obj.salle else None


class CourseCreateSerializer(serializers.ModelSerializer):
    """Used by admin to create / update a course."""
    salle = serializers.PrimaryKeyRelatedField(queryset=Salle.objects.all(), required=True)
    class Meta:
        model = Course
        fields = ['id', 'name', 'coach', 'time', 'day', 'salle', 'max_members', 'number_of_sessions', 'session_price']

    def create(self, validated_data):
        # Inject the requesting admin as created_by
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            validated_data['created_by'] = request.user
        
        # Extract number_of_sessions before creating the course
        number_of_sessions = validated_data.pop('number_of_sessions', 1)
        
        # Create the course
        course = super().create(validated_data)
        
        # Create sessions for the course
        from datetime import datetime, timedelta
        today = datetime.now().date()
        session_date = today
        
        # Find the next occurrence of course.day starting from today
        from datetime import datetime
        weekday_map = {'MON': 0, 'TUE': 1, 'WED': 2, 'THU': 3, 'FRI': 4, 'SAT': 5, 'SUN': 6}
        target_weekday = weekday_map.get(course.day, 0)
        
        while session_date.weekday() != target_weekday:
            session_date += timedelta(days=1)
        
        # Create n sessions starting from that date
        for i in range(number_of_sessions):
            Session.objects.create(
                course=course,
                date=session_date + timedelta(weeks=i),
                salle_fk=course.salle
            )
        
        return course

    def validate(self, data):
        # Ensure the selected salle is not already assigned to another course at same day/time
        salle = data.get('salle')
        day = data.get('day')
        time = data.get('time')
        if salle and day and time:
            conflict = Course.objects.filter(salle=salle, day=day, time=time).exists()
            if conflict:
                raise serializers.ValidationError({
                    'salle': f"Room '{salle.name}' is already assigned to another course at {day} {time}."
                })
        return data


# ── Attendance & Warnings ─────────────────────────────────────────────────────

class AttendanceRecordSerializer(serializers.ModelSerializer):
    member_name = serializers.ReadOnlyField(source='member.get_full_name')

    class Meta:
        model = AttendanceRecord
        fields = ['id', 'session', 'member', 'member_name', 'is_present', 'marked_by', 'marked_at']
        read_only_fields = ['marked_by', 'marked_at']


class AbsenceWarningSerializer(serializers.ModelSerializer):
    session_date = serializers.ReadOnlyField(source='session.date')
    course_name = serializers.ReadOnlyField(source='session.course.name')

    class Meta:
        model = AbsenceWarning
        fields = ['id', 'member', 'session', 'session_date', 'course_name', 'issued_at', 'notified']