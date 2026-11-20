# Money Map Daily Budget & Rollover Guide

## 1. Concept & Purpose
The Money Map Daily Spending Calendar provides daily budget tracking with chronological rollover. Instead of a rigid monthly budget where overspending on day 2 is unnoticed until month-end, the daily calendar allocates a daily allowance and rolls over surplus or deficit from day to day.

---

## 2. Mathematical Logic & Rollover Rules

1. **Base Daily Allowance**:
   $$\text{Base Allowance} = \frac{\text{Monthly Budget}}{\text{Total Days in Month}}$$
   Remainder minor units are distributed to earlier days so that $\sum \text{Base Allowance} = \text{Monthly Budget}$ exactly.

2. **Daily Rollover Accumulation**:
   $$\text{Available Today} = \text{Base Allowance} + \text{Carried In from Yesterday}$$
   $$\text{Carried Out to Tomorrow} = \text{Available Today} - \text{Eligible Spend Today}$$

3. **Status Categorization**:
   - $\text{Eligible Spend} < \text{Available} \implies$ **Under Budget** (Green, positive surplus carried forward).
   - $\text{Eligible Spend} = \text{Available} \implies$ **At Budget** (Green/neutral, zero balance carried forward).
   - $\text{Eligible Spend} > \text{Available} \implies$ **Over Budget** (Red, negative deficit reduces future days).
   - Day is in the future $\implies$ **Future** (Grey, projected base allowance displayed).

4. **Budget Exclusion**:
   Transactions where `is_budget_included == 0` (e.g. reimbursable expenses) are omitted from `Eligible Spend Today`.

---

## 3. UI Features

- **Month Navigation**: Select past, current, or future months.
- **Category Filter**: View overall budget or isolate a single category.
- **Monthly Summary**: Total Planned, Spent So Far, and Net Rollover Balance.
- **7-Column Calendar Grid**: Visual status dot, actual spent, and available allowance per cell.
- **Agenda / List Toggle**: View as an chronological daily scrollable list.
- **Day Detail Modal**: Complete accounting breakdown (Base, Carried In, Available, Spent, Carried Out) plus transaction register for that day.
