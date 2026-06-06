from rest_framework import serializers
from .models import SubscriptionPlan, Subscription, Payment, Invoice


# ─── Subscription Plans ───────────────────────────────────────────────────────

class SubscriptionPlanSerializer(serializers.ModelSerializer):
    """Read-only — used by members to browse available plans."""
    created_by_name = serializers.ReadOnlyField(source='created_by.get_full_name')

    class Meta:
        model = SubscriptionPlan
        fields = (
            'id', 'name', 'plan_type', 'price',
            'times_per_week', 'duration_days', 'session_count',
            'description', 'is_active', 'is_featured',
            'created_by_name',
        )
        read_only_fields = fields


class SubscriptionPlanAdminSerializer(serializers.ModelSerializer):
    """Full access — used by admin to create and edit plans."""

    class Meta:
        model = SubscriptionPlan
        fields = (
            'id', 'name', 'plan_type', 'price',
            'times_per_week', 'duration_days', 'session_count',
            'description', 'is_active', 'is_featured',
        )

    def validate_price(self, value):
        if value <= 0:
            raise serializers.ValidationError('Price must be greater than 0.')
        return value

    def validate_times_per_week(self, value):
        if value < 1 or value > 7:
            raise serializers.ValidationError(
                'Times per week must be between 1 and 7.'
            )
        return value

    def validate_duration_days(self, value):
        if value is not None and value <= 0:
            raise serializers.ValidationError(
                'Duration must be greater than 0.'
            )
        return value

    def validate(self, attrs):
        plan_type = attrs.get('plan_type')
        duration_days = attrs.get('duration_days')
        session_count = attrs.get('session_count')

        if plan_type in ('monthly', 'annual', 'free_trial') and not duration_days:
            raise serializers.ValidationError(
                {'duration_days': 'Duration is required for this plan type.'}
            )
        if plan_type == 'per_session' and not session_count:
            raise serializers.ValidationError(
                {'session_count': 'Session count is required for per session plans.'}
            )
        return attrs


# ─── Subscriptions ────────────────────────────────────────────────────────────

class SubscriptionSerializer(serializers.ModelSerializer):
    # Nested plan details when reading
    plan = SubscriptionPlanSerializer(read_only=True)

    # Only ID needed when writing (subscribing)
    plan_id = serializers.PrimaryKeyRelatedField(
        queryset=SubscriptionPlan.objects.filter(is_active=True),
        source='plan',
        write_only=True,
    )

    user_name = serializers.ReadOnlyField(source='user.get_full_name')
    is_currently_active = serializers.SerializerMethodField()
    can_pause = serializers.SerializerMethodField()
    pause_days_remaining = serializers.SerializerMethodField()

    class Meta:
        model = Subscription
        fields = (
            'id', 'user_name', 'plan', 'plan_id',
            'status', 'start_date', 'end_date',
            'sessions_remaining',
            'pause_start_date', 'pause_end_date',
            'total_pause_days_used', 'pause_days_remaining',
            'is_currently_active', 'can_pause',
            'created_at',
        )
        read_only_fields = (
            'id', 'user_name', 'status',
            'start_date', 'end_date',
            'sessions_remaining', 'total_pause_days_used',
            'created_at',
        )

    def get_is_currently_active(self, obj):
        return obj.is_active()

    def get_can_pause(self, obj):
        return obj.can_pause()

    def get_pause_days_remaining(self, obj):
        return max(0, 60 - obj.total_pause_days_used)


# ─── Payments ─────────────────────────────────────────────────────────────────

class PaymentSerializer(serializers.ModelSerializer):
    subscription_plan = serializers.ReadOnlyField(
        source='subscription.plan.name'
    )
    member_name = serializers.ReadOnlyField(
        source='subscription.user.get_full_name'
    )
    has_invoice = serializers.SerializerMethodField()

    class Meta:
        model = Payment
        fields = (
            'id', 'subscription', 'subscription_plan',
            'member_name', 'amount', 'payment_method',
            'status', 'transaction_id',
            'paid_at', 'created_at', 'has_invoice',
        )
        read_only_fields = (
            'id', 'subscription', 'subscription_plan',
            'member_name', 'amount', 'status',
            'transaction_id', 'paid_at', 'created_at',
        )

    def get_has_invoice(self, obj):
        return hasattr(obj, 'invoice')


class PaymentCreateSerializer(serializers.Serializer):
    """Only needs payment method — everything else is auto-filled."""
    payment_method = serializers.ChoiceField(
        choices=['card', 'mobile', 'cash']
    )


# ─── Invoices ─────────────────────────────────────────────────────────────────

class InvoiceSerializer(serializers.ModelSerializer):
    """
    Invoice = official receipt after a payment.
    Contains payment details + a unique invoice number + optional PDF.
    Members download this as proof of payment.
    """
    payment_amount = serializers.ReadOnlyField(source='payment.amount')
    payment_method = serializers.ReadOnlyField(source='payment.payment_method')
    payment_status = serializers.ReadOnlyField(source='payment.status')
    plan_name = serializers.ReadOnlyField(source='payment.subscription.plan.name')
    member_name = serializers.ReadOnlyField(
        source='payment.subscription.user.get_full_name'
    )
    member_email = serializers.ReadOnlyField(
        source='payment.subscription.user.email'
    )

    class Meta:
        model = Invoice
        fields = (
            'id', 'invoice_number',
            'member_name', 'member_email',
            'plan_name', 'payment_amount',
            'payment_method', 'payment_status',
            'pdf_file', 'issued_at',
        )
        read_only_fields = fields