import pytest
from hypothesis import given, strategies as st
from app.domain.exceptions import (
    DuplicateSplitMember,
    InvalidAmount,
    SplitSumMismatch,
)
from app.domain.split import _member_numeric_sort_key, custom_split_validate, equal_split

class TestSplitDomain:
    def test_official_rounding_check_rule_100000_paisa_3_ways(self):
        """100000 split 3 ways => 33334/33333/33333 for M01/M02/M03."""
        members = ["M03", "M01", "M02"]
        result = equal_split(100_000, members)
        assert result == {
            "M01": 33334,
            "M02": 33333,
            "M03": 33333,
        }
        assert sum(result.values()) == 100_000

    def test_ordering_m10_sorts_after_m2(self):
        """Ordering test: M10 must sort after M2 (numeric, not string)."""
        # String sorting would place M10 before M2 ('M10' < 'M2')
        # Numeric sorting places M2 before M10, so M2 gets the remainder paisa!
        members = ["M10", "M2"]
        result = equal_split(101, members)  # 50 each, 1 remainder
        assert list(result.keys()) == ["M2", "M10"]
        assert result["M2"] == 51
        assert result["M10"] == 50

    def test_sort_key_helper_variants(self):
        assert _member_numeric_sort_key(5) == (0, 5)
        assert _member_numeric_sort_key("M5") == (1, 5)
        assert _member_numeric_sort_key("alpha") == (2, "alpha")

    def test_equal_split_validations(self):
        with pytest.raises(DuplicateSplitMember):
            equal_split(1000, [])

        with pytest.raises(DuplicateSplitMember):
            equal_split(1000, ["M01", "M01"])

        with pytest.raises(InvalidAmount):
            equal_split(0, ["M01", "M02"])

        with pytest.raises(InvalidAmount):
            equal_split(-500, ["M01", "M02"])

    def test_custom_split_validate_success(self):
        allocations = {"M01": 50000, "M02": 30000, "M03": 70000}
        validated = custom_split_validate(150000, allocations)
        assert validated == allocations

    def test_custom_split_validate_wrong_sum(self):
        """Custom split: wrong sum raises SplitSumMismatch carrying expected, actual, difference."""
        allocations = {"M01": 50000, "M02": 30000, "M03": 69999}
        with pytest.raises(SplitSumMismatch) as exc_info:
            custom_split_validate(150000, allocations)

        err = exc_info.value
        assert err.expected == 150000
        assert err.actual == 149999
        assert err.difference == -1

    def test_custom_split_validate_zero_and_negative_shares(self):
        """Custom split: zero or negative share raises InvalidAmount."""
        with pytest.raises(InvalidAmount):
            custom_split_validate(1000, {"M01": 1000, "M02": 0})

        with pytest.raises(InvalidAmount):
            custom_split_validate(1000, {"M01": 1500, "M02": -500})

    def test_custom_split_validate_empty_allocations(self):
        with pytest.raises(SplitSumMismatch):
            custom_split_validate(1000, {})

    @given(
        total_paisa=st.integers(min_value=1, max_value=1_000_000_000),
        n=st.integers(min_value=1, max_value=10),
    )
    def test_hypothesis_equal_split_invariants(self, total_paisa: int, n: int):
        """
        Hypothesis property: for random totals (1..10^9) and n in 1..10,
        equal_split conserves total and spread<=1 and remainder goes to lowest IDs.
        """
        members = [f"M{i}" for i in range(1, n + 1)]
        allocations = equal_split(total_paisa, members)

        # 1. Total conservation
        assert sum(allocations.values()) == total_paisa

        # 2. Spread <= 1
        assert max(allocations.values()) - min(allocations.values()) <= 1

        # 3. Remainder goes to lowest IDs
        base, rem = divmod(total_paisa, n)
        for idx, mid in enumerate(members):
            expected = base + (1 if idx < rem else 0)
            assert allocations[mid] == expected
