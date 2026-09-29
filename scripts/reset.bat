@echo off
setlocal
cd /d "%~dp0\.."

docker compose up -d
echo Waiting for Postgres to be healthy...
:wait
for /f "tokens=*" %%i in ('docker inspect -f "{{.State.Health.Status}}" iris_postgis_db 2^>nul') do set STATUS=%%i
if not "%STATUS%"=="healthy" (
    timeout /t 1 /nobreak >nul
    goto wait
)

if not defined IRIS_DATABASE_URL set IRIS_DATABASE_URL=postgresql://iris_user:iris_password@localhost:5433/iris
python -m pip install -q -r requirements.txt
python scripts\rebuild.py
if errorlevel 1 (
    echo FAILED: rebuild.py exited with an error. See output above.
    echo If this is a password/auth error, the Docker volume likely predates
    echo the current docker-compose.yml. Fix with:
    echo     docker compose down -v ^&^& scripts\reset.bat
    exit /b 1
)
echo Done. Run "pytest tests/test_schema.py -v" for the behavioural test suite.
