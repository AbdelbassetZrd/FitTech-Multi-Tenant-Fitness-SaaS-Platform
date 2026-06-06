from django.contrib import admin
from .models import NutritionProfile, NutritionChat, NutritionMessage


@admin.register(NutritionProfile)
class NutritionProfileAdmin(admin.ModelAdmin):
    list_display = (
        'member_email', 'height_cm', 'weight_kg', 'activity_level',
        'dietary_preference', 'created_at'
    )
    list_filter = ('dietary_preference', 'activity_level', 'created_at')
    search_fields = ('member__email', 'member__first_name', 'member__last_name')
    readonly_fields = ('created_at', 'updated_at')
    
    fieldsets = (
        ('Member Info', {
            'fields': ('member',)
        }),
        ('Physical Metrics', {
            'fields': ('height_cm', 'weight_kg', 'age', 'activity_level')
        }),
        ('Dietary Preferences', {
            'fields': ('dietary_preference', 'allergies', 'dislikes')
        }),
        ('Goals & Targets', {
            'fields': (
                'nutrition_goals', 'target_daily_calories', 'target_daily_protein_g'
            )
        }),
        ('Medical Information', {
            'fields': ('medical_conditions', 'supplements_taken'),
            'classes': ('collapse',)
        }),
        ('Timestamps', {
            'fields': ('created_at', 'updated_at'),
            'classes': ('collapse',)
        }),
    )
    
    def member_email(self, obj):
        return obj.member.email
    member_email.short_description = 'Member Email'


@admin.register(NutritionChat)
class NutritionChatAdmin(admin.ModelAdmin):
    list_display = ('title', 'member_email', 'message_count', 'created_at', 'updated_at')
    list_filter = ('created_at', 'updated_at')
    search_fields = ('member__email', 'title')
    readonly_fields = ('created_at', 'updated_at', 'member')
    
    fieldsets = (
        ('Chat Info', {
            'fields': ('member', 'title')
        }),
        ('Timestamps', {
            'fields': ('created_at', 'updated_at'),
            'classes': ('collapse',)
        }),
    )
    
    def member_email(self, obj):
        return obj.member.email
    member_email.short_description = 'Member'
    
    def message_count(self, obj):
        return obj.messages.count()
    message_count.short_description = 'Messages'


@admin.register(NutritionMessage)
class NutritionMessageAdmin(admin.ModelAdmin):
    list_display = ('chat_title', 'role', 'content_preview', 'created_at')
    list_filter = ('role', 'created_at')
    search_fields = ('chat__member__email', 'content')
    readonly_fields = ('created_at', 'chat')
    
    fieldsets = (
        ('Message Info', {
            'fields': ('chat', 'role')
        }),
        ('Content', {
            'fields': ('content',)
        }),
        ('Metadata', {
            'fields': ('tokens_used', 'created_at'),
            'classes': ('collapse',)
        }),
    )
    
    def chat_title(self, obj):
        return obj.chat.title
    chat_title.short_description = 'Chat'
    
    def content_preview(self, obj):
        return obj.content[:100] + ('...' if len(obj.content) > 100 else '')
    content_preview.short_description = 'Content'
