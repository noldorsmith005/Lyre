package Napster;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.List;
import java.util.ArrayList;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.sql.Statement;
import javafx.application.Application;
import javafx.stage.Stage;



public class MediaHandler {
	private String databaseUrl;
	private String assetsUrl;

	// private void log(String message) {
	//     try (java.io.FileWriter fw = new java.io.FileWriter("/tmp/Napster-debug.log", true)) {
	//         fw.write(new java.util.Date() + ": " + message + "\n");
	//     } catch (java.io.IOException e) {
	//         // silently fail
	//     }
	// }

	public MediaHandler() {
		databaseUrl = "jdbc:sqlite:" + App.appData.toString() + "/data.db";
		assetsUrl = App.appData.toString() + "/";

		try {
            Path basePath = Paths.get(assetsUrl);
            Path audioDir = basePath.resolve("audio");
            Path coverDir = basePath.resolve("cover");

            if (Files.notExists(basePath) || !Files.isDirectory(basePath)) {
                Files.createDirectories(audioDir);
            	Files.createDirectories(coverDir);
            	createDatabase();
            }
            
        } catch (IOException | SecurityException e) {
            System.err.println("CRITICAL: Failed to initialize storage structure: " + e.getMessage());
        }
	}


	// Init methods
  	private void createDatabase() {
        try (Connection conn = DriverManager.getConnection(databaseUrl);
             Statement stmt = conn.createStatement()) {

            stmt.execute("""
                CREATE TABLE IF NOT EXISTS PlaylistIDs (
                    playlist_id INTEGER PRIMARY KEY
                )
            """);

            stmt.execute("""
                CREATE TABLE IF NOT EXISTS Playlists (
                    playlist_id INTEGER PRIMARY KEY,
                    title       TEXT
                )
            """);

            stmt.execute("""
                CREATE TABLE IF NOT EXISTS Tracks (
                    track_id   INTEGER PRIMARY KEY,
                    title      TEXT,
                    artist     TEXT,
                    duration   TEXT
                )
            """);

        } catch (SQLException e) {
            System.err.println("Failed to create database: " + e.getMessage());
            throw new RuntimeException(e);
        }
    }

    // Database methods
	public ArrayList<AudioPlayer.Track> searchTracks(String filter) {
		ArrayList<AudioPlayer.Track> tracks = new ArrayList<>();

	    String normalizedFilter = filter.replaceAll("[^a-zA-Z]", "").toLowerCase();

	    if (normalizedFilter.isEmpty()) {
	        return tracks;
	    }

	    String sql = "SELECT * FROM Tracks WHERE NORMALIZE(title) LIKE ? OR NORMALIZE(artist) LIKE ? ORDER BY title ASC";

	    try (java.sql.Connection conn = java.sql.DriverManager.getConnection(databaseUrl)) {
	        org.sqlite.Function.create(conn, "NORMALIZE", new org.sqlite.Function() {
			    @Override
			    protected void xFunc() throws org.sqlite.SQLiteException {
			        try {
			            String value = value_text(0);
			            if (value == null) {
			                result((String) null);
			            } else {
			                result(value.replaceAll("[^a-zA-Z]", "").toLowerCase());
			            }
			        } catch (java.sql.SQLException e) {
			            throw new org.sqlite.SQLiteException("NORMALIZE error: " + e.getMessage(), 
			                org.sqlite.SQLiteErrorCode.SQLITE_ERROR);
			        }
			    }
			});

	        try (java.sql.PreparedStatement pstmt = conn.prepareStatement(sql)) {
	            pstmt.setString(1, "%" + normalizedFilter + "%");
	            pstmt.setString(2, "%" + normalizedFilter + "%");

	            try (java.sql.ResultSet rs = pstmt.executeQuery()) {
	                while (rs.next()) {
	                    tracks.add(new AudioPlayer.Track(
	                        rs.getInt("track_id"),
	                        rs.getString("title"),
	                        rs.getString("artist"),
	                        rs.getString("duration"),
	                        true,
	                        ""
	                    ));
	                }
	            }
	        }
	    } catch (java.sql.SQLException e) {
	        System.err.println("Could not load tracks: " + e.getMessage());
	    }
	    return tracks;
	}


    public ArrayList<AudioPlayer.Playlist> loadPlaylists() {
    	String sql = "SELECT * FROM Playlists";
		ArrayList<AudioPlayer.Playlist> tracks = new ArrayList<>();

		try (java.sql.Connection conn = java.sql.DriverManager.getConnection(databaseUrl);
		     java.sql.Statement  stmt = conn.createStatement();
		     java.sql.ResultSet  rs   = stmt.executeQuery(sql)) {

		    while (rs.next()) {
			tracks.add(new AudioPlayer.Playlist(
			    rs.getInt("playlist_id"),
			    rs.getString("title")
			));
		    }

		} catch (java.sql.SQLException e) {
		    System.err.println("Could not load playlists: " + e.getMessage());
		}

		return tracks;
    }
    
	public ArrayList<AudioPlayer.Track> loadPlaylistTracks(Integer playlistID) {
		List<Integer> ids = new ArrayList<>();
	    String tableName = "playlist_" + playlistID;
	    String getTrackIDs = "SELECT * FROM " + tableName + " ORDER BY [order] ASC";
	    ArrayList<AudioPlayer.Track> tracks = new ArrayList<>();
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
	                tracks.add(new AudioPlayer.Track(
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

	public void newTrack(AudioPlayer.Track track) {
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

	public void deleteTrack(AudioPlayer.Track track) {
		String sql_get = "SELECT playlist_id FROM Playlists";
		String sql = "DELETE FROM Tracks WHERE track_id=?";
		List<Integer> playlist_ids = new ArrayList<>();

		try (java.sql.Connection conn = java.sql.DriverManager.getConnection(databaseUrl);
		     java.sql.PreparedStatement pstmt = conn.prepareStatement(sql_get);
		     java.sql.ResultSet rs = pstmt.executeQuery()) {

		    while (rs.next()) {
		        playlist_ids.add(rs.getInt("playlist_id"));
		    }

		} catch (java.sql.SQLException e) {
		    System.err.println("Could not retrieve playlist ids: " + e.getMessage());
		}

		for (Integer id : playlist_ids) {
		    removeFromPlaylist(id, track.trackID);
		}

	    try (java.sql.Connection conn = java.sql.DriverManager.getConnection(databaseUrl);
	        java.sql.PreparedStatement pstmt = conn.prepareStatement(sql)) {
	        pstmt.setInt(1, track.trackID);
	        pstmt.executeUpdate();

	    } catch (java.sql.SQLException e) {
	        System.err.println("Could not delete track: " + e.getMessage());
	    }
	}

}

