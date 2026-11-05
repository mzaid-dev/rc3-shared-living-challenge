import re
from typing import Any, Dict, List, Optional

class RuleBasedIntentParser:
    """
    High-speed deterministic intent parser and entity extractor for Hisab.
    Provides offline parsing, unit test predictability, and fallback capability.
    """

    @staticmethod
    def parse(message: str, members: List[Dict[str, Any]], active_member_name: Optional[str] = None) -> Dict[str, Any]:
        msg = message.strip()
        msg_lower = msg.lower()
        member_names = [m.get("name", "").lower() for m in members if m.get("name")]
        member_name_map = {m.get("name", "").lower(): m.get("name") for m in members if m.get("name")}
        member_codes = [m.get("code", "").lower() for m in members if m.get("code")]

        # 1. Budget Information
        if any(k in msg_lower for k in ["how much did we spend", "total spend", "spending this month", "budget", "remaining budget", "utilization"]):
            return {
                "intent": "get_budget",
                "confidence": 0.95,
                "entities": {},
                "message": "Retrieving your household monthly budget summary.",
            }

        # 2. Settlement Suggestions / Simplification
        if any(k in msg_lower for k in ["settlement suggestion", "suggest settlement", "simplify debt", "minimum transfer", "smart settle", "how to settle"]):
            return {
                "intent": "get_settlement_suggestions",
                "confidence": 0.95,
                "entities": {},
                "message": "Generating simplified settlement suggestions.",
            }

        # 3. Settle Debt Mutation
        # e.g., "Settle 250 from Ayesha to Ali", "Record settlement of 500 PKR from Bilal to Ali"
        settle_match = re.search(r"settle(?:ment)?\s+(?:of\s+)?(?:pkr\s*)?(\d+(?:\.\d+)?)\s*(?:pkr)?\s+from\s+([a-zA-Z0-9_]+)\s+to\s+([a-zA-Z0-9_]+)", msg, re.IGNORECASE)
        if settle_match:
            amt, s_name, r_name = settle_match.groups()
            return {
                "intent": "settle_debt",
                "confidence": 0.95,
                "entities": {
                    "amount": amt,
                    "sender": s_name,
                    "recipient": r_name,
                },
                "message": f"Settling PKR {amt} from {s_name} to {r_name}.",
            }

        # 4. Member Balances
        if any(k in msg_lower for k in ["balance", "who owes", "who receives", "my share", "net balance", "who owes whom"]):
            target_mem = None
            for name in member_names:
                if name in msg_lower:
                    target_mem = member_name_map[name]
                    break
            return {
                "intent": "get_balances",
                "confidence": 0.95,
                "entities": {"member": target_mem},
                "message": f"Fetching household balance records{f' for {target_mem}' if target_mem else ''}.",
            }

        # 5. Shopping Checkout
        if "checkout" in msg_lower:
            payer = None
            for name in member_names:
                if f"paid by {name}" in msg_lower or f"by {name}" in msg_lower:
                    payer = member_name_map[name]
                    break
            return {
                "intent": "shopping_checkout",
                "confidence": 0.90,
                "entities": {
                    "payer": payer,
                },
                "message": "Preparing shopping checkout proposal.",
            }

        # 6. Add Shopping Item
        add_shop_match = re.search(r"add\s+(\d+)?\s*(bottles?|packs?|dozens?|bags?|kg|litres?|liters?)?\s*(?:of\s+)?([a-zA-Z0-9\s\-]+?)\s*(?:to\s+(?:the\s+)?shopping\s*(?:list)?|$)", msg, re.IGNORECASE)
        if ("shopping" in msg_lower or "buy" in msg_lower) and ("add" in msg_lower or "need" in msg_lower):
            raw_qty = "1"
            raw_unit = "pack"
            raw_title = msg

            if add_shop_match:
                g1, g2, g3 = add_shop_match.groups()
                if g1:
                    raw_qty = g1
                if g2:
                    clean_u = g2.lower().rstrip("s")
                    if clean_u in ["bottle", "pack", "dozen", "bag"]:
                        raw_unit = clean_u
                    elif clean_u in ["kg"]:
                        raw_unit = "bag"
                    elif clean_u in ["litre", "liter"]:
                        raw_unit = "bottle"
                if g3:
                    raw_title = re.sub(r"^(?:of\s+)", "", g3.strip(), flags=re.IGNORECASE).strip()
            else:
                cleaned = re.sub(r"(?i)\b(add|to|the|shopping|list|please|of)\b", "", msg).strip()
                if cleaned:
                    raw_title = cleaned

            title_lower = raw_title.lower()
            if "milk" in title_lower or "water" in title_lower or "oil" in title_lower or "coke" in title_lower or "juice" in title_lower:
                if raw_unit not in ["bottle", "pack"]:
                    raw_unit = "bottle"
            elif "egg" in title_lower:
                raw_unit = "dozen"
            elif "rice" in title_lower or "flour" in title_lower or "sugar" in title_lower or "atta" in title_lower:
                raw_unit = "bag"

            return {
                "intent": "add_shopping_item",
                "confidence": 0.92,
                "entities": {
                    "title": raw_title.capitalize(),
                    "quantity": int(raw_qty) if raw_qty.isdigit() else 1,
                    "unit": raw_unit,
                },
                "message": f"Adding {raw_qty} {raw_unit} of {raw_title} to shopping list.",
            }

        # 7. Shopping List Retrieval
        if any(k in msg_lower for k in ["shopping list", "what to buy", "pending items", "shopping items", "grocery list"]):
            return {
                "intent": "get_shopping_list",
                "confidence": 0.95,
                "entities": {},
                "message": "Retrieving current household shopping list.",
            }

        # 8. List Recent Expenses (checked before create_expense to avoid misclassification)
        if any(k in msg_lower for k in ["recent expenses", "expense history", "show expenses", "past expenses", "what did we pay", "view expenses", "show our recent expenses"]):
            return {
                "intent": "get_expenses",
                "confidence": 0.90,
                "entities": {},
                "message": "Loading recent household expenses.",
            }

        # 9. Create Expense Mutation
        exp_amount_match = re.search(r"(?:pkr\s*)?(\d+(?:\.\d+)?)\s*(?:pkr)?", msg, re.IGNORECASE)
        is_expense_request = any(k in msg_lower for k in ["expense", "paid", "split", "cost", "spent"]) or (exp_amount_match and "add" in msg_lower)
        if is_expense_request:
            amount = exp_amount_match.group(1) if exp_amount_match else None
            
            payer = None
            for name in member_names:
                if f"paid by {name}" in msg_lower or f"by {name}" in msg_lower:
                    payer = member_name_map[name]
                    break
            if not payer:
                for name in member_names:
                    if re.search(rf"\b{name}\b", msg_lower):
                        payer = member_name_map[name]
                        break

            title = "Shared Expense"
            title_clean = msg
            title_clean = re.sub(r"(?i)\b(add|record|expense|pkr|\d+(?:\.\d+)?|paid|by|and|split|equally|for)\b", " ", title_clean)
            for name in member_names:
                title_clean = re.sub(rf"(?i)\b{name}\b", " ", title_clean)
            title_clean = " ".join(title_clean.split()).strip()
            if len(title_clean) > 2:
                title = title_clean.title()

            split_type = "equal"
            if "custom" in msg_lower:
                split_type = "custom"

            if not amount:
                return {
                    "intent": "clarification_needed",
                    "confidence": 0.85,
                    "entities": {"missing_field": "amount"},
                    "message": "How much was the expense amount in PKR?",
                }

            return {
                "intent": "create_expense",
                "confidence": 0.92,
                "entities": {
                    "title": title,
                    "amount": amount,
                    "payer": payer or (active_member_name or (members[0].get("name") if members else "Ali")),
                    "split_type": split_type,
                    "participants": [m.get("name") for m in members],
                },
                "message": f"Creating {split_type} expense of PKR {amount} for '{title}'.",
            }

        # 10. General Greeting / Fallback
        if any(k in msg_lower for k in ["hello", "hi", "salam", "assalam", "hey", "help"]):
            return {
                "intent": "general_help",
                "confidence": 0.99,
                "entities": {},
                "message": (
                    "Assalam-o-Alaikum! I am your Hisab Assistant. You can ask me:\n"
                    "• 'How much did we spend this month?'\n"
                    "• 'Show member balances' or 'Who owes whom?'\n"
                    "• 'Add 1500 PKR groceries paid by Ali and split equally'\n"
                    "• 'Add 2 bottles of milk to the shopping list'\n"
                    "• 'Suggest settlement' or 'Show shopping list'"
                ),
            }

        return {
            "intent": "general_help",
            "confidence": 0.50,
            "entities": {},
            "message": "I can help with household expenses, monthly budget, member balances, shopping list, and settlements. What would you like to do?",
        }

