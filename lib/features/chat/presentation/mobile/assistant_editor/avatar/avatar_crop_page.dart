import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

// ── Avatar crop page (bytes variant) ────────────────────────────────────────

/// A crop page that accepts raw bytes (from `ImagePickerApi.pickFromGallery`)
/// rather than a file path; otherwise identical to the user avatar crop page.
class AvatarCropPage extends StatefulWidget {
  const AvatarCropPage({super.key, required this.imageBytes});

  final Uint8List imageBytes;

  static Future<Uint8List?> push(BuildContext context, Uint8List imageBytes) {
    return Navigator.of(context).push<Uint8List?>(
      PageRouteBuilder<Uint8List?>(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, __, ___) => AvatarCropPage(imageBytes: imageBytes),
      ),
    );
  }

  @override
  State<AvatarCropPage> createState() => _AvatarCropPageState();
}

class _AvatarCropPageState extends State<AvatarCropPage> {
  final _cropController = CropController();
  bool _isCropping = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(LucideIcons.x, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  Text(
                    '裁剪头像',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: Crop(
                image: widget.imageBytes,
                controller: _cropController,
                aspectRatio: 1,
                withCircleUi: true,
                baseColor: Colors.black,
                maskColor: Colors.black.withValues(alpha: 0.7),
                cornerDotBuilder: (size, edgeAlignment) =>
                    const SizedBox.shrink(),
                onCropped: (croppedImage) {
                  setState(() => _isCropping = false);
                  if (mounted) Navigator.of(context).pop(croppedImage);
                },
              ),
            ),
            Container(
              height: 72,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _isCropping
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : FilledButton.icon(
                          onPressed: () {
                            setState(() => _isCropping = true);
                            _cropController.crop();
                          },
                          icon: const Icon(LucideIcons.check, size: 18),
                          label: const Text('确认'),
                          style: FilledButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                          ),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
