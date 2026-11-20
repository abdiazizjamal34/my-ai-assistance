import 'package:flutter_test/flutter_test.dart';

import 'package:personal_ai_chief_of_staff/core/network/api_client.dart';
import 'package:personal_ai_chief_of_staff/main.dart';

void main() {
  testWidgets('shows the backend status screen', (tester) async {
    await tester.pumpWidget(
      ChiefOfStaffApp(
        apiClient: ApiClient(
          baseUrl: 'http://localhost:4000',
          userId: 'test-user',
        ),
      ),
    );

    expect(find.text('Personal AI Chief of Staff'), findsOneWidget);
    expect(find.text('Backend Status'), findsOneWidget);
    expect(find.text('Check Connection'), findsOneWidget);
  });
}