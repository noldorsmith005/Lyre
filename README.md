# Napster


Napster is an application for sharing, downloading, and playing music. It implements all the classic music streaming service features, like playlist customization, queues, and more. Users can create a group server, connect to it, and upload and download music.


Setup Documentation:
	- To configure, clone this repository. The audio and cover files for each track should be in the .wav and .jpg formats respectively, and the filenames should be of the format {track_id}.{file_extension}. Place your database, 'audio' and 'cover' directories in ~/Libarary/Application\ Support/Napster


Packaging:
	- In the project root, make directories input, packaging, and dist. In ./input, place Napster.jar, your sqlite, gson, and flac jars, client.config, and the resources directory. In ./packaging, place your icon.icns file. Modify the jpackage command in ./setup as needed for your OS, and then copy and run the command from the project root. 


To Do:
	-Song tags in server-side database for searching
	-Migration: server-side downloads pivot table mapping song_id -> user_id for each download (removed/added as needed). 
	-Migration: playlists table with fields user_id, name, track_ids
	-Playlist+Song sync: Computer -> user can upload/update their playlists to the server, stored as rows in the playlists table. Mobile -> user can pull sync the uploaded playlists to their device. 1. sync tracks (compare local tracks to downloads pivot table and remove/download as needed) 2. sync playlists (rearrange songs, create/delete/modify playlists as needed). 
