from rest_framework.permissions import BasePermission


def _get_role(request):
    """Extract role from JWT claims."""
    if request.auth and hasattr(request.auth, 'get'):
        return request.auth.get('role', None)
    # Admin uses Django session/JWT — no role claim, check is_staff
    if request.user and request.user.is_authenticated:
        return 'admin'
    return None


class IsAdminToken(BasePermission):
    """Only Django admin users (is_staff=True)."""
    message = 'Admin access required.'

    def has_permission(self, request, view):
        return (
            request.user and
            request.user.is_authenticated and
            request.user.is_staff
        )


class IsMemberToken(BasePermission):
    """Only members — checks JWT role claim."""
    message = 'Member access required.'

    def has_permission(self, request, view):
        return _get_role(request) == 'member'


class IsCoachToken(BasePermission):
    """Only coaches — checks JWT role claim."""
    message = 'Coach access required.'

    def has_permission(self, request, view):
        return _get_role(request) == 'coach'


class IsCoachOrAdmin(BasePermission):
    """Coaches and admins."""
    message = 'Coach or admin access required.'

    def has_permission(self, request, view):
        role = _get_role(request)
        return role in ('coach', 'admin') or (
            request.user and request.user.is_staff
        )


class IsMemberOrCoach(BasePermission):
    """Members and coaches — not admin."""
    message = 'Member or coach access required.'

    def has_permission(self, request, view):
        return _get_role(request) in ('member', 'coach')


class IsNotSuspended(BasePermission):
    """Block suspended members."""
    message = 'Your account is currently suspended.'

    def has_permission(self, request, view):
        role = _get_role(request)
        if role != 'member':
            return True  # only applies to members
        member_id = request.auth.get('user_id') if request.auth else None
        if not member_id:
            return False
        try:
            from users.models import Member
            member = Member.objects.get(id=member_id)
            return not member.is_suspension_active()
        except Member.DoesNotExist:
            return False