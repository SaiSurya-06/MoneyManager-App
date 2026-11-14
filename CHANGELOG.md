# Money Manager — Production Changelog

All notable changes to the Money Manager application are documented in this file.
The project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [2.0.0-prod] - 2026-11-14

### CRITICAL: Financial Precision & Database Migration (F01)
- **Added**: Centralized `Money` utility class (`lib/core/utils/money.dart`) implementing exact integer minor-unit financial arithmetic (paise/cents/sats) to eliminate IEEE 754 floating-point inaccuracies.
- **Added**: Support for ISO currency exponents (e.g. JPY=0, USD/INR=2, BHD=3), deterministic half-up rounding, percentage calculations, Martin Fowler remainder-preserving allocation, and exchange rate conversion.
- **Added**: Database Schema Migration v13 (`lib/core/database/database.dart`) with `balance_minor`, `amount_minor`, `limit_amount_minor`, `target_amount_minor`, `spending_limit_minor`, `is_archived`, `archived_at`, `billing_cycle_start_day`, `statement_due_day`, `minimum_due`, `minimum_due_minor`, `is_budget_included`.
- **Added**: `migration_audit` table verifying record count parity before and after schema upgrades.
- **Added**: Pre- and post-migration balance validation routines ensuring zero data loss.
- **Updated**: Models (`Account`, `Transaction`, `Budget`, `SavingsGoal`, `DebtLoan`, `TransactionTemplate`) with exact minor-unit getters and backward-compatible mapping.
- **Updated**: `CurrencyFormatter` to format directly from integer minor units.

### CRITICAL: Account Archiving & Safe Deletion (F02)
- **Added**: Safe account lifecycle management (`is_archived: 0 | 1`, `archived_at`).
- **Added**: Guarded deletion in `AccountDao`: accounts with existing transactions cannot be deleted; attempting deletion throws `StateError` and prompts the user to archive instead.
- **Added**: Active vs Archived account filter chips and banners in `AccountsPage` (`lib/pages/accounts/accounts_page.dart`).
- **Added**: Dedicated `[ARCHIVED]` status badge on `AccountCard`.
- **Added**: Archive and restore toggle buttons with transaction safety warnings in `AccountForm`.

### HIGH: Credit Card Management & Non-Duplicate Accounting (F03)
- **Added**: Full Credit Card account attributes: `limitAmount` / `limitAmountMinor`, `availableCredit` / `availableCreditMinor`, `billingCycleStartDay` (1–31), `statementDueDay` (1–31), and `minimumDue` / `minimumDueMinor`.
- **Added**: Credit limit, available credit gauge, billing cycle start day, due day, and minimum due form fields in `AccountForm`.
- **Added**: Two-tab ledger view in `AccountTransactionsPage`: `All Activity` vs `Payment History`.
- **Added**: Non-duplicate settlement accounting: credit card bill payments use `is_budget_included = 0` (or `type == 'transfer'`), extinguishing credit card liability without duplicating monthly budget expense deductions.

### HIGH: Ledger Quick Templates with Account Name (F04)
- **Updated**: Quick-Add Template cards in Ledger (`lib/pages/transactions/transactions_page.dart`) displaying template title, formatted amount, category with icon and color, transaction type badge, and associated account name.
- **Added**: Two-step tap workflow: tapping a template opens `TransactionForm` pre-filled with title, amount, category, account, type, and current timestamp for user verification before persisting.
- **Added**: Dedicated `Quick Log` action for one-tap entry with instant confirmation toast showing account name and amount.
- **Added**: Graceful fallback: warning banner and prompt if the associated account has been archived or deleted.

### HIGH: Money Map Daily Spending Calendar with Rollover (F05)
- **Added**: `DailySpendingCalculator` engine (`lib/core/analytics/daily_budget_calculator.dart`) computing base daily allowances, chronological rollover accumulation/reduction, and daily spending using exact minor units.
- **Added**: Remainder distribution algorithm ensuring sum of daily allowances exactly equals monthly budget.
- **Added**: Interactive `DailySpendingCalendar` widget (`lib/pages/budgets/widgets/daily_spending_calendar.dart`) with Month selector, Category filter chips, Monthly Summary card, 7-column Calendar Grid, and Agenda List view toggle.
- **Added**: Day detail bottom sheet displaying Base Allowance, Carried In, Total Available, Eligible Spent, Carried Out, and associated transaction logs.
- **Added**: Integration into Money Map tab (`BudgetsPage`) and `TrackTab`.

### HIGH: Yes/No Budget Deduction During Transaction Entry (F06)
- **Added**: `is_budget_included` toggle ("Deduct from Budget") in `TransactionForm` with subtitle explanation, default `true`, visible exclusively for expense transactions.
- **Updated**: `BudgetsNotifier` SQL queries selecting only expenses where `COALESCE(is_budget_included, 1) = 1` for category budgets, thresholds, and rollovers.
- **Added**: `[NO BUDGET]` visual badge in `TransactionListItem` (`lib/pages/transactions/transaction_list_item.dart`).
- **Ensured**: Excluded expenses remain fully tracked in account balances, total financial spending, net income, and cash flow.

### HIGH: Automated Monthly PDF Reports (F07)
- **Added**: `MonthlyPdfReportService` (`lib/core/services/monthly_pdf_report_service.dart`) generating exactly two A4 PDF documents on the 1st of every month:
  1. `Money_Manager_Income_Expense_Report_YYYY-MM.pdf` (Executive Summary, Category/Account Income Analysis, Category/Top 5 Expense Analysis, Account Summary, Observations).
  2. `Money_Manager_Budget_Report_YYYY-MM.pdf` (Budget Summary, Category Adherence Table, Daily Rollover Analysis, Adherence Recommendations).
- **Added**: SQLite tracking table `report_history` recording report type, month, file path, size, SHA-256 checksum, and auto vs manual status.
- **Added**: Background catch-up check on app launch generating missed previous-month reports.
- **Added**: Notification alert (`showMonthlyReportAlert`) upon report generation.
- **Added**: `MonthlyReportsPage` (`lib/pages/more/monthly_reports_page.dart`) in More navigation for viewing, sharing, and manual historical regeneration.

### Quality Assurance & Testing
- **Added**: Comprehensive test suites in `test/unit/`:
  - `money_precision_test.dart`
  - `migration_v13_test.dart`
  - `account_archiving_test.dart`
  - `credit_card_management_test.dart`
  - `quick_templates_test.dart`
  - `daily_budget_rollover_test.dart`
  - `budget_inclusion_test.dart`
  - `monthly_pdf_reports_test.dart`
