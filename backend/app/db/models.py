from datetime import date, datetime
from typing import Any, Dict, Optional
import uuid

from sqlalchemy import (
    BigInteger,
    Boolean,
    CheckConstraint,
    Date,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    JSON,
    String,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base

def generate_uuid() -> str:
    return str(uuid.uuid4())

# 1. Users Table
class User(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=generate_uuid)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True, nullable=False)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    display_name: Mapped[str] = mapped_column(String(100), nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    members: Mapped[list["Member"]] = relationship("Member", back_populates="user")
    refresh_sessions: Mapped[list["RefreshSession"]] = relationship("RefreshSession", back_populates="user")

# 2. Households Table
class Household(Base):
    __tablename__ = "households"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=generate_uuid)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    currency: Mapped[str] = mapped_column(String(10), default="PKR", nullable=False)
    timezone: Mapped[str] = mapped_column(String(50), default="Asia/Karachi", nullable=False)
    invite_code: Mapped[str] = mapped_column(String(32), unique=True, index=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    members: Mapped[list["Member"]] = relationship("Member", back_populates="household", cascade="all, delete-orphan")
    shopping_items: Mapped[list["ShoppingItem"]] = relationship("ShoppingItem", back_populates="household", cascade="all, delete-orphan")
    expenses: Mapped[list["Expense"]] = relationship("Expense", back_populates="household", cascade="all, delete-orphan")
    settlements: Mapped[list["Settlement"]] = relationship("Settlement", back_populates="household", cascade="all, delete-orphan")
    budgets: Mapped[list["MonthlyBudget"]] = relationship("MonthlyBudget", back_populates="household", cascade="all, delete-orphan")

# 3. Members Table
class Member(Base):
    __tablename__ = "members"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    household_id: Mapped[str] = mapped_column(String(36), ForeignKey("households.id", ondelete="CASCADE"), nullable=False)
    user_id: Mapped[Optional[str]] = mapped_column(String(36), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    code: Mapped[str] = mapped_column(String(20), nullable=False)  # e.g., 'M01', 'M02', 'M03'
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    role: Mapped[str] = mapped_column(String(20), default="member", nullable=False)
    sort_order: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    household: Mapped["Household"] = relationship("Household", back_populates="members")
    user: Mapped[Optional["User"]] = relationship("User", back_populates="members")

    __table_args__ = (
        CheckConstraint("role IN ('owner', 'admin', 'member')", name="chk_member_role"),
        UniqueConstraint("household_id", "code", name="uq_member_household_code"),
        UniqueConstraint("household_id", "name", name="uq_member_household_name"),
        UniqueConstraint("household_id", "user_id", name="uq_member_household_user"),
    )

# 4. Shopping Items Table
class ShoppingItem(Base):
    __tablename__ = "shopping_items"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    household_id: Mapped[str] = mapped_column(String(36), ForeignKey("households.id", ondelete="CASCADE"), nullable=False)
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    unit: Mapped[str] = mapped_column(String(50), nullable=False)  # e.g. pack, dozen, bottle, bag
    requested_qty: Mapped[int] = mapped_column(Integer, nullable=False)
    status: Mapped[str] = mapped_column(String(20), default="pending", nullable=False)
    created_by_member_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("members.id", ondelete="SET NULL"), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    household: Mapped["Household"] = relationship("Household", back_populates="shopping_items")

    __table_args__ = (
        CheckConstraint("requested_qty > 0", name="chk_shopping_item_qty"),
        CheckConstraint("status IN ('pending', 'bought')", name="chk_shopping_item_status"),
        Index("ix_shopping_items_household_status", "household_id", "status"),
    )

# 5. Expenses Table
class Expense(Base):
    __tablename__ = "expenses"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    household_id: Mapped[str] = mapped_column(String(36), ForeignKey("households.id", ondelete="CASCADE"), nullable=False)
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    category: Mapped[str] = mapped_column(String(100), default="General", nullable=False)
    amount_paisa: Mapped[int] = mapped_column(BigInteger, nullable=False)
    payer_member_id: Mapped[int] = mapped_column(Integer, ForeignKey("members.id", ondelete="RESTRICT"), nullable=False)
    split_type: Mapped[str] = mapped_column(String(20), nullable=False)
    expense_date: Mapped[date] = mapped_column(Date, nullable=False)
    source: Mapped[str] = mapped_column(String(20), default="manual", nullable=False)
    created_by_user_id: Mapped[Optional[str]] = mapped_column(String(36), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    household: Mapped["Household"] = relationship("Household", back_populates="expenses")
    splits: Mapped[list["ExpenseSplit"]] = relationship("ExpenseSplit", back_populates="expense", cascade="all, delete-orphan")

    __table_args__ = (
        CheckConstraint("amount_paisa > 0", name="chk_expense_amount_paisa"),
        CheckConstraint("split_type IN ('equal', 'custom')", name="chk_expense_split_type"),
        CheckConstraint("source IN ('manual', 'checkout')", name="chk_expense_source"),
        Index("ix_expenses_household_date", "household_id", "expense_date"),
    )

# 6. Expense Splits Table
class ExpenseSplit(Base):
    __tablename__ = "expense_splits"

    expense_id: Mapped[int] = mapped_column(Integer, ForeignKey("expenses.id", ondelete="CASCADE"), primary_key=True)
    member_id: Mapped[int] = mapped_column(Integer, ForeignKey("members.id", ondelete="RESTRICT"), primary_key=True)
    share_paisa: Mapped[int] = mapped_column(BigInteger, nullable=False)

    expense: Mapped["Expense"] = relationship("Expense", back_populates="splits")

    __table_args__ = (
        CheckConstraint("share_paisa > 0", name="chk_split_share_paisa"),
    )

# 7. Checkout Items Table
class CheckoutItem(Base):
    __tablename__ = "checkout_items"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    expense_id: Mapped[int] = mapped_column(Integer, ForeignKey("expenses.id", ondelete="CASCADE"), nullable=False)
    item_id: Mapped[int] = mapped_column(Integer, ForeignKey("shopping_items.id", ondelete="CASCADE"), unique=True, nullable=False)

# 8. Settlements Table
class Settlement(Base):
    __tablename__ = "settlements"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    household_id: Mapped[str] = mapped_column(String(36), ForeignKey("households.id", ondelete="CASCADE"), nullable=False)
    sender_member_id: Mapped[int] = mapped_column(Integer, ForeignKey("members.id", ondelete="RESTRICT"), nullable=False)
    recipient_member_id: Mapped[int] = mapped_column(Integer, ForeignKey("members.id", ondelete="RESTRICT"), nullable=False)
    amount_paisa: Mapped[int] = mapped_column(BigInteger, nullable=False)
    created_by_user_id: Mapped[Optional[str]] = mapped_column(String(36), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    household: Mapped["Household"] = relationship("Household", back_populates="settlements")

    __table_args__ = (
        CheckConstraint("amount_paisa > 0", name="chk_settlement_amount_paisa"),
        CheckConstraint("sender_member_id <> recipient_member_id", name="chk_settlement_distinct_members"),
    )

# 9. Monthly Budgets Table
class MonthlyBudget(Base):
    __tablename__ = "monthly_budgets"

    household_id: Mapped[str] = mapped_column(String(36), ForeignKey("households.id", ondelete="CASCADE"), primary_key=True)
    month: Mapped[str] = mapped_column(String(7), primary_key=True)  # Format 'YYYY-MM'
    limit_paisa: Mapped[int] = mapped_column(BigInteger, nullable=False)

    household: Mapped["Household"] = relationship("Household", back_populates="budgets")

    __table_args__ = (
        CheckConstraint("limit_paisa > 0", name="chk_budget_limit_paisa"),
    )

# 10. Refresh Sessions Table
class RefreshSession(Base):
    __tablename__ = "refresh_sessions"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=generate_uuid)
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    family_id: Mapped[str] = mapped_column(String(36), nullable=False)
    token_hash: Mapped[str] = mapped_column(String(64), unique=True, nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    used_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    revoked_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    replaced_by_id: Mapped[Optional[str]] = mapped_column(String(36), nullable=True)
    user_agent: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    user: Mapped["User"] = relationship("User", back_populates="refresh_sessions")

    __table_args__ = (
        Index("ix_refresh_sessions_user_id", "user_id"),
        Index("ix_refresh_sessions_family_id", "family_id"),
    )

# 11. Idempotency Keys Table
class IdempotencyKey(Base):
    __tablename__ = "idempotency_keys"

    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    endpoint: Mapped[str] = mapped_column(String(100), primary_key=True)
    key: Mapped[str] = mapped_column(String(100), primary_key=True)
    request_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    response_status: Mapped[int] = mapped_column(Integer, nullable=False)
    response_body: Mapped[Dict[str, Any]] = mapped_column(JSON, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)

# 12. Audit Logs Table
class AuditLog(Base):
    __tablename__ = "audit_logs"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    household_id: Mapped[str] = mapped_column(String(36), nullable=False)
    user_id: Mapped[Optional[str]] = mapped_column(String(36), nullable=True)
    action: Mapped[str] = mapped_column(String(50), nullable=False)
    entity_type: Mapped[str] = mapped_column(String(50), nullable=False)
    entity_id: Mapped[str] = mapped_column(String(100), nullable=False)
    payload: Mapped[Optional[Dict[str, Any]]] = mapped_column(JSON, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    __table_args__ = (
        Index("ix_audit_logs_household_created", "household_id", "created_at"),
    )

# 13. Assistant Conversations Table
class AssistantConversation(Base):
    __tablename__ = "assistant_conversations"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=generate_uuid)
    authenticated_user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    household_id: Mapped[str] = mapped_column(String(36), ForeignKey("households.id", ondelete="CASCADE"), nullable=False)
    title: Mapped[str] = mapped_column(String(200), default="Chat", nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)

    messages: Mapped[list["AssistantMessage"]] = relationship("AssistantMessage", back_populates="conversation", cascade="all, delete-orphan", order_by="AssistantMessage.created_at")
    pending_actions: Mapped[list["AssistantPendingAction"]] = relationship("AssistantPendingAction", back_populates="conversation", cascade="all, delete-orphan")

    __table_args__ = (
        Index("ix_assistant_conv_user_household", "authenticated_user_id", "household_id"),
    )

# 14. Assistant Messages Table
class AssistantMessage(Base):
    __tablename__ = "assistant_messages"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    conversation_id: Mapped[str] = mapped_column(String(36), ForeignKey("assistant_conversations.id", ondelete="CASCADE"), nullable=False)
    role: Mapped[str] = mapped_column(String(20), nullable=False)  # 'user', 'assistant', 'system'
    content: Mapped[str] = mapped_column(Text, nullable=False)
    metadata_json: Mapped[Optional[Dict[str, Any]]] = mapped_column(JSON, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    conversation: Mapped["AssistantConversation"] = relationship("AssistantConversation", back_populates="messages")

    __table_args__ = (
        Index("ix_assistant_msg_conv", "conversation_id", "created_at"),
    )

# 15. Assistant Pending Actions Table
class AssistantPendingAction(Base):
    __tablename__ = "assistant_pending_actions"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=generate_uuid)
    conversation_id: Mapped[str] = mapped_column(String(36), ForeignKey("assistant_conversations.id", ondelete="CASCADE"), nullable=False)
    authenticated_user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    household_id: Mapped[str] = mapped_column(String(36), ForeignKey("households.id", ondelete="CASCADE"), nullable=False)
    action_type: Mapped[str] = mapped_column(String(50), nullable=False)  # 'create_expense', 'add_shopping_item', 'shopping_checkout', 'settle_debt'
    validated_payload: Mapped[Dict[str, Any]] = mapped_column(JSON, nullable=False)
    status: Mapped[str] = mapped_column(String(20), default="pending", nullable=False)  # 'pending', 'confirmed', 'rejected', 'expired'
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    idempotency_key: Mapped[str] = mapped_column(String(64), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    executed_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)

    conversation: Mapped["AssistantConversation"] = relationship("AssistantConversation", back_populates="pending_actions")

    __table_args__ = (
        Index("ix_assistant_pending_user_household", "authenticated_user_id", "household_id"),
        Index("ix_assistant_pending_status", "status"),
    )


