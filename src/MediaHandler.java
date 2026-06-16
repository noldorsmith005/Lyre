package Napster;

import java.io.File;
import java.util.List;
import java.util.ArrayList;
import java.util.Random;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import javafx.application.Application;
import javafx.util.Duration;
import javafx.stage.Stage;
import javafx.animation.KeyFrame;
import javafx.animation.Timeline;
import javafx.geometry.Insets;
import javafx.geometry.Pos;
import javafx.geometry.HPos;
import javafx.scene.media.*;
import javafx.scene.control.*;
import javafx.scene.layout.*;
import javafx.scene.image.Image;
import javafx.scene.image.ImageView;



public class MediaHandler {
	private static String databaseUrl = "jdbc:sqlite:" + System.getProperty("user.home") + "/Library/Application Support/Napster/data.db";
	private static String assetsUrl = System.getProperty("user.home") + "/Library/Application Support/Napster";

	private void log(String message) {
	    try (java.io.FileWriter fw = new java.io.FileWriter("/tmp/Napster-debug.log", true)) {
	        fw.write(new java.util.Date() + ": " + message + "\n");
	    } catch (java.io.IOException e) {
	        // silently fail
	    }
	}

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


    public class AudioPlayer extends VBox {
		private MediaPlayer player;
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
		private Timeline progressUpdater;
		Image playPauseImg = new Image(new File("./resources/play.png").toURI().toString());
    	Button playPauseBtn = new Button();
		Image nextImg = new Image(new File("./resources/next.png").toURI().toString());
    	Button nextBtn = new Button();
		Image prevImg = new Image(new File("./resources/previous.png").toURI().toString());
    	Button prevBtn = new Button();
    	Image loopImg = new Image(new File("./resources/loop_unselected.png").toURI().toString());
    	Button loopBtn = new Button();

    	private final Runnable onRefresh;

		public AudioPlayer(Runnable onRefresh) {
			this.onRefresh = onRefresh;

			// Track Title Label
		    titleLabel = new Label("");
		    titleLabel.setStyle("-fx-font-size: 20px; -fx-font-weight: bold; -fx-text-fill: #ffffff;");
		    titleLabel.setMaxWidth(400);
        	titleLabel.setTextOverrun(OverrunStyle.ELLIPSIS);
        	titleLabel.setAlignment(Pos.CENTER);

        	// Artist Label
		    artistLabel = new Label("");
		    artistLabel.setStyle("-fx-font-size: 15px; -fx-text-fill: #888;");

		    // Cover Art
		    trackCover = new ImageView();
		    trackCover.setFitWidth(400);
		    trackCover.setFitHeight(400);
		    trackCover.setPreserveRatio(true);
		    Image image = new Image(new File(assetsUrl + "/cover/default.jpg").toURI().toString());
		    trackCover.setImage(image);

		    // Track Bar
		    trackBar = new Slider(0, 1, 0);
		    trackBar.setMaxWidth(400);
		    trackBar.setMouseTransparent(false);
			trackBar.setFocusTraversable(false);
			trackBar.setOnMousePressed(e -> trackBar.getParent().requestFocus());
		    HBox.setHgrow(trackBar, Priority.ALWAYS);
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
		    nextBtn.setOnAction(e -> {
			    next();
		    });
				     
		    ImageView prevGraphic = new ImageView(prevImg);
	        prevGraphic.setFitWidth(25);
	        prevGraphic.setFitHeight(25);
	        prevGraphic.setPreserveRatio(true);
	        prevBtn.setGraphic(prevGraphic);
	        prevBtn.setStyle("-fx-background-color: transparent; -fx-cursor: hand;");
		    prevBtn.setOnAction(e -> {
			    next();
		    });
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
		    """
	        ));
	        clearBtn.setOnMouseExited(e -> clearBtn.setStyle("""
			-fx-background-color: transparent;
			-fx-background-radius: 50%;
			-fx-min-width: 20px;
			-fx-min-height: 20px;
			-fx-cursor: hand;
			-fx-text-fill: #ffffff;
		    """
	        ));
		    clearBtn.setOnAction(e -> {
			 	clearQueue();
		    });

		    // Song info
		    VBox infoRow = new VBox(10, trackCover, titleLabel, artistLabel);
		    infoRow.setAlignment(Pos.CENTER);

		    // Track Bar Row
		    HBox seekRow = new HBox(8, currentTimeLabel, trackBar, totalTimeLabel);
		    seekRow.setAlignment(Pos.CENTER);

		    // Control Row
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

			// Queue
		    HBox queueRow = new HBox(12, queueLabel, queueSpacer, clearBtn);
		    controlRow.setAlignment(Pos.CENTER);

		    queueCards.setPadding(new Insets(20, 32, 20, 32));

		    for (MediaHandler.Track track : queue) {
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

		    progressUpdater = new Timeline(new KeyFrame(Duration.millis(250), e -> updateProgress()));
		    progressUpdater.setCycleCount(Timeline.INDEFINITE);
		}

	    private void updatePausePlayButton(Button button, boolean isSelected) {
	        if (isSelected) {
	            playPauseImg = new Image(new File("./resources/pause.png").toURI().toString());
	        } else {
	            playPauseImg = new Image(new File("./resources/play.png").toURI().toString());
	        }

	        ImageView graphic = new ImageView(playPauseImg);
	        graphic.setFitWidth(25);
	        graphic.setFitHeight(25);
	        graphic.setPreserveRatio(true);

	        playPauseBtn.setGraphic(graphic);
	    }

	    private void updateLoopBtn(Button button, boolean isSelected) {
	        if (isSelected) {
	            loopImg = new Image(new File("./resources/loop_selected.png").toURI().toString());
	        } else {
	            loopImg = new Image(new File("./resources/loop_unselected.png").toURI().toString());
	        }

	        ImageView graphic = new ImageView(loopImg);
	        graphic.setFitWidth(25);
	        graphic.setFitHeight(25);
	        graphic.setPreserveRatio(true);

	        loopBtn.setGraphic(graphic);
	    }

	    private void updateProgress() {
		    if (player == null) return;
		    Duration current = player.getCurrentTime();
		    Duration total = player.getTotalDuration();
		    if (total != null && !total.isUnknown() && !trackBar.isValueChanging()) {
				trackBar.setValue(current.toMillis() / total.toMillis());
				currentTimeLabel.setText(formatTime(current));
		    }
		}

		private String formatTime(Duration d) {
		    int s = (int) d.toSeconds();
		    return String.format("%d:%02d", s / 60, s % 60);
		}

		private HBox buildCard(MediaHandler.Track track) {
		    Label nameLabel = new Label(track.title);
		    nameLabel.setStyle(
			"-fx-text-fill: #e8e8e8;" +
			"-fx-font-size: 17px;"
		    );
		    nameLabel.setMaxWidth(200);
        	nameLabel.setTextOverrun(OverrunStyle.ELLIPSIS);

		    Label artistLabel = new Label(track.artist);
		    artistLabel.setStyle(
			"-fx-text-fill: #555555;" +
			"-fx-font-size: 13px;"
		    );
		    nameLabel.setMaxWidth(200);
        	nameLabel.setTextOverrun(OverrunStyle.ELLIPSIS);

		    VBox textBlock = new VBox(3, nameLabel, artistLabel);
		    HBox.setHgrow(textBlock, Priority.ALWAYS);

		    Label durationLabel = new Label(track.duration);
		    artistLabel.setStyle(
			"-fx-text-fill: #555555;" +
			"-fx-font-size: 15px;"
		    );

		    Region spacer = new Region();
		    HBox.setHgrow(spacer, Priority.ALWAYS);

		    Label removeBtn = new Label("⛌");
		    removeBtn.setStyle(
			"-fx-text-fill: #e8e8e8;" +
			"-fx-font-size: 17px;" +
			"-fx-font-weight: bold;"
		    );
		    removeBtn.setOnMouseEntered(e -> removeBtn.setStyle(
			"-fx-text-fill: #555555;" +
			"-fx-font-size: 17px;" +
			"-fx-font-weight: bold;"
		    ));
		    removeBtn.setOnMouseExited(e -> removeBtn.setStyle(
			"-fx-text-fill: #e8e8e8;" +
			"-fx-font-size: 17px;" +
			"-fx-font-weight: bold;"
		    ));
		    removeBtn.setOnMouseClicked(e -> {
			    removeFromQueue(track);
		    });

		    HBox card = new HBox(12, textBlock, spacer, durationLabel, removeBtn);
		    card.setAlignment(Pos.CENTER_LEFT);
		    card.setPadding(new Insets(14, 18, 14, 18));
		    card.setStyle(
			"-fx-background-color: #161616;" +
			"-fx-background-radius: 10;" +
			"-fx-cursor: hand;"
		    );

		    card.setOnMouseEntered(e -> card.setStyle(
			"-fx-background-color: #1c1c1c;" +
			"-fx-background-radius: 10;" +
			"-fx-cursor: hand;"
		    ));
		    card.setOnMouseExited(e -> card.setStyle(
			"-fx-background-color: #161616;" +
			"-fx-background-radius: 10;" +
			"-fx-cursor: hand;"
		    ));

		    return card;
		}

		public void play(Track track) {
		    if (player != null) {
				player.stop();
				player.dispose();
		    }
		    String file = new File(assetsUrl + "/audio/" + track.trackID + ".wav").toURI().toString();
		    Media media = new Media(file);
		    player = new MediaPlayer(media);
		    player.play();
		    playing = true;
		    currTrack = track.trackID;
		    updatePausePlayButton(playPauseBtn, true);
		    titleLabel.setText(track.title);
		    artistLabel.setText(track.artist);
		    File coverFile = new File(assetsUrl + "/cover/" + track.trackID + ".jpg");
			if (!coverFile.exists()) {
			    coverFile = new File(assetsUrl + "/cover/default.jpg");
			}
			Image image = new Image(coverFile.toURI().toString());
		    trackCover.setImage(image);
		    progressUpdater.playFromStart();
		    player.setOnReady(() -> {
			Duration total = player.getTotalDuration();
			totalTimeLabel.setText(formatTime(total));
		    });
		    player.setOnEndOfMedia(this::next);
		    onRefresh.run();
		}

		public void pause() {
		    if (player != null) player.pause();
		    playing = false;
		    updatePausePlayButton(playPauseBtn, false);
		    progressUpdater.stop();
		}

		public void resume() {
		    if (player != null) player.play();
		    playing = true;
		    updatePausePlayButton(playPauseBtn, true);
		    progressUpdater.play();
		}

		public void seek(double percent) {
		    if (player != null) {
			Duration total = player.getTotalDuration();
			if (total != null && !total.isUnknown())
			    player.seek(total.multiply(percent));
		    }
		}

		public void next() {
			if (loop == true) {
	    		seek(0.0);
	    		resume();
		    }
		    else if (!queue.isEmpty()) {
				Track next = queue.remove(0);
				play(next);
		    } 
		    else if (!playlist.isEmpty()) {
		    	if (shuffle == true) {
		    		Random rand = new Random();
		    		int idx = rand.nextInt(playlist.size());
		    		Track next = playlist.remove(idx);
					play(next);
		    	} 
		    	else {
		    		Track next = playlist.remove(0);
					play(next);
		    	}
			} 
			else {
				if (player != null) player.stop();
					playing = false;
					progressUpdater.stop();
			    }
			    queueCards.getChildren().clear();
			    for (MediaHandler.Track curr : queue) {
				HBox card = buildCard(curr);
				queueCards.getChildren().add(card);
	   		}
		}

		public void addToQueue(Track track) {
		    queue.add(track);
		    queueCards.getChildren().clear();
		    for (MediaHandler.Track curr : queue) {
				HBox card = buildCard(curr);
				queueCards.getChildren().add(card);
		    }
		}

		public void addToPlaylistQueue(Track track) {
		    playlist.add(track);
	    }

		public void removeFromQueue(Track track) {
		    queue.removeIf(t -> t.trackID == track.trackID);
		    queueCards.getChildren().clear();
		    for (MediaHandler.Track curr : queue) {
				HBox card = buildCard(curr);
				queueCards.getChildren().add(card);
		    }
		}

		public void clearQueue() {
			queueCards.getChildren().clear();
			queue.clear();
		}

		public void clearPlaylistQueue() {
			playlist.clear();
		}

		public void setShuffle() {
			shuffle = !shuffle;
		}

		public boolean isShuffled() {
			return shuffle;
		}

		public boolean trackPlaying(Track track) {
			if (track.trackID == currTrack) {
				return true;
			}
			else {
				return false;
			}
		}

		public boolean isPlaying() {
			return playing;
		}
    }

    // Database methods
    
	public ArrayList<Track> searchTracks(String filter) { 
	    String sql = "SELECT * FROM Tracks WHERE title LIKE ? ORDER BY title ASC"; 
	    ArrayList<Track> tracks = new ArrayList<>(); 
	    
	    try (java.sql.Connection conn = java.sql.DriverManager.getConnection(databaseUrl); 
	         java.sql.PreparedStatement pstmt = conn.prepareStatement(sql)) { 
	        
	        pstmt.setString(1, "%" + filter + "%");
	        
	        try (java.sql.ResultSet rs = pstmt.executeQuery()) {
	            while (rs.next()) { 
	                tracks.add(new Track(
	                    rs.getInt("track_id"), 
	                    rs.getString("title"), 
	                    rs.getString("artist"),
	                    rs.getString("duration"),
	                    true,
	                    ""
	                )); 
	            } 
	        }
	    } catch (java.sql.SQLException e) { 
	        System.err.println("Could not load tracks: " + e.getMessage()); 
	    } 
	    return tracks; 
	}


    public ArrayList<Playlist> loadPlaylists() {
		String sql = "SELECT * FROM Playlists";
		ArrayList<Playlist> tracks = new ArrayList<>();

		try (java.sql.Connection conn = java.sql.DriverManager.getConnection(databaseUrl);
		     java.sql.Statement  stmt = conn.createStatement();
		     java.sql.ResultSet  rs   = stmt.executeQuery(sql)) {

		    while (rs.next()) {
			tracks.add(new Playlist(
			    rs.getInt("playlist_id"),
			    rs.getString("title")
			));
		    }

		} catch (java.sql.SQLException e) {
		    System.err.println("Could not load playlists: " + e.getMessage());
		}

		return tracks;
    }
    
	public ArrayList<Track> loadPlaylistTracks(Integer playlistID) {
	    List<Integer> ids = new ArrayList<>();
	    String tableName = "playlist_" + playlistID;
	    String getTrackIDs = "SELECT * FROM " + tableName + " ORDER BY [order] ASC";
	    ArrayList<Track> tracks = new ArrayList<>();
	    try (java.sql.Connection conn = java.sql.DriverManager.getConnection(databaseUrl);
	         java.sql.Statement stmt = conn.createStatement();
	         java.sql.ResultSet rs = stmt.executeQuery(getTrackIDs)) {
	        while (rs.next()) {
	            ids.add(rs.getInt("track_id"));
	        }

	    } catch (java.sql.SQLException e) {
	        System.err.println("Could not load playlist track IDs: " + e.getMessage());
	    }
	    for (int i = 0; i < ids.size(); i++) {
	        Integer id = ids.get(i);
	        String getTracks = "SELECT * FROM Tracks WHERE track_id=" + id;
	        try (java.sql.Connection conn = java.sql.DriverManager.getConnection(databaseUrl);
	            java.sql.Statement stmt = conn.createStatement();
	            java.sql.ResultSet rs = stmt.executeQuery(getTracks)) {
	            while (rs.next()) {
	                tracks.add(new Track(
	                    rs.getInt("track_id"),
	                    rs.getString("title"),
	                    rs.getString("artist"),
	                    rs.getString("duration"),
	                    true,
	                    ""
	                ));
	            }
	        } catch (java.sql.SQLException e) {
	            System.err.println("Could not load track: " + e.getMessage());
	        }
	    }
	    return tracks;
	}

	public void addToPlaylist(Integer playlist_id, Integer track_id) {
	    String tableName = "playlist_" + playlist_id;
	    String sql = "INSERT INTO " + tableName + " ([order], track_id) VALUES ((SELECT COALESCE(MAX([order]), 0) + 1 FROM " + tableName + "), ?);";
	    try (java.sql.Connection conn = java.sql.DriverManager.getConnection(databaseUrl);
	         java.sql.PreparedStatement pstmt = conn.prepareStatement(sql)) {

	        pstmt.setInt(1, track_id);
	        pstmt.executeUpdate();

	    } catch (java.sql.SQLException e) {
	        System.err.println("Could not add track to playlist: " + e.getMessage());
	    }
	}

	public void removeFromPlaylist(Integer playlist_id, Integer track_id) {
	    String tableName = "playlist_" + playlist_id;
	    String sql = "DELETE FROM " + tableName + " WHERE track_id = ?;";
	    try (java.sql.Connection conn = java.sql.DriverManager.getConnection(databaseUrl);
	         java.sql.PreparedStatement pstmt = conn.prepareStatement(sql)) {

	        pstmt.setInt(1, track_id);
	        pstmt.executeUpdate();

	    } catch (java.sql.SQLException e) {
	        System.err.println("Could not remove track from playlist: " + e.getMessage());
	    }
	}

	public void changeTrackOrder(Integer playlist_id, Integer track_id, Integer new_order) {
	    String tableName = "playlist_" + playlist_id;
	    String sql = "UPDATE " + tableName + " SET [order] = ? WHERE track_id = ?;";
	    try (java.sql.Connection conn = java.sql.DriverManager.getConnection(databaseUrl);
	         java.sql.PreparedStatement pstmt = conn.prepareStatement(sql)) {
	        pstmt.setInt(1, new_order);
	        pstmt.setInt(2, track_id);
	        pstmt.executeUpdate();
	    } catch (java.sql.SQLException e) {
	        System.err.println("Could not change track order: " + e.getMessage());
	    }
	}

	public boolean isInPlaylist(Integer playlist_id, Integer track_id) {
	    String tableName = "playlist_" + playlist_id;
	    String sql = "SELECT 1 FROM " + tableName + " WHERE track_id = ? LIMIT 1;";

	    try (java.sql.Connection conn = java.sql.DriverManager.getConnection(databaseUrl);
	         java.sql.PreparedStatement pstmt = conn.prepareStatement(sql)) {

	        pstmt.setInt(1, track_id);
	        try (java.sql.ResultSet rs = pstmt.executeQuery()) {
	            return rs.next();
	        }

	    } catch (java.sql.SQLException e) {
	        System.err.println("Could not check playlist contents: " + e.getMessage());
	        return false;
	    }
	}

	public void createPlaylist() {
		// String dbPath = databaseUrl.replace("jdbc:sqlite:", "");
	    // java.io.File dbFile = new java.io.File(dbPath);
	    // log("DB exists: " + dbFile.exists());
	    // log("DB writable: " + dbFile.canWrite());

	    java.util.Random random = new java.util.Random();

	    String title = "New Playlist";

	    try (java.sql.Connection conn = java.sql.DriverManager.getConnection(databaseUrl)) {

	        int newPlaylistId;
	        while (true) {
	            newPlaylistId = 10000 + random.nextInt(90000);
	            String checkSQL = "SELECT 1 FROM Playlists WHERE playlist_id = ?";
	            try (java.sql.PreparedStatement checkStmt = conn.prepareStatement(checkSQL)) {
	                checkStmt.setInt(1, newPlaylistId);
	                try (java.sql.ResultSet rs = checkStmt.executeQuery()) {
	                    if (!rs.next()) break;
	                }
	            }
	        }

	        String tableName = "playlist_" + newPlaylistId;
	        String createTableSQL = "CREATE TABLE " + tableName + " (" +
	            "[order] INTEGER, " +
	            "track_id INTEGER" +
	            ");";
	        try (java.sql.Statement stmt = conn.createStatement()) {
	            stmt.execute(createTableSQL);
	        }

	        // Register the playlist in the Playlists table
	        String insertSQL = "INSERT INTO Playlists (playlist_id, title) VALUES (?, ?)";
	        try (java.sql.PreparedStatement pstmt = conn.prepareStatement(insertSQL)) {
	            pstmt.setInt(1, newPlaylistId);
	            pstmt.setString(2, title);
	            pstmt.executeUpdate();
	        }

	        String insertIDSQL = "INSERT INTO PlaylistIDs (playlist_id) VALUES (?)";
			try (java.sql.PreparedStatement pstmt = conn.prepareStatement(insertIDSQL)) {
			    pstmt.setInt(1, newPlaylistId);
			    pstmt.executeUpdate();
			}

	    } catch (java.sql.SQLException e) {
	        System.err.println("Could not create playlist: " + e.getMessage());
	    }
	}

	public void deletePlaylist(Integer playlist_id) {
	    String tableName = "playlist_" + playlist_id;

	    try (java.sql.Connection conn = java.sql.DriverManager.getConnection(databaseUrl)) {

	        String dropTableSQL = "DROP TABLE IF EXISTS " + tableName + ";";
	        try (java.sql.Statement stmt = conn.createStatement()) {
	            stmt.execute(dropTableSQL);
	        }

	        String deleteSQL = "DELETE FROM Playlists WHERE playlist_id = ?;";
	        try (java.sql.PreparedStatement pstmt = conn.prepareStatement(deleteSQL)) {
	            pstmt.setInt(1, playlist_id);
	            pstmt.executeUpdate();
	        }

	        String deleteIDSQL = "DELETE FROM PlaylistIDs WHERE playlist_id = ?;";
			try (java.sql.PreparedStatement pstmt = conn.prepareStatement(deleteIDSQL)) {
			    pstmt.setInt(1, playlist_id);
			    pstmt.executeUpdate();
			}

	    } catch (java.sql.SQLException e) {
	        System.err.println("Could not delete playlist: " + e.getMessage());
	    }
	}

	public void editPlaylistTitle(Integer playlist_id, String newTitle) {
	    String sql = "UPDATE Playlists SET title = ? WHERE playlist_id = ?;";
	    try (java.sql.Connection conn = java.sql.DriverManager.getConnection(databaseUrl);
	        java.sql.PreparedStatement pstmt = conn.prepareStatement(sql)) {
	        pstmt.setString(1, newTitle);
	        pstmt.setInt(2, playlist_id);
	        pstmt.executeUpdate();

	    } catch (java.sql.SQLException e) {
	        System.err.println("Could not edit playlist title: " + e.getMessage());
	    }
	}

	public static void newTrack(Track track) {
		String sql = "INSERT OR IGNORE INTO Tracks (track_id, title, artist, duration) VALUES (?, ?, ?, ?)";
	    try (java.sql.Connection conn = java.sql.DriverManager.getConnection(databaseUrl);
	        java.sql.PreparedStatement pstmt = conn.prepareStatement(sql)) {
	        pstmt.setInt(1, track.trackID);
	        pstmt.setString(2, track.title);
	        pstmt.setString(3, track.artist);
	        pstmt.setString(4, track.duration);
	        pstmt.executeUpdate();

	    } catch (java.sql.SQLException e) {
	        System.err.println("Could not add track: " + e.getMessage());
	    }
	}

}

