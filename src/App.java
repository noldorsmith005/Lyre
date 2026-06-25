package Napster;

import java.io.File;
import java.util.List;
import java.util.Optional;
import java.util.ArrayList;
import java.util.Random;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.function.BiConsumer;
import java.nio.file.Path;
import javafx.util.Duration;
import javafx.application.Application;
import javafx.geometry.Insets;
import javafx.geometry.Pos;
import javafx.geometry.Bounds;
import javafx.scene.Scene;
import javafx.scene.control.*;
import javafx.scene.layout.*;
import javafx.scene.image.Image;
import javafx.scene.image.ImageView;
import javafx.scene.shape.Rectangle;
import javafx.scene.input.KeyCode;
import javafx.scene.input.ScrollEvent;
import javafx.scene.input.MouseEvent;
import javafx.scene.effect.GaussianBlur;
import javafx.scene.control.Alert;
import javafx.scene.control.Alert.AlertType;
import javafx.scene.Node;
import javafx.scene.paint.Color;
import javafx.scene.canvas.Canvas;
import javafx.stage.Stage;
import javafx.stage.Popup;
import javafx.stage.FileChooser;
import javafx.animation.Timeline;
import javafx.animation.KeyFrame;
import javafx.animation.KeyValue;
import javafx.animation.Animation;
import javafx.animation.AnimationTimer;
import javafx.animation.Interpolator;
import javafx.application.Platform;
import java.lang.reflect.Method;
import javafx.event.EventHandler;



public class App extends Application {
    public static Path appData;
    private String assetsUrl;

    public static MediaHandler mediaHandler;
    private static ServerClient serverClient;
    private static AudioPlayer audioPlayer;
    private DragHandler dragHandler;

    private Stage mainStage = new Stage();
    private HBox rootContent = new HBox();
    private StackPane root = new StackPane(rootContent);
    private Scene scene;

    private boolean serverConnection = false;
    private Label panelTitle = new Label("Select a playlist");
    private Label subtitle = new Label("0 tracks");
    private Image shuffleImg = new Image(new File("./resources/shuffle_unselected.png").toURI().toString());
    private Button shuffleBtn = new Button();
    private Image rlsImg = new Image(new File("./resources/library_unselected.png").toURI().toString());
    private Button rlsBtn = new Button();
    private ListView<AudioPlayer.Track> track_list;
    private AudioPlayer.Playlist currPlaylist;
    private VBox itemList = new VBox(2);
    private VBox sidebarVBox;
    private ArrayList<AudioPlayer.Playlist> playlists = new ArrayList<>();
    private ArrayList<AudioPlayer.Track> playlist_tracks = new ArrayList<>();

    private ScheduledExecutorService scheduler = Executors.newSingleThreadScheduledExecutor();
    private ScheduledFuture<?> hoverTask;
    private AnimationTimer activeScrollTimer = null;

    String audioPath = "";
    String coverPath = "";



    @Override
    public void start(Stage stage) {
        String home = System.getProperty("user.home");
        String os = System.getProperty("os.name").toLowerCase();

        if (os.contains("mac")) {
            appData = Path.of(home, "Library", "Application Support", "Napster");
        } else if (os.contains("win")) {
            appData = Path.of(System.getenv("APPDATA"), "Napster");
        } else {
            appData = Path.of(home, ".config", "Napster/");
        }
        assetsUrl = appData.toString();

        // Handler Initializations
        mediaHandler = new MediaHandler();
        serverClient = new ServerClient();
        audioPlayer = new AudioPlayer(() -> refresh());

        playlists = mediaHandler.loadPlaylists();

        rootContent.setStyle("-fx-background-color: #000000;"); // #0f0f0f

        VBox sidebar = buildSidebar();
        HBox.setHgrow(sidebar, Priority.NEVER);

        VBox mainPanel = buildMainPanel();
        HBox.setHgrow(mainPanel, Priority.ALWAYS);

        VBox mediaPanel = buildMediaPanel();
        HBox.setHgrow(mediaPanel, Priority.NEVER);
        VBox.setVgrow(mediaPanel, Priority.ALWAYS);
        mediaPanel.setMaxHeight(Double.MAX_VALUE);

        rootContent.getChildren().addAll(sidebar, mainPanel, mediaPanel);

        scene = new Scene(root);

        stage.setScene(scene);
        stage.setMaximized(true);
        stage.show();
        stage.setResizable(false);

        scene.setOnKeyPressed(e -> {
            if (e.getCode() == KeyCode.SPACE) {
                audioPlayer.playPauseBtn.fire();
                e.consume();
            }
        });

        stage.widthProperty().addListener((obs, oldW, newW) -> {
            double w = newW.doubleValue();
            sidebar.setPrefWidth(w * 0.25);
            sidebar.setMinWidth(w * 0.25);
            sidebar.setMaxWidth(w * 0.25);
            mediaPanel.setPrefWidth(w * 0.25);
            mediaPanel.setMinWidth(w * 0.25);
            mediaPanel.setMaxWidth(w * 0.25);
        });

        stage.setOnCloseRequest(event -> scheduler.shutdownNow());

        mainStage = stage;
    }


    // ── Playlists Side Panel ───────────────────────────────────────────────────
    private VBox buildSidebar() {
        Label appName = new Label("Playlists");
        appName.setStyle(
            "-fx-text-fill: #ffffff;" +
            "-fx-font-size: 25px;" +
            "-fx-font-weight: bold;" +
            "-fx-padding: 0 0 0 4;"
        );

        Label newBtn = new Label("+");
        newBtn.setStyle(
            "-fx-text-fill: #ffffff;" +
            "-fx-font-size: 35px;" +
            "-fx-font-weight: 300;" +
            "-fx-cursor: hand;"
        );
        newBtn.setOnMouseEntered(e -> newBtn.setStyle(
            "-fx-text-fill: #888888;" +
            "-fx-font-size: 35px;" +
            "-fx-font-weight: 300;" +
            "-fx-cursor: hand;"
        ));
        newBtn.setOnMouseExited(e -> newBtn.setStyle(
            "-fx-text-fill: #ffffff;" +
            "-fx-font-size: 35px;" +
            "-fx-font-weight: 300;" +
            "-fx-cursor: hand;"
        ));
        newBtn.setOnMouseClicked(e -> {
            mediaHandler.createPlaylist();
            refreshSidebarList();
        });

        Region spacer = new Region();
        HBox.setHgrow(spacer, Priority.ALWAYS);

        HBox header = new HBox(appName, spacer, newBtn);
        header.setAlignment(Pos.CENTER_LEFT);
        header.setPadding(new Insets(24, 20, 20, 20));
        header.setStyle(
            "-fx-border-color: transparent transparent #2a2a2a transparent;" +
            "-fx-border-width: 0 0 1 0;"
        );

        itemList.setPadding(new Insets(12, 10, 12, 10));
        refreshSidebarList();

        ScrollPane scroll = new ScrollPane(itemList);
        scroll.setFitToWidth(true);
        scroll.setHbarPolicy(ScrollPane.ScrollBarPolicy.NEVER);
        scroll.setStyle(
            "-fx-background: transparent;" +
            "-fx-background-color: transparent;" +
            "-fx-border-color: transparent;"
        );
        VBox.setVgrow(scroll, Priority.ALWAYS);

        sidebarVBox = new VBox(header, scroll);
        sidebarVBox.setFocusTraversable(true);
        sidebarVBox.setOnMousePressed(e -> sidebarVBox.requestFocus());
        sidebarVBox.setStyle(
            "-fx-background-color: #000000;" +
            "-fx-border-color: transparent #2a2a2a transparent transparent;" +
            "-fx-border-width: 0 1 0 0;"
        );
        sidebarVBox.setPrefWidth(260);

        return sidebarVBox;
    }


    // ── Main panel ────────────────────────────────────────────────
    private VBox buildMainPanel() {
        // Search Bar
        TextField search = new TextField();
        search.setPromptText("Search songs...");
        search.setStyle(
            "-fx-background-color: #000000;" +
            "-fx-text-fill: #ffffff;" +
            "-fx-prompt-text-fill: #b3b3b3;" +
            "-fx-background-radius: 500;" +
            "-fx-border-color: #ffffff;" +
            "-fx-border-radius: 500;" +
            "-fx-border-width: 0.8;" +
            "-fx-padding: 13 42 13 48;" +
            "-fx-font-size: 16px;" +
            "-fx-font-family: 'Circular', 'Helvetica Neue', Helvetica, Arial, sans-serif;"
        );
        search.setPrefWidth(360);
        search.setPrefHeight(50);
        search.setOnAction(event -> {
            String query = search.getText();
            if (query.strip().isEmpty() == false) {
                if (serverConnection == true) {
                    try {
                        playlist_tracks = serverClient.searchTracks(query);
                    } catch (Exception e) {
                        System.out.println("Something went wrong with the search: " + e.getMessage());
                        e.printStackTrace();
                    }
                }
                else {
                    playlist_tracks = mediaHandler.searchTracks(query);
                }
                displayAll();
            }
        });

        Image searchImg = new Image(new File("./resources/search.png").toURI().toString());
        ImageView searchIcon = new ImageView(searchImg);
        searchIcon.setFitWidth(18);
        searchIcon.setFitHeight(18);
        searchIcon.setPreserveRatio(true);
        searchIcon.setMouseTransparent(true);
        StackPane.setMargin(searchIcon, new Insets(0, 0, 0, 14));

        Label clearBtn = new Label("✕");
        clearBtn.setStyle(
            "-fx-background-color: transparent;" +
            "-fx-text-fill: #555555;" +
            "-fx-font-size: 22px;" +
            "-fx-cursor: hand;" +
            "-fx-padding: 0;" +
            "-fx-min-width: 16px;" +
            "-fx-min-height: 16px;"
        );
        clearBtn.setVisible(false);
        clearBtn.setOnMouseClicked(e -> {
            search.clear();
            search.requestFocus();
        });
        search.textProperty().addListener((obs, oldVal, newVal) ->
            clearBtn.setVisible(newVal != null && !newVal.isEmpty())
        );
        clearBtn.setOnMouseEntered(e -> clearBtn.setStyle(
            "-fx-background-color: transparent;" +
            "-fx-text-fill: #aaaaaa;" +
            "-fx-font-size: 22px;" +
            "-fx-cursor: hand;" +
            "-fx-padding: 0;" +
            "-fx-min-width: 16px;" +
            "-fx-min-height: 16px;"
        ));
        clearBtn.setOnMouseExited(e -> clearBtn.setStyle(
            "-fx-background-color: transparent;" +
            "-fx-text-fill: #555555;" +
            "-fx-font-size: 22px;" +
            "-fx-cursor: hand;" +
            "-fx-padding: 0;" +
            "-fx-min-width: 16px;" +
            "-fx-min-height: 16px;"
        ));

        StackPane searchWrapper = new StackPane();
        searchWrapper.setAlignment(Pos.CENTER_LEFT);
        StackPane.setAlignment(clearBtn, Pos.CENTER_RIGHT);
        StackPane.setMargin(clearBtn, new Insets(0, 12, 0, 0));
        searchWrapper.getChildren().addAll(search, searchIcon, clearBtn);

        // Remote Library Server (RLS) Connection Button
        ImageView rlsView = new ImageView(rlsImg);
        rlsView.setFitWidth(30);
        rlsView.setFitHeight(30);
        rlsView.setPreserveRatio(true);
        rlsBtn.setGraphic(rlsView);
        rlsBtn.setStyle(
            "-fx-background-color: transparent;" +
            "-fx-border-color: transparent;" +
            "-fx-cursor: hand;" +
            "-fx-padding: 6;"
        );
        rlsBtn.setOnAction(event -> {
            if (serverConnection == false && serverClient.registered() == false) {
                openRegisterModal(mainStage, root);
            }
            else {
                if (serverClient.ping() == true) {
                    serverConnection = !serverConnection;
                    updateRlsButtonStyle(serverConnection);
                }
                else {
                    triggerAlert("Server Error", "Server Offline");
                }
            }
        });
        rlsBtn.setOnMouseEntered(e ->
            rlsBtn.setStyle(
                "-fx-background-color: transparent;" +
                "-fx-background-radius: 500;" +
                "-fx-border-color: transparent;" +
                "-fx-cursor: hand;" +
                "-fx-padding: 6;"
            )
        );
        rlsBtn.setOnMouseExited(e ->
            rlsBtn.setStyle(
                "-fx-background-color: transparent;" +
                "-fx-border-color: transparent;" +
                "-fx-cursor: hand;" +
                "-fx-padding: 6;"
            )
        );
        updateRlsButtonStyle(serverConnection);

        // Upload Button
        Button uploadBtn = new Button();
        Image uploadImg = new Image(new File("./resources/upload.png").toURI().toString());
        ImageView uploadGraphic = new ImageView(uploadImg);
        uploadGraphic.setFitWidth(25);
        uploadGraphic.setFitHeight(25);
        uploadGraphic.setPreserveRatio(true);
        uploadBtn.setGraphic(uploadGraphic);
        uploadBtn.setStyle(
            "-fx-background-color: transparent;" +
            "-fx-border-color: transparent;" +
            "-fx-cursor: hand;" +
            "-fx-padding: 6;"
        );
        uploadBtn.setOnAction(e -> {
            if (serverConnection == true) {
                coverPath = "";
                audioPath = "";
                openUploadModal(mainStage, root);
            }
            else {
                triggerAlert("Server Error", "Connect to server");
            }
        });

        // Clear Server Config Button
        Button clearConfigBtn = new Button();
        Image clearConfigImg = new Image(new File("./resources/clear_config.png").toURI().toString());
        ImageView clearConfigGraphic = new ImageView(clearConfigImg);
        clearConfigGraphic.setFitWidth(30);
        clearConfigGraphic.setFitHeight(30);
        clearConfigGraphic.setPreserveRatio(true);
        clearConfigBtn.setGraphic(clearConfigGraphic);
        clearConfigBtn.setStyle(
            "-fx-background-color: transparent;" +
            "-fx-border-color: transparent;" +
            "-fx-cursor: hand;" +
            "-fx-padding: 6;"
        );
        clearConfigBtn.setOnAction(e -> {
            Alert alert = new Alert(Alert.AlertType.CONFIRMATION);
            alert.setTitle("Confirm");
            alert.setHeaderText(null);
            alert.setGraphic(null);
            alert.setContentText("Are you sure you want to clear your server configuration? You will have to re-authenticate. ");

            DialogPane dialogPane = alert.getDialogPane();
            dialogPane.setStyle("-fx-background-color: #2b2b2b;");

            alert.setOnShown(ev -> {
                Node content = dialogPane.lookup(".content.label");
                if (content != null) content.setStyle("-fx-text-fill: white;");
                for (ButtonType bt : dialogPane.getButtonTypes()) {
                    Button btn = (Button) dialogPane.lookupButton(bt);
                    if (btn != null) {
                        if (bt == ButtonType.CANCEL) {
                            btn.setStyle(
                                "-fx-background-color: #808080;" +
                                "-fx-text-fill: white;" +
                                "-fx-background-radius: 3px;" +
                                "-fx-cursor: hand;"
                            );
                        } else {
                            btn.setStyle(
                                "-fx-background-color: #FF0000;" +
                                "-fx-text-fill: white;" +
                                "-fx-background-radius: 3px;" +
                                "-fx-cursor: hand;"
                            );
                        }
                    }
                }
            });

            Optional<ButtonType> result = alert.showAndWait();
            if (result.isPresent() && result.get() == ButtonType.OK) {
                serverClient.clearRLSConfig();
            }
        });

        // Spacers
        Region spacer = new Region();
        HBox.setHgrow(spacer, Priority.ALWAYS);
        Region searchSpacer = new Region();
        HBox.setHgrow(searchSpacer, Priority.ALWAYS);
        Region vSpacer = new Region();
        VBox.setVgrow(vSpacer, Priority.ALWAYS);

        HBox searchBar = new HBox(8, searchWrapper, rlsBtn, searchSpacer, uploadBtn, clearConfigBtn);
        searchBar.setAlignment(Pos.CENTER_LEFT);
        searchBar.setMaxWidth(Double.MAX_VALUE);

        StackPane searchContainer = new StackPane(searchBar, clearBtn);
        StackPane.setAlignment(clearBtn, Pos.CENTER_RIGHT);
        StackPane.setMargin(clearBtn, new Insets(0, 8, 0, 0));

        HBox topBar = new HBox(searchContainer);
        topBar.setAlignment(Pos.CENTER_LEFT);
        topBar.setPadding(new Insets(16, 32, 16, 32));
        topBar.setStyle(
            "-fx-border-color: transparent transparent #2a2a2a transparent;" +
            "-fx-border-width: 0 0 1 0;"
        );
        HBox.setHgrow(searchContainer, Priority.ALWAYS);

        // Edit Playlist Popup
        Popup editPopup = new Popup();
        editPopup.setAutoHide(true);

        VBox editContainer = new VBox();
        editContainer.setSpacing(8);
        editContainer.setStyle(
            "-fx-background-color: #2b2b2b;" +
            "-fx-padding: 10px;" +
            "-fx-background-radius: 5px;"
        );

        TextField editTextField = new TextField();
        editTextField.setPromptText("New name...");
        editTextField.setStyle(
            "-fx-background-color: #3c3f41;" +
            "-fx-text-fill: white;" +
            "-fx-prompt-text-fill: #7f8c8d;" +
            "-fx-background-radius: 3px;" +
            "-fx-padding: 8px 15px;"
        );
        editTextField.setOnAction(e -> {
            mediaHandler.editPlaylistTitle(currPlaylist.playlistID, editTextField.getText());
            panelTitle.setText(editTextField.getText());
            refreshSidebarList();
            editTextField.clear();
        });

        Button deleteBtn = new Button("Delete Playlist");
        deleteBtn.setStyle(
            "-fx-background-color: #FF0000;" +
            "-fx-text-fill: white;" +
            "-fx-background-radius: 3px;" +
            "-fx-cursor: hand;" +
            "-fx-padding: 8px 15px;"
        );
        deleteBtn.setOnAction(e -> {
            Alert alert = new Alert(Alert.AlertType.CONFIRMATION);
            alert.setTitle("Confirm");
            alert.setHeaderText(null);
            alert.setGraphic(null);
            alert.setContentText("Are you sure you want to delete " + panelTitle.getText() + "?");

            DialogPane dialogPane = alert.getDialogPane();
            dialogPane.setStyle("-fx-background-color: #2b2b2b;");

            alert.setOnShown(ev -> {
                Node content = dialogPane.lookup(".content.label");
                if (content != null) content.setStyle("-fx-text-fill: white;");
                for (ButtonType bt : dialogPane.getButtonTypes()) {
                    Button btn = (Button) dialogPane.lookupButton(bt);
                    if (btn != null) {
                        if (bt == ButtonType.CANCEL) {
                            btn.setStyle(
                                "-fx-background-color: #808080;" +
                                "-fx-text-fill: white;" +
                                "-fx-background-radius: 3px;" +
                                "-fx-cursor: hand;"
                            );
                        } else {
                            btn.setStyle(
                                "-fx-background-color: #FF0000;" +
                                "-fx-text-fill: white;" +
                                "-fx-background-radius: 3px;" +
                                "-fx-cursor: hand;"
                            );
                        }
                    }
                }
            });

            Optional<ButtonType> result = alert.showAndWait();
            if (result.isPresent() && result.get() == ButtonType.OK) {
                mediaHandler.deletePlaylist(currPlaylist.playlistID);
                refreshSidebarList();
            }
        });

        editContainer.setPrefSize(350, 150);
        editContainer.getChildren().addAll(editTextField, vSpacer, deleteBtn);
        editPopup.getContent().add(editContainer);

        // Header
        panelTitle.setStyle(
            "-fx-text-fill: #ffffff;" +
            "-fx-font-size: 25px;" +
            "-fx-font-weight: bold;"
        );
        subtitle.setStyle(
            "-fx-text-fill: #555555;" +
            "-fx-font-size: 15px;"
        );

        Button editBtn = new Button("Edit Playlist");
        editBtn.setStyle("""
            -fx-background-color: transparent;
            -fx-font-size: 14px;
            -fx-cursor: hand;
            -fx-text-fill: #ffffff;
            -fx-alignment: center-left;
            -fx-padding: 0;
        """);
        editBtn.setOnMouseEntered(e -> editBtn.setStyle("""
            -fx-background-color: transparent;
            -fx-font-size: 14px;
            -fx-cursor: hand;
            -fx-text-fill: #555555;
            -fx-alignment: center-left;
            -fx-padding: 0;
        """));
        editBtn.setOnMouseExited(e -> editBtn.setStyle("""
            -fx-background-color: transparent;
            -fx-font-size: 14px;
            -fx-cursor: hand;
            -fx-text-fill: #ffffff;
            -fx-alignment: center-left;
            -fx-padding: 0;
        """));
        editBtn.setOnAction(e -> {
            double x = editBtn.localToScreen(editBtn.getBoundsInLocal()).getMinX();
            double y = editBtn.localToScreen(editBtn.getBoundsInLocal()).getMaxY();
            editPopup.show(editBtn, (x + 200), (y + 20));
        });

        // Shuffle Button
        ImageView shuffleGraphic = new ImageView(shuffleImg);
        shuffleGraphic.setFitWidth(35);
        shuffleGraphic.setFitHeight(35);
        shuffleGraphic.setPreserveRatio(true);
        shuffleBtn.setGraphic(shuffleGraphic);
        shuffleBtn.setStyle("-fx-background-color: transparent; -fx-cursor: hand;");
        shuffleBtn.setOnAction(e -> {
            audioPlayer.setShuffle();
            updateShuffleButtonStyle(audioPlayer.isShuffled());
        });
        updateShuffleButtonStyle(audioPlayer.isShuffled());

        VBox titleBlock = new VBox(4, panelTitle, subtitle, editBtn);
        HBox headerRow = new HBox(titleBlock, spacer, shuffleBtn);
        headerRow.setAlignment(Pos.CENTER_LEFT);
        HBox.setHgrow(titleBlock, Priority.ALWAYS);
        headerRow.setPadding(new Insets(28, 32, 20, 32));
        headerRow.setStyle(
            "-fx-border-color: transparent transparent #2a2a2a transparent;" +
            "-fx-border-width: 0 0 1 0;"
        );

        track_list = buildTrackListView();
        StackPane trackListContainer = new StackPane(track_list);
        trackListContainer.setStyle("-fx-background-color: #000000;");
        VBox.setVgrow(trackListContainer, Priority.ALWAYS);

        Canvas dropCanvas = new Canvas();
        dropCanvas.setMouseTransparent(true);
        dropCanvas.widthProperty().bind(trackListContainer.widthProperty());
        dropCanvas.heightProperty().bind(trackListContainer.heightProperty());
        trackListContainer.getChildren().add(dropCanvas);

        dragHandler = new DragHandler(() -> {
            updateOrder(currPlaylist.playlistID);
            refreshTrackList(currPlaylist);
        }, this::autoScroll, dropCanvas);

        VBox panel;
        if (currPlaylist != null) {
            panel = new VBox(topBar, headerRow, trackListContainer);
        }
        else {
            panel = new VBox(topBar, trackListContainer);
        }

        panel.setFocusTraversable(true);
        panel.setOnMousePressed(e -> panel.requestFocus());
        panel.setStyle("-fx-background-color: #000000;");
        VBox.setVgrow(track_list, Priority.ALWAYS);

        return panel;
    }


    // ── Media panel ────────────────────────────────────────────────
    private VBox buildMediaPanel() {
        VBox panel = new VBox();
        panel.setFocusTraversable(true);
        panel.setOnMousePressed(e -> panel.requestFocus());
        VBox.setVgrow(audioPlayer, Priority.ALWAYS);
        panel.getChildren().add(audioPlayer);
        return panel;
    }


    // ── Track List Builder ──────────────────────────────────────
    private ListView<AudioPlayer.Track> buildTrackListView() {
        ListView<AudioPlayer.Track> listView = new ListView<>();
        listView.setFixedCellSize(80);
        listView.setStyle(
            "-fx-background-color: #000000;" +
            "-fx-border-color: transparent;" +
            "-fx-padding: 20 32 20 32;"
        );
        VBox.setVgrow(listView, Priority.ALWAYS);

        listView.setCellFactory(lv -> new ListCell<>() {
            @Override
            protected void updateItem(AudioPlayer.Track track, boolean empty) {
                super.updateItem(track, empty);
                if (empty || track == null) {
                    setGraphic(null);
                    setText(null);
                    setStyle(
                        "-fx-background-color: #000000;" +
                        "-fx-padding: 0;" +
                        "-fx-border-color: transparent;"
                    );
                } else {
                    HBox trackRow = new HBox(12);
                    HBox card = buildCard(track);

                    if (currPlaylist != null) {
                        Label orderLabel = new Label(Integer.toString(getOrder(track)));
                        orderLabel.setStyle(
                            "-fx-text-fill: #555555;" +
                            "-fx-font-size: 15px;"
                        );
                        HBox.setHgrow(card, Priority.ALWAYS);
                        trackRow.setAlignment(Pos.CENTER_LEFT);
                        trackRow.getChildren().addAll(orderLabel, card);
                    } else {
                        HBox.setHgrow(card, Priority.ALWAYS);
                        trackRow.getChildren().add(card);
                    }

                    if (currPlaylist != null) {
                        dragHandler.setupCardDrag(trackRow, track, listView, playlist_tracks);
                    }
                    setGraphic(trackRow);
                    setText(null);
                    setStyle(
                        "-fx-background-color: #000000;" +
                        "-fx-padding: 4 0 4 0;" +
                        "-fx-border-color: transparent;"
                    );
                }
            }
        });

        listView.getStylesheets().add("data:text/css," + java.net.URLEncoder.encode(
            ".list-view .scroll-bar:vertical { -fx-opacity: 0; -fx-pref-width: 0; }" +
            ".list-view .scroll-bar:vertical .track { -fx-pref-width: 0; }" +
            ".list-view .scroll-bar:vertical .thumb { -fx-pref-width: 0; }" +
            ".list-view { -fx-focus-color: transparent; -fx-faint-focus-color: transparent; -fx-background-insets: 0; }" +
            ".list-view:focused { -fx-background-insets: 0; }" +
            ".list-view .list-cell { -fx-background-color: #0f0f0f; }" +
            ".list-view .list-cell:filled:selected { -fx-background-color: #0f0f0f; }" +
            ".list-view .list-cell:filled:hover { -fx-background-color: #0f0f0f; }",
            java.nio.charset.StandardCharsets.UTF_8
        ).replace("+", "%20"));

        final double[] velocity = {0.0};
        final double friction = 0.9;
        final double scrollMultiplier = 1.5;
        
        final Object[] virtualFlowHolder = {null};
        final Method[] scrollMethodHolder = {null};
        final AnimationTimer[] timer = {null};

        listView.addEventFilter(ScrollEvent.SCROLL, event -> {
            if (event.getDeltaY() == 0) return;

            if (virtualFlowHolder[0] == null) {
                virtualFlowHolder[0] = listView.lookup(".virtual-flow");
                if (virtualFlowHolder[0] != null) {
                    try {
                        scrollMethodHolder[0] = virtualFlowHolder[0].getClass()
                            .getMethod("scrollPixels", double.class);
                    } catch (Exception e) {
                        // ignore
                    }
                }
            }

            if (virtualFlowHolder[0] == null || scrollMethodHolder[0] == null) {
                return;
            }

            event.consume();
            velocity[0] += -event.getDeltaY() * scrollMultiplier;

            if (timer[0] == null) {
                timer[0] = new AnimationTimer() {
                    @Override
                    public void handle(long now) {
                        if (Math.abs(velocity[0]) < 0.5) {
                            velocity[0] = 0.0;
                            stop();
                            return;
                        }

                        double step = velocity[0] * 0.15;
                        try {
                            scrollMethodHolder[0].invoke(virtualFlowHolder[0], step);
                        } catch (Exception e) {
                            stop();
                        }
                        velocity[0] *= friction;
                    }
                };
            }
            timer[0].start();
        });

        return listView;
    }


    // ── Helpers ───────────────────────────────────────────────────
    private void triggerAlert(String titleMsg, String headerMsg) {
        Alert alert = new Alert(AlertType.ERROR);

        alert.setTitle(titleMsg);
        alert.setHeaderText(headerMsg);
        alert.setContentText(null); 

        alert.setContentText(""); 

        DialogPane dialogPane = alert.getDialogPane();
        dialogPane.setGraphic(null);

        dialogPane.setStyle("-fx-background-color: #2b2b2b;");

        Node headerPanel = dialogPane.lookup(".header-panel");
        if (headerPanel != null) {
            headerPanel.setStyle("-fx-background-color: #2b2b2b;");
        }

        Node contentRegion = dialogPane.lookup(".content-region");
        if (contentRegion != null) {
            contentRegion.setStyle("-fx-padding: 0; -fx-max-height: 0; -fx-pref-height: 0; -fx-min-height: 0;");
            contentRegion.setVisible(false);
            contentRegion.setManaged(false);
        }

        Platform.runLater(() -> {
            dialogPane.lookupAll(".label").forEach(node -> node.setStyle("-fx-text-fill: white;"));
            
            Node buttonBar = dialogPane.lookup(".button-bar");
            if (buttonBar != null) {
                buttonBar.setStyle("-fx-background-color: #2b2b2b;");
            }

            Button okButton = (Button) dialogPane.lookupButton(ButtonType.OK);
            if (okButton != null) {
                String baseStyle = 
                    "-fx-background-color: #b32424; " + 
                    "-fx-text-fill: white; " +
                    "-fx-border-color: #d32f2f; " +
                    "-fx-border-radius: 3; " +
                    "-fx-background-radius: 3; " +
                    "-fx-font-weight: bold;";
                    
                String hoverStyle = 
                    "-fx-background-color: #d32f2f; " + 
                    "-fx-text-fill: white; " + 
                    "-fx-border-color: #ff5252; " + 
                    "-fx-border-radius: 3; " + 
                    "-fx-background-radius: 3; " + 
                    "-fx-font-weight: bold;";

                okButton.setStyle(baseStyle);
                
                okButton.setOnMouseEntered(e -> okButton.setStyle(hoverStyle));
                okButton.setOnMouseExited(e -> okButton.setStyle(baseStyle));
            }
        });

        alert.showAndWait();
    }

    private void updateShuffleButtonStyle(boolean isSelected) {
        if (isSelected) {
            shuffleImg = new Image(new File("./resources/shuffle_selected.png").toURI().toString());
        } else {
            shuffleImg = new Image(new File("./resources/shuffle_unselected.png").toURI().toString());
        }
        ImageView graphic = new ImageView(shuffleImg);
        graphic.setFitWidth(32);
        graphic.setFitHeight(32);
        graphic.setPreserveRatio(true);
        shuffleBtn.setGraphic(graphic);
    }

    private void updateRlsButtonStyle(boolean isSelected) {
        if (isSelected) {
            rlsImg = new Image(new File("./resources/library_selected.png").toURI().toString());
        } else {
            rlsImg = new Image(new File("./resources/library_unselected.png").toURI().toString());
        }
        ImageView graphic = new ImageView(rlsImg);
        graphic.setFitWidth(32);
        graphic.setFitHeight(32);
        graphic.setPreserveRatio(true);
        rlsBtn.setGraphic(graphic);
    }

    public static String getPlaylistDuration(List<String> durations) {
        if (durations == null || durations.isEmpty()) return "00:00:00";
        long totalSeconds = 0;
        for (String duration : durations) {
            String[] parts = duration.split(":");
            if (parts.length == 3) {
                totalSeconds += Long.parseLong(parts[0]) * 3600
                             + Long.parseLong(parts[1]) * 60
                             + Long.parseLong(parts[2]);
            } else if (parts.length == 2) {
                totalSeconds += Long.parseLong(parts[0]) * 60
                             + Long.parseLong(parts[1]);
            }
        }
        return String.format("%02d:%02d:%02d",
            totalSeconds / 3600,
            (totalSeconds % 3600) / 60,
            totalSeconds % 60);
    }

    private void displayAll() {
        currPlaylist = null;
        VBox mainPanel = buildMainPanel();
        HBox.setHgrow(mainPanel, Priority.ALWAYS);
        rootContent.getChildren().set(1, mainPanel);
        ArrayList<String> durations = rebuildCards();
        String playlist_duration = getPlaylistDuration(durations);
        subtitle.setText(playlist_tracks.size() + " tracks;   Duration: " + playlist_duration);
    }

    private Integer getOrder(AudioPlayer.Track track) {
        for (int i = 0; i < playlist_tracks.size(); i++) {
            if (playlist_tracks.get(i).trackID == track.trackID) return i + 1;
        }
        return 0;
    }

    private void updateOrder(Integer playlist_id) {
        for (int i = 0; i < playlist_tracks.size(); i++) {
            mediaHandler.changeTrackOrder(playlist_id, playlist_tracks.get(i).trackID, i + 1);
        }
    }

    public void refresh() {
        rebuildCards();
    }

    public void autoScroll(String mode) {
        if (mode.equals("up")) {
            scrollByCard(track_list, false);
        }
        else if (mode.equals("down")) {
            scrollByCard(track_list, true);
        }
        else {
            System.out.println("Invalid mode. ");
        }
    }

    private void scrollByCard(ListView<AudioPlayer.Track> listView, boolean scrollDown) {
        if (activeScrollTimer != null) return;

        final double CARD_HEIGHT = listView.getFixedCellSize();

        Node virtualFlow = listView.lookup(".virtual-flow");
        if (virtualFlow == null) return;

        try {
            Method scrollMethod = virtualFlow.getClass().getMethod("scrollPixels", double.class);

            final double[] remaining = { scrollDown ? CARD_HEIGHT : -CARD_HEIGHT };
            final double STEP = CARD_HEIGHT / 12.0;
            final double[] lastY = { -1 };

            activeScrollTimer = new AnimationTimer() {
                @Override
                public void handle(long now) {
                    ScrollBar scrollBar = (ScrollBar) listView.lookup(".scroll-bar:vertical");
                    if (scrollBar != null) {
                        double currentVal = scrollBar.getValue();
                        if (lastY[0] != -1 && currentVal == lastY[0] && Math.abs(remaining[0]) > STEP) {
                            stop();
                            activeScrollTimer = null;
                            return;
                        }
                        lastY[0] = currentVal;
                    }

                    double step = Math.copySign(Math.min(Math.abs(remaining[0]), STEP), remaining[0]);
                    try {
                        scrollMethod.invoke(virtualFlow, step);
                    } catch (Exception e) {
                        stop();
                        activeScrollTimer = null;
                        return;
                    }
                    remaining[0] -= step;
                    if (Math.abs(remaining[0]) < 0.5) {
                        stop();
                        activeScrollTimer = null;
                    }
                }
            };
            activeScrollTimer.start();

        } catch (NoSuchMethodException e) {
            listView.lookupAll(".list-cell").stream()
                .filter(n -> n instanceof ListCell<?> cell && !cell.isEmpty())
                .map(n -> (ListCell<?>) n)
                .mapToInt(ListCell::getIndex)
                .min()
                .ifPresent(firstVisible ->
                    listView.scrollTo(scrollDown ? firstVisible + 1 : Math.max(0, firstVisible - 1))
                );
        }
    }

    private void refreshTrackList(AudioPlayer.Playlist playlist) {
        VBox mainPanel = buildMainPanel();
        HBox.setHgrow(mainPanel, Priority.ALWAYS);
        rootContent.getChildren().set(1, mainPanel);
        playlist_tracks = mediaHandler.loadPlaylistTracks(playlist.playlistID);
        panelTitle.setText(playlist.title);
        ArrayList<String> durations = rebuildCards();
        subtitle.setText(playlist_tracks.size() + " tracks  |  Duration: " + getPlaylistDuration(durations));
    }

    private ArrayList<String> rebuildCards() {
        track_list.getItems().setAll(playlist_tracks);
        track_list.refresh();
        ArrayList<String> durations = new ArrayList<>();
        for (AudioPlayer.Track track : playlist_tracks) durations.add(track.duration);
        return durations;
    }

    private void refreshSidebarList() {
        playlists = mediaHandler.loadPlaylists();
        itemList.getChildren().clear();

        for (AudioPlayer.Playlist playlist : playlists) {
            Label item = new Label(playlist.title);
            item.setMaxWidth(Double.MAX_VALUE);
            item.setPadding(new Insets(10, 14, 10, 14));
            item.setStyle(
                "-fx-text-fill: #a0a0a0;" +
                "-fx-font-size: 18px;" +
                "-fx-background-color: transparent;" +
                "-fx-background-radius: 7;" +
                "-fx-cursor: hand;"
            );
            item.setOnMouseEntered(e -> item.setStyle(
                "-fx-text-fill: #ffffff;" +
                "-fx-font-size: 18px;" +
                "-fx-background-color: #0f0f0f;" +
                "-fx-background-radius: 7;" +
                "-fx-cursor: hand;"
            ));
            item.setOnMouseExited(e -> {
                boolean selected = item.getUserData() != null && (boolean) item.getUserData();
                if (!selected) item.setStyle(
                    "-fx-text-fill: #a0a0a0;" +
                    "-fx-font-size: 18px;" +
                    "-fx-background-color: transparent;" +
                    "-fx-background-radius: 7;" +
                    "-fx-cursor: hand;"
                );
            });
            item.setOnMouseClicked(e -> {
                refreshSidebarList();
                currPlaylist = playlist;
                itemList.getChildren().forEach(child -> {
                    if (child instanceof Label l) {
                        l.setUserData(false);
                        l.setStyle(
                            "-fx-text-fill: #a0a0a0;" +
                            "-fx-font-size: 18px;" +
                            "-fx-background-color: transparent;" +
                            "-fx-background-radius: 7;" +
                            "-fx-cursor: hand;"
                        );
                    }
                });
                item.setUserData(true);
                item.setStyle(
                    "-fx-text-fill: #ffffff;" +
                    "-fx-font-size: 18px;" +
                    "-fx-background-color: #2a2a2a;" +
                    "-fx-background-radius: 7;" +
                    "-fx-cursor: hand;"
                );
                refreshTrackList(playlist);
            });

            itemList.getChildren().add(item);
        }
    }


    // ── Track Cards ───────────────────────────────────────────────
    private HBox buildCard(AudioPlayer.Track track) {
        Label nameLabel = new Label(track.title);
        nameLabel.setStyle(
            "-fx-text-fill: #e8e8e8;" +
            "-fx-font-size: 17px;"
        );
        nameLabel.setMaxWidth(275);
        nameLabel.setTextOverrun(OverrunStyle.ELLIPSIS);

        Label artistLabel = new Label(track.artist);
        artistLabel.setStyle(
            "-fx-text-fill: #555555;" +
            "-fx-font-size: 15px;"
        );

        Label contribLabel = new Label("Uploaded by:  " + track.contributor);
        contribLabel.setStyle(
            "-fx-text-fill: #ffffff;" +
            "-fx-font-size: 15px;"
        );

        VBox textBlock = new VBox(3, nameLabel, artistLabel);
        HBox.setHgrow(textBlock, Priority.ALWAYS);

        Label durationLabel = new Label(track.duration);
        durationLabel.setStyle(
            "-fx-text-fill: #e8e8e8;" +
            "-fx-font-size: 15px;"
        );

        Region spacer = new Region();
        HBox.setHgrow(spacer, Priority.ALWAYS);

        Region space = new Region();
        space.setPrefSize(20, 10);

        // Playlist Popup
        Popup playlistPopup = new Popup();
        playlistPopup.setAutoHide(true);

        playlistPopup.setOnShown(e -> {
            if (scene != null) {
                scene.addEventFilter(MouseEvent.MOUSE_PRESSED, new EventHandler<MouseEvent>() {
                    @Override
                    public void handle(MouseEvent event) {
                        playlistPopup.hide();
                        scene.removeEventFilter(MouseEvent.MOUSE_PRESSED, this);
                    }
                });
            }
        });

        VBox playlistContainer = new VBox();
        playlistContainer.setSpacing(5);
        playlistContainer.setStyle(
            "-fx-background-color: #2b2b2b;" +
            "-fx-padding: 10px;" +
            "-fx-background-radius: 5px;"
        );

        for (AudioPlayer.Playlist playlist : playlists) {
            HBox row = new HBox(8);
            row.setAlignment(Pos.CENTER_LEFT);
            row.setStyle(
                "-fx-background-color: #3c3f41;" +
                "-fx-padding: 8px 15px;" +
                "-fx-background-radius: 3px;"
            );

            Region rowSpacer = new Region();
            HBox.setHgrow(rowSpacer, Priority.ALWAYS);

            Button dotBtn = new Button();
            dotBtn.setPrefSize(13, 13);
            dotBtn.setMinSize(13, 13);
            dotBtn.setMaxSize(13, 13);

            boolean selected = mediaHandler.isInPlaylist(playlist.playlistID, track.trackID);
            dotBtn.setUserData(selected);
            dotBtn.setStyle(selected
                ? "-fx-background-color: #FF0000; -fx-background-radius: 50%; -fx-cursor: hand;"
                : "-fx-background-color: #7f8c8d; -fx-background-radius: 50%; -fx-cursor: hand;"
            );

            dotBtn.setOnAction(e -> {
                boolean isSelected = (boolean) dotBtn.getUserData();
                boolean newState = !isSelected;
                dotBtn.setUserData(newState);
                if (newState) {
                    mediaHandler.addToPlaylist(playlist.playlistID, track.trackID);
                    dotBtn.setStyle("-fx-background-color: #FF0000; -fx-background-radius: 50%; -fx-cursor: hand;");
                } else {
                    mediaHandler.removeFromPlaylist(playlist.playlistID, track.trackID);
                    if (currPlaylist != null) refreshTrackList(currPlaylist);
                    updateOrder(playlist.playlistID);
                    dotBtn.setStyle("-fx-background-color: #7f8c8d; -fx-background-radius: 50%; -fx-cursor: hand;");
                }
            });

            Label playlistItem = new Label(playlist.title);
            playlistItem.setStyle("-fx-text-fill: white;");
            row.getChildren().addAll(playlistItem, rowSpacer, dotBtn);
            playlistContainer.getChildren().add(row);
        }

        // Remove Download Button
        Button removeBtn = new Button("Remove Download");
        removeBtn.setStyle("""
            -fx-background-color: transparent;
            -fx-background-radius: 50%;
            -fx-min-width: 20px;
            -fx-min-height: 20px;
            -fx-cursor: hand;
            -fx-text-fill: #ff0000;
        """);
        removeBtn.setOnAction(e -> {
            if (serverClient.ping() == true) {
                serverClient.removeDownload(track);
                playlist_tracks.removeIf(item -> item.trackID == track.trackID);
                refresh();
            }
            else {
                triggerAlert("Server Error", "Server Offline");
            }
        });

        ScrollPane scrollPane = new ScrollPane(playlistContainer);
        scrollPane.setFitToWidth(true);
        scrollPane.setPrefViewportHeight(150);
        scrollPane.setPrefWidth(250);
        scrollPane.setHbarPolicy(ScrollPane.ScrollBarPolicy.NEVER);
        scrollPane.setVbarPolicy(ScrollPane.ScrollBarPolicy.NEVER);
        scrollPane.setStyle(
            "-fx-background: transparent;" +
            "-fx-background-color: transparent;" +
            "-fx-padding: 0;" +
            "-fx-border-width: 0;"
        );

        VBox popupActions = new VBox(12, scrollPane, removeBtn);
        popupActions.setStyle(
            "-fx-background-color: #2b2b2b;" +
            "-fx-padding: 10px;" +
            "-fx-background-radius: 5px;"
        );
        playlistPopup.getContent().add(popupActions);

        // Play Button
        Button playButton = new Button();
        Image playButtonImg = new Image(new File("./resources/play.png").toURI().toString());
        ImageView playButtonGraphic = new ImageView(playButtonImg);
        playButtonGraphic.setFitWidth(12);
        playButtonGraphic.setFitHeight(12);
        playButtonGraphic.setPreserveRatio(true);
        playButton.setGraphic(playButtonGraphic);
        playButton.setStyle("-fx-background-color: transparent; -fx-cursor: hand;");
        playButton.setOnAction(e -> {
            audioPlayer.clearPlaylistQueue();
            int init_idx = audioPlayer.isShuffled() ? 0 : getOrder(track);
            for (int i = init_idx; i < playlist_tracks.size(); i++) {
                audioPlayer.addToPlaylistQueue(playlist_tracks.get(i));
            }
            audioPlayer.play(track);
        });

        // Thumbnail Track Image
        ImageView thumbCover = new ImageView();
        thumbCover.setFitWidth(40);
        thumbCover.setFitHeight(40);
        thumbCover.setPreserveRatio(true);
        File coverFile = new File(assetsUrl + "/cover/" + track.trackID + ".jpg");
        if (!coverFile.exists()) {
            coverFile = new File("./resources/default.jpg");
        }
        Image thumbImage = new Image(coverFile.toURI().toString());
        thumbCover.setImage(thumbImage);

        // Queue Button
        Button addToQueueBtn = new Button();
        Image queueImg = new Image(new File("./resources/add_to_queue.png").toURI().toString());
        Image queueImgHover = new Image(new File("./resources/add_to_queue_hover.png").toURI().toString());
        ImageView queueGraphic = new ImageView(queueImg);
        queueGraphic.setFitWidth(16);
        queueGraphic.setFitHeight(16);
        queueGraphic.setPreserveRatio(true);
        addToQueueBtn.setGraphic(queueGraphic);
        addToQueueBtn.setStyle("-fx-background-color: transparent; -fx-cursor: hand;");
        addToQueueBtn.setOnMouseEntered(e -> queueGraphic.setImage(queueImgHover));
        addToQueueBtn.setOnMouseExited(e -> queueGraphic.setImage(queueImg));
        addToQueueBtn.setOnAction(e -> audioPlayer.addToQueue(track));

        // Playlist Button
        Button addToPlaylistBtn = new Button();
        Image playlistImg = new Image(new File("./resources/add_to_playlist.png").toURI().toString());
        Image playlistImgHover = new Image(new File("./resources/add_to_playlist_hover.png").toURI().toString());
        ImageView playlistGraphic = new ImageView(playlistImg);
        playlistGraphic.setFitWidth(16);
        playlistGraphic.setFitHeight(16);
        playlistGraphic.setPreserveRatio(true);
        addToPlaylistBtn.setGraphic(playlistGraphic);
        addToPlaylistBtn.setStyle("-fx-background-color: transparent; -fx-cursor: hand;");
        addToPlaylistBtn.setOnMouseEntered(e -> playlistGraphic.setImage(playlistImgHover));
        addToPlaylistBtn.setOnMouseExited(e -> playlistGraphic.setImage(playlistImg));
        addToPlaylistBtn.setOnAction(e -> {
            if (!playlistPopup.isShowing()) {
                if (!playlists.isEmpty()) {
                    double x = addToPlaylistBtn.localToScreen(addToPlaylistBtn.getBoundsInLocal()).getMinX();
                    double y = addToPlaylistBtn.localToScreen(addToPlaylistBtn.getBoundsInLocal()).getMaxY();
                    playlistPopup.show(addToPlaylistBtn, x, y);
                }
            } else {
                playlistPopup.hide();
            }
        });

        // Download Button
        Button downloadBtn = new Button();
        Image downloadImg = new Image(new File("./resources/download.png").toURI().toString());
        ImageView downloadGraphic = new ImageView(downloadImg);
        downloadGraphic.setFitWidth(22);
        downloadGraphic.setFitHeight(22);
        downloadGraphic.setPreserveRatio(true);
        downloadBtn.setGraphic(downloadGraphic);
        downloadBtn.setStyle("-fx-background-color: transparent; -fx-cursor: hand; -fx-padding: 3;"); 
        downloadBtn.setOnAction(e -> {
            downloadBtn.setDisable(true);
            serverClient.downloadTrack(track);
            track.downloaded = true;
            downloadBtn.setDisable(false);
            refresh();
        });

        final HBox card;
        if (track.downloaded == true) {
            if (audioPlayer.isPlaying() && audioPlayer.trackPlaying(track)) {
                card = new HBox(12, playButton, thumbCover, textBlock, buildPlayBars(), spacer, addToQueueBtn, addToPlaylistBtn, space, durationLabel);
            } else {
                card = new HBox(12, playButton, thumbCover, textBlock, spacer, addToQueueBtn, addToPlaylistBtn, space, durationLabel);
            }
        }
        else {
            card = new HBox(12, downloadBtn, thumbCover, textBlock, spacer, contribLabel);
        }

        card.setAlignment(Pos.CENTER_LEFT);
        card.setPadding(new Insets(14, 18, 14, 18));
        card.setStyle(
            "-fx-background-color: transparent;" +
            "-fx-border-color: #1a1a1a;" +
            "-fx-background-radius: 15;" +
            "-fx-border-radius: 15;" +
            "-fx-border-width: 2;" +
            "-fx-cursor: hand;"
        );

        final Popup[] activePopup = {null};

        card.setOnMouseEntered(e -> {
            card.setStyle(
                "-fx-background-color: #0f0f0f;" +
                "-fx-border-color: #1a1a1a;" +
                "-fx-background-radius: 15;" +
                "-fx-border-radius: 15;" +
                "-fx-border-width: 2;" +
                "-fx-cursor: hand;"
            );
            double x = e.getScreenX();
            double y = e.getScreenY();
            hoverTask = scheduler.schedule(() -> Platform.runLater(() -> {
                if (card.getScene() == null) return;
                Popup popup = new Popup();
                Label popupLabel = new Label(track.title);
                popupLabel.setStyle(
                    "-fx-background-color: #333;" +
                    "-fx-text-fill: white;" +
                    "-fx-padding: 6px 10px;" +
                    "-fx-background-radius: 6px;"
                );
                popup.getContent().add(popupLabel);
                popup.show(card.getScene().getWindow(), x, y - 30);
                activePopup[0] = popup;
            }), 2, TimeUnit.SECONDS);
        });

        card.setOnMouseExited(e -> {
            card.setStyle(
                "-fx-background-color: transparent;" +
                "-fx-border-color: #1a1a1a;" +
                "-fx-background-radius: 15;" +
                "-fx-border-radius: 15;" +
                "-fx-border-width: 2;" +
                "-fx-cursor: hand;"
            );
            if (hoverTask != null && !hoverTask.isDone()) hoverTask.cancel(false);
            if (activePopup[0] != null) Platform.runLater(() -> {
                activePopup[0].hide();
                activePopup[0] = null;
            });
        });

        return card;
    }


    private HBox buildPlayBars() {
        HBox bars = new HBox(3);
        bars.setAlignment(Pos.BOTTOM_CENTER);

        int numBars = 15;
        Random random = new Random();

        for (int i = 0; i < numBars; i++) {
            Rectangle bar = new Rectangle(4, 4);
            bar.setFill(Color.web("#ff0000"));
            bar.setArcWidth(2);
            bar.setArcHeight(2);

            Timeline tl = new Timeline();
            tl.setCycleCount(Animation.INDEFINITE);
            final Rectangle b = bar;
            tl.getKeyFrames().add(new KeyFrame(Duration.millis(300 + random.nextInt(300)), e -> {
                double newHeight = 4 + random.nextDouble() * 14;
                Timeline hop = new Timeline(
                    new KeyFrame(Duration.ZERO,
                        new KeyValue(b.heightProperty(), b.getHeight(), Interpolator.EASE_BOTH)),
                    new KeyFrame(Duration.millis(200 + random.nextInt(200)),
                        new KeyValue(b.heightProperty(), newHeight, Interpolator.EASE_BOTH))
                );
                hop.play();
            }));
            tl.setDelay(Duration.millis(i * 40));
            tl.play();
            bars.getChildren().add(bar);
        }

        return bars;
    }

    // RLS Registration Modal
    private void openRegisterModal(Stage owner, StackPane rootPane) {
        AtomicBoolean dismissable = new AtomicBoolean(true);

        Rectangle overlay = new Rectangle();
        overlay.widthProperty().bind(rootPane.widthProperty());
        overlay.heightProperty().bind(rootPane.heightProperty());
        overlay.setFill(Color.rgb(0, 0, 0, 0.65));
        overlay.setMouseTransparent(false);
        rootContent.setEffect(new GaussianBlur(4));

        Label title = new Label("Register a user with the RLS: ");
        title.setStyle(
            "-fx-font-size: 16px;" +
            "-fx-font-weight: bold;" +
            "-fx-text-fill: #ffffff;"
        );

        TextField urlField = new TextField();
        urlField.setPromptText("Enter server url...");
        urlField.setPrefWidth(260);
        urlField.setPrefHeight(38);
        urlField.setStyle(
            "-fx-background-color: #1e1e1e;" +
            "-fx-text-fill: #ffffff;" +
            "-fx-prompt-text-fill: #555555;" +
            "-fx-border-color: #2a2a2a;" +
            "-fx-border-radius: 6;" +
            "-fx-background-radius: 6;" +
            "-fx-border-width: 1.5;" +
            "-fx-font-size: 14px;" +
            "-fx-padding: 0 12;"
        );

        TextField authField = new TextField();
        authField.setPromptText("Enter server access token...");
        authField.setPrefWidth(260);
        authField.setPrefHeight(38);
        authField.setStyle(
            "-fx-background-color: #1e1e1e;" +
            "-fx-text-fill: #ffffff;" +
            "-fx-prompt-text-fill: #555555;" +
            "-fx-border-color: #2a2a2a;" +
            "-fx-border-radius: 6;" +
            "-fx-background-radius: 6;" +
            "-fx-border-width: 1.5;" +
            "-fx-font-size: 14px;" +
            "-fx-padding: 0 12;"
        );

        TextField inputField = new TextField();
        inputField.setPromptText("Enter a username...");
        inputField.setPrefWidth(260);
        inputField.setPrefHeight(38);
        inputField.setStyle(
            "-fx-background-color: #1e1e1e;" +
            "-fx-text-fill: #ffffff;" +
            "-fx-prompt-text-fill: #555555;" +
            "-fx-border-color: #2a2a2a;" +
            "-fx-border-radius: 6;" +
            "-fx-background-radius: 6;" +
            "-fx-border-width: 1.5;" +
            "-fx-font-size: 14px;" +
            "-fx-padding: 0 12;"
        );

        Button submitBtn = new Button("Register");
        submitBtn.setPrefHeight(38);
        submitBtn.setStyle(
            "-fx-background-color: #cc0000;" +
            "-fx-text-fill: white;" +
            "-fx-font-size: 14px;" +
            "-fx-padding: 0 20;" +
            "-fx-background-radius: 6;" +
            "-fx-cursor: hand;"
        );
        submitBtn.setDefaultButton(true);

        VBox inputs = new VBox(10, urlField, authField, inputField);
        HBox inputRow = new HBox(10, inputs, submitBtn);
        inputRow.setAlignment(Pos.CENTER_LEFT);
        HBox.setHgrow(inputField, Priority.ALWAYS);
        inputField.setMaxWidth(Double.MAX_VALUE);

        Label statusLabel = new Label();
        statusLabel.setVisible(false);
        statusLabel.setManaged(false);
        statusLabel.setStyle(
            "-fx-font-size: 12px;" +
            "-fx-text-fill: " + ("#ff4444") + ";"
        );

        VBox card = new VBox(10, title, inputRow, statusLabel);
        card.setAlignment(Pos.CENTER_LEFT);
        card.setPadding(new Insets(24, 28, 24, 28));
        card.setStyle(
            "-fx-background-color: #111111;" +
            "-fx-background-radius: 10;" +
            "-fx-border-color: #2a2a2a;" +
            "-fx-border-radius: 10;" +
            "-fx-border-width: 1;"
        );
        card.setMaxSize(600, 300);
        card.setEffect(null);

        StackPane glass = new StackPane(overlay, card);
        StackPane.setAlignment(card, Pos.CENTER);
        glass.prefWidthProperty().bind(rootPane.widthProperty());
        glass.prefHeightProperty().bind(rootPane.heightProperty());
        glass.setOnKeyPressed(e -> e.consume());
        glass.setMouseTransparent(false);
        rootPane.getChildren().add(glass);

        Runnable handleSubmit = () -> {
            String username = inputField.getText().trim();
            String token = authField.getText().trim();
            String url = urlField.getText().trim();

            if (username.isEmpty() || token.isEmpty() || url.isEmpty()) {
                inputField.setStyle(
                    "-fx-background-color: #1e1e1e;" +
                    "-fx-text-fill: #ffffff;" +
                    "-fx-prompt-text-fill: #555555;" +
                    "-fx-border-color: #cc0000;" +
                    "-fx-border-radius: 6;" +
                    "-fx-background-radius: 6;" +
                    "-fx-border-width: 1.5;" +
                    "-fx-font-size: 14px;" +
                    "-fx-padding: 0 12;"
                );
                return;
            }
            try {
                String message = serverClient.createAndRegister(url, token, username);
                if (message == null) {
                    rootPane.getChildren().remove(glass);
                    rootContent.setEffect(null);
                    serverConnection = true;
                    updateRlsButtonStyle(true);

                }
                else {
                    statusLabel.setText(message);
                    statusLabel.setVisible(true);
                    statusLabel.setManaged(true);
                }
            } catch (Exception e) {
                statusLabel.setText(e.getMessage());
                statusLabel.setVisible(true);
                statusLabel.setManaged(true);
            }
        };

        submitBtn.setOnAction(e -> {
            dismissable.set(false);
            submitBtn.setDisable(true);
            handleSubmit.run();
            submitBtn.setDisable(false);
            dismissable.set(true);
        });

        urlField.requestFocus();
    }

    // Upload Track Modal
    private void openUploadModal(Stage owner, StackPane rootPane) {
        AtomicBoolean dismissable = new AtomicBoolean(true);
        FileChooser fileChooser = new FileChooser();
        fileChooser.setTitle("Select a File");

        Rectangle overlay = new Rectangle();
        overlay.widthProperty().bind(rootPane.widthProperty());
        overlay.heightProperty().bind(rootPane.heightProperty());
        overlay.setFill(Color.rgb(0, 0, 0, 0.65));
        overlay.setMouseTransparent(false);
        rootContent.setEffect(new GaussianBlur(4));

        Label titleLabel = new Label("Upload Track");
        titleLabel.setStyle(
            "-fx-font-size: 16px;" +
            "-fx-font-weight: bold;" +
            "-fx-text-fill: #ffffff;"
        );

        TextField titleField = new TextField();
        titleField.setPromptText("Enter track title...");
        titleField.setPrefWidth(260);
        titleField.setPrefHeight(38);
        titleField.setStyle(
            "-fx-background-color: #1e1e1e;" +
            "-fx-text-fill: #ffffff;" +
            "-fx-prompt-text-fill: #555555;" +
            "-fx-border-color: #2a2a2a;" +
            "-fx-border-radius: 6;" +
            "-fx-background-radius: 6;" +
            "-fx-border-width: 1.5;" +
            "-fx-font-size: 14px;" +
            "-fx-padding: 0 12;"
        );

        TextField artistField = new TextField();
        artistField.setPromptText("Enter track artist...");
        artistField.setPrefWidth(260);
        artistField.setPrefHeight(38);
        artistField.setStyle(
            "-fx-background-color: #1e1e1e;" +
            "-fx-text-fill: #ffffff;" +
            "-fx-prompt-text-fill: #555555;" +
            "-fx-border-color: #2a2a2a;" +
            "-fx-border-radius: 6;" +
            "-fx-background-radius: 6;" +
            "-fx-border-width: 1.5;" +
            "-fx-font-size: 14px;" +
            "-fx-padding: 0 12;"
        );

        Button selectMediaBtn = new Button("Select a media file. ");
        selectMediaBtn.setPrefHeight(38);
        selectMediaBtn.setStyle(
            "-fx-background-color: #808080;" +
            "-fx-text-fill: white;" +
            "-fx-font-size: 14px;" +
            "-fx-padding: 4px 5px;" +
            "-fx-background-radius: 6;" +
            "-fx-cursor: hand;"
        );
        selectMediaBtn.setOnAction(e -> {
            fileChooser.getExtensionFilters().clear();
            FileChooser.ExtensionFilter mediaFilter = new FileChooser.ExtensionFilter("Audio Files", "*.wav", "*.mp3");
            fileChooser.getExtensionFilters().add(mediaFilter);
            File selectedFile = fileChooser.showOpenDialog(owner);
            if (selectedFile != null) {
                audioPath = selectedFile.toPath().toString();
            }
        });

        Button selectCoverBtn = new Button("Select a cover file. ");
        selectCoverBtn.setPrefHeight(38);
        selectCoverBtn.setStyle(
            "-fx-background-color: #808080;" +
            "-fx-text-fill: white;" +
            "-fx-font-size: 14px;" +
            "-fx-padding: 4px 5px;" +
            "-fx-background-radius: 6;" +
            "-fx-cursor: hand;"
        );
        selectCoverBtn.setOnAction(e -> {
            fileChooser.getExtensionFilters().clear();
            FileChooser.ExtensionFilter coverFilter = new FileChooser.ExtensionFilter("Cover", "*.jpg", "*.png");
            fileChooser.getExtensionFilters().add(coverFilter);
            File selectedFile = fileChooser.showOpenDialog(owner);
            if (selectedFile != null) {
                coverPath = selectedFile.toPath().toString();
            }
        });

        HBox selectRow = new HBox(10, selectMediaBtn, selectCoverBtn);

        Button submitBtn = new Button("Upload");
        submitBtn.setPrefHeight(38);
        submitBtn.setStyle(
            "-fx-background-color: #cc0000;" +
            "-fx-text-fill: white;" +
            "-fx-font-size: 14px;" +
            "-fx-padding: 0 20;" +
            "-fx-background-radius: 6;" +
            "-fx-cursor: hand;"
        );
        submitBtn.setDefaultButton(true);

        VBox inputs = new VBox(10, titleField, artistField, selectRow);
        HBox inputRow = new HBox(10, inputs, submitBtn);
        inputRow.setAlignment(Pos.CENTER_LEFT);
        HBox.setHgrow(titleField, Priority.ALWAYS);
        titleField.setMaxWidth(Double.MAX_VALUE);

        Label statusLabel = new Label();
        statusLabel.setVisible(false);
        statusLabel.setManaged(false);
        statusLabel.setStyle(
            "-fx-font-size: 12px;" +
            "-fx-text-fill: " + ("#ff4444") + ";"
        );

        VBox card = new VBox(10, titleLabel, inputRow, statusLabel);
        card.setAlignment(Pos.CENTER_LEFT);
        card.setPadding(new Insets(24, 28, 24, 28));
        card.setStyle(
            "-fx-background-color: #111111;" +
            "-fx-background-radius: 10;" +
            "-fx-border-color: #2a2a2a;" +
            "-fx-border-radius: 10;" +
            "-fx-border-width: 1;"
        );
        card.setMaxSize(600, 300);
        card.setEffect(null);

        StackPane glass = new StackPane(overlay, card);
        StackPane.setAlignment(card, Pos.CENTER);
        glass.prefWidthProperty().bind(rootPane.widthProperty());
        glass.prefHeightProperty().bind(rootPane.heightProperty());
        glass.setOnKeyPressed(e -> e.consume());
        glass.setMouseTransparent(false);
        rootPane.getChildren().add(glass);

        overlay.setOnMouseClicked(event -> {
            if (!dismissable.get()) {
                event.consume();
                return;
            }
            rootPane.getChildren().remove(glass);
            rootContent.setEffect(null);
        });

        Runnable handleSubmit = () -> {
            String title = titleField.getText().trim();
            String artist = artistField.getText().trim();

            if (title.isEmpty() || artist.isEmpty() || coverPath.equals("") || audioPath.equals("")) {
                titleField.setStyle(
                    "-fx-background-color: #1e1e1e;" +
                    "-fx-text-fill: #ffffff;" +
                    "-fx-prompt-text-fill: #555555;" +
                    "-fx-border-color: #cc0000;" +
                    "-fx-border-radius: 6;" +
                    "-fx-background-radius: 6;" +
                    "-fx-border-width: 1.5;" +
                    "-fx-font-size: 14px;" +
                    "-fx-padding: 0 12;"
                );
                return;
            }
            try {
                AudioPlayer.Track newTrack = new AudioPlayer.Track(0, title, artist, "", false, "");
                serverClient.uploadTrack(newTrack, audioPath, coverPath);
                rootPane.getChildren().remove(glass);
                rootContent.setEffect(null);
            } catch (Exception e) {
                statusLabel.setText(e.getMessage());
                statusLabel.setVisible(true);
                statusLabel.setManaged(true);
            }
        };

        submitBtn.setOnAction(e -> {
            dismissable.set(false);
            submitBtn.setDisable(true);
            handleSubmit.run();
            submitBtn.setDisable(false);
            dismissable.set(true);
        });

        titleField.requestFocus();
    }
    
    public static void main(String[] args) {
        launch(args);
    }
}

