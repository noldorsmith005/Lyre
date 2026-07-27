import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
import '../screens/settings_screen.dart';
import '../services/theme_service.dart';

class Sidebar extends StatefulWidget {
  final List<Playlist> playlists;
  final Function(Playlist) onPlaylistSelected;
  final VoidCallback onCreatePlaylist;
  final String? selectedPlaylistId;

  const Sidebar({
    Key? key,
    required this.playlists,
    required this.onPlaylistSelected,
    required this.onCreatePlaylist,
    this.selectedPlaylistId,
  }) : super(key: key);

  @override
  _SidebarState createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF000000),
        border: Border(
          right: BorderSide(color: Color(0xFF2A2A2A), width: 1.0),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 20, 20),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFF2A2A2A), width: 1.0),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'Playlists',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _HoverButton(
                  text: '+',
                  defaultColor: Colors.white,
                  hoverColor: const Color(0xFF888888),
                  fontSize: 35,
                  fontWeight: FontWeight.w300,
                  onTap: widget.onCreatePlaylist,
                ),
              ],
            ),
          ),
          
          // Playlist Items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              itemCount: widget.playlists.length,
              itemBuilder: (context, index) {
                final playlist = widget.playlists[index];
                final isSelected = widget.selectedPlaylistId == playlist.playlistID.toString();
                
                return _PlaylistListItem(
                  playlist: playlist,
                  isSelected: isSelected,
                  onTap: () => widget.onPlaylistSelected(playlist),
                );
              },
            ),
          ),

          // Settings Section
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xFF2A2A2A), width: 1.0),
              ),
            ),
            child: ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              leading: const Icon(Icons.settings, color: Colors.white70),
              title: const Text('Settings', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HoverButton extends StatefulWidget {
  final String text;
  final Color defaultColor;
  final Color hoverColor;
  final double fontSize;
  final FontWeight fontWeight;
  final VoidCallback onTap;

  const _HoverButton({
    required this.text,
    required this.defaultColor,
    required this.hoverColor,
    required this.fontSize,
    required this.fontWeight,
    required this.onTap,
  });

  @override
  __HoverButtonState createState() => __HoverButtonState();
}

class __HoverButtonState extends State<_HoverButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Text(
          widget.text,
          style: TextStyle(
            color: _isHovered ? widget.hoverColor : widget.defaultColor,
            fontSize: widget.fontSize,
            fontWeight: widget.fontWeight,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}

class _PlaylistListItem extends StatefulWidget {
  final Playlist playlist;
  final bool isSelected;
  final VoidCallback onTap;

  const _PlaylistListItem({
    required this.playlist,
    required this.isSelected,
    required this.onTap,
  });

  @override
  __PlaylistListItemState createState() => __PlaylistListItemState();
}

class __PlaylistListItemState extends State<_PlaylistListItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final themeColor = context.watch<ThemeService>().themeColor;

    final bgColor = widget.isSelected
        ? themeColor.withOpacity(0.18)
        : (_isHovered ? const Color(0xFF0F0F0F) : Colors.transparent);
        
    final textColor = widget.isSelected
        ? Colors.white
        : (_isHovered ? const Color(0xFFFFFFFF) : const Color(0xFFA0A0A0));

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(7),
            border: widget.isSelected
                ? Border(left: BorderSide(color: themeColor, width: 3.5))
                : null,
          ),
          child: Text(
            widget.playlist.title,
            style: TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: widget.isSelected ? FontWeight.bold : FontWeight.normal,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
