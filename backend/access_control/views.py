import threading
from django.utils.decorators import method_decorator
from django.views.decorators.csrf import csrf_exempt
from rest_framework import permissions, status
from rest_framework.permissions import IsAdminUser
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.exceptions import AuthenticationFailed
from rest_framework_simplejwt.tokens import AccessToken
from rest_framework_simplejwt.exceptions import TokenError
from datetime import date

from users.models import Member, Coach, CustomUser
from subscriptions.models import Subscription
from .models import NFCDevice, AccessLog

# ── In-memory UID capture slot ─────────────────────────────────────────────────
# Keyed by session_id so multiple admin tabs can capture independently.
_uid_slots: dict = {}
_uid_slots_lock = threading.Lock()


# ── Helpers ───────────────────────────────────────────────────────────────────

def _resolve_user(request):
    """Decode the bearer JWT and return (user_obj, role)."""
    auth_header = request.headers.get('Authorization', '')
    if not auth_header.startswith('Bearer '):
        raise AuthenticationFailed('Authentication credentials were not provided.')
    raw_token = auth_header.split(' ', 1)[1].strip()
    try:
        access = AccessToken(raw_token)
    except TokenError as exc:
        raise AuthenticationFailed(str(exc))

    user_id = access.get('user_id')
    role = access.get('role')
    if not user_id:
        raise AuthenticationFailed('Invalid token payload.')

    if role == 'member':
        try:
            return Member.objects.get(id=user_id), 'member'
        except Member.DoesNotExist:
            raise AuthenticationFailed('Member not found.')
    if role == 'coach':
        try:
            return Coach.objects.get(id=user_id), 'coach'
        except Coach.DoesNotExist:
            raise AuthenticationFailed('Coach not found.')
    try:
        return CustomUser.objects.get(id=user_id), 'admin'
    except CustomUser.DoesNotExist:
        raise AuthenticationFailed('User not found.')


def _customuser_for_member(member: Member):
    if not getattr(member, 'email', None):
        return None
    return CustomUser.objects.filter(email=member.email).first()


def _active_subscription_for(member: Member):
    return (
        Subscription.objects
        .filter(user=member)
        .exclude(status='cancelled')
        .order_by('-created_at')
        .first()
    )


def _membership_display_id(member: Member) -> str:
    raw = (str(member.id) or '').replace('-', '').upper()
    if len(raw) >= 5:
        return f"FT-{raw[0:3]}-{raw[3:5]}"
    return f"FT-{raw}"


def _staff_display_id(user, role: str) -> str:
    raw = str(getattr(user, 'id', '') or '').replace('-', '').upper()
    prefix = 'CO' if role == 'coach' else 'AD'
    if len(raw) >= 5:
        return f"{prefix}-{raw[0:3]}-{raw[3:5]}"
    return f"{prefix}-{raw}"


def _log_kwargs(role: str, user, device) -> dict:
    """Build the correct FK kwargs for creating an AccessLog."""
    base = {'role': role, 'device': device}
    if role == 'member':
        base['member'] = user
    elif role == 'coach':
        base['coach'] = user
    else:
        base['admin_user'] = user
    return base


def _device_filter_kwargs(role: str, user) -> dict:
    """Build the correct FK kwargs for querying AccessLog by owner."""
    if role == 'member':
        return {'member': user}
    if role == 'coach':
        return {'coach': user}
    return {'admin_user': user}


# ── UID Capture (NFC reader → admin form) ────────────────────────────────────

@method_decorator(csrf_exempt, name='dispatch')
class CaptureUIDView(APIView):
    """
    POST /api/access/capture-uid/   { "nfc_uid": "A1B2C3D4", "session_id": "abc" }
        Called by the NFC reader when the admin wants to register a new card.
        No auth required — same as the scan endpoint.

    GET  /api/access/capture-uid/?session_id=abc
        Polled by the admin frontend every second.
        Returns the UID once and clears it, or null if not yet scanned.
        Requires admin auth.
    """
    permission_classes = [permissions.AllowAny]
    authentication_classes = []

    def post(self, request):
        import json as _json

        uid = None
        session_id = 'default'

        raw_body = request.body.decode('utf-8', errors='ignore').strip()

        try:
            parsed = _json.loads(raw_body)
            if isinstance(parsed, dict):
                # Format A: { "tagId": "C1:09:B2:DE", "source": "NFC_READ", ... }
                tag_id = parsed.get('tagId') or parsed.get('tag_id') or parsed.get('id', '')
                if tag_id:
                    uid = tag_id.replace(':', '').upper()
            elif isinstance(parsed, list):
                # Format B: ["id:044f63f23c2a80", "source:NFC", ...]
                for item in parsed:
                    if isinstance(item, str) and item.startswith('id:'):
                        uid = item[3:].strip().replace(':', '').upper()
                        break
        except Exception:
            pass

        # Format C: standard JSON object { "nfc_uid": "...", "session_id": "..." }
        if not uid:
            uid = (request.data.get('nfc_uid') or '').strip().replace(':', '').upper()
            session_id = request.data.get('session_id', 'default').strip()

        if not uid:
            from django.http import HttpResponse
            return HttpResponse('No valid data received.', content_type='text/plain', status=400)

        with _uid_slots_lock:
            _uid_slots[session_id] = uid

        # The NFC Reader/Writer app requires the response body to be exactly "ok_ok"
        from django.http import HttpResponse
        return HttpResponse('ok_ok', content_type='text/plain')

    def get(self, request):
        session_id = request.query_params.get('session_id', 'default').strip()
        with _uid_slots_lock:
            uid = _uid_slots.pop(session_id, None)
        return Response({'uid': uid})


# ── Admin: Assign NFC device (supports member / coach / admin) ─────────────────

class AssignNFCDeviceView(APIView):
    permission_classes = [IsAdminUser]

    def post(self, request):
        uid = request.data.get('uid')
        device_type = request.data.get('device_type', 'card')
        role = request.data.get('role', 'member')
        user_id = request.data.get('user_id')

        if not uid or not user_id:
            return Response({'error': 'user_id and uid are required.'}, status=400)
        if role not in ('member', 'coach', 'admin'):
            return Response({'error': 'role must be member, coach, or admin.'}, status=400)
        if NFCDevice.objects.filter(uid=uid, is_active=True).exists():
            return Response({'error': 'UID already registered.'}, status=400)

        if role == 'member':
            try:
                obj = Member.objects.get(id=user_id)
            except Member.DoesNotExist:
                return Response({'error': 'Member not found.'}, status=404)
            device = NFCDevice.objects.create(member=obj, role='member', uid=uid, device_type=device_type)
        elif role == 'coach':
            try:
                obj = Coach.objects.get(id=user_id)
            except Coach.DoesNotExist:
                return Response({'error': 'Coach not found.'}, status=404)
            device = NFCDevice.objects.create(coach=obj, role='coach', uid=uid, device_type=device_type)
        else:
            try:
                obj = CustomUser.objects.get(id=user_id)
            except CustomUser.DoesNotExist:
                return Response({'error': 'Admin user not found.'}, status=404)
            device = NFCDevice.objects.create(admin_user=obj, role='admin', uid=uid, device_type=device_type)

        return Response({
            'message': 'NFC device assigned successfully.',
            'device_id': device.id,
            'role': role,
            'owner': device.get_owner_name(),
            'uid': uid,
        })


class DeactivateNFCDeviceView(APIView):
    permission_classes = [IsAdminUser]

    def post(self, request):
        uid = request.data.get('uid')
        try:
            device = NFCDevice.objects.get(uid=uid)
        except NFCDevice.DoesNotExist:
            return Response({'error': 'Device not found.'}, status=404)
        device.delete()
        return Response({'message': 'Device deleted.', 'uid': uid})


class ListNFCDevicesView(APIView):
    """GET /api/access/devices/ — admin only, list all NFC devices."""
    permission_classes = [IsAdminUser]

    def get(self, request):
        role_filter = request.query_params.get('role')
        qs = NFCDevice.objects.select_related('member', 'coach', 'admin_user').order_by('-created_at')
        if role_filter:
            qs = qs.filter(role=role_filter)
        data = [
            {
                'id': d.id,
                'uid': d.uid,
                'role': d.role,
                'owner': d.get_owner_name(),
                'device_type': d.device_type,
                'is_active': d.is_active,
                'created_at': d.created_at.isoformat(),
            }
            for d in qs
        ]
        return Response({'results': data})


# ── Public: NFC Scan (called by the physical NFC reader device) ────────────────

@method_decorator(csrf_exempt, name='dispatch')
class NFCScanView(APIView):
    """
    POST /api/access/scan/
    Body: { "nfc_uid": "<hex_uid>" }

    Called by the external NFC reader app (Raspberry Pi / Android reader).
    No authentication required — the UID is the credential.
    Returns: { "allowed": true/false, "reason": "...", "user": "...", "role": "..." }
    """
    permission_classes = [permissions.AllowAny]
    authentication_classes = []

    def post(self, request):
        import json as _json

        uid = None
        raw_body = request.body.decode('utf-8', errors='ignore').strip()
        try:
            parsed = _json.loads(raw_body)
            if isinstance(parsed, dict):
                # Format A: { "tagId": "C1:09:B2:DE", ... }
                tag_id = parsed.get('tagId') or parsed.get('tag_id') or parsed.get('id', '')
                if tag_id:
                    uid = tag_id.replace(':', '').upper()
            elif isinstance(parsed, list):
                # Format B: ["id:044f63f23c2a80", ...]
                for item in parsed:
                    if isinstance(item, str) and item.startswith('id:'):
                        uid = item[3:].strip().replace(':', '').upper()
                        break
        except Exception:
            pass

        # Format C: standard { "nfc_uid": "..." }
        if not uid:
            uid = (request.data.get('nfc_uid') or '').strip().replace(':', '').upper()

        if not uid:
            return Response({'allowed': False, 'reason': 'Missing nfc_uid.'}, status=400)

        try:
            device = NFCDevice.objects.select_related('member', 'coach', 'admin_user').get(
                uid=uid, is_active=True
            )
        except NFCDevice.DoesNotExist:
            return Response({'allowed': False, 'reason': 'Unknown or inactive NFC device.'}, status=404)

        role = device.role
        owner = device.get_owner()
        owner_name = device.get_owner_name()
        log_kw = _log_kwargs(role, owner, device)
        filter_kw = _device_filter_kwargs(role, owner)

        # ── Coaches and Admins: always allow ──────────────────────────────────
        if role in ('coach', 'admin'):
            AccessLog.objects.create(**log_kw, allowed=True, reason='Staff access granted')
            return Response({
                'allowed': True,
                'reason': 'Staff access granted',
                'user': owner_name,
                'role': role,
            })

        # ── Members: subscription check ───────────────────────────────────────
        subscription = _active_subscription_for(owner)
        if not subscription:
            AccessLog.objects.create(**log_kw, allowed=False, reason='No active subscription')
            return Response({'allowed': False, 'reason': 'No active subscription', 'role': role})

        if not subscription.is_active():
            AccessLog.objects.create(**log_kw, allowed=False, reason='Subscription expired')
            return Response({'allowed': False, 'reason': 'Subscription expired', 'role': role})

        today = date.today()
        already_entered = AccessLog.objects.filter(
            **filter_kw, timestamp__date=today, allowed=True
        ).exists()
        if already_entered:
            AccessLog.objects.create(**log_kw, allowed=False, reason='Already entered today')
            return Response({'allowed': False, 'reason': 'Already entered today', 'role': role})

        if subscription.plan.plan_type == 'per_session':
            if not subscription.sessions_remaining or subscription.sessions_remaining <= 0:
                AccessLog.objects.create(**log_kw, allowed=False, reason='No sessions remaining')
                return Response({'allowed': False, 'reason': 'No sessions remaining', 'role': role})

        AccessLog.objects.create(**log_kw, allowed=True, reason='Access granted')
        if subscription.plan.plan_type == 'per_session':
            subscription.sessions_remaining -= 1
            subscription.save(update_fields=['sessions_remaining'])

        return Response({
            'allowed': True,
            'reason': 'Access granted',
            'user': owner_name,
            'role': role,
        })



class MyAccessStatusView(APIView):
    """
    GET /api/access/me/
    Works for members, coaches, and admins.
    """
    permission_classes = [permissions.AllowAny]
    authentication_classes = []

    def get(self, request):
        try:
            user, role = _resolve_user(request)
        except AuthenticationFailed as exc:
            return Response({'detail': str(exc)}, status=status.HTTP_401_UNAUTHORIZED)

        # Fetch the user's active NFC device
        if role == 'member':
            device = NFCDevice.objects.filter(member=user, role='member', is_active=True).order_by('-created_at').first()
        elif role == 'coach':
            device = NFCDevice.objects.filter(coach=user, role='coach', is_active=True).order_by('-created_at').first()
        else:
            device = NFCDevice.objects.filter(admin_user=user, role='admin', is_active=True).order_by('-created_at').first()

        # Staff (coach/admin) always have access
        if role in ('coach', 'admin'):
            display_id = _staff_display_id(user, role)
            role_label = 'COACH' if role == 'coach' else 'ADMIN'
            return Response({
                'membership_id': display_id,
                'full_name': user.get_full_name(),
                'role': role_label,
                'role_label': role_label,
                'nfc_uid': device.uid if device else None,
                'device_type': device.device_type if device else None,
                'is_connected': device is not None,
                'subscription_active': True,
                'plan_label': 'Staff — Always Allowed',
            })

        # Member: check subscription
        subscription = _active_subscription_for(user)
        if subscription:
            try:
                subscription.update_status()
            except Exception:
                pass

        plan_label = ''
        active = False
        if subscription:
            plan = getattr(subscription, 'plan', None)
            plan_label = getattr(plan, 'name', '') or getattr(plan, 'plan_type', '') or ''
            try:
                active = bool(subscription.is_active())
            except Exception:
                active = subscription.status == 'active'

        return Response({
            'membership_id': _membership_display_id(user),
            'full_name': user.get_full_name(),
            'role': 'ACTIVE MEMBER' if active else 'INACTIVE',
            'role_label': 'MEMBER',
            'nfc_uid': device.uid if device else None,
            'device_type': device.device_type if device else None,
            'is_connected': bool(device and active),
            'subscription_active': active,
            'plan_label': plan_label,
        })


class MeRegisterCardView(APIView):
    """
    POST /api/access/me/register-card/
    Lets the authenticated user register their own NFC card from the mobile app.
    Body: { "uid": "A1B2C3D4", "device_type": "card" }
    """
    permission_classes = [permissions.AllowAny]
    authentication_classes = []

    def post(self, request):
        try:
            user, role = _resolve_user(request)
        except AuthenticationFailed as exc:
            return Response({'detail': str(exc)}, status=status.HTTP_401_UNAUTHORIZED)

        uid = (request.data.get('uid') or '').strip().replace(':', '').upper()
        device_type = request.data.get('device_type', 'card')

        if not uid:
            return Response({'error': 'uid is required.'}, status=400)
        if NFCDevice.objects.filter(uid=uid, is_active=True).exists():
            return Response({'error': 'UID already registered.'}, status=400)

        # Remove any previous device for this user before creating a new one
        if role == 'member':
            NFCDevice.objects.filter(member=user).delete()
        elif role == 'coach':
            NFCDevice.objects.filter(coach=user).delete()
        else:
            NFCDevice.objects.filter(admin_user=user).delete()

        create_kwargs = {'uid': uid, 'device_type': device_type, 'role': role}
        if role == 'member':
            create_kwargs['member'] = user
        elif role == 'coach':
            create_kwargs['coach'] = user
        else:
            create_kwargs['admin_user'] = user

        device = NFCDevice.objects.create(**create_kwargs)
        return Response({
            'message': 'NFC card registered successfully.',
            'uid': device.uid,
            'device_type': device.device_type,
        })


class MyAccessHistoryView(APIView):
    """
    GET /api/access/history/?limit=20
    Works for members, coaches, and admins.
    """
    permission_classes = [permissions.AllowAny]
    authentication_classes = []

    def get(self, request):
        try:
            user, role = _resolve_user(request)
        except AuthenticationFailed as exc:
            return Response({'detail': str(exc)}, status=status.HTTP_401_UNAUTHORIZED)

        try:
            limit = int(request.query_params.get('limit', 20))
        except (TypeError, ValueError):
            limit = 20
        limit = max(1, min(limit, 100))

        filter_kw = _device_filter_kwargs(role, user)
        logs = (
            AccessLog.objects
            .filter(**filter_kw)
            .select_related('device')
            .order_by('-timestamp')[:limit]
        )

        results = [
            {
                'id': log.id,
                'allowed': log.allowed,
                'reason': log.reason,
                'timestamp': log.timestamp.isoformat(),
                'device_uid': log.device.uid if log.device_id else None,
                'device_type': log.device.device_type if log.device_id else None,
            }
            for log in logs
        ]
        return Response({'results': results})


class MyNFCScanView(APIView):
    """
    POST /api/access/me/scan/
    Simulates an NFC tap using the authenticated user's own active device.
    Works for members, coaches, and admins.
    """
    permission_classes = [permissions.AllowAny]
    authentication_classes = []

    def post(self, request):
        try:
            user, role = _resolve_user(request)
        except AuthenticationFailed as exc:
            return Response({'detail': str(exc)}, status=status.HTTP_401_UNAUTHORIZED)

        if role == 'member':
            device = NFCDevice.objects.filter(member=user, role='member', is_active=True).order_by('-created_at').first()
        elif role == 'coach':
            device = NFCDevice.objects.filter(coach=user, role='coach', is_active=True).order_by('-created_at').first()
        else:
            device = NFCDevice.objects.filter(admin_user=user, role='admin', is_active=True).order_by('-created_at').first()

        if not device:
            return Response(
                {'allowed': False, 'reason': 'No NFC device assigned to this account.'},
                status=status.HTTP_404_NOT_FOUND,
            )

        # Coaches and admins: always allowed (no logging — real door reader logs)
        if role in ('coach', 'admin'):
            return Response({
                'allowed': True,
                'reason': 'Staff access granted',
                'user': user.get_full_name(),
                'role': role,
            })

        # Members: check subscription only — no AccessLog written here.
        # Only the physical door reader (POST /api/access/scan/) creates log entries.
        subscription = _active_subscription_for(user)
        if not subscription:
            return Response({'allowed': False, 'reason': 'No active subscription'})
        if not subscription.is_active():
            return Response({'allowed': False, 'reason': 'Subscription expired'})

        return Response({
            'allowed': True,
            'reason': 'Access granted',
            'user': user.get_full_name(),
            'role': role,
        })
