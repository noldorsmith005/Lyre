# Napster

To Do:
	-Compressed asset files -> uncompress on load
	-Scroll up/down when song dragged out of bounds
	~Online Mode:
		-Server:
			-SQLite Database
			-Audio stream, search, download requests via Https
			-App-end API client for remote server, modes for online and offline
			-Upload page for adding tracks
	-Optimization: 
		-Use GraalVM native image to compile the package into a binary, reducing memory and improving speed

Napster is an application for sharing, downloading, and playing music. It implements all the classic music streaming service features, like playlist customization, queues, and more. Users can create a group server, connect to it, and upload and download music to and from it.


Setup Documentation:
	- To configure, clone this repository. The audio and cover files for each track should be in the .wav and .jpg formats respectively, and the filenames should be of the format {track_id}.{file_extension}. Place your database, 'audio' and 'cover' directories in ~/Libarary/Application\ Support/Napster

	Database format:
	Database : data.db
	Tables   : PlaylistIDs, Playlists, Tracks, playlist_{playlist_id}

	============================================================
	  TABLE: PlaylistIDs   [1 row(s)]  PK: playlist_id
	============================================================
	+-------------+
	| playlist_id |
	| (INTEGER)   |
	+-------------+
	|			  |
	+-------------+

	============================================================
	  TABLE: Playlists   [1 row(s)]  PK: playlist_id
	============================================================
	+-------------+------------------+
	| playlist_id | title            |
	| (INTEGER)   | (TEXT)           |
	+-------------+------------------+
	|			  |  			     |
	+-------------+------------------+

	============================================================
	  TABLE: Tracks   [0 row(s)]  PK: track_id
	============================================================
	+-----------+------------------------------------+----------------+----------+
	| track_id  | title                              | artist         | duration |
	| (INTEGER) | (TEXT)                             | (TEXT)         | (TEXT)   |
	+-----------+------------------------------------+----------------+----------+
	|																			 |
	+-----------+------------------------------------+----------------+----------+

	============================================================
	  TABLE: playlist_{playlist_id}   [0 row(s)]
	============================================================
	+-----------+-----------+
	| order     | track_id  |
	| (INTEGER) | (INTEGER) |
	+-----------+-----------+
	|                       |
	+-----------+-----------+
