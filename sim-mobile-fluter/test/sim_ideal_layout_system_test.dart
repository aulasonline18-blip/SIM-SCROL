import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/shared/widgets/shared_widgets.dart';
import 'package:sim_mobile/sim/classroom/classroom_text_scale.dart';
import 'package:sim_mobile/sim/ui/sim_design_system.dart';
import 'package:sim_mobile/sim/ui/widgets/cyber_step_shell.dart';

void main() {
  test('SIM Ideal breakpoints keep phone focused and tablet wider', () {
    expect(SimBreakpoints.frameMaxWidth(390), 480);
    expect(SimBreakpoints.learningMaxWidth(390), 480);
    expect(SimBreakpoints.frameMaxWidth(800), 840);
    expect(SimBreakpoints.learningMaxWidth(800), 640);
    expect(SimBreakpoints.frameMaxWidth(1200), 1120);
    expect(SimBreakpoints.learningMaxWidth(1200), 720);
  });

  test('classroom text scale grows strongly on phone and tablet', () {
    expect(ClassroomTextScale.scaleForWidth(5, 390), 1.44);
    expect(ClassroomTextScale.scaleForWidth(3, 390), 1.12);
    expect(ClassroomTextScale.scaleForWidth(1, 800), 1.18);
    expect(ClassroomTextScale.scaleForWidth(5, 800), 1.86);
    expect(
      ClassroomTextScale.scaleForWidth(1, 800),
      greaterThan(ClassroomTextScale.scaleForWidth(5, 390) - 0.3),
    );
  });

  testWidgets('primary and secondary actions keep accessible touch height', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            PrimaryWideButton(label: 'Continuar', onTap: () {}),
            SecondaryWideButton(label: 'Voltar', onTap: () {}),
          ],
        ),
      ),
    );

    expect(tester.getSize(find.text('Continuar')).height, greaterThan(0));
    expect(
      tester.getSize(find.byType(FilledButton).first).height,
      greaterThanOrEqualTo(SimTouch.min),
    );
    expect(
      tester.getSize(find.byType(FilledButton).last).height,
      greaterThanOrEqualTo(SimTouch.min),
    );
  });

  testWidgets('CyberStepShell widens learning column on tablet', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(820, 1000));
    await tester.pumpWidget(
      const MaterialApp(
        home: CyberStepShell(
          step: 1,
          total: 5,
          child: SizedBox(key: Key('ideal-child'), width: double.infinity),
        ),
      ),
    );

    final childWidth = tester
        .getSize(find.byKey(const Key('ideal-child')))
        .width;
    expect(childWidth, greaterThan(560));
    expect(childWidth, lessThanOrEqualTo(640));

    await tester.binding.setSurfaceSize(null);
  });
}
