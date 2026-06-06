from django.db import models
from django.conf import settings


class SubscriptionPlan(models.Model):
    PLAN_TYPES = [
        ('monthly', 'Monthly'),
        ('annual', 'Annual'),
        ('per_session', 'Per Session'),
        ('free_trial', 'Free Trial'),
    ]

    name = models.CharField(max_length=100)
    plan_type = models.CharField(max_length=20, choices=PLAN_TYPES)
    price = models.DecimalField(max_digits=10, decimal_places=2)
    times_per_week = models.IntegerField(
        default=7,
        help_text='How many sessions per week allowed'
    )
    duration_days = models.IntegerField(null=True, blank=True)
    session_count = models.IntegerField(null=True, blank=True)
    is_active = models.BooleanField(default=True)
    is_featured = models.BooleanField(default=False)
    description = models.TextField(blank=True)
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True, blank=True,
        related_name='created_plans',
    )
    updated_at = models.DateTimeField(auto_now=True)
    created_at = models.DateTimeField(auto_now_add=True)


    def __str__(self):
        return f'{self.name} - {self.plan_type}'


class Subscription(models.Model):
    STATUS_CHOICES = [
        ('active', 'Active'),
        ('expired', 'Expired'),
        ('paused', 'Paused'),
        ('cancelled', 'Cancelled'),
    ]

    user = models.ForeignKey(
        'users.Member',
        on_delete=models.CASCADE,
        related_name='subscriptions'
    )
    plan = models.ForeignKey(
        SubscriptionPlan,
        on_delete=models.PROTECT,
        related_name='subscriptions'
    )
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='active')
    start_date = models.DateField()
    end_date = models.DateField(null=True, blank=True)
    sessions_remaining = models.IntegerField(null=True, blank=True)

    # Pause
    pause_start_date = models.DateField(null=True, blank=True)
    pause_end_date = models.DateField(null=True, blank=True)
    total_pause_days_used = models.IntegerField(default=0)

    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f'{self.user.get_full_name()} - {self.plan.name}'

    def is_active(self):
        from django.utils import timezone
        today = timezone.now().date()
        return self.status == 'active' and (
            self.end_date is None or self.end_date >= today
        )

    def can_pause(self):
        return self.total_pause_days_used < 60 and self.status == 'active'


class Payment(models.Model):
    PAYMENT_METHODS = [
        ('card', 'Card'),
        ('mobile', 'Mobile Payment'),
        ('cash', 'Cash'),
    ]

    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('completed', 'Completed'),
        ('failed', 'Failed'),
        ('refunded', 'Refunded'),
    ]

    subscription = models.ForeignKey(
        Subscription,
        on_delete=models.CASCADE,
        related_name='payments'
    )
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    payment_method = models.CharField(max_length=20, choices=PAYMENT_METHODS)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    transaction_id = models.CharField(max_length=100, blank=True)
    paid_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f'Payment {self.transaction_id} - {self.status}'


class Invoice(models.Model):
    payment = models.OneToOneField(
        Payment,
        on_delete=models.CASCADE,
        related_name='invoice'
    )
    invoice_number = models.CharField(max_length=50, unique=True)
    issued_at = models.DateTimeField(auto_now_add=True)
    pdf_file = models.FileField(upload_to='invoices/', blank=True, null=True)

    def __str__(self):
        return f'Invoice {self.invoice_number}'