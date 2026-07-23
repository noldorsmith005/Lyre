class Track {
  int trackID;
  bool downloaded;
  String title;
  String artist;
  String duration;
  String contributor;

  Track({
    required this.trackID,
    this.downloaded = false,
    required this.title,
    required this.artist,
    required this.duration,
    this.contributor = '',
  });

  Map<String, dynamic> toJson() => {
        'trackID': trackID,
        'downloaded': downloaded,
        'title': title,
        'artist': artist,
        'duration': duration,
        'contributor': contributor,
      };

  factory Track.fromJson(Map<String, dynamic> json) => Track(
        trackID: json['trackID'] as int,
        downloaded: json['downloaded'] as bool? ?? false,
        title: json['title'] as String? ?? '',
        artist: json['artist'] as String? ?? '',
        duration: json['duration'] as String? ?? '',
        contributor: json['contributor'] as String? ?? '',
      );
}
