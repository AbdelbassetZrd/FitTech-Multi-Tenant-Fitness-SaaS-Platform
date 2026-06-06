from django.urls import path
from .views import (
    NFCScanView,
    CaptureUIDView,
    AssignNFCDeviceView,
    DeactivateNFCDeviceView,
    ListNFCDevicesView,
    MyAccessStatusView,
    MyAccessHistoryView,
    MyNFCScanView,
    MeRegisterCardView,
)

urlpatterns = [
    # Called by the physical NFC reader device (no auth required)
    path('scan/', NFCScanView.as_view(), name='nfc-scan'),
    path('capture-uid/', CaptureUIDView.as_view(), name='nfc-capture-uid'),

    # Admin management
    path("assign/", AssignNFCDeviceView.as_view(), name="nfc-assign"),
    path("deactivate/", DeactivateNFCDeviceView.as_view(), name="nfc-deactivate"),
    path("devices/", ListNFCDevicesView.as_view(), name="nfc-devices"),

    # Mobile app endpoints (member / coach / admin)
    path("me/", MyAccessStatusView.as_view(), name="access-me"),
    path("me/scan/", MyNFCScanView.as_view(), name="access-me-scan"),
    path("me/register-card/", MeRegisterCardView.as_view(), name="access-me-register-card"),
    path("history/", MyAccessHistoryView.as_view(), name="access-history"),
]