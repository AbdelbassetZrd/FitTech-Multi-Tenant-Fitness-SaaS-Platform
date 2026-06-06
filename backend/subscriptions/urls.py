from django.urls import path
from . import views

urlpatterns = [

    # ── Plans (members) ──────────────────────────────────────────────────────
    path('plans/', views.SubscriptionPlanListView.as_view(), name='plan_list'),

    # ── Subscriptions (members) ───────────────────────────────────────────────
    path('subscribe/', views.SubscribeView.as_view(), name='subscribe'),
    path('my/', views.MySubscriptionView.as_view(), name='my_subscription'),
    path('history/', views.SubscriptionHistoryView.as_view(), name='subscription_history'),
    path('pause/', views.PauseSubscriptionView.as_view(), name='pause_subscription'),
    path('resume/', views.ResumeSubscriptionView.as_view(), name='resume_subscription'),
    path('cancel/', views.CancelSubscriptionView.as_view(), name='cancel_subscription'),

    # ── Payments (members) ────────────────────────────────────────────────────
    path('payments/', views.PaymentHistoryView.as_view(), name='payment_history'),
    path('payments/pay/', views.PaymentCreateView.as_view(), name='payment_create'),
    path('payments/<int:pk>/', views.PaymentDetailView.as_view(), name='payment_detail'),

    # ── Chargily Integration ──────────────────────────────────────────────────
    path('chargily/initiate/', views.InitiateChargilyPaymentView.as_view(), name='initiate_chargily_payment'),
    path('chargily/verify/', views.VerifyChargilyPaymentView.as_view(), name='verify_chargily_payment'),
    path('chargily/status/', views.CheckSubscriptionStatusView.as_view(), name='check_subscription_status'),
    path('chargily/webhook/', views.ChargilyWebhookView.as_view(), name='chargily_webhook'),

    # ── Payment redirect pages (detected by Flutter WebView) ──────────────────
    path('payment-success/', views.PaymentSuccessRedirectView.as_view(), name='payment_success'),
    path('payment-failure/', views.PaymentFailureRedirectView.as_view(), name='payment_failure'),

    # ── Invoices (members) ────────────────────────────────────────────────────
    path('invoices/', views.InvoiceListView.as_view(), name='invoice_list'),
    path('invoices/<int:pk>/', views.InvoiceDetailView.as_view(), name='invoice_detail'),

    # ── Admin — plans ─────────────────────────────────────────────────────────
    path('admin/plans/', views.SubscriptionPlanAdminListCreateView.as_view(), name='admin_plan_list'),
    path('admin/plans/<int:pk>/', views.SubscriptionPlanAdminDetailView.as_view(), name='admin_plan_detail'),

    # ── Admin — subscriptions & payments ─────────────────────────────────────
    path('admin/subscriptions/', views.AdminSubscriptionListView.as_view(), name='admin_subscription_list'),
    path('admin/subscriptions/create/', views.AdminCreateSubscriptionView.as_view(), name='admin_create_subscription'),
    path('admin/subscriptions/<int:pk>/cancel/', views.AdminCancelSubscriptionView.as_view(), name='admin_cancel_subscription'),
    path('admin/subscriptions/<int:pk>/update-plan/', views.AdminUpdateSubscriptionPlanView.as_view(), name='admin_update_subscription_plan'),
    path('admin/payments/', views.AdminPaymentListView.as_view(), name='admin_payment_list'),
    path('admin/payments/<int:pk>/', views.AdminPaymentDetailView.as_view(), name='admin_payment_detail'),
]