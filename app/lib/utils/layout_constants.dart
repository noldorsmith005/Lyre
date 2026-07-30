import 'dart:io' show Platform;

class LayoutConstants {
  // Desktop panel ratios
  static double get sidebarRatio => Platform.isWindows ? 0.14 : 0.18;
  static double get mediaPanelRatio => Platform.isWindows ? 0.26875 : 0.25;

  // Track list cells
  static double get cellSize => Platform.isWindows ? 64 : 68;
  static double get cellSpacing => Platform.isWindows ? 4.5 : 4.0;
  static double get trackCardTextSize => Platform.isWindows ? 200.0 : 275.0;

  // Font sizes
  static double get titleFontSize => Platform.isWindows ? 14 : 17;
  static double get subFontSize => Platform.isWindows ? 12 : 15;

  // Thumbnails
  static double get thumbSize => Platform.isWindows ? 48 : 56;

  // Padding
  static double get paddingV => Platform.isWindows ? 4 : 6;
  static double get paddingH => Platform.isWindows ? 14 : 18;

  // Cover art
  static double get coverSize => Platform.isWindows ? 300 : 400;

  // Queue card sizes
  static double get cardTextSize => Platform.isWindows ? 220.0 : 200.0;
  static double get queueTitleFontSize => Platform.isWindows ? 15 : 17;
  static double get queueArtistFontSize => Platform.isWindows ? 12 : 13;
  static double get queueDurationFontSize => Platform.isWindows ? 13 : 15;
  static double get queueCardsSpacing => Platform.isWindows ? 12 : 8;
  static double get queueCardPaddingV => Platform.isWindows ? 10 : 14;
  static double get queueCardPaddingH => Platform.isWindows ? 14 : 18;
  static double get queueContainerPaddingH => Platform.isWindows ? 16 : 32;
}
