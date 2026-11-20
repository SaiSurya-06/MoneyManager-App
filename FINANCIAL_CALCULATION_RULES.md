# Financial Calculation Rules & Precision Engine

## 1. Golden Rules of Monetary Calculations

1. **Integer Representation**: All monetary quantities stored in persistent storage or used in arithmetic must be represented as exact integers in minor currency units (e.g., paise, cents, satoshis).
2. **Never Floating-Point**: Authoritative financial calculations must never execute floating-point arithmetic (`double` addition/multiplication/division) without deterministic integer conversion.
3. **Deterministic Half-Up Rounding**: When converting from decimal inputs or percentages to minor units, use standard symmetric half-up rounding (`ROUND(x + 0.5)` for positive numbers).
4. **Remainder-Preserving Allocation**: When distributing a monetary quantity across ratios (splits) or days, remainder units must be allocated deterministically (e.g. earlier recipients receive +1 minor unit until the remainder is exhausted), ensuring the sum of parts exactly equals the whole.

---

## 2. Core Equations

### 2.1 Currency Minor Unit Conversion
$$\text{minorUnits} = \text{round}(\text{majorUnits} \times 10^{\text{exponent}})$$
$$\text{majorUnits} = \frac{\text{minorUnits}}{10^{\text{exponent}}}$$

- INR, USD, EUR: $\text{exponent} = 2$ ($1.00 \to 100$)
- JPY, KRW: $\text{exponent} = 0$ ($1 \to 1$)
- BHD, KWD: $\text{exponent} = 3$ ($1.000 \to 1000$)

### 2.2 Account Balance Calculation
For account $A$ with opening balance $\text{initialBalanceMinor}(A)$ across all chronological transactions $T$:
$$\text{balanceMinor}(A) = \text{initialBalanceMinor}(A) + \sum_{t \in T_{\text{income}}, t.acc = A} t.\text{amountMinor} - \sum_{t \in T_{\text{expense}}, t.acc = A} t.\text{amountMinor} - \sum_{t \in T_{\text{transfer\_out}}, t.src = A} t.\text{amountMinor} + \sum_{t \in T_{\text{transfer\_in}}, t.dst = A} t.\text{amountMinor} + \sum_{t \in T_{\text{cc\_payment}}, t.dst = A} t.\text{amountMinor}$$

- **Opening Balance Invariant**: When an account is created with a starting balance, $\text{initialBalanceMinor}(A)$ is stored directly on the account record. Under no circumstances may recalculation, migration, or restore reset $\text{initialBalanceMinor}(A)$ to $0$.
- **Legacy Database Derivation**: For legacy databases where opening balances were not stored separately, the opening balance is derived via:
  $$\text{initialBalanceMinor}(A) = \text{storedBalanceMinor}(A) - \text{netTransactionsMinor}(A)$$

### 2.3 Credit Card Available Credit
$$\text{availableCreditMinor} = \text{limitAmountMinor} - \max(0, -\text{balanceMinor})$$
*(where negative balance represents liability/debt incurred by purchases)*

### 2.4 Money Map Daily Budget & Rollover
For month with $D$ total days and total monthly budget $B_{\text{minor}}$:
1. Base daily allowance for day $d \in [1, D]$:
   $$\text{baseDaily} = B_{\text{minor}} \mathbin{/\!\!/} D$$
   $$\text{remainder} = B_{\text{minor}} \pmod D$$
   $$\text{baseAllowance}(d) = \text{baseDaily} + \begin{cases} 1, & \text{if } d \le \text{remainder} \\ 0, & \text{otherwise} \end{cases}$$

2. Day $d$ rollover tracking:
   $$\text{carriedIn}(1) = 0$$
   $$\text{available}(d) = \text{baseAllowance}(d) + \text{carriedIn}(d)$$
   $$\text{spent}(d) = \sum_{t \in T_{\text{eligible}}, t.day = d} t.\text{amountMinor}$$
   *(where $t \in T_{\text{eligible}} \iff t.\text{type} = \text{'expense'} \land t.\text{is\_budget\_included} = 1$)*
   $$\text{carriedOut}(d) = \text{available}(d) - \text{spent}(d)$$
   $$\text{carriedIn}(d + 1) = \text{carriedOut}(d)$$

---

## 3. Edge Cases & Boundary Handling

1. **Zero / Negative Budgets**: If monthly budget is zero or not set, base allowance is 0. Any spending results in negative rollover (overspending).
2. **Leap Years**: Leap years (e.g. Feb 2024, Feb 2028) calculate with 29 days using `DateTime(year, month + 1, 0).day`.
3. **Budget Exclusion**: Transactions tagged `is_budget_included = 0` are excluded from $\text{spent}(d)$ and monthly budget adherence, but remain included in account balance deductions and total financial cash flow.
