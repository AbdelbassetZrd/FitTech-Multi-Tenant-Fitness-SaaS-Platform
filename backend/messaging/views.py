from django.db.models import Q
from django.views.generic import TemplateView
from rest_framework import status, permissions
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.exceptions import AuthenticationFailed
from rest_framework_simplejwt.tokens import AccessToken
from rest_framework_simplejwt.exceptions import TokenError
from drf_spectacular.utils import extend_schema

from users.models import Member, Coach, CustomUser
from notifications.models import Notification
from .models import DirectMessage
from .serializers import DirectMessageSerializer, SendMessageSerializer


def _resolve_user(request):
    """Decode the bearer JWT and return (user_obj, role).

    Member/Coach tokens don't reference CustomUser rows, so we resolve them
    manually rather than relying on DRF's default JWTAuthentication.
    """
    auth_header = request.headers.get('Authorization', '')
    if not auth_header.startswith('Bearer '):
        raise AuthenticationFailed('Authentication credentials were not provided.')
    raw_token = auth_header.split(' ', 1)[1].strip()

    try:
        access = AccessToken(raw_token)
    except TokenError as exc:
        raise AuthenticationFailed(str(exc))

    user_id = access.get('user_id')
    role = access.get('role')

    if not user_id:
        raise AuthenticationFailed('Invalid token payload.')

    if role == 'member':
        try:
            return Member.objects.get(id=user_id), 'member'
        except Member.DoesNotExist:
            raise AuthenticationFailed('Member not found.')
    if role == 'coach':
        try:
            return Coach.objects.get(id=user_id), 'coach'
        except Coach.DoesNotExist:
            raise AuthenticationFailed('Coach not found.')

    # Default: admin / staff token issued via Django auth.
    try:
        return CustomUser.objects.get(id=user_id), 'admin'
    except CustomUser.DoesNotExist:
        raise AuthenticationFailed('User not found.')

class TestChatView(TemplateView):
    template_name = 'test_chat.html'

class ContactListView(APIView):
    """List potential chat contacts based on user role."""
    permission_classes = [permissions.AllowAny]
    authentication_classes = []

    @extend_schema(tags=["Messaging"])
    def get(self, request):
        try:
            user, role = _resolve_user(request)
        except AuthenticationFailed as exc:
            return Response({'detail': str(exc)}, status=status.HTTP_401_UNAUTHORIZED)
        user_id = str(user.id)

        contacts = []

        # 0. Always inject the FitTech AI bot at the top of the list
        contacts.append({
            'id': 'nutrition-bot',
            'name': 'FitTech AI 🤖',
            'role': 'bot',
            'email': 'fittech-ai@fittech.ai',
            'description': 'Your personal AI fitness and nutrition coach. Ask me anything about workouts, meals, diet plans, and more!',
        })

        # 1. Always include Coaches and Admins
        coaches = Coach.objects.filter(is_active=True)
        for c in coaches:
            if str(c.id) != str(user_id):
                contacts.append({
                    'id': str(c.id),
                    'name': f"{c.first_name} {c.last_name}",
                    'role': 'coach',
                    'email': c.email
                })
        
        admins = CustomUser.objects.filter(is_active=True)
        for a in admins:
            if str(a.id) != str(user_id):
                contacts.append({
                    'id': str(a.id),
                    'name': f"{a.first_name} {a.last_name}",
                    'role': 'admin',
                    'email': a.email
                })

        # 2. If current user is Coach or Admin, also include Members
        if role in ('coach', 'admin'):
            members = Member.objects.filter(is_active=True)
            for m in members:
                if str(m.id) != str(user_id):
                    contacts.append({
                        'id': str(m.id),
                        'name': f"{m.first_name} {m.last_name}",
                        'role': 'member',
                        'email': m.email
                    })

        return Response({
            'current_user_id': user_id,
            'contacts': contacts
        })

@extend_schema(tags=["Messaging"])
class InboxView(APIView):
    """List messages involving the current user.

    Optional query param: `with_user=<id>` returns only the conversation
    between the current user and the target user (sorted oldest first).
    """
    permission_classes = [permissions.AllowAny]
    authentication_classes = []

    def get(self, request):
        from django.contrib.contenttypes.models import ContentType
        try:
            user, _ = _resolve_user(request)
        except AuthenticationFailed as exc:
            return Response({'detail': str(exc)}, status=status.HTTP_401_UNAUTHORIZED)

        user_type = ContentType.objects.get_for_model(user)

        with_user = request.query_params.get('with_user')
        if with_user:
            target_obj = None
            for model in [Member, Coach, CustomUser]:
                try:
                    target_obj = model.objects.get(id=with_user)
                    break
                except model.DoesNotExist:
                    continue
            if not target_obj:
                return Response({'results': []})
            target_type = ContentType.objects.get_for_model(target_obj)
            qs = DirectMessage.objects.filter(
                (Q(sender_type=user_type, sender_id=str(user.id)) &
                 Q(recipient_type=target_type, recipient_id=str(target_obj.id))) |
                (Q(sender_type=target_type, sender_id=str(target_obj.id)) &
                 Q(recipient_type=user_type, recipient_id=str(user.id)))
            ).order_by('created_at')
            # Mark inbound messages as read
            DirectMessage.objects.filter(
                recipient_type=user_type,
                recipient_id=str(user.id),
                sender_type=target_type,
                sender_id=str(target_obj.id),
                is_read=False,
            ).update(is_read=True)
            return Response({
                'results': DirectMessageSerializer(qs, many=True).data,
            })

        qs = DirectMessage.objects.filter(
            Q(sender_type=user_type, sender_id=str(user.id)) |
            Q(recipient_type=user_type, recipient_id=str(user.id))
        ).order_by('-created_at')
        return Response({
            'results': DirectMessageSerializer(qs, many=True).data,
        })


@extend_schema(tags=["Messaging"])
class SendMessageView(APIView):
    """Send a private message to another user (member, coach, or admin)."""
    permission_classes = [permissions.AllowAny]
    authentication_classes = []

    @extend_schema(request=SendMessageSerializer, responses={201: DirectMessageSerializer})
    def post(self, request):
        try:
            user, _ = _resolve_user(request)
        except AuthenticationFailed as exc:
            return Response({'detail': str(exc)}, status=status.HTTP_401_UNAUTHORIZED)

        serializer = SendMessageSerializer(data=request.data)
        if serializer.is_valid():
            message = serializer.save(sender=user)

            # Trigger Notification (only when recipient is a Member)
            try:
                if isinstance(message.recipient, Member):
                    Notification.objects.create(
                        member=message.recipient,
                        notification_type='new_message',
                        title=f"New Message from {user.get_full_name()}",
                        message=message.content[:50] + ('...' if len(message.content) > 50 else ''),
                    )
            except Exception:
                pass

            # ── Real-time broadcast ──────────────────────────────────────────
            # Push the saved message to the WebSocket room so both participants
            # see it immediately without polling or page refresh.
            try:
                from channels.layers import get_channel_layer
                from asgiref.sync import async_to_sync

                channel_layer = get_channel_layer()
                if channel_layer is not None:
                    s_id = str(message.sender_id).strip().lower()[:36]
                    r_id = str(message.recipient_id).strip().lower()[:36]
                    room = f"private_chat_{'_'.join(sorted([s_id, r_id]))}"
                    sender_name = ' '.join(
                        filter(None, [
                            getattr(user, 'first_name', ''),
                            getattr(user, 'last_name', ''),
                        ])
                    ).strip() or getattr(user, 'email', s_id)
                    async_to_sync(channel_layer.group_send)(
                        room,
                        {
                            'type': 'chat_message',
                            'id': message.id,
                            'message': message.content,
                            'sender_id': str(message.sender_id),
                            'sender_name': sender_name,
                            'recipient_id': str(message.recipient_id),
                            'created_at': message.created_at.isoformat(),
                            'is_bot': False,
                        },
                    )
            except Exception:
                # Never let a WS broadcast failure break the REST response.
                pass

            return Response(DirectMessageSerializer(message).data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


@extend_schema(tags=["Messaging"])
class MarkAsReadView(APIView):
    """Mark a specific message as read."""
    permission_classes = [permissions.AllowAny]
    authentication_classes = []

    @extend_schema(tags=["Messaging"], responses={200: None})
    def patch(self, request, pk):
        from django.contrib.contenttypes.models import ContentType
        try:
            user, _ = _resolve_user(request)
        except AuthenticationFailed as exc:
            return Response({'detail': str(exc)}, status=status.HTTP_401_UNAUTHORIZED)

        user_type = ContentType.objects.get_for_model(user)
        try:
            message = DirectMessage.objects.get(
                pk=pk,
                recipient_type=user_type,
                recipient_id=str(user.id),
            )
            message.is_read = True
            message.save(update_fields=['is_read'])
            return Response({'status': 'Message marked as read'})
        except DirectMessage.DoesNotExist:
            return Response({'error': 'Message not found.'}, status=status.HTTP_404_NOT_FOUND)


@extend_schema(tags=["Messaging"])
class BotChatView(APIView):
    """
    Chat with the FitTech AI bot over plain HTTP (used by the mobile member
    app, which does not have a WebSocket transport).

    POST /api/messaging/bot/
    Body: {"message": "<user text>"}
    Returns: {"reply": "<assistant text>", "created_at": iso8601}
    """
    permission_classes = [permissions.AllowAny]
    authentication_classes = []

    @extend_schema(tags=["Messaging"])
    def post(self, request):
        try:
            user, _ = _resolve_user(request)
        except AuthenticationFailed as exc:
            return Response({'detail': str(exc)}, status=status.HTTP_401_UNAUTHORIZED)

        if not isinstance(user, Member):
            return Response(
                {'error': 'Only members can chat with the FitTech AI bot.'},
                status=status.HTTP_403_FORBIDDEN,
            )

        message = (request.data.get('message') or '').strip()
        if not message:
            return Response(
                {'error': 'Message must not be empty.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        from nutrition.models import (
            NutritionChat,
            NutritionMessage,
            NutritionProfile,
        )
        from nutrition.services import NutritionChatbotService

        chat, _created = NutritionChat.objects.get_or_create(
            member=user,
            title='FitTech AI Chat',
        )

        # Persist the user's message first.
        NutritionMessage.objects.create(chat=chat, role='user', content=message)

        # Build conversation history (everything except the message we just
        # saved, capped at the last 20 turns).
        history_qs = list(
            NutritionMessage.objects.filter(chat=chat).order_by('created_at')
        )
        history = [
            {'role': msg.role, 'content': msg.content}
            for msg in history_qs[:-1]
        ][-20:]

        # Build user profile context if available.
        try:
            profile = NutritionProfile.objects.get(member=user)
            user_profile = {
                'age': profile.age,
                'fitness_goal': getattr(user, 'fitness_goal', ''),
                'dietary_preference': profile.dietary_preference,
                'allergies': profile.allergies,
                'medical_conditions': profile.medical_conditions,
                'nutrition_goals': profile.nutrition_goals,
            }
        except NutritionProfile.DoesNotExist:
            user_profile = {'fitness_goal': getattr(user, 'fitness_goal', '')}

        result = NutritionChatbotService().get_nutrition_advice(
            message, history, user_profile,
        )
        bot_text = result.get(
            'message',
            "Sorry, I couldn't process your question right now.",
        )

        bot_msg = NutritionMessage.objects.create(
            chat=chat,
            role='assistant',
            content=bot_text,
            tokens_used=result.get('tokens_used', 0),
        )

        return Response({
            'reply': bot_text,
            'created_at': bot_msg.created_at.isoformat(),
            'chat_id': str(chat.id),
        })


@extend_schema(tags=["Messaging"])
class NutritionBotHistoryView(APIView):
    """
    Return the FitTech AI bot conversation history for the current member.
    The frontend can call this endpoint to pre-fill the chat window before
    the WebSocket connection is established.

    GET /api/messaging/bot-history/
    """
    permission_classes = [permissions.AllowAny]
    authentication_classes = []

    @extend_schema(tags=["Messaging"])
    def get(self, request):
        from nutrition.models import NutritionChat, NutritionMessage

        try:
            user, _ = _resolve_user(request)
        except AuthenticationFailed as exc:
            return Response({'detail': str(exc)}, status=status.HTTP_401_UNAUTHORIZED)

        # Only Members have nutrition chats
        if not isinstance(user, Member):
            return Response(
                {'error': 'Only members can access the nutrition bot.'},
                status=status.HTTP_403_FORBIDDEN,
            )

        # Get the most-recent FitTech AI session (auto-created on first message)
        chat = (
            NutritionChat.objects
            .filter(member=user, title='FitTech AI Chat')
            .order_by('-updated_at')
            .first()
        )

        if not chat:
            return Response({'messages': [], 'chat_id': None})

        messages = NutritionMessage.objects.filter(chat=chat).order_by('created_at')
        data = [
            {
                'id': str(msg.id),
                'role': msg.role,
                'sender_name': 'FitTech AI \U0001f916' if msg.role == 'assistant' else user.get_full_name(),
                'sender_id': 'nutrition-bot' if msg.role == 'assistant' else str(user.id),
                'content': msg.content,
                'created_at': msg.created_at.isoformat(),
                'is_bot': msg.role == 'assistant',
            }
            for msg in messages
        ]

        return Response({'chat_id': str(chat.id), 'messages': data})
