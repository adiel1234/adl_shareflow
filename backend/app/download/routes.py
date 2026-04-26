"""
Download & join landing pages.
Handles smart OS detection for app download, web-based invite links,
and the deferred-link fallback used by the Flutter app on first launch.
"""
import os
from flask import Blueprint, request, redirect, render_template_string

download_bp = Blueprint('download', __name__)

# Configured via environment variables on Railway
TESTFLIGHT_URL = os.environ.get(
    'TESTFLIGHT_URL',
    'https://testflight.apple.com/join/placeholder'
)
APK_URL = os.environ.get(
    'APK_DOWNLOAD_URL',
    ''
)

_PAGE_HTML = """<!DOCTYPE html>
<html lang="he" dir="rtl">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>ADL ShareFlow — הורד את האפליקציה</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
      background: #f0f4ff;
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 24px;
    }
    .card {
      background: white;
      border-radius: 24px;
      padding: 40px 32px;
      max-width: 400px;
      width: 100%;
      text-align: center;
      box-shadow: 0 8px 32px rgba(0,0,0,0.08);
    }
    .logo { font-size: 48px; margin-bottom: 12px; }
    h1 { font-size: 22px; font-weight: 700; color: #1e3a8a; margin-bottom: 8px; }
    p { color: #64748b; font-size: 15px; margin-bottom: 32px; line-height: 1.5; }
    .btn {
      display: block;
      width: 100%;
      padding: 16px;
      border-radius: 14px;
      font-size: 16px;
      font-weight: 600;
      text-decoration: none;
      margin-bottom: 12px;
      cursor: pointer;
      border: none;
    }
    .btn-ios { background: #1e3a8a; color: white; }
    .btn-android { background: #15803d; color: white; }
    .btn-disabled { background: #e2e8f0; color: #94a3b8; cursor: not-allowed; }
    .hint { font-size: 12px; color: #94a3b8; margin-top: 16px; }
  </style>
</head>
<body>
  <div class="card">
    <div class="logo">💸</div>
    <h1>ADL ShareFlow</h1>
    <p>שיתוף הוצאות קל ומהיר עם חברים ומשפחה</p>

    {% if ios_url %}
    <a class="btn btn-ios" href="{{ ios_url }}">📱 iPhone — הורד דרך TestFlight</a>
    {% else %}
    <span class="btn btn-disabled">📱 iPhone — בקרוב</span>
    {% endif %}

    {% if apk_url %}
    <a class="btn btn-android" href="{{ apk_url }}">🤖 Android — הורד APK</a>
    {% else %}
    <span class="btn btn-disabled">🤖 Android — בקרוב</span>
    {% endif %}

    <p class="hint">גרסת פיילוט — ADL Projects</p>
  </div>
</body>
</html>"""


@download_bp.get('/download')
def download_page():
    """Smart download page — shows iOS + Android buttons."""
    ua = request.headers.get('User-Agent', '').lower()
    # Auto-redirect if OS is detectable
    if 'iphone' in ua or 'ipad' in ua:
        if TESTFLIGHT_URL and 'placeholder' not in TESTFLIGHT_URL:
            return redirect(TESTFLIGHT_URL)
    elif 'android' in ua:
        if APK_URL:
            return redirect(APK_URL)

    return render_template_string(
        _PAGE_HTML,
        ios_url=TESTFLIGHT_URL if 'placeholder' not in TESTFLIGHT_URL else None,
        apk_url=APK_URL or None,
    )


@download_bp.get('/join/<invite_code>')
def join_page(invite_code: str):
    """
    Web invite link: https://<host>/join/<code>
    Writes the invite code to the clipboard via JS and redirects to /download.
    Flutter reads 'shareflow-invite:<code>' from clipboard on first launch.
    """
    code = invite_code.upper()
    html = f"""<!DOCTYPE html>
<html lang="he" dir="rtl">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>הצטרף ל-ADL ShareFlow</title>
  <style>
    body {{ font-family: -apple-system, sans-serif; text-align: center;
           padding: 60px 24px; background: #f0f4ff; }}
    h1 {{ color: #1e3a8a; font-size: 24px; margin-bottom: 12px; }}
    p  {{ color: #64748b; margin-bottom: 32px; }}
    .btn {{ display: inline-block; background: #1e3a8a; color: white;
            padding: 16px 32px; border-radius: 14px; text-decoration: none;
            font-size: 16px; font-weight: 600; }}
  </style>
</head>
<body>
  <h1>💸 ADL ShareFlow</h1>
  <p>קיבלת הזמנה להצטרף לקבוצה!<br>הורד את האפליקציה כדי להצטרף.</p>
  <a class="btn" href="/download">הורד את האפליקציה</a>
  <script>
    // Write the invite code to clipboard so Flutter can read it on first launch
    try {{
      navigator.clipboard.writeText('shareflow-invite:{code}').catch(function() {{}});
    }} catch(e) {{}}
  </script>
</body>
</html>"""
    return html


@download_bp.get('/api/deferred-link')
def deferred_link():
    """
    Called by the Flutter app on first launch as a fallback for deferred deep links.
    The clipboard method (shareflow-invite:<code>) is the primary mechanism.
    This endpoint returns None when no server-side deferred link is available.
    """
    return {'invite_code': None}
