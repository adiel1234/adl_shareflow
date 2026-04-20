"""
ShareFlow Admin — Standalone Dashboard
=======================================
הפעלה: python run.py
גישה:  http://localhost:5002/shareflow
"""
import os
from flask import Flask, redirect, url_for, session, request, render_template_string

# Load .env if exists
try:
    from dotenv import load_dotenv
    load_dotenv(os.path.join(os.path.dirname(__file__), '.env'))
except ImportError:
    pass

app = Flask(__name__)
app.secret_key = os.getenv('SECRET_KEY', 'shareflow-admin-secret-2024')

# Expose Python builtins needed by the Jinja2 templates
app.jinja_env.globals.update(str=str, int=int, float=float, round=round)

# ── Stub 'adl' blueprint so url_for('adl.login') works in routes.py ──
from flask import Blueprint as _BP
_adl_stub = _BP('adl', __name__)

@_adl_stub.get('/adl-login')
def login():
    return redirect('/login')

app.register_blueprint(_adl_stub)

from shareflow.routes import shareflow_bp

# ── Auth ──────────────────────────────────────────────────────────────
ADMIN_PASSWORD = os.getenv('ADMIN_PASSWORD', 'Adiel1234ADL')

LOGIN_HTML = """
<!doctype html>
<html dir="rtl">
<head>
  <meta charset="utf-8">
  <title>ShareFlow Admin — כניסה</title>
  <style>
    * { box-sizing: border-box; }
    body { font-family: -apple-system, sans-serif; background: linear-gradient(135deg,#1e40af,#059669);
           min-height: 100vh; display: flex; align-items: center; justify-content: center; margin: 0; }
    .card { background: #fff; border-radius: 20px; padding: 40px; width: 340px; box-shadow: 0 20px 60px rgba(0,0,0,.15); }
    h2 { margin: 0 0 24px; font-size: 1.4rem; color: #0f172a; text-align: center; }
    input { width: 100%; border: 1px solid #e2e8f0; border-radius: 10px; padding: 12px 14px;
            font-size: 14px; margin-bottom: 14px; outline: none; }
    input:focus { border-color: #1e40af; }
    button { width: 100%; background: linear-gradient(135deg,#1e40af,#059669); color: #fff;
             border: none; border-radius: 10px; padding: 12px; font-size: 15px;
             font-weight: 600; cursor: pointer; }
    .err { color: #dc2626; font-size: 13px; margin-bottom: 12px; text-align: center; }
    .logo { text-align: center; font-size: 2rem; margin-bottom: 8px; }
  </style>
</head>
<body>
  <div class="card">
    <div class="logo">📊</div>
    <h2>ShareFlow Admin</h2>
    {% if error %}<div class="err">{{ error }}</div>{% endif %}
    <form method="post">
      <input type="password" name="password" placeholder="סיסמת מנהל" autofocus>
      <button type="submit">כניסה</button>
    </form>
  </div>
</body>
</html>
"""


@app.get('/login')
@app.post('/login')
def login():
    if request.method == 'POST':
        if request.form.get('password') == ADMIN_PASSWORD:
            session['adl_logged_in'] = True
            return redirect('/shareflow')
        return render_template_string(LOGIN_HTML, error='סיסמה שגויה')
    return render_template_string(LOGIN_HTML, error=None)


@app.get('/logout')
def logout():
    session.clear()
    return redirect('/login')


@app.get('/')
def root():
    return redirect('/shareflow')


# ── Blueprint ─────────────────────────────────────────────────────────
app.register_blueprint(shareflow_bp, url_prefix='/shareflow')

# ── Run ───────────────────────────────────────────────────────────────
if __name__ == '__main__':
    port = int(os.getenv('PORT', 5002))
    print(f"\n✅  ShareFlow Admin: http://localhost:{port}/shareflow\n")
    app.run(host='0.0.0.0', port=port, debug=False)
