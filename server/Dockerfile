FROM python:3.12-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app ./app

ENV DISCIPLINA_DB_PATH=/data/disciplina.db \
    DISCIPLINA_HOST=0.0.0.0 \
    DISCIPLINA_PORT=8741

VOLUME ["/data"]
EXPOSE 8741

CMD ["python", "-m", "app"]
