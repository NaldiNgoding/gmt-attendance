import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gmt_attendance_2026/main.dart';
import 'package:gmt_attendance_2026/attendance_home.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('GmtApp shows HomePage when logged in',
      (WidgetTester tester) async {
    await tester.pumpWidget(const GmtApp(isLoggedIn: true));
    await tester.pumpAndSettle();

    expect(find.byType(HomePage), findsOneWidget);
  });

  testWidgets('GmtApp shows WelcomePage when not logged in',
      (WidgetTester tester) async {
    await tester.pumpWidget(const GmtApp(isLoggedIn: false));
    await tester.pumpAndSettle();

    // Pastikan bukan HomePage
    expect(find.byType(HomePage), findsNothing);
  });
}
