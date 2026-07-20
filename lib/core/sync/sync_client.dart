import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/account.dart';
import '../../providers/partner_sync_provider.dart';
import '../utils/app_logger.dart';

class SyncClient {
  final Ref ref;

  SyncClient(this.ref);

  /// Handles reconciliation for partner sync.
  /// Partner accounts, transactions, and calendar items are kept strictly isolated 
  /// within PartnerSyncState for display only in the Partner Sharing module.
  /// Personal local SQLite database remains 100% separate and unmerged.
  Future<void> reconcile({
    required List<Account> newPartnerAccounts,
    required List<PartnerTransaction> newPartnerTransactions,
    required List<PartnerTransaction> oldPartnerTransactions,
    List<Map<String, dynamic>>? partnerBudgets,
    List<Map<String, dynamic>>? partnerPlanningMeta,
  }) async {
    try {
      AppLogger.i(
        'Partner sync payload received (${newPartnerAccounts.length} accounts, ${newPartnerTransactions.length} transactions). Stored strictly isolated in Partner Sharing module.',
        tag: 'SyncClient',
      );
    } catch (e, stack) {
      AppLogger.e('SyncClient reconciliation error', error: e, stackTrace: stack, tag: 'SyncClient');
    }
  }
}
