from datetime import timedelta, datetime
from decimal import Decimal

from django.db.models import Sum
from django.utils import timezone
from drf_spectacular.utils import extend_schema
from rest_framework import generics, permissions, status
from rest_framework.exceptions import AuthenticationFailed
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.tokens import AccessToken

from users.models import Member

from .models import Workout
from .serializers import WorkoutSerializer, WorkoutProgressionSerializer


def _authorization_token(request):
    auth_header = request.headers.get('Authorization', '')
    if not auth_header.startswith('Bearer '):
        raise AuthenticationFailed('Authentication credentials were not provided.')
    return auth_header.split(' ', 1)[1].strip()


def _member_from_request(request):
    try:
        access = AccessToken(_authorization_token(request))
    except TokenError as exc:
        raise AuthenticationFailed(str(exc))

    if access.get('role') != 'member':
        raise AuthenticationFailed('Not a member token.')

    member_id = access.get('user_id')
    try:
        return Member.objects.get(id=member_id)
    except Member.DoesNotExist:
        raise AuthenticationFailed('Member not found.')


class WorkoutBaseView:
    serializer_class = WorkoutSerializer
    permission_classes = [permissions.AllowAny]
    authentication_classes = []

    def get_member(self):
        return _member_from_request(self.request)

    def get_queryset(self):
        return Workout.objects.filter(member=self.get_member()).prefetch_related('exercises')

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context['member'] = self.get_member()
        return context

@extend_schema(tags=['Workouts'], description="List all workouts for the current member.")
class WorkoutListView(WorkoutBaseView, generics.ListAPIView):
    def get(self, request, *args, **kwargs):
        self.get_member()
        return super().get(request, *args, **kwargs)

@extend_schema(tags=['Workouts'], description="Log a new workout with exercises.")
class WorkoutCreateView(WorkoutBaseView, generics.CreateAPIView):
    def post(self, request, *args, **kwargs):
        self.get_member()
        return super().post(request, *args, **kwargs)

    def perform_create(self, serializer):
        serializer.save()

@extend_schema(tags=['Workouts'], description="Get details of a specific workout.")
class WorkoutDetailView(WorkoutBaseView, generics.RetrieveAPIView):
    lookup_field = 'pk'

    def get(self, request, *args, **kwargs):
        self.get_member()
        return super().get(request, *args, **kwargs)

class WorkoutProgressionView(APIView):
    permission_classes = [permissions.AllowAny]
    authentication_classes = []

    def get_duration_minutes(self, workout):
        start = datetime.combine(workout.day, workout.start_time)
        end = datetime.combine(workout.day, workout.end_time)
        if end > start:
            return (end - start).total_seconds() / 60
        if end < start:
            return ((end + timedelta(days=1)) - start).total_seconds() / 60
        return 0

    def get_metrics(self, queryset):
        # Calculate total calories
        calories = queryset.aggregate(total=Sum('calories_burned'))['total'] or 0
        
        # Calculate total duration in minutes
        total_minutes = 0
        for workout in queryset:
            total_minutes += self.get_duration_minutes(workout)
        
        return {
            "calories": calories,
            "duration_minutes": total_minutes
        }

    def get_day_curve(self, queryset):
        workouts = list(queryset.order_by('start_time', 'id'))
        curve = []
        for index, workout in enumerate(workouts, start=1):
            label = workout.start_time.strftime('%H:%M') if workout.start_time else f'S{index}'
            curve.append({
                'label': label,
                'calories': workout.calories_burned or Decimal('0.00'),
                'duration_minutes': self.get_duration_minutes(workout),
            })
        return curve

    def get_week_curve(self, queryset, today):
        curve = []
        for day_offset in range(6, -1, -1):
            current_day = today - timedelta(days=day_offset)
            day_queryset = queryset.filter(day=current_day)
            metrics = self.get_metrics(day_queryset)
            curve.append({
                'label': current_day.strftime('%a'),
                'calories': metrics['calories'],
                'duration_minutes': metrics['duration_minutes'],
            })
        return curve

    def get_month_curve(self, queryset, today):
        curve = []
        month_start = today - timedelta(days=29)
        for week_index in range(5):
            range_start = month_start + timedelta(days=week_index * 7)
            if range_start > today:
                break
            range_end = min(today, range_start + timedelta(days=6))
            week_queryset = queryset.filter(day__gte=range_start, day__lte=range_end)
            metrics = self.get_metrics(week_queryset)
            curve.append({
                'label': f'{range_start.strftime("%d %b")}-{range_end.strftime("%d %b")}',
                'calories': metrics['calories'],
                'duration_minutes': metrics['duration_minutes'],
            })
        return curve

    @extend_schema(tags=['Workouts'], responses={200: WorkoutProgressionSerializer})
    def get(self, request):
        try:
            member = _member_from_request(request)
        except AuthenticationFailed:
            return Response({"error": "Member profile not found"}, status=status.HTTP_404_NOT_FOUND)

        today = timezone.now().date()
        base_qs = Workout.objects.filter(member=member)
        day_qs = base_qs.filter(day=today)
        week_qs = base_qs.filter(day__gte=today - timedelta(days=6), day__lte=today)
        month_qs = base_qs.filter(day__gte=today - timedelta(days=29), day__lte=today)

        return Response({
            "day": self.get_metrics(day_qs),
            "week": self.get_metrics(week_qs),
            "month": self.get_metrics(month_qs),
            "day_curve": self.get_day_curve(day_qs),
            "week_curve": self.get_week_curve(base_qs, today),
            "month_curve": self.get_month_curve(base_qs, today),
        })
