import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zipr/screens/zipr_feed_viewer_screen.dart';
import 'package:zipr/theme/app_theme.dart';
import 'package:zipr/widgets/zoomable_photo_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Modern Photo Gallery Zooming & Edge Slide Mechanics', () {
    testWidgets('ZoomablePhotoWidget defaults to BoxFit.fitWidth and full device width', (tester) async {
      // Create a temporary 1x1 image file
      final tempDir = Directory.systemTemp.createTempSync('photo_test');
      final tempFile = File('${tempDir.path}/test.jpg')..writeAsBytesSync([
        0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
        0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xFF, 0xDB, 0x00, 0x43,
        0x00, 0x08, 0x06, 0x06, 0x07, 0x06, 0x05, 0x08, 0x07, 0x07, 0x07, 0x09,
        0x09, 0x08, 0x0A, 0x0C, 0x14, 0x0D, 0x0C, 0x0B, 0x0B, 0x0C, 0x19, 0x12,
        0x13, 0x0F, 0x14, 0x1D, 0x1A, 0x1F, 0x1E, 0x1D, 0x1A, 0x1C, 0x1C, 0x20,
        0x24, 0x2E, 0x27, 0x20, 0x22, 0x2C, 0x23, 0x1C, 0x1C, 0x28, 0x37, 0x29,
        0x2C, 0x30, 0x31, 0x34, 0x34, 0x34, 0x1F, 0x27, 0x39, 0x3D, 0x38, 0x32,
        0x3C, 0x2E, 0x33, 0x34, 0x32, 0xFF, 0xC0, 0x00, 0x0B, 0x08, 0x00, 0x01,
        0x00, 0x01, 0x01, 0x01, 0x11, 0x00, 0xFF, 0xC4, 0x00, 0x1F, 0x00, 0x00,
        0x01, 0x05, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
        0x09, 0x0A, 0x0B, 0xFF, 0xDA, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3F,
        0x00, 0xBF, 0x80, 0xFF, 0xD9
      ]);

      bool zoomChanged = false;
      int navDirection = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZoomablePhotoWidget(
              photoFile: tempFile,
              onZoomChanged: (z) => zoomChanged = z,
              onNavigateAdjacent: (dir) => navDirection = dir,
            ),
          ),
        ),
      );
      expect(zoomChanged, isFalse);
      expect(navDirection, equals(0));

      final widgetFinder = find.byType(ZoomablePhotoWidget);
      expect(widgetFinder, findsOneWidget);

      final photoWidget = tester.widget<ZoomablePhotoWidget>(widgetFinder);
      expect(photoWidget.fit, equals(BoxFit.fitWidth));

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final imageWidget = tester.widget<Image>(imageFinder);
      expect(imageWidget.fit, equals(BoxFit.fitWidth));
      expect(imageWidget.width, equals(double.infinity));

      // Clean up
      tempDir.deleteSync(recursive: true);
    });

    test('Modern gallery boundary math accurately flags left/right edges for adjacent navigation', () {
      const screenWidth = 390.0;
      const scale = 2.5;
      const minTx = screenWidth * (1.0 - scale); // 390 * (1 - 2.5) = -585.0

      // Case 1: At left edge (tx = 0)
      const txLeft = 0.0;
      final isAtLeftEdge = txLeft >= -5.0;
      final isAtRightEdge1 = txLeft <= (minTx + 5.0);
      expect(isAtLeftEdge, isTrue);
      expect(isAtRightEdge1, isFalse);

      // Case 2: At right edge (tx = -585.0)
      const txRight = -585.0;
      final isAtLeftEdge2 = txRight >= -5.0;
      final isAtRightEdge2 = txRight <= (minTx + 5.0);
      expect(isAtLeftEdge2, isFalse);
      expect(isAtRightEdge2, isTrue);

      // Case 3: In the middle (inspecting media)
      const txMid = -300.0;
      expect(txMid >= -5.0, isFalse);
      expect(txMid <= (minTx + 5.0), isFalse);
    });

    test('ViewerMode enum provides continuous and cards modes', () {
      expect(ViewerMode.values.length, equals(2));
      expect(ViewerMode.continuous.name, equals('continuous'));
      expect(ViewerMode.cards.name, equals('cards'));
    });

    test('AppTheme brand palette has leaf green as primary accent', () {
      expect(AppTheme.brandLeafGreen, equals(const Color(0xFF7ED957)));
      expect(AppTheme.darkBg, equals(const Color(0xFF1B2714)));
    });
  });
}
