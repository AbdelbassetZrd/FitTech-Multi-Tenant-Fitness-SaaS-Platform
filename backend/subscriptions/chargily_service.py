"""
Chargily API Integration Service
Handles payment creation, verification, and webhook processing for Algerian payments
"""

import requests
import json
import hmac
import hashlib
from typing import Optional, Dict, Any
from decimal import Decimal
from django.conf import settings
from django.utils import timezone
from datetime import datetime


class ChargilyService:
    """Service to integrate with Chargily payment API"""

    # API Credentials (from environment variables)
    PUBLIC_KEY = getattr(settings, 'CHARGILY_KEY', getattr(settings, 'CHARGILY_PUBLIC_KEY', 'test_pk_Ya9tFVPBUvauUjIplUvJgBd1ItahWxhVq1xqeWRo'))
    SECRET_KEY = getattr(settings, 'CHARGILY_SECRET', getattr(settings, 'CHARGILY_SECRET_KEY', 'test_sk_EanNg5PT3auugrzxTUd3Vb53WVAMNukukyADQ77L'))
    API_BASE_URL = getattr(settings, 'CHARGILY_API_URL', getattr(settings, 'CHARGILY_URL', 'https://pay.chargily.net/test/api/v2')).rstrip('/')

    @staticmethod
    def create_payment(
        amount: Decimal,
        success_url: str,
        failure_url: str,
        description: str = "FitTech Gym Subscription",
        metadata: Optional[Dict[str, Any]] = None
    ) -> Dict[str, Any]:
        """
        Create a payment checkout with Chargily

        Args:
            amount: Payment amount in DZD (Algerian Dinar)
            success_url: URL to redirect after successful payment
            failure_url: URL to redirect after failed payment
            description: Payment description
            metadata: Additional metadata to store with payment

        Returns:
            Dict containing checkout_url and transaction_id
        """
        try:
            headers = {
                'Authorization': f'Bearer {ChargilyService.SECRET_KEY}',
                'Content-Type': 'application/json',
            }

            payload = {
                'amount': float(amount),
                'currency': 'dzd',
                'description': description,
                'success_url': success_url,
                'failure_url': failure_url,
                'metadata': metadata or {},
            }

            webhook_url = getattr(settings, 'CHARGILY_WEBHOOK_URL', '')
            if webhook_url:
                payload['webhook_endpoint'] = webhook_url

            response = requests.post(
                f'{ChargilyService.API_BASE_URL}/checkouts',
                headers=headers,
                json=payload,
                timeout=10
            )

            response.raise_for_status()
            data = response.json()

            return {
                'success': True,
                'checkout_url': data.get('checkout_url'),
                'transaction_id': data.get('id'),
                'data': data,
            }

        except requests.exceptions.RequestException as e:
            error_details = str(e)
            if hasattr(e, 'response') and e.response is not None:
                try:
                    error_details = f"{e.response.status_code} - {e.response.text}"
                except:
                    pass
            return {
                'success': False,
                'error': f'Chargily API Error: {error_details}',
            }
        except Exception as e:
            return {
                'success': False,
                'error': f'Unexpected error: {str(e)}',
            }

    @staticmethod
    def verify_payment(transaction_id: str) -> Dict[str, Any]:
        """
        Verify a payment status from Chargily

        Args:
            transaction_id: The transaction ID from Chargily

        Returns:
            Dict containing payment status and details
        """
        try:
            headers = {
                'Authorization': f'Bearer {ChargilyService.SECRET_KEY}',
                'Content-Type': 'application/json',
            }

            response = requests.get(
                f'{ChargilyService.API_BASE_URL}/checkouts/{transaction_id}',
                headers=headers,
                timeout=10
            )

            response.raise_for_status()
            data = response.json()

            return {
                'success': True,
                'status': data.get('status'),  # pending, completed, failed, etc.
                'amount': data.get('amount'),
                'currency': data.get('currency'),
                'invoice_id': data.get('invoice_id'),
                'data': data,
            }

        except requests.exceptions.RequestException as e:
            return {
                'success': False,
                'error': f'Chargily API Error: {str(e)}',
            }
        except Exception as e:
            return {
                'success': False,
                'error': f'Unexpected error: {str(e)}',
            }

    @staticmethod
    def verify_webhook_signature(payload: str, signature: str) -> bool:
        """
        Verify webhook signature from Chargily

        Args:
            payload: Raw request body as string
            signature: Signature header value

        Returns:
            True if signature is valid, False otherwise
        """
        try:
            computed_signature = hmac.new(
                ChargilyService.SECRET_KEY.encode(),
                payload.encode(),
                hashlib.sha256
            ).hexdigest()

            return computed_signature == signature
        except Exception as e:
            print(f'Webhook signature verification error: {str(e)}')
            return False

    @staticmethod
    def get_payment_status(transaction_id: str) -> Optional[str]:
        """
        Get simple payment status

        Args:
            transaction_id: Transaction ID from Chargily

        Returns:
            Payment status or None if error
        """
        result = ChargilyService.verify_payment(transaction_id)
        if result['success']:
            return result['status']
        return None

    @staticmethod
    def is_payment_successful(transaction_id: str) -> bool:
        """
        Check if payment was successful

        Args:
            transaction_id: Transaction ID from Chargily

        Returns:
            True if payment status is 'completed', False otherwise
        """
        status = ChargilyService.get_payment_status(transaction_id)
        return status == 'completed'
