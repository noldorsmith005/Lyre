package Napster;

import javafx.geometry.Bounds;
import javafx.scene.Cursor;
import javafx.scene.Node;
import javafx.scene.control.ListCell;
import javafx.scene.control.ListView;
import javafx.scene.layout.HBox;
import javafx.scene.canvas.Canvas;
import javafx.scene.canvas.GraphicsContext;
import javafx.scene.paint.Color;
import java.util.List;


public class DragHandler {
    private MediaHandler.Track draggedTrack = null;
    private int dragSourceIndex = -1;
    private final Runnable onReorder;
    private final Canvas dropCanvas;

    public DragHandler(Runnable onReorder, Canvas dropCanvas) {
        this.onReorder = onReorder;
        this.dropCanvas = dropCanvas;
    }

    public void setupCardDrag(HBox card, MediaHandler.Track track, ListView<MediaHandler.Track> trackList, List<MediaHandler.Track> tracks) {
        card.setCursor(Cursor.OPEN_HAND);

        card.setOnMousePressed(e -> {
            draggedTrack = track;
            dragSourceIndex = tracks.indexOf(track);
            card.setOpacity(0.5);
            card.setCursor(Cursor.CLOSED_HAND);
            e.consume();
        });

        card.setOnMouseDragged(e -> {
            if (draggedTrack == null) return;
            double localY = trackList.sceneToLocal(0, e.getSceneY()).getY();
            double listHeight = trackList.getHeight();
            int idx = getDropIndex(trackList, e.getSceneY());

            if (localY < 40) trackList.scrollTo(Math.max(0, idx - 1));
            else if (localY > listHeight - 40) trackList.scrollTo(Math.min(tracks.size() - 1, idx + 1));

            drawIndicator(trackList, idx);
            e.consume();
        });

        card.setOnMouseReleased(e -> {
            if (draggedTrack == null) return;
            clearIndicator();
            int targetIndex = getDropIndex(trackList, e.getSceneY());
            if (targetIndex != dragSourceIndex && targetIndex != dragSourceIndex + 1) {
                tracks.remove(dragSourceIndex);
                int insertAt = targetIndex > dragSourceIndex ? targetIndex - 1 : targetIndex;
                tracks.add(insertAt, draggedTrack);
                onReorder.run();
            }
            card.setOpacity(1.0);
            card.setCursor(Cursor.OPEN_HAND);
            draggedTrack = null;
            dragSourceIndex = -1;
            e.consume();
        });
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
        dropCanvas.getGraphicsContext2D()
                  .clearRect(0, 0, dropCanvas.getWidth(), dropCanvas.getHeight());
    }

    private int getDropIndex(ListView<MediaHandler.Track> trackList, double sceneY) {
        int count = trackList.getItems().size();
        int index = count; // default: drop at the end
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
