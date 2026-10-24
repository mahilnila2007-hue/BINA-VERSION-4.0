import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/color_palette.dart';

/// Helper utility for launching exercise instructional training videos
/// externally via YouTube app (if available) or the default web browser.
class VideoLauncherHelper {
  /// Extracts the standard 11-character YouTube video ID from a URL or raw ID.
  static String extractVideoId(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return '';

    // Direct 11-character alphanumeric/dash/underscore ID
    final idRegex = RegExp(r'^[a-zA-Z0-9_-]{11}$');
    if (idRegex.hasMatch(trimmed)) {
      return trimmed;
    }

    // Parse URL query parameter 'v'
    final uri = Uri.tryParse(trimmed);
    if (uri != null) {
      if (uri.queryParameters.containsKey('v')) {
        final v = uri.queryParameters['v'];
        if (v != null && v.isNotEmpty) {
          return v;
        }
      }
      // youtu.be/<id>
      if (uri.host.contains('youtu.be') && uri.pathSegments.isNotEmpty) {
        return uri.pathSegments.first;
      }
      // youtube.com/embed/<id>
      if (uri.pathSegments.contains('embed')) {
        final idx = uri.pathSegments.indexOf('embed');
        if (idx + 1 < uri.pathSegments.length) {
          return uri.pathSegments[idx + 1];
        }
      }
    }

    // Fallback regex matching standard 11-character YouTube video ID
    final match = RegExp(r'(?:v=|\/|youtu\.be\/|embed\/)([a-zA-Z0-9_-]{11})')
        .firstMatch(trimmed);
    if (match != null && match.groupCount >= 1) {
      return match.group(1)!;
    }

    return trimmed;
  }

  /// Builds the full canonical YouTube web URL for a given video ID or URL.
  static String getFullWebUrl(String videoUrlOrId) {
    final videoId = extractVideoId(videoUrlOrId);
    if (videoId.isNotEmpty) {
      return 'https://www.youtube.com/watch?v=$videoId';
    }
    if (videoUrlOrId.startsWith('http://') || videoUrlOrId.startsWith('https://')) {
      return videoUrlOrId;
    }
    return 'https://www.youtube.com/watch?v=$videoUrlOrId';
  }

  /// Opens the exercise training video externally.
  /// 
  /// Flow:
  /// 1. Try launching the native YouTube app via `vnd.youtube:<videoId>`.
  /// 2. If YouTube app is not available or fails, fall back to opening
  ///    `https://www.youtube.com/watch?v=<videoId>` in the default web browser.
  /// 3. Completely avoids embedded WebViews (`LaunchMode.externalApplication`).
  /// 4. Gracefully handles errors without crashing.
  static Future<bool> openExerciseVideo(String videoUrlOrId) async {
    final videoId = extractVideoId(videoUrlOrId);
    final fullWebUrl = getFullWebUrl(videoUrlOrId);
    final webUri = Uri.parse(fullWebUrl);

    // 1. Attempt opening in YouTube app first (if valid videoId present)
    if (videoId.isNotEmpty) {
      final appUri = Uri.parse('vnd.youtube:$videoId');
      try {
        if (await canLaunchUrl(appUri)) {
          final launched = await launchUrl(
            appUri,
            mode: LaunchMode.externalApplication,
          );
          if (launched) return true;
        }
      } catch (e) {
        debugPrint('YouTube app URI launch attempt failed, falling back to browser: $e');
      }
    }

    // 2. Fall back to opening in the default browser externally
    try {
      if (await canLaunchUrl(webUri)) {
        final launched = await launchUrl(
          webUri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) return true;
      }
    } catch (e) {
      debugPrint('Browser canLaunchUrl check failed: $e');
    }

    // 3. Last-resort direct external launch attempt
    try {
      return await launchUrl(
        webUri,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('Error launching exercise video externally: $e');
      return false;
    }
  }

  /// Opens the video and provides non-intrusive visual feedback if launching fails.
  static Future<void> launchVideoWithFeedback(
    BuildContext context,
    String videoUrlOrId,
  ) async {
    final success = await openExerciseVideo(videoUrlOrId);
    if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to open video ($videoUrlOrId) externally. Please check your browser.'),
          backgroundColor: AppPalette.coralRed,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
