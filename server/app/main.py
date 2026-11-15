import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.config import get_settings
from app.routes import router
from app.seed import seed_if_empty
from app.web_ui import mount_web

log = logging.getLogger("disciplina")


@asynccontextmanager
async def lifespan(_app: FastAPI):
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(name)s: %(message)s")
    seed_if_empty()
    if get_settings().using_default_keys:
        log.warning(
            "Используются ключи по умолчанию. Задайте DISCIPLINA_IOS_API_KEY и DISCIPLINA_BOT_API_KEY."
        )
    yield


app = FastAPI(
    title="Дисциплина",
    version="1.0.0",
    summary="Данные и правила личного арбитража трафика",
    description=(
        "Сервер хранит финансы, связки, гео, задачи, журнал решений и правила "
        "и отдаёт приложение Monolith как PWA с корня сайта. "
        "Ключ передаётся в заголовке X-API-Key. "
        "Ключ телефона читает и меняет всё. Ключ бота читает статистику и пишет дневные цифры, "
        "проводки и записи журнала, но не меняет правила."
    ),
    lifespan=lifespan,
)

app.include_router(router)


@app.get("/health", tags=["service"], summary="Проверка, что процесс жив")
def health() -> dict:
    return {"ok": True, "name": "Дисциплина"}


mount_web(app)
