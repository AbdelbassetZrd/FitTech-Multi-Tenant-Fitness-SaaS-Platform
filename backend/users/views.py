import secrets
from datetime import timedelta
import uuid
from drf_yasg.utils import swagger_auto_schema
import random
from django.db import IntegrityError
from django.utils import timezone
from django.conf import settings
from django.template.loader import render_to_string
from django.core.mail import EmailMessage
from django.contrib.auth.hashers import make_password
from .serializers import ResendVerificationSerializer

from rest_framework import status, generics
from rest_framework.decorators import api_view, permission_classes
from rest_framework.exceptions import AuthenticationFailed
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.permissions import IsAuthenticated, AllowAny, IsAdminUser
from rest_framework_simplejwt.tokens import RefreshToken, AccessToken
from rest_framework_simplejwt.exceptions import TokenError

from drf_spectacular.utils import extend_schema

from .models import Member, Coach
from .serializers import (
    MemberRegistrationSerializer,
    MemberProfileSerializer,
    MemberUpdateSerializer,
    PasswordChangeSerializer,
    PasswordResetRequestSerializer,
    PasswordResetConfirmSerializer,
    CoachCreateSerializer,
    CoachProfileSerializer,
    CoachUpdateSerializer,
    CoachPublicSerializer,
    VerifyOTPSerializer,
    RequestOTPSerializer,
)
from .serializers import MemberLoginSerializer


from django.shortcuts import render, redirect
from django.contrib.auth.decorators import login_required
from django.contrib import messages
from django.core.mail import send_mail
from django.conf import settings
from .models import OTPVerification
from .forms import PhoneNumberForm, OTPVerifyForm
from allauth.account.models import EmailConfirmationHMAC, EmailAddress


# ─── JWT helpers (custom payload for non-AbstractUser models) ─────────────────

def _member_tokens(member):
    """Return JWT access+refresh for a Member."""
    refresh = RefreshToken()
    refresh['user_id'] = str(member.id)
    refresh['email'] = member.email
    refresh['role'] = 'member'
    return {'access': str(refresh.access_token), 'refresh': str(refresh)}


def _coach_tokens(coach):
    """Return JWT access+refresh for a Coach."""
    refresh = RefreshToken()
    refresh['user_id'] = str(coach.id)
    refresh['email'] = coach.email
    refresh['role'] = 'coach'
    return {'access': str(refresh.access_token), 'refresh': str(refresh)}


def _authorization_token(request):
    auth_header = request.headers.get('Authorization', '')
    if not auth_header.startswith('Bearer '):
        raise AuthenticationFailed('Authentication credentials were not provided.')
    return auth_header.split(' ', 1)[1].strip()


def _member_from_request(request):
    try:
        access = AccessToken(_authorization_token(request))
    except TokenError as exc:
        raise AuthenticationFailed(str(exc))

    if access.get('role') != 'member':
        raise AuthenticationFailed('Not a member token.')

    member_id = access.get('user_id')
    try:
        return Member.objects.get(id=member_id)
    except Member.DoesNotExist:
        raise AuthenticationFailed('Member not found.')


def _coach_from_request(request):
    try:
        access = AccessToken(_authorization_token(request))
    except TokenError as exc:
        raise AuthenticationFailed(str(exc))

    if access.get('role') != 'coach':
        raise AuthenticationFailed('Not a coach token.')

    coach_id = access.get('user_id')
    try:
        return Coach.objects.get(id=coach_id)
    except Coach.DoesNotExist:
        raise AuthenticationFailed('Coach not found.')


# ─── Email helpers ────────────────────────────
def send_member_verification_email(member):
    try:
        # generate token
        token = str(uuid.uuid4())

        member.email_verification_token = token
        member.email_verification_expires = timezone.now() + timedelta(days=1)
        member.save()

        activation_url = f"{getattr(settings, 'FRONTEND_URL', 'http://localhost:3000')}/verify-email/{token}"

        subject = "Verify your FitTech account"
        message = render_to_string('email_verification.html', {
            'user': member,
            'activation_url': activation_url,
        })

        email = EmailMessage(subject, message, to=[member.email])
        email.content_subtype = 'html'
        email.send()

    except Exception as e:
        print(f'Verification email failed: {e}')

def _send_coach_welcome_email(coach, raw_password):
    """Notify a newly created coach of their credentials."""
    try:
        subject = 'Welcome to FitTech — your coach account'
        message = render_to_string('coach_welcome.html', {
            'coach': coach,
            'password': raw_password,
            'login_url': '{}/coach/login'.format(
                getattr(settings, 'FRONTEND_URL', 'http://localhost:3000')
            ),
        })
        email = EmailMessage(subject, message, to=[coach.email])
        email.content_subtype = 'html'
        email.send()
    except Exception as e:
        print(f'Coach welcome email failed: {e}')


# ═══════════════════════════════════════════════════════════════════════════════
#  MEMBER VIEWS
# ═══════════════════════════════════════════════════════════════════════════════

class MemberRegisterView(APIView):
    permission_classes = [AllowAny]

    @extend_schema(request=MemberRegistrationSerializer, responses={201: MemberProfileSerializer})
    def post(self, request):
        serializer = MemberRegistrationSerializer(data=request.data)
        if serializer.is_valid():
            try:
                member = serializer.save()
                send_member_verification_email(member)
                return Response({
                    'message': 'Registration successful. Please verify your email.',
                    'member_id': member.id,
                    'email': member.email,
                }, status=status.HTTP_201_CREATED)
            except IntegrityError:
                return Response(
                    {'error': 'A member with this email already exists.'},
                    status=status.HTTP_400_BAD_REQUEST,
                )
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class MemberLoginView(APIView):
    permission_classes = [AllowAny]

    @extend_schema(request=MemberLoginSerializer)  # ← this is what tells Swagger the fields

    def post(self, request):
        email = request.data.get('email')
        password = request.data.get('password')

        if not email or not password:
            return Response(
                {'error': 'Email and password are required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            member = Member.objects.get(email=email)
        except Member.DoesNotExist:
            return Response({'error': 'Invalid credentials.'}, status=status.HTTP_401_UNAUTHORIZED)

        if not member.check_password(password):
            return Response({'error': 'Invalid credentials.'}, status=status.HTTP_401_UNAUTHORIZED)

        if not member.email_verified:
            return Response({
                'error': 'Please verify your email before logging in.',
                'needs_verification': True,
            }, status=status.HTTP_401_UNAUTHORIZED)

        if not member.is_active:
            return Response({'error': 'Account deactivated.'}, status=status.HTTP_403_FORBIDDEN)

        if member.is_suspension_active():
            return Response({
                'error': f'Account suspended until {member.suspension_end_date}.',
                'suspended_until': str(member.suspension_end_date),
            }, status=status.HTTP_403_FORBIDDEN)

        member.last_login = timezone.now()
        member.save(update_fields=['last_login'])

        tokens = _member_tokens(member)
        return Response({
            **tokens,
            'member': MemberProfileSerializer(member).data,
        })


class MemberVerifyEmailView(APIView):
    permission_classes = [AllowAny]

    def get(self, request, key):
        try:
            member = Member.objects.get(email_verification_token=key)

            # check expiration
            if member.email_verification_expires < timezone.now():
                return Response(
                    {'error': 'Token expired'},
                    status=status.HTTP_400_BAD_REQUEST
                )

            if member.email_verified:
                return Response({'message': 'Email already verified.'})

            # verify
            member.email_verified = True
            member.email_verification_token = ''
            member.save(update_fields=['email_verified', 'email_verification_token'])

            # generate tokens (your function)
            tokens = _member_tokens(member)

            return Response({
                'message': 'Email verified successfully.',
                **tokens,
                'member': MemberProfileSerializer(member).data,
            })

        except Member.DoesNotExist:
            return Response(
                {'error': 'Invalid token'},
                status=status.HTTP_400_BAD_REQUEST
            )

        except Exception as e:
            return Response(
                {'error': str(e)},
                status=status.HTTP_400_BAD_REQUEST
            )

class MemberResendVerificationView(APIView):
    permission_classes = [AllowAny]


    @extend_schema(request=ResendVerificationSerializer)


    def post(self, request):
        email = request.data.get('email')
        if not email:
            return Response({'error': 'Email is required.'}, status=status.HTTP_400_BAD_REQUEST)
        try:
            member = Member.objects.get(email=email)
            if member.email_verified:
                return Response({'message': 'Email is already verified.'})
            send_member_verification_email(member)
        except Member.DoesNotExist:
            pass
        return Response({'message': 'If that email exists, a verification link was sent.'})


class MemberProfileView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]

    def get(self, request):
        try:
            member = _member_from_request(request)
        except AuthenticationFailed as exc:
            return Response({'detail': str(exc)}, status=status.HTTP_401_UNAUTHORIZED)
        return Response(MemberProfileSerializer(member).data)


class MemberUpdateProfileView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]

    def patch(self, request):
        try:
            member = _member_from_request(request)
        except AuthenticationFailed as exc:
            return Response({'detail': str(exc)}, status=status.HTTP_401_UNAUTHORIZED)

        serializer = MemberUpdateSerializer(member, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(MemberProfileSerializer(member).data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class MemberPasswordChangeView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]

    def post(self, request):
        try:
            member = _member_from_request(request)
        except AuthenticationFailed as exc:
            return Response({'detail': str(exc)}, status=status.HTTP_401_UNAUTHORIZED)

        serializer = PasswordChangeSerializer(data=request.data, context={'member': member})
        if serializer.is_valid():
            serializer.save()
            return Response({'message': 'Password changed successfully.'})
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class MemberPasswordResetRequestView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = PasswordResetRequestSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        email = serializer.validated_data['email']
        try:
            member = Member.objects.get(email=email)
            token = secrets.token_urlsafe(32)
            member.password_reset_token = token
            member.password_reset_expires = timezone.now() + timedelta(hours=2)
            member.save(update_fields=['password_reset_token', 'password_reset_expires'])

            reset_url = '{}/reset-password/{}'.format(
                getattr(settings, 'FRONTEND_URL', 'http://localhost:3000'), token
            )
            message = render_to_string('password_reset.html', {
                'user': member, 'reset_url': reset_url,
            })
            email_msg = EmailMessage('Reset your FitTech password', message, to=[member.email])
            email_msg.content_subtype = 'html'
            email_msg.send()
        except Member.DoesNotExist:
            pass

        return Response({'message': 'If that email exists, a reset link has been sent.'})


class MemberPasswordResetConfirmView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = PasswordResetConfirmSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        token = serializer.validated_data['token']
        try:
            member = Member.objects.get(password_reset_token=token)
        except Member.DoesNotExist:
            return Response(
                {'error': 'Invalid or expired reset token.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if member.password_reset_expires < timezone.now():
            return Response(
                {'error': 'Reset token has expired.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        member.set_password(serializer.validated_data['new_password'])
        member.password_reset_token = ''
        member.password_reset_expires = None
        member.save()
        return Response({'message': 'Password reset successfully.'})


@api_view(['POST'])
@permission_classes([AllowAny])
def member_logout_view(request):
    try:
        token = RefreshToken(request.data.get('refresh_token'))
        token.blacklist()
        return Response({'message': 'Successfully logged out.'})
    except Exception:
        return Response({'error': 'Invalid token.'}, status=status.HTTP_400_BAD_REQUEST)


# ═══════════════════════════════════════════════════════════════════════════════
#  COACH VIEWS
# ═══════════════════════════════════════════════════════════════════════════════

class CoachLoginView(APIView):
    """Coaches log in with email + password (set by admin)."""
    permission_classes = [AllowAny]

    def post(self, request):
        email = request.data.get('email')
        password = request.data.get('password')

        if not email or not password:
            return Response(
                {'error': 'Email and password are required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            coach = Coach.objects.get(email=email)
        except Coach.DoesNotExist:
            return Response({'error': 'Invalid credentials.'}, status=status.HTTP_401_UNAUTHORIZED)

        if not coach.check_password(password):
            return Response({'error': 'Invalid credentials.'}, status=status.HTTP_401_UNAUTHORIZED)

        if not coach.is_active:
            return Response(
                {'error': 'Coach account is deactivated. Contact admin.'},
                status=status.HTTP_403_FORBIDDEN,
            )

        coach.last_login = timezone.now()
        coach.save(update_fields=['last_login'])

        tokens = _coach_tokens(coach)
        return Response({
            **tokens,
            'coach': CoachProfileSerializer(coach).data,
        })


class CoachProfileView(APIView):
    """Coach views their own profile."""
    permission_classes = [AllowAny]
    authentication_classes = []

    def get(self, request):
        try:
            coach = _coach_from_request(request)
        except AuthenticationFailed as exc:
            return Response({'detail': str(exc), 'code': 'user_not_found'}, status=status.HTTP_401_UNAUTHORIZED)
        return Response(CoachProfileSerializer(coach).data)


class CoachUpdateProfileView(APIView):
    """Coach updates their own profile (limited fields)."""
    permission_classes = [AllowAny]
    authentication_classes = []

    def patch(self, request):
        try:
            coach = _coach_from_request(request)
        except AuthenticationFailed as exc:
            return Response({'detail': str(exc), 'code': 'user_not_found'}, status=status.HTTP_401_UNAUTHORIZED)

        serializer = CoachUpdateSerializer(coach, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(CoachProfileSerializer(coach).data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class CoachPasswordChangeView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []

    def post(self, request):
        try:
            coach = _coach_from_request(request)
        except AuthenticationFailed as exc:
            return Response({'detail': str(exc), 'code': 'user_not_found'}, status=status.HTTP_401_UNAUTHORIZED)

        serializer = PasswordChangeSerializer(data=request.data, context={'member': coach})
        if serializer.is_valid():
            serializer.save()
            return Response({'message': 'Password changed successfully.'})
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class CoachPasswordResetRequestView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []

    def post(self, request):
        serializer = PasswordResetRequestSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        email = serializer.validated_data['email']
        try:
            coach = Coach.objects.get(email=email)
            token = secrets.token_urlsafe(32)
            coach.password_reset_token = token
            coach.password_reset_expires = timezone.now() + timedelta(hours=2)
            coach.save(update_fields=['password_reset_token', 'password_reset_expires'])

            reset_url = '{}/reset-password/{}'.format(
                getattr(settings, 'FRONTEND_URL', 'http://localhost:3000'), token
            )
            message = render_to_string('password_reset.html', {
                'user': coach, 'reset_url': reset_url,
            })
            email_msg = EmailMessage('Reset your FitTech coach password', message, to=[coach.email])
            email_msg.content_subtype = 'html'
            email_msg.send()
        except Coach.DoesNotExist:
            pass

        return Response({'message': 'If that email exists, a reset link has been sent.'})


class CoachPasswordResetConfirmView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []

    def post(self, request):
        serializer = PasswordResetConfirmSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        token = serializer.validated_data['token']
        try:
            coach = Coach.objects.get(password_reset_token=token)
        except Coach.DoesNotExist:
            return Response(
                {'error': 'Invalid or expired reset token.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if coach.password_reset_expires < timezone.now():
            return Response(
                {'error': 'Reset token has expired.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        coach.set_password(serializer.validated_data['new_password'])
        coach.password_reset_token = ''
        coach.password_reset_expires = None
        coach.save()
        return Response({'message': 'Password reset successfully.'})


class CoachPublicListView(generics.ListAPIView):
    """Public list of coaches visible in the mobile app."""
    serializer_class = CoachPublicSerializer
    permission_classes = [AllowAny]
    queryset = Coach.objects.filter(is_active=True, is_available=True)


# ═══════════════════════════════════════════════════════════════════════════════
#  ADMIN-ONLY COACH MANAGEMENT
# ═══════════════════════════════════════════════════════════════════════════════

class AdminCoachCreateView(APIView):
    """Admin creates a coach account and emails credentials."""
    permission_classes = [IsAdminUser]

    @extend_schema(request=CoachCreateSerializer, responses={201: CoachProfileSerializer})
    def post(self, request):
        serializer = CoachCreateSerializer(data=request.data, context={'request': request})
        if serializer.is_valid():
            try:
                raw_password = request.data.get('password')
                coach = serializer.save()
                _send_coach_welcome_email(coach, raw_password)
                return Response(
                    CoachProfileSerializer(coach).data,
                    status=status.HTTP_201_CREATED,
                )
            except IntegrityError:
                return Response(
                    {'error': 'A coach with this email already exists.'},
                    status=status.HTTP_400_BAD_REQUEST,
                )
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class AdminCoachListView(generics.ListAPIView):
    """Admin lists all coaches."""
    serializer_class = CoachProfileSerializer
    permission_classes = [IsAdminUser]
    queryset = Coach.objects.all().order_by('-created_at')


class AdminCoachDetailView(APIView):
    """Admin can update or deactivate a coach."""
    permission_classes = [IsAdminUser]

    def get_coach(self, pk):
        try:
            return Coach.objects.get(id=pk)
        except Coach.DoesNotExist:
            return None

    def get(self, request, pk):
        coach = self.get_coach(pk)
        if not coach:
            return Response({'error': 'Coach not found.'}, status=status.HTTP_404_NOT_FOUND)
        return Response(CoachProfileSerializer(coach).data)

    def patch(self, request, pk):
        coach = self.get_coach(pk)
        if not coach:
            return Response({'error': 'Coach not found.'}, status=status.HTTP_404_NOT_FOUND)
        serializer = CoachCreateSerializer(
            coach, data=request.data,
            partial=True, context={'request': request}
        )
        if serializer.is_valid():
            serializer.save()
            return Response(CoachProfileSerializer(coach).data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    def delete(self, request, pk):
        coach = self.get_coach(pk)
        if not coach:
            return Response({'error': 'Coach not found.'}, status=status.HTTP_404_NOT_FOUND)
        coach.is_active = False
        coach.save(update_fields=['is_active'])
        return Response({'message': 'Coach deactivated successfully.'})
    

class RequestMemberOTPView(APIView):
    permission_classes = [AllowAny]
    @extend_schema(request=RequestOTPSerializer)

    def post(self, request):
        email = request.data.get('email')

        if not email:
            return Response({'error': 'Email is required'}, status=400)

        try:
            member = Member.objects.get(email=email)
        except Member.DoesNotExist:
            return Response({'error': 'Member not found'}, status=404)

        # generate OTP
        otp = str(random.randint(100000, 999999))
        member.otp_code = otp
        member.otp_expires = timezone.now() + timedelta(minutes=10)
        member.save()

        # send email
        send_mail(
            subject='Your Verification Code',
            message=f'Your OTP is: {otp}\n\nExpires in 10 minutes.',
            from_email=settings.DEFAULT_FROM_EMAIL,
            recipient_list=[member.email],
        )

        return Response({'message': 'OTP sent successfully'})
    
    
class VerifyMemberOTPView(APIView):
    permission_classes = [AllowAny]
    @extend_schema(request=VerifyOTPSerializer)


    def post(self, request):
        email = request.data.get('email')
        otp = request.data.get('otp_code')

        if not email or not otp:
            return Response({'error': 'Email and OTP are required'}, status=400)

        try:
            member = Member.objects.get(email=email)
        except Member.DoesNotExist:
            return Response({'error': 'Member not found'}, status=404)

        if not member.otp_expires or member.otp_expires < timezone.now():
            return Response({'error': 'OTP expired'}, status=400)

        if otp == member.otp_code:
            member.email_verified = True
            member.otp_code = ''
            member.save()

            return Response({'message': 'OTP verified successfully'})

        return Response({'error': 'Invalid OTP'}, status=400)


class MemberTokenRefreshView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        refresh_token = request.data.get('refresh')
        if not refresh_token:
            return Response({'detail': 'Refresh token is required.'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            refresh = RefreshToken(refresh_token)
        except TokenError as exc:
            return Response({'detail': str(exc)}, status=status.HTTP_401_UNAUTHORIZED)

        return Response({'access': str(refresh.access_token)})
    
from rest_framework_simplejwt.views import TokenObtainPairView

class AdminLoginView(TokenObtainPairView):
    """Admin logs in and gets JWT tokens."""
    pass


# ─── Google OAuth ─────────────────────────────────────────────────────────────

from .oauth import verify_google_token  # noqa: E402  (kept local to avoid cycles)
from .models import MemberProfile, CustomUser  # noqa: E402


def _google_member_payload(member, *, created=False):
    """Build the user payload returned by both Google sign-in endpoints."""
    profile = getattr(member, 'profile', None)
    return {
        'id': str(member.id),
        'email': member.email,
        'first_name': member.first_name,
        'last_name': member.last_name,
        'full_name': f"{member.first_name} {member.last_name}".strip(),
        'role': 'member',
        'is_new': created,
        'phone': member.phone,
        'date_of_birth': member.date_of_birth.isoformat() if member.date_of_birth else None,
        'photo': member.photo.url if getattr(member, 'photo', None) else None,
        'fitness_goal': member.fitness_goal,
        'medical_restrictions': member.medical_restrictions,
        'email_verified': member.email_verified,
        'is_suspended': member.is_suspended,
        'suspension_end_date': member.suspension_end_date.isoformat() if member.suspension_end_date else None,
        'warnings_count': member.warnings_count,
        'bio': profile.bio if profile else '',
        'is_newsletter_subscribed': profile.is_newsletter_subscribed if profile else False,
        'profile_completion_percentage': profile.profile_completion_percentage if profile else 0,
        'is_profile_complete': profile.is_profile_complete if profile else False,
        'is_suspension_active': member.is_suspension_active(),
    }


def _admin_payload_from_google(admin_user):
    """Build the admin user payload for Google sign-in (matches frontend User shape)."""
    return {
        'id': str(admin_user.id),
        'email': admin_user.email,
        'full_name': admin_user.get_full_name(),
        'first_name': admin_user.first_name,
        'last_name': admin_user.last_name,
        'role': 'admin',
        'phone': getattr(admin_user, 'phone', '') or '',
        'date_of_birth': None,
        'photo': None,
        'fitness_goal': '',
        'medical_restrictions': '',
        'email_verified': True,
        'is_suspended': False,
        'suspension_end_date': None,
        'warnings_count': 0,
        'bio': '',
        'is_newsletter_subscribed': False,
        'profile_completion_percentage': 100,
        'is_profile_complete': True,
        'is_suspension_active': False,
    }


def _admin_tokens(admin_user):
    """Build a JWT pair for an admin/CustomUser using the same payload shape
    as :func:`_member_tokens` so the existing JWT helpers keep working."""
    refresh = RefreshToken()
    refresh['user_id'] = str(admin_user.id)
    refresh['email'] = admin_user.email
    refresh['role'] = 'admin'
    return {'access': str(refresh.access_token), 'refresh': str(refresh)}


class MemberGoogleAuthView(APIView):
    """POST /api/auth/members/users/auth/google/

    Verifies a Google ID token issued for the **web** client. If the email
    belongs to an admin (CustomUser), an admin token is returned; otherwise a
    member is created/looked up and a member token is returned.
    """
    authentication_classes = []
    permission_classes = [AllowAny]

    def post(self, request):
        token = request.data.get('token')
        if not token:
            return Response({'error': 'Google token is required.'}, status=status.HTTP_400_BAD_REQUEST)

        if not getattr(settings, 'GOOGLE_CLIENT_ID', None):
            return Response(
                {'error': 'Server is missing GOOGLE_CLIENT_ID configuration.'},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )

        google_data = verify_google_token(token)
        if not google_data:
            return Response({'error': 'Invalid Google token.'}, status=status.HTTP_401_UNAUTHORIZED)

        email = google_data['email']

        # Admins live in CustomUser and are matched by email.
        admin_user = CustomUser.objects.filter(email=email).first()
        if admin_user is not None:
            if not admin_user.is_active:
                return Response({'error': 'Admin account is inactive.'}, status=status.HTTP_403_FORBIDDEN)
            tokens = _admin_tokens(admin_user)
            return Response({**tokens, 'user': _admin_payload_from_google(admin_user)})

        member, created = Member.objects.get_or_create(
            email=email,
            defaults={
                'first_name': google_data['first_name'],
                'last_name': google_data['last_name'],
                'email_verified': bool(google_data['email_verified']),
                'password': '',
            },
        )
        if created:
            MemberProfile.objects.create(member=member)

        if member.is_suspended:
            return Response({'error': 'Your account is suspended.'}, status=status.HTTP_403_FORBIDDEN)
        if not member.is_active:
            return Response({'error': 'Your account is inactive.'}, status=status.HTTP_403_FORBIDDEN)

        tokens = _member_tokens(member)
        return Response({**tokens, 'user': _google_member_payload(member, created=created)})


class MemberGoogleAuthMobileView(APIView):
    """POST /api/auth/members/users/auth/google/mobile/

    Same logic as :class:`MemberGoogleAuthView` but the caller specifies
    ``platform`` (``android`` or ``ios``) so we can verify the ID token
    against the right OAuth client id.
    """
    authentication_classes = []
    permission_classes = [AllowAny]

    def post(self, request):
        token = request.data.get('token')
        platform = request.data.get('platform')

        if not token:
            return Response({'error': 'Google token is required.'}, status=status.HTTP_400_BAD_REQUEST)
        if platform not in ('android', 'ios'):
            return Response({'error': 'Platform must be android or ios.'}, status=status.HTTP_400_BAD_REQUEST)

        client_id = (
            settings.GOOGLE_CLIENT_ID_ANDROID
            if platform == 'android'
            else settings.GOOGLE_CLIENT_ID_IOS
        )
        if not client_id:
            return Response(
                {'error': f'Server is missing GOOGLE_CLIENT_ID_{platform.upper()} configuration.'},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )

        google_data = verify_google_token(token, client_id=client_id)
        if not google_data:
            return Response({'error': 'Invalid Google token.'}, status=status.HTTP_401_UNAUTHORIZED)

        email = google_data['email']

        admin_user = CustomUser.objects.filter(email=email).first()
        if admin_user is not None:
            if not admin_user.is_active:
                return Response({'error': 'Admin account is inactive.'}, status=status.HTTP_403_FORBIDDEN)
            tokens = _admin_tokens(admin_user)
            return Response({**tokens, 'user': _admin_payload_from_google(admin_user)})

        member, created = Member.objects.get_or_create(
            email=email,
            defaults={
                'first_name': google_data['first_name'],
                'last_name': google_data['last_name'],
                'email_verified': bool(google_data['email_verified']),
                'password': '',
            },
        )
        if created:
            MemberProfile.objects.create(member=member)

        if member.is_suspended:
            return Response({'error': 'Your account is suspended.'}, status=status.HTTP_403_FORBIDDEN)
        if not member.is_active:
            return Response({'error': 'Your account is inactive.'}, status=status.HTTP_403_FORBIDDEN)

        tokens = _member_tokens(member)
        return Response({**tokens, 'user': _google_member_payload(member, created=created)})

# ─── Admin: profile + member management ──────────────────────────────────────

from .serializers import AdminMemberCreateSerializer  # noqa: E402


class AdminProfileView(APIView):
    """GET /api/auth/admin/profile/ — return the logged-in admin's profile in
    the same shape as the frontend ``User`` interface."""
    permission_classes = [IsAuthenticated]

    def get(self, request):
        admin_user = CustomUser.objects.filter(id=request.user.id).first()
        if admin_user is None:
            return Response({'error': 'Admin not found.'}, status=status.HTTP_404_NOT_FOUND)
        return Response(_admin_payload_from_google(admin_user))


class MemberListView(generics.ListAPIView):
    """GET /api/auth/admin/members/ — list all members (admin only)."""
    serializer_class = MemberProfileSerializer
    permission_classes = [IsAdminUser]
    queryset = Member.objects.all().order_by('-created_at')


class AdminMemberCreateView(APIView):
    """POST /api/auth/admin/members/create/ — create a pre-verified member."""
    permission_classes = [IsAdminUser]

    @extend_schema(request=AdminMemberCreateSerializer, responses={201: MemberProfileSerializer})
    def post(self, request):
        serializer = AdminMemberCreateSerializer(data=request.data, context={'request': request})
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        try:
            member = serializer.save()
        except IntegrityError:
            return Response(
                {'error': 'A member with this email already exists.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        return Response(MemberProfileSerializer(member).data, status=status.HTTP_201_CREATED)


class MemberSearchView(generics.ListAPIView):
    """GET /api/auth/admin/members/search/?q=… — search members by email."""
    serializer_class = MemberProfileSerializer
    permission_classes = [IsAdminUser]

    def get_queryset(self):
        query = self.request.query_params.get('q', '').strip()
        if not query:
            return Member.objects.all().order_by('-created_at')
        return Member.objects.filter(email__icontains=query).order_by('-created_at')


class SuspendMemberView(APIView):
    """POST /api/auth/admin/members/<pk>/suspend/."""
    permission_classes = [IsAdminUser]

    def post(self, request, pk):
        member = Member.objects.filter(id=pk).first()
        if member is None:
            return Response({'error': 'Member not found.'}, status=status.HTTP_404_NOT_FOUND)
        member.is_suspended = True
        member.save(update_fields=['is_suspended'])
        return Response({'message': 'Member suspended successfully.'})


class RemoveSuspensionView(APIView):
    """POST /api/auth/admin/members/<pk>/remove-suspension/."""
    permission_classes = [IsAdminUser]

    def post(self, request, pk):
        member = Member.objects.filter(id=pk).first()
        if member is None:
            return Response({'error': 'Member not found.'}, status=status.HTTP_404_NOT_FOUND)
        member.is_suspended = False
        member.suspension_end_date = None
        member.save(update_fields=['is_suspended', 'suspension_end_date'])
        return Response({'message': 'Suspension removed successfully.'})
