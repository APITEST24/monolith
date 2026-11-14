import os
import tempfile
from pathlib import Path

_db = Path(tempfile.mkdtemp(prefix="disciplina-")) / "test.db"
os.environ["DISCIPLINA_DB_PATH"] = str(_db)
os.environ["DISCIPLINA_IOS_API_KEY"] = "test-ios"
os.environ["DISCIPLINA_BOT_API_KEY"] = "test-bot"
os.environ["DISCIPLINA_HOST"] = "127.0.0.1"
os.environ["DISCIPLINA_PORT"] = "8741"

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.seed import reset_and_seed

IOS = {"X-API-Key": "test-ios"}
BOT = {"X-API-Key": "test-bot"}


@pytest.fixture
def client():
    reset_and_seed()
    with TestClient(app) as test_client:
        yield test_client
