from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List, Optional, Union
import uuid

from sqlalchemy.orm import Session
from sqlalchemy import func

from app.ai.provider import get_llm_provider
from app.core.config import settings
from app.core.errors import (
    ForbiddenError,
    NotFoundError,
    ValidationAppError,
)
from app.db.models import (
    AssistantConversation,
    AssistantMessage,
    AssistantPendingAction,
    Member,
)
from app.deps import Context
from app.domain.balances import compute_net
from app.domain.money import format_pkr, parse_pkr
from app.domain.split import equal_split
from app.repositories.audit_repo import AuditRepository
from app.repositories.ledger_repo import LedgerRepository
from app.repositories.member_repo import MemberRepository
from app.repositories.shopping_repo import ShoppingRepository
from app.schemas.assistant import (
    ActionPayload,
    AssistantResponsePayload,
    ChatRequest,
    ChatResponse,
    ConfirmRequest,
    ConfirmResponse,
    ConversationDetail,
    ConversationMessage,
    ConversationSummary,
)
from app.schemas.checkout import CheckoutRequest
from app.schemas.expense import ExpenseCreate
from app.schemas.settle import SettlementCreate
from app.schemas.shopping import ShoppingItemCreate
from app.services.balance_service import BalanceService
from app.services.budget_service import BudgetService
from app.services.checkout_service import CheckoutService
from app.services.expense_service import ExpenseService
from app.services.settlement_service import SettlementService
from app.services.shopping_service import ShoppingService

class AssistantService:
    @staticmethod
    async def chat(
        session: Session,
        ctx: Context,
        payload: ChatRequest,
    ) -> ChatResponse:
        """
        Processes a natural language chat message using LangChain and existing financial services.
        Guarantees strict authentication and household scoping.
        """
        if not ctx.user:
            raise ForbiddenError("User is not authenticated.")
        if not ctx.household_id:
            raise NotFoundError("User is not associated with any household.")

        # 1. Resolve or create conversation
        if payload.conversation_id:
            conv = (
                session.query(AssistantConversation)
                .filter_by(id=payload.conversation_id)
                .first()
            )
            if not conv:
                raise NotFoundError("Conversation not found.")
            if conv.household_id != ctx.household_id or conv.authenticated_user_id != ctx.user.id:
                raise NotFoundError("Conversation not found in authorized household.")
        else:
            conv = AssistantConversation(
                authenticated_user_id=ctx.user.id,
                household_id=ctx.household_id,
                title=payload.message[:50].strip(),
            )
            session.add(conv)
            session.flush()

        # 2. Persist user message
        user_msg = AssistantMessage(
            conversation_id=conv.id,
            role="user",
            content=payload.message.strip(),
        )
        session.add(user_msg)
        session.flush()

        # 3. Resolve Household Members
        members = MemberRepository.list_by_household(session, ctx.household_id)
        members_info = [
            {"id": m.id, "code": m.code, "name": m.name, "role": m.role}
            for m in members
        ]
        member_name_map = {m.name.lower(): m for m in members}
        member_code_map = {m.code.lower(): m for m in members}

        # Resolve active member name for context
        active_member_name = None
        if payload.active_member_id is not None:
            resolved_mem = MemberRepository.resolve_member(
                session, ctx.household_id, payload.active_member_id
            )
            if resolved_mem:
                active_member_name = resolved_mem.name
        if not active_member_name and ctx.member_code:
            mem_by_code = member_code_map.get(ctx.member_code.lower())
            if mem_by_code:
                active_member_name = mem_by_code.name

        # 4. Invoke LangChain AI Provider
        provider = get_llm_provider()
        ai_result = await provider.extract_intent_and_entities(
            message=payload.message,
            members=members_info,
            active_member=active_member_name,
        )

        intent = ai_result.get("intent", "general_help")
        # Normalize intents from LLMs (e.g., 'add_expense' -> 'create_expense')
        if intent == "add_expense":
            intent = "create_expense"

        entities = ai_result.get("entities", {}) or {}

        # 5. Route to existing business service or mutation proposal
        resp_payload: AssistantResponsePayload
        requires_confirmation = False

        if intent == "get_budget":
            budget_data = BudgetService.get_budget_summary(session, ctx)
            msg = (
                f"Household budget for {budget_data['month']}: "
                f"Spent PKR {budget_data['spent']:,.2f} ({budget_data['percent']}%), "
                f"Remaining PKR {budget_data['remaining']:,.2f} (Status: {budget_data['status']})."
            )
            resp_payload = AssistantResponsePayload(
                type="budget_summary",
                message=msg,
                data=budget_data,
            )

        elif intent == "get_expenses":
            expenses_data = ExpenseService.list_expenses(session, ctx, limit=5)
            msg = f"Retrieved {len(expenses_data)} recent expenses for your household."
            resp_payload = AssistantResponsePayload(
                type="expense_summary",
                message=msg,
                data=expenses_data,
            )

        elif intent == "get_balances":
            target_mem_code = None
            raw_mem = entities.get("member")
            if raw_mem:
                resolved = (
                    member_name_map.get(str(raw_mem).lower())
                    or member_code_map.get(str(raw_mem).lower())
                )
                if resolved:
                    target_mem_code = resolved.code

            balances_data = BalanceService.get_household_balances(
                session=session,
                ctx=ctx,
                member_id=target_mem_code,
            )
            msg = (
                f"Current household spending is PKR {balances_data['household_total_spending']:,.2f}. "
                f"Zero-sum balance sheet verified."
            )
            resp_payload = AssistantResponsePayload(
                type="balance_summary",
                message=msg,
                data=balances_data,
            )

        elif intent == "get_settlement_suggestions":
            suggestions = BalanceService.simplify_household_debts(
                session=session,
                ctx=ctx,
            )
            msg = f"Generated {len(suggestions)} simplified debt settlement transfers."
            resp_payload = AssistantResponsePayload(
                type="settlement_suggestions",
                message=msg,
                data=suggestions,
            )

        elif intent == "get_shopping_list":
            items = ShoppingService.list_shopping_items(session, ctx)
            pending_count = sum(1 for i in items if i["status"] == "pending")
            msg = f"Shopping list has {len(items)} items ({pending_count} pending)."
            resp_payload = AssistantResponsePayload(
                type="shopping_list",
                message=msg,
                data=items,
            )

        elif intent == "create_expense":
            raw_amt = entities.get("amount")
            if not raw_amt:
                resp_payload = AssistantResponsePayload(
                    type="text",
                    message="How much was the expense amount in PKR?",
                )
            else:
                try:
                    amt_paisa = parse_pkr(raw_amt)
                    if amt_paisa <= 0:
                        raise ValueError()
                except Exception:
                    resp_payload = AssistantResponsePayload(
                        type="text",
                        message="Please specify a valid positive expense amount in PKR.",
                    )
                    amt_paisa = 0

                if amt_paisa > 0:
                    title = str(entities.get("title") or entities.get("category") or "Shared Expense").strip().title()
                    raw_payer = entities.get("payer")
                    payer_mem = None
                    if raw_payer:
                        payer_mem = (
                            member_name_map.get(str(raw_payer).lower())
                            or member_code_map.get(str(raw_payer).lower())
                        )
                    if not payer_mem:
                        payer_mem = (
                            member_name_map.get((active_member_name or "").lower())
                            or members[0]
                        )

                    raw_participants = entities.get("participants") or []
                    resolved_participants: List[Member] = []
                    for p in raw_participants:
                        pm = member_name_map.get(str(p).lower()) or member_code_map.get(str(p).lower())
                        if pm and pm not in resolved_participants:
                            resolved_participants.append(pm)
                    if not resolved_participants:
                        resolved_participants = members

                    split_type = entities.get("split_type") or "equal"
                    category = entities.get("category") or "General"

                    participant_names = [m.name for m in resolved_participants]

                    expiry = datetime.now(timezone.utc) + timedelta(minutes=settings.AI_ACTION_EXPIRY_MINUTES)
                    action = AssistantPendingAction(
                        conversation_id=conv.id,
                        authenticated_user_id=ctx.user.id,
                        household_id=ctx.household_id,
                        action_type="create_expense",
                        validated_payload={
                            "title": title,
                            "category": category,
                            "amount": str(format_pkr(amt_paisa)),
                            "payer_id": payer_mem.code,
                            "split_type": split_type,
                            "split_members": [m.code for m in resolved_participants],
                        },
                        status="pending",
                        expires_at=expiry,
                        idempotency_key=str(uuid.uuid4()),
                    )
                    session.add(action)
                    session.flush()

                    requires_confirmation = True
                    resp_payload = AssistantResponsePayload(
                        type="confirmation_required",
                        message=(
                            f"Please confirm recording expense '{title}' for PKR {format_pkr(amt_paisa)} "
                            f"paid by {payer_mem.name}, split equally among {len(participant_names)} roommates."
                        ),
                        action=ActionPayload(
                            action_id=action.id,
                            action_type="create_expense",
                            title=title,
                            amount=str(format_pkr(amt_paisa)),
                            currency="PKR",
                            payer=payer_mem.name,
                            participants=participant_names,
                            confirmation_required=True,
                        ),
                    )

        elif intent == "add_shopping_item":
            title = str(entities.get("title") or "Item").strip().capitalize()
            raw_qty = entities.get("quantity") or 1
            raw_unit = str(entities.get("unit") or "pack").strip().lower()
            if raw_unit not in ["pack", "dozen", "bottle", "bag"]:
                raw_unit = "pack"

            expiry = datetime.now(timezone.utc) + timedelta(minutes=settings.AI_ACTION_EXPIRY_MINUTES)
            action = AssistantPendingAction(
                conversation_id=conv.id,
                authenticated_user_id=ctx.user.id,
                household_id=ctx.household_id,
                action_type="add_shopping_item",
                validated_payload={
                    "title": title,
                    "unit": raw_unit,
                    "requested_qty": int(raw_qty),
                },
                status="pending",
                expires_at=expiry,
                idempotency_key=str(uuid.uuid4()),
            )
            session.add(action)
            session.flush()

            requires_confirmation = True
            resp_payload = AssistantResponsePayload(
                type="confirmation_required",
                message=f"Please confirm adding {raw_qty} {raw_unit} of '{title}' to the shopping list.",
                action=ActionPayload(
                    action_id=action.id,
                    action_type="add_shopping_item",
                    title=title,
                    details={"unit": raw_unit, "quantity": int(raw_qty)},
                    confirmation_required=True,
                ),
            )

        elif intent == "shopping_checkout":
            pending_items = ShoppingRepository.list_items(session, ctx.household_id, status="pending")
            if not pending_items:
                resp_payload = AssistantResponsePayload(
                    type="text",
                    message="There are currently no pending shopping items to checkout.",
                )
            else:
                raw_payer = entities.get("payer")
                payer_mem = None
                if raw_payer:
                    payer_mem = (
                        member_name_map.get(str(raw_payer).lower())
                        or member_code_map.get(str(raw_payer).lower())
                    )
                if not payer_mem:
                    payer_mem = members[0]

                item_ids = [i.id for i in pending_items]
                item_names = [i.title for i in pending_items]
                total_paid = entities.get("amount") or "0.00"

                expiry = datetime.now(timezone.utc) + timedelta(minutes=settings.AI_ACTION_EXPIRY_MINUTES)
                action = AssistantPendingAction(
                    conversation_id=conv.id,
                    authenticated_user_id=ctx.user.id,
                    household_id=ctx.household_id,
                    action_type="shopping_checkout",
                    validated_payload={
                        "item_ids": item_ids,
                        "total_paid": str(total_paid),
                        "payer_id": payer_mem.code,
                        "split_members": [m.code for m in members],
                    },
                    status="pending",
                    expires_at=expiry,
                    idempotency_key=str(uuid.uuid4()),
                )
                session.add(action)
                session.flush()

                requires_confirmation = True
                resp_payload = AssistantResponsePayload(
                    type="confirmation_required",
                    message=f"Please confirm checking out {len(item_ids)} shopping items ({', '.join(item_names[:3])}...) paid by {payer_mem.name}.",
                    action=ActionPayload(
                        action_id=action.id,
                        action_type="shopping_checkout",
                        title=f"Checkout ({len(item_ids)} items)",
                        amount=str(total_paid),
                        currency="PKR",
                        payer=payer_mem.name,
                        items=[{"id": i.id, "title": i.title} for i in pending_items],
                        confirmation_required=True,
                    ),
                )

        elif intent == "settle_debt":
            raw_s = entities.get("sender")
            raw_r = entities.get("recipient")
            raw_amt = entities.get("amount")

            sender_mem = (
                member_name_map.get(str(raw_s).lower())
                or member_code_map.get(str(raw_s).lower())
                if raw_s else None
            )
            recipient_mem = (
                member_name_map.get(str(raw_r).lower())
                or member_code_map.get(str(raw_r).lower())
                if raw_r else None
            )

            if not sender_mem or not recipient_mem or not raw_amt:
                resp_payload = AssistantResponsePayload(
                    type="text",
                    message="Please specify who is paying whom and the settlement amount (e.g., 'Settle 250 from Ayesha to Ali').",
                )
            elif sender_mem.id == recipient_mem.id:
                resp_payload = AssistantResponsePayload(
                    type="text",
                    message="A member cannot settle with themselves.",
                )
            else:
                amt_paisa = parse_pkr(raw_amt)
                expiry = datetime.now(timezone.utc) + timedelta(minutes=settings.AI_ACTION_EXPIRY_MINUTES)
                action = AssistantPendingAction(
                    conversation_id=conv.id,
                    authenticated_user_id=ctx.user.id,
                    household_id=ctx.household_id,
                    action_type="settle_debt",
                    validated_payload={
                        "sender_id": sender_mem.code,
                        "recipient_id": recipient_mem.code,
                        "amount": str(format_pkr(amt_paisa)),
                    },
                    status="pending",
                    expires_at=expiry,
                    idempotency_key=str(uuid.uuid4()),
                )
                session.add(action)
                session.flush()

                requires_confirmation = True
                resp_payload = AssistantResponsePayload(
                    type="confirmation_required",
                    message=f"Please confirm debt settlement of PKR {format_pkr(amt_paisa)} from {sender_mem.name} to {recipient_mem.name}.",
                    action=ActionPayload(
                        action_id=action.id,
                        action_type="settle_debt",
                        amount=str(format_pkr(amt_paisa)),
                        currency="PKR",
                        details={"sender": sender_mem.name, "recipient": recipient_mem.name},
                        confirmation_required=True,
                    ),
                )

        elif intent == "clarification_needed":
            resp_payload = AssistantResponsePayload(
                type="text",
                message=ai_result.get("message") or "Could you please provide more details?",
            )
        else:
            resp_payload = AssistantResponsePayload(
                type="text",
                message=ai_result.get("message") or (
                    "Assalam-o-Alaikum! I can help you check monthly budgets, view balances, "
                    "add shared expenses, manage shopping items, and settle debts. What would you like to do?"
                ),
            )

        # 6. Persist assistant response message
        asst_msg = AssistantMessage(
            conversation_id=conv.id,
            role="assistant",
            content=resp_payload.message,
            metadata_json={"type": resp_payload.type, "requires_confirmation": requires_confirmation},
        )
        session.add(asst_msg)
        session.commit()

        return ChatResponse(
            success=True,
            conversation_id=conv.id,
            response=resp_payload,
            requires_confirmation=requires_confirmation,
        )

    @staticmethod
    def confirm_action(
        session: Session,
        ctx: Context,
        payload: ConfirmRequest,
    ) -> ConfirmResponse:
        """
        Executes or rejects a proposed pending action after explicit user confirmation.
        Enforces single-use, expiration, and caller authorization.
        """
        if not ctx.user:
            raise ForbiddenError("User is not authenticated.")
        if not ctx.household_id:
            raise NotFoundError("User is not associated with any household.")

        action = (
            session.query(AssistantPendingAction)
            .filter_by(id=payload.action_id)
            .first()
        )
        if not action or action.conversation_id != payload.conversation_id:
            raise NotFoundError("Action proposal not found in this conversation.")

        if action.household_id != ctx.household_id or action.authenticated_user_id != ctx.user.id:
            raise NotFoundError("Action proposal not found in authorized household.")

        if action.status != "pending":
            raise ValidationAppError(f"Action cannot be processed because it is already '{action.status}'.")

        now_utc = datetime.now(timezone.utc)
        if action.expires_at.replace(tzinfo=timezone.utc) < now_utc:
            action.status = "expired"
            session.commit()
            raise ValidationAppError("Action proposal has expired. Please make a new request.")

        if not payload.confirmed:
            action.status = "rejected"
            session.commit()

            asst_msg = AssistantMessage(
                conversation_id=payload.conversation_id,
                role="assistant",
                content="Action proposal was cancelled by user.",
                metadata_json={"type": "action_rejected"},
            )
            session.add(asst_msg)
            session.commit()

            return ConfirmResponse(
                success=True,
                conversation_id=payload.conversation_id,
                response=AssistantResponsePayload(
                    type="action_rejected",
                    message="Action was cancelled by user.",
                ),
                requires_confirmation=False,
            )

        # Execute through existing business services!
        result_data: Any = None
        success_message = ""

        if action.action_type == "create_expense":
            exp_create = ExpenseCreate(**action.validated_payload)
            result_data = ExpenseService.create_expense(
                session=session,
                ctx=ctx,
                payload=exp_create,
                idempotency_key=action.idempotency_key,
            )
            success_message = (
                f"Expense of PKR {result_data['amount']:,.2f} for '{result_data['title']}' "
                f"was successfully recorded!"
            )

        elif action.action_type == "add_shopping_item":
            shop_create = ShoppingItemCreate(**action.validated_payload)
            result_data = ShoppingService.create_shopping_item(
                session=session,
                ctx=ctx,
                payload=shop_create,
                idempotency_key=action.idempotency_key,
            )
            success_message = (
                f"Item '{result_data['title']}' ({result_data['requested_qty']} {result_data['unit']}) "
                f"was added to the shopping list."
            )

        elif action.action_type == "shopping_checkout":
            chk_request = CheckoutRequest(**action.validated_payload)
            result_data = CheckoutService.checkout(
                session=session,
                ctx=ctx,
                payload=chk_request,
                idempotency_key=action.idempotency_key,
            )
            success_message = (
                f"Shopping checkout completed for PKR {result_data['amount']:,.2f}!"
            )

        elif action.action_type == "settle_debt":
            settle_create = SettlementCreate(**action.validated_payload)
            result_data = SettlementService.create_settlement(
                session=session,
                ctx=ctx,
                payload=settle_create,
                idempotency_key=action.idempotency_key,
            )
            success_message = (
                f"Settlement of PKR {result_data['amount']:,.2f} was successfully recorded."
            )
        else:
            raise ValidationAppError(f"Unsupported action type: {action.action_type}")

        action.status = "confirmed"
        action.executed_at = func.now()

        AuditRepository.record_audit(
            session=session,
            household_id=ctx.household_id,
            user_id=ctx.user.id,
            action=f"assistant_{action.action_type}_confirmed",
            entity_type="assistant_action",
            entity_id=action.id,
            payload=action.validated_payload,
        )

        asst_msg = AssistantMessage(
            conversation_id=payload.conversation_id,
            role="assistant",
            content=success_message,
            metadata_json={"type": "action_success", "action_id": action.id},
        )
        session.add(asst_msg)
        session.commit()

        return ConfirmResponse(
            success=True,
            conversation_id=payload.conversation_id,
            response=AssistantResponsePayload(
                type="action_success",
                message=success_message,
                data=result_data,
            ),
            requires_confirmation=False,
        )

    @staticmethod
    def list_conversations(session: Session, ctx: Context) -> List[ConversationSummary]:
        if not ctx.user or not ctx.household_id:
            raise NotFoundError("User not associated with a household.")

        convs = (
            session.query(AssistantConversation)
            .filter_by(authenticated_user_id=ctx.user.id, household_id=ctx.household_id)
            .order_by(AssistantConversation.updated_at.desc())
            .all()
        )
        return [
            ConversationSummary(
                id=c.id,
                title=c.title,
                created_at=c.created_at,
                updated_at=c.updated_at,
                message_count=len(c.messages),
            )
            for c in convs
        ]

    @staticmethod
    def get_conversation_detail(session: Session, ctx: Context, conversation_id: str) -> ConversationDetail:
        if not ctx.user or not ctx.household_id:
            raise NotFoundError("User not associated with a household.")

        c = session.query(AssistantConversation).filter_by(id=conversation_id).first()
        if not c or c.household_id != ctx.household_id or c.authenticated_user_id != ctx.user.id:
            raise NotFoundError("Conversation not found in authorized household.")

        return ConversationDetail(
            id=c.id,
            title=c.title,
            created_at=c.created_at,
            updated_at=c.updated_at,
            messages=[
                ConversationMessage(
                    id=m.id,
                    role=m.role,
                    content=m.content,
                    metadata=m.metadata_json,
                    created_at=m.created_at,
                )
                for m in c.messages
            ],
        )

    @staticmethod
    def create_conversation(session: Session, ctx: Context, title: Optional[str] = None) -> ConversationSummary:
        if not ctx.user or not ctx.household_id:
            raise NotFoundError("User not associated with a household.")

        conv = AssistantConversation(
            authenticated_user_id=ctx.user.id,
            household_id=ctx.household_id,
            title=(title or "New Chat").strip(),
        )
        session.add(conv)
        session.commit()
        session.refresh(conv)

        return ConversationSummary(
            id=conv.id,
            title=conv.title,
            created_at=conv.created_at,
            updated_at=conv.updated_at,
            message_count=0,
        )
