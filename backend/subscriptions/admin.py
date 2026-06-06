from django.contrib import admin
from django.utils.html import format_html
from .models import SubscriptionPlan, Subscription, Payment, Invoice


# ─── Subscription Plan ────────────────────────────────────────────────────────

@admin.register(SubscriptionPlan)
class SubscriptionPlanAdmin(admin.ModelAdmin):
    list_display = (
        'name', 'plan_type', 'price_display',
        'times_per_week', 'duration_days',
        'is_active', 'is_featured', 'created_by', 'created_at',
    )
    list_filter = ('plan_type', 'is_active', 'is_featured')
    search_fields = ('name', 'description')
    list_editable = ('is_active', 'is_featured')
    readonly_fields = ('created_at', 'updated_at', 'created_by')
    fieldsets = (
        ('Basic Info', {
            'fields': ('name', 'plan_type', 'description', 'is_active', 'is_featured')
        }),
        ('Pricing & Duration', {
            'fields': ('price', 'times_per_week', 'duration_days', 'session_count')
        }),
        ('Meta', {
            'fields': ('created_by', 'created_at', 'updated_at'),
            'classes': ('collapse',),
        }),
    )

    def price_display(self, obj):
        return f'{obj.price} DZD'
    price_display.short_description = 'Price'

    def save_model(self, request, obj, form, change):
        if not change:
            obj.created_by = request.user
        super().save_model(request, obj, form, change)


# ─── Subscription ─────────────────────────────────────────────────────────────

@admin.register(Subscription)
class SubscriptionAdmin(admin.ModelAdmin):
    list_display = (
        'get_member_name', 'get_plan_name', 'status',
        'start_date', 'end_date', 'sessions_remaining',
        'total_pause_days_used', 'created_at',
    )
    list_filter = ('status', 'plan__plan_type')
    search_fields = (
        'user__first_name', 'user__last_name',
        'user__email', 'plan__name',
    )
    readonly_fields = ('created_at',)
    fieldsets = (
        ('Member & Plan', {
            'fields': ('user', 'plan', 'status')
        }),
        ('Dates', {
            'fields': ('start_date', 'end_date')
        }),
        ('Sessions', {
            'fields': ('sessions_remaining',)
        }),
        ('Pause Info', {
            'fields': (
                'pause_start_date', 'pause_end_date',
                'total_pause_days_used',
            ),
            'classes': ('collapse',),
        }),
        ('Meta', {
            'fields': ('created_at',),
            'classes': ('collapse',),
        }),
    )

    def get_member_name(self, obj):
        return obj.user.get_full_name()
    get_member_name.short_description = 'Member'

    def get_plan_name(self, obj):
        return obj.plan.name
    get_plan_name.short_description = 'Plan'


# ─── Payment ──────────────────────────────────────────────────────────────────

@admin.register(Payment)
class PaymentAdmin(admin.ModelAdmin):
    list_display = (
        'get_member_name', 'get_plan_name',
        'amount_display', 'payment_method',
        'status_badge', 'transaction_id',
        'paid_at', 'created_at',
    )
    list_filter = ('status', 'payment_method')
    search_fields = (
        'subscription__user__first_name',
        'subscription__user__last_name',
        'subscription__user__email',
        'transaction_id',
    )
    readonly_fields = ('created_at', 'paid_at', 'transaction_id')
    fieldsets = (
        ('Payment Info', {
            'fields': (
                'subscription', 'amount',
                'payment_method', 'status',
            )
        }),
        ('Transaction', {
            'fields': ('transaction_id', 'paid_at', 'created_at'),
            'classes': ('collapse',),
        }),
    )

    def get_member_name(self, obj):
        return obj.subscription.user.get_full_name()
    get_member_name.short_description = 'Member'

    def get_plan_name(self, obj):
        return obj.subscription.plan.name
    get_plan_name.short_description = 'Plan'

    def amount_display(self, obj):
        return f'{obj.amount} DZD'
    amount_display.short_description = 'Amount'

    def status_badge(self, obj):
        colors = {
            'completed': 'green',
            'pending': 'orange',
            'failed': 'red',
            'refunded': 'gray',
        }
        color = colors.get(obj.status, 'black')
        return format_html(
            '<span style="color: {}; font-weight: bold;">{}</span>',
            color,
            obj.status.upper(),
        )
    status_badge.short_description = 'Status'


# ─── Invoice ──────────────────────────────────────────────────────────────────

@admin.register(Invoice)
class InvoiceAdmin(admin.ModelAdmin):
    list_display = (
        'invoice_number', 'get_member_name',
        'get_plan_name', 'get_amount',
        'issued_at', 'has_pdf',
    )
    search_fields = (
        'invoice_number',
        'payment__subscription__user__first_name',
        'payment__subscription__user__last_name',
        'payment__subscription__user__email',
    )
    readonly_fields = ('invoice_number', 'issued_at')
    fieldsets = (
        ('Invoice Info', {
            'fields': ('payment', 'invoice_number', 'issued_at')
        }),
        ('File', {
            'fields': ('pdf_file',)
        }),
    )

    def get_member_name(self, obj):
        return obj.payment.subscription.user.get_full_name()
    get_member_name.short_description = 'Member'

    def get_plan_name(self, obj):
        return obj.payment.subscription.plan.name
    get_plan_name.short_description = 'Plan'

    def get_amount(self, obj):
        return f'{obj.payment.amount} DZD'
    get_amount.short_description = 'Amount'

    def has_pdf(self, obj):
        if obj.pdf_file:
            return format_html(
                '<a href="{}" target="_blank">Download</a>',
                obj.pdf_file.url
            )
        return 'No PDF'
    has_pdf.short_description = 'PDF'