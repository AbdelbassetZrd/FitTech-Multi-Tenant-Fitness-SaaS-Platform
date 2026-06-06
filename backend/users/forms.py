from django import forms

class PhoneNumberForm(forms.Form):
    phone_number = forms.CharField(
        max_length=20,
        widget=forms.TextInput(attrs={'placeholder': '+1234567890'})
    )

class OTPVerifyForm(forms.Form):
    otp_code = forms.CharField(
        max_length=6,
        min_length=6,
        widget=forms.TextInput(attrs={
            'placeholder': '6-digit code',
            'autocomplete': 'one-time-code'
        })
    )