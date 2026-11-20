# Monthly PDF Report Generation Guide

## 1. Overview
Money Manager automatically generates two auditable, publication-quality A4 PDF reports on the 1st of every month:
1. **Monthly Income & Expense Analysis**: Full financial reality across all transactions and accounts.
2. **Monthly Budget Performance Report**: Budget-adherence and daily rollover performance across budget-eligible outlays.

---

## 2. Report Details

### 2.1 Report 1: Monthly Income & Expense Analysis
- **File Name**: `Money_Manager_Income_Expense_Report_YYYY-MM.pdf`
- **Sections**:
  1. *Header*: App Title, Report Name, Period, Generation Timestamp, Currency.
  2. *Executive Financial Summary*: Total Income, Total Expenses, Net Savings, Savings Rate (%).
  3. *Income Analysis*: Category breakdown (transactions, amount, % of income) and Account breakdown.
  4. *Expense Analysis*: Category breakdown (transactions, amount, % of expenses).
  5. *Top 5 Major Expenses*: Date, title, category, account, and amount.
  6. *Account Balances & Activity*: Account balances, types, and status.
  7. *Observations & Recommendations*: Rule-based financial analysis.

### 2.2 Report 2: Monthly Budget Performance Report
- **File Name**: `Money_Manager_Budget_Report_YYYY-MM.pdf`
- **Sections**:
  1. *Header*: App Title, Report Name, Period, Generation Timestamp, Currency.
  2. *Budget Performance Summary*: Planned Budget, Actual Spend (budget-eligible only), Variance, Adherence Rate (%), and Net Rollover Balance.
  3. *Category Budget Adherence Table*: Category, Planned, Actual, Variance, Status (Within Budget / Near Limit / Over Budget).
  4. *Money Map Daily Rollover & Calendar Analysis*: Average Daily Allowance, Average Daily Spend, Under/Over day counts, Peak Single-Day Overspend.
  5. *Budget Adherence Recommendations*: Rule-based budget advice.

---

## 3. Storage, Database Tracking & Triggers

- **Storage Location**: `getApplicationDocumentsDirectory()/reports/monthly/`.
- **Database Table (`report_history`)**: Records report type, month, file path, size, SHA-256 checksum, and generation timestamp.
- **Triggers**:
  - *Automated Startup / Catch-up*: On app launch, checks if previous month reports are present. If missing, generates them idempotently.
  - *Manual Generation*: Accessible via `More` $\to$ `Monthly Financial Reports` (`MonthlyReportsPage`), allowing generation, regeneration, viewing, and sharing.
- **Sharing**: Integrated with Android Share Sheet via `share_plus`.
