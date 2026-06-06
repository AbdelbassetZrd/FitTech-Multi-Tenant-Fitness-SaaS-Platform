from django.urls import path
from .views import (
    MemberRegisterView, MemberLoginView, MemberVerifyEmailView,
    MemberResendVerificationView, MemberProfileView, MemberUpdateProfileView,
    MemberPasswordChangeView, MemberPasswordResetRequestView,
    MemberPasswordResetConfirmView, member_logout_view,
    CoachLoginView, CoachProfileView, CoachUpdateProfileView,
    CoachPasswordChangeView, CoachPasswordResetRequestView,
    CoachPasswordResetConfirmView, CoachPublicListView,
    AdminCoachCreateView, AdminCoachListView, AdminCoachDetailView,
    RequestMemberOTPView, VerifyMemberOTPView, AdminLoginView,
    MemberTokenRefreshView,
    MemberGoogleAuthView, MemberGoogleAuthMobileView,
    AdminProfileView, MemberListView, AdminMemberCreateView,
    MemberSearchView, SuspendMemberView, RemoveSuspensionView,
)
from . import views

urlpatterns = [
    # ── Member auth ──────────────────────────────────────
    path('members/register/',           MemberRegisterView.as_view()),
    path('members/login/',              MemberLoginView.as_view()),
    path('members/logout/',             member_logout_view),
    path('members/verify-email/<str:key>/', MemberVerifyEmailView.as_view()),
    path('members/resend-verification/', MemberResendVerificationView.as_view()),
    path('members/profile/',            MemberProfileView.as_view()),
    path('members/profile/update/',     MemberUpdateProfileView.as_view()),
    path('members/password/change/',    MemberPasswordChangeView.as_view()),
    path('members/password/reset/',     MemberPasswordResetRequestView.as_view()),
    path('members/password/reset/confirm/', MemberPasswordResetConfirmView.as_view()),

    # ── Coach auth ───────────────────────────────────────
    path('coaches/login/',              CoachLoginView.as_view()),
    path('coaches/profile/',            CoachProfileView.as_view()),
    path('coaches/profile/update/',     CoachUpdateProfileView.as_view()),
    path('coaches/password/change/',    CoachPasswordChangeView.as_view()),
    path('coaches/password/reset/',     CoachPasswordResetRequestView.as_view()),
    path('coaches/password/reset/confirm/', CoachPasswordResetConfirmView.as_view()),
    path('coaches/public/',             CoachPublicListView.as_view()),

    # ── Admin → Coach management ─────────────────────────
    path('admin/coaches/',              AdminCoachListView.as_view()),
    path('admin/coaches/create/',       AdminCoachCreateView.as_view()),
    path('admin/coaches/<str:pk>/',     AdminCoachDetailView.as_view()),
    path('members/request-otp/', RequestMemberOTPView.as_view()),
    path('members/verify-otp/', VerifyMemberOTPView.as_view()),
    path('token/refresh/', MemberTokenRefreshView.as_view()),
    path('admin/login/', AdminLoginView.as_view(), name='admin_login'),

    # ── Google OAuth ─────────────────────────────────────
    path('members/users/auth/google/', MemberGoogleAuthView.as_view(), name='member-google-auth'),
    path('members/users/auth/google/mobile/', MemberGoogleAuthMobileView.as_view(), name='member-google-auth-mobile'),

    # ── Admin: profile + member management ──────────────
    path('admin/profile/',                              AdminProfileView.as_view(),       name='admin_profile'),
    path('admin/members/',                              MemberListView.as_view(),         name='member-list'),
    path('admin/members/create/',                       AdminMemberCreateView.as_view(),  name='member-create'),
    path('admin/members/search/',                       MemberSearchView.as_view(),       name='member-search'),
    path('admin/members/<str:pk>/suspend/',             SuspendMemberView.as_view(),      name='member-suspend'),
    path('admin/members/<str:pk>/remove-suspension/',   RemoveSuspensionView.as_view(),   name='member-remove-suspension'),
    ]