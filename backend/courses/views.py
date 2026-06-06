from django.utils import timezone

from rest_framework import generics, status, serializers
from rest_framework.permissions import IsAdminUser, AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.exceptions import AuthenticationFailed

from drf_spectacular.utils import (
    extend_schema, extend_schema_view,
    OpenApiParameter, OpenApiExample, OpenApiResponse,
    inline_serializer,
)
from drf_spectacular.types import OpenApiTypes
from rest_framework_simplejwt.tokens import AccessToken
from rest_framework_simplejwt.exceptions import TokenError

from users.permissions import IsNotSuspended
from .models import Course, Session, Booking, AttendanceRecord, AbsenceWarning, Salle, CoursePayment
from subscriptions.chargily_service import ChargilyService
from .serializers import (
    CourseSerializer,
    CourseCreateSerializer,
    SessionSerializer,
    SessionDetailSerializer,
    SessionCreateSerializer,
    BookingSerializer,
    AttendanceRecordSerializer,
    AbsenceWarningSerializer,
    SalleSerializer,
    SalleCreateSerializer,
)


@extend_schema(tags=["Coach — Courses"])
class CoachCourseListView(APIView):
    """**Coach only.** List courses that belong to the authenticated coach."""
    permission_classes = [AllowAny]
    authentication_classes = []

    def get(self, request):
        claims = _coach_claims(request)
        coach_id = claims.get('user_id')

        courses = Course.objects.filter(coach_id=coach_id).select_related('salle', 'coach').order_by('day', 'time')
        data = []
        for course in courses:
            sessions = _upcoming_course_sessions(course)
            session_summaries = []
            for s in sessions:
                session_summaries.append({
                    'id': s.id,
                    'date': s.date,
                    'time': course.time,
                    'salle': s.salle_fk.name if s.salle_fk else None,
                    'confirmed_count': s.confirmed_count,
                    'waiting_count': s.waiting_count,
                    'is_cancelled': s.is_cancelled,
                })

            data.append({
                'id': course.id,
                'name': course.name,
                'day': course.day,
                'time': course.time,
                'max_members': course.max_members,
                'number_of_sessions': course.number_of_sessions,
                'salle': course.salle.name if course.salle else None,
                'sessions': session_summaries,
            })

        return Response(data)


@extend_schema(tags=["Coach — Courses"])
class CoachCourseDetailView(APIView):
    """**Coach only.** Get full course details: sessions and bookings per session."""
    permission_classes = [AllowAny]
    authentication_classes = []

    def get(self, request, pk):
        claims = _coach_claims(request)
        coach_id = claims.get('user_id')

        try:
            course = Course.objects.select_related('coach', 'salle').get(pk=pk)
        except Course.DoesNotExist:
            return Response({'error': 'Course not found.'}, status=status.HTTP_404_NOT_FOUND)

        if str(course.coach.id) != str(coach_id):
            return Response({'error': 'Not your course.'}, status=status.HTTP_403_FORBIDDEN)

        sessions = course.sessions.select_related('salle_fk').prefetch_related('bookings__member').order_by('date')
        sessions_data = []
        for s in sessions:
            bookings = s.bookings.select_related('member').order_by('status', 'created_at')
            sessions_data.append({
                'id': s.id,
                'date': s.date,
                'time': course.time,
                'salle': s.salle_fk.name if s.salle_fk else None,
                'is_cancelled': s.is_cancelled,
                'confirmed_count': s.confirmed_count,
                'waiting_count': s.waiting_count,
                'bookings': BookingSerializer(bookings, many=True).data,
                'attendance_marked': s.attendance_records.exists(),
            })

        course_data = CourseSerializer(course).data
        course_data['sessions'] = sessions_data

        return Response(course_data)


# ─── Helpers ──────────────────────────────────────────────────────────────────

def _get_member(request):
    """Extract the Member object from a JWT-authenticated member request."""
    from users.models import Member
    member_id = _member_claims(request).get('user_id')
    if not member_id:
        return None
    try:
        return Member.objects.get(id=member_id)
    except Member.DoesNotExist:
        return None


def _authorization_token(request):
    auth_header = request.headers.get('Authorization', '')
    if not auth_header.startswith('Bearer '):
        raise AuthenticationFailed('Authentication credentials were not provided.')
    return auth_header.split(' ', 1)[1].strip()


def _token_claims(request):
    try:
        return AccessToken(_authorization_token(request))
    except TokenError as exc:
        raise AuthenticationFailed(str(exc))


def _member_claims(request):
    claims = _token_claims(request)
    if claims.get('role') != 'member':
        raise AuthenticationFailed('Not a member token.')
    return claims


def _coach_claims(request):
    claims = _token_claims(request)
    if claims.get('role') != 'coach':
        raise AuthenticationFailed('Not a coach token.')
    return claims


def _notify_member(member, title, message, notification_type='booking_confirmed'):
    """Create an in-app Notification + send an email to the member."""
    from notifications.models import Notification
    from django.core.mail import EmailMessage

    # 1. In-app notification
    Notification.objects.create(
        member=member,
        notification_type=notification_type,
        title=title,
        message=message,
    )

    # 2. Email (best-effort — fails silently)
    try:
        email = EmailMessage(
            subject=f"FitTech — {title}",
            body=message,
            to=[member.email],
        )
        email.send()
    except Exception as exc:
        print(f"[courses] Email notification failed: {exc}")


def _promote_next_waiting(session):
    """
    FIFO: promote the oldest 'waiting' booking to 'confirmed'.
    Triggers in-app + email notification.
    Returns the promoted Booking or None.
    """
    next_booking = (
        Booking.objects
        .select_related('member')
        .filter(session=session, status='waiting')
        .order_by('created_at')
        .first()
    )
    if not next_booking:
        return None

    next_booking.status = 'confirmed'
    next_booking.save(update_fields=['status'])

    session_label = f"{session.course.name} on {session.date}"
    _notify_member(
        member=next_booking.member,
        title="You've been confirmed for a session!",
        message=(
            f"Great news! A spot opened up and you have been confirmed for "
            f"'{session_label}'. "
            f"Room: {session.course.salle} | "
            f"Coach: {session.course.coach.get_full_name()}. "
            f"See you there!"
        ),
        notification_type='booking_confirmed',
    )
    return next_booking


def _upcoming_course_sessions(course):
    return list(
        course.sessions
        .select_related('salle_fk')
        .filter(is_cancelled=False, date__gte=timezone.now().date())
        .order_by('date')
    )


def _course_booking_summary(course, member):
    bookings = list(
        Booking.objects
        .select_related('session', 'session__salle_fk')
        .filter(member=member, session__course=course)
        .order_by('session__date')
    )
    if not bookings:
        return None

    confirmed_count = sum(1 for booking in bookings if booking.status == 'confirmed')
    waiting_count = sum(1 for booking in bookings if booking.status == 'waiting')
    next_session = bookings[0].session

    if confirmed_count == len(bookings):
        status_label = 'confirmed'
    elif waiting_count == len(bookings):
        status_label = 'waiting'
    else:
        status_label = 'mixed'

    return {
        'course_id': course.id,
        'course_name': course.name,
        'coach_name': course.coach.get_full_name(),
        'day': course.day,
        'time': course.time,
        'number_of_sessions': course.number_of_sessions,
        'booked_sessions_count': len(bookings),
        'confirmed_sessions_count': confirmed_count,
        'waiting_sessions_count': waiting_count,
        'status': status_label,
        'next_session_date': next_session.date,
        'salle': next_session.salle_fk.name if next_session.salle_fk else None,
        'duration_time': next_session.duration_time,
        'session_price': course.session_price,
        'total_price': course.session_price * len(bookings),
    }


# ═══════════════════════════════════════════════════════════════════════════════
#  ADMIN — SALLE MANAGEMENT
# ═══════════════════════════════════════════════════════════════════════════════

@extend_schema(tags=["Admin — Salles"])
class AdminSalleListView(generics.ListAPIView):
    """**Admin only.** List all Salles."""
    serializer_class = SalleSerializer
    permission_classes = [IsAdminUser]
    queryset = Salle.objects.all().order_by('name')


@extend_schema(tags=["Admin — Salles"])
class AdminSalleCreateView(APIView):
    """**Admin only.** Create a new Salle."""
    permission_classes = [IsAdminUser]

    @extend_schema(
        summary="Create a salle",
        request=SalleCreateSerializer,
        responses={201: SalleSerializer}
    )
    def post(self, request):
        serializer = SalleCreateSerializer(data=request.data)
        if serializer.is_valid():
            salle = serializer.save()
            return Response(SalleSerializer(salle).data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


@extend_schema(tags=["Admin — Salles"])
class AdminSalleDetailView(APIView):
    """**Admin only.** Retrieve, update, or delete a Salle."""
    permission_classes = [IsAdminUser]

    def _get_salle(self, pk):
        try:
            return Salle.objects.get(pk=pk)
        except Salle.DoesNotExist:
            return None

    @extend_schema(summary="Get salle details", responses={200: SalleSerializer})
    def get(self, request, pk):
        salle = self._get_salle(pk)
        if not salle:
            return Response({'error': 'Not found.'}, status=status.HTTP_404_NOT_FOUND)
        return Response(SalleSerializer(salle).data)

    @extend_schema(summary="Update salle", request=SalleCreateSerializer, responses={200: SalleSerializer})
    def patch(self, request, pk):
        salle = self._get_salle(pk)
        if not salle:
            return Response({'error': 'Not found.'}, status=status.HTTP_404_NOT_FOUND)
        serializer = SalleCreateSerializer(salle, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(SalleSerializer(salle).data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    @extend_schema(summary="Delete salle")
    def delete(self, request, pk):
        salle = self._get_salle(pk)
        if not salle:
            return Response({'error': 'Not found.'}, status=status.HTTP_404_NOT_FOUND)
        salle.delete()
        return Response({'message': 'Deleted successfully.'}, status=status.HTTP_200_OK)


# ═══════════════════════════════════════════════════════════════════════════════
#  ADMIN — COURSE MANAGEMENT
# ═══════════════════════════════════════════════════════════════════════════════

@extend_schema(tags=["Admin — Courses"])
class AdminCourseListView(generics.ListAPIView):
    """
    **Admin only.**
    List every course in the system.
    """
    serializer_class = CourseSerializer
    permission_classes = [IsAdminUser]
    queryset = Course.objects.select_related('coach', 'created_by').order_by('day', 'time')

    @extend_schema(
        summary="List all courses",
        description="Returns every course. Admin access only.",
        responses={200: CourseSerializer(many=True)},
    )
    def get(self, request, *args, **kwargs):
        return super().get(request, *args, **kwargs)


@extend_schema(tags=["Admin — Courses"])
class AdminCourseCreateView(APIView):
    """**Admin only.** Create a new course."""
    permission_classes = [IsAdminUser]

    @extend_schema(
        summary="Create a course",
        description=(
            "Admin creates a course. Fields: `name`, `coach` (id), `time`, `day` "
            "(MON/TUE/WED/THU/FRI/SAT/SUN), `max_members`, `salle`, `number_of_sessions`."
        ),
        request=CourseCreateSerializer,
        responses={
            201: CourseSerializer,
            400: OpenApiResponse(description="Validation error"),
        },
        examples=[
            OpenApiExample(
                "Create course example",
                value={
                    "name": "Morning Yoga",
                    "coach": "<coach-uuid>",
                    "time": "08:00:00",
                    "day": "MON",
                    "max_members": 15,
                    "salle": "Salle A",
                    "number_of_sessions": 12,
                },
                request_only=True,
            )
        ],
    )
    def post(self, request):
        serializer = CourseCreateSerializer(data=request.data, context={'request': request})
        if serializer.is_valid():
            course = serializer.save()
            return Response(CourseSerializer(course).data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


@extend_schema(tags=["Admin — Courses"])
class AdminCourseDetailView(APIView):
    """**Admin only.** Retrieve, update, or delete a course."""
    permission_classes = [IsAdminUser]

    def _get_course(self, pk):
        try:
            return Course.objects.select_related('coach', 'created_by').get(pk=pk)
        except Course.DoesNotExist:
            return None

    @extend_schema(
        summary="Get course details",
        responses={200: CourseSerializer, 404: OpenApiResponse(description="Not found")},
    )
    def get(self, request, pk):
        course = self._get_course(pk)
        if not course:
            return Response({'error': 'Course not found.'}, status=status.HTTP_404_NOT_FOUND)
        return Response(CourseSerializer(course).data)

    @extend_schema(
        summary="Update a course (partial)",
        request=CourseCreateSerializer,
        responses={200: CourseSerializer, 400: OpenApiResponse(description="Validation error")},
    )
    def patch(self, request, pk):
        course = self._get_course(pk)
        if not course:
            return Response({'error': 'Course not found.'}, status=status.HTTP_404_NOT_FOUND)
        serializer = CourseCreateSerializer(
            course, data=request.data, partial=True, context={'request': request}
        )
        if serializer.is_valid():
            serializer.save()
            return Response(CourseSerializer(course).data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    @extend_schema(
        summary="Delete a course",
        responses={200: OpenApiResponse(description="Deleted successfully")},
    )
    def delete(self, request, pk):
        course = self._get_course(pk)
        if not course:
            return Response({'error': 'Course not found.'}, status=status.HTTP_404_NOT_FOUND)
        course.delete()
        return Response({'message': 'Course deleted successfully.'}, status=status.HTTP_200_OK)


# ═══════════════════════════════════════════════════════════════════════════════
#  ADMIN — SESSION MANAGEMENT
# ═══════════════════════════════════════════════════════════════════════════════

@extend_schema(tags=["Admin — Sessions"])
class AdminSessionListView(generics.ListAPIView):
    """**Admin only.** List all sessions. Filter by ?course=<id>."""
    serializer_class = SessionSerializer
    permission_classes = [IsAdminUser]

    @extend_schema(
        summary="List all sessions",
        description="Returns all sessions. Optionally filter with `?course=<id>`.",
        parameters=[
            OpenApiParameter(
                name='course',
                type=OpenApiTypes.INT,
                location=OpenApiParameter.QUERY,
                description='Filter sessions by course ID',
                required=False,
            )
        ],
        responses={200: SessionSerializer(many=True)},
    )
    def get(self, request, *args, **kwargs):
        return super().get(request, *args, **kwargs)

    def get_queryset(self):
        qs = Session.objects.select_related('course', 'course__coach').order_by('date')
        course_id = self.request.query_params.get('course')
        if course_id:
            qs = qs.filter(course_id=course_id)
        return qs


@extend_schema(tags=["Admin — Sessions"])
class AdminSessionCreateView(APIView):
    """**Admin only.** Create a session for an existing course."""
    permission_classes = [IsAdminUser]

    @extend_schema(
        summary="Create a session",
        description="Create a session linked to a course. Provide `course` (id), `date` (YYYY-MM-DD), optional `notes`.",
        request=SessionCreateSerializer,
        responses={
            201: SessionDetailSerializer,
            400: OpenApiResponse(description="Validation error"),
        },
        examples=[
            OpenApiExample(
                "Create session example",
                value={"course": 1, "date": "2026-04-15", "notes": ""},
                request_only=True,
            )
        ],
    )
    def post(self, request):
        serializer = SessionCreateSerializer(data=request.data)
        if serializer.is_valid():
            session = serializer.save()
            return Response(SessionDetailSerializer(session).data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


@extend_schema(tags=["Admin — Sessions"])
class AdminSessionDetailView(APIView):
    """**Admin only.** Retrieve, update, or delete a session (includes full booking list)."""
    permission_classes = [IsAdminUser]

    def _get_session(self, pk):
        try:
            return (
                Session.objects
                .select_related('course', 'course__coach')
                .prefetch_related('bookings__member')
                .get(pk=pk)
            )
        except Session.DoesNotExist:
            return None

    @extend_schema(
        summary="Get session details (with bookings)",
        responses={200: SessionDetailSerializer, 404: OpenApiResponse(description="Not found")},
    )
    def get(self, request, pk):
        session = self._get_session(pk)
        if not session:
            return Response({'error': 'Session not found.'}, status=status.HTTP_404_NOT_FOUND)
        return Response(SessionDetailSerializer(session).data)

    @extend_schema(
        summary="Update a session (partial)",
        request=SessionCreateSerializer,
        responses={200: SessionDetailSerializer},
    )
    def patch(self, request, pk):
        session = self._get_session(pk)
        if not session:
            return Response({'error': 'Session not found.'}, status=status.HTTP_404_NOT_FOUND)
        serializer = SessionCreateSerializer(session, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(SessionDetailSerializer(session).data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    @extend_schema(
        summary="Delete a session",
        responses={200: OpenApiResponse(description="Deleted successfully")},
    )
    def delete(self, request, pk):
        session = self._get_session(pk)
        if not session:
            return Response({'error': 'Session not found.'}, status=status.HTTP_404_NOT_FOUND)
        session.delete()
        return Response({'message': 'Session deleted successfully.'}, status=status.HTTP_200_OK)


# ═══════════════════════════════════════════════════════════════════════════════
#  MEMBER — COURSES & SESSIONS
# ═══════════════════════════════════════════════════════════════════════════════

@extend_schema(tags=["Member — Courses"])
class CourseListView(generics.ListAPIView):
    """**Member only.** Browse all available courses."""
    serializer_class = CourseSerializer
    permission_classes = [AllowAny]
    authentication_classes = []
    queryset = Course.objects.select_related('coach', 'created_by').order_by('day', 'time')

    @extend_schema(
        summary="List all courses",
        description="Browse every course available at the gym.",
        responses={200: CourseSerializer(many=True)},
    )
    def get(self, request, *args, **kwargs):
        _member_claims(request)
        return super().get(request, *args, **kwargs)

    def list(self, request, *args, **kwargs):
        member = _get_member(request)
        queryset = list(self.get_queryset())
        serializer = self.get_serializer(queryset, many=True)

        next_sessions = {}
        for course in queryset:
            sessions = _upcoming_course_sessions(course)
            if sessions:
                next_sessions[course.id] = sessions[0]

        booked_summaries = {}
        if member:
            for course in queryset:
                summary = _course_booking_summary(course, member)
                if summary:
                    booked_summaries[course.id] = summary

        for item in serializer.data:
            course_id = item['id']
            next_session = next_sessions.get(course_id)
            summary = booked_summaries.get(course_id)
            item['is_booked'] = summary is not None
            item['booking_status'] = summary['status'] if summary else None
            item['booked_sessions_count'] = summary['booked_sessions_count'] if summary else 0
            item['confirmed_sessions_count'] = summary['confirmed_sessions_count'] if summary else 0
            item['waiting_sessions_count'] = summary['waiting_sessions_count'] if summary else 0
            item['next_session_date'] = next_session.date if next_session else None
            item['salle'] = next_session.salle_fk.name if next_session and next_session.salle_fk else None
            item['duration_time'] = next_session.duration_time if next_session else None
            item['slots_available'] = (
                max(0, item['max_members'] - next_session.confirmed_count)
                if next_session else item['max_members']
            )

        return Response(serializer.data)


@extend_schema(tags=["Member — Courses"])
class CourseBookView(APIView):
    """**Member only.** Book an entire course across its upcoming sessions."""
    permission_classes = [AllowAny]
    authentication_classes = []

    @extend_schema(
        summary="Book a whole course",
        description="Creates bookings for all upcoming non-cancelled sessions in the selected course.",
        request=None,
        responses={201: OpenApiResponse(description="Course booked successfully")},
    )
    def post(self, request, pk):
        _member_claims(request)
        if not IsNotSuspended().has_permission(request, self):
            return Response(
                {'error': IsNotSuspended.message},
                status=status.HTTP_403_FORBIDDEN,
            )

        member = _get_member(request)
        if not member:
            return Response({'error': 'Invalid member token.'}, status=status.HTTP_401_UNAUTHORIZED)

        try:
            course = Course.objects.select_related('coach').get(pk=pk)
        except Course.DoesNotExist:
            return Response({'error': 'Course not found.'}, status=status.HTTP_404_NOT_FOUND)

        if course.session_price > 0:
            return Response(
                {'error': 'This course requires payment. Use the payment endpoint to book.'},
                status=status.HTTP_402_PAYMENT_REQUIRED,
            )

        if Booking.objects.filter(member=member, session__course=course).exists():
            return Response(
                {'error': 'You already booked this course.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        sessions = _upcoming_course_sessions(course)
        if not sessions:
            return Response(
                {'error': 'This course has no upcoming sessions.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        confirmed_count = 0
        waiting_count = 0
        for session in sessions:
            booking_status = 'confirmed' if not session.is_full else 'waiting'
            Booking.objects.create(session=session, member=member, status=booking_status)
            if booking_status == 'confirmed':
                confirmed_count += 1
            else:
                waiting_count += 1

        return Response(
            {
                'detail': 'Course booked successfully.',
                'course_booking': _course_booking_summary(course, member),
                'confirmed_sessions_count': confirmed_count,
                'waiting_sessions_count': waiting_count,
            },
            status=status.HTTP_201_CREATED,
        )


@extend_schema(tags=["Member — Courses"])
class CourseCancelView(APIView):
    """**Member only.** Cancel an entire course booking."""
    permission_classes = [AllowAny]
    authentication_classes = []

    @extend_schema(
        summary="Cancel a whole course booking",
        description="Deletes all the member's bookings for the selected course.",
        request=None,
        responses={200: OpenApiResponse(description="Course booking cancelled")},
    )
    def post(self, request, pk):
        _member_claims(request)
        member = _get_member(request)
        if not member:
            return Response({'error': 'Invalid member token.'}, status=status.HTTP_401_UNAUTHORIZED)

        try:
            course = Course.objects.select_related('coach').get(pk=pk)
        except Course.DoesNotExist:
            return Response({'error': 'Course not found.'}, status=status.HTTP_404_NOT_FOUND)

        bookings = list(
            Booking.objects
            .select_related('session')
            .filter(member=member, session__course=course)
        )
        if not bookings:
            return Response(
                {'error': 'No course booking found.'},
                status=status.HTTP_404_NOT_FOUND,
            )

        deleted_count = len(bookings)
        promoted_count = 0
        for booking in bookings:
            was_confirmed = booking.status == 'confirmed'
            session = booking.session
            booking.delete()
            if was_confirmed and _promote_next_waiting(session):
                promoted_count += 1

        return Response(
            {
                'detail': 'Course booking cancelled successfully.',
                'deleted_sessions_count': deleted_count,
                'promoted_waiting_members_count': promoted_count,
            },
            status=status.HTTP_200_OK,
        )


@extend_schema(tags=["Member — Sessions"])
class SessionListView(generics.ListAPIView):
    """**Member only.** List upcoming non-cancelled sessions."""
    serializer_class = SessionSerializer
    permission_classes = [AllowAny]
    authentication_classes = []

    @extend_schema(
        summary="List upcoming sessions",
        description="Returns all future, non-cancelled sessions. Filter by `?course=<id>`.",
        parameters=[
            OpenApiParameter(
                name='course',
                type=OpenApiTypes.INT,
                location=OpenApiParameter.QUERY,
                description='Filter by course ID',
                required=False,
            )
        ],
        responses={200: SessionSerializer(many=True)},
    )
    def get(self, request, *args, **kwargs):
        _member_claims(request)
        return super().get(request, *args, **kwargs)

    def get_queryset(self):
        qs = (
            Session.objects
            .select_related('course', 'course__coach')
            .filter(is_cancelled=False, date__gte=timezone.now().date())
            .order_by('date')
        )
        course_id = self.request.query_params.get('course')
        if course_id:
            qs = qs.filter(course_id=course_id)
        return qs


@extend_schema(tags=["Member — Sessions"])
class SessionBookView(APIView):
    """
    **Member only.** Book a session.

    - If capacity is available → `confirmed`
    - If session is full → `waiting` (FIFO queue)
    """
    permission_classes = [AllowAny]
    authentication_classes = []

    @extend_schema(
        summary="Book a session",
        description=(
            "Book a seat in a session. If the session is full you are placed on the "
            "FIFO waiting list and automatically promoted when a confirmed member cancels."
        ),
        request=None,
        responses={
            201: OpenApiResponse(description="Booking created (confirmed or waiting)"),
            400: OpenApiResponse(description="Already booked / session cancelled"),
            404: OpenApiResponse(description="Session not found"),
        },
    )
    def post(self, request, pk):
        _member_claims(request)
        if not IsNotSuspended().has_permission(request, self):
            return Response(
                {'error': IsNotSuspended.message},
                status=status.HTTP_403_FORBIDDEN,
            )
        member = _get_member(request)
        if not member:
            return Response({'error': 'Invalid member token.'}, status=status.HTTP_401_UNAUTHORIZED)

        try:
            session = Session.objects.select_related('course').get(pk=pk)
        except Session.DoesNotExist:
            return Response({'error': 'Session not found.'}, status=status.HTTP_404_NOT_FOUND)

        if session.course.session_price > 0:
            return Response(
                {'error': 'This course requires payment. Use the payment endpoint to book.'},
                status=status.HTTP_402_PAYMENT_REQUIRED,
            )

        if session.is_cancelled:
            return Response({'error': 'This session has been cancelled.'}, status=status.HTTP_400_BAD_REQUEST)

        if Booking.objects.filter(session=session, member=member).exists():
            return Response(
                {'error': 'You already have a booking for this session.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        booking_status = 'confirmed' if not session.is_full else 'waiting'
        booking = Booking.objects.create(session=session, member=member, status=booking_status)

        return Response({
            'detail': f"Booked successfully — status: {booking_status}.",
            'booking_id': booking.id,
            'status': booking_status,
            'session': SessionSerializer(session).data,
        }, status=status.HTTP_201_CREATED)


@extend_schema(tags=["Member — Sessions"])
class SessionCancelView(APIView):
    """
    **Member only.** Cancel your booking for a session.

    FIFO: if you had a `confirmed` spot, the first member on the waiting list
    is automatically promoted and notified (in-app + email).
    """
    permission_classes = [AllowAny]
    authentication_classes = []

    @extend_schema(
        summary="Cancel my booking",
        description=(
            "Cancel your attendance for a session. If you were confirmed, "
            "the next person on the waiting list is promoted and notified automatically."
        ),
        request=None,
        responses={
            200: OpenApiResponse(description="Booking cancelled"),
            404: OpenApiResponse(description="Booking or session not found"),
        },
    )
    def post(self, request, pk):
        _member_claims(request)
        member = _get_member(request)
        if not member:
            return Response({'error': 'Invalid member token.'}, status=status.HTTP_401_UNAUTHORIZED)

        try:
            session = Session.objects.select_related('course').get(pk=pk)
        except Session.DoesNotExist:
            return Response({'error': 'Session not found.'}, status=status.HTTP_404_NOT_FOUND)

        try:
            booking = Booking.objects.get(session=session, member=member)
        except Booking.DoesNotExist:
            return Response(
                {'error': 'No booking found for this session.'},
                status=status.HTTP_404_NOT_FOUND,
            )

        was_confirmed = (booking.status == 'confirmed')
        booking.delete()

        promoted = None
        if was_confirmed:
            promoted = _promote_next_waiting(session)

        response_data = {'detail': 'Your booking has been cancelled.'}
        if promoted:
            response_data['detail'] += (
                f' {promoted.member.get_full_name()} was next on the waiting list '
                f'and has been confirmed & notified.'
            )

        return Response(response_data, status=status.HTTP_200_OK)


@extend_schema(tags=["Member — Sessions"])
class MemberBookingsView(generics.ListAPIView):
    """**Member only.** List all your whole-course bookings."""
    serializer_class = BookingSerializer
    permission_classes = [AllowAny]
    authentication_classes = []

    @extend_schema(
        summary="My bookings",
        description="Returns all bookings for the currently authenticated member.",
        responses={200: BookingSerializer(many=True)},
    )
    def get(self, request, *args, **kwargs):
        _member_claims(request)
        member = _get_member(self.request)
        if not member:
            return Response([], status=status.HTTP_200_OK)

        courses = (
            Course.objects
            .select_related('coach')
            .filter(sessions__bookings__member=member)
            .distinct()
            .order_by('day', 'time')
        )
        data = []
        for course in courses:
            summary = _course_booking_summary(course, member)
            if summary is not None:
                data.append(summary)
        return Response(data, status=status.HTTP_200_OK)


# ═══════════════════════════════════════════════════════════════════════════════
#  COACH — ATTENDANCE, STATS & EARNINGS
# ═══════════════════════════════════════════════════════════════════════════════
from django.db.models import Sum, Count, Q
from django.db import IntegrityError


@extend_schema(tags=["Coach — Sessions"])
class CoachSessionOverviewView(APIView):
    """**Coach only.** List coach sessions with member bookings for dashboard use."""
    permission_classes = [AllowAny]
    authentication_classes = []

    @extend_schema(summary="Get coach session overview")
    def get(self, request):
        coach_id = _coach_claims(request).get('user_id')
        today = timezone.now().date()
        sessions = (
            Session.objects
            .filter(course__coach_id=coach_id, date__gte=today)
            .select_related('course', 'course__coach', 'salle_fk')
            .prefetch_related('bookings__member', 'attendance_records')
            .order_by('date', 'course__time')
        )

        data = []
        for session in sessions:
            bookings = session.bookings.select_related('member').order_by('status', 'created_at')
            data.append({
                'id': session.id,
                'course_id': session.course_id,
                'course_name': session.course.name,
                'coach_name': session.course.coach.get_full_name(),
                'date': session.date,
                'time': session.course.time,
                'day': session.course.day,
                'is_cancelled': session.is_cancelled,
                'notes': session.notes,
                'confirmed_count': session.confirmed_count,
                'waiting_count': session.waiting_count,
                'is_full': session.is_full,
                'max_members': session.course.max_members,
                'salle': session.salle_fk.name if session.salle_fk else None,
                'duration_time': session.duration_time,
                'attendance_marked': session.attendance_records.exists(),
                'bookings': BookingSerializer(bookings, many=True).data,
            })

        return Response(data)

@extend_schema(tags=["Coach — Sessions"])
class CoachMarkAttendanceView(APIView):
    """
    **Coach only.** Mark attendance for a session.
    """
    permission_classes = [AllowAny]
    authentication_classes = []

    @extend_schema(
        summary="Mark session attendance",
        description="Mark missing members. If missed without cancel, warning issued. 3 warnings = 1 week suspension.",
        request=inline_serializer(
            name="AttendanceRequest",
            fields={
                "present_member_ids": serializers.ListField(child=serializers.CharField())
            }
        ) if 'inline_serializer' in globals() else None,
        responses={200: OpenApiResponse(description="Attendance marked")}
    )
    def post(self, request, pk):
        claims = _coach_claims(request)
        try:
            session = Session.objects.select_related('course', 'course__coach').get(pk=pk)
        except Session.DoesNotExist:
            return Response({'error': 'Session not found.'}, status=status.HTTP_404_NOT_FOUND)

        coach_id = claims.get('user_id')
        if str(session.course.coach.id) != str(coach_id):
            return Response({'error': 'Not your session.'}, status=status.HTTP_403_FORBIDDEN)

        # Allow marking only on or after the session date
        if session.date > timezone.now().date():
            return Response({'error': 'Cannot mark attendance for upcoming sessions.'}, status=status.HTTP_400_BAD_REQUEST)

        # Check if already marked
        if AttendanceRecord.objects.filter(session=session).exists():
            return Response({'error': 'Attendance already marked for this session.'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            from users.models import Coach
            coach = Coach.objects.get(id=coach_id)
        except:
            return Response({'error': 'Coach not found.'}, status=status.HTTP_404_NOT_FOUND)

        present_ids = [str(i) for i in request.data.get('present_member_ids', [])]
        confirmed_bookings = session.bookings.filter(status='confirmed').select_related('member')

        warnings_issued = 0
        suspensions_applied = 0
        attended = 0
        absent = 0

        for booking in confirmed_bookings:
            member = booking.member
            is_present = str(member.id) in present_ids

            try:
                AttendanceRecord.objects.create(
                    session=session,
                    member=member,
                    is_present=is_present,
                    marked_by=coach
                )
            except IntegrityError:
                continue # Skip if already recorded by concurrency

            if is_present:
                attended += 1
            else:
                absent += 1
                # Issue warning
                AbsenceWarning.objects.create(member=member, session=session)
                member.warnings_count += 1
                warnings_issued += 1

                notification_type = 'absence_warning'
                title = f"Absence Warning: {session.course.name}"
                msg = f"You missed the session on {session.date} without cancelling. Please cancel if you cannot attend."

                if member.warnings_count >= 3:
                    member.is_suspended = True
                    member.suspension_end_date = timezone.now().date() + timezone.timedelta(days=7)
                    member.warnings_count = 0 # reset
                    suspensions_applied += 1
                    notification_type = 'account_suspended'
                    title = "Account Suspended"
                    msg = f"You have missed 3 sessions without cancelling. Your account is suspended until {member.suspension_end_date}."

                member.save(update_fields=['warnings_count', 'is_suspended', 'suspension_end_date'])
                
                # Notify
                _notify_member(member=member, title=title, message=msg, notification_type=notification_type)

        return Response({
            'detail': 'Attendance marked successfully',
            'attended': attended,
            'absent': absent,
            'warnings_issued': warnings_issued,
            'suspensions_applied': suspensions_applied
        })


@extend_schema(tags=["Coach — Sessions"])
class CoachSessionStatsView(APIView):
    """**Coach only.** Session statistics for their courses."""
    permission_classes = [AllowAny]
    authentication_classes = []

    @extend_schema(summary="Get session statistics")
    def get(self, request):
        coach_id = _coach_claims(request).get('user_id')
        sessions = Session.objects.filter(course__coach_id=coach_id).select_related('course').prefetch_related('bookings', 'attendance_records')
        
        stats = []
        for session in sessions:
            confirmed = session.bookings.filter(status='confirmed').count()
            waiting = session.bookings.filter(status='waiting').count()
            attended = session.attendance_records.filter(is_present=True).count() if session.attendance_records.exists() else 0
            rate = int((attended / confirmed) * 100) if confirmed > 0 and session.attendance_records.exists() else 0

            stats.append({
                'session_id': session.id,
                'course_name': session.course.name,
                'date': session.date,
                'is_cancelled': session.is_cancelled,
                'confirmed_count': confirmed,
                'waiting_count': waiting,
                'attended_count': attended,
                'attendance_rate_percent': rate,
            })
            
        return Response(stats)


@extend_schema(tags=["Coach — Sessions"])
class CoachEarningsDashboardView(APIView):
    """**Coach only.** View monthly earnings."""
    permission_classes = [AllowAny]
    authentication_classes = []

    @extend_schema(
        summary="Get monthly earnings",
        parameters=[
            OpenApiParameter(name='month', type=OpenApiTypes.STR, description='YYYY-MM format, defaults to current month')
        ]
    )
    def get(self, request):
        coach_id = _coach_claims(request).get('user_id')
        month_str = request.query_params.get('month')
        
        if month_str:
            try:
                target_month = timezone.datetime.strptime(month_str, '%Y-%m').date()
            except ValueError:
                return Response({'error': 'Invalid month format, use YYYY-MM'}, status=400)
        else:
            target_month = timezone.now().date().replace(day=1)
            
        sessions = Session.objects.filter(
            course__coach_id=coach_id,
            is_cancelled=False,
            date__year=target_month.year,
            date__month=target_month.month
        ).select_related('course').prefetch_related('attendance_records')

        total_earnings = 0
        breakdown = []

        for session in sessions:
            # Check if attendance exists
            if session.attendance_records.exists():
                attended_count = session.attendance_records.filter(is_present=True).count()
                price = session.course.session_price
                earnings = float(price) * attended_count
                total_earnings += earnings
                
                breakdown.append({
                    'session_id': session.id,
                    'course_name': session.course.name,
                    'date': session.date,
                    'attended_count': attended_count,
                    'price_per_member': float(price),
                    'earnings': earnings
                })

        return Response({
            'month': target_month.strftime('%Y-%m'),
            'total_earnings': total_earnings,
            'sessions': breakdown
        })


# ═══════════════════════════════════════════════════════════════════════════════
#  MEMBER & SHARED VIEWS
# ═══════════════════════════════════════════════════════════════════════════════

CALORIE_MAP = {
    'crossfit': 600, 'yoga': 300, 'spinning': 500, 'pilates': 250,
    'cardio': 400, 'strength': 450, 'nutrition': 0, 'other': 350
}

@extend_schema(tags=["Member — Dashboard"])
class MemberActivityDashboardView(APIView):
    """**Member only.** Personal activity dashboard."""
    permission_classes = [AllowAny]
    authentication_classes = []

    @extend_schema(summary="Get member dashboard metrics")
    def get(self, request):
        _member_claims(request)
        member = _get_member(request)
        if not member:
            return Response(status=401)

        now_date = timezone.now().date()
        start_of_week = now_date - timezone.timedelta(days=now_date.weekday())
        
        # Sessions attended this week
        records_this_week = AttendanceRecord.objects.filter(
            member=member,
            is_present=True,
            session__date__gte=start_of_week
        ).select_related('session__course')

        # All time
        records_all = AttendanceRecord.objects.filter(
            member=member,
            is_present=True
        ).select_related('session', 'session__course__coach')

        weekly_sessions = records_this_week.count()
        
        total_calories = sum([
            CALORIE_MAP.get(r.session.course.coach.specialities, 350) 
            for r in records_all 
            if getattr(r.session.course.coach, 'specialities', None)
        ])
        
        # Simple goal progress mock (e.g., 3 sessions a week goal)
        goal_progress = min(100, int((weekly_sessions / 3.0) * 100))

        return Response({
            'weekly_sessions': weekly_sessions,
            'total_calories_burned': total_calories,
            'goal_progress_percent': goal_progress,
            'total_sessions_attended': records_all.count()
        })


@extend_schema(tags=["Member — Dashboard"])
class AbsenceWarningListView(generics.ListAPIView):
    """**Member AND Coach.** List absence warnings."""
    serializer_class = AbsenceWarningSerializer
    permission_classes = [AllowAny]
    authentication_classes = []

    @extend_schema(summary="List absence warnings")
    def get(self, request, *args, **kwargs):
        _token_claims(request)
        return super().get(request, *args, **kwargs)

    def get_queryset(self):
        claims = _token_claims(self.request)
        role = claims.get('role')
        user_id = claims.get('user_id')
        
        if role == 'member':
            return AbsenceWarning.objects.filter(member_id=user_id).select_related('session', 'session__course').order_by('-issued_at')
        elif role == 'coach':
            return AbsenceWarning.objects.filter(session__course__coach_id=user_id).select_related('member', 'session', 'session__course').order_by('-issued_at')
        return AbsenceWarning.objects.none()


# ── Course Payment (Chargily) ─────────────────────────────────────────────────

@extend_schema(tags=["Member — Courses"])
class InitiateCoursePaymentView(APIView):
    """Initiate a Chargily checkout to pay for booking a course."""
    permission_classes = [AllowAny]
    authentication_classes = []

    def post(self, request, pk):
        _member_claims(request)
        if not IsNotSuspended().has_permission(request, self):
            return Response({'error': IsNotSuspended.message}, status=status.HTTP_403_FORBIDDEN)

        member = _get_member(request)
        if not member:
            return Response({'error': 'Invalid member token.'}, status=status.HTTP_401_UNAUTHORIZED)

        try:
            course = Course.objects.get(pk=pk)
        except Course.DoesNotExist:
            return Response({'error': 'Course not found.'}, status=status.HTTP_404_NOT_FOUND)

        if Booking.objects.filter(member=member, session__course=course).exists():
            return Response({'error': 'You already booked this course.'}, status=status.HTTP_400_BAD_REQUEST)

        sessions = _upcoming_course_sessions(course)
        if not sessions:
            return Response({'error': 'This course has no upcoming sessions.'}, status=status.HTTP_400_BAD_REQUEST)

        total_amount = course.session_price * len(sessions)

        from django.conf import settings
        frontend_url = getattr(settings, 'FRONTEND_URL', 'http://localhost:3000').rstrip('/')
        success_url = f'{frontend_url}/payment-success?type=course&course_id={course.id}'
        failure_url = f'{frontend_url}/payment-failure?type=course&course_id={course.id}'

        result = ChargilyService.create_payment(
            amount=total_amount,
            success_url=success_url,
            failure_url=failure_url,
            description=f'Course booking: {course.name}',
            metadata={'course_id': course.id, 'member_id': str(member.id), 'type': 'course_booking'},
        )

        if not result.get('success'):
            return Response({'error': result.get('error', 'Payment initiation failed.')}, status=status.HTTP_502_BAD_GATEWAY)

        CoursePayment.objects.create(
            member=member,
            course=course,
            amount=total_amount,
            transaction_id=result['transaction_id'],
            status='pending',
        )

        return Response({
            'checkout_url': result['checkout_url'],
            'transaction_id': result['transaction_id'],
            'course_id': course.id,
            'amount': float(total_amount),
        }, status=status.HTTP_201_CREATED)


@extend_schema(tags=["Member — Courses"])
class VerifyCoursePaymentView(APIView):
    """Verify a Chargily course payment and create bookings on success."""
    permission_classes = [AllowAny]
    authentication_classes = []

    def post(self, request):
        _member_claims(request)
        member = _get_member(request)
        if not member:
            return Response({'error': 'Invalid member token.'}, status=status.HTTP_401_UNAUTHORIZED)

        transaction_id = request.data.get('transaction_id')
        course_id = request.data.get('course_id')

        if not transaction_id or not course_id:
            return Response({'error': 'transaction_id and course_id are required.'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            payment = CoursePayment.objects.get(transaction_id=transaction_id, member=member)
        except CoursePayment.DoesNotExist:
            return Response({'error': 'Payment record not found.'}, status=status.HTTP_404_NOT_FOUND)

        if payment.status == 'completed':
            return Response({'detail': 'Already confirmed.'}, status=status.HTTP_200_OK)

        result = ChargilyService.verify_payment(transaction_id)
        chargily_status = result.get('status', '') if result.get('success') else ''

        if chargily_status != 'paid':
            payment.status = 'failed'
            payment.save(update_fields=['status'])
            return Response({'error': f'Payment not completed. Status: {chargily_status}'}, status=status.HTTP_400_BAD_REQUEST)

        payment.status = 'completed'
        payment.paid_at = timezone.now()
        payment.save(update_fields=['status', 'paid_at'])

        course = payment.course
        if Booking.objects.filter(member=member, session__course=course).exists():
            return Response({'detail': 'Course already booked.', 'course_booking': _course_booking_summary(course, member)}, status=status.HTTP_200_OK)

        sessions = _upcoming_course_sessions(course)
        confirmed_count = 0
        waiting_count = 0
        for session in sessions:
            booking_status = 'confirmed' if not session.is_full else 'waiting'
            Booking.objects.get_or_create(session=session, member=member, defaults={'status': booking_status})
            if booking_status == 'confirmed':
                confirmed_count += 1
            else:
                waiting_count += 1

        return Response({
            'detail': 'Payment verified and course booked successfully.',
            'course_booking': _course_booking_summary(course, member),
            'confirmed_sessions_count': confirmed_count,
            'waiting_sessions_count': waiting_count,
        }, status=status.HTTP_201_CREATED)