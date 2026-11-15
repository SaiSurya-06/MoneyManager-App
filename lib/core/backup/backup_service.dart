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

  Future<void> importDataFromJson(String jsonStr) async {
    final Map<String, dynamic> data = jsonDecode(jsonStr);
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

      for (var table in tables) {
        if (data.containsKey(table)) {
          try {
            await txn.delete(table);
            final List<dynamic> rows = data[table];
            for (var row in rows) {
              if (row is Map<String, dynamic>) {
                await txn.insert(table, row);
              }
            }
          } catch (_) {}
        }
      }
    });

    // Reconcile and recalculate balances
    await AppDatabase.instance.recalculateAllBalances(db);
  }

  Future<String> exportDataToCsv() async {
    final db = await AppDatabase.instance.database;
    final List<List<dynamic>> csvData = [
      ['Date', 'Title', 'Amount', 'Type', 'Category', 'Account', 'Note', 'Recurrence', 'Recurrence End Date', 'Is Private']
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
        isPrivate
      ]);
    }

    return const ListToCsvConverter().convert(csvData);
  }

  Future<void> importDataFromCsv(String csvStr) async {
    final List<List<dynamic>> rows = const CsvToListConverter().convert(csvStr);
    if (rows.isEmpty) return;

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

    final categoryList = await db.query('category');
    final Map<String, int> categoryNameToId = {
      for (var row in categoryList) (row['name'] as String).toLowerCase().trim(): row['id'] as int
    };
    int otherCategoryId = categoryNameToId['other'] ?? CategoryDao.otherCategoryId;

    final accountList = await db.query('account');
    final Map<String, int> accountNameToId = {
      for (var row in accountList) (row['name'] as String).toLowerCase().trim(): row['id'] as int
    };

    await db.transaction((txn) async {
      await txn.delete('transaction_log');
      await txn.rawUpdate('UPDATE account SET balance = 0.0, balance_minor = 0');

      for (int i = headerRowIndex + 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.length < 6) continue;

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

        if (title.isEmpty || amount <= 0 || !['income', 'expense', 'transfer'].contains(type)) {
          continue;
        }

        int categoryId = categoryNameToId[categoryName.toLowerCase()] ?? otherCategoryId;

        int? accountId = accountNameToId[accountName.toLowerCase()];
        if (accountId == null) {
          accountId = await txn.insert('account', {
            'name': accountName,
            'type': 'Bank',
            'balance': 0.0,
            'balance_minor': 0,
            'initial_balance': 0.0,
            'initial_balance_minor': 0,
            'icon': 'account_balance',
            'color': '1E88E5',
            'is_shared': 1,
            'created_at': DateTime.now().toIso8601String(),
          });
          accountNameToId[accountName.toLowerCase()] = accountId;
        }

        DateTime date;
        try {
          date = DateTime.parse(dateStr);
        } catch (_) {
          date = DateTime.now();
        }

        DateTime? recurrenceEndDate;
        if (recurrence != 'none' && recEndStr.isNotEmpty) {
          try {
            recurrenceEndDate = DateTime.parse(recEndStr);
          } catch (_) {}
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
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    });

    await AppDatabase.instance.recalculateAllBalances(db);
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
          'db_schema_version': '14',
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
        options: const OpenDatabaseOptions(readOnly: true),
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

        if (userVersion > 14) {
          return BackupValidationResult(
            isValid: false,
            schemaVersion: userVersion,
            errorMessage: 'Backup was created by a newer version of Money Manager (v$userVersion). Current app supports up to v14. Please update the application.',
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
    final tempDir = await getTemporaryDirectory();

    final localDbPath = p.join(dbFolder.path, 'money_manager.db');
    final activeDbFile = File(localDbPath);
    final safetyBackupFile = File(p.join(tempDir.path, 'money_manager_pre_restore_safety_backup.db'));
    final stageDbFile = File(p.join(tempDir.path, 'temp_restore_stage_${DateTime.now().millisecondsSinceEpoch}.db'));

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

      // -------------------------------------------------------------
      // Step 2: Create a safety backup of active database
      // -------------------------------------------------------------
      if (await activeDbFile.exists()) {
        try {
          await AppDatabase.instance.checkpoint();
        } catch (_) {}
        await activeDbFile.copy(safetyBackupFile.path);

        final activeWalFile = File('$localDbPath-wal');
        if (await activeWalFile.exists()) {
          await activeWalFile.copy('${safetyBackupFile.path}-wal');
        }
        final activeShmFile = File('$localDbPath-shm');
        if (await activeShmFile.exists()) {
          await activeShmFile.copy('${safetyBackupFile.path}-shm');
        }
      }

      // -------------------------------------------------------------
      // Step 3: Restore into temporary database & run migrations & reconcile balances
      // -------------------------------------------------------------
      if (await stageDbFile.exists()) await stageDbFile.delete();
      final stageWal = File('${stageDbFile.path}-wal');
      if (await stageWal.exists()) await stageWal.delete();
      final stageShm = File('${stageDbFile.path}-shm');
      if (await stageShm.exists()) await stageShm.delete();

      await backupFile.copy(stageDbFile.path);

      final stageDb = await openDatabase(
        stageDbFile.path,
        version: 14,
        onUpgrade: AppDatabase.instance.upgradeDatabase,
      );

      final quickCheck = await stageDb.rawQuery('PRAGMA quick_check');
      final isOk = quickCheck.isNotEmpty && quickCheck.first.values.first == 'ok';
      if (!isOk) {
        await stageDb.close();
        throw Exception('Integrity check failed on staged migrated database.');
      }

      // Reconcile and audit all balances
      await AppDatabase.instance.recalculateAllBalances(stageDb);

      final accounts = await stageDb.query('account');
      final txCount = Sqflite.firstIntValue(await stageDb.rawQuery('SELECT COUNT(*) FROM transaction_log')) ?? 0;

      final balanceSummaries = accounts.map((acc) {
        final name = acc['name'] as String;
        final balance = (acc['balance'] as num).toDouble();
        return '$name: ₹$balance';
      }).toList();

      await stageDb.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
      await stageDb.close();

      // -------------------------------------------------------------
      // Step 4: Replace active database safely
      // -------------------------------------------------------------
      await AppDatabase.instance.close();

      // Delete active WAL and SHM files to prevent corruption from leftover frames
      final activeWal = File('$localDbPath-wal');
      if (await activeWal.exists()) await activeWal.delete();
      final activeShm = File('$localDbPath-shm');
      if (await activeShm.exists()) await activeShm.delete();

      // Copy stage file over active DB
      await stageDbFile.copy(localDbPath);
      await stageDbFile.delete();

      // Re-open active database
      await AppDatabase.instance.database;

      // Clean up safety backup upon verified success
      if (await safetyBackupFile.exists()) {
        try { await safetyBackupFile.delete(); } catch (_) {}
      }

      return RestoreResult(
        success: true,
        message: 'Database restored and balances reconciled successfully.',
        restoredAccounts: accounts.length,
        restoredTransactions: txCount,
        balanceSummaries: balanceSummaries,
      );
    } catch (e, stack) {
      AppLogger.e('Error during database restore', error: e, stackTrace: stack, tag: 'BackupService');

      // Rollback to safety backup if active DB was modified
      if (await safetyBackupFile.exists()) {
        try {
          await AppDatabase.instance.close();
          await safetyBackupFile.copy(localDbPath);
          final safetyWal = File('${safetyBackupFile.path}-wal');
          if (await safetyWal.exists()) {
            await safetyWal.copy('$localDbPath-wal');
          }
          final safetyShm = File('${safetyBackupFile.path}-shm');
          if (await safetyShm.exists()) {
            await safetyShm.copy('$localDbPath-shm');
          }
          await AppDatabase.instance.database;
        } catch (_) {}
      }

      return RestoreResult(
        success: false,
        message: 'Restore operation failed. Active database preserved.',
        errorMessage: '$e',
      );
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
