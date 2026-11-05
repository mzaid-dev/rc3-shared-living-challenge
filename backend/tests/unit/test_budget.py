import pytest
from app.domain.budget import budget_status

class TestBudgetDomain:
    def test_budget_thresholds(self):
        """
        Tests budget thresholds at 79, 80, 99, 100, 101 percent:
        - < 80: on_track
        - 80..<100: near_limit
        - >= 100: over_budget
        """
        limit = 100_000  # 1,000.00 PKR

        # 79% -> on_track
        s79 = budget_status(79_000, limit)
        assert s79["percent"] == 79
        assert s79["remaining_paisa"] == 21_000
        assert s79["status"] == "on_track"

        # 80% -> near_limit
        s80 = budget_status(80_000, limit)
        assert s80["percent"] == 80
        assert s80["remaining_paisa"] == 20_000
        assert s80["status"] == "near_limit"

        # 99% -> near_limit
        s99 = budget_status(99_000, limit)
        assert s99["percent"] == 99
        assert s99["remaining_paisa"] == 1_000
        assert s99["status"] == "near_limit"

        # 100% -> over_budget
        s100 = budget_status(100_000, limit)
        assert s100["percent"] == 100
        assert s100["remaining_paisa"] == 0
        assert s100["status"] == "over_budget"

        # 101% -> over_budget
        s101 = budget_status(101_000, limit)
        assert s101["percent"] == 101
        assert s101["remaining_paisa"] == -1_000
        assert s101["status"] == "over_budget"

    def test_official_benchmark_budget(self):
        """Official benchmark: 420000/500000 => 84, remaining 80000, near_limit."""
        result = budget_status(420_000, 500_000)
        assert result["percent"] == 84
        assert result["remaining_paisa"] == 80_000
        assert result["status"] == "near_limit"

    def test_limit_paisa_zero_or_negative_safe(self):
        """limit <= 0 handled safely without ZeroDivisionError."""
        s_zero = budget_status(50_000, 0)
        assert s_zero["status"] == "over_budget"
        assert s_zero["remaining_paisa"] == -50_000

        s_zero_unspent = budget_status(0, 0)
        assert s_zero_unspent["status"] == "on_track"
        assert s_zero_unspent["remaining_paisa"] == 0

        s_neg = budget_status(10_000, -5000)
        assert s_neg["status"] == "over_budget"
