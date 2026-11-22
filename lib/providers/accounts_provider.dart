import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/database/daos/account_dao.dart';
import '../models/account.dart';
import '../core/database/database.dart';

class AccountsState {
  final List<Account> accounts;
  final bool isLoading;
  final String? errorMessage;
  final bool showArchivedOnly;
  final List<int> activeAccountOrder;

  AccountsState({
    required this.accounts,
    this.isLoading = false,
    this.errorMessage,
    this.showArchivedOnly = false,
    this.activeAccountOrder = const [],
  });

  List<Account> get activeAccounts => accounts.where((a) => !a.isArchived).toList();
  List<Account> get archivedAccounts => accounts.where((a) => a.isArchived).toList();

  List<Account> get orderedActiveAccounts {
    final active = activeAccounts;
    final byId = {for (final account in active) account.id: account};
    final ranked = activeAccountOrder.toSet();
    return [
      for (final id in activeAccountOrder)
        if (byId[id] != null) byId[id]!,
      ...active.where((account) => !ranked.contains(account.id)),
    ];
  }

  AccountsState copyWith({
    List<Account>? accounts,
    bool? isLoading,
    String? errorMessage,
    bool? showArchivedOnly,
    List<int>? activeAccountOrder,
  }) {
    return AccountsState(
      accounts: accounts ?? this.accounts,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      showArchivedOnly: showArchivedOnly ?? this.showArchivedOnly,
      activeAccountOrder: activeAccountOrder ?? this.activeAccountOrder,
    );
  }
}

class AccountsNotifier extends StateNotifier<AccountsState> {
  final AccountDao _accountDao = AccountDao();

  AccountsNotifier() : super(AccountsState(accounts: [], isLoading: true)) {
    loadAccounts();
  }

  Future<void> loadAccounts() async {
    try {
      state = state.copyWith(isLoading: true);
      final accounts = await _accountDao.getAllAccounts(includeArchived: true);
      final activeAccountOrder = await _accountDao.getActiveAccountOrder();
      state = state.copyWith(
        accounts: accounts,
        activeAccountOrder: activeAccountOrder,
        isLoading: false,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Failed to load accounts: $e');
    }
  }

  Future<void> saveActiveAccountOrder(List<int> ids) async {
    await _accountDao.saveActiveAccountOrder(ids);
    if (mounted) state = state.copyWith(activeAccountOrder: List.of(ids));
  }

  void toggleArchivedFilter(bool showArchivedOnly) {
    state = state.copyWith(showArchivedOnly: showArchivedOnly);
  }

  Future<int?> addAccount(
    String name,
    String type,
    double balance,
    String icon,
    String color,
    bool isShared, [
    double? limitAmount,
    int? billingCycleStartDay,
    int? statementDueDay,
    double? minimumDue,
  ]) async {
    try {
      final newAccount = Account(
        name: name,
        type: type,
        balance: balance,
        icon: icon,
        color: color,
        isShared: isShared,
        createdAt: DateTime.now(),
        limitAmount: limitAmount,
        billingCycleStartDay: billingCycleStartDay,
        statementDueDay: statementDueDay,
        minimumDue: minimumDue,
      );
      final id = await _accountDao.insertAccount(newAccount);
      await loadAccounts();
      await AppDatabase.queueSyncAction('insert', 'account', id, newAccount.copyWith(id: id).toMap());
      return id;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to add account: $e');
      return null;
    }
  }

  Future<bool> updateAccount(Account account) async {
    try {
      await _accountDao.updateAccount(account);
      await loadAccounts();
      await AppDatabase.queueSyncAction('update', 'account', account.id!, account.toMap());
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to update account: $e');
      return false;
    }
  }

  Future<int> getTransactionCount(int accountId) async {
    return await _accountDao.getTransactionCountForAccount(accountId);
  }

  /// Archives the account.
  Future<bool> archiveAccount(int id) async {
    try {
      await _accountDao.archiveAccount(id);
      await loadAccounts();
      await AppDatabase.queueSyncAction('update', 'account', id, {'id': id, 'is_archived': 1});
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to archive account: $e');
      return false;
    }
  }

  /// Restores an archived account.
  Future<bool> restoreAccount(int id) async {
    try {
      await _accountDao.restoreAccount(id);
      await loadAccounts();
      await AppDatabase.queueSyncAction('update', 'account', id, {'id': id, 'is_archived': 0});
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to restore account: $e');
      return false;
    }
  }

  /// Safe deletion: will fail with informative message if transactions exist.
  Future<bool> deleteAccount(int id) async {
    try {
      final txCount = await _accountDao.getTransactionCountForAccount(id);
      if (txCount > 0) {
        state = state.copyWith(
          errorMessage: 'Cannot delete account with $txCount existing transactions. Please archive it instead.',
        );
        return false;
      }
      await _accountDao.deleteAccount(id);
      await loadAccounts();
      await AppDatabase.queueSyncAction('delete', 'account', id, {'id': id});
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to delete account: $e');
      return false;
    }
  }
}

final accountsProvider = StateNotifierProvider<AccountsNotifier, AccountsState>((ref) {
  return AccountsNotifier();
});
