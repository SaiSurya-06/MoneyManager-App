# Money Manager — Baseline Architecture & Codebase Investigation Report

## 1. Executive Summary
This baseline report documents the initial state of the Money Manager application prior to implementing production-grade features F01 through F07. All findings are derived directly from the source code, SQLite database migrations, models, DAOs, state providers, and CI/CD pipelines in the repository.

---

## 2. Technical Stack & Architecture

- **Framework**: Flutter 3.x (Dart 3.x)
- **State Management**: Riverpod (`StateNotifierProvider`, `Notifier`)
- **Navigation**: `GoRouter` v14.2.0 with declarative routes and `ShellRoute`
- **Local Database**: SQLite via `sqflite` v2.3.3+1 and `sqflite_common_ffi`
- **Data Modeling**: `freezed` & `json_serializable`
- **Charting**: `fl_chart` v0.68.0
- **Security & Storage**: `flutter_secure_storage`, `local_auth`, AES/RSA encryption (`pointycastle`, `encrypt`)
- **Reporting & Export**: `pdf` v3.10.8, `printing` v5.11.1, `csv` v6.0.0, `excel` v4.0.6
- **Notifications**: `flutter_local_notifications` v17.1.2 with `timezone`
- **CI/CD**: GitHub Actions (`.github/workflows/flutter_ci.yml`) on `ubuntu-latest` building single release APK signed with keystore.

---

## 3. Database Schema Baseline (v12)

The database schema currently operates at **Version 12** (`AppDatabase._initDB` with `version: 12`).

### 16 Core Tables Identified:
1. `user_profile`: ID, name, preferred_currency, pin_hash, biometric_enabled, theme_preference, reminder_enabled, reminder_time.
2. `account`: ID, name, type ('Bank', 'Cash', 'Credit Card', 'Savings', 'Investment'), balance (REAL), icon, color, is_shared, limit_amount (REAL), created_at.
3. `category`: ID, name, icon, color, is_default, type, parent_id, spending_limit (REAL), dark_color.
4. `transaction_log`: ID, account_id (FK account ON DELETE CASCADE), category_id (FK category ON DELETE CASCADE), title, amount (REAL), type ('income', 'expense', 'transfer'), date, note, recurrence, recurrence_end_date, is_private, tags, parent_id, transfer_to_account_id, created_at, subcategory_id (FK category ON DELETE SET NULL).
5. `budget`: ID, category_id (FK category ON DELETE CASCADE), month ('YYYY-MM'), limit_amount (REAL), recurrence, group_name.
6. `partner_snapshot`: ID, partner_name, partner_display_color, encoded_data, imported_at, partner_key.
7. `savings_goal`: ID, name, target_amount (REAL), current_amount (REAL), target_date, color, icon, created_at.
8. `debt_loan`: ID, name, type, balance (REAL), original_amount (REAL), interest_rate (REAL), monthly_payment (REAL), start_date, created_at.
9. `filter_preset`: ID, name, filters_json.
10. `transaction_template`: ID, title, amount (REAL), type, category_id, account_id.
11. `health_score_history`: ID, date, score (REAL).
12. `sync_queue`: ID, action, table_name, record_id, record_data, created_at.
13. `diagnostic_profile`: ID, user_profile_id, created_at, updated_at, current_act, current_section, completed, profile_json.
14. `intelligence_report_history`: ID, month, report_json, updated_at.
15. `weekly_checkins`: ID, week_end_date, mood, reason_tags, notes, created_at.
16. `planning_meta`: ID, month, estimated_income (REAL), strategy, needs_pct, wants_pct, savings_pct, investments_pct, emergency_pct, is_completed, updated_at.

---

## 4. Analysis of Requested Features (F01–F07)

### F01 — Financial Amount Precision (CRITICAL)
- **Current State**: Monetary columns (`account.balance`, `transaction_log.amount`, `budget.limit_amount`, `savings_goal.target_amount`, `savings_goal.current_amount`, `debt_loan.balance`, `debt_loan.original_amount`, `debt_loan.monthly_payment`, `category.spending_limit`, `transaction_template.amount`, `planning_meta.estimated_income`) use SQLite `REAL`. Dart models use `double` with ad-hoc rounding `roundToDouble() / 100.0`.
- **Target Architecture**:
  - Centralized `Money` / `Currency` utility storing integer minor units (paise/cents, e.g. 1 INR = 100 paise; JPY = 1 minor unit).
  - Explicit currency configuration based on user profile.
  - Safe database migration (v13) converting existing `REAL` values to `INTEGER` minor units with documented rounding.
  - Recalculation verification comparing pre- and post-migration totals.

### F02 — Account Archiving and Safe Deletion (CRITICAL)
- **Current State**: `account` table has no archive state. `transaction_log` has `FOREIGN KEY (account_id) REFERENCES account(id) ON DELETE CASCADE`. Deleting an account silently cascades and deletes all historical transactions!
- **Target Architecture**:
  - Add `is_archived INTEGER NOT NULL DEFAULT 0`, `archived_at TEXT` to `account`.
  - Prevent deletion of accounts containing transactions.
  - Filter archived accounts from default transaction creation dropdowns while preserving visibility in historical logs and reports.
  - Provide restore capability.

### F03 — Credit Card Management (HIGH)
- **Current State**: Basic account type `'Credit Card'` exists with `limit_amount`. Outstanding balance is negative in `balance`. No billing cycle tracking, statement generation date, due date, or structured payment history.
- **Target Architecture**:
  - Add credit card metadata: `credit_limit`, `billing_cycle_start_day`, `statement_due_day`, `minimum_due`.
  - Calculated: `available_credit = credit_limit - outstanding_balance`.
  - Payment settlement workflow: bill payments reduce credit card liability and debit source account without double counting expenses in budget or analytics.

### F04 — Show Account Name in Ledger Quick Templates (HIGH)
- **Current State**: Quick templates row in `TransactionsPage` displays template title and amount in small chips. It does not display the associated account name, category, or transaction type. Clicking immediately inserts a transaction instead of allowing pre-filled editing.
- **Target Architecture**:
  - Update quick template cards to clearly show: Title, Type badge, Amount, Category, and Account name (resolved from `account_id`).
  - Tapping opens `TransactionForm` prepopulated with template values.

### F05 — Money Map Daily Spending Calendar with Rollover (HIGH)
- **Current State**: Money Map has 4 tabs: Plan, Track, Review, Adjust. `_calculateRollover` in `budgets_provider.dart` is an un-implemented stub returning `0.0`. No calendar view showing daily allowances and dynamic deficit/surplus rollovers.
- **Target Architecture**:
  - Daily spending allowance calculation: `(Monthly Budget / Days In Month) + Previous Day Rollover`.
  - Daily calendar widget integrated into Money Map showing daily budget, eligible actual spending, deficit/surplus, and visual color codes (under budget, at budget, overspent, future).
  - Day details view showing contributing transactions.

### F06 — Yes/No Budget Deduction During Transaction Entry (HIGH)
- **Current State**: All expense transactions automatically deduct from budget in `BudgetsNotifier._calculateSpendings()`. Users cannot designate an expense as non-budgeted.
- **Target Architecture**:
  - Add `is_budget_included INTEGER NOT NULL DEFAULT 1` to `transaction_log`.
  - Add clean UI toggle `[ YES ] [ NO ]` to `TransactionForm`.
  - Budget calculations filter `WHERE type = 'expense' AND is_budget_included = 1`. Total spending / analytics still tracks the financial outflow regardless.

### F07 — Automatic Monthly PDF Reports (HIGH)
- **Current State**: `PdfReportHelper` provides single manual summary PDF generation. No background scheduling or monthly generation of separate (1) Income & Expense Analysis and (2) Budget Performance Reports.
- **Target Architecture**:
  - Two distinct, auditable PDF reports:
    1. Monthly Income & Expense Analysis (`Money_Manager_Income_Expense_Report_YYYY-MM.pdf`)
    2. Monthly Budget Performance Report (`Money_Manager_Budget_Report_YYYY-MM.pdf`)
  - Deterministic analytics, category breakdown, daily budget rollover table.
  - Idempotent generation service with metadata tracking table `report_history`.
  - Android background/app-resumption scheduling with recovery for missed executions.

---

## 5. Google Sheets Development Audit
- **Spreadsheet Created**: `Money Manager — Development & Release Audit Log`
- **Spreadsheet ID**: `1wWmdowakQXlznb3O-vODKsY8wMoNjEX-wWLYAu2bhlw`
- **Worksheets Verified**:
  1. `MASTER CHANGE LOG`
  2. `PROMPT HISTORY`
  3. `BUG & ISSUE TRACKER`
  4. `TEST EXECUTION LOG`
  5. `RELEASE & DEPLOYMENT LOG`
- **Initial Logs Written**: P-001 (Master Prompt), LOG-001 (Baseline Audit).

---

## 6. Execution Plan & Next Steps
We will proceed strictly in sequence:
1. **F01**: Financial Amount Precision (`Money` utility, schema v13 migration, model updates).
2. **F02**: Account Archiving and Safe Deletion.
3. **F03**: Credit Card Management & Payment Settlement.
4. **F04**: Show Account Name in Quick Templates.
5. **F05**: Money Map Daily Spending Calendar with Rollover.
6. **F06**: Yes/No Budget Deduction in Transactions.
7. **F07**: Automated Monthly PDF Reports (Income & Expense + Budget Performance).
8. Regression & End-to-End Integration Tests.
9. Documentation, Git Commits & Push, CI/CD Verification.
