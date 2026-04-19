@echo off
start "ShareFlow backend" cmd /k "cd /d %USERPROFILE%\adl_shareflow\backend && call venv\Scripts\activate && python run.py"
timeout /t 5 /nobreak >nul
start "ngrok tunnel" cmd /k "ngrok http --domain=engine-hacking-anywhere.ngrok-free.dev 5050"
timeout /t 3 /nobreak >nul
cd /d "%USERPROFILE%\adl_shareflow\mobile"
flutter run -d chrome --dart-define=FLAVOR=dev
