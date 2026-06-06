from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APIClient
from rest_framework import status
from datetime import timedelta

from users.models import Member, CustomUser
from subscriptions.models import Subscription, SubscriptionPlan
from nutrition.models import NutritionProfile, NutritionChat, NutritionMessage
from nutrition.services import NutritionChatbotService


# ─── Helpers ──────────────────────────────────────────────────────────────────

def create_member(email, **kwargs):
    """Create a Member with sensible defaults."""
    defaults = {
        'first_name': 'Test',
        'last_name': 'User',
        'fitness_goal': 'weight_loss',
    }
    defaults.update(kwargs)
    member = Member(email=email, **defaults)
    member.set_password('testpass123')
    member.save()
    return member


def create_custom_user(email, **kwargs):
    """Create a CustomUser (used as the FK target for Subscription.user)."""
    defaults = {'first_name': 'Test', 'last_name': 'User'}
    defaults.update(kwargs)
    return CustomUser.objects.create_user(email=email, password='testpass123', **defaults)


def create_plan(name='Test Plan', plan_type='monthly', price=9.99, is_active=True):
    return SubscriptionPlan.objects.create(
        name=name,
        plan_type=plan_type,
        price=price,
        is_active=is_active,
    )


def create_active_subscription(custom_user, plan):
    """
    Create an active Subscription linked to a CustomUser.
    Note: Subscription.user is a FK to CustomUser (admins table), NOT Member.
    """
    return Subscription.objects.create(
        user=custom_user,
        plan=plan,
        status='active',
        start_date=timezone.now().date(),
        end_date=timezone.now().date() + timedelta(days=30),
    )


# ─── Nutrition Profile Tests ──────────────────────────────────────────────────

class NutritionProfileTests(TestCase):

    def setUp(self):
        self.client = APIClient()

        # Create Member (authenticated user)
        self.member = create_member('test@nutrition.com')

        # Create a matching CustomUser with the same email so IsPaidMember can
        # find the subscription (Subscription.user FK → CustomUser/admins table)
        self.custom_user = create_custom_user('test@nutrition.com')

        # Create the subscription plan and link it to the CustomUser
        self.plan = create_plan('Premium Plan')
        self.subscription = create_active_subscription(self.custom_user, self.plan)

        # Create nutrition profile for the member
        self.profile = NutritionProfile.objects.create(
            member=self.member,
            height_cm=175,
            weight_kg=85,
            age=30,
            dietary_preference='omnivore',
            nutrition_goals='Lose 5kg',
            target_daily_calories=2000,
        )

    def test_get_nutrition_profile(self):
        """Test retrieving nutrition profile from the database."""
        profile = NutritionProfile.objects.get(member=self.member)
        self.assertEqual(profile.height_cm, 175)
        self.assertEqual(profile.dietary_preference, 'omnivore')
        self.assertEqual(profile.nutrition_goals, 'Lose 5kg')
        self.assertEqual(profile.target_daily_calories, 2000)

    def test_require_subscription(self):
        """Test that only members with active subscriptions can access chatbot."""
        # Create a member WITHOUT a CustomUser / subscription
        unsubscribed_member = create_member('unsubscribed@test.com')

        # No CustomUser with this email → no subscription
        subscriptions = Subscription.objects.filter(
            user__email=unsubscribed_member.email,
            status='active'
        )
        self.assertEqual(subscriptions.count(), 0)

    def test_subscribed_member_has_active_subscription(self):
        """Test that the subscribed member's subscription is found correctly."""
        # IsPaidMember looks up CustomUser by email then checks subscription
        active_sub = Subscription.objects.filter(
            user__email=self.member.email,
            status='active'
        ).first()
        self.assertIsNotNone(active_sub)
        self.assertEqual(active_sub.status, 'active')


# ─── Nutrition Chat Tests ──────────────────────────────────────────────────────

class NutritionChatTests(TestCase):

    def setUp(self):
        self.client = APIClient()

        # Create member + matching CustomUser (for subscription lookup)
        self.member = create_member('chat@test.com')
        self.custom_user = create_custom_user('chat@test.com')

        self.plan = create_plan('Chat Plan')
        self.subscription = create_active_subscription(self.custom_user, self.plan)

    def test_create_nutrition_chat(self):
        """Test creating a new nutrition chat."""
        chat = NutritionChat.objects.create(
            member=self.member,
            title='My First Nutrition Chat'
        )

        self.assertEqual(chat.member, self.member)
        self.assertEqual(chat.title, 'My First Nutrition Chat')
        self.assertTrue(chat.id)

    def test_add_message_to_chat(self):
        """Test adding user and assistant messages to a chat."""
        chat = NutritionChat.objects.create(
            member=self.member,
            title='Test Chat'
        )

        user_msg = NutritionMessage.objects.create(
            chat=chat,
            role='user',
            content='What should I eat for breakfast?'
        )

        assistant_msg = NutritionMessage.objects.create(
            chat=chat,
            role='assistant',
            content='A balanced breakfast should include protein, carbs, and healthy fats.'
        )

        self.assertEqual(chat.messages.count(), 2)
        self.assertEqual(user_msg.role, 'user')
        self.assertEqual(assistant_msg.role, 'assistant')

    def test_chat_ordered_by_created_at(self):
        """Messages should be in chronological order."""
        chat = NutritionChat.objects.create(member=self.member, title='Order Test')
        msg1 = NutritionMessage.objects.create(chat=chat, role='user', content='First')
        msg2 = NutritionMessage.objects.create(chat=chat, role='assistant', content='Second')

        messages = list(chat.messages.all())
        self.assertEqual(messages[0].id, msg1.id)
        self.assertEqual(messages[1].id, msg2.id)


# ─── Nutrition Service Tests ───────────────────────────────────────────────────

class NutritionServiceTests(TestCase):
    """Test the NutritionChatbotService (no API key required — uses fallback)."""

    def setUp(self):
        self.service = NutritionChatbotService()

    def test_fallback_response_no_api_key(self):
        """Without an API key the service returns a successful fallback response."""
        response = self.service.get_nutrition_advice(
            'What is a good meal plan?',
            [],
            {'fitness_goal': 'weight_loss'}
        )
        self.assertTrue(response['success'])
        self.assertIn('message', response)
        self.assertTrue(len(response['message']) > 0)

    def test_fallback_protein_keyword(self):
        """Protein keyword triggers the protein-specific fallback."""
        response = self.service.get_nutrition_advice('How much protein should I eat?', [], {})
        self.assertTrue(response['success'])
        self.assertIn('protein', response['message'].lower())

    def test_fallback_breakfast_keyword(self):
        """Breakfast keyword triggers the breakfast-specific fallback."""
        response = self.service.get_nutrition_advice('What should I eat for breakfast?', [], {})
        self.assertTrue(response['success'])
        self.assertIn('message', response)
        self.assertTrue(len(response['message']) > 0)

    def test_fallback_generic_response(self):
        """Unknown topic returns a generic helpful response."""
        response = self.service.get_nutrition_advice('Tell me about superfoods', [], {})
        self.assertTrue(response['success'])
        self.assertEqual(response['model'], 'fallback-mode')
        self.assertEqual(response['tokens_used'], 0)

    def test_system_prompt_includes_user_profile(self):
        """System message should include user profile details."""
        profile = {
            'age': 30,
            'fitness_goal': 'muscle_gain',
            'dietary_preference': 'vegan',
            'allergies': 'peanuts',
            'medical_conditions': '',
            'nutrition_goals': 'Build lean muscle',
        }
        system_msg = self.service._build_system_message(profile)
        self.assertIn('30', system_msg)
        self.assertIn('muscle_gain', system_msg)
        self.assertIn('vegan', system_msg)
        self.assertIn('peanuts', system_msg)
        self.assertIn('Build lean muscle', system_msg)
