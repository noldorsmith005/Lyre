@echo off
set JFX_JMODS=..\lib\javafx-jmods-26.0.1
set JFX_SDK=..\lib\javafx-sdk-26.0.1\lib
set SQLite=..\lib\sqlite-jdbc\sqlite-jdbc-3.53.1.0.jar
set GSON=..\lib\gson-2.11.0\gson-2.11.0.jar
set FLAC=..\lib\jflac-1.5.2\jflac-codec-1.5.2.jar
set MODS=javafx.controls,javafx.fxml,javafx.media

rem Locate jar executable if not on PATH
set JAR_CMD=jar
where jar >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    if exist "%JAVA_HOME%\bin\jar.exe" (
        set JAR_CMD="%JAVA_HOME%\bin\jar.exe"
    ) else if exist "C:\Program Files\Java\latest\jdk-26\bin\jar.exe" (
        set JAR_CMD="C:\Program Files\Java\latest\jdk-26\bin\jar.exe"
    ) else (
        for /d %%i in ("C:\Program Files\Java\jdk-*") do (
            if exist "%%i\bin\jar.exe" set JAR_CMD="%%i\bin\jar.exe"
        )
    )
)

echo Compiling...
javac --module-path "%JFX_JMODS%" --add-modules %MODS% -classpath "%SQLite%;%GSON%;%FLAC%" ./App.java ./MediaHandler.java ./AudioPlayer.java ./DragHandler.java ./ServerClient.java -d ..\bin

if %ERRORLEVEL% EQU 0 (
    echo Packaging...
    %JAR_CMD% cfe ./Napster.jar Napster.App -C ..\bin Napster

    echo Running...
    java -Dprism.order=d3d ^
    --module-path "%JFX_SDK%" --add-modules %MODS% ^
    -cp "./Napster.jar;%SQLite%;%GSON%;%FLAC%" ^
    --enable-native-access=javafx.graphics,javafx.media,ALL-UNNAMED ^
    Napster.App
) else (
    echo Compilation failed
)
