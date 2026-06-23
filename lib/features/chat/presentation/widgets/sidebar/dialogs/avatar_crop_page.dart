import 'dart:io';
import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Full-screen avatar crop page with SafeArea and no transition animation.
class AvatarCropPage extends StatefulWidget {
  const AvatarCropPage({super.key, required this.imagePath});

  final String imagePath;

  /// Push this page with zero-duration transition.
  static Future<Uint8List?> push(BuildContext context, String imagePath) {
    return Navigator.of(context).push<Uint8List?>(
      PageRouteBuilder<Uint8List?>(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, __, ___) => AvatarCropPage(imagePath: imagePath),
      ),
    );
  }

  @override
  State<AvatarCropPage> createState() => _AvatarCropPageState();
}

class _AvatarCropPageState extends State<AvatarCropPage> {
  final _cropController = CropController();
  late final Future<Uint8List> _imageFuture;
  bool _isCropping = false;

  @override
  void initState() {
    super.initState();
    _imageFuture = File(widget.imagePath).readAsBytes();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            _buildTopBar(theme),
            // Crop area
            Expanded(child: _buildCropArea()),
            // Bottom bar
            _buildBottomBar(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(ThemeData theme) {
    return Container(
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
    );
  }

  Widget _buildCropArea() {
    return FutureBuilder<Uint8List>(
      future: _imageFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }
        return Crop(
          image: snapshot.data!,
          controller: _cropController,
          aspectRatio: 1,
          withCircleUi: true,
          baseColor: Colors.black,
          maskColor: Colors.black.withValues(alpha: 0.7),
          cornerDotBuilder: (size, edgeAlignment) => const SizedBox.shrink(),
          onCropped: (result) {
            setState(() => _isCropping = false);
            result.when(
              success: (croppedImage) {
                if (mounted) Navigator.of(context).pop(croppedImage);
              },
              error: (error) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('裁剪失败，请重试')),
                  );
                }
              },
            );
          },
        );
      },
    );
  }

  Widget _buildBottomBar(ThemeData theme) {
    return Container(
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
    );
  }
}
