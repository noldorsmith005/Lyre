package Napster;

import java.util.List;
import java.util.function.Consumer;
import javafx.geometry.Bounds;
import javafx.scene.Cursor;
import javafx.scene.Node;
import javafx.scene.control.ListCell;
import javafx.scene.control.ListView;
import javafx.scene.control.ScrollBar;
import javafx.scene.layout.HBox;
import javafx.scene.input.ClipboardContent;
import javafx.scene.input.Dragboard;
import javafx.scene.input.TransferMode;
import javafx.scene.image.WritableImage;
import javafx.scene.canvas.Canvas;
import javafx.scene.canvas.GraphicsContext;
import javafx.scene.paint.Color;
import javafx.animation.AnimationTimer;



public class DragHandler {
    private MediaHandler.Track draggedTrack = null;
    private int dragSourceIndex = -1;
    private String currentZone = null;
    private AnimationTimer zoneTimer = null;
    private final Runnable onReorder;
    private final Consumer<String> autoScroll;
    private final Canvas dropCanvas;
    private ListView<MediaHandler.Track> trackList = null;
    private double lastMouseSceneY = -1;

    public DragHandler(Runnable onReorder, Consumer<String> autoScroll, Canvas dropCanvas) {
        this.onReorder = onReorder;
        this.autoScroll = autoScroll;
        this.dropCanvas = dropCanvas;
    }

    public void setupCardDrag(HBox card, MediaHandler.Track track, ListView<MediaHandler.Track> trackList, List<MediaHandler.Track> tracks) {
        this.trackList = trackList;
        card.setCursor(Cursor.OPEN_HAND);

        if (trackList.getProperties().putIfAbsent("drag_handlers_initialized", Boolean.TRUE) == null) {
            trackList.setOnDragOver(e -> {
                if (draggedTrack != null && e.getDragboard().hasString()) {
                    e.acceptTransferModes(TransferMode.MOVE);
                    lastMouseSceneY = e.getSceneY();
                    double localY = trackList.sceneToLocal(0, e.getSceneY()).getY();
                    double listHeight = trackList.getHeight();
                    int idx = getDropIndex(trackList, e.getSceneY());
                    int lastIndex = tracks.size() - 1;

                    String newZone = null;
                    if (localY < 120 && dragSourceIndex != 0) {
                        boolean canScrollUp = true;
                        ScrollBar scrollBar = (ScrollBar) trackList.lookup(".scroll-bar:vertical");
                        if (scrollBar != null) {
                            if (scrollBar.getValue() <= scrollBar.getMin()) {
                                canScrollUp = false;
                            }
                        } else {
                            canScrollUp = false;
                        }
                        if (canScrollUp) {
                            newZone = "top";
                        }
                    } else if (localY > listHeight - 120 && dragSourceIndex != lastIndex) {
                        boolean canScrollDown = true;
                        ScrollBar scrollBar = (ScrollBar) trackList.lookup(".scroll-bar:vertical");
                        if (scrollBar != null) {
                            if (scrollBar.getValue() >= scrollBar.getMax()) {
                                canScrollDown = false;
                            }
                        } else {
                            canScrollDown = false;
                        }
                        if (canScrollDown) {
                            newZone = "bottom";
                        }
                    }

                    if (!java.util.Objects.equals(newZone, currentZone)) {
                        currentZone = newZone;
                        if (newZone == null) {
                            stopZoneTimer();
                        } else {
                            startZoneTimer(newZone);
                        }
                    }

                    drawIndicator(trackList, idx);
                }
                e.consume();
            });

            trackList.setOnDragDropped(e -> {
                if (draggedTrack != null) {
                    stopZoneTimer();
                    currentZone = null;
                    lastMouseSceneY = -1;
                    clearIndicator();
                    int targetIndex = getDropIndex(trackList, e.getSceneY());
                    targetIndex = Math.min(targetIndex, tracks.size()); // clamp
                    if (targetIndex != dragSourceIndex && targetIndex != dragSourceIndex + 1) {
                        tracks.remove(dragSourceIndex);
                        int insertAt = targetIndex > dragSourceIndex ? targetIndex - 1 : targetIndex;
                        insertAt = Math.max(0, Math.min(insertAt, tracks.size())); // clamp insertAt too
                        tracks.add(insertAt, draggedTrack);
                        onReorder.run();
                    }
                    e.setDropCompleted(true);
                }
                e.consume();
            });
        }

        card.setOnMousePressed(e -> {
            card.setOpacity(0.5);
            card.setCursor(Cursor.CLOSED_HAND);
            e.consume();
        });

        card.setOnMouseReleased(e -> {
            if (draggedTrack == null) {
                card.setOpacity(1.0);
                card.setCursor(Cursor.OPEN_HAND);
            }
            e.consume();
        });

        card.setOnDragDetected(e -> {
            Dragboard db = card.startDragAndDrop(TransferMode.MOVE);
            
            db.setDragView(new WritableImage(1, 1));
            
            ClipboardContent content = new ClipboardContent();
            content.putString("dragged_track");
            db.setContent(content);
            
            draggedTrack = track;
            dragSourceIndex = tracks.indexOf(track);
            card.setOpacity(0.5);
            card.setCursor(Cursor.CLOSED_HAND);
            e.consume();
        });

        card.setOnDragDone(e -> {
            card.setOpacity(1.0);
            card.setCursor(Cursor.OPEN_HAND);
            draggedTrack = null;
            dragSourceIndex = -1;
            stopZoneTimer();
            currentZone = null;
            lastMouseSceneY = -1;
            clearIndicator();
            e.consume();
        });
    }

    private void startZoneTimer(String zone) {
        stopZoneTimer();
        zoneTimer = new AnimationTimer() {
            @Override
            public void handle(long now) {
                boolean canScroll = true;
                ScrollBar scrollBar = (ScrollBar) trackList.lookup(".scroll-bar:vertical");
                if (scrollBar != null) {
                    if (zone.equals("top") && scrollBar.getValue() <= scrollBar.getMin()) {
                        canScroll = false;
                    } else if (zone.equals("bottom") && scrollBar.getValue() >= scrollBar.getMax()) {
                        canScroll = false;
                    }
                } else {
                    canScroll = false;
                }

                if (!canScroll) {
                    if (lastMouseSceneY != -1 && trackList != null) {
                        int idx = getDropIndex(trackList, lastMouseSceneY);
                        drawIndicator(trackList, idx);
                    }
                    stopZoneTimer();
                    currentZone = null;
                    return;
                }

                autoScroll.accept(zone.equals("top") ? "up" : "down");
                if (lastMouseSceneY != -1 && trackList != null) {
                    int idx = getDropIndex(trackList, lastMouseSceneY);
                    drawIndicator(trackList, idx);
                }
            }
        };
        zoneTimer.start();
    }

    private void stopZoneTimer() {
        if (zoneTimer != null) {
            zoneTimer.stop();
            zoneTimer = null;
        }
    }

    private void drawIndicator(ListView<MediaHandler.Track> trackList, int dropIndex) {
        GraphicsContext gc = dropCanvas.getGraphicsContext2D();
        gc.clearRect(0, 0, dropCanvas.getWidth(), dropCanvas.getHeight());

        ListCell<MediaHandler.Track> ref = cellAt(trackList, dropIndex);
        boolean atTop = ref != null;
        if (ref == null) ref = cellAt(trackList, dropIndex - 1);
        if (ref == null) return;

        Bounds b = ref.localToScene(ref.getLayoutBounds());
        double sceneY = atTop ? b.getMinY() : b.getMaxY();

        Bounds xb = b;
        if (ref.getGraphic() instanceof HBox row && !row.getChildren().isEmpty()) {
            Node cardNode = row.getChildren().get(row.getChildren().size() - 1);
            xb = cardNode.localToScene(cardNode.getLayoutBounds());
        }

        double canvasY = dropCanvas.sceneToLocal(0, sceneY).getY();
        double x1 = dropCanvas.sceneToLocal(xb.getMinX(), 0).getX();
        double x2 = dropCanvas.sceneToLocal(xb.getMaxX(), 0).getX();

        gc.setStroke(Color.web("#ff0000"));
        gc.setLineWidth(2);
        gc.strokeLine(x1, canvasY, x2, canvasY);
    }

    private void clearIndicator() {
        dropCanvas.getGraphicsContext2D().clearRect(0, 0, dropCanvas.getWidth(), dropCanvas.getHeight());
    }

    private int getDropIndex(ListView<MediaHandler.Track> trackList, double sceneY) {
        int count = trackList.getItems().size();
        int index = count;
        for (Node n : trackList.lookupAll(".list-cell")) {
            if (n instanceof ListCell<?> cell && !cell.isEmpty()) {
                Bounds b = cell.localToScene(cell.getLayoutBounds());
                double midpoint = b.getMinY() + b.getHeight() / 2;
                if (sceneY < midpoint && cell.getIndex() < index) {
                    index = cell.getIndex();
                }
            }
        }
        return Math.max(0, Math.min(index, count));
    }

    @SuppressWarnings("unchecked")
    private ListCell<MediaHandler.Track> cellAt(ListView<MediaHandler.Track> trackList, int index) {
        if (index < 0) return null;
        for (Node n : trackList.lookupAll(".list-cell")) {
            if (n instanceof ListCell<?> cell && !cell.isEmpty() && cell.getIndex() == index) {
                return (ListCell<MediaHandler.Track>) cell;
            }
        }
        return null;
    }
}
