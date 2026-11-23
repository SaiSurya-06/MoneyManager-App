import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:money_manager/core/utils/share_code_encoder.dart';
import 'package:money_manager/models/account.dart';
import 'package:money_manager/models/transaction.dart';
import 'package:money_manager/providers/accounts_provider.dart';
import 'package:money_manager/providers/auth_provider.dart';
import 'package:money_manager/providers/categories_provider.dart';
import 'package:money_manager/providers/transactions_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/core/utils/encryption_service.dart';
import 'package:money_manager/providers/partner_sync_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Partner host only issues an invite after uploading selected data',
      () async {
    final date = DateTime(2026, 1, 1);
    final account = Account(
      id: 1,
      name: 'Household',
      type: 'Bank',
      balance: 100,
      icon: 'account_balance',
      color: '#4CAF50',
      isShared: false,
      createdAt: date,
    );
    final archived = account.copyWith(
      id: 2,
      name: 'Archived household',
      isShared: true,
      isArchived: true,
    );
    final transaction = Transaction(
      id: 1,
      accountId: 1,
      categoryId: 1,
      title: 'Shared purchase',
      amount: 20,
      type: 'expense',
      date: date,
      isPrivate: false,
      createdAt: date,
    );
    final accounts = _TestAccounts()..setAccounts([account, archived]);
    final container = ProviderContainer(overrides: [
      accountsProvider.overrideWith((ref) => accounts),
      authProvider.overrideWith((ref) => _TestAuth()),
      categoriesProvider.overrideWith(_TestCategories.new),
      transactionsProvider.overrideWith((ref) => _TestTransactions(ref, [
        transaction,
        transaction.copyWith(id: 3, accountId: 2, title: 'Archived purchase'),
        transaction.copyWith(id: 2, title: 'Private purchase', isPrivate: true),
      ])),
    ]);
    addTearDown(container.dispose);

    var failUpload = true;
    var supportsPost = false;
    var legacyUploads = 0;
    var postUploads = 0;
    var receipts = 0;
    var peerSnapshot = '404';
    final uploads = <Map<String, dynamic>>[];
    final encryption = EncryptionService.instance;
    await http.runWithClient(() async {
      final host = container.read(partnerSyncProvider.notifier);
      const endpoint = 'https://script.google.com/macros/s/test/exec';

      expect(await host.generateInviteCode(endpoint), isNull);
      expect(container.read(partnerSyncProvider).isConnected, isFalse);

      failUpload = false;
      final invite = ShareCodeEncoder.decode((await host.generateInviteCode(endpoint))!);
      final password = invite['password'] as String;
      final salt = invite['salt'] as String;
      final sender = '${invite['room']}__A_data';
      Map<String, dynamic> readSnapshot(Map<String, dynamic> envelope) {
        expect(envelope.containsKey('transactions'), isFalse);
        final ciphertext = envelope['encrypted'] as String;
        final signature = envelope['signature'] as String;
        expect(encryption.verifySyncSnapshot(ciphertext, password, sender, signature), isTrue);
        expect(encryption.verifySyncSnapshot(ciphertext, password, '${sender}other', signature), isFalse);
        expect(encryption.verifySyncSnapshot('${ciphertext}x', password, sender, signature), isFalse);
        return jsonDecode(encryption.decrypt(ciphertext, password, salt)) as Map<String, dynamic>;
      }

      final empty = readSnapshot(uploads.single);
      expect(empty['accounts'], isEmpty);
      expect(empty['transactions'], isEmpty);

      accounts.setAccounts([account.copyWith(isShared: true), archived]);
      expect(await host.syncNow(), isTrue);
      final shared = readSnapshot(uploads.last);
      expect(shared['accounts'], hasLength(1));
      final transactions = shared['transactions'] as List;
      expect(transactions.single['t'], transaction.title);

      final legacyCount = legacyUploads;
      supportsPost = true;
      expect(await host.syncNow(), isTrue);
      expect(postUploads, 1);
      expect(receipts, 1);
      expect(readSnapshot(uploads.last)['accounts'], shared['accounts']);
      failUpload = true;
      expect(await host.syncNow(), isFalse);
      expect(postUploads, 2);
      expect(legacyUploads, legacyCount);
      failUpload = false;

      final peer = jsonEncode({
        'profile': {'name': 'Partner'},
        'accounts': [archived.toMap()],
        'transactions': [],
      });
      final ciphertext = encryption.encrypt(peer, password, salt);
      final peerSender = '${invite['room']}__B_data';
      peerSnapshot = ShareCodeEncoder.encode({
        'encrypted': ciphertext,
        'signature': encryption.signSyncSnapshot(ciphertext, password, peerSender),
      });
      final linking = host.syncNow(partnerJustJoined: true);
      final progress = container.read(partnerSyncProvider);
      expect(progress.partnerName, 'Waiting...');
      expect(progress.isSyncing, isTrue);
      expect(await linking, isTrue);
      expect(container.read(partnerSyncProvider).partnerAccounts, isEmpty);
      expect(container.read(partnerSyncProvider).partnerAuthenticated, isTrue);
      expect(container.read(partnerSyncProvider).partnerName, 'Partner');

      peerSnapshot = ShareCodeEncoder.encode({
        'profile': {'name': 'Unsigned replacement'},
        'accounts': [],
        'transactions': [],
      });
      expect(await host.syncNow(), isFalse);
      expect(container.read(partnerSyncProvider).partnerName, 'Partner');

    }, () => MockClient((request) async {
      final parameters = request.url.queryParameters;
      if (request.url.host == 'script.googleusercontent.com') {
        expect(request.method, 'GET');
        expect(request.body, isEmpty);
        expect(parameters, isEmpty);
        receipts++;
        return http.Response('assembled', 200);
      }
      if (parameters['action'] == 'test') {
        return http.Response(
          supportsPost && parameters['client'] == '2' ? 'ok:post-v1' : 'ok',
          200,
        );
      }
      if (parameters['action'] == 'set_snapshot') {
        postUploads++;
        expect(request.method, 'POST');
        expect(parameters.containsKey('val'), isFalse);
        if (failUpload) return http.Response('error: could not save snapshot', 200);
        uploads.add(ShareCodeEncoder.decode(request.body));
        return http.Response('', 302, headers: {
          'location': 'https://script.googleusercontent.com/receipt',
        });
      }
      if (parameters['action'] == 'get') return http.Response(peerSnapshot, 200);
      legacyUploads++;
      expect(parameters['action'], 'set_chunk');
      if (failUpload) return http.Response('<html>Unavailable</html>', 200);
      expect(parameters['total'], '1');
      uploads.add(ShareCodeEncoder.decode(parameters['val']!));
      return http.Response('assembled', 200);
    }));
  });

  group('EncryptionService Tests (Issue #2)', () {
    final service = EncryptionService.instance;
    const password = 'mySecretPin1234';
    const salt = 'randomSaltStr';
    const plaintext = 'Sensitive Transaction Data';

    test('Encryption & Decryption Roundtrip with PBKDF2', () {
      final encrypted = service.encrypt(plaintext, password, salt);
      expect(encrypted, isNotEmpty);
      expect(encrypted, isNot(contains(plaintext)));

      final decrypted = service.decrypt(encrypted, password, salt);
      expect(decrypted, equals(plaintext));
    });

    test('Decryption fails with incorrect password', () {
      final encrypted = service.encrypt(plaintext, password, salt);
      expect(() => service.decrypt(encrypted, 'wrongPassword', salt), throwsException);
    });

    test('Legacy key derivation fallback', () {
      // Manually derive legacy key and verify fallback mechanism
      final legacyKey = service.deriveLegacyKey(password, salt);
      expect(legacyKey.bytes.length, equals(32));
    });
  });

  group('PartnerTransaction Payload Validation (Issue #11)', () {
    test('Validates negative and NaN amounts', () {
      final mapWithNan = {
        'title': 'Test Tx',
        'amount': double.nan,
        'type': 'expense',
        'date': '2026-07-21T00:00:00.000',
      };
      final tx = PartnerTransaction.fromMap(mapWithNan);
      expect(tx.amount, equals(0.0));
    });

    test('Validates malformed dates cleanly without throwing', () {
      final mapWithBadDate = {
        'title': 'Test Tx',
        'amount': 50.0,
        'type': 'expense',
        'date': 'invalid-date-string',
      };
      final tx = PartnerTransaction.fromMap(mapWithBadDate);
      expect(tx.amount, equals(50.0));
      expect(tx.date, isNotNull);
    });
  });
}


class _TestAccounts extends AccountsNotifier {
  @override
  Future<void> loadAccounts() async {}

  void setAccounts(List<Account> accounts) {
    state = AccountsState(accounts: accounts);
  }
}

class _TestAuth extends AuthNotifier {
  @override
  Future<void> checkProfile() async {}
}

class _TestCategories extends CategoriesNotifier {
  _TestCategories(super.ref);

  @override
  Future<void> loadCategories() async {}
}

class _TestTransactions extends TransactionsNotifier {
  _TestTransactions(super.ref, List<Transaction> transactions) {
    state = TransactionsState(
      transactions: transactions,
      projectedTransactions: transactions,
    );
  }

  @override
  Future<void> loadTransactions() async {}

  @override
  Future<void> loadPresets() async {}
}
