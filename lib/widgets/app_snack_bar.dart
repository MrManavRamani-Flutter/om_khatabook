import 'package:flutter/material.dart';

class AppSnackBar {
  /// Displays a modern, non-blocking floating SnackBar for items moved to Recycle Bin.
  /// Includes an immediate UNDO button and a dedicated CLOSE (✕) button.
  static void showRecycleBinSnackBar(
    BuildContext context, {
    required String message,
    required VoidCallback onUndo,
    Duration duration = const Duration(seconds: 4),
  }) {
    final messenger = ScaffoldMessenger.of(context);
    // Dismiss any existing snackbars immediately so it never stacks or hangs
    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        duration: duration,
        behavior: SnackBarBehavior.floating,
        elevation: 6,
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: const Color(0xFF1E293B),
        content: Row(
          children: [
            const Icon(Icons.delete_sweep_outlined, size: 20, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            // UNDO BUTTON
            InkWell(
              onTap: () {
                onUndo();
                messenger.hideCurrentSnackBar();
              },
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.amberAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.4)),
                ),
                child: const Text(
                  'UNDO',
                  style: TextStyle(
                    color: Colors.amberAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // CLOSE / DISMISS BUTTON (✕)
            InkWell(
              onTap: () => messenger.hideCurrentSnackBar(),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 16, color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

