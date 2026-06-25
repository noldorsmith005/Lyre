# Napster


Napster is an application for sharing, downloading, and playing music. It implements all the classic music streaming service features, like playlist customization, queues, and more. Users can create a group server, connect to it, and upload and download music.


Setup Documentation:
	- To configure, clone this repository. The audio and cover files for each track should be in the .wav and .jpg formats respectively, and the filenames should be of the format {track_id}.{file_extension}. Place your database, 'audio' and 'cover' directories in ~/Libarary/Application\ Support/Napster


Packaging:
	- In the project root, make directories input, packaging, and dist. In ./input, place Napster.jar, your sqlite, gson, and flac jars, client.config, and the resources directory. In ./packaging, place your icon.icns file. Modify the jpackage command in ./setup as needed for your OS, and then copy and run the command from the project root. 

