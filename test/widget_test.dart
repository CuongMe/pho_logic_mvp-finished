import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pho_logic/src/app/app.dart';

void main() {
  testWidgets('Pho Logic app starts on its real application widget', (
    tester,
  ) async {
    await tester.pumpWidget(const PhoLogicApp());
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
