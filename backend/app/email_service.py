"""
Email delivery via Resend API.
Configure RESEND_API_KEY in environment variables to enable.
"""
import os
import resend

_RESEND_API_KEY = os.getenv('RESEND_API_KEY', '')
_SENDER_NAME = os.getenv('SMTP_SENDER_NAME', 'ADL ShareFlow')
_FROM_EMAIL = os.getenv('RESEND_FROM_EMAIL', 'onboarding@resend.dev')


def _is_configured() -> bool:
    return bool(_RESEND_API_KEY)


def _send(to_email: str, subject: str, html: str) -> bool:
    if not _is_configured():
        print('[email_service] RESEND_API_KEY is not configured')
        return False
    try:
        resend.api_key = _RESEND_API_KEY
        resend.Emails.send({
            'from': f'{_SENDER_NAME} <{_FROM_EMAIL}>',
            'to': [to_email],
            'subject': subject,
            'html': html,
        })
        return True
    except Exception as e:
        print(f'[email_service] Failed to send email: {e}')
        return False


def send_group_invitation(
    *,
    to_email: str,
    inviter_name: str,
    group_name: str,
    invite_code: str,
    group_emoji: str = '👥',
) -> bool:
    """
    Send a group invitation email via Resend.
    Returns True on success, False if not configured or send fails.
    """
    join_url = f'https://adlshareflow-production.up.railway.app/join/{invite_code}'
    subject = f'{inviter_name} הזמין אותך להצטרף לקבוצה "{group_name}"'

    html = f"""
<!DOCTYPE html>
<html dir="rtl" lang="he">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{subject}</title>
</head>
<body style="margin:0;padding:0;background:#f5f5f7;font-family:system-ui,-apple-system,sans-serif;direction:rtl;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#f5f5f7;padding:40px 0;">
    <tr>
      <td align="center">
        <table width="560" cellpadding="0" cellspacing="0"
               style="background:#ffffff;border-radius:20px;overflow:hidden;box-shadow:0 4px 20px rgba(0,0,0,0.08);">
          <tr>
            <td style="background:linear-gradient(135deg,#6366F1,#8B5CF6);padding:36px 32px;text-align:center;">
              <div style="font-size:48px;margin-bottom:8px;">{group_emoji}</div>
              <h1 style="margin:0;color:#ffffff;font-size:24px;font-weight:700;">ADL ShareFlow</h1>
              <p style="margin:8px 0 0;color:rgba(255,255,255,0.8);font-size:14px;">
                חלוקת הוצאות בקלות
              </p>
            </td>
          </tr>
          <tr>
            <td style="padding:36px 32px;">
              <h2 style="margin:0 0 12px;font-size:22px;color:#1a1a2e;font-weight:700;">
                הוזמנת להצטרף לקבוצה!
              </h2>
              <p style="margin:0 0 24px;font-size:16px;color:#444;line-height:1.6;">
                <strong>{inviter_name}</strong> הזמין אותך להצטרף לקבוצה
                <strong>"{group_name}"</strong> ב-ADL ShareFlow.
              </p>
              <div style="background:#f0f0ff;border:2px dashed #6366F1;border-radius:16px;
                          padding:24px;text-align:center;margin-bottom:28px;">
                <p style="margin:0 0 8px;font-size:13px;color:#666;">קוד הצטרפות</p>
                <div style="font-size:36px;font-weight:800;color:#6366F1;letter-spacing:8px;">
                  {invite_code}
                </div>
              </div>
              <div style="text-align:center;margin-bottom:24px;">
                <a href="{join_url}"
                   style="display:inline-block;background:linear-gradient(135deg,#6366F1,#8B5CF6);
                          color:#ffffff;text-decoration:none;font-size:16px;font-weight:700;
                          padding:14px 36px;border-radius:50px;">
                  הצטרף עכשיו
                </a>
              </div>
              <p style="margin:0 0 28px;font-size:13px;color:#888;text-align:center;">
                אם הכפתור לא עובד, העתק את הקוד <strong>{invite_code}</strong>
                ישירות לאפליקציה.
              </p>
              <div style="background:#f8f8f8;border-radius:14px;padding:20px;text-align:center;">
                <p style="margin:0 0 12px;font-size:13px;color:#666;font-weight:600;">
                  עדיין אין לך את האפליקציה?
                </p>
                <a href="{join_url}"
                   style="display:inline-block;background:#1a1a2e;color:#ffffff;
                          text-decoration:none;font-size:14px;font-weight:600;
                          padding:12px 28px;border-radius:50px;">
                  הורד את ADL ShareFlow
                </a>
              </div>
            </td>
          </tr>
          <tr>
            <td style="padding:20px 32px;background:#fafafa;border-top:1px solid #eee;
                        text-align:center;">
              <p style="margin:0;font-size:12px;color:#aaa;">
                ADL ShareFlow · adl.co.il
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
"""
    return _send(to_email, subject, html)
