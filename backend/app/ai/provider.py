from abc import ABC, abstractmethod
import json
from typing import Any, Dict, List, Optional
import httpx
from langchain_core.output_parsers import JsonOutputParser
from langchain_core.runnables import RunnableLambda

from app.ai.parser import RuleBasedIntentParser
from app.ai.prompts import build_system_prompt
from app.core.config import settings
from app.core.logging import logger

class BaseLLMProvider(ABC):
    @abstractmethod
    async def extract_intent_and_entities(
        self,
        message: str,
        members: List[Dict[str, Any]],
        active_member: Optional[str] = None,
        conversation_history: Optional[List[Dict[str, str]]] = None,
    ) -> Dict[str, Any]:
        """Analyzes user message and extracts structured intent and parameters."""
        pass

class LangChainMockProvider(BaseLLMProvider):
    """
    Deterministic offline LangChain LCEL runnable pipeline.
    Uses RuleBasedIntentParser with JsonOutputParser.
    """
    def __init__(self):
        self.output_parser = JsonOutputParser()

    async def extract_intent_and_entities(
        self,
        message: str,
        members: List[Dict[str, Any]],
        active_member: Optional[str] = None,
        conversation_history: Optional[List[Dict[str, str]]] = None,
    ) -> Dict[str, Any]:
        def _parse_runnable(inputs: Dict[str, Any]) -> str:
            raw_res = RuleBasedIntentParser.parse(
                message=inputs["message"],
                members=inputs["members"],
                active_member_name=inputs.get("active_member"),
            )
            return json.dumps(raw_res)

        runnable = RunnableLambda(_parse_runnable) | self.output_parser
        return await runnable.ainvoke({
            "message": message,
            "members": members,
            "active_member": active_member,
        })

class LangChainOpenAICompatibleProvider(BaseLLMProvider):
    """
    Generic LangChain LCEL pipeline for OpenAI-compatible providers:
    GroqCloud, DeepSeek, Grok (xAI), or OpenAI.
    """
    def __init__(
        self,
        provider_name: str,
        api_key: str,
        base_url: str,
        model: str,
        timeout: int = 15,
    ):
        self.provider_name = provider_name
        self.api_key = api_key
        self.base_url = base_url.rstrip("/")
        self.model = model
        self.timeout = timeout
        self.output_parser = JsonOutputParser()

    async def extract_intent_and_entities(
        self,
        message: str,
        members: List[Dict[str, Any]],
        active_member: Optional[str] = None,
        conversation_history: Optional[List[Dict[str, str]]] = None,
    ) -> Dict[str, Any]:
        if not self.api_key:
            raise ValueError(f"{self.provider_name} API key is not configured.")

        system_prompt = build_system_prompt(members, active_member or "Ali")
        endpoint = f"{self.base_url}/chat/completions"
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
        }
        payload = {
            "model": self.model,
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": message},
            ],
            "temperature": 0.1,
            "response_format": {"type": "json_object"},
        }

        async def _call_api(inputs: Dict[str, Any]) -> str:
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                res = await client.post(endpoint, headers=headers, json=payload)
                if res.status_code != 200:
                    raise RuntimeError(f"{self.provider_name} returned status {res.status_code}: {res.text}")
                data = res.json()
                return data["choices"][0]["message"]["content"]

        chain = RunnableLambda(_call_api) | self.output_parser
        return await chain.ainvoke({
            "system_prompt": system_prompt,
            "user_message": message,
        })

class ResilientLangChainAssistantProvider(BaseLLMProvider):
    """
    Multi-Tier Resilient Provider:
    Tier 1: DeepSeek (when key provided)
    Tier 2: Groq (ultra-fast gpt-oss-120b)
    Tier 3: Grok (xAI)
    Tier 4: Offline Deterministic Parser
    """
    def __init__(self):
        self.mock_fallback = LangChainMockProvider()

    async def extract_intent_and_entities(
        self,
        message: str,
        members: List[Dict[str, Any]],
        active_member: Optional[str] = None,
        conversation_history: Optional[List[Dict[str, str]]] = None,
    ) -> Dict[str, Any]:
        # 1. Primary: DeepSeek (if key configured)
        if settings.DEEPSEEK_API_KEY:
            try:
                deepseek = LangChainOpenAICompatibleProvider(
                    provider_name="DeepSeek",
                    api_key=settings.DEEPSEEK_API_KEY,
                    base_url=settings.DEEPSEEK_BASE_URL,
                    model=settings.DEEPSEEK_MODEL,
                    timeout=settings.AI_TIMEOUT_SECONDS,
                )
                return await deepseek.extract_intent_and_entities(
                    message, members, active_member, conversation_history
                )
            except Exception as e:
                logger.warning(f"DeepSeek call failed: {e}. Falling back to Groq.")

        # 2. Secondary: Groq (configured with active key!)
        if settings.GROQ_API_KEY:
            try:
                groq = LangChainOpenAICompatibleProvider(
                    provider_name="Groq",
                    api_key=settings.GROQ_API_KEY,
                    base_url=settings.GROQ_BASE_URL,
                    model=settings.GROQ_MODEL,
                    timeout=settings.AI_TIMEOUT_SECONDS,
                )
                return await groq.extract_intent_and_entities(
                    message, members, active_member, conversation_history
                )
            except Exception as e:
                logger.warning(f"Groq call failed: {e}. Falling back to deterministic chain.")

        # 3. Tertiary: Grok (xAI)
        if settings.GROK_API_KEY:
            try:
                grok = LangChainOpenAICompatibleProvider(
                    provider_name="Grok",
                    api_key=settings.GROK_API_KEY,
                    base_url=settings.GROK_BASE_URL,
                    model=settings.GROK_MODEL,
                    timeout=settings.AI_TIMEOUT_SECONDS,
                )
                return await grok.extract_intent_and_entities(
                    message, members, active_member, conversation_history
                )
            except Exception as e:
                logger.warning(f"Grok call failed: {e}. Falling back to deterministic chain.")

        # 4. Final Safety Net: Deterministic Parser
        return await self.mock_fallback.extract_intent_and_entities(
            message, members, active_member, conversation_history
        )

def get_llm_provider() -> BaseLLMProvider:
    provider_type = (settings.AI_PROVIDER or "groq").lower().strip()
    if provider_type in ["groq", "deepseek", "grok", "resilient"]:
        return ResilientLangChainAssistantProvider()
    return LangChainMockProvider()
