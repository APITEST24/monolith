import secrets
from dataclasses import dataclass

from fastapi import Depends, HTTPException, Security
from fastapi.security import APIKeyHeader

from app.config import get_settings

api_key_header = APIKeyHeader(name="X-API-Key", auto_error=False)

READ = "read"
WRITE_STATS = "write_stats"
WRITE_SUMMARIES = "write_summaries"
WRITE_ALL = "write_all"

_BOT_ACTIONS = {READ, WRITE_STATS, WRITE_SUMMARIES}


@dataclass
class Principal:
    role: str

    def allows(self, action: str) -> bool:
        if self.role == "ios":
            return True
        return action in _BOT_ACTIONS


def _same(left: str, right: str) -> bool:
    if len(left) != len(right):
        return False
    return secrets.compare_digest(left, right)


def get_principal(key: str | None = Security(api_key_header)) -> Principal:
    if not key:
        raise HTTPException(status_code=401, detail="Нужен заголовок X-API-Key")
    settings = get_settings()
    if _same(key, settings.ios_api_key):
        return Principal(role="ios")
    if _same(key, settings.bot_api_key):
        return Principal(role="bot")
    raise HTTPException(status_code=401, detail="Неверный API-ключ")


def require(action: str):
    def dependency(principal: Principal = Depends(get_principal)) -> Principal:
        if not principal.allows(action):
            raise HTTPException(status_code=403, detail="Этому ключу нельзя выполнять это действие")
        return principal

    return dependency
