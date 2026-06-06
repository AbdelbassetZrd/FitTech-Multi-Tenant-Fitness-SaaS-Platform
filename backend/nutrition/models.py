from django.db import models
from django.contrib.contenttypes.fields import GenericForeignKey
from django.contrib.contenttypes.models import ContentType
from users.models import Member
import uuid


def generate_chat_id():
    return str(uuid.uuid4())


class NutritionProfile(models.Model):
    """Stores personalized nutrition profile for members"""
    
    DIETARY_PREFERENCES = [
        ('omnivore', 'Omnivore'),
        ('vegetarian', 'Vegetarian'),
        ('vegan', 'Vegan'),
        ('pescatarian', 'Pescatarian'),
        ('keto', 'Keto'),
        ('paleo', 'Paleo'),
        ('low_carb', 'Low Carb'),
    ]

    ACTIVITY_LEVELS = [
        ('sedentary', 'Sedentary'),
        ('light', 'Lightly Active'),
        ('moderate', 'Moderately Active'),
        ('very_active', 'Very Active'),
        ('extremely_active', 'Extremely Active'),
    ]

    id = models.CharField(
        max_length=36, primary_key=True,
        default=generate_chat_id, editable=False
    )
    member = models.OneToOneField(
        Member,
        on_delete=models.CASCADE,
        related_name='nutrition_profile'
    )
    
    # Basic health metrics
    height_cm = models.FloatField(null=True, blank=True, help_text="Height in cm")
    weight_kg = models.FloatField(null=True, blank=True, help_text="Weight in kg")
    age = models.IntegerField(null=True, blank=True)
    activity_level = models.CharField(
        max_length=20,
        choices=ACTIVITY_LEVELS,
        default='moderate'
    )
    
    # Dietary preferences
    dietary_preference = models.CharField(
        max_length=20,
        choices=DIETARY_PREFERENCES,
        default='omnivore'
    )
    allergies = models.TextField(
        blank=True,
        help_text="Comma-separated list of food allergies"
    )
    dislikes = models.TextField(
        blank=True,
        help_text="Foods the member dislikes"
    )
    
    # Goals
    nutrition_goals = models.TextField(
        blank=True,
        help_text="e.g., 'lose 5kg', 'gain muscle', 'improve energy'"
    )
    target_daily_calories = models.IntegerField(
        null=True,
        blank=True,
        help_text="Target daily calorie intake"
    )
    target_daily_protein_g = models.FloatField(
        null=True,
        blank=True,
        help_text="Target daily protein in grams"
    )
    
    # Medical/dietary restrictions
    medical_conditions = models.TextField(
        blank=True,
        help_text="e.g., 'diabetes', 'hypertension', 'lactose intolerant'"
    )
    supplements_taken = models.TextField(
        blank=True,
        help_text="Current supplements or medications"
    )
    
    updated_at = models.DateTimeField(auto_now=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'nutrition_profiles'

    def __str__(self):
        return f"Nutrition Profile - {self.member.first_name} {self.member.last_name}"


class NutritionChat(models.Model):
    """Stores nutrition chatbot conversations"""
    
    id = models.CharField(
        max_length=36, primary_key=True,
        default=generate_chat_id, editable=False
    )
    member = models.ForeignKey(
        Member,
        on_delete=models.CASCADE,
        related_name='nutrition_chats'
    )
    title = models.CharField(max_length=255, blank=True)
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'nutrition_chats'
        ordering = ['-updated_at']

    def __str__(self):
        return f"Chat - {self.member.email} - {self.created_at}"


class NutritionMessage(models.Model):
    """Individual messages in a nutrition chat conversation"""
    
    ROLE_CHOICES = [
        ('user', 'User'),
        ('assistant', 'Assistant'),
    ]

    id = models.CharField(
        max_length=36, primary_key=True,
        default=generate_chat_id, editable=False
    )
    chat = models.ForeignKey(
        NutritionChat,
        on_delete=models.CASCADE,
        related_name='messages'
    )
    role = models.CharField(max_length=10, choices=ROLE_CHOICES)
    content = models.TextField()
    
    # Optional: Store metadata about the response
    tokens_used = models.IntegerField(null=True, blank=True)
    
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'nutrition_messages'
        ordering = ['created_at']

    def __str__(self):
        return f"{self.role} - {self.created_at}"
