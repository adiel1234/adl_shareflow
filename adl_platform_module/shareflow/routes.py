"""
ADL ShareFlow — ADL Platform Admin Module
=========================================
Integration with existing ADL Dashboard (garage_system).

שילוב:
1. ב-garage_system/adl_platform/app/__init__.py:
   from adl_shareflow_module.shareflow.routes import shareflow_bp
   app.register_blueprint(shareflow_bp, url_prefix='/shareflow')

2. הוספת רשומה לטבלת המערכות (adl_control DB):
   INSERT INTO systems (name, code, base_url, status)
   VALUES ('ADL ShareFlow', 'shareflow', 'http://localhost:5050', 'active');

3. הוספת משתני סביבה ל-.env של adl_platform:
   SHAREFLOW_API_URL=http://localhost:5050/api
   SHAREFLOW_ADMIN_KEY=your-secret-admin-key
"""
import os
import urllib.request
import urllib.parse
import json
from functools import wraps
from flask import Blueprint, render_template_string, session, redirect, url_for, request

shareflow_bp = Blueprint('shareflow', __name__)

SHAREFLOW_API = os.getenv('SHAREFLOW_API_URL', 'http://localhost:5050/api')
SHAREFLOW_ADMIN_KEY = os.getenv('SHAREFLOW_ADMIN_KEY', '')


def _adl_headers():
    return {'X-ADL-Admin-Key': SHAREFLOW_ADMIN_KEY}


def _api_get(path: str, params: dict = None) -> dict:
    url = f'{SHAREFLOW_API}{path}'
    if params:
        url += '?' + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers=_adl_headers())
    try:
        with urllib.request.urlopen(req, timeout=5) as resp:
            return json.loads(resp.read()).get('data', {})
    except Exception:
        return {}


def _api_put(path: str, body: dict = None) -> dict:
    url = f'{SHAREFLOW_API}{path}'
    data = json.dumps(body or {}).encode()
    req = urllib.request.Request(
        url, data=data, method='PUT',
        headers={**_adl_headers(), 'Content-Type': 'application/json'},
    )
    try:
        with urllib.request.urlopen(req, timeout=5) as resp:
            return json.loads(resp.read())
    except Exception:
        return {}


def _api_post(path: str, body: dict = None) -> dict:
    url = f'{SHAREFLOW_API}{path}'
    data = json.dumps(body or {}).encode()
    req = urllib.request.Request(
        url, data=data, method='POST',
        headers={**_adl_headers(), 'Content-Type': 'application/json'},
    )
    try:
        with urllib.request.urlopen(req, timeout=5) as resp:
            return json.loads(resp.read())
    except Exception:
        return {}


def _login_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        if not session.get('adl_logged_in'):
            return redirect(url_for('adl.login'))
        return f(*args, **kwargs)
    return decorated


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

@shareflow_bp.get('/')
@_login_required
def dashboard():
    stats = _api_get('/adl/stats')
    return render_template_string(DASHBOARD_TEMPLATE, stats=stats)


@shareflow_bp.get('/users')
@_login_required
def users():
    page = request.args.get('page', 1, type=int)
    search = request.args.get('search', '')
    data = _api_get('/adl/users', {'page': page, 'per_page': 50, 'search': search})
    return render_template_string(USERS_TEMPLATE, data=data, page=page, search=search)


@shareflow_bp.post('/users/<user_id>/suspend')
@_login_required
def suspend_user(user_id):
    _api_put(f'/adl/users/{user_id}/suspend')
    return redirect(url_for('shareflow.users'))


@shareflow_bp.post('/users/<user_id>/activate')
@_login_required
def activate_user(user_id):
    _api_put(f'/adl/users/{user_id}/activate')
    return redirect(url_for('shareflow.users'))


@shareflow_bp.post('/users/<user_id>/set-plan')
@_login_required
def set_plan(user_id):
    plan = request.form.get('plan', 'free')
    _api_put(f'/adl/users/{user_id}/set-plan', {'plan': plan})
    return redirect(url_for('shareflow.users'))


@shareflow_bp.get('/groups')
@_login_required
def groups():
    page = request.args.get('page', 1, type=int)
    data = _api_get('/adl/groups', {'page': page, 'per_page': 50})
    return render_template_string(GROUPS_TEMPLATE, data=data, page=page)


@shareflow_bp.get('/ocr-stats')
@_login_required
def ocr_stats():
    stats = _api_get('/adl/ocr-stats')
    return render_template_string(OCR_TEMPLATE, stats=stats)


@shareflow_bp.get('/monetization')
@_login_required
def monetization():
    state = request.args.get('state', '')
    page = request.args.get('page', 1, type=int)
    params = {'page': page, 'per_page': 50}
    if state:
        params['state'] = state
    data = _api_get('/adl/monetization', params)
    stats = _api_get('/adl/stats')
    sf = stats.get('shareflow', {})
    return render_template_string(MONETIZATION_TEMPLATE,
                                  data=data, sf=sf, page=page, state=state)


@shareflow_bp.post('/groups/<group_id>/activate')
@_login_required
def activate_group(group_id):
    split = request.form.get('split', 'false') == 'true'
    _api_post(f'/adl/groups/{group_id}/activate', {'split_among_group': split})
    return redirect(url_for('shareflow.monetization'))


@shareflow_bp.get('/feature-flags')
@_login_required
def feature_flags():
    data = _api_get('/adl/feature-flags')
    return render_template_string(FLAGS_TEMPLATE, flags=data.get('flags', []))


@shareflow_bp.post('/feature-flags/<key>')
@_login_required
def update_flag(key):
    value = request.form.get('value', '')
    description = request.form.get('description', '')
    _api_put(f'/adl/feature-flags/{key}', {'value': value, 'description': description})
    return redirect(url_for('shareflow.feature_flags'))


# ---------------------------------------------------------------------------
# Templates
# ---------------------------------------------------------------------------

_NAV = """
<style>
  * { box-sizing: border-box; }
  body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; direction: rtl; background: #f8fafc; margin: 0; }
  .sf-nav { background: linear-gradient(135deg,#1e40af,#059669); color: #fff; padding: 12px 24px; display: flex; align-items: center; gap: 16px; }
  .sf-nav a { color: rgba(255,255,255,0.85); text-decoration: none; font-size: 14px; padding: 6px 12px; border-radius: 6px; transition: background 0.2s; }
  .sf-nav a:hover, .sf-nav a.active { background: rgba(255,255,255,0.15); color: #fff; }
  .sf-nav .brand { font-weight: 700; font-size: 16px; margin-left: auto; }
  .sf-page { padding: 28px 32px; max-width: 1280px; margin: 0 auto; }
  .sf-card { background: #fff; border: 1px solid #e2e8f0; border-radius: 14px; padding: 24px; }
  .sf-grid { display: grid; gap: 16px; }
  .sf-grid-3 { grid-template-columns: repeat(3,1fr); }
  .sf-grid-2 { grid-template-columns: repeat(2,1fr); }
  .sf-stat { background: #fff; border: 1px solid #e2e8f0; border-radius: 14px; padding: 20px; }
  .sf-stat .val { font-size: 2rem; font-weight: 700; color: #1e40af; }
  .sf-stat .lbl { color: #64748b; font-size: 0.875rem; margin-top: 4px; }
  .sf-table { width: 100%; border-collapse: collapse; }
  .sf-table th { background: #1e293b; color: #fff; padding: 10px 14px; text-align: right; font-size: 13px; }
  .sf-table td { padding: 10px 14px; border-bottom: 1px solid #f1f5f9; font-size: 13px; }
  .sf-table tr:hover td { background: #f8fafc; }
  .badge { display: inline-block; padding: 2px 10px; border-radius: 20px; font-size: 12px; font-weight: 600; }
  .badge-free { background: #dbeafe; color: #1e40af; }
  .badge-pro { background: #d1fae5; color: #059669; }
  .badge-active { background: #d1fae5; color: #059669; }
  .badge-inactive { background: #fee2e2; color: #dc2626; }
  .btn { display: inline-block; padding: 6px 14px; border-radius: 7px; font-size: 12px; font-weight: 600; cursor: pointer; border: none; text-decoration: none; }
  .btn-primary { background: #1e40af; color: #fff; }
  .btn-danger { background: #dc2626; color: #fff; }
  .btn-success { background: #059669; color: #fff; }
  .btn-sm { padding: 4px 10px; font-size: 11px; }
  h1 { font-size: 1.5rem; font-weight: 700; color: #0f172a; margin: 0 0 24px; }
  h2 { font-size: 1.2rem; font-weight: 600; color: #0f172a; margin: 0 0 16px; }
  .input { border: 1px solid #e2e8f0; border-radius: 8px; padding: 8px 12px; font-size: 13px; }
  form { display: inline; }
</style>
<nav class="sf-nav">
  <span class="brand">📊 ShareFlow Admin</span>
  <a href="{{ url_for('shareflow.dashboard') }}" class="{{ 'active' if request.endpoint=='shareflow.dashboard' else '' }}">דשבורד</a>
  <a href="{{ url_for('shareflow.users') }}" class="{{ 'active' if request.endpoint=='shareflow.users' else '' }}">משתמשים</a>
  <a href="{{ url_for('shareflow.groups') }}" class="{{ 'active' if request.endpoint=='shareflow.groups' else '' }}">קבוצות</a>
  <a href="{{ url_for('shareflow.ocr_stats') }}" class="{{ 'active' if request.endpoint=='shareflow.ocr_stats' else '' }}">OCR</a>
  <a href="{{ url_for('shareflow.monetization') }}" class="{{ 'active' if request.endpoint=='shareflow.monetization' else '' }}">מונטיזציה</a>
  <a href="{{ url_for('shareflow.feature_flags') }}" class="{{ 'active' if request.endpoint=='shareflow.feature_flags' else '' }}">Feature Flags</a>
</nav>
"""

DASHBOARD_TEMPLATE = _NAV + """
<div class="sf-page">
  <h1>📊 ADL ShareFlow — סקירה כללית</h1>

  <h2>👥 משתמשים</h2>
  <div class="sf-grid sf-grid-3" style="margin-bottom:24px">
    {% for label, val, color in [
      ('סה"כ משתמשים', stats.get('users',{}).get('total',0), '#1e40af'),
      ('משתמשים פעילים', stats.get('users',{}).get('active',0), '#059669'),
      ('Pro', stats.get('users',{}).get('pro',0), '#7c3aed'),
      ('חדשים (30 יום)', stats.get('users',{}).get('new_30d',0), '#0891b2'),
      ('חדשים (7 ימים)', stats.get('users',{}).get('new_7d',0), '#0891b2'),
      ('Free', stats.get('users',{}).get('free',0), '#64748b'),
    ] %}
    <div class="sf-stat"><div class="val" style="color:{{ color }}">{{ val }}</div><div class="lbl">{{ label }}</div></div>
    {% endfor %}
  </div>

  <h2>📋 הוצאות וקבוצות</h2>
  <div class="sf-grid sf-grid-3" style="margin-bottom:24px">
    {% for label, val, color in [
      ('קבוצות פעילות', stats.get('groups',{}).get('total',0), '#1e40af'),
      ('קבוצות פעילות (30י)', stats.get('groups',{}).get('active_30d',0), '#059669'),
      ('סה"כ הוצאות', stats.get('expenses',{}).get('total',0), '#0891b2'),
      ('הוצאות (30 יום)', stats.get('expenses',{}).get('last_30d',0), '#7c3aed'),
      ('נפח כולל (₪)', '%.0f'|format(stats.get('expenses',{}).get('total_volume_ils',0)), '#059669'),
      ('הסדרים מאושרים', stats.get('settlements',{}).get('confirmed',0), '#059669'),
    ] %}
    <div class="sf-stat"><div class="val" style="color:{{ color }}">{{ val }}</div><div class="lbl">{{ label }}</div></div>
    {% endfor %}
  </div>

  <h2>📷 OCR</h2>
  <div class="sf-grid sf-grid-3" style="margin-bottom:24px">
    {% for label, val, color in [
      ('סריקות כולל', stats.get('ocr',{}).get('total_scans',0), '#1e40af'),
      ('מאושרות', stats.get('ocr',{}).get('confirmed',0), '#059669'),
      ('אחוז הצלחה', str(stats.get('ocr',{}).get('success_rate',0))+'%', '#7c3aed'),
    ] %}
    <div class="sf-stat"><div class="val" style="color:{{ color }}">{{ val }}</div><div class="lbl">{{ label }}</div></div>
    {% endfor %}
  </div>

  <h2>💰 מונטיזציה</h2>
  <div class="sf-grid sf-grid-3" style="margin-bottom:24px">
    {% set sf = stats.get('shareflow', {}) %}
    {% for label, val, color in [
      ('קבוצות חינמיות', sf.get('groups_free',0), '#1e40af'),
      ('ממתינות להפעלה', sf.get('groups_limited',0), '#d97706'),
      ('פעילות (אירוע)', sf.get('groups_active_event',0), '#059669'),
      ('פעילות (שוטפות)', sf.get('groups_active_ongoing',0), '#059669'),
      ('אחוז המרה', sf.get('upgrade_conversion_rate','0%'), '#0891b2'),
      ('הכנסות 30י (₪)', '%.0f'|format(sf.get('revenue_30d_ils',0)), '#7c3aed'),
    ] %}
    <div class="sf-stat"><div class="val" style="color:{{ color }}">{{ val }}</div><div class="lbl">{{ label }}</div></div>
    {% endfor %}
  </div>

  <div style="display:flex;gap:12px;flex-wrap:wrap">
    <a href="{{ url_for('shareflow.users') }}" class="btn btn-primary">ניהול משתמשים</a>
    <a href="{{ url_for('shareflow.groups') }}" class="btn btn-primary">ניהול קבוצות</a>
    <a href="{{ url_for('shareflow.monetization') }}" class="btn" style="background:#059669;color:#fff">מונטיזציה</a>
    <a href="{{ url_for('shareflow.ocr_stats') }}" class="btn btn-success">סטטיסטיקות OCR</a>
    <a href="{{ url_for('shareflow.feature_flags') }}" class="btn" style="background:#7c3aed;color:#fff">Feature Flags</a>
  </div>
</div>
"""

USERS_TEMPLATE = _NAV + """
<div class="sf-page">
  <h1>👥 משתמשי ShareFlow</h1>
  <div style="margin-bottom:16px;display:flex;gap:12px;align-items:center">
    <form method="get">
      <input class="input" name="search" placeholder="חפש לפי שם / אימייל" value="{{ search }}" style="width:260px">
      <button class="btn btn-primary" style="margin-right:8px">חפש</button>
    </form>
    <span style="color:#64748b;font-size:13px">{{ data.get('pagination',{}).get('total',0) }} משתמשים</span>
  </div>
  <div class="sf-card" style="padding:0;overflow:hidden">
    <table class="sf-table">
      <thead>
        <tr>
          <th>שם</th><th>אימייל</th><th style="text-align:center">תוכנית</th>
          <th style="text-align:center">סטטוס</th><th style="text-align:center">נרשם</th><th style="text-align:center">פעולות</th>
        </tr>
      </thead>
      <tbody>
        {% for user in data.get('users', []) %}
        <tr>
          <td><strong>{{ user.display_name }}</strong></td>
          <td style="direction:ltr">{{ user.email }}</td>
          <td style="text-align:center">
            <span class="badge {{ 'badge-pro' if user.plan=='pro' else 'badge-free' }}">{{ user.plan }}</span>
          </td>
          <td style="text-align:center">
            <span class="badge {{ 'badge-active' if user.is_active else 'badge-inactive' }}">
              {{ 'פעיל' if user.is_active else 'מושעה' }}
            </span>
          </td>
          <td style="text-align:center;color:#64748b;font-size:12px">
            {{ user.created_at[:10] if user.created_at else '-' }}
          </td>
          <td style="text-align:center">
            <div style="display:flex;gap:6px;justify-content:center;flex-wrap:wrap">
              {% if user.is_active %}
              <form action="{{ url_for('shareflow.suspend_user', user_id=user.id) }}" method="post">
                <button class="btn btn-danger btn-sm">השעה</button>
              </form>
              {% else %}
              <form action="{{ url_for('shareflow.activate_user', user_id=user.id) }}" method="post">
                <button class="btn btn-success btn-sm">הפעל</button>
              </form>
              {% endif %}
              <form action="{{ url_for('shareflow.set_plan', user_id=user.id) }}" method="post" style="display:flex;gap:4px">
                <select name="plan" class="input" style="padding:3px 6px;font-size:11px">
                  <option value="free" {{ 'selected' if user.plan=='free' }}>Free</option>
                  <option value="pro" {{ 'selected' if user.plan=='pro' }}>Pro</option>
                </select>
                <button class="btn btn-sm" style="background:#7c3aed;color:#fff">שנה</button>
              </form>
            </div>
          </td>
        </tr>
        {% else %}
        <tr><td colspan="6" style="text-align:center;padding:32px;color:#94a3b8">לא נמצאו משתמשים</td></tr>
        {% endfor %}
      </tbody>
    </table>
  </div>
  {% set total = data.get('pagination',{}).get('total', 0) %}
  {% set pages = (total // 50) + (1 if total % 50 else 0) %}
  {% if pages > 1 %}
  <div style="margin-top:16px;display:flex;gap:8px">
    {% for p in range(1, pages+1) %}
    <a href="{{ url_for('shareflow.users', page=p, search=search) }}"
       class="btn {{ 'btn-primary' if p==page else '' }}" style="{{ '' if p==page else 'background:#e2e8f0;color:#1e293b' }}">
      {{ p }}
    </a>
    {% endfor %}
  </div>
  {% endif %}
</div>
"""

GROUPS_TEMPLATE = _NAV + """
<div class="sf-page">
  <h1>🏘️ קבוצות ShareFlow</h1>
  <p style="color:#64748b;margin-bottom:16px">{{ data.get('pagination',{}).get('total',0) }} קבוצות</p>
  <div class="sf-card" style="padding:0;overflow:hidden">
    <table class="sf-table">
      <thead>
        <tr>
          <th>שם</th><th style="text-align:center">מטבע</th><th style="text-align:center">חברים</th>
          <th style="text-align:center">הוצאות</th><th style="text-align:center">נוצרה</th>
        </tr>
      </thead>
      <tbody>
        {% for g in data.get('groups', []) %}
        <tr>
          <td><strong>{{ g.name }}</strong>{% if g.description %}<br><small style="color:#64748b">{{ g.description }}</small>{% endif %}</td>
          <td style="text-align:center"><span class="badge badge-free">{{ g.base_currency }}</span></td>
          <td style="text-align:center">{{ g.member_count }}</td>
          <td style="text-align:center">{{ g.expense_count }}</td>
          <td style="text-align:center;color:#64748b;font-size:12px">{{ g.created_at[:10] if g.created_at else '-' }}</td>
        </tr>
        {% else %}
        <tr><td colspan="5" style="text-align:center;padding:32px;color:#94a3b8">אין קבוצות</td></tr>
        {% endfor %}
      </tbody>
    </table>
  </div>
</div>
"""

OCR_TEMPLATE = _NAV + """
<div class="sf-page">
  <h1>📷 סטטיסטיקות OCR</h1>
  <div class="sf-grid sf-grid-2" style="max-width:600px">
    {% for label, val, color in [
      ('סריקות כולל', stats.get('total', 0), '#1e40af'),
      ('מאושרות', stats.get('confirmed', 0), '#059669'),
      ('ממתינות', stats.get('pending', 0), '#d97706'),
      ('נכשלו', stats.get('failed', 0), '#dc2626'),
      ('אחוז הצלחה', str(stats.get('success_rate', 0))+'%', '#7c3aed'),
    ] %}
    <div class="sf-stat">
      <div class="val" style="color:{{ color }}">{{ val }}</div>
      <div class="lbl">{{ label }}</div>
    </div>
    {% endfor %}
  </div>
</div>
"""

MONETIZATION_TEMPLATE = _NAV + """
<div class="sf-page">
  <h1>💰 מונטיזציה — מצב קבוצות</h1>

  <div class="sf-grid sf-grid-3" style="margin-bottom:24px">
    {% for label, val, color in [
      ('חינמיות', sf.get('groups_free',0), '#1e40af'),
      ('ממתינות להפעלה', sf.get('groups_limited',0), '#d97706'),
      ('פעילות — אירוע', sf.get('groups_active_event',0), '#059669'),
      ('פעילות — שוטפות', sf.get('groups_active_ongoing',0), '#059669'),
      ('פגות תוקף', sf.get('groups_expired',0), '#dc2626'),
      ('קריאה בלבד', sf.get('groups_read_only',0), '#7c3aed'),
    ] %}
    <div class="sf-stat"><div class="val" style="color:{{ color }}">{{ val }}</div><div class="lbl">{{ label }}</div></div>
    {% endfor %}
  </div>

  <div class="sf-grid sf-grid-3" style="margin-bottom:24px">
    {% for label, val, color in [
      ('אחוז המרה', sf.get('upgrade_conversion_rate','0%'), '#0891b2'),
      ('הכנסות סה"כ (₪)', '%.0f'|format(sf.get('total_revenue_ils',0)), '#059669'),
      ('הכנסות 30י (₪)', '%.0f'|format(sf.get('revenue_30d_ils',0)), '#7c3aed'),
    ] %}
    <div class="sf-stat"><div class="val" style="color:{{ color }}">{{ val }}</div><div class="lbl">{{ label }}</div></div>
    {% endfor %}
  </div>

  <div style="margin-bottom:16px;display:flex;gap:10px;flex-wrap:wrap">
    <a href="{{ url_for('shareflow.monetization') }}" class="btn {{ 'btn-primary' if not state else '' }}" style="{{ '' if not state else 'background:#e2e8f0;color:#1e293b' }}">הכל</a>
    {% for s, label, color in [('free','חינמי','#1e40af'),('limited','ממתין','#d97706'),('active','פעיל','#059669'),('expired','פג','#dc2626'),('read_only','קריאה בלבד','#7c3aed')] %}
    <a href="{{ url_for('shareflow.monetization', state=s) }}"
       class="btn" style="background:{{ color }};color:#fff">{{ label }}</a>
    {% endfor %}
  </div>

  <div class="sf-card" style="padding:0;overflow:hidden">
    <table class="sf-table">
      <thead>
        <tr>
          <th>שם קבוצה</th>
          <th style="text-align:center">סוג</th>
          <th style="text-align:center">מצב</th>
          <th style="text-align:center">חברים</th>
          <th style="text-align:center">הוצאות</th>
          <th style="text-align:center">תוקף עד</th>
          <th style="text-align:center">הפעלה ידנית</th>
        </tr>
      </thead>
      <tbody>
        {% for g in data.get('groups', []) %}
        {% set state_colors = {'free': '#dbeafe', 'limited': '#fef3c7', 'active': '#d1fae5', 'expired': '#fee2e2', 'read_only': '#ede9fe'} %}
        {% set state_texts = {'free': '#1e40af', 'limited': '#92400e', 'active': '#065f46', 'expired': '#991b1b', 'read_only': '#5b21b6'} %}
        {% set s = g.get('group_state','free') %}
        <tr>
          <td>
            <strong>{{ g.name }}</strong>
            {% if g.description %}<br><small style="color:#64748b">{{ g.description }}</small>{% endif %}
          </td>
          <td style="text-align:center">
            <span class="badge badge-free">{{ '🎯 אירוע' if g.get('group_type')=='event' else '🔄 שוטף' }}</span>
          </td>
          <td style="text-align:center">
            <span class="badge" style="background:{{ state_colors.get(s,'#e2e8f0') }};color:{{ state_texts.get(s,'#1e293b') }}">
              {{ s }}
            </span>
          </td>
          <td style="text-align:center">{{ g.member_count }}</td>
          <td style="text-align:center">{{ g.expense_count }}</td>
          <td style="text-align:center;font-size:12px;color:#64748b">
            {{ g.expiry_date[:10] if g.get('expiry_date') else '—' }}
          </td>
          <td style="text-align:center">
            {% if s in ('free','limited','expired','read_only') %}
            <form action="{{ url_for('shareflow.activate_group', group_id=g.id) }}" method="post">
              <input type="hidden" name="split" value="false">
              <button class="btn btn-success btn-sm">⚡ הפעל</button>
            </form>
            {% else %}
            <span style="color:#94a3b8;font-size:12px">פעיל</span>
            {% endif %}
          </td>
        </tr>
        {% else %}
        <tr><td colspan="7" style="text-align:center;padding:32px;color:#94a3b8">אין קבוצות</td></tr>
        {% endfor %}
      </tbody>
    </table>
  </div>
</div>
"""

FLAGS_TEMPLATE = _NAV + """
<div class="sf-page">
  <h1>🚩 Feature Flags</h1>
  <p style="color:#64748b;margin-bottom:24px">ניהול דגלי תכונות לשליטה על פיצ'רים בזמן אמת.</p>
  {% if flags %}
  <div style="display:flex;flex-direction:column;gap:12px">
    {% for flag in flags %}
    <div class="sf-card" style="display:flex;align-items:center;gap:16px;padding:16px 20px">
      <div style="flex:1">
        <strong>{{ flag.key }}</strong>
        {% if flag.description %}<div style="color:#64748b;font-size:13px;margin-top:2px">{{ flag.description }}</div>{% endif %}
      </div>
      <form action="{{ url_for('shareflow.update_flag', key=flag.key) }}" method="post" style="display:flex;gap:8px;align-items:center">
        <input class="input" name="value" value="{{ flag.value or '' }}" placeholder="ערך" style="width:180px">
        <input class="input" name="description" value="{{ flag.description or '' }}" placeholder="תיאור" style="width:200px">
        <button class="btn btn-primary">שמור</button>
      </form>
    </div>
    {% endfor %}
  </div>
  {% else %}
  <div class="sf-card" style="text-align:center;padding:48px;color:#94a3b8">
    <div style="font-size:2rem;margin-bottom:12px">🚩</div>
    אין feature flags מוגדרים
  </div>
  {% endif %}

  <div class="sf-card" style="margin-top:24px">
    <h2>הוסף Flag חדש</h2>
    <form action="{{ url_for('shareflow.update_flag', key='new') }}" method="post" style="display:flex;gap:10px;flex-wrap:wrap">
      <input class="input" name="key" placeholder="שם הדגל (key)" required style="width:200px">
      <input class="input" name="value" placeholder="ערך" style="width:180px">
      <input class="input" name="description" placeholder="תיאור" style="width:220px">
      <button class="btn btn-primary">צור</button>
    </form>
  </div>
</div>
"""
