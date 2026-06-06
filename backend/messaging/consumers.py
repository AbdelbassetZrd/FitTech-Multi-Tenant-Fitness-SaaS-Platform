import json
from channels.generic.websocket import AsyncWebsocketConsumer
from channels.db import database_sync_to_async
from .models import DirectMessage
from django.contrib.auth import get_user_model

User = get_user_model()

# Fixed ID used for the FitTech AI bot contact
NUTRITION_BOT_ID = 'nutrition-bot'
NUTRITION_BOT_NAME = 'FitTech AI 🤖'


class ChatConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        raw_target_id = self.scope['url_route']['kwargs']['room_name']
        self.target_id = str(raw_target_id).strip().lower()

        # Cap non-bot IDs to standard UUID length
        if self.target_id != NUTRITION_BOT_ID:
            self.target_id = self.target_id[:36]

        self.user = self.scope.get('user')

        if not self.user or not self.user.is_authenticated:
            await self.close()
            return

        # Determine if this is a bot chat session
        self.is_bot_chat = (self.target_id == NUTRITION_BOT_ID)

        # Create deterministic room name
        user_id = str(self.user.id).strip().lower()[:36]
        if self.is_bot_chat:
            self.room_group_name = f'bot_chat_{user_id}'
        else:
            ids = sorted([user_id, self.target_id])
            self.room_group_name = f'private_chat_{ids[0]}_{ids[1]}'

        # Join room group
        await self.channel_layer.group_add(
            self.room_group_name,
            self.channel_name
        )
        await self.accept()

        # Load and send chat history
        if self.is_bot_chat:
            history = await self.get_bot_chat_history()
        else:
            history = await self.get_chat_history()

        for msg in history:
            await self.send(text_data=json.dumps(msg))

        # Send connected notice
        await self.send(text_data=json.dumps({
            'sender_name': 'System',
            'sender_id': 'system',
            'message': f'Connected to {"FitTech AI 🤖" if self.is_bot_chat else "chat"}. Ready!',
            'created_at': 'Now',
            'is_bot': False,
        }))

    # ── Bot chat history ───────────────────────────────────────────────────────

    @database_sync_to_async
    def get_bot_chat_history(self):
        """Fetch the last 50 nutrition bot messages for this user."""
        from nutrition.models import NutritionChat, NutritionMessage
        # Find the most recent NutritionChat for this member
        from users.models import Member
        try:
            member = Member.objects.get(id=self.user.id)
        except Member.DoesNotExist:
            return []

        chats = NutritionChat.objects.filter(member=member).order_by('-updated_at')
        if not chats.exists():
            return []

        # Collect messages from the latest chat
        latest_chat = chats.first()
        messages = NutritionMessage.objects.filter(chat=latest_chat).order_by('created_at')[:50]

        result = []
        for msg in messages:
            result.append({
                'message': msg.content,
                'sender_name': NUTRITION_BOT_NAME if msg.role == 'assistant' else self.user.get_full_name(),
                'sender_id': NUTRITION_BOT_ID if msg.role == 'assistant' else str(self.user.id),
                'created_at': msg.created_at.isoformat(),
                'is_bot': msg.role == 'assistant',
            })
        return result

    # ── Regular chat history ───────────────────────────────────────────────────

    @database_sync_to_async
    def get_chat_history(self):
        from users.models import Member, Coach, CustomUser
        from django.contrib.contenttypes.models import ContentType
        from django.db.models import Q

        user_type = ContentType.objects.get_for_model(self.user)

        target_obj = None
        for model in [Member, Coach, CustomUser]:
            try:
                target_obj = model.objects.get(id=self.target_id)
                break
            except model.DoesNotExist:
                continue

        if not target_obj:
            return []

        target_type = ContentType.objects.get_for_model(target_obj)

        messages = DirectMessage.objects.filter(
            (Q(sender_type=user_type, sender_id=self.user.id) & Q(recipient_type=target_type, recipient_id=self.target_id)) |
            (Q(sender_type=target_type, sender_id=self.target_id) & Q(recipient_type=user_type, recipient_id=self.user.id))
        ).order_by('created_at')[:50]

        DirectMessage.objects.filter(
            recipient_type=user_type,
            recipient_id=self.user.id,
            sender_type=target_type,
            sender_id=self.target_id,
            is_read=False
        ).update(is_read=True)

        return [
            {
                'message': msg.content,
                'sender_name': msg.sender.get_full_name() if msg.sender else 'Unknown',
                'sender_id': str(msg.sender_id),
                'created_at': msg.created_at.isoformat(),
                'is_bot': False,
            }
            for msg in messages
        ]

    # ── Disconnect ─────────────────────────────────────────────────────────────

    async def disconnect(self, close_code):
        if hasattr(self, 'room_group_name'):
            await self.channel_layer.group_discard(
                self.room_group_name,
                self.channel_name
            )

    # ── Receive from WebSocket ─────────────────────────────────────────────────

    async def receive(self, text_data):
        data = json.loads(text_data)
        message_content = data.get('message', '').strip()
        recipient_id = data.get('recipient_id', self.target_id)

        if not message_content:
            return

        if self.is_bot_chat:
            await self._handle_bot_message(message_content)
        else:
            await self._handle_regular_message(message_content, recipient_id)

    # ── Bot message flow ───────────────────────────────────────────────────────

    async def _handle_bot_message(self, user_message: str):
        """Save user message, call NutritionChatbotService, broadcast both."""
        from django.utils import timezone

        # Echo user's own message back to room
        await self.channel_layer.group_send(
            self.room_group_name,
            {
                'type': 'chat_message',
                'message': user_message,
                'sender_id': str(self.user.id),
                'sender_name': self.user.get_full_name(),
                'created_at': timezone.now().isoformat(),
                'is_bot': False,
            }
        )

        # Get AI response and save to NutritionChat
        bot_response = await self.get_bot_response(user_message)

        # Send bot reply to room
        await self.channel_layer.group_send(
            self.room_group_name,
            {
                'type': 'chat_message',
                'message': bot_response,
                'sender_id': NUTRITION_BOT_ID,
                'sender_name': NUTRITION_BOT_NAME,
                'created_at': timezone.now().isoformat(),
                'is_bot': True,
            }
        )

    @database_sync_to_async
    def get_bot_response(self, user_message: str) -> str:
        """
        Call the AI service and return the response text.

        For Member users the full flow is used: conversation history is persisted
        to NutritionChat/NutritionMessage and the member's nutrition profile is
        passed as context so the AI can give personalised advice.

        For Admin / Coach users (who are not Member instances) the AI is still
        called, but without persistent history or member-specific context.
        """
        from nutrition.services import NutritionChatbotService
        from users.models import Member

        service = NutritionChatbotService()

        # ── Member path: persist history + use nutrition profile ──────────────
        try:
            member = Member.objects.get(id=self.user.id)
        except Member.DoesNotExist:
            # Admin / Coach — call AI with no history and no member context
            result = service.get_nutrition_advice(user_message, [], {})
            return result.get('message', 'Sorry, I could not process your question right now.')

        from nutrition.models import NutritionChat, NutritionMessage, NutritionProfile

        # Get or create the persistent bot chat session for this member
        chat, _ = NutritionChat.objects.get_or_create(
            member=member,
            title='FitTech AI Chat',
        )

        # Save the user message
        NutritionMessage.objects.create(chat=chat, role='user', content=user_message)

        # Build conversation history — exclude the message just saved (the last one).
        # Convert QuerySet to list first because Django doesn't support negative indexing.
        history_list = list(
            NutritionMessage.objects.filter(chat=chat).order_by('created_at')
        )
        history = [
            {'role': msg.role, 'content': msg.content}
            for msg in history_list[:-1]  # all except the user message just saved
        ][-20:]  # keep at most last 20 entries for context

        # Build user profile context
        try:
            profile = NutritionProfile.objects.get(member=member)
            user_profile = {
                'age': profile.age,
                'fitness_goal': member.fitness_goal,
                'dietary_preference': profile.dietary_preference,
                'allergies': profile.allergies,
                'medical_conditions': profile.medical_conditions,
                'nutrition_goals': profile.nutrition_goals,
            }
        except NutritionProfile.DoesNotExist:
            user_profile = {'fitness_goal': getattr(member, 'fitness_goal', '')}

        result = service.get_nutrition_advice(user_message, history, user_profile)
        bot_text = result.get('message', 'Sorry, I could not process your question right now.')

        # Persist the bot reply
        NutritionMessage.objects.create(
            chat=chat,
            role='assistant',
            content=bot_text,
            tokens_used=result.get('tokens_used', 0),
        )

        return bot_text

    # ── Regular message flow ───────────────────────────────────────────────────

    async def _handle_regular_message(self, message_content: str, recipient_id: str):
        saved_message = await self.save_message(self.user, recipient_id, message_content)

        if saved_message:
            await self.channel_layer.group_send(
                self.room_group_name,
                {
                    'type': 'chat_message',
                    'id': saved_message.id,
                    'message': message_content,
                    'sender_id': str(self.user.id),
                    'sender_name': f'{self.user.first_name} {self.user.last_name}',
                    'recipient_id': recipient_id,
                    'created_at': saved_message.created_at.isoformat(),
                    'is_bot': False,
                }
            )

    # ── Group message handler ──────────────────────────────────────────────────

    async def chat_message(self, event):
        payload = {
            'message': event['message'],
            'sender_id': event['sender_id'],
            'sender_name': event['sender_name'],
            'created_at': event['created_at'],
            'is_bot': event.get('is_bot', False),
        }
        # Include id and recipient_id when present so Flutter can dedup
        # WS echoes against messages already added via the REST response.
        if 'id' in event:
            payload['id'] = event['id']
        if 'recipient_id' in event:
            payload['recipient_id'] = event['recipient_id']
        await self.send(text_data=json.dumps(payload))

    # ── DB helpers ─────────────────────────────────────────────────────────────

    @database_sync_to_async
    def save_message(self, sender, recipient_id, content):
        from users.models import Member, Coach, CustomUser

        recipient = None
        for model in [Member, Coach, CustomUser]:
            try:
                recipient = model.objects.get(id=recipient_id)
                break
            except model.DoesNotExist:
                continue

        if not recipient:
            print(f'Recipient {recipient_id} not found in any model.')
            return None

        return DirectMessage.objects.create(
            sender=sender,
            recipient=recipient,
            content=content
        )
