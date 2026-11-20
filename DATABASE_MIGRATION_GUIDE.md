# Database Migration Guide — Version 13

## 1. Overview & Purpose
Database migration v13 transitions the Money Manager application from IEEE 754 floating-point monetary storage to deterministic integer minor-unit storage (`paise` for INR, `cents` for USD/EUR, `sats` for BTC). This ensures mathematical determinism, eliminates compounding rounding errors, and establishes support for account archiving, credit card billing cycles, budget exclusion toggles, and automated monthly report auditing.

---

## 2. Schema Changes

### 2.1 Added Columns

| Table | Column | Type | Default | Purpose |
|---|---|---|---|---|
| `account` | `balance_minor` | `INTEGER` | `0` | Exact integer balance in minor units |
| `account` | `limit_amount_minor` | `INTEGER` | `NULL` | Credit card limit in minor units |
| `account` | `is_archived` | `INTEGER` | `0` | Soft delete / archive flag (0=active, 1=archived) |
| `account` | `archived_at` | `TEXT` | `NULL` | ISO 8601 timestamp of archival |
| `account` | `billing_cycle_start_day` | `INTEGER` | `NULL` | Billing cycle start day (1–31) |
| `account` | `statement_due_day` | `INTEGER` | `NULL` | Statement payment due day (1–31) |
| `account` | `minimum_due` | `REAL` | `NULL` | Minimum amount due (float backward compatibility) |
| `account` | `minimum_due_minor` | `INTEGER` | `NULL` | Minimum amount due in minor units |
| `transaction_log` | `amount_minor` | `INTEGER` | `0` | Exact transaction amount in minor units |
| `transaction_log` | `is_budget_included` | `INTEGER` | `1` | Budget deduction eligibility flag (1=yes, 0=no) |
| `budget` | `limit_amount_minor` | `INTEGER` | `0` | Monthly budget limit in minor units |
| `savings_goal` | `target_amount_minor` | `INTEGER` | `0` | Goal target amount in minor units |
| `savings_goal` | `current_amount_minor` | `INTEGER` | `0` | Goal current accumulated amount in minor units |
| `debt_loan` | `balance_minor` | `INTEGER` | `0` | Outstanding debt balance in minor units |
| `debt_loan` | `original_amount_minor` | `INTEGER` | `0` | Original debt principal in minor units |
| `debt_loan` | `monthly_payment_minor` | `INTEGER` | `0` | Minimum monthly installment in minor units |
| `category` | `spending_limit_minor` | `INTEGER` | `NULL` | Category spending cap in minor units |
| `transaction_template` | `amount_minor` | `INTEGER` | `0` | Quick template default amount in minor units |
| `planning_meta` | `estimated_income_minor` | `INTEGER` | `0` | Estimated monthly income in minor units |

### 2.2 New Tables

#### `migration_audit`
```sql
CREATE TABLE IF NOT EXISTS migration_audit (
  version INTEGER PRIMARY KEY,
  migrated_at TEXT NOT NULL,
  record_counts TEXT NOT NULL,
  validation_result TEXT NOT NULL
);
```

#### `report_history`
```sql
CREATE TABLE IF NOT EXISTS report_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  report_type TEXT NOT NULL,
  reporting_month TEXT NOT NULL,
  generated_at TEXT NOT NULL,
  file_path TEXT NOT NULL,
  file_size_bytes INTEGER NOT NULL,
  checksum TEXT NOT NULL,
  is_auto_generated INTEGER NOT NULL DEFAULT 1
);
```

---

## 3. Migration Procedure (`_migrateToV13`)

1. **Pre-Migration Audit**: Queries and records row counts for `account`, `transaction_log`, and `budget`.
2. **Column Alteration**: Safely applies `ALTER TABLE ... ADD COLUMN` statements wrapped in individual try-catch blocks to prevent aborts if columns already exist.
3. **Data Conversion**:
   - Converts existing floating-point balances to minor units using `CAST(ROUND(val * 100) AS INTEGER)`.
   - Initializes `is_archived = 0` and `is_budget_included = 1` for all legacy records.
4. **Deterministic Balance Recalculation**:
   - Invokes `recalculateAllBalances(db)` which sums all historical `income` transactions, subtracts all `expense` transactions, and debits/credits `transfer` transactions in integer minor units.
   - Synchronizes `balance_minor` and `balance = balance_minor / 100.0`.
5. **Post-Migration Audit**: Verifies record counts match pre-migration counts exactly. Writes audit entry into `migration_audit`.
6. **Recovery & Rollback Strategy**: If an unhandled SQLite exception occurs during migration, the migration fails gracefully, leaving legacy `REAL` columns intact. The app maintains backward compatibility by reading `balance` or `amount` when minor units are 0 or unpopulated.

---

## 4. Verification & Testing Results

- Automated test file: `test/unit/migration_v13_test.dart`.
- Upgrade simulation verified from schema v12 to v13.
- Pre-existing accounts and transactions preserved with 100% record parity.
- Round-trip floating point amounts (e.g. 19.99, 1250.50) successfully converted without fraction truncation.
