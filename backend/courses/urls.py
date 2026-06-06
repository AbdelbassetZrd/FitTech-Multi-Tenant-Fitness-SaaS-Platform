from django.urls import path
from .views import (
    # Admin — Course
    AdminCourseListView,
    AdminCourseCreateView,
    AdminCourseDetailView,
    # Admin — Salles
    AdminSalleListView,
    AdminSalleCreateView,
    AdminSalleDetailView,
    # Admin — Session
    AdminSessionListView,
    AdminSessionCreateView,
    AdminSessionDetailView,
    # Member
    CourseListView,
    CourseBookView,
    CourseCancelView,
    SessionListView,
    SessionBookView,
    SessionCancelView,
    MemberBookingsView,
    CoachSessionOverviewView,
    CoachMarkAttendanceView,
    CoachSessionStatsView,
    CoachEarningsDashboardView,
    CoachCourseListView,
    CoachCourseDetailView,
    MemberActivityDashboardView,
    AbsenceWarningListView,
    InitiateCoursePaymentView,
    VerifyCoursePaymentView,
)

urlpatterns = [

    # ── Member: browse ────────────────────────────────────────────────
    # GET  /api/courses/list/
    path('list/', CourseListView.as_view(), name='course-list'),

    # POST /api/courses/<pk>/book/
    path('<int:pk>/book/', CourseBookView.as_view(), name='course-book'),

    # POST /api/courses/<int:pk>/cancel/
    path('<int:pk>/cancel/', CourseCancelView.as_view(), name='course-cancel'),

    # GET  /api/courses/sessions/          (upcoming, optionally ?course=<id>)
    path('sessions/', SessionListView.as_view(), name='session-list'),

    # POST /api/courses/sessions/<pk>/book/
    path('sessions/<int:pk>/book/', SessionBookView.as_view(), name='session-book'),

    # POST /api/courses/sessions/<pk>/cancel/
    path('sessions/<int:pk>/cancel/', SessionCancelView.as_view(), name='session-cancel'),

    # GET  /api/courses/my-bookings/
    path('my-bookings/', MemberBookingsView.as_view(), name='member-bookings'),

    # ── Admin: course management ──────────────────────────────────────
    # GET  /api/courses/admin/courses/
    path('admin/courses/', AdminCourseListView.as_view(), name='admin-course-list'),

    # POST /api/courses/admin/courses/create/
    path('admin/courses/create/', AdminCourseCreateView.as_view(), name='admin-course-create'),

    # GET / PATCH / DELETE  /api/courses/admin/courses/<pk>/
    path('admin/courses/<int:pk>/', AdminCourseDetailView.as_view(), name='admin-course-detail'),

    # ── Admin: session management ─────────────────────────────────────
    # GET  /api/courses/admin/sessions/    (optionally ?course=<id>)
    path('admin/sessions/', AdminSessionListView.as_view(), name='admin-session-list'),

    # POST /api/courses/admin/sessions/create/
    path('admin/sessions/create/', AdminSessionCreateView.as_view(), name='admin-session-create'),

    # GET / PATCH / DELETE  /api/courses/admin/sessions/<pk>/
    path('admin/sessions/<int:pk>/', AdminSessionDetailView.as_view(), name='admin-session-detail'),

    # ── Admin: salle management ───────────────────────────────────────
    # GET  /api/courses/admin/salles/
    path('admin/salles/', AdminSalleListView.as_view(), name='admin-salle-list'),
    
    # POST /api/courses/admin/salles/create/
    path('admin/salles/create/', AdminSalleCreateView.as_view(), name='admin-salle-create'),
    
    # GET / PATCH / DELETE  /api/courses/admin/salles/<pk>/
    path('admin/salles/<int:pk>/', AdminSalleDetailView.as_view(), name='admin-salle-detail'),

    # ── Coach ────────────────────────────────────────────────────────
    # GET  /api/courses/coach/sessions/
    path('coach/sessions/', CoachSessionOverviewView.as_view(), name='coach-session-overview'),

    # POST /api/courses/sessions/<pk>/attendance/
    path('sessions/<int:pk>/attendance/', CoachMarkAttendanceView.as_view(), name='coach-mark-attendance'),
    
    # GET  /api/courses/coach/sessions/stats/
    path('coach/sessions/stats/', CoachSessionStatsView.as_view(), name='coach-session-stats'),
    
    # GET  /api/courses/coach/earnings/
    path('coach/earnings/', CoachEarningsDashboardView.as_view(), name='coach-earnings'),

    # GET /api/courses/coach/courses/  (list coach's courses)
    path('coach/courses/', CoachCourseListView.as_view(), name='coach-course-list'),

    # GET /api/courses/coach/courses/<pk>/  (course detail for coach)
    path('coach/courses/<int:pk>/', CoachCourseDetailView.as_view(), name='coach-course-detail'),

    # ── Member Dashobard & Absence Warnings ──────────────────────────
    # GET  /api/courses/member/dashboard/
    path('member/dashboard/', MemberActivityDashboardView.as_view(), name='member-dashboard'),
    
    # GET  /api/courses/absence-warnings/
    path('absence-warnings/', AbsenceWarningListView.as_view(), name='absence-warnings'),

    # ── Course Payments (Chargily) ────────────────────────────────────
    # POST /api/courses/<pk>/initiate-payment/
    path('<int:pk>/initiate-payment/', InitiateCoursePaymentView.as_view(), name='course-initiate-payment'),

    # POST /api/courses/verify-course-payment/
    path('verify-course-payment/', VerifyCoursePaymentView.as_view(), name='course-verify-payment'),
]