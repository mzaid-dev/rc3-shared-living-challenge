import pytest
from app.domain.exceptions import (
    InvalidAmount,
    SelfSettlement,
    SettleExceedsCredit,
    SettleExceedsDebt,
)
from app.domain.settlement import simplify_debts, validate_settlement

class TestSettlementDomain:
    def test_official_settlement_flow_step_by_step(self):
        """
        Settlement:
        1. Ayesha->Ali 25000 ok
        2. then Ayesha->Bilal 20000 ok
        3. Ayesha->Ali 30000 fails SETTLE_EXCEEDS_CREDIT
        4. Ali->Ayesha fails (Ali is a creditor)
        5. self-payment fails
        6. zero amount fails
        7. negative amount fails
        """
        # Benchmark initial net balances: Ali +25000, Ayesha -45000, Bilal +20000
        net = {"Ali": 25_000, "Ayesha": -45_000, "Bilal": 20_000}

        # 1. Ayesha -> Ali 25000 is valid
        validate_settlement(net, sender="Ayesha", recipient="Ali", amount_paisa=25_000)

        # 3. Ayesha -> Ali 30000 fails SETTLE_EXCEEDS_CREDIT (Ali only has 250.00 credit)
        with pytest.raises(SettleExceedsCredit) as exc_info:
            validate_settlement(net, sender="Ayesha", recipient="Ali", amount_paisa=30_000)
        assert "25.00 PKR" in str(exc_info.value) or "250.00 PKR" in str(exc_info.value)

        # 4. Ali -> Ayesha fails (Ali is a creditor, not a debtor)
        with pytest.raises(SettleExceedsDebt) as exc_info:
            validate_settlement(net, sender="Ali", recipient="Ayesha", amount_paisa=5_000)
        assert "not a debtor" in str(exc_info.value)

        # 5. Self-payment fails
        with pytest.raises(SelfSettlement):
            validate_settlement(net, sender="Ayesha", recipient="Ayesha", amount_paisa=5_000)

        # 6. Zero amount fails
        with pytest.raises(InvalidAmount):
            validate_settlement(net, sender="Ayesha", recipient="Ali", amount_paisa=0)

        # 7. Negative amount fails
        with pytest.raises(InvalidAmount):
            validate_settlement(net, sender="Ayesha", recipient="Ali", amount_paisa=-1000)

        # Execute settlement 1: Ayesha pays Ali 25000
        # Model updates:
        net["Ayesha"] += 25_000  # -45000 + 25000 = -20000
        net["Ali"] -= 25_000     # 25000 - 25000 = 0

        # Now: Ali is 0, Ayesha is -20000, Bilal is +20000
        # 2. Ayesha -> Bilal 20000 is valid
        validate_settlement(net, sender="Ayesha", recipient="Bilal", amount_paisa=20_000)

        # Over-settlement checks on remaining debt
        with pytest.raises(SettleExceedsDebt) as exc_info:
            validate_settlement(net, sender="Ayesha", recipient="Bilal", amount_paisa=20_001)
        assert "200.00 PKR" in str(exc_info.value)

        # Cannot settle with Ali anymore because Ali net is now 0 (not a creditor)
        with pytest.raises(SettleExceedsCredit) as exc_info:
            validate_settlement(net, sender="Ayesha", recipient="Ali", amount_paisa=1_000)
        assert "not a creditor" in str(exc_info.value)

    def test_simplify_debts_algorithm(self):
        """Pure domain simplify_debts produces minimal cash flow transactions."""
        net = {"M01": 25_000, "M02": -45_000, "M03": 20_000}
        txs = simplify_debts(net)
        assert len(txs) == 2
        # Ayesha settles 25000 to Ali and 20000 to Bilal
        assert txs[0]["sender"] == "M02"
        assert txs[0]["recipient"] == "M01"
        assert txs[0]["amount_paisa"] == 25_000

        assert txs[1]["sender"] == "M02"
        assert txs[1]["recipient"] == "M03"
        assert txs[1]["amount_paisa"] == 20_000

