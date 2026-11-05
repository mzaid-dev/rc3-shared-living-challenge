from contextlib import asynccontextmanager
import json
from json.decoder import JSONDecodeError
import uuid
from typing import Any

from fastapi import FastAPI, Request, Response
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy import text
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.core.config import settings
from app.core.errors import (
    AppError,
    MalformedJsonError,
    domain_to_app_error,
)
from app.core.logging import logger
from app.core.ratelimit import limiter
from app.db.base import Base
from app.db.seed import seed_demo_data
from app.db.session import SessionLocal, engine
from app.domain.exceptions import DomainError
from app.routers import (
    assistant,
    audit,
    auth,
    balances,
    budget,
    checkout,
    dashboard,
    expenses,
    households,
    members,
    settle,
    shopping,
)
from slowapi.errors import RateLimitExceeded

@asynccontextmanager
async def lifespan(app: FastAPI):
    if settings.ENV == "production" and not settings.AUTH_ENABLED:
        raise RuntimeError("FATAL: AUTH_ENABLED cannot be False in production environment.")
    # Initialize all database tables on startup
    Base.metadata.create_all(bind=engine)
    if settings.SEED_DEMO:
        with SessionLocal() as session:
            seed_demo_data(session)
    yield

app = FastAPI(
    title=settings.PROJECT_NAME,
    lifespan=lifespan,
    docs_url="/docs" if (settings.ENV != "production" or settings.DOCS_ENABLED) else None,
    redoc_url="/redoc" if (settings.ENV != "production" or settings.DOCS_ENABLED) else None,
    openapi_url="/openapi.json" if (settings.ENV != "production" or settings.DOCS_ENABLED) else None,
)
app.state.limiter = limiter

Base.metadata.create_all(bind=engine)
if settings.SEED_DEMO:
    with SessionLocal() as _init_session:
        seed_demo_data(_init_session)

# CORS Configuration
if settings.CORS_ORIGINS:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.CORS_ORIGINS,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

# 0. Rate Limit Error Handler
@app.exception_handler(RateLimitExceeded)
async def rate_limit_handler(request: Request, exc: RateLimitExceeded):
    req_id = getattr(request.state, "request_id", "unknown")
    res = JSONResponse(
        status_code=429,
        content={
            "error": {
                "code": "RATE_LIMITED",
                "message": "Too many requests. Please slow down.",
            }
        },
    )
    res.headers["X-Request-ID"] = req_id
    return res

# 1. Request-ID, Size Limit & Security Headers Middleware
@app.middleware("http")
async def security_and_request_middleware(request: Request, call_next):
    req_id = request.headers.get("X-Request-ID")
    if not req_id:
        req_id = str(uuid.uuid4())
    request.state.request_id = req_id

    # Check for oversized payload (> 64 KB limit)
    content_length = request.headers.get("content-length")
    if content_length:
        try:
            if int(content_length) > settings.MAX_REQUEST_BODY_BYTES:
                res = JSONResponse(
                    status_code=413,
                    content={
                        "error": {
                            "code": "PAYLOAD_TOO_LARGE",
                            "message": f"Request payload exceeds maximum allowed size of {settings.MAX_REQUEST_BODY_BYTES // 1024} KB.",
                        }
                    },
                )
                res.headers["X-Request-ID"] = req_id
                return res
        except ValueError:
            pass

    # Check for body decode errors on JSON requests
    if request.method in ("POST", "PUT", "PATCH"):
        content_type = request.headers.get("content-type", "")
        if "application/json" in content_type:
            try:
                body = await request.body()
                if len(body) > settings.MAX_REQUEST_BODY_BYTES:
                    res = JSONResponse(
                        status_code=413,
                        content={
                            "error": {
                                "code": "PAYLOAD_TOO_LARGE",
                                "message": f"Request payload exceeds maximum allowed size of {settings.MAX_REQUEST_BODY_BYTES // 1024} KB.",
                            }
                        },
                    )
                    res.headers["X-Request-ID"] = req_id
                    return res
                if body:
                    json.loads(body)
            except JSONDecodeError as err:
                response_content = {
                    "error": {
                        "code": "MALFORMED_JSON",
                        "message": f"Malformed JSON payload: {str(err)}",
                    }
                }
                res = JSONResponse(status_code=400, content=response_content)
                res.headers["X-Request-ID"] = req_id
                return res

    response: Response = await call_next(request)

    # Security & Tracking Headers
    response.headers["X-Request-ID"] = req_id
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"

    # Anti-caching for authentication endpoints
    if request.url.path.startswith("/api/auth"):
        response.headers["Cache-Control"] = "no-store, no-cache, must-revalidate"
        response.headers["Pragma"] = "no-cache"

    return response

# 2. Uniform Error Envelope Handlers (Hard Rule 6)
@app.exception_handler(AppError)
async def app_error_handler(request: Request, exc: AppError):
    req_id = getattr(request.state, "request_id", "unknown")
    logger.warning(f"[{req_id}] AppError: code={exc.code} status={exc.status_code} msg={exc.message}")
    res = JSONResponse(
        status_code=exc.status_code,
        content=exc.to_envelope(),
    )
    res.headers["X-Request-ID"] = req_id
    return res

@app.exception_handler(DomainError)
async def domain_error_handler(request: Request, exc: DomainError):
    app_err = domain_to_app_error(exc)
    req_id = getattr(request.state, "request_id", "unknown")
    logger.warning(f"[{req_id}] DomainError mapped to {app_err.code}: {app_err.message}")
    res = JSONResponse(
        status_code=app_err.status_code,
        content=app_err.to_envelope(),
    )
    res.headers["X-Request-ID"] = req_id
    return res

@app.exception_handler(RequestValidationError)
async def validation_error_handler(request: Request, exc: RequestValidationError):
    req_id = getattr(request.state, "request_id", "unknown")
    field_errors = []
    for err in exc.errors():
        loc = ".".join(str(l) for l in err.get("loc", []) if l != "body")
        field_errors.append({
            "field": loc or "body",
            "issue": err.get("msg", "Invalid value"),
        })

    logger.warning(f"[{req_id}] RequestValidationError: {field_errors}")
    res = JSONResponse(
        status_code=422,
        content={
            "error": {
                "code": "VALIDATION_ERROR",
                "message": "Request payload validation failed.",
                "fields": field_errors,
            }
        },
    )
    res.headers["X-Request-ID"] = req_id
    return res

@app.exception_handler(StarletteHTTPException)
async def http_exception_handler(request: Request, exc: StarletteHTTPException):
    req_id = getattr(request.state, "request_id", "unknown")
    code_map = {
        400: "MALFORMED_JSON",
        401: "INVALID_CREDENTIALS",
        403: "FORBIDDEN",
        404: "NOT_FOUND",
        405: "METHOD_NOT_ALLOWED",
        409: "ITEM_ALREADY_BOUGHT",
        422: "VALIDATION_ERROR",
        429: "RATE_LIMITED",
    }
    code = code_map.get(exc.status_code, "INTERNAL_ERROR")
    logger.warning(f"[{req_id}] HTTPException: code={code} status={exc.status_code} detail={exc.detail}")
    res = JSONResponse(
        status_code=exc.status_code,
        content={
            "error": {
                "code": code,
                "message": str(exc.detail),
            }
        },
    )
    res.headers["X-Request-ID"] = req_id
    return res

@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception):
    # Log full traceback server-side with request_id; NEVER leak stack traces to client!
    req_id = getattr(request.state, "request_id", "unknown")
    logger.error(f"[{req_id}] Unhandled Exception: {exc}", exc_info=True)
    res = JSONResponse(
        status_code=500,
        content={
            "error": {
                "code": "INTERNAL_ERROR",
                "message": "An internal server error occurred.",
            }
        },
    )
    res.headers["X-Request-ID"] = req_id
    return res

# Mount Routers
app.include_router(auth.router)
app.include_router(households.router)
app.include_router(members.router)
app.include_router(shopping.router)
app.include_router(checkout.router)
app.include_router(expenses.router)
app.include_router(balances.router)
app.include_router(settle.router)
app.include_router(budget.router)
app.include_router(dashboard.router)
app.include_router(audit.router)
app.include_router(assistant.router)

# Foundation Endpoints
@app.get("/", tags=["Root"])
def root():
    """Root welcome endpoint with service status and documentation links."""
    return {
        "message": "RC3 Shared Living API is running",
        "status": "online",
        "docs": "/docs",
        "health": "/health",
        "version": "1.0.0",
    }

@app.get("/health")
def health_check():
    """System health check endpoint verifying database connectivity."""
    with SessionLocal() as session:
        session.execute(text("SELECT 1"))
    return {"status": "ok", "database": "ok"}
