
import 'package:flutter_test/flutter_test.dart';
import 'package:project17_password_reset/main.dart';

void main() {
  testWidgets('Password Reset Workflow loads correctly',
      (WidgetTester tester) async {
    await tester.pumpWidget(const PasswordResetApp());

    expect(
      find.text('Password Reset Request Workflow'),
      findsOneWidget,
    );

    expect(
      find.text('Create reset request'),
      findsOneWidget,
    );

    expect(
      find.text('Request queue'),
      findsOneWidget,
    );
  });
}
