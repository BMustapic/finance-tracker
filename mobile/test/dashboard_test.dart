import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:finance_tracker/main.dart';

void main() {
  testWidgets('loads balances and saves a transaction through the API', (
    tester,
  ) async {
    final transactions = <Map<String, dynamic>>[];
    Map<String, dynamic>? posted;
    final client = MockClient((request) async {
      if (request.method == 'POST') {
        posted = jsonDecode(request.body) as Map<String, dynamic>;
        transactions.add({...posted!, 'id': 'tx1'});
        return http.Response(jsonEncode(transactions.last), 201);
      }
      return http.Response(
        jsonEncode({
          'accounts': [
            {'id': '1', 'name': 'Everyday', 'opening': 10000},
          ],
          'categories': [
            {'id': '1', 'name': 'Groceries'},
          ],
          'transactions': transactions,
        }),
        200,
      );
    });
    await tester.pumpWidget(MaterialApp(home: Dashboard(client: client)));
    await tester.pumpAndSettle();
    expect(find.text('€100.00'), findsOneWidget);
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Transaction'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Food');
    await tester.enterText(find.byType(TextFormField).at(1), '12.50');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(posted?['amount'], -1250);
    expect(posted?['accountId'], '1');
    expect(find.text('€87.50'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);
    client.close();
  });
  testWidgets('API failure gives a visible recoverable error', (tester) async {
    final client = MockClient((_) async => http.Response('unavailable', 503));
    await tester.pumpWidget(MaterialApp(home: Dashboard(client: client)));
    await tester.pumpAndSettle();
    expect(find.textContaining('Cannot reach the API'), findsOneWidget);
    expect(find.byTooltip('Refresh'), findsOneWidget);
    client.close();
  });
}
