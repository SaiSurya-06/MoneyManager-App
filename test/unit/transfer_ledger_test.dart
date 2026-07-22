import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_manager/models/transaction.dart';
import 'package:money_manager/providers/transactions_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Transfer Ledger Tests', () {
    final now = DateTime.now();

    final txExpense = Transaction(
      id: 1,
      accountId: 1, // Account 1 (e.g. Checking)
      categoryId: 1,
      title: 'Groceries',
      amount: 50.0,
      type: 'expense',
      date: now,
      isPrivate: false,
      createdAt: now,
    );

    final txIncome = Transaction(
      id: 2,
      accountId: 1, // Account 1
      categoryId: 2,
      title: 'Salary',
      amount: 1000.0,
      type: 'income',
      date: now,
      isPrivate: false,
      createdAt: now,
    );

    final txTransfer = Transaction(
      id: 3,
      accountId: 1, // Account 1 (Source)
      transferToAccountId: 2, // Account 2 (Destination)
      categoryId: 3,
      title: 'Transfer to Savings',
      amount: 200.0,
      type: 'transfer',
      date: now,
      isPrivate: false,
      createdAt: now,
    );

    final txTransferNoteOnly = Transaction(
      id: 4,
      accountId: 1, // Account 1 (Source)
      categoryId: 3,
      title: 'Legacy Transfer',
      amount: 150.0,
      type: 'transfer',
      date: now,
      note: 'Transfer to target account ID: 3',
      isPrivate: false,
      createdAt: now,
    );

    test('effectiveDestinationAccountId returns transferToAccountId or parses note', () {
      expect(txTransfer.effectiveDestinationAccountId, equals(2));
      expect(txTransferNoteOnly.effectiveDestinationAccountId, equals(3));
      expect(txExpense.effectiveDestinationAccountId, isNull);
    });

    test('Unfiltered ledger displays one transfer entry per transfer transaction', () {
      final container = ProviderContainer(
        overrides: [
          transactionsProvider.overrideWith((ref) {
            final notifier = TransactionsNotifier(ref);
            notifier.state = notifier.state.copyWith(
              transactions: [txExpense, txIncome, txTransfer, txTransferNoteOnly],
              isLoading: false,
            );
            return notifier;
          }),
        ],
      );

      final notifier = container.read(transactionsProvider.notifier);
      final filtered = notifier.getFilteredTransactions();

      // Should contain all 4 transactions, each transfer appears exactly once
      expect(filtered.length, equals(4));
      expect(filtered.where((t) => t.type == 'transfer').length, equals(2));
    });

    test('Filtering by source account includes the transfer as source', () {
      final container = ProviderContainer(
        overrides: [
          transactionsProvider.overrideWith((ref) {
            final notifier = TransactionsNotifier(ref);
            notifier.state = notifier.state.copyWith(
              transactions: [txExpense, txIncome, txTransfer, txTransferNoteOnly],
              filterAccountId: 1, // Account 1 is source for txTransfer and txTransferNoteOnly
              isLoading: false,
            );
            return notifier;
          }),
        ],
      );

      final notifier = container.read(transactionsProvider.notifier);
      final filtered = notifier.getFilteredTransactions();

      // Account 1 should see txExpense, txIncome, txTransfer, txTransferNoteOnly
      expect(filtered.length, equals(4));
      expect(filtered.map((t) => t.id), containsAll([1, 2, 3, 4]));
    });

    test('Filtering by destination account includes the transfer as credit', () {
      final container = ProviderContainer(
        overrides: [
          transactionsProvider.overrideWith((ref) {
            final notifier = TransactionsNotifier(ref);
            notifier.state = notifier.state.copyWith(
              transactions: [txExpense, txIncome, txTransfer, txTransferNoteOnly],
              filterAccountId: 2, // Account 2 is destination for txTransfer
              isLoading: false,
            );
            return notifier;
          }),
        ],
      );

      final notifier = container.read(transactionsProvider.notifier);
      final filtered = notifier.getFilteredTransactions();

      // Account 2 should see only txTransfer (as destination credit)
      expect(filtered.length, equals(1));
      expect(filtered.first.id, equals(3));
      expect(filtered.first.effectiveDestinationAccountId, equals(2));
    });

    test('Filtering by Account 3 includes txTransferNoteOnly as destination credit', () {
      final container = ProviderContainer(
        overrides: [
          transactionsProvider.overrideWith((ref) {
            final notifier = TransactionsNotifier(ref);
            notifier.state = notifier.state.copyWith(
              transactions: [txExpense, txIncome, txTransfer, txTransferNoteOnly],
              filterAccountId: 3, // Account 3 is destination for txTransferNoteOnly
              isLoading: false,
            );
            return notifier;
          }),
        ],
      );

      final notifier = container.read(transactionsProvider.notifier);
      final filtered = notifier.getFilteredTransactions();

      expect(filtered.length, equals(1));
      expect(filtered.first.id, equals(4));
      expect(filtered.first.effectiveDestinationAccountId, equals(3));
    });
  });
}
