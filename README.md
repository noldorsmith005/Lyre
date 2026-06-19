# Napster

To Do:
	-Remaining server features: encrypt any remaining raw
	-Disable empty queries
	-No drag on track search
	-Scroll up/down when song dragged out of bounds
	-Fix search limitations, work around special characters, etc
	-Support for .mp3, .png, .jpeg
	-Compressed asset files -> uncompress on load
	-Optimization: 
		-Use GraalVM native image to compile the package into a binary, reducing memory and improving speed
	-Config/setup scripts
	-Style README

Napster is an application for sharing, downloading, and playing music. It implements all the classic music streaming service features, like playlist customization, queues, and more. Users can create a group server, connect to it, and upload and download music.


Setup Documentation:
	- To configure, clone this repository. The audio and cover files for each track should be in the .wav and .jpg formats respectively, and the filenames should be of the format {track_id}.{file_extension}. Place your database, 'audio' and 'cover' directories in ~/Libarary/Application\ Support/Napster


