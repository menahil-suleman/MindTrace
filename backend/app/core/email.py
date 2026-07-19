import logging

import httpx

from app.core.config import get_settings

logger = logging.getLogger(__name__)

BREVO_ENDPOINT = "https://api.brevo.com/v3/smtp/email"

# Hosted separately from the repo (Brevo needs an absolute, publicly reachable
# image URL — it can't pull from the Flutter app's local assets).
LOGO_URL = "https://i.postimg.cc/Xv0ZhNV7/mindtrace-logo.png"

# Brand colors, matching lib/core/theme.dart on the Flutter side.
_DARK_GREEN = "#163422"
_LIGHT_GREEN = "#EAF7EA"
_MUTED = "#5F5E5A"
_FOOTER_MUTED = "#888780"
_FOOTER_BG = "#F7F7F3"


def _render_reset_code_email(code: str) -> str:
    return f"""
    <div style="font-family:'Manrope',Arial,sans-serif;max-width:420px;margin:0 auto;
                background:#FFFFFF;border-radius:16px;overflow:hidden;border:1px solid #E0E0DA;">
      <div style="background:{_DARK_GREEN};padding:28px 24px;text-align:center;">
        <img src="{LOGO_URL}" alt="MindTrace" style="height:40px;" />
      </div>
      <div style="padding:32px 28px;">
        <p style="font-size:16px;color:{_DARK_GREEN};font-weight:600;margin:0 0 8px;">
          Reset your password
        </p>
        <p style="font-size:14px;color:{_MUTED};line-height:1.6;margin:0 0 24px;">
          Use the code below to continue resetting your password. This code expires in 10 minutes.
        </p>
        <div style="background:{_LIGHT_GREEN};border-radius:16px;padding:20px;text-align:center;margin:0 0 24px;">
          <span style="font-size:32px;font-weight:700;letter-spacing:8px;color:{_DARK_GREEN};">{code}</span>
        </div>
        <p style="font-size:13px;color:{_FOOTER_MUTED};line-height:1.6;margin:0;">
          If you didn't request this, you can safely ignore this email. Your password won't be changed.
        </p>
      </div>
      <div style="background:{_FOOTER_BG};padding:16px 28px;text-align:center;">
        <span style="font-size:12px;color:{_FOOTER_MUTED};">
          MindTrace &middot; non-diagnostic mental health screening
        </span>
      </div>
    </div>
    """


async def send_password_reset_email(to_email: str, code: str) -> None:
    """Send the OTP email via Brevo, or just log it if Brevo isn't configured
    (local dev without a .env entry, and CI) so nothing here needs real
    credentials or network access to run or be tested."""
    settings = get_settings()

    if not settings.brevo_api_key or not settings.brevo_sender_email:
        logger.info("Password reset code for %s: %s (Brevo not configured — not sent)", to_email, code)
        return

    payload = {
        "sender": {"name": settings.brevo_sender_name, "email": settings.brevo_sender_email},
        "to": [{"email": to_email}],
        "subject": "Your MindTrace password reset code",
        "htmlContent": _render_reset_code_email(code),
    }
    headers = {
        "api-key": settings.brevo_api_key,
        "content-type": "application/json",
        "accept": "application/json",
    }

    try:
        async with httpx.AsyncClient(timeout=10.0) as http_client:
            response = await http_client.post(BREVO_ENDPOINT, json=payload, headers=headers)
            response.raise_for_status()
    except httpx.HTTPError:
        # Don't let an email-provider outage 500 the request — the code is
        # already saved, and the person can just hit "Resend Code".
        logger.exception("Failed to send password reset email to %s via Brevo", to_email)
