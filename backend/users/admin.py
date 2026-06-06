from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from .models import CustomUser, Member, MemberProfile, Coach


@admin.register(CustomUser)
class CustomUserAdmin(UserAdmin):
    model = CustomUser
    list_display = ['email', 'first_name', 'last_name', 'is_staff', 'is_superuser']
    list_filter = ['is_staff', 'is_superuser', 'is_active']
    ordering = ['email']
    search_fields = ['email', 'first_name', 'last_name']
    fieldsets = (
        (None, {'fields': ('email', 'password')}),
        ('Personal info', {'fields': ('first_name', 'last_name', 'phone')}),
        ('Permissions', {'fields': ('is_active', 'is_staff', 'is_superuser', 'groups', 'user_permissions')}),
    )
    add_fieldsets = (
        (None, {
            'classes': ('wide',),
            'fields': ('email', 'first_name', 'last_name', 'password1', 'password2', 'is_staff', 'is_superuser'),
        }),
    )


class MemberProfileInline(admin.StackedInline):
    model = MemberProfile
    can_delete = False
    verbose_name_plural = 'Profile'


@admin.register(Member)
class MemberAdmin(admin.ModelAdmin):
    list_display = [
        'email', 'first_name', 'last_name',
        'email_verified', 'is_active', 'is_suspended',
        'warnings_count', 'created_at',
    ]
    list_filter = ['email_verified', 'is_active', 'is_suspended', 'fitness_goal']
    search_fields = ['email', 'first_name', 'last_name']
    ordering = ['-created_at']
    readonly_fields = ['id', 'created_at', 'updated_at', 'last_login']
    inlines = [MemberProfileInline]

    fieldsets = (
        ('Account', {'fields': ('id', 'email', 'password', 'email_verified', 'is_active')}),
        ('Personal info', {'fields': ('first_name', 'last_name', 'phone', 'date_of_birth', 'photo')}),
        ('Health profile', {'fields': ('fitness_goal', 'medical_restrictions')}),
        ('Suspension', {'fields': ('is_suspended', 'suspension_end_date', 'warnings_count')}),
        ('Timestamps', {'fields': ('last_login', 'created_at', 'updated_at')}),
    )

    def save_model(self, request, obj, form, change):
        """Hash password if it was changed in admin."""
        if 'password' in form.changed_data:
            obj.set_password(form.cleaned_data['password'])
        super().save_model(request, obj, form, change)


@admin.register(Coach)
class CoachAdmin(admin.ModelAdmin):
    list_display = [
        'email', 'first_name', 'last_name',
        'specialities', 'years_of_experience',
        'is_active', 'is_available', 'created_by', 'created_at',
    ]
    list_filter = ['is_active', 'is_available', 'specialities']
    search_fields = ['email', 'first_name', 'last_name']
    ordering = ['-created_at']
    readonly_fields = ['id', 'created_by', 'created_at', 'updated_at', 'last_login']

    fieldsets = (
        ('Account', {'fields': ('id', 'email', 'password', 'is_active', 'created_by')}),
        ('Personal info', {'fields': ('first_name', 'last_name', 'phone', 'photo')}),
        ('Professional info', {'fields': ('specialities', 'bio', 'years_of_experience', 'is_available')}),
        ('Timestamps', {'fields': ('last_login', 'created_at', 'updated_at')}),
    )

    def save_model(self, request, obj, form, change):
        if not change:
            obj.created_by = request.user
        if 'password' in form.changed_data:
            obj.set_password(form.cleaned_data['password'])
        super().save_model(request, obj, form, change)

    def has_add_permission(self, request):
        """Only admin (staff) can create coaches."""
        return request.user.is_staff

    def has_delete_permission(self, request, obj=None):
        return request.user.is_superuser