import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  final source = File(
    '/tmp/codex-remote-attachments/019f0e26-090c-7ed3-bb12-deabcef8ffe6/da725c47-3fad-4769-a74a-f77662ebc353/1-Photo-1.jpg',
  );
  if (!source.existsSync()) {
    throw StateError('Launcher icon source image not found: ${source.path}');
  }

  final decoded = img.decodeImage(source.readAsBytesSync());
  if (decoded == null) {
    throw StateError('Could not decode launcher icon source image.');
  }

  // Bust crop: focuses the face, glasses, ears, hand, and upper body so the
  // launcher icon remains readable at small Android sizes.
  final crop = img.copyCrop(decoded, x: 220, y: 40, width: 760, height: 760);
  final base = img.Image(width: 1024, height: 1024);
  img.fill(base, color: img.ColorRgb8(255, 255, 255));

  final resized = img.copyResize(
    crop,
    width: 960,
    height: 960,
    interpolation: img.Interpolation.cubic,
  );
  img.compositeImage(base, resized, dstX: 32, dstY: 32);

  final assetDir = Directory('assets/app_icon')..createSync(recursive: true);
  File('${assetDir.path}/sim_launcher_icon.png').writeAsBytesSync(
    img.encodePng(base, level: 6),
  );

  const sizes = <String, int>{
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
  };

  for (final entry in sizes.entries) {
    final icon = img.copyResize(
      base,
      width: entry.value,
      height: entry.value,
      interpolation: img.Interpolation.cubic,
    );
    final target = File(
      'android/app/src/main/res/${entry.key}/ic_launcher.png',
    );
    target.writeAsBytesSync(img.encodePng(icon, level: 6));
  }
}
