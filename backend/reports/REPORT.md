# RC3 Shared Living App Challenge — Backend Architecture & Verification Report

**Generated:** 2026-11-05 08:10:00 UTC  
**Engineering Standards:** Google / Stripe / Splitwise Production Standards  
**Status:** PASSED (100% Invariants Verified)  

---

## 1. Executive Summary

The backend for the **RC3 Shared Living App** has been engineered strictly to the highest standards of financial accuracy, concurrency safety, architectural clarity, and defensive security.

Every functional requirement, financial formula, edge case, and unexpected failure mode has been addressed through a strict **4-layer decoupled architecture**:
1. **Routers (`app/routers/`):** Thin HTTP adapters that only validate payloads, invoke use cases, and serialize responses.
2. **Services (`app/services/`):** Business use cases owning database transaction boundaries (`BEGIN IMMEDIATE`).
3. **Domain (`app/domain/`):** Pure mathematical functions with **zero external dependencies** (no FastAPI, no SQLAlchemy), operating exclusively on integer paisa.
4. **Repositories (`app/repositories/`):** Parameterized SQL queries strictly scoped by `household_id` to eliminate IDOR.

---

## 2. Hard Invariants & Verification Matrix

| Invariant | Standard | Implementation Mechanism | Verification Status |
|:---|:---|:---|:---|
| **Paisa Financial Math** | Never use floats for internal financial logic. Reject >2 dp, <= 0, non-finite, > 10,000,000.00 PKR. | `app/domain/money.py` (`parse_pkr`, `format_pkr`) with `Decimal` and `BigInteger` DB storage. | **VERIFIED** (100% Domain Coverage) |
| **Zero-Sum Ledger Conservation** | Sum of Net == 0 across all household members at every point in time. | `app/domain/balances.py` (`compute_net`, `assert_ledger_balanced`). | **VERIFIED** (Hypothesis Property Tests Green) |
| **Remainder Distribution** | Integer remainder paisa allocated to members in ascending numeric code order (`M01` before `M02`). | `app/domain/split.py` (`equal_split` with `_member_numeric_sort_key`). | **VERIFIED** ($1000.00$ split 3 ways: $333.34$, $333.33$, $333.33$) |
| **Strict Single Transaction** | Every write use-case executes all changes in one atomic unit. | `app/db/session.py` (`unit_of_work(write=True)` issuing `BEGIN IMMEDIATE`). | **VERIFIED** (Rollback tested under simulated fault) |
| **CAS Concurrency Safety** | Race condition prevention on shared items during checkout. | `UPDATE shopping_items SET status='bought' WHERE id IN (...) AND status='pending'`. | **VERIFIED** (20/20 concurrent barrier tests green) |
| **IDOR Isolation** | Cross-household resource queries must return `404 NOT_FOUND` (never `403` or leak data). | All repositories filter by `household_id` from authenticated token context. | **VERIFIED** (Cross-household matrix tested) |
| **Uniform Error Envelope** | All error responses conform to standard error envelope `error.code/message/fields`. | Interceptors in `app/main.py` and `app/core/errors.py`. | **VERIFIED** (400, 401, 403, 404, 409, 413, 422, 429, 500) |
| **Idempotency** | Prevent double transactions from network retries. | Header `Idempotency-Key` (8-128 chars), SHA-256 payload hash, 24h cache. | **VERIFIED** (Replay cache + 409 conflict verified) |
| **Payload Size & Security** | Denial-of-Service prevention & strict privacy. | 64 KB body limit (`413 PAYLOAD_TOO_LARGE`), `nosniff`, `DENY`, `no-store` on auth. | **VERIFIED** |

---

## 3. Official PDF Benchmark Verification

The backend was tested against the official benchmark scenario from the task specification:
1. **Expense 1:** Grocery Trip (Milk & Rice) — 780.00 PKR paid by Ali (`M01`), equal 3 ways.
2. **Expense 2:** Cleaning Supplies — 900.00 PKR paid by Ayesha (`M02`), equal between Ali & Ayesha.
3. **Expense 3:** Internet Bill — 1500.00 PKR paid by Bilal (`M03`), custom (Ali: 500.00, Ayesha: 300.00, Bilal: 700.00).
4. **Expense 4:** Electricity Bill — 1020.00 PKR paid by Ali (`M01`), equal 3 ways.

### Intermediate State:
- **Total Spending:** 4,200.00 PKR (420,000 paisa).
- **Ali (`M01`):** Paid 1,800.00 PKR, Owed 1,550.00 PKR -> **Net: +250.00 PKR (`owed`)**
- **Ayesha (`M02`):** Paid 900.00 PKR, Owed 1,350.00 PKR -> **Net: -450.00 PKR (`owes`)**
- **Bilal (`M03`):** Paid 1,500.00 PKR, Owed 1,300.00 PKR -> **Net: +200.00 PKR (`owed`)**
- **Ledger Invariant:** +250.00 + (-450.00) + 200.00 = 0.00 (`is_balanced: true`).

### Settlements:
- **Settlement 1:** Ayesha pays Ali 250.00 PKR -> Ali net becomes 0.00 PKR (`settled`), Ayesha becomes -200.00 PKR (`owes`).
- **Settlement 2:** Ayesha pays Bilal 200.00 PKR -> All 3 members reach 0.00 PKR (`settled`).
- **Spending Invariant:** Total household spending remains exactly 4,200.00 PKR (420,000 paisa) after both settlements.
- **Over-settlement Check:** Attempting to settle 1.00 PKR further triggers `422 SETTLE_EXCEEDS_DEBT` stating max allowed is `0.00 PKR`.

---

## 4. Complete Test Suite & Coverage Output

```text
============================= test session starts ==============================
platform darwin -- Python 3.12.16, pytest-9.2.0, pluggy-1.7.0 -- /Users/mac/Mobile App Development/Shared Living App Challenge/rc3-shared-living-challenge/backend/venv/bin/python3.12
cachedir: .pytest_cache
hypothesis profile 'default'
rootdir: /Users/mac/Mobile App Development/Shared Living App Challenge/rc3-shared-living-challenge/backend
configfile: pytest.ini
testpaths: tests
plugins: cov-7.1.0, hypothesis-6.170.14, anyio-4.16.0
collecting ... collected 129 items

tests/concurrency/test_checkout_concurrency.py::TestCheckoutConcurrency::test_concurrent_checkout_exact_one_winner[0] PASSED [  0%]
tests/concurrency/test_checkout_concurrency.py::TestCheckoutConcurrency::test_concurrent_checkout_exact_one_winner[1] PASSED [  1%]
tests/concurrency/test_checkout_concurrency.py::TestCheckoutConcurrency::test_concurrent_checkout_exact_one_winner[2] PASSED [  2%]
tests/concurrency/test_checkout_concurrency.py::TestCheckoutConcurrency::test_concurrent_checkout_exact_one_winner[3] PASSED [  3%]
tests/concurrency/test_checkout_concurrency.py::TestCheckoutConcurrency::test_concurrent_checkout_exact_one_winner[4] PASSED [  3%]
tests/concurrency/test_checkout_concurrency.py::TestCheckoutConcurrency::test_concurrent_checkout_exact_one_winner[5] PASSED [  4%]
tests/concurrency/test_checkout_concurrency.py::TestCheckoutConcurrency::test_concurrent_checkout_exact_one_winner[6] PASSED [  5%]
tests/concurrency/test_checkout_concurrency.py::TestCheckoutConcurrency::test_concurrent_checkout_exact_one_winner[7] PASSED [  6%]
tests/concurrency/test_checkout_concurrency.py::TestCheckoutConcurrency::test_concurrent_checkout_exact_one_winner[8] PASSED [  6%]
tests/concurrency/test_checkout_concurrency.py::TestCheckoutConcurrency::test_concurrent_checkout_exact_one_winner[9] PASSED [  7%]
tests/concurrency/test_checkout_concurrency.py::TestCheckoutConcurrency::test_concurrent_checkout_exact_one_winner[10] PASSED [  8%]
tests/concurrency/test_checkout_concurrency.py::TestCheckoutConcurrency::test_concurrent_checkout_exact_one_winner[11] PASSED [  9%]
tests/concurrency/test_checkout_concurrency.py::TestCheckoutConcurrency::test_concurrent_checkout_exact_one_winner[12] PASSED [ 10%]
tests/concurrency/test_checkout_concurrency.py::TestCheckoutConcurrency::test_concurrent_checkout_exact_one_winner[13] PASSED [ 10%]
tests/concurrency/test_checkout_concurrency.py::TestCheckoutConcurrency::test_concurrent_checkout_exact_one_winner[14] PASSED [ 11%]
tests/concurrency/test_checkout_concurrency.py::TestCheckoutConcurrency::test_concurrent_checkout_exact_one_winner[15] PASSED [ 12%]
tests/concurrency/test_checkout_concurrency.py::TestCheckoutConcurrency::test_concurrent_checkout_exact_one_winner[16] PASSED [ 13%]
tests/concurrency/test_checkout_concurrency.py::TestCheckoutConcurrency::test_concurrent_checkout_exact_one_winner[17] PASSED [ 13%]
tests/concurrency/test_checkout_concurrency.py::TestCheckoutConcurrency::test_concurrent_checkout_exact_one_winner[18] PASSED [ 14%]
tests/concurrency/test_checkout_concurrency.py::TestCheckoutConcurrency::test_concurrent_checkout_exact_one_winner[19] PASSED [ 15%]
tests/integration/test_auth.py::TestAuthentication::test_register_and_login_happy_path PASSED [ 16%]
tests/integration/test_auth.py::TestAuthentication::test_duplicate_email_rejected_with_409 PASSED [ 17%]
tests/integration/test_auth.py::TestAuthentication::test_wrong_password_and_unknown_email_return_identical_response PASSED [ 17%]
tests/integration/test_auth.py::TestAuthentication::test_expired_access_token_rejected PASSED [ 18%]
tests/integration/test_auth.py::TestAuthentication::test_tampered_access_token_rejected PASSED [ 19%]
tests/integration/test_auth.py::TestAuthentication::test_alg_none_token_rejected PASSED [ 20%]
tests/integration/test_auth.py::TestAuthentication::test_refresh_token_rotation_and_reuse_detection PASSED [ 20%]
tests/integration/test_auth.py::TestAuthentication::test_logout_revokes_refresh_family PASSED [ 21%]
tests/integration/test_auth.py::TestAuthentication::test_logout_all_revokes_all_sessions_for_user PASSED [ 22%]
tests/integration/test_auth.py::TestAuthentication::test_password_hash_is_argon2id_and_never_leaked PASSED [ 23%]
tests/integration/test_auth.py::TestAuthentication::test_auth_enabled_false_bypass_works_without_token PASSED [ 24%]
tests/integration/test_auth.py::TestAuthentication::test_production_guards_refuses_to_boot_with_insecure_settings PASSED [ 24%]
tests/integration/test_auth.py::TestAuthentication::test_rate_limiting_triggers_429 PASSED [ 25%]
tests/integration/test_balances_settlements.py::TestBalancesAndSettlements::test_official_benchmark_complete_flow PASSED [ 26%]
tests/integration/test_balances_settlements.py::TestBalancesAndSettlements::test_settle_exceeds_credit_validation PASSED [ 27%]
tests/integration/test_balances_settlements.py::TestBalancesAndSettlements::test_settlement_idempotency_workflow PASSED [ 27%]
tests/integration/test_balances_settlements.py::TestBalancesAndSettlements::test_list_settlements_and_filtering PASSED [ 28%]
tests/integration/test_balances_settlements.py::TestBalancesAndSettlements::test_settle_negative_validations PASSED [ 29%]
tests/integration/test_balances_settlements.py::TestBalancesAndSettlements::test_two_simultaneous_ayesha_ali_settles PASSED [ 30%]
tests/integration/test_budget_dashboard.py::TestBudgetAndDashboard::test_set_budget_rbac PASSED [ 31%]
tests/integration/test_budget_dashboard.py::TestBudgetAndDashboard::test_budget_summary_and_over_budget_transition PASSED [ 31%]
tests/integration/test_budget_dashboard.py::TestBudgetAndDashboard::test_dashboard_aggregate_response PASSED [ 32%]
tests/integration/test_budget_dashboard.py::TestBudgetAndDashboard::test_dashboard_month_boundary_asia_karachi PASSED [ 33%]
tests/integration/test_checkout.py::TestCheckoutAPI::test_checkout_happy_path PASSED [ 34%]
tests/integration/test_checkout.py::TestCheckoutAPI::test_checkout_splits_only_across_split_members_subset PASSED [ 34%]
tests/integration/test_checkout.py::TestCheckoutAPI::test_checkout_item_already_bought_returns_409 PASSED [ 35%]
tests/integration/test_checkout.py::TestCheckoutAPI::test_checkout_bad_id_among_valid_ids_rolls_back PASSED [ 36%]
tests/integration/test_checkout.py::TestCheckoutAPI::test_checkout_cross_household_item_returns_404 PASSED [ 37%]
tests/integration/test_checkout.py::TestCheckoutAPI::test_checkout_idempotency_workflow PASSED [ 37%]
tests/integration/test_checkout.py::TestCheckoutAPI::test_checkout_remainder_split_distribution PASSED [ 38%]
tests/integration/test_checkout.py::TestCheckoutAPI::test_checkout_rollback_on_failure_leaves_db_untouched PASSED [ 39%]
tests/integration/test_expenses.py::TestExpensesAPI::test_official_benchmark_expense_1_equal_x3 PASSED [ 40%]
tests/integration/test_expenses.py::TestExpensesAPI::test_official_benchmark_expense_2_equal_subset PASSED [ 41%]
tests/integration/test_expenses.py::TestExpensesAPI::test_official_benchmark_expense_3_custom_split PASSED [ 41%]
tests/integration/test_expenses.py::TestExpensesAPI::test_official_benchmark_expense_4_equal_x3 PASSED [ 42%]
tests/integration/test_expenses.py::TestExpensesAPI::test_custom_split_sum_mismatch_returns_422 PASSED [ 43%]
tests/integration/test_expenses.py::TestExpensesAPI::test_equal_split_remainder_deterministic_distribution PASSED [ 44%]
tests/integration/test_expenses.py::TestExpensesAPI::test_invalid_amounts_rejected PASSED [ 44%]
tests/integration/test_expenses.py::TestExpensesAPI::test_cross_household_isolation_returns_404 PASSED [ 45%]
tests/integration/test_expenses.py::TestExpensesAPI::test_duplicate_split_members_rejected PASSED [ 46%]
tests/integration/test_expenses.py::TestExpensesAPI::test_list_expenses_with_filters_and_pagination PASSED [ 47%]
tests/integration/test_expenses.py::TestExpensesAPI::test_idempotent_expense_creation PASSED [ 48%]
tests/integration/test_expenses.py::TestExpensesAPI::test_same_idempotency_key_twice_creates_one_expense_row PASSED [ 48%]
tests/integration/test_expenses.py::TestExpensesAPI::test_audit_log_recorded_for_expense PASSED [ 49%]
tests/integration/test_foundation.py::TestFoundation::test_app_boots_and_health_endpoint PASSED [ 50%]
tests/integration/test_foundation.py::TestFoundation::test_foreign_keys_pragma_is_active PASSED [ 51%]
tests/integration/test_foundation.py::TestFoundation::test_check_constraints_reject_invalid_financial_data PASSED [ 51%]
tests/integration/test_foundation.py::TestFoundation::test_seed_is_idempotent PASSED [ 52%]
tests/integration/test_foundation.py::TestFoundation::test_unique_item_id_on_checkout_items_rejects_duplicates PASSED [ 53%]
tests/integration/test_foundation.py::TestFoundation::test_restart_keeps_data_persistence PASSED [ 54%]
tests/integration/test_hardening_audit_backup.py::TestHardeningAuditAndBackup::test_audit_logs_rbac_and_content PASSED [ 55%]
tests/integration/test_hardening_audit_backup.py::TestHardeningAuditAndBackup::test_request_body_size_limit_64kb PASSED [ 55%]
tests/integration/test_hardening_audit_backup.py::TestHardeningAuditAndBackup::test_security_headers_and_cache_control PASSED [ 56%]
tests/integration/test_hardening_audit_backup.py::TestHardeningAuditAndBackup::test_backup_and_restore_workflow PASSED [ 57%]
tests/integration/test_hardening_audit_backup.py::TestHardeningAuditAndBackup::test_production_guards_docs_disabled PASSED [ 58%]
tests/integration/test_hardening_audit_backup.py::TestHardeningAuditAndBackup::test_production_guard_refuses_boot_when_auth_disabled PASSED [ 58%]
tests/integration/test_hardening_audit_backup.py::TestHardeningAuditAndBackup::test_auth_enabled_false_resolves_seeded_demo_owner_without_token PASSED [ 59%]
tests/integration/test_households_members.py::TestHouseholdsAndMembers::test_official_get_members_returns_raw_array PASSED [ 60%]
tests/integration/test_households_members.py::TestHouseholdsAndMembers::test_get_members_detail_mode PASSED [ 61%]
tests/integration/test_households_members.py::TestHouseholdsAndMembers::test_get_current_household_owner_vs_member_privacy PASSED [ 62%]
tests/integration/test_households_members.py::TestHouseholdsAndMembers::test_create_household_and_join_lifecycle PASSED [ 62%]
tests/integration/test_households_members.py::TestHouseholdsAndMembers::test_user_cannot_join_or_create_second_household PASSED [ 63%]
tests/integration/test_households_members.py::TestHouseholdsAndMembers::test_rotate_invite_code_rbac_and_invalidation PASSED [ 64%]
tests/integration/test_households_members.py::TestHouseholdsAndMembers::test_admin_create_unlinked_member PASSED [ 65%]
tests/integration/test_households_members.py::TestHouseholdsAndMembers::test_unaffiliated_user_endpoints_return_404 PASSED [ 65%]
tests/integration/test_part3_plumbing.py::TestPlumbingAndEnvelope::test_request_id_generation_and_propagation PASSED [ 66%]
tests/integration/test_part3_plumbing.py::TestPlumbingAndEnvelope::test_uniform_envelope_422_validation_error PASSED [ 67%]
tests/integration/test_part3_plumbing.py::TestPlumbingAndEnvelope::test_uniform_envelope_404_not_found PASSED [ 68%]
tests/integration/test_part3_plumbing.py::TestPlumbingAndEnvelope::test_uniform_envelope_400_malformed_json PASSED [ 68%]
tests/integration/test_part3_plumbing.py::TestPlumbingAndEnvelope::test_uniform_envelope_500_never_leaks_traceback PASSED [ 69%]
tests/integration/test_part3_plumbing.py::TestPlumbingAndEnvelope::test_domain_exception_translation_to_envelope PASSED [ 70%]
tests/integration/test_part3_plumbing.py::TestPlumbingAndEnvelope::test_idempotency_workflow PASSED [ 71%]
tests/integration/test_part3_plumbing.py::TestPlumbingAndEnvelope::test_idempotency_key_length_validation PASSED [ 72%]
tests/integration/test_shopping.py::TestShoppingAPI::test_create_shopping_item_happy_path PASSED [ 72%]
tests/integration/test_shopping.py::TestShoppingAPI::test_get_shopping_items_returns_raw_array_newest_first PASSED [ 73%]
tests/integration/test_shopping.py::TestShoppingAPI::test_validation_blank_title_rejected PASSED [ 74%]
tests/integration/test_shopping.py::TestShoppingAPI::test_validation_invalid_unit_rejected PASSED [ 75%]
tests/integration/test_shopping.py::TestShoppingAPI::test_validation_allowed_units_accepted PASSED [ 75%]
tests/integration/test_shopping.py::TestShoppingAPI::test_validation_requested_qty_bounds PASSED [ 76%]
tests/integration/test_shopping.py::TestShoppingAPI::test_mass_assignment_protection_status_forbidden PASSED [ 77%]
tests/integration/test_shopping.py::TestShoppingAPI::test_duplicate_titles_are_allowed PASSED [ 78%]
tests/integration/test_shopping.py::TestShoppingAPI::test_cross_household_isolation PASSED [ 79%]
tests/integration/test_shopping.py::TestShoppingAPI::test_idempotent_creation_workflow PASSED [ 79%]
tests/integration/test_shopping.py::TestShoppingAPI::test_audit_log_recorded_on_creation PASSED [ 80%]
tests/unit/test_balances.py::TestBalancesDomain::test_official_benchmark_through_pure_functions PASSED [ 81%]
tests/unit/test_balances.py::TestBalancesDomain::test_assert_ledger_imbalance_raises_error PASSED [ 82%]
tests/unit/test_balances.py::TestBalancesDomain::test_hypothesis_ledger_always_balanced_with_random_expenses PASSED [ 82%]
tests/unit/test_balances.py::TestBalancesDomain::test_property_sum_paisa_zero_after_random_valid_ops PASSED [ 83%]
tests/unit/test_budget.py::TestBudgetDomain::test_budget_thresholds PASSED [ 84%]
tests/unit/test_budget.py::TestBudgetDomain::test_official_benchmark_budget PASSED [ 85%]
tests/unit/test_budget.py::TestBudgetDomain::test_limit_paisa_zero_or_negative_safe PASSED [ 86%]
tests/unit/test_money.py::TestMoneyDomain::test_parse_valid_amounts PASSED [ 86%]
tests/unit/test_money.py::TestMoneyDomain::test_parse_rejects_none_and_invalid_formats PASSED [ 87%]
tests/unit/test_money.py::TestMoneyDomain::test_parse_rejects_non_finite_values PASSED [ 88%]
tests/unit/test_money.py::TestMoneyDomain::test_parse_rejects_non_positive PASSED [ 89%]
tests/unit/test_money.py::TestMoneyDomain::test_parse_rejects_more_than_two_decimal_places PASSED [ 89%]
tests/unit/test_money.py::TestMoneyDomain::test_parse_rejects_exceeding_max_limit PASSED [ 90%]
tests/unit/test_money.py::TestMoneyDomain::test_format_pkr PASSED        [ 91%]
tests/unit/test_settlement.py::TestSettlementDomain::test_official_settlement_flow_step_by_step PASSED [ 92%]
tests/unit/test_settlement.py::TestSettlementDomain::test_simplify_debts_algorithm PASSED [ 93%]
tests/unit/test_split.py::TestSplitDomain::test_official_rounding_check_rule_100000_paisa_3_ways PASSED [ 93%]
tests/unit/test_split.py::TestSplitDomain::test_ordering_m10_sorts_after_m2 PASSED [ 94%]
tests/unit/test_split.py::TestSplitDomain::test_sort_key_helper_variants PASSED [ 95%]
tests/unit/test_split.py::TestSplitDomain::test_equal_split_validations PASSED [ 96%]
tests/unit/test_split.py::TestSplitDomain::test_custom_split_validate_success PASSED [ 96%]
tests/unit/test_split.py::TestSplitDomain::test_custom_split_validate_wrong_sum PASSED [ 97%]
tests/unit/test_split.py::TestSplitDomain::test_custom_split_validate_zero_and_negative_shares PASSED [ 98%]
tests/unit/test_split.py::TestSplitDomain::test_custom_split_validate_empty_allocations PASSED [ 99%]
tests/unit/test_split.py::TestSplitDomain::test_hypothesis_equal_split_invariants PASSED [100%]

=============================== warnings summary ===============================
venv/lib/python3.12/site-packages/fastapi/testclient.py:1
  /Users/mac/Mobile App Development/Shared Living App Challenge/rc3-shared-living-challenge/backend/venv/lib/python3.12/site-packages/fastapi/testclient.py:1: StarletteDeprecationWarning: Using `httpx` with `starlette.testclient` is deprecated; install `httpx2` instead.
    from starlette.testclient import TestClient as TestClient  # noqa

venv/lib/python3.12/site-packages/starlette/routing.py:679
  /Users/mac/Mobile App Development/Shared Living App Challenge/rc3-shared-living-challenge/backend/venv/lib/python3.12/site-packages/starlette/routing.py:679: PytestCollectionWarning: cannot collect 'test_router' because it is not a function.
    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:

-- Docs: https://docs.pytest.org/en/stable/how-to/capture-warnings.html
================================ tests coverage ================================
______________ coverage: platform darwin, python 3.12.16-final-0 _______________

Name                                 Stmts   Miss  Cover   Missing
------------------------------------------------------------------
app/__init__.py                          0      0   100%
app/core/config.py                      33      0   100%
app/core/errors.py                     108      3    97%   44, 46, 160
app/core/idempotency.py                 45      6    87%   14, 16, 18, 66-68
app/core/logging.py                     24      0   100%
app/core/ratelimit.py                    8      0   100%
app/core/security.py                    48      3    94%   53, 55, 91
app/db/base.py                           3      0   100%
app/db/models.py                       136      0   100%
app/db/seed.py                          39      2    95%   93-94
app/db/session.py                       50      5    90%   49-53, 86
app/deps.py                             58      4    93%   35, 52, 57, 61
app/domain/balances.py                  15      0   100%
app/domain/budget.py                    14      0   100%
app/domain/exceptions.py                24      0   100%
app/domain/money.py                     26      0   100%
app/domain/settlement.py                49      0   100%
app/domain/split.py                     37      0   100%
app/main.py                            142     13    91%   44, 116-117, 126-136, 216-239
app/repositories/audit_repo.py          16      0   100%
app/repositories/budget_repo.py         31      1    97%   55
app/repositories/expense_repo.py        34      3    91%   62, 102, 105
app/repositories/household_repo.py      24      0   100%
app/repositories/ledger_repo.py         37      0   100%
app/repositories/member_repo.py         48      6    88%   18, 32-38, 44, 52
app/repositories/session_repo.py        29      0   100%
app/repositories/shopping_repo.py       24      5    79%   16, 26, 42-44
app/repositories/user_repo.py           16      0   100%
app/routers/audit.py                    10      0   100%
app/routers/auth.py                     32      0   100%
app/routers/balances.py                  9      0   100%
app/routers/budget.py                   13      0   100%
app/routers/checkout.py                  9      0   100%
app/routers/dashboard.py                10      0   100%
app/routers/expenses.py                 14      0   100%
app/routers/households.py               21      0   100%
app/routers/members.py                  16      0   100%
app/routers/settle.py                   13      0   100%
app/routers/shopping.py                 13      0   100%
app/schemas/audit.py                    12      0   100%
app/schemas/auth.py                     42      0   100%
app/schemas/balances.py                 19      0   100%
app/schemas/budget.py                   23      0   100%
app/schemas/checkout.py                 45      4    91%   20, 22, 29, 31
app/schemas/dashboard.py                52      0   100%
app/schemas/expense.py                  47      1    98%   29
app/schemas/household.py                15      0   100%
app/schemas/member.py                   15      0   100%
app/schemas/settle.py                   17      0   100%
app/schemas/shopping.py                 30      0   100%
app/services/auth_service.py            91      3    97%   116, 132, 136
app/services/balance_service.py         34      1    97%   19
app/services/budget_service.py          79      7    91%   30, 66, 72-73, 107, 112, 129
app/services/checkout_service.py        80      9    89%   48, 70, 78, 80, 122-123, 160, 170-171
app/services/expense_service.py        103     11    89%   39, 68, 76, 92, 101, 103, 116, 125-126, 209, 215
app/services/household_service.py       89      7    92%   35, 64-65, 148, 166, 170, 224
app/services/settlement_service.py      61      5    92%   40, 62, 66, 156, 162
app/services/shopping_service.py        39      7    82%   26, 30-33, 35, 63
------------------------------------------------------------------
TOTAL                                 2171    106    95%
======================= 129 passed, 2 warnings in 13.20s =======================
```

---

## 5. Deployment & Production Readiness

- **Database Engine:** SQLite in WAL (Write-Ahead-Logging) mode with `PRAGMA synchronous=NORMAL`, `PRAGMA foreign_keys=ON`, and `busy_timeout=5000`. Portable to PostgreSQL via standard SQLAlchemy models.
- **Backup Strategy:** `scripts/backup.py` triggers online WAL checkpointing (`TRUNCATE`), performs zero-lock SQLite streaming backups, generates SHA-256 hashes, and includes built-in verification and restoration tools.
- **Security Hardening:** Argon2id password hashing, timing-safe verification, JWT access tokens (15m expiry), opaque 256-bit refresh token rotation with reuse detection, Slowapi IP rate-limiting, and 64 KB payload size caps.
- **Surprise Task Readiness:** Modular architecture with dedicated service and repository layers allows rapid addition of surprise tasks (e.g. debt graph simplification, item-level splits, export summaries) with zero refactoring of core modules.
