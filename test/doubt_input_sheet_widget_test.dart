import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/features/classroom/doubt_input_sheet_widget.dart';
import 'package:sim_mobile/sim/auxiliary/aux_room_models.dart';
import 'package:sim_mobile/sim/auxiliary/doubt_input_sheet.dart';
import 'package:sim_mobile/sim/ui/sim_theme.dart';

const _phoneSize = Size(390, 640);

Future<void> _pumpSheet(
  WidgetTester tester, {
  required TextEditingController controller,
  double bottomInset = 0,
  Size size = _phoneSize,
  DoubtImagePayload? initialImage,
  void Function(DoubtInputDraft draft)? onSubmit,
}) async {
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(size);
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          viewInsets: EdgeInsets.only(bottom: bottomInset),
        ),
        child: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: SimThemeScope(
              darkMode: false,
              onToggleDarkMode: () {},
              child: DoubtInputSheet(
                controller: controller,
                busy: false,
                initialImage: initialImage,
                onSubmit: onSubmit ?? (_) {},
                onClose: () {},
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 220));
}

void main() {
  testWidgets('keeps composer and submit action visible above keyboard', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await _pumpSheet(tester, controller: controller, bottomInset: 300);

    final frameRect = tester.getRect(
      find.byKey(const Key('doubt-input-sheet-frame')),
    );
    final fieldRect = tester.getRect(find.byType(TextField));
    final submitRect = tester.getRect(
      find.byKey(const Key('doubt-input-submit-button')),
    );

    expect(frameRect.bottom, lessThanOrEqualTo(_phoneSize.height - 300));
    expect(fieldRect.bottom, lessThanOrEqualTo(_phoneSize.height - 300));
    expect(submitRect.bottom, lessThanOrEqualTo(_phoneSize.height - 300));
    expect(find.text('Enviar dúvida'), findsWidgets);
  });

  testWidgets('preserves focused text across keyboard and resize changes', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await _pumpSheet(tester, controller: controller, bottomInset: 280);
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'Texto preservado');
    await tester.pump();

    expect(controller.text, 'Texto preservado');
    expect(FocusManager.instance.primaryFocus, isNotNull);

    await _pumpSheet(
      tester,
      controller: controller,
      bottomInset: 180,
      size: const Size(740, 390),
    );

    expect(controller.text, 'Texto preservado');
    expect(find.text('Texto preservado'), findsOneWidget);
    expect(FocusManager.instance.primaryFocus, isNotNull);
  });

  testWidgets('keeps submit action findable and tappable with keyboard open', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'Tenho uma dúvida.');
    addTearDown(controller.dispose);
    DoubtInputDraft? submitted;

    await _pumpSheet(
      tester,
      controller: controller,
      bottomInset: 300,
      onSubmit: (draft) => submitted = draft,
    );

    await tester.tap(find.byKey(const Key('doubt-input-submit-button')));
    await tester.pump();

    expect(submitted?.cleanText, 'Tenho uma dúvida.');
  });

  testWidgets('keeps attachment preview accessible when keyboard opens', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    const image = DoubtImagePayload(
      name: 'resolucao.png',
      type: 'image/png',
      size: 4,
      dataUrl: 'data:image/png;base64,AAAA',
    );

    await _pumpSheet(
      tester,
      controller: controller,
      bottomInset: 300,
      initialImage: image,
    );

    expect(find.text('Foto: resolucao.png'), findsOneWidget);
    expect(find.text('Remover'), findsOneWidget);

    final previewRect = tester.getRect(find.text('Foto: resolucao.png'));
    expect(previewRect.bottom, lessThanOrEqualTo(_phoneSize.height - 300));
  });
}
