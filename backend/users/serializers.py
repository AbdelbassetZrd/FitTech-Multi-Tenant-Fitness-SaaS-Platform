from rest_framework import serializers
from django.contrib.auth.hashers import make_password
from .models import Member, MemberProfile, Coach


# ─── Member Serializers ───────────────────────────────────────────────────────

class MemberRegistrationSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=8)
    # Accept both ``password2`` (Next.js frontend) and ``confirm_password``
    # (legacy/Flutter clients) so the same endpoint works for every caller.
    password2 = serializers.CharField(write_only=True, required=False)
    confirm_password = serializers.CharField(write_only=True, required=False)

    class Meta:
        model = Member
        fields = [
            'email', 'password', 'password2', 'confirm_password',
            'first_name', 'last_name', 'phone',
            'date_of_birth', 'fitness_goal', 'medical_restrictions',
        ]

    def validate(self, data):
        confirm = data.pop('password2', None) or data.pop('confirm_password', None)
        if confirm is None:
            raise serializers.ValidationError(
                {'password2': 'This field is required.'}
            )
        if data['password'] != confirm:
            raise serializers.ValidationError({'password2': 'Passwords do not match.'})
        return data

    def create(self, validated_data):
        validated_data['password'] = make_password(validated_data['password'])
        member = Member.objects.create(**validated_data)
        MemberProfile.objects.create(member=member)
        return member


class AdminMemberCreateSerializer(serializers.ModelSerializer):
    """Used by admin to create a member account directly (already verified)."""
    password = serializers.CharField(write_only=True, min_length=8)

    class Meta:
        model = Member
        fields = [
            'email', 'password', 'first_name', 'last_name',
            'phone', 'date_of_birth', 'fitness_goal', 'medical_restrictions',
        ]

    def create(self, validated_data):
        validated_data['password'] = make_password(validated_data['password'])
        validated_data['email_verified'] = True
        member = Member.objects.create(**validated_data)
        MemberProfile.objects.create(member=member)
        return member


class MemberProfileSerializer(serializers.ModelSerializer):
    profile_completion_percentage = serializers.IntegerField(
        source='profile.profile_completion_percentage', read_only=True
    )
    is_newsletter_subscribed = serializers.BooleanField(
        source='profile.is_newsletter_subscribed', read_only=True
    )

    class Meta:
        model = Member
        fields = [
            'id', 'email', 'first_name', 'last_name',
            'phone', 'date_of_birth', 'photo',
            'fitness_goal', 'medical_restrictions',
            'email_verified', 'has_active_subscription', 'is_suspended', 'suspension_end_date',
            'warnings_count', 'last_login', 'created_at',
            'profile_completion_percentage', 'is_newsletter_subscribed',
        ]
        read_only_fields = [
            'id', 'email', 'email_verified', 'has_active_subscription', 'warnings_count',
            'is_suspended', 'suspension_end_date', 'last_login', 'created_at',
        ]


class MemberUpdateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Member
        fields = [
            'first_name', 'last_name', 'phone',
            'date_of_birth', 'photo',
            'fitness_goal', 'medical_restrictions',
        ]


class PasswordChangeSerializer(serializers.Serializer):
    old_password = serializers.CharField(write_only=True)
    new_password = serializers.CharField(write_only=True, min_length=8)

    def validate_old_password(self, value):
        member = self.context['member']
        if not member.check_password(value):
            raise serializers.ValidationError('Old password is incorrect.')
        return value

    def save(self):
        member = self.context['member']
        member.set_password(self.validated_data['new_password'])
        member.save()


class PasswordResetRequestSerializer(serializers.Serializer):
    email = serializers.EmailField()


class PasswordResetConfirmSerializer(serializers.Serializer):
    token = serializers.CharField()
    new_password = serializers.CharField(min_length=8)


# ─── Coach Serializers ────────────────────────────────────────────────────────

class CoachCreateSerializer(serializers.ModelSerializer):
    """Used by admin to create a coach account."""
    password = serializers.CharField(write_only=True, min_length=8)

    class Meta:
        model = Coach
        fields = [
            'email', 'password', 'first_name', 'last_name',
            'phone', 'photo', 'specialities', 'bio', 'years_of_experience',
        ]

    def create(self, validated_data):
        validated_data['password'] = make_password(validated_data['password'])
        validated_data['created_by'] = self.context['request'].user
        return Coach.objects.create(**validated_data)


class CoachProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = Coach
        fields = [
            'id', 'email', 'first_name', 'last_name',
            'phone', 'photo', 'specialities', 'bio',
            'years_of_experience', 'is_active', 'is_available',
            'last_login', 'created_at',
        ]
        read_only_fields = ['id', 'email', 'last_login', 'created_at']


class CoachUpdateSerializer(serializers.ModelSerializer):
    """Coach updates their own profile."""
    class Meta:
        model = Coach
        fields = [
            'first_name', 'last_name', 'phone',
            'photo', 'bio', 'years_of_experience', 'is_available',
        ]


class CoachPublicSerializer(serializers.ModelSerializer):
    """Public-facing coach info shown in the app."""
    class Meta:
        model = Coach
        fields = [
            'id', 'first_name', 'last_name',
            'photo', 'specialities', 'bio', 'years_of_experience',
        ]
        

class MemberLoginSerializer(serializers.Serializer):
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True)
    
class ResendVerificationSerializer(serializers.Serializer):
    email = serializers.EmailField()
    
class RequestOTPSerializer(serializers.Serializer):
    email = serializers.EmailField()
    
class VerifyOTPSerializer(serializers.Serializer):
    email = serializers.EmailField()
    otp_code = serializers.CharField(max_length=6)