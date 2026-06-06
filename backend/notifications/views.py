from rest_framework import generics
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework import status

from drf_spectacular.utils import extend_schema, OpenApiParameter, OpenApiExample
from drf_spectacular.types import OpenApiTypes

from users.permissions import IsMemberToken
from .models import Notification
from .serializers import NotificationSerializer


class MemberNotificationListView(generics.ListAPIView):
    """
    GET /api/notifications/
    Returns all notifications for the authenticated member, newest first.
    """
    serializer_class = NotificationSerializer
    permission_classes = [IsMemberToken]

    @extend_schema(
        summary="List my notifications",
        description="Returns all in-app notifications for the current member (newest first).",
        responses={200: NotificationSerializer(many=True)},
        tags=["Notifications"],
    )
    def get(self, request, *args, **kwargs):
        return super().get(request, *args, **kwargs)

    def get_queryset(self):
        from users.models import Member
        member_id = self.request.auth.get('user_id') if self.request.auth else None
        if not member_id:
            return Notification.objects.none()
        try:
            member = Member.objects.get(id=member_id)
        except Member.DoesNotExist:
            return Notification.objects.none()
        return Notification.objects.filter(member=member).order_by('-created_at')


class MarkNotificationReadView(APIView):
    """
    POST /api/notifications/<pk>/read/
    Mark a specific notification as read.
    """
    permission_classes = [IsMemberToken]

    @extend_schema(
        summary="Mark notification as read",
        responses={200: {"type": "object", "properties": {"detail": {"type": "string"}}}},
        tags=["Notifications"],
    )
    def post(self, request, pk):
        from users.models import Member
        member_id = request.auth.get('user_id') if request.auth else None
        try:
            member = Member.objects.get(id=member_id)
            notification = Notification.objects.get(pk=pk, member=member)
        except (Member.DoesNotExist, Notification.DoesNotExist):
            return Response({'error': 'Notification not found.'}, status=status.HTTP_404_NOT_FOUND)

        notification.is_read = True
        notification.save(update_fields=['is_read'])
        return Response({'detail': 'Notification marked as read.'})


class MarkAllNotificationsReadView(APIView):
    """
    POST /api/notifications/read-all/
    Mark all notifications for the member as read.
    """
    permission_classes = [IsMemberToken]

    @extend_schema(
        summary="Mark all notifications as read",
        responses={200: {"type": "object", "properties": {"detail": {"type": "string"}}}},
        tags=["Notifications"],
    )
    def post(self, request):
        from users.models import Member
        member_id = request.auth.get('user_id') if request.auth else None
        try:
            member = Member.objects.get(id=member_id)
        except Member.DoesNotExist:
            return Response({'error': 'Member not found.'}, status=status.HTTP_404_NOT_FOUND)

        updated = Notification.objects.filter(member=member, is_read=False).update(is_read=True)
        return Response({'detail': f'{updated} notification(s) marked as read.'})
