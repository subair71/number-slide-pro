@echo off
setlocal
pushd "%~dp0"
set "JDK_BIN="
if exist "%JAVA_HOME%\bin\jarsigner.exe" set "JDK_BIN=%JAVA_HOME%\bin"
if not defined JDK_BIN if exist "%ProgramFiles%\Android\Android Studio\jbr\bin\jarsigner.exe" set "JDK_BIN=%ProgramFiles%\Android\Android Studio\jbr\bin"
if not defined JDK_BIN for %%J in (jarsigner.exe) do if not "%%~$PATH:J"=="" for %%B in ("%%~$PATH:J") do set "JDK_BIN=%%~dpB"
if not defined JDK_BIN (
  echo Install a JDK 17 or newer, or Android Studio with its bundled JDK, then run this file again.
  if not defined NUMBER_SLIDE_HEADLESS pause
  exit /b 1
)
"%JDK_BIN%\java.exe" --source 17 FirstUpload.java %*
if errorlevel 1 (
  echo No new bundle was prepared for submission.
  if not defined NUMBER_SLIDE_HEADLESS pause
  exit /b 1
)
if defined NUMBER_SLIDE_HEADLESS exit /b 0
start "" explorer.exe "%CD%\UPLOAD_TO_PLAY"
start "" "%CD%\First-upload-guide.html"
start "" "https://play.google.com/console/"
echo Use the signed AAB in UPLOAD_TO_PLAY. Keep the upload keystore and password private.
pause
popd
