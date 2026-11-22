import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:sqflite/sqflite.dart';
import '../database/database.dart';
import '../database/daos/category_dao.dart';
import '../utils/app_logger.dart';

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}

class BackupValidationResult {
  final bool isValid;
  final String? errorMessage;
  final int? schemaVersion;
  final int accountCount;
  final int transactionCount;
  final Map<String, dynamic>? metadata;

  const BackupValidationResult({
    required this.isValid,
    this.errorMessage,
    this.schemaVersion,
    this.accountCount = 0,
    this.transactionCount = 0,
    this.metadata,
  });
}

class RestoreResult {
  final bool success;
  final String message;
  final int restoredAccounts;
  final int restoredTransactions;
  final List<String> balanceSummaries;
  final String? errorMessage;

  const RestoreResult({
    required this.success,
    required this.message,
    this.restoredAccounts = 0,
    this.restoredTransactions = 0,
    this.balanceSummaries = const [],
    this.errorMessage,
  });
}

class BackupService {
  static final BackupService instance = BackupService._internal();
  BackupService._internal();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      drive.DriveApi.driveAppdataScope,
      drive.DriveApi.driveFileScope,
    ],
  );

  GoogleSignInAccount? _currentUser;
  GoogleSignInAccount? get currentUser => _currentUser;

  bool get isSignedIn => _currentUser != null;

  // Track if we are running in simulated fallback mode
  bool isSimulatedMode = false;

  void enableSimulatedMode() {
    isSimulatedMode = true;
    _currentUser = null;
  }

  Future<bool> signInSilently() async {
    try {
      _currentUser = await _googleSignIn.signInSilently();
      return _currentUser != null;
    } catch (e) {
      AppLogger.w('Silent Google sign-in failed', error: e, tag: 'BackupService');
      return false;
    }
  }

  Future<bool> signIn() async {
    try {
      _currentUser = await _googleSignIn.signIn();
      isSimulatedMode = false;
      return _currentUser != null;
    } catch (e, stack) {
      AppLogger.e('Google sign-in error', error: e, stackTrace: stack, tag: 'BackupService');
      return false;
    }
  }

  Future<void> signOut() async {
    if (isSimulatedMode) {
      isSimulatedMode = false;
      return;
    }
    try {
      _currentUser = await _googleSignIn.signOut();
    } catch (e) {
      AppLogger.w('Google sign-out error', error: e, tag: 'BackupService');
    }
  }

  // --- General Google Drive File Upload & Download Helpers ---

  Future<bool> backupFileToDrive(File localFile, String driveFileName) async {
    if (!await localFile.exists()) return false;

    if (isSimulatedMode) {
      final dbFolder = await getApplicationDocumentsDirectory();
      final backupPath = p.join(dbFolder.path, 'simulated_$driveFileName');
      await localFile.copy(backupPath);
      return true;
    }

    if (_currentUser == null) throw Exception('Google account is not signed in.');

    final authHeaders = await _currentUser!.authHeaders;
    final authenticateClient = GoogleAuthClient(authHeaders);
    final driveApi = drive.DriveApi(authenticateClient);

    // Search for existing file
    final fileList = await driveApi.files.list(
      q: "name = '$driveFileName' and trashed = false",
      spaces: 'appDataFolder',
    );

    final media = drive.Media(localFile.openRead(), await localFile.length());
    final driveFile = drive.File()
      ..name = driveFileName
      ..parents = ['appDataFolder'];

    if (fileList.files != null && fileList.files!.isNotEmpty) {
      final existingFileId = fileList.files!.first.id!;
      await driveApi.files.update(
        drive.File()..name = driveFileName,
        existingFileId,
        uploadMedia: media,
      );
    } else {
      await driveApi.files.create(
        driveFile,
        uploadMedia: media,
      );
    }
    return true;
  }

  Future<bool> restoreFileFromDrive(String driveFileName, File localDestinationFile) async {
    if (isSimulatedMode) {
      final dbFolder = await getApplicationDocumentsDirectory();
      final backupPath = p.join(dbFolder.path, 'simulated_$driveFileName');
      final backupFile = File(backupPath);
      if (!await backupFile.exists()) return false;
      
      await backupFile.copy(localDestinationFile.path);
      return true;
    }

    if (_currentUser == null) throw Exception('Google account is not signed in.');

    final authHeaders = await _currentUser!.authHeaders;
    final authenticateClient = GoogleAuthClient(authHeaders);
    final driveApi = drive.DriveApi(authenticateClient);

    final fileList = await driveApi.files.list(
      q: "name = '$driveFileName' and trashed = false",
      spaces: 'appDataFolder',
    );

    if (fileList.files == null || fileList.files!.isEmpty) {
      throw Exception('No backup file named "$driveFileName" found on Google Drive.');
    }

    final fileId = fileList.files!.first.id!;
    final drive.Media response = await driveApi.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final List<int> dataStore = [];
    await response.stream.forEach((data) {
      dataStore.addAll(data);
    });
    await localDestinationFile.writeAsBytes(dataStore);
    return true;
  }

  // --- SQLite Legacy Wrappers ---

  Future<bool> backupDatabase() async {
    return backupToGoogleDrive('sqlite');
  }

  Future<bool> restoreDatabase() async {
    return restoreFromGoogleDrive('sqlite');
  }

  // --- Advanced Backup Formats Serializer & Deserializers ---

  Future<String> exportDataToJson() async {
    final db = await AppDatabase.instance.database;
    final Map<String, dynamic> data = {};
    
    final tables = [
      'user_profile',
      'account',
      'category',
      'transaction_log',
      'budget',
      'savings_goal',
      'debt_loan',
      'filter_preset',
      'diagnostic_profile',
      'transaction_template',
      'health_score_history',
      'intelligence_report_history',
      'weekly_checkins',
      'planning_meta',
      'report_history',
      'backup_metadata',
      'balance_audit_log',
    ];

    for (var table in tables) {
      try {
        final list = await db.query(table);
        data[table] = list;
      } catch (_) {}
    }
    return jsonEncode(data);
  }

  List<Map<String, dynamic>> _restoreDiagnosticOwners(
    List<Map<String, dynamic>> diagnostics,
    List<Map<String, dynamic>> sourceProfiles,
    List<Map<String, dynamic>> deviceProfiles,
  ) {
    return diagnostics.map((row) {
      final sourceId = row['user_profile_id'];
      final source = sourceProfiles.where((profile) => profile['id'] == sourceId);
      final matches = source.length == 1
          ? deviceProfiles.where((profile) => profile['name'] == source.single['name'])
          : deviceProfiles.where((profile) => profile['id'] == sourceId);
      final int targetId;
      if (sourceProfiles.length == 1 &&
          source.length == 1 &&
          deviceProfiles.length == 1) {
        // A new phone can have a different profile name and id.
        targetId = deviceProfiles.single['id'] as int;
      } else if (matches.length == 1) {
        targetId = matches.single['id'] as int;
      } else {
        throw const FormatException(
          'A backup profile with diagnostic records cannot be matched. '
          'Set up matching profile names on this device before restoring.',
        );
      }
      return {...row, 'user_profile_id': targetId};
    }).toList();
  }

  Future<void> importDataFromJson(String jsonStr) async {
    final data = jsonDecode(jsonStr);
    if (data is! Map<String, dynamic>) {
      throw const FormatException('The backup must contain a JSON object.');
    }
    final db = await AppDatabase.instance.database;

    await db.transaction((txn) async {
      final tables = [
        'user_profile',
        'account',
        'category',
        'transaction_log',
        'budget',
        'savings_goal',
        'debt_loan',
        'filter_preset',
        'diagnostic_profile',
        'transaction_template',
        'health_score_history',
        'intelligence_report_history',
        'weekly_checkins',
        'planning_meta',
        'report_history',
        'backup_metadata',
        'balance_audit_log',
      ];

      final imported = <String, List<Map<String, dynamic>>>{};
      for (final table in tables) {
        if (!data.containsKey(table)) continue;
        final rows = data[table];
        if (rows is! List || rows.any((row) => row is! Map<String, dynamic>)) {
          throw FormatException('Invalid rows in backup table $table.');
        }
        imported[table] = rows.cast<Map<String, dynamic>>();
      }
      final sourceProfiles = imported.remove('user_profile') ?? const [];
      if (imported.isEmpty) {
        throw const FormatException('The backup contains no supported financial tables.');
      }
      final diagnostics = imported['diagnostic_profile'];
      if (diagnostics != null && diagnostics.isNotEmpty) {
        imported['diagnostic_profile'] = _restoreDiagnosticOwners(
          diagnostics,
          sourceProfiles,
          await txn.query('user_profile'),
        );
      }

      // Remove dependent rows before their parent rows, then load parents first.
      for (final table in imported.keys.toList().reversed) {
        await txn.delete(table);
      }
      for (final entry in imported.entries) {
        for (final row in entry.value) {
          await txn.insert(entry.key, row);
        }
      }
      await AppDatabase.instance.recalculateAllBalances(txn);
    });
  }

  Future<String> exportDataToCsv() async {
    final db = await AppDatabase.instance.database;
    final List<List<dynamic>> csvData = [
      ['Date', 'Title', 'Amount', 'Type', 'Category', 'Account', 'Note', 'Recurrence', 'Recurrence End Date', 'Is Private', 'Destination Account', 'Deduct from Budget']
    ];

    final txs = await db.query('transaction_log');
    
    final accounts = await db.query('account');
    final Map<int, String> accountMap = {
      for (var row in accounts) row['id'] as int: row['name'] as String
    };

    final categories = await db.query('category');
    final Map<int, String> categoryMap = {
      for (var row in categories) row['id'] as int: row['name'] as String
    };

    for (var tx in txs) {
      final date = tx['date'] as String;
      final title = tx['title'] as String;
      final amount = (tx['amount'] as num).toDouble();
      final type = tx['type'] as String;
      final categoryName = categoryMap[tx['category_id'] as int] ?? 'Other';
      final accountName = accountMap[tx['account_id'] as int] ?? 'Account';
      final note = tx['note'] as String? ?? '';
      final recurrence = tx['recurrence'] as String? ?? 'none';
      final recEnd = tx['recurrence_end_date'] as String? ?? '';
      final isPrivate = (tx['is_private'] as int? ?? 0) == 1 ? 'yes' : 'no';

      final destinationId = tx['transfer_to_account_id'] as int? ??
          AppDatabase.parseCreditCardTargetAccountId(note) ??
          AppDatabase.parseDestAccountId(note);

      csvData.add([
        date,
        title,
        amount,
        type,
        categoryName,
        accountName,
        note,
        recurrence,
        recEnd,
        isPrivate,
        accountMap[destinationId] ?? '',
        (tx['is_budget_included'] as int? ?? 1) == 1 ? 'yes' : 'no',
      ]);
    }

    return const ListToCsvConverter().convert(csvData);
  }

  Future<void> importDataFromCsv(String csvStr) async {
    final List<List<dynamic>> rows = const CsvToListConverter().convert(csvStr);

    int headerRowIndex = -1;
    for (int i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (row.length >= 6) {
        final firstCol = row[0].toString().toLowerCase().trim();
        final secondCol = row[1].toString().toLowerCase().trim();
        if (firstCol == 'date' && secondCol == 'title') {
          headerRowIndex = i;
          break;
        }
      }
    }

    if (headerRowIndex == -1) {
      throw Exception('Invalid CSV file: missing transaction headers');
    }

    final db = await AppDatabase.instance.database;

    await db.transaction((txn) async {
      final categoryList = await txn.query('category');
      final Map<String, int> categoryNameToId = {
        for (var row in categoryList) (row['name'] as String).toLowerCase().trim(): row['id'] as int
      };
      final otherCategoryId = categoryNameToId['other'] ?? CategoryDao.otherCategoryId;

      final accountList = await txn.query('account');
      final Map<String, int> accountNameToId = {
        for (var row in accountList) (row['name'] as String).toLowerCase().trim(): row['id'] as int
      };

      Future<int> findOrCreateAccount(String name) async {
        final key = name.toLowerCase();
        final existing = accountNameToId[key];
        if (existing != null) return existing;
        final id = await txn.insert('account', {
          'name': name,
          'type': 'Bank',
          'balance': 0.0,
          'balance_minor': 0,
          'initial_balance': 0.0,
          'initial_balance_minor': 0,
          'icon': 'account_balance',
          'color': '1E88E5',
          'is_shared': 0,
          'created_at': DateTime.now().toIso8601String(),
        });
        accountNameToId[key] = id;
        return id;
      }

      await txn.delete('transaction_log');

      for (int i = headerRowIndex + 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.every((cell) => cell.toString().trim().isEmpty)) continue;
        if (row.length < 6) {
          throw FormatException('Incomplete transaction on CSV row ${i + 1}.');
        }

        final dateStr = row[0].toString().trim();
        final title = row[1].toString().trim();
        final amount = double.tryParse(row[2].toString()) ?? 0.0;
        final type = row[3].toString().trim().toLowerCase();
        final categoryName = row[4].toString().trim();
        final accountName = row[5].toString().trim();
        final note = row.length > 6 ? row[6].toString().trim() : '';
        final recurrence = row.length > 7 ? row[7].toString().trim().toLowerCase() : 'none';
        final recEndStr = row.length > 8 ? row[8].toString().trim() : '';
        final isPrivateStr = row.length > 9 ? row[9].toString().trim().toLowerCase() : 'no';

        if (title.isEmpty ||
            accountName.isEmpty ||
            !amount.isFinite ||
            amount <= 0 ||
            !['income', 'expense', 'transfer'].contains(type)) {
          throw FormatException('Invalid transaction on CSV row ${i + 1}.');
        }

        final categoryId = categoryNameToId[categoryName.toLowerCase()] ?? otherCategoryId;

        final accountId = await findOrCreateAccount(accountName);
        final destinationName = row.length > 10 ? row[10].toString().trim() : '';
        final destinationId = destinationName.isNotEmpty
            ? await findOrCreateAccount(destinationName)
            : AppDatabase.parseCreditCardTargetAccountId(note) ??
                AppDatabase.parseDestAccountId(note);
        if (type == 'transfer' &&
            (destinationId == null ||
                destinationId == accountId ||
                !accountNameToId.containsValue(destinationId))) {
          throw FormatException('Missing or invalid transfer destination on CSV row ${i + 1}.');
        }
        final budgetIncluded =
            row.length <= 11 || row[11].toString().trim().toLowerCase() != 'no';

        final date = DateTime.tryParse(dateStr);
        if (date == null ||
            (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dateStr) &&
                date.toIso8601String().substring(0, 10) != dateStr)) {
          throw FormatException('Invalid date on CSV row ${i + 1}.');
        }
        final recurrenceEndDate = recEndStr.isEmpty
            ? null
            : DateTime.tryParse(recEndStr);
        if (recEndStr.isNotEmpty && recurrenceEndDate == null) {
          throw FormatException('Invalid recurrence end date on CSV row ${i + 1}.');
        }

        final isPrivate = isPrivateStr == 'yes' || isPrivateStr == 'true' || isPrivateStr == '1';
        final amtMinor = (amount * 100).round();

        await txn.insert('transaction_log', {
          'account_id': accountId,
          'category_id': categoryId,
          'title': title,
          'amount': amount,
          'amount_minor': amtMinor,
          'type': type,
          'date': date.toIso8601String().substring(0, 10),
          'note': note.isEmpty ? null : note,
          'recurrence': recurrence,
          'recurrence_end_date': recurrenceEndDate?.toIso8601String().substring(0, 10),
          'is_private': isPrivate ? 1 : 0,
          'transfer_to_account_id': destinationId,
          'is_budget_included': budgetIncluded ? 1 : 0,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
      await AppDatabase.instance.recalculateAllBalances(txn);
    });
  }

  // --- High-Level Local Backup & Restore Entry Points ---

  Future<bool> backupToLocal(String format) async {
    try {
      final dbFolder = await getApplicationDocumentsDirectory();
      final tempDir = await getTemporaryDirectory();
      
      File fileToShare;
      String fileName;

      if (format == 'sqlite') {
        final localDbPath = p.join(dbFolder.path, 'money_manager.db');
        final dbFile = File(localDbPath);
        if (!await dbFile.exists()) return false;
        
        // 1. Flush WAL and checkpoint
        await AppDatabase.instance.checkpoint();

        // 2. Validate database integrity before export
        final isIntegrityValid = await AppDatabase.instance.verifyIntegrity();
        if (!isIntegrityValid) {
          AppLogger.e('Database integrity check failed prior to export.', tag: 'BackupService');
          return false;
        }

        // 3. Stamp metadata in SQLite database
        final db = await AppDatabase.instance.database;
        String preferredCurrency = 'INR';
        try {
          final profile = await db.query('user_profile', limit: 1);
          if (profile.isNotEmpty && profile.first['preferred_currency'] != null) {
            preferredCurrency = profile.first['preferred_currency'] as String;
          }
        } catch (_) {}

        final metadata = {
          'backup_created_at': DateTime.now().toIso8601String(),
          'app_version': '1.1.0',
          'db_schema_version': AppDatabase.schemaVersion.toString(),
          'backup_format_version': '2.0',
          'preferred_currency': preferredCurrency,
        };

        for (final entry in metadata.entries) {
          await db.insert(
            'backup_metadata',
            {'key': entry.key, 'value': entry.value},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        // 4. Final checkpoint to ensure metadata is flushed
        await AppDatabase.instance.checkpoint();

        fileName = 'money_manager_backup_${DateTime.now().millisecondsSinceEpoch}.db';
        final tempFile = File(p.join(tempDir.path, fileName));
        await dbFile.copy(tempFile.path);

        final bytes = await tempFile.readAsBytes();
        final checksum = sha256.convert(bytes).toString();
        AppLogger.i('Backup exported. Checksum: $checksum, size: ${bytes.length} bytes', tag: 'BackupService');

        fileToShare = tempFile;
      } else if (format == 'json') {
        final jsonStr = await exportDataToJson();
        fileName = 'money_manager_backup_${DateTime.now().millisecondsSinceEpoch}.json';
        final tempFile = File(p.join(tempDir.path, fileName));
        await tempFile.writeAsString(jsonStr);
        fileToShare = tempFile;
      } else if (format == 'csv') {
        final csvStr = await exportDataToCsv();
        fileName = 'money_manager_backup_${DateTime.now().millisecondsSinceEpoch}.csv';
        final tempFile = File(p.join(tempDir.path, fileName));
        await tempFile.writeAsString(csvStr);
        fileToShare = tempFile;
      } else {
        return false;
      }

      await Share.shareXFiles(
        [XFile(fileToShare.path, mimeType: format == 'sqlite' ? 'application/octet-stream' : 'text/$format')],
        subject: 'Money Manager Backup (${format.toUpperCase()})',
      );
      return true;
    } catch (e, stack) {
      AppLogger.e('Error during backupToLocal', error: e, stackTrace: stack, tag: 'BackupService');
      return false;
    }
  }

  /// Validates candidate backup file.
  Future<BackupValidationResult> validateBackupFile(File candidateFile) async {
    try {
      if (!await candidateFile.exists()) {
        return const BackupValidationResult(
          isValid: false,
          errorMessage: 'Backup file does not exist.',
        );
      }

      final fileSize = await candidateFile.length();
      if (fileSize < 100) {
        return const BackupValidationResult(
          isValid: false,
          errorMessage: 'Selected file is not a valid SQLite database (file is empty or too small).',
        );
      }

      // Check SQLite header magic bytes
      final raf = await candidateFile.open(mode: FileMode.read);
      final headerBytes = await raf.read(16);
      await raf.close();

      final magic = utf8.decode(headerBytes.sublist(0, 15), allowMalformed: true);
      if (magic != 'SQLite format 3' || headerBytes[15] != 0) {
        return const BackupValidationResult(
          isValid: false,
          errorMessage: 'Selected file is not a valid SQLite database.',
        );
      }

      // Open read-only to inspect schema and user_version
      final db = await databaseFactory.openDatabase(
        candidateFile.path,
        options: OpenDatabaseOptions(readOnly: true),
      );
      try {
        final quickCheck = await db.rawQuery('PRAGMA quick_check');
        final isOk = quickCheck.isNotEmpty && quickCheck.first.values.first == 'ok';
        if (!isOk) {
          return const BackupValidationResult(
            isValid: false,
            errorMessage: 'Database integrity check failed.',
          );
        }

        final versionResult = await db.rawQuery('PRAGMA user_version');
        final int userVersion = Sqflite.firstIntValue(versionResult) ?? 0;

        if (userVersion > AppDatabase.schemaVersion) {
          return BackupValidationResult(
            isValid: false,
            schemaVersion: userVersion,
            errorMessage: 'Backup was created by a newer version of Money Manager (v$userVersion). Current app supports up to v${AppDatabase.schemaVersion}. Please update the application.',
          );
        }

        final tablesResult = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
        final tableNames = tablesResult.map((r) => r['name'] as String).toSet();

        if (!tableNames.contains('account') || !tableNames.contains('transaction_log') || !tableNames.contains('category')) {
          return const BackupValidationResult(
            isValid: false,
            errorMessage: 'Database is missing essential financial tables (account, transaction_log, category).',
          );
        }

        final accountCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM account')) ?? 0;
        final txCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM transaction_log')) ?? 0;

        return BackupValidationResult(
          isValid: true,
          schemaVersion: userVersion,
          accountCount: accountCount,
          transactionCount: txCount,
        );
      } finally {
        await db.close();
      }
    } catch (e) {
      return BackupValidationResult(
        isValid: false,
        errorMessage: 'Validation failed: $e',
      );
    }
  }

  /// Full 5-step restoration pipeline.
  Future<RestoreResult> restoreFromFile(File backupFile, {String format = 'sqlite'}) async {
    if (format != 'sqlite') {
      try {
        final content = await backupFile.readAsString();
        if (format == 'json') {
          await importDataFromJson(content);
        } else if (format == 'csv') {
          await importDataFromCsv(content);
        } else {
          throw FormatException('Unsupported backup format: $format.');
        }
        return const RestoreResult(
          success: true,
          message: 'Data restored successfully.',
        );
      } catch (e) {
        return RestoreResult(
          success: false,
          message: 'Restore failed.',
          errorMessage: '$e',
        );
      }
    }

    final dbFolder = await getApplicationDocumentsDirectory();
    final localDbPath = p.join(dbFolder.path, 'money_manager.db');
    final activeDbFile = File(localDbPath);
    final scratch = await dbFolder.createTemp('restore_');
    final safetyBackupFile = File(p.join(scratch.path, 'previous.db'));
    final stageDbFile = File(p.join(scratch.path, 'staged.db'));
    var retainRecoveryCopy = false;
    Database? staged;

    try {
      // -------------------------------------------------------------
      // Step 1: Validate the backup
      // -------------------------------------------------------------
      final validation = await validateBackupFile(backupFile);
      if (!validation.isValid) {
        return RestoreResult(
          success: false,
          message: 'Validation failed',
          errorMessage: validation.errorMessage ?? 'Invalid database file.',
        );
      }

      await backupFile.copy(stageDbFile.path);

      final stageDb = staged = await openDatabase(
        stageDbFile.path,
        version: AppDatabase.schemaVersion,
        onUpgrade: AppDatabase.instance.upgradeDatabase,
      );

      final quickCheck = await stageDb.rawQuery('PRAGMA quick_check');
      final isOk = quickCheck.isNotEmpty && quickCheck.first.values.first == 'ok';
      if (!isOk) {
        throw Exception('Integrity check failed on staged migrated database.');
      }

      // Backups carry financial data. Device-local PIN hashes and their
      // secure-storage salts must stay paired on the device doing the restore.
      final deviceDb = await AppDatabase.instance.database;
      final deviceProfiles = await deviceDb.query('user_profile');
      await stageDb.transaction((txn) async {
        final sourceProfiles = await txn.query('user_profile');
        final diagnosticTable = await txn.query(
          'sqlite_master',
          where: "type = 'table' AND name = 'diagnostic_profile'",
        );
        if (diagnosticTable.isNotEmpty) {
          final diagnostics = _restoreDiagnosticOwners(
            await txn.query('diagnostic_profile'),
            sourceProfiles,
            deviceProfiles,
          );
          for (final row in diagnostics) {
            await txn.update(
              'diagnostic_profile',
              {'user_profile_id': row['user_profile_id']},
              where: 'id = ?',
              whereArgs: [row['id']],
            );
          }
        }
        await txn.delete('user_profile');
        for (final profile in deviceProfiles) {
          await txn.insert('user_profile', profile);
        }
      });

      // Reconcile and audit all balances
      await AppDatabase.instance.recalculateAllBalances(stageDb);

      final accounts = await stageDb.query('account');
      final txCount = Sqflite.firstIntValue(await stageDb.rawQuery('SELECT COUNT(*) FROM transaction_log')) ?? 0;

      final balanceSummaries = accounts.map((acc) {
        final name = acc['name'] as String;
        final balance = (acc['balance'] as num).toDouble();
        return '$name: ₹$balance';
      }).toList();

      final stageCheckpoint = await stageDb.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
      if (stageCheckpoint.single['busy'] != 0) {
        throw StateError('Could not checkpoint the restored database.');
      }
      await stageDb.close();
      staged = null;

      await AppDatabase.instance.replaceDatabaseFile(() async {
        final wal = File('$localDbPath-wal');
        if (await wal.exists() && await wal.length() > 0) {
          throw StateError('The active database still has uncommitted WAL data.');
        }
        if (await wal.exists()) await wal.delete();
        final shm = File('$localDbPath-shm');
        if (await shm.exists()) await shm.delete();

        await activeDbFile.copy(safetyBackupFile.path);
        // Both files are on the same volume. Android replaces the file atomically.
        await stageDbFile.rename(localDbPath);
        try {
          final restored = await openDatabase(localDbPath, readOnly: true);
          try {
            if (!await AppDatabase.instance.verifyIntegrity(restored)) {
              throw StateError('The installed database failed its integrity check.');
            }
          } finally {
            await restored.close();
          }
        } catch (_) {
          retainRecoveryCopy = true;
          await safetyBackupFile.rename(localDbPath);
          retainRecoveryCopy = false;
          rethrow;
        }
      });

      return RestoreResult(
        success: true,
        message: 'Database restored and balances reconciled successfully.',
        restoredAccounts: accounts.length,
        restoredTransactions: txCount,
        balanceSummaries: balanceSummaries,
      );
    } catch (e, stack) {
      AppLogger.e('Error during database restore', error: e, stackTrace: stack, tag: 'BackupService');

      return RestoreResult(
        success: false,
        message: 'Restore operation failed.',
        errorMessage: retainRecoveryCopy
            ? '$e. Recovery database saved at ${safetyBackupFile.path}.'
            : '$e',
      );
    } finally {
      try {
        await staged?.close();
        if (!retainRecoveryCopy) await scratch.delete(recursive: true);
      } catch (e) {
        AppLogger.w('Could not clean up restore files', error: e, tag: 'BackupService');
      }
    }
  }

  Future<RestoreResult> restoreFromLocalWithResult(String format) async {
    try {
      final pickerResult = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );

      if (pickerResult == null || pickerResult.files.isEmpty) {
        return const RestoreResult(
          success: false,
          message: 'Restore cancelled',
          errorMessage: 'No file was selected.',
        );
      }

      final file = pickerResult.files.single;
      final tempDir = await getTemporaryDirectory();
      final candidatePath = p.join(tempDir.path, 'picked_backup_${file.name}');
      final candidateFile = File(candidatePath);

      if (file.bytes != null) {
        await candidateFile.writeAsBytes(file.bytes!);
      } else if (file.path != null) {
        await File(file.path!).copy(candidateFile.path);
      } else {
        return const RestoreResult(
          success: false,
          message: 'Restore failed',
          errorMessage: 'Unable to read selected file.',
        );
      }

      return await restoreFromFile(candidateFile, format: format);
    } catch (e) {
      return RestoreResult(
        success: false,
        message: 'Restore error',
        errorMessage: '$e',
      );
    }
  }

  Future<bool> restoreFromLocal(String format) async {
    final result = await restoreFromLocalWithResult(format);
    return result.success;
  }

  // --- High-Level Google Drive Backup & Restore Entry Points ---

  Future<bool> backupToGoogleDrive(String format) async {
    try {
      final dbFolder = await getApplicationDocumentsDirectory();
      final tempDir = await getTemporaryDirectory();
      File localFile;
      String driveFileName;

      if (format == 'sqlite') {
        final localDbPath = p.join(dbFolder.path, 'money_manager.db');
        localFile = File(localDbPath);
        driveFileName = 'money_manager_backup.db';

        // Checkpoint before upload
        await AppDatabase.instance.checkpoint();
        final isValid = await AppDatabase.instance.verifyIntegrity();
        if (!isValid) return false;
      } else if (format == 'json') {
        final jsonStr = await exportDataToJson();
        driveFileName = 'money_manager_backup.json';
        localFile = File(p.join(tempDir.path, driveFileName));
        await localFile.writeAsString(jsonStr);
      } else if (format == 'csv') {
        final csvStr = await exportDataToCsv();
        driveFileName = 'money_manager_backup.csv';
        localFile = File(p.join(tempDir.path, driveFileName));
        await localFile.writeAsString(csvStr);
      } else {
        return false;
      }

      return await backupFileToDrive(localFile, driveFileName);
    } catch (_) {
      return false;
    }
  }

  Future<RestoreResult> restoreFromGoogleDriveWithResult(String format) async {
    try {
      final tempDir = await getTemporaryDirectory();
      
      if (format == 'sqlite') {
        final candidateFile = File(p.join(tempDir.path, 'downloaded_drive_backup.db'));
        final success = await restoreFileFromDrive('money_manager_backup.db', candidateFile);
        if (!success) {
          return const RestoreResult(
            success: false,
            message: 'Restore failed',
            errorMessage: 'Could not download backup from Google Drive.',
          );
        }
        return await restoreFromFile(candidateFile, format: 'sqlite');
      } else if (format == 'json') {
        final tempFile = File(p.join(tempDir.path, 'money_manager_backup.json'));
        final success = await restoreFileFromDrive('money_manager_backup.json', tempFile);
        if (!success) {
          return const RestoreResult(
            success: false,
            message: 'Restore failed',
            errorMessage: 'Could not download JSON backup from Google Drive.',
          );
        }
        return await restoreFromFile(tempFile, format: 'json');
      } else if (format == 'csv') {
        final tempFile = File(p.join(tempDir.path, 'money_manager_backup.csv'));
        final success = await restoreFileFromDrive('money_manager_backup.csv', tempFile);
        if (!success) {
          return const RestoreResult(
            success: false,
            message: 'Restore failed',
            errorMessage: 'Could not download CSV backup from Google Drive.',
          );
        }
        return await restoreFromFile(tempFile, format: 'csv');
      }
      return const RestoreResult(
        success: false,
        message: 'Invalid format',
        errorMessage: 'Unsupported backup format.',
      );
    } catch (e) {
      return RestoreResult(
        success: false,
        message: 'Restore error',
        errorMessage: '$e',
      );
    }
  }

  Future<bool> restoreFromGoogleDrive(String format) async {
    final result = await restoreFromGoogleDriveWithResult(format);
    return result.success;
  }
}
