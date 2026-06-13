#!/bin/bash
JFX=../lib/javafx-sdk-26.0.1/lib
SQLite=../lib/sqlite-jdbc/sqlite-jdbc-3.53.1.0.jar
MODS=javafx.controls,javafx.fxml,javafx.media

echo "Compiling..."
javac --module-path "$JFX" --add-modules $MODS -classpath "$SQLite" ./App.java ./MediaHandler.java ./DragHandler.java ./ServerClient.java -d ../bin 2>&1 | head -20

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo "Packaging..."
    jar cfe ./Napster.jar Napster.App -C ../bin Napster

    echo "Running..."
    java --module-path "$JFX" --add-modules $MODS \
    -cp "./Napster.jar:$SQLite" \
    --enable-native-access=javafx.graphics,javafx.media,ALL-UNNAMED \
    Napster.App
else
    echo "Compilation failed"
fi

