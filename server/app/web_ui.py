"""Serve the built PWA from web/dist. API routes stay on the FastAPI app."""

from __future__ import annotations

import os
from pathlib import Path

from fastapi import FastAPI
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles

INDEX_CACHE = {"Cache-Control": "no-cache"}


def web_dist() -> Path | None:
    candidates: list[Path] = []
    override = os.environ.get("DISCIPLINA_WEB_DIST")
    if override:
        candidates.append(Path(override))
    here = Path(__file__).resolve()
    candidates.append(here.parents[2] / "web" / "dist")
    candidates.append(here.parents[1] / "web")
    for path in candidates:
        if (path / "index.html").is_file():
            return path
    return None


def mount_web(app: FastAPI) -> None:
    dist = web_dist()
    if dist is None:

        @app.get("/", include_in_schema=False)
        def root() -> dict:
            return {
                "name": "Дисциплина",
                "health": "/health",
                "docs": "/docs",
                "openapi": "/openapi.json",
            }

        return

    index = dist / "index.html"

    @app.get("/", include_in_schema=False)
    def spa() -> FileResponse:
        return FileResponse(index, headers=INDEX_CACHE)

    assets = dist / "assets"
    if assets.is_dir():
        app.mount("/assets", StaticFiles(directory=assets), name="web-assets")
    for folder in ("fonts", "icons", "splash"):
        folder_path = dist / folder
        if folder_path.is_dir():
            app.mount(f"/{folder}", StaticFiles(directory=folder_path), name=f"web-{folder}")

    extras = {
        "sw.js": "application/javascript",
        "manifest.webmanifest": "application/manifest+json",
        "demo-snapshot.json": "application/json",
    }

    def _serve(path: Path, media_type: str, cache: bool):
        def _file() -> FileResponse:
            headers = {} if cache else {"Cache-Control": "no-cache"}
            return FileResponse(path, media_type=media_type, headers=headers)

        return _file

    for name, media_type in extras.items():
        path = dist / name
        if path.is_file():
            app.add_api_route(
                f"/{name}",
                _serve(path, media_type, name != "sw.js"),
                methods=["GET"],
                include_in_schema=False,
            )
