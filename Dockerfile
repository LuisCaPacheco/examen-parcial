# Imagen minima para el taller 5 - THE ODYSSEY
# Alpine: superficie minima -> Trivy HIGH,CRITICAL limpio (Debian trae CVEs sin fix)
FROM python:3.12-alpine

RUN adduser -D appuser
WORKDIR /app

COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app/app.py .

ENV APP_VERSION="1.0.0-stable"
ENV SHOULD_FAIL="false"
ENV PORT="8080"

USER appuser
EXPOSE 8080

# Healthcheck nativo de Docker (usado tambien por el workflow)
HEALTHCHECK --interval=15s --timeout=5s --retries=3 CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/health').read()" || exit 1

CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "--timeout", "30", "app:app"]
