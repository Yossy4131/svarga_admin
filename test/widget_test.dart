import 'package:flutter_test/flutter_test.dart';

import 'package:svarga_admin/main.dart';

void main() {
  testWidgets('AdminApp shows login page', (WidgetTester tester) async {
    await tester.pumpWidget(const AdminApp());
    await tester.pump();
    // ログインページにURL・トークン入力フィールドが表示される
    expect(find.text('Svarga Admin'), findsOneWidget);
  });
}
