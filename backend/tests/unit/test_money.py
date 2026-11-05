from decimal import Decimal
import pytest
from app.domain.exceptions import InvalidAmount
from app.domain.money import format_pkr, parse_pkr

class TestMoneyDomain:
    def test_parse_valid_amounts(self):
        assert parse_pkr(780) == 78000
        assert parse_pkr("780.00") == 78000
        assert parse_pkr(Decimal("1500.50")) == 150050
        assert parse_pkr(10.5) == 1050
        assert parse_pkr("0.01") == 1
        assert parse_pkr("10000000.00") == 1_000_000_000

    def test_parse_rejects_none_and_invalid_formats(self):
        with pytest.raises(InvalidAmount):
            parse_pkr(None)

        with pytest.raises(InvalidAmount):
            parse_pkr("abc")

    def test_parse_rejects_non_finite_values(self):
        with pytest.raises(InvalidAmount):
            parse_pkr("nan")

        with pytest.raises(InvalidAmount):
            parse_pkr("inf")

        with pytest.raises(InvalidAmount):
            parse_pkr(float("nan"))

        with pytest.raises(InvalidAmount):
            parse_pkr(float("inf"))

    def test_parse_rejects_non_positive(self):
        with pytest.raises(InvalidAmount):
            parse_pkr(0)

        with pytest.raises(InvalidAmount):
            parse_pkr("0.00")

        with pytest.raises(InvalidAmount):
            parse_pkr("-10.00")

    def test_parse_rejects_more_than_two_decimal_places(self):
        with pytest.raises(InvalidAmount):
            parse_pkr("10.125")

        with pytest.raises(InvalidAmount):
            parse_pkr(Decimal("333.333"))

    def test_parse_rejects_exceeding_max_limit(self):
        with pytest.raises(InvalidAmount):
            parse_pkr("10000000.01")

    def test_format_pkr(self):
        assert format_pkr(33334) == Decimal("333.34")
        assert format_pkr(100) == Decimal("1.00")
        assert format_pkr(0) == Decimal("0.00")
