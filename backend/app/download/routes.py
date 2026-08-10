"""
Download & join landing pages.
Handles smart OS detection for app download, web-based invite links,
and the deferred-link fallback used by the Flutter app on first launch.
"""
import os
import re

import requests
from pathlib import Path
from flask import Blueprint, request, redirect, render_template_string, Response, stream_with_context

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

_DRIVE_FILE_ID_RE = re.compile(r'(?:[/?&]id=|/d/)([a-zA-Z0-9_-]+)')


def _drive_file_id_from_apk_url(url: str) -> str | None:
    if not url:
        return None
    m = _DRIVE_FILE_ID_RE.search(url.strip())
    return m.group(1) if m else None


def _apk_public_url() -> str | None:
    """URL shown to users — proxy Drive large-file downloads through our backend."""
    raw = APK_URL.strip()
    if not raw:
        return None
    if _drive_file_id_from_apk_url(raw):
        return f"{request.url_root.rstrip('/')}/download/apk"
    return raw


def _stream_google_drive_apk(file_id: str):
    """Two-step Drive download (virus-scan interstitial bypass on server)."""
    session = requests.Session()
    session.headers.update({'User-Agent': 'ADL-ShareFlow-APK-Proxy/1.0'})
    warn = session.get(
        'https://drive.google.com/uc',
        params={'export': 'download', 'id': file_id},
        timeout=120,
    )
    warn.raise_for_status()
    uuid_m = re.search(r'name="uuid" value="([^"]+)"', warn.text)
    uuid = uuid_m.group(1) if uuid_m else 't'
    confirm_m = re.search(r'name="confirm" value="([^"]+)"', warn.text)
    confirm = confirm_m.group(1) if confirm_m else 't'
    resp = session.get(
        'https://drive.usercontent.google.com/download',
        params={
            'id': file_id,
            'export': 'download',
            'confirm': confirm,
            'uuid': uuid,
        },
        stream=True,
        timeout=600,
    )
    resp.raise_for_status()
    ct = resp.headers.get('Content-Type', '')
    if 'text/html' in ct or int(resp.headers.get('Content-Length', '999999999')) < 100_000:
        raise RuntimeError('Drive returned HTML instead of APK (check file sharing / file id)')
    filename = 'app-arm64-v8a-release.apk'
    cd = resp.headers.get('Content-Disposition', '')
    fn_m = re.search(r'filename="?([^";]+)"?', cd)
    if fn_m:
        filename = fn_m.group(1)
    return resp, filename


_PAGE_HTML = """<!DOCTYPE html>
<html lang="he" dir="rtl">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>ADL ShareFlow - הורד את האפליקציה</title>
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
    <a class="btn btn-ios" href="{{ ios_url }}">📱 iPhone - הורד דרך TestFlight</a>
    {% else %}
    <span class="btn btn-disabled">📱 iPhone - בקרוב</span>
    {% endif %}

    {% if apk_url %}
    <a class="btn btn-android" href="{{ apk_url }}">🤖 Android - הורד APK</a>
    {% else %}
    <span class="btn btn-disabled">🤖 Android - בקרוב</span>
    {% endif %}

    <p class="hint">גרסת פיילוט - ADL Projects</p>
  </div>
</body>
</html>"""


@download_bp.get('/download')
def download_page():
    """Smart download page - shows iOS + Android buttons."""
    ua = request.headers.get('User-Agent', '').lower()
    # Auto-redirect if OS is detectable
    if 'iphone' in ua or 'ipad' in ua:
        if TESTFLIGHT_URL and 'placeholder' not in TESTFLIGHT_URL:
            return redirect(TESTFLIGHT_URL)
    elif 'android' in ua:
        apk_target = _apk_public_url()
        if apk_target:
            return redirect(apk_target)

    return render_template_string(
        _PAGE_HTML,
        ios_url=TESTFLIGHT_URL if 'placeholder' not in TESTFLIGHT_URL else None,
        apk_url=_apk_public_url(),
    )


@download_bp.get('/api/deferred-link')
def deferred_link():
    """
    Called by the Flutter app on first launch as a fallback for deferred deep links.
    The clipboard method (shareflow-invite:<code>) is the primary mechanism.
    This endpoint returns None when no server-side deferred link is available.
    """
    return {'invite_code': None}


_STATIC_DIR = Path(__file__).resolve().parent.parent / 'static'

_PLACEHOLDER_TOKENS = ('placeholder', 'PLACEHOLDER')


def _valid_testflight_url() -> str | None:
    url = TESTFLIGHT_URL.strip()
    if not url or any(t in url for t in _PLACEHOLDER_TOKENS):
        return None
    return url


def _pilot_download_urls() -> dict[str, str]:
    """Resolve download URLs for pilot guide (env-driven at serve time)."""
    base = request.url_root.rstrip('/')
    download_page = f'{base}/download'
    ios = _valid_testflight_url() or download_page
    apk = _apk_public_url() or download_page
    return {
        'ios': ios,
        'download_page': download_page,
        'apk': apk,
    }


@download_bp.get('/download/apk')
def download_apk_proxy():
    """Serve Android APK — Drive is streamed (virus-scan bypass); GitHub/other redirect."""
    raw = (APK_URL or '').strip()
    if not raw:
        return Response('APK download not configured', status=503)

    file_id = _drive_file_id_from_apk_url(raw)
    if not file_id:
        # GitHub Releases / direct HTTPS — redirect (no Drive interstitial).
        return redirect(raw, code=302)

    try:
        drive_resp, filename = _stream_google_drive_apk(file_id)
    except Exception as exc:
        return Response(f'APK download failed: {exc}', status=502)

    @stream_with_context
    def generate():
        try:
            for chunk in drive_resp.iter_content(chunk_size=1024 * 256):
                if chunk:
                    yield chunk
        finally:
            drive_resp.close()

    headers = {
        'Content-Disposition': f'attachment; filename="{filename}"',
        'Cache-Control': 'no-store',
    }
    cl = drive_resp.headers.get('Content-Length')
    if cl:
        headers['Content-Length'] = cl
    return Response(
        generate(),
        mimetype='application/vnd.android.package-archive',
        headers=headers,
    )


@download_bp.get('/pilot/join')
def pilot_landing():
    """Pilot persuasion landing — decide to participate (not install)."""
    html_path = _STATIC_DIR / 'pilot_landing.html'
    html = html_path.read_text(encoding='utf-8')
    return Response(html, mimetype='text/html; charset=utf-8')


@download_bp.get('/getting-started')
def getting_started():
    """Short install + first-steps page after user opts in."""
    html_path = _STATIC_DIR / 'getting_started.html'
    html = html_path.read_text(encoding='utf-8')
    urls = _pilot_download_urls()
    html = (
        html
        .replace('__IOS_DOWNLOAD_URL__', urls['ios'])
        .replace('__DOWNLOAD_PAGE_URL__', urls['download_page'])
        .replace('__APK_DOWNLOAD_URL__', urls['apk'])
    )
    return Response(html, mimetype='text/html; charset=utf-8')


@download_bp.get('/pilot')
def pilot_onboarding():
    """Legacy full guide — redirect to the shorter getting-started flow."""
    return redirect('/getting-started', code=302)


@download_bp.get('/pilot/invite')
@download_bp.get('/invite')
def pilot_invite():
    """Legacy invite aliases — redirect to the new landing page."""
    return redirect('/pilot/join', code=302)


@download_bp.get('/privacy')
def privacy_policy():
    """Privacy policy page - required by App Store and Google Play."""
    html = """<!DOCTYPE html>
<html lang="he" dir="rtl">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>מדיניות פרטיות - ADL ShareFlow</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
      background: #f8fafc;
      color: #1e293b;
      line-height: 1.7;
      padding: 40px 24px;
      max-width: 720px;
      margin: 0 auto;
    }
    h1 { font-size: 26px; font-weight: 700; color: #1e3a8a; margin-bottom: 8px; }
    .updated { font-size: 13px; color: #64748b; margin-bottom: 32px; }
    h2 { font-size: 17px; font-weight: 600; color: #1e3a8a; margin: 28px 0 10px; }
    p, li { font-size: 15px; color: #334155; margin-bottom: 8px; }
    ul { padding-right: 20px; }
    a { color: #3b82f6; }
    .contact { background: #f0f4ff; border-radius: 12px; padding: 20px; margin-top: 32px; }
  </style>
</head>
<body>
  <h1>מדיניות פרטיות</h1>
  <p class="updated">עודכן לאחרונה: אפריל 2026</p>

  <p>
    ADL ShareFlow ("האפליקציה", "השירות") היא אפליקציה לניהול ושיתוף הוצאות בין קבוצות.
    מדיניות זו מסבירה אילו מידע אנו אוספים, כיצד אנו משתמשים בו, ואת זכויותיך.
  </p>

  <h2>מידע שאנו אוספים</h2>
  <ul>
    <li><strong>פרטי חשבון:</strong> שם תצוגה, כתובת אימייל, מספר טלפון (אופציונלי).</li>
    <li><strong>פרטי תשלום:</strong> מספר חשבון בנק, שם בנק, סניף, מספר טלפון לביט/פייבוקס - נשמרים לצרכי הסדרת חובות בין חברי הקבוצה בלבד.</li>
    <li><strong>נתוני שימוש:</strong> הוצאות, קבוצות, יתרות - נשמרים כדי לספק את שירות חלוקת ההוצאות.</li>
    <li><strong>מזהה מכשיר:</strong> FCM Token לצורך שליחת התראות Push.</li>
  </ul>

  <h2>כיצד אנו משתמשים במידע</h2>
  <ul>
    <li>מתן שירות חלוקת הוצאות בין חברי קבוצה.</li>
    <li>שליחת התראות על הוצאות חדשות, תזכורות תשלום ועדכוני קבוצה.</li>
    <li>שיפור ואבטחת השירות.</li>
  </ul>

  <h2>שיתוף מידע</h2>
  <p>
    אנו <strong>לא מוכרים</strong> מידע אישי לצדדים שלישיים.
    פרטי תשלום (בנק, Bit, PayBox) מוצגים לחברי הקבוצה שלך בלבד, לצורך הסדרת חובות.
  </p>

  <h2>אבטחה</h2>
  <p>
    המידע מוצפן בהעברה (HTTPS) ומאוחסן בשרתים מאובטחים.
    אנו משתמשים ב-JWT לאימות ו-bcrypt להצפנת סיסמאות.
  </p>

  <h2>שמירת מידע</h2>
  <p>
    נתוני קבוצה נמחקים כ-30 יום לאחר סיום הקבוצה.
    ניתן לבקש מחיקת חשבון בכל עת דרך הגדרות האפליקציה.
  </p>

  <h2>ילדים</h2>
  <p>השירות אינו מיועד לילדים מתחת לגיל 13. אנו לא אוספים מידע מילדים ביודעין.</p>

  <h2>שינויים במדיניות</h2>
  <p>כל שינוי במדיניות הפרטיות יפורסם בדף זה ויעודכן בתאריך "עודכן לאחרונה".</p>

  <div class="contact">
    <strong>יצירת קשר</strong><br>
    לשאלות בנושא פרטיות: <a href="mailto:support@adlprojects.co.il">support@adlprojects.co.il</a>
  </div>
</body>
</html>"""
    return html
