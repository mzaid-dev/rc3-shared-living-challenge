#!/usr/bin/env python3
"""
Seed Clean, Professional, Realistic Showcase Data for Viva Demo
Run: python scripts/seed_showcase_data.py
"""
import os
import sys
from datetime import date, datetime, timezone
from zoneinfo import ZoneInfo

# Setup backend import path
BACKEND_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if BACKEND_DIR not in sys.path:
    sys.path.insert(0, BACKEND_DIR)

from app.core.config import settings
from app.core.security import hash_password
from app.db.models import (
    AssistantConversation,
    AssistantMessage,
    AssistantPendingAction,
    CheckoutItem,
    Expense,
    ExpenseSplit,
    Household,
    Member,
    MonthlyBudget,
    Settlement,
    ShoppingItem,
    User,
)
from app.db.session import SessionLocal

def seed_showcase():
    session = SessionLocal()
    try:
        print("[*] Finding demo user and household...")
        ali_user = session.query(User).filter_by(email="ali@demo.pk").first()
        if not ali_user:
            print("[!] ali@demo.pk not found. Please run regular seed first.")
            return

        ali_member = session.query(Member).filter_by(user_id=ali_user.id).first()
        if not ali_member:
            print("[!] Member record for Ali not found.")
            return

        household = session.query(Household).filter_by(id=ali_member.household_id).first()
        if not household:
            print("[!] Household not found.")
            return

        # Ensure household name looks great
        household.name = "Gulberg Apartment"
        session.flush()

        # Fetch all 3 members (Ali, Ayesha, Bilal)
        members = session.query(Member).filter_by(household_id=household.id).order_by(Member.code).all()
        member_map = {m.code: m for m in members}
        
        m_ali = member_map.get("M01")
        m_ayesha = member_map.get("M02")
        m_bilal = member_map.get("M03")

        if not (m_ali and m_ayesha and m_bilal):
            print("[!] Need M01, M02, and M03 to exist.")
            return

        print(f"[*] Cleaning old test data for household '{household.name}' ({household.id})...")

        # 1. Delete old checkout items, splits, expenses
        h_expenses = session.query(Expense).filter_by(household_id=household.id).all()
        exp_ids = [e.id for e in h_expenses]
        if exp_ids:
            session.query(ExpenseSplit).filter(ExpenseSplit.expense_id.in_(exp_ids)).delete(synchronize_session=False)
            session.query(CheckoutItem).filter(CheckoutItem.expense_id.in_(exp_ids)).delete(synchronize_session=False)
            session.query(Expense).filter(Expense.id.in_(exp_ids)).delete(synchronize_session=False)

        # 2. Delete old settlements
        session.query(Settlement).filter_by(household_id=household.id).delete(synchronize_session=False)

        # 3. Delete old shopping items
        session.query(ShoppingItem).filter_by(household_id=household.id).delete(synchronize_session=False)

        # 4. Delete old assistant conversations
        h_convs = session.query(AssistantConversation).filter_by(household_id=household.id).all()
        conv_ids = [c.id for c in h_convs]
        if conv_ids:
            session.query(AssistantPendingAction).filter(AssistantPendingAction.conversation_id.in_(conv_ids)).delete(synchronize_session=False)
            session.query(AssistantMessage).filter(AssistantMessage.conversation_id.in_(conv_ids)).delete(synchronize_session=False)
            session.query(AssistantConversation).filter(AssistantConversation.id.in_(conv_ids)).delete(synchronize_session=False)

        session.flush()
        print("[+] Old test data wiped cleanly.")

        # 5. Seed Realistic, Clean Expenses in "k's"
        # Total: 13,000 PKR (4,800 + 3,500 + 2,900 + 600 + 1,200)
        # Ali: 7,700 PKR paid -> Net balance: +PKR 3,366.66
        # Ayesha: 3,500 PKR paid -> Net balance: -PKR 833.33
        # Bilal: 1,800 PKR paid -> Net balance: -PKR 2,533.33
        expenses_data = [
            {
                "title": "Weekly Metro Groceries & Supplies",
                "category": "Groceries",
                "amount_pkr": 4800.00,
                "payer": m_ali,
                "date": date(2026, 11, 2),
            },
            {
                "title": "Nayatel Fiber WiFi Internet",
                "category": "Utilities",
                "amount_pkr": 3500.00,
                "payer": m_ayesha,
                "date": date(2026, 11, 3),
            },
            {
                "title": "Al-Madina Biryani & Soft Drinks",
                "category": "Dining",
                "amount_pkr": 2900.00,
                "payer": m_ali,
                "date": date(2026, 11, 4),
            },
            {
                "title": "Drinking Water Can Refills (3x 19L)",
                "category": "General",
                "amount_pkr": 600.00,
                "payer": m_bilal,
                "date": date(2026, 11, 4),
            },
            {
                "title": "Kitchen & Cleaning Supplies",
                "category": "Supplies",
                "amount_pkr": 1200.00,
                "payer": m_bilal,
                "date": date(2026, 11, 5),
            },
        ]

        print("[*] Inserting 5 realistic shared expenses...")
        for ed in expenses_data:
            amount_paisa = int(round(ed["amount_pkr"] * 100))
            exp = Expense(
                household_id=household.id,
                title=ed["title"],
                category=ed["category"],
                amount_paisa=amount_paisa,
                payer_member_id=ed["payer"].id,
                split_type="equal",
                expense_date=ed["date"],
                source="manual",
                created_by_user_id=ali_user.id,
            )
            session.add(exp)
            session.flush()

            # Equal 3-way split with integer paisa remainder allocation
            base_share = amount_paisa // 3
            rem = amount_paisa % 3
            shares = [base_share + (1 if i < rem else 0) for i in range(3)]

            for m, share in zip([m_ali, m_ayesha, m_bilal], shares):
                split = ExpenseSplit(
                    expense_id=exp.id,
                    member_id=m.id,
                    share_paisa=share,
                )
                session.add(split)

        # 6. Update Monthly Budget for 2026-11
        active_month = "2026-11"
        budget = session.query(MonthlyBudget).filter_by(household_id=household.id, month=active_month).first()
        if not budget:
            budget = MonthlyBudget(
                household_id=household.id,
                month=active_month,
                limit_paisa=3500_000,  # 35,000.00 PKR
            )
            session.add(budget)
        else:
            budget.limit_paisa = 3500_000  # 35,000.00 PKR
        
        session.flush()

        # 7. Seed Clean, Realistic Shopping Items (3 Pending, 2 Bought)
        print("[*] Inserting 5 clean shopping items (3 pending, 2 bought)...")
        shopping_data = [
            ("Nestlé MilkPack 1L", "pack", 3, "pending", m_ali),
            ("Dawn White Bread Large", "pack", 1, "pending", m_ayesha),
            ("Farm Fresh Eggs", "dozen", 1, "pending", m_bilal),
            ("Dalda Cooking Oil 5L", "bottle", 1, "bought", m_ali),
            ("Tapal Danedar Tea 450g", "pack", 1, "bought", m_ayesha),
        ]
        for title, unit, qty, status, member in shopping_data:
            item = ShoppingItem(
                household_id=household.id,
                title=title,
                unit=unit,
                requested_qty=qty,
                status=status,
                created_by_member_id=member.id,
            )
            session.add(item)

        # 8. Seed 1 Clean Assistant Conversation
        conv = AssistantConversation(
            household_id=household.id,
            authenticated_user_id=ali_user.id,
            title="Monthly spending inquiry",
        )
        session.add(conv)
        session.flush()

        m1 = AssistantMessage(
            conversation_id=conv.id,
            role="user",
            content="How much did we spend this month?",
        )
        m2 = AssistantMessage(
            conversation_id=conv.id,
            role="assistant",
            content="Household spending for November 2026 is PKR 13,000.00 out of your PKR 35,000.00 monthly budget (37.1% utilized). You have PKR 22,000.00 remaining in your budget.",
        )
        session.add_all([m1, m2])

        session.commit()
        print("\n" + "=" * 60)
        print(" [SUCCESS] SHOWCASE DATA SEEDED SUCCESSFULLY! ")
        print("=" * 60)
        print(" Household Name    : Gulberg Apartment")
        print(" Active Members    : Ali (M01), Ayesha (M02), Bilal (M03)")
        print(" Monthly Limit     : PKR 35,000.00")
        print(" Total Spent       : PKR 13,000.00 (37.1% utilized)")
        print(" Budget Remaining  : PKR 22,000.00 (62.9% remaining)")
        print(" Pending Shopping  : 3 items (MilkPack, Bread, Eggs)")
        print(" Ali Net Balance   : +PKR 3,366.66 (Owed)")
        print(" Ayesha Net Balance: -PKR 833.33 (Owes)")
        print(" Bilal Net Balance : -PKR 2,533.33 (Owes)")
        print(" Sum of Balances   : PKR 0.00 (Exact zero-sum ledger)")
        print("=" * 60 + "\n")

    except Exception as e:
        session.rollback()
        print(f"[!] Error seeding showcase data: {e}")
        import traceback
        traceback.print_exc()
    finally:
        session.close()

if __name__ == "__main__":
    seed_showcase()
