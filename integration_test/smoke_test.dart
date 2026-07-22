import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sim_mobile/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SIM app renders initial route', (tester) async {
    await app.main();
    await tester.pump();
    expect(tester.binding.renderViews, isNotEmpty);
  });
}
