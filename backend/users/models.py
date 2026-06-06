from django.db import models
from django.contrib.auth.models import AbstractUser, BaseUserManager
import uuid
from django.utils import timezone
from django.conf import settings
from datetime import timedelta
import random



def generate_user_id():
    return str(uuid.uuid4())


# ─── User Manager ────────────────────────────────────────────────────────────

class CustomUserManager(BaseUserManager):
    def create_user(self, email, password=None, **extra_fields):
        if not email:
            raise ValueError('Email is required')
        email = self.normalize_email(email)
        user = self.model(email=email, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, email, password=None, **extra_fields):
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)
        return self.create_user(email, password, **extra_fields)


# ─── Abstract Base User (Admin lives here via Django's default) ───────────────

class CustomUser(AbstractUser):
    """
    Admin accounts only. Members and Coaches have their own tables.
    """
    username = None
    id = models.CharField(
        max_length=36, primary_key=True,
        default=generate_user_id, editable=False
    )
    email = models.EmailField(unique=True)
    first_name = models.CharField(max_length=150)
    last_name = models.CharField(max_length=150)
    phone = models.CharField(max_length=20, blank=True)

    groups = models.ManyToManyField(
        'auth.Group', blank=True,
        related_name='customuser_set',
    )
    user_permissions = models.ManyToManyField(
        'auth.Permission', blank=True,
        related_name='customuser_set',
    )

    objects = CustomUserManager()

    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = ['first_name', 'last_name']

    class Meta:
        db_table = 'admins'

    def __str__(self):
        return f'{self.get_full_name()} ({self.email})'

    def get_full_name(self):
        return f'{self.first_name} {self.last_name}'


# ─── Member Table ─────────────────────────────────────────────────────────────

class Member(models.Model):
    
    FITNESS_GOALS = [
        ('weight_loss', 'Weight Loss'),
        ('muscle_gain', 'Muscle Gain'),
        ('endurance', 'Endurance'),
        ('flexibility', 'Flexibility'),
        ('general', 'General Fitness'),
    ]

    id = models.CharField(
        max_length=36, primary_key=True,
        default=generate_user_id, editable=False
    )
    email = models.EmailField(unique=True)
    password = models.CharField(max_length=128)
    first_name = models.CharField(max_length=150)
    last_name = models.CharField(max_length=150)
    phone = models.CharField(max_length=20, blank=True)
    date_of_birth = models.DateField(null=True, blank=True)
    photo = models.ImageField(upload_to='members/', blank=True, null=True)

    # Health profile (visible to coaches)
    fitness_goal = models.CharField(max_length=20, choices=FITNESS_GOALS, blank=True)
    medical_restrictions = models.TextField(blank=True)

    # Account state
    email_verified = models.BooleanField(default=False)
    is_active = models.BooleanField(default=True)
    is_suspended = models.BooleanField(default=False)
    suspension_end_date = models.DateField(null=True, blank=True)
    warnings_count = models.IntegerField(default=0)
    
    # Subscription
    has_active_subscription = models.BooleanField(
        default=False,
        help_text='Whether user has an active paid subscription'
    )

    # Password reset
    password_reset_token = models.CharField(max_length=64, blank=True)
    password_reset_expires = models.DateTimeField(null=True, blank=True)

    # OTP
    otp_code = models.CharField(max_length=6, blank=True)
    otp_expires = models.DateTimeField(null=True, blank=True)
    
    email_verification_token = models.CharField(max_length=64, blank=True)
    email_verification_expires = models.DateTimeField(null=True, blank=True)

    last_login = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'members'

    def __str__(self):
        return f'{self.get_full_name()} ({self.email})'

    def get_full_name(self):
        return f'{self.first_name} {self.last_name}'

    def check_password(self, raw_password):
        from django.contrib.auth.hashers import check_password
        return check_password(raw_password, self.password)

    def set_password(self, raw_password):
        from django.contrib.auth.hashers import make_password
        self.password = make_password(raw_password)

    def is_suspension_active(self):
        if self.is_suspended and self.suspension_end_date:
            return self.suspension_end_date >= timezone.now().date()
        return False

    def save(self, *args, **kwargs):
        if not self.pk:
            self.id = generate_user_id()
        super().save(*args, **kwargs)


class MemberProfile(models.Model):
    member = models.OneToOneField(
        Member, on_delete=models.CASCADE, related_name='profile'
    )
    bio = models.TextField(blank=True, max_length=500)
    is_newsletter_subscribed = models.BooleanField(default=False)
    is_profile_complete = models.BooleanField(default=False)
    profile_completion_percentage = models.IntegerField(default=0)

    class Meta:
        db_table = 'member_profiles'

    def __str__(self):
        return f'{self.member.get_full_name()} Profile'

    def calculate_completion_percentage(self):
        fields = [
            self.member.first_name,
            self.member.last_name,
            self.member.email,
            self.member.phone,
            self.member.date_of_birth,
            self.member.photo,
            self.bio,
        ]
        filled = sum(1 for f in fields if f)
        pct = int((filled / len(fields)) * 100)
        self.profile_completion_percentage = pct
        self.is_profile_complete = pct == 100
        self.save()


# ─── Coach Table ──────────────────────────────────────────────────────────────

class Coach(models.Model):
    SPECIALITY_CHOICES = [
        ('crossfit', 'CrossFit'),
        ('yoga', 'Yoga'),
        ('spinning', 'Spinning'),
        ('pilates', 'Pilates'),
        ('cardio', 'Cardio'),
        ('strength', 'Strength Training'),
        ('nutrition', 'Nutrition'),
        ('other', 'Other'),
    ]

    id = models.CharField(
        max_length=36, primary_key=True,
        default=generate_user_id, editable=False
    )
    # Coach account is created by admin — admin is the FK
    created_by = models.ForeignKey(
        CustomUser, on_delete=models.SET_NULL,
        null=True, related_name='created_coaches'
    )

    email = models.EmailField(unique=True)
    password = models.CharField(max_length=128)
    first_name = models.CharField(max_length=150)
    last_name = models.CharField(max_length=150)
    phone = models.CharField(max_length=20, blank=True)
    photo = models.ImageField(upload_to='coaches/', blank=True, null=True)
    specialities = models.CharField(max_length=100, choices=SPECIALITY_CHOICES, blank=True)
    bio = models.TextField(blank=True)
    years_of_experience = models.PositiveIntegerField(default=0)

    # Account state
    is_active = models.BooleanField(default=True)
    is_available = models.BooleanField(default=True)

    # Password reset
    password_reset_token = models.CharField(max_length=64, blank=True)
    password_reset_expires = models.DateTimeField(null=True, blank=True)

    last_login = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'coaches'

    def __str__(self):
        return f'Coach {self.get_full_name()} ({self.email})'

    def get_full_name(self):
        return f'{self.first_name} {self.last_name}'

    def check_password(self, raw_password):
        from django.contrib.auth.hashers import check_password
        return check_password(raw_password, self.password)

    def set_password(self, raw_password):
        from django.contrib.auth.hashers import make_password
        self.password = make_password(raw_password)

    def is_suspension_active(self):
        return False  # Coaches are not suspended, only deactivated

    def save(self, *args, **kwargs):
        if not self.pk:
            self.id = generate_user_id()
        super().save(*args, **kwargs)
        

 
class OTPVerification(models.Model):
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='otp'
    )
    phone_number = models.CharField(max_length=20)
    otp_code = models.CharField(max_length=6)
    is_verified = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()

    def generate_otp(self):
        self.otp_code = str(random.randint(100000, 999999))
        self.expires_at = timezone.now() + timedelta(minutes=10)
        self.is_verified = False
        self.save()
        return self.otp_code

    def is_expired(self):
        return timezone.now() > self.expires_at

    def __str__(self):
        return f"{self.user} - {'Verified' if self.is_verified else 'Pending'}"
