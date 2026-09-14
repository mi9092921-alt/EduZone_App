import 'package:app/shared/widgets/confirm_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> openDialog(
    WidgetTester tester, {
    bool isDangerous = false,
    bool isLoading = false,
    bool settle = true,
    VoidCallback? onConfirm,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => ConfirmDialog(
                    title: 'Delete item?',
                    description: 'This cannot be undone.',
                    confirmLabel: 'Delete',
                    cancelLabel: 'Cancel',
                    isDangerous: isDangerous,
                    isLoading: isLoading,
                    onConfirm: onConfirm,
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    // settle: false for the loading state — its spinner animates forever,
    // so pumpAndSettle would time out.
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump();
    }
  }

  testWidgets('renders title, description and action labels', (tester) async {
    await openDialog(tester);
    expect(find.text('Delete item?'), findsOneWidget);
    expect(find.text('This cannot be undone.'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('cancel pops the dialog without confirming', (tester) async {
    var confirmed = false;
    await openDialog(tester, onConfirm: () => confirmed = true);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Delete item?'), findsNothing);
    expect(confirmed, isFalse);
  });

  testWidgets('confirm invokes the callback', (tester) async {
    var confirmed = false;
    await openDialog(tester, onConfirm: () => confirmed = true);
    await tester.tap(find.text('Delete'));
    await tester.pump();
    expect(confirmed, isTrue);
  });

  testWidgets('loading state disables the confirm action', (tester) async {
    var confirmed = false;
    await openDialog(
      tester,
      isLoading: true,
      settle: false,
      onConfirm: () => confirmed = true,
    );

    // While loading, AppButton replaces the label with a spinner and
    // nulls its onPressed — assert that contract on the rendered button.
    final button = tester.widget<ElevatedButton>(
      find.byType(ElevatedButton).last,
    );
    expect(button.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(confirmed, isFalse);
  });
}
