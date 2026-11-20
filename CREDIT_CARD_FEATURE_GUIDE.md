# Credit Card Feature Guide & Non-Duplicate Accounting

## 1. Architecture & Model
Credit Card accounts in Money Manager are modeled as standard `Account` entities with `type == 'Credit Card'`. They incorporate the following dedicated fields:

- `limitAmount` / `limitAmountMinor`: Total sanctioned credit limit.
- `availableCredit` / `availableCreditMinor`: Remaining purchasing power.
- `billingCycleStartDay`: Day of the month (1–31) on which the statement cycle begins.
- `statementDueDay`: Day of the month (1–31) by which the bill payment must be made.
- `minimumDue` / `minimumDueMinor`: Minimum mandatory payment required.

---

## 2. Non-Duplicate Settlement Accounting

### The Problem
When a user buys an item with a Credit Card, an expense of \$100 is logged under Category "Electronics". At the end of the month, the user pays the \$100 credit card bill from their Bank Account. If the bill payment is logged as an ordinary expense, the user's spending is double-counted as \$200 instead of \$100.

### The Solution
Money Manager enforces strict non-duplicate accounting via two workflows:

1. **Transfer Workflow (Recommended)**:
   - Source Account: Bank Account (debited by \$100).
   - Destination Account: Credit Card (credited by \$100, extinguishing debt).
   - Transaction Type: `transfer`.
   - Budget Impact: **Zero**. Transfers never deduct from category budgets or daily rollover allowances.

2. **Credit Card Payment Category Workflow**:
   - Source Account: Bank Account (debited by \$100).
   - Destination Credit Card: Target credit card specified in note / transfer target.
   - Transaction Type: `expense` with `is_budget_included = 0`.
   - Budget Impact: **Zero**. The toggle is automatically disabled or excluded from budget deductions, ensuring the bill payment settles the credit card balance without double-counting as a living expense.

---

## 3. User Interface Screens

1. **Account Form (`AccountForm`)**:
   - Selecting type "Credit Card" displays dedicated fields: Credit Limit, Billing Cycle Start Day, Payment Due Day, and Minimum Due.
2. **Account Card (`AccountCard`)**:
   - Displays Credit Limit and remaining Available Credit with visual warning colors when utilization exceeds 70% or 90%.
3. **Transaction History (`AccountTransactionsPage`)**:
   - Header shows Available Credit, Billing Cycle dates, and Due Date.
   - Two-tab view: `All Activity` vs `Payment History` (filtering specifically for bill settlement transfers and payments).
