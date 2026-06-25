package Napster;

import java.io.*;
import java.util.List;
import java.util.ArrayList;
import java.util.Random;
import javafx.util.Duration;
import javafx.animation.Timeline;
import javafx.animation.KeyFrame;
import javafx.scene.image.Image;
import javafx.scene.image.ImageView;
import javafx.geometry.Pos;
import javafx.geometry.HPos;
import javafx.geometry.Insets;
import javafx.scene.control.*;
import javafx.scene.layout.*;
import javafx.scene.media.*;
import org.jflac.FLACDecoder;
import org.jflac.metadata.StreamInfo;
import org.jflac.frame.Frame;
import org.jflac.util.ByteData;
import javax.sound.sampled.*;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicLong;



public class AudioPlayer extends VBox {
    private static String assetsUrl;

    private SourceDataLine audioLine;
    private Thread playbackThread;
    private final AtomicBoolean paused = new AtomicBoolean(false);
    private final AtomicBoolean stopped = new AtomicBoolean(false);
    private final Object pauseLock = new Object();

    private final AtomicLong framesPlayed = new AtomicLong(0);
    private volatile long totalFrames = 0;
    private volatile float sampleRate = 44100f;

    private ArrayList<Track> queue = new ArrayList<>();
    private ArrayList<Track> playlist = new ArrayList<>();
    private VBox queueCards = new VBox(8);
    private Integer currTrack = null;
    private boolean playing = false;
    private boolean shuffle = false;
    private boolean loop = false;

    private final Label titleLabel;
    private final Label artistLabel;
    private final Label queueLabel;
    private ImageView trackCover;
    private final Button clearBtn;
    private final Slider trackBar;
    private final Label currentTimeLabel;
    private final Label totalTimeLabel;
    private final Timeline progressUpdater;

    Image playPauseImg = new Image(new File("./resources/play.png").toURI().toString());
    Button playPauseBtn = new Button();
    Image nextImg = new Image(new File("./resources/next.png").toURI().toString());
    Button nextBtn = new Button();
    Image prevImg = new Image(new File("./resources/previous.png").toURI().toString());
    Button prevBtn = new Button();
    Image loopImg = new Image(new File("./resources/loop_unselected.png").toURI().toString());
    Button loopBtn = new Button();

    private final Runnable onRefresh;


    public static class Track {
        int trackID;
        boolean downloaded;
        String title, artist, duration, contributor;

        Track(int trackID, String title, String artist, String duration, boolean downloaded, String contributor) {
            this.trackID = trackID;
            this.title = title;
            this.artist = artist;
            this.duration = duration;
            this.downloaded = downloaded;
            this.contributor = contributor;
        }
    }

    public static class Playlist {
        int playlistID;
        String title;

        Playlist(int playlistID, String title) {
            this.playlistID = playlistID;
            this.title = title;
        }
    }


    public AudioPlayer(Runnable onRefresh) {
        this.onRefresh = onRefresh;
        assetsUrl = App.appData.toString();

        titleLabel = new Label("");
        titleLabel.setStyle("-fx-font-size: 20px; -fx-font-weight: bold; -fx-text-fill: #ffffff;");
        titleLabel.setMaxWidth(400);
        titleLabel.setTextOverrun(OverrunStyle.ELLIPSIS);
        titleLabel.setAlignment(Pos.CENTER);

        artistLabel = new Label("");
        artistLabel.setStyle("-fx-font-size: 15px; -fx-text-fill: #888;");

        trackCover = new ImageView();
        trackCover.setFitWidth(400);
        trackCover.setFitHeight(400);
        trackCover.setPreserveRatio(true);
        Image image = new Image(new File("./resources/default.jpg").toURI().toString());
        trackCover.setImage(image);

        trackBar = new Slider(0, 1, 0);
        trackBar.setMaxWidth(Double.MAX_VALUE);
        HBox.setHgrow(trackBar, Priority.ALWAYS);
        trackBar.setMouseTransparent(false);
        trackBar.setFocusTraversable(false);
        trackBar.setOnMousePressed(e -> trackBar.getParent().requestFocus());
        trackBar.valueChangingProperty().addListener((obs, wasChanging, isChanging) -> {
            if (!isChanging) seek(trackBar.getValue());
        });
        trackBar.valueProperty().addListener((obs, oldVal, newVal) -> {
            double pct = newVal.doubleValue() * 100;
            javafx.scene.Node track = trackBar.lookup(".track");
            if (track != null)
                track.setStyle("-fx-background-color: linear-gradient(to right, #ffffff " + pct + "%, #444 " + pct + "%);");
        });

        currentTimeLabel = new Label("0:00");
        currentTimeLabel.setStyle("-fx-font-size: 11px; -fx-text-fill: #888;");

        totalTimeLabel = new Label("0:00");
        totalTimeLabel.setStyle("-fx-font-size: 11px; -fx-text-fill: #888;");

        ImageView playPauseGraphic = new ImageView(playPauseImg);
        playPauseGraphic.setFitWidth(25);
        playPauseGraphic.setFitHeight(25);
        playPauseGraphic.setPreserveRatio(true);
        playPauseBtn.setGraphic(playPauseGraphic);
        playPauseBtn.setStyle("-fx-background-color: transparent; -fx-cursor: hand;");
        playPauseBtn.setOnMouseEntered(e -> updatePausePlayButton(playPauseBtn, playing));
        playPauseBtn.setOnMouseExited(e -> updatePausePlayButton(playPauseBtn, playing));
        playPauseBtn.setOnAction(e -> {
            if (playing) pause();
            else resume();
        });
        updatePausePlayButton(playPauseBtn, playing);

        ImageView loopGraphic = new ImageView(loopImg);
        loopGraphic.setFitWidth(26);
        loopGraphic.setFitHeight(26);
        loopGraphic.setPreserveRatio(true);
        loopBtn.setGraphic(loopGraphic);
        loopBtn.setStyle("-fx-background-color: transparent; -fx-cursor: hand;");
        loopBtn.setOnMouseEntered(e -> updateLoopBtn(loopBtn, loop));
        loopBtn.setOnMouseExited(e -> updateLoopBtn(loopBtn, loop));
        loopBtn.setOnAction(e -> {
            loop = !loop;
            updateLoopBtn(loopBtn, loop);
        });
        updateLoopBtn(loopBtn, loop);

        ImageView nextGraphic = new ImageView(nextImg);
        nextGraphic.setFitWidth(25);
        nextGraphic.setFitHeight(25);
        nextGraphic.setPreserveRatio(true);
        nextBtn.setGraphic(nextGraphic);
        nextBtn.setStyle("-fx-background-color: transparent; -fx-cursor: hand;");
        nextBtn.setOnAction(e -> next());

        ImageView prevGraphic = new ImageView(prevImg);
        prevGraphic.setFitWidth(25);
        prevGraphic.setFitHeight(25);
        prevGraphic.setPreserveRatio(true);
        prevBtn.setGraphic(prevGraphic);
        prevBtn.setStyle("-fx-background-color: transparent; -fx-cursor: hand;");
        prevBtn.setOnAction(e -> {
            if (!playing) {
                seek(0.0);
                trackBar.setValue(0.0);
                currentTimeLabel.setText("0:00");
            } else {
                seek(0.0);
            }
        });

        queueLabel = new Label("Next in Queue: ");
        queueLabel.setStyle("-fx-font-size: 17px; -fx-font-weight: bold; -fx-text-fill: #ffffff;");

        Region queueSpacer = new Region();
        HBox.setHgrow(queueSpacer, Priority.ALWAYS);

        clearBtn = new Button("Clear Queue");
        clearBtn.setStyle("""
            -fx-background-color: transparent;
            -fx-background-radius: 50%;
            -fx-min-width: 20px;
            -fx-min-height: 20px;
            -fx-cursor: hand;
            -fx-text-fill: #ffffff;
        """);
        clearBtn.setOnMouseEntered(e -> clearBtn.setStyle("""
            -fx-background-color: transparent;
            -fx-background-radius: 50%;
            -fx-min-width: 20px;
            -fx-min-height: 20px;
            -fx-cursor: hand;
            -fx-text-fill: #555555;
        """));
        clearBtn.setOnMouseExited(e -> clearBtn.setStyle("""
            -fx-background-color: transparent;
            -fx-background-radius: 50%;
            -fx-min-width: 20px;
            -fx-min-height: 20px;
            -fx-cursor: hand;
            -fx-text-fill: #ffffff;
        """));
        clearBtn.setOnAction(e -> clearQueue());

        VBox infoRow = new VBox(10, trackCover, titleLabel, artistLabel);
        infoRow.setAlignment(Pos.CENTER);

        HBox seekRow = new HBox(8, currentTimeLabel, trackBar, totalTimeLabel);
        seekRow.setAlignment(Pos.CENTER);
        seekRow.setMaxWidth(Double.MAX_VALUE);

        GridPane controlRow = new GridPane();
        controlRow.setAlignment(Pos.CENTER);
        controlRow.setMaxWidth(Double.MAX_VALUE);

        HBox leftGroup = new HBox(12, prevBtn);
        leftGroup.setAlignment(Pos.CENTER_RIGHT);
        leftGroup.setMaxWidth(Double.MAX_VALUE);
        HBox.setHgrow(leftGroup, Priority.ALWAYS);

        HBox rightGroup = new HBox(12, nextBtn, loopBtn);
        rightGroup.setAlignment(Pos.CENTER_LEFT);
        rightGroup.setMaxWidth(Double.MAX_VALUE);
        HBox.setHgrow(rightGroup, Priority.ALWAYS);

        controlRow.add(leftGroup, 0, 0);
        controlRow.add(playPauseBtn, 1, 0);
        controlRow.add(rightGroup, 2, 0);

        ColumnConstraints col1 = new ColumnConstraints();
        col1.setPercentWidth(43);
        col1.setHalignment(HPos.RIGHT);
        col1.setFillWidth(true);

        ColumnConstraints col2 = new ColumnConstraints();
        col2.setPercentWidth(15);
        col2.setHalignment(HPos.CENTER);

        ColumnConstraints col3 = new ColumnConstraints();
        col3.setPercentWidth(43);
        col3.setHalignment(HPos.LEFT);
        col3.setFillWidth(true);

        controlRow.getColumnConstraints().addAll(col1, col2, col3);

        HBox queueRow = new HBox(12, queueLabel, queueSpacer, clearBtn);
        controlRow.setAlignment(Pos.CENTER);

        queueCards.setPadding(new Insets(20, 32, 20, 32));

        for (Track track : queue) {
            HBox card = buildCard(track);
            queueCards.getChildren().add(card);
        }

        ScrollPane scroll = new ScrollPane(queueCards);
        scroll.setFitToWidth(true);
        scroll.setHbarPolicy(ScrollPane.ScrollBarPolicy.NEVER);
        scroll.setVbarPolicy(ScrollPane.ScrollBarPolicy.NEVER);
        scroll.setStyle(
                "-fx-background: transparent;" +
                "-fx-background-color: transparent;" +
                "-fx-border-color: transparent;"
        );
        VBox queuePanel = new VBox(scroll);
        queuePanel.setFocusTraversable(true);
        queuePanel.setOnMousePressed(e -> queuePanel.requestFocus());
        queuePanel.setStyle("-fx-background-color: #000000;");
        VBox.setVgrow(scroll, Priority.ALWAYS);

        Region spacer = new Region();
        VBox.setVgrow(spacer, Priority.ALWAYS);

        setSpacing(8);
        setPadding(new Insets(12, 16, 12, 16));
        setStyle("-fx-border-color: #555555; -fx-border-radius: 8; -fx-background-radius: 8;");
        getChildren().addAll(infoRow, seekRow, controlRow, queueRow, queuePanel, spacer);

        // Progress bar updates every 250 ms from frame-counter
        progressUpdater = new Timeline(new KeyFrame(Duration.millis(250), e -> updateProgress()));
        progressUpdater.setCycleCount(Timeline.INDEFINITE);
    }

    // ── Helpers ────────────────────────────────────────────────
    private void updatePausePlayButton(Button button, boolean isSelected) {
        playPauseImg = isSelected
                ? new Image(new File("./resources/pause.png").toURI().toString())
                : new Image(new File("./resources/play.png").toURI().toString());
        ImageView graphic = new ImageView(playPauseImg);
        graphic.setFitWidth(25);
        graphic.setFitHeight(25);
        graphic.setPreserveRatio(true);
        playPauseBtn.setGraphic(graphic);
    }

    private void updateLoopBtn(Button button, boolean isSelected) {
        loopImg = isSelected
                ? new Image(new File("./resources/loop_selected.png").toURI().toString())
                : new Image(new File("./resources/loop_unselected.png").toURI().toString());
        ImageView graphic = new ImageView(loopImg);
        graphic.setFitWidth(25);
        graphic.setFitHeight(25);
        graphic.setPreserveRatio(true);
        loopBtn.setGraphic(graphic);
    }

    private void updateProgress() {
        if (audioLine == null || totalFrames == 0) return;
        long played = framesPlayed.get();
        double progress = (double) played / totalFrames;
        if (!trackBar.isValueChanging()) {
            trackBar.setValue(progress);
            currentTimeLabel.setText(formatTime(played / sampleRate));
        }
    }

    private String formatTime(double seconds) {
        int s = (int) seconds;
        return String.format("%d:%02d", s / 60, s % 60);
    }

    // ── FLAC Playback Engine ──────────────────────────────────────────────────
    private void stopAudio() {
        stopped.set(true);
        synchronized (pauseLock) {
            pauseLock.notifyAll();
        }
        if (playbackThread != null) {
            try { playbackThread.join(2000); } catch (InterruptedException ignored) {}
            playbackThread = null;
        }
        if (audioLine != null) {
            audioLine.stop();
            audioLine.close();
            audioLine = null;
        }
        framesPlayed.set(0);
        totalFrames = 0;
    }

    /**
     * Decodes the FLAC file on a background thread and writes PCM to a
     * SourceDataLine. The FX thread reads framesPlayed for seek/progress.
    */
    private void startFlacPlayback(File flacFile, long seekToFrame) {
        stopped.set(false);
        paused.set(false);

        playbackThread = new Thread(() -> {
            try (FileInputStream fis = new FileInputStream(flacFile)) {
                FLACDecoder decoder = new FLACDecoder(fis);

                StreamInfo info = decoder.readStreamInfo();
                if (info == null) {
                    System.err.println("No StreamInfo found in FLAC file: " + flacFile);
                    return;
                }

                sampleRate = info.getSampleRate();
                int channels = info.getChannels();
                int bitsPerSample = info.getBitsPerSample();
                totalFrames = info.getTotalSamples();

                AudioFormat format = new AudioFormat(
                    sampleRate,
                    bitsPerSample,
                    channels,
                    true,
                    false
                );

                long totalSec = (long)(totalFrames / sampleRate);
                javafx.application.Platform.runLater(() ->
                        totalTimeLabel.setText(formatTime(totalSec)));

                DataLine.Info lineInfo = new DataLine.Info(SourceDataLine.class, format);
                audioLine = (SourceDataLine) AudioSystem.getLine(lineInfo);
                audioLine.open(format);
                audioLine.start();

                framesPlayed.set(0);
                long framesToSkip  = seekToFrame;
                int  bytesPerFrame = ((bitsPerSample / 8) * channels);

                ByteData pcmData = new ByteData(4096);
                while (!stopped.get()) {
                    synchronized (pauseLock) {
                        while (paused.get() && !stopped.get()) {
                            try { pauseLock.wait(); } catch (InterruptedException ignored) {}
                        }
                    }
                    if (stopped.get()) break;

                    Frame nextFrame = decoder.readNextFrame();
                    byte[] pcmBuffer = null;
                    int    pcmLength = 0;
                    if (nextFrame != null) {
                        pcmData = decoder.decodeFrame(nextFrame, pcmData);
                        pcmBuffer = pcmData.getData();
                        pcmLength = pcmData.getLen();
                    }
                    if (nextFrame == null || pcmBuffer == null || pcmLength == 0) {
                        javafx.application.Platform.runLater(() -> {
                            if (loop) {
                                seek(0.0);
                                resume();
                            } else {
                                next();
                            }
                        });
                        break;
                    }

                    long framesInBuffer = pcmLength / bytesPerFrame;

                    if (framesToSkip > 0) {
                        if (framesToSkip >= framesInBuffer) {
                            framesToSkip -= framesInBuffer;
                            framesPlayed.addAndGet(framesInBuffer);
                            continue;
                        } else {
                            int skipBytes = (int)(framesToSkip * bytesPerFrame);
                            audioLine.write(pcmBuffer, skipBytes, pcmLength - skipBytes);
                            framesPlayed.addAndGet(framesInBuffer);
                            framesToSkip = 0;
                            continue;
                        }
                    }

                    audioLine.write(pcmBuffer, 0, pcmLength);
                    framesPlayed.addAndGet(framesInBuffer);
                }

                audioLine.drain();
                audioLine.close();

            } catch (Exception e) {
                System.err.println("FLAC playback error: " + e.getMessage());
                e.printStackTrace();
            }
        }, "flac-playback");

        playbackThread.setDaemon(true);
        playbackThread.start();
    }

    // ── Playback Control Methods ───────────────────────────────────────────────────

    public void play(Track track) {
        stopAudio();

        File flacFile = new File(assetsUrl + "/audio/" + track.trackID + ".flac");
        if (!flacFile.exists()) {
            System.err.println("FLAC file not found: " + flacFile.getAbsolutePath());
            return;
        }

        playing    = true;
        currTrack  = track.trackID;
        updatePausePlayButton(playPauseBtn, true);
        titleLabel.setText(track.title);
        artistLabel.setText(track.artist);

        File coverFile = new File(assetsUrl + "/cover/" + track.trackID + ".jpg");
        if (!coverFile.exists()) coverFile = new File("./resources/default.jpg");
        trackCover.setImage(new Image(coverFile.toURI().toString()));

        trackBar.setValue(0.0);
        currentTimeLabel.setText("0:00");

        startFlacPlayback(flacFile, 0);
        progressUpdater.playFromStart();
        onRefresh.run();
    }

    public void pause() {
        paused.set(true);
        if (audioLine != null) audioLine.stop();
        playing = false;
        updatePausePlayButton(playPauseBtn, false);
        progressUpdater.stop();
    }

    public void resume() {
        paused.set(false);
        if (audioLine != null) audioLine.start();
        synchronized (pauseLock) { pauseLock.notifyAll(); }
        playing = true;
        updatePausePlayButton(playPauseBtn, true);
        progressUpdater.play();
    }

    public void seek(double percent) {
        if (currTrack == null || totalFrames == 0) return;
        long targetFrame = (long)(percent * totalFrames);
        File flacFile = new File(assetsUrl + "/audio/" + currTrack + ".flac");

        boolean wasPlaying = playing;
        stopAudio();

        framesPlayed.set(targetFrame);
        startFlacPlayback(flacFile, targetFrame);

        if (wasPlaying) {
            playing = true;
            updatePausePlayButton(playPauseBtn, true);
            progressUpdater.play();
        } else {
            paused.set(true);
            playing = false;
        }
    }

    public void next() {
        if (loop) {
            seek(0.0);
            resume();
        } else if (!queue.isEmpty()) {
            Track next = queue.remove(0);
            play(next);
        } else if (!playlist.isEmpty()) {
            if (shuffle) {
                Random rand = new Random();
                int idx = rand.nextInt(playlist.size());
                play(playlist.remove(idx));
            } else {
                play(playlist.remove(0));
            }
        } else {
            stopAudio();
            playing = false;
            progressUpdater.stop();
            updatePausePlayButton(playPauseBtn, false);
        }
        queueCards.getChildren().clear();
        for (Track curr : queue) {
            queueCards.getChildren().add(buildCard(curr));
        }
    }

    // ── Queue / Playlist Managers ───────────────────────────────
    public void addToQueue(Track track) {
        queue.add(track);
        queueCards.getChildren().clear();
        for (Track curr : queue) queueCards.getChildren().add(buildCard(curr));
    }

    public void addToPlaylistQueue(Track track) { playlist.add(track); }

    public void removeFromQueue(Track track) {
        queue.removeIf(t -> t.trackID == track.trackID);
        queueCards.getChildren().clear();
        for (Track curr : queue) queueCards.getChildren().add(buildCard(curr));
    }

    public void clearQueue() {
        queueCards.getChildren().clear();
        queue.clear();
    }

    public void clearPlaylistQueue() { playlist.clear(); }

    public void setShuffle() { shuffle = !shuffle; }
    public boolean isShuffled() { return shuffle; }
    public boolean isPlaying() { return playing; }

    public boolean trackPlaying(Track track) {
        return track.trackID == currTrack;
    }

    // ── Card Builder ──────────────────────────────────────────────
    private HBox buildCard(Track track) {
        Label nameLabel = new Label(track.title);
        nameLabel.setStyle("-fx-text-fill: #e8e8e8; -fx-font-size: 17px;");
        nameLabel.setMaxWidth(200);
        nameLabel.setTextOverrun(OverrunStyle.ELLIPSIS);

        Label artistLabel = new Label(track.artist);
        artistLabel.setStyle("-fx-text-fill: #555555; -fx-font-size: 13px;");
        artistLabel.setMaxWidth(200);
        artistLabel.setTextOverrun(OverrunStyle.ELLIPSIS);

        VBox textBlock = new VBox(3, nameLabel, artistLabel);
        HBox.setHgrow(textBlock, Priority.ALWAYS);

        Label durationLabel = new Label(track.duration);
        durationLabel.setStyle("-fx-text-fill: #555555; -fx-font-size: 15px;");

        Region spacer = new Region();
        HBox.setHgrow(spacer, Priority.ALWAYS);

        Label removeBtn = new Label("⛌");
        removeBtn.setStyle("-fx-text-fill: #e8e8e8; -fx-font-size: 17px; -fx-font-weight: bold;");
        removeBtn.setOnMouseEntered(e -> removeBtn.setStyle("-fx-text-fill: #555555; -fx-font-size: 17px; -fx-font-weight: bold;"));
        removeBtn.setOnMouseExited(e -> removeBtn.setStyle("-fx-text-fill: #e8e8e8; -fx-font-size: 17px; -fx-font-weight: bold;"));
        removeBtn.setOnMouseClicked(e -> removeFromQueue(track));

        HBox card = new HBox(12, textBlock, spacer, durationLabel, removeBtn);
        card.setAlignment(Pos.CENTER_LEFT);
        card.setPadding(new Insets(14, 18, 14, 18));
        card.setStyle("-fx-background-color: #161616; -fx-background-radius: 10; -fx-cursor: hand;");
        card.setOnMouseEntered(e -> card.setStyle("-fx-background-color: #1c1c1c; -fx-background-radius: 10; -fx-cursor: hand;"));
        card.setOnMouseExited(e -> card.setStyle("-fx-background-color: #161616; -fx-background-radius: 10; -fx-cursor: hand;"));

        return card;
    }
}


