from google.oauth2 import id_token
from google.auth.transport import requests as google_requests
from django.conf import settings


def verify_google_token(token, client_id=None):
    """Verify a Google ID token and return the relevant profile fields.

    Returns ``None`` when the token is invalid (Google's library raises
    :class:`ValueError`). The optional ``client_id`` lets mobile callers pass
    the Android/iOS client id; web callers fall back to ``GOOGLE_CLIENT_ID``.
    """
    try:
        id_info = id_token.verify_oauth2_token(
            token,
            google_requests.Request(),
            client_id or settings.GOOGLE_CLIENT_ID,
        )
        return {
            'email': id_info.get('email'),
            'first_name': id_info.get('given_name', ''),
            'last_name': id_info.get('family_name', ''),
            'email_verified': id_info.get('email_verified', False),
        }
    except ValueError:
        return None
