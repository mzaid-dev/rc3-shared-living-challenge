import pytest
from hypothesis import given, strategies as st
from app.domain.balances import assert_ledger_balanced, compute_net
from app.domain.exceptions import LedgerImbalance
from app.domain.split import custom_split_validate, equal_split

class TestBalancesDomain:
    def test_official_benchmark_through_pure_functions(self):
        """
        Official benchmark through pure functions:
        the 4 expenses:
        1. 780 equal x3
        2. 900 equal Ali+Ayesha
        3. 1500 custom 500/300/700
        4. 1020 equal x3
        => nets +25000/-45000/+20000 paisa, sum 0, spending 420000.
        """
        members = ["M01", "M02", "M03"]  # Ali, Ayesha, Bilal
        paid = {m: 0 for m in members}
        owed = {m: 0 for m in members}
        total_spending_paisa = 0

        # Expense 1: Grocery Trip (Milk & Rice) - 780.00 PKR paid by Ali (M01), equal 3 ways
        exp1_paisa = 78_000
        paid["M01"] += exp1_paisa
        total_spending_paisa += exp1_paisa
        s1 = equal_split(exp1_paisa, members)
        for m, share in s1.items():
            owed[m] += share

        # Expense 2: Cleaning Supplies - 900.00 PKR paid by Ayesha (M02), equal between Ali & Ayesha
        exp2_paisa = 90_000
        paid["M02"] += exp2_paisa
        total_spending_paisa += exp2_paisa
        s2 = equal_split(exp2_paisa, ["M01", "M02"])
        for m, share in s2.items():
            owed[m] += share

        # Expense 3: Internet Bill - 1,500.00 PKR paid by Bilal (M03), custom: Ali 500, Ayesha 300, Bilal 700
        exp3_paisa = 150_000
        paid["M03"] += exp3_paisa
        total_spending_paisa += exp3_paisa
        s3 = custom_split_validate(exp3_paisa, {"M01": 50_000, "M02": 30_000, "M03": 70_000})
        for m, share in s3.items():
            owed[m] += share

        # Expense 4: Electricity Bill - 1,020.00 PKR paid by Ali (M01), equal 3 ways
        exp4_paisa = 102_000
        paid["M01"] += exp4_paisa
        total_spending_paisa += exp4_paisa
        s4 = equal_split(exp4_paisa, members)
        for m, share in s4.items():
            owed[m] += share

        # Compute net balances
        net = compute_net(paid=paid, owed=owed, received={}, sent={}, member_ids=members)

        assert total_spending_paisa == 420_000  # 4,200.00 PKR
        assert net["M01"] == 25_000             # +250.00 PKR (Ali)
        assert net["M02"] == -45_000            # -450.00 PKR (Ayesha)
        assert net["M03"] == 20_000             # +200.00 PKR (Bilal)
        assert sum(net.values()) == 0

        # Assert balanced
        assert_ledger_balanced(net)

    def test_assert_ledger_imbalance_raises_error(self):
        imbalanced = {"M01": 25000, "M02": -24000}
        with pytest.raises(LedgerImbalance):
            assert_ledger_balanced(imbalanced)

    @given(
        num_expenses=st.integers(min_value=1, max_value=20),
        amounts=st.lists(st.integers(min_value=10, max_value=100_000), min_size=20, max_size=20),
        payers=st.lists(st.sampled_from(["M01", "M02", "M03"]), min_size=20, max_size=20),
    )
    def test_hypothesis_ledger_always_balanced_with_random_expenses(
        self, num_expenses: int, amounts: list[int], payers: list[str]
    ):
        """
        Hypothesis: random expenses + random settlements always keep sum(net) == 0.
        """
        members = ["M01", "M02", "M03"]
        paid = {m: 0 for m in members}
        owed = {m: 0 for m in members}
        received = {m: 0 for m in members}
        sent = {m: 0 for m in members}

        for i in range(num_expenses):
            amt = amounts[i]
            payer = payers[i]
            paid[payer] += amt
            splits = equal_split(amt, members)
            for m, share in splits.items():
                owed[m] += share

        # Random valid transfers between members
        net = compute_net(paid, owed, received, sent, members)
        debtors = [m for m, val in net.items() if val < 0]
        creditors = [m for m, val in net.items() if val > 0]

        if debtors and creditors:
            d = debtors[0]
            c = creditors[0]
            transfer = min(-net[d], net[c])
            if transfer > 0:
                sent[d] += transfer
                received[c] += transfer

        final_net = compute_net(paid, owed, received, sent, members)
        assert sum(final_net.values()) == 0
        assert_ledger_balanced(final_net)

    @given(
        operations=st.lists(
            st.tuples(
                st.sampled_from(["expense", "settle"]),
                st.integers(min_value=100, max_value=500_000),
                st.sampled_from(["M01", "M02", "M03"]),
                st.sampled_from(["M01", "M02", "M03"]),
            ),
            min_size=5,
            max_size=30,
        )
    )
    def test_property_sum_paisa_zero_after_random_valid_ops(self, operations):
        """Property test: sum_paisa == 0 after random valid ops (expenses & settlements)."""
        members = ["M01", "M02", "M03"]
        paid = {m: 0 for m in members}
        owed = {m: 0 for m in members}
        received = {m: 0 for m in members}
        sent = {m: 0 for m in members}

        for op_type, amt, m1, m2 in operations:
            if op_type == "expense":
                paid[m1] += amt
                splits = equal_split(amt, members)
                for m, share in splits.items():
                    owed[m] += share
            else:
                current_net = compute_net(paid, owed, received, sent, members)
                debtors = [m for m, val in current_net.items() if val < 0]
                creditors = [m for m, val in current_net.items() if val > 0]
                if debtors and creditors:
                    d = debtors[0]
                    c = creditors[0]
                    max_allowed = min(-current_net[d], current_net[c])
                    settle_amt = min(amt, max_allowed)
                    if settle_amt > 0:
                        sent[d] += settle_amt
                        received[c] += settle_amt

            net = compute_net(paid, owed, received, sent, members)
            assert sum(net.values()) == 0, f"Invariant violated: sum(net) = {sum(net.values())}"
            assert_ledger_balanced(net)

