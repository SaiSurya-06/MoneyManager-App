import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/models/account.dart';
import 'package:money_manager/pages/accounts/account_card.dart';
import 'package:money_manager/pages/accounts/accounts_page.dart';
import 'package:money_manager/providers/accounts_provider.dart';
import 'package:money_manager/providers/auth_provider.dart';

void main() {
  for (final (width, scale) in [
    (390.0, 1.0),
    (320.0, 2.0),
  ]) {
    testWidgets('Accounts fit at width $width and text scale $scale', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 1000);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountsProvider.overrideWith(
              (ref) => _TestAccounts([
                _creditCard(1, 'Household credit card with a long name'),
                _creditCard(2, 'Travel credit card'),
                _creditCard(3, 'Archived credit card', archived: true),
              ]),
            ),
            authProvider.overrideWith((ref) => _TestAuth()),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
              ),
              child: child!,
            ),
            home: const AccountsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final first = find.text('Household credit card with a long name');
      final second = find.text('Travel credit card');
      await tester.scrollUntilVisible(second, 160);
      expect(first, findsOneWidget);
      expect(second, findsOneWidget);
      expect(tester.getTopLeft(first).dx, tester.getTopLeft(second).dx);
      expect(tester.getBottomLeft(first).dy, lessThan(tester.getTopLeft(second).dy));
      final utilization = find.textContaining('Utilized:').last;
      await tester.ensureVisible(utilization);
      await tester.pumpAndSettle();
      final lastCard = find.ancestor(
        of: utilization,
        matching: find.byType(AccountCard),
      );
      expect(
        tester.getBottomRight(utilization).dy,
        lessThan(tester.getBottomRight(lastCard).dy),
      );
      expect(find.textContaining('Pending payment:'), findsWidgets);

      if (scale == 1.0) {
        final reorder = find.text('Reorder');
        await tester.scrollUntilVisible(reorder, -200);
        await tester.tap(reorder);
        await tester.pumpAndSettle();
        final handles = find.byIcon(Icons.drag_handle);
        final start = tester.getCenter(handles.last);
        final target = tester.getCenter(handles.first) + const Offset(0, 8);
        final drag = await tester.startGesture(start);
        for (var step = 1; step <= 8; step++) {
          await drag.moveTo(Offset.lerp(start, target, step / 8)!);
          await tester.pump(const Duration(milliseconds: 40));
        }
        await drag.up();
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save order'));
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(second).dy, lessThan(tester.getTopLeft(first).dy));
      }

      final archived = find.text('Archived (1)');
      await tester.scrollUntilVisible(archived, -200);
      await tester.tap(archived);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Archived credit card'), 160);
      expect(find.text('Archived credit card'), findsOneWidget);
    });
  }

  testWidgets('Account card forwards tap and long-press actions', (tester) async {
    int taps = 0;
    int longPresses = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AccountCard(
          account: _creditCard(1, 'Travel credit card'),
          currency: 'INR',
          onTap: () => taps++,
          onLongPress: () => longPresses++,
        ),
      ),
    ));
    await tester.tap(find.text('Travel credit card'));
    await tester.longPress(find.text('Travel credit card'));
    expect(taps, 1);
    expect(longPresses, 1);
  });
}

Account _creditCard(int id, String name, {bool archived = false}) {
  return Account(
    id: id,
    name: name,
    type: 'Credit Card',
    balance: -456789.12,
    limitAmount: 1234567.89,
    icon: 'credit_card',
    color: '#7950AB',
    isShared: false,
    isArchived: archived,
    createdAt: DateTime(2026, 1, 1),
  );
}

class _TestAccounts extends AccountsNotifier {
  _TestAccounts(List<Account> accounts) {
    state = AccountsState(accounts: accounts);
  }

  @override
  Future<void> saveActiveAccountOrder(List<int> ids) async {
    final accounts = {for (final account in state.activeAccounts) account.id: account};
    state = state.copyWith(accounts: [
      for (final id in ids) accounts[id]!,
      ...state.archivedAccounts,
    ]);
  }

  @override
  Future<void> loadAccounts() async {}
}

class _TestAuth extends AuthNotifier {
  @override
  Future<void> checkProfile() async {}
}
