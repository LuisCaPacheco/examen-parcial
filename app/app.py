from flask import Flask, jsonify
import os

app = Flask(__name__)
VERSION = os.getenv("APP_VERSION", "1.0.0-stable")
SHOULD_FAIL = os.getenv("SHOULD_FAIL", "false").lower() == "true"

@app.get("/")
def index():
    return jsonify({
        "service": "the-odyssey-rollback-demo",
        "team": "THE ODYSSEY",
        "version": VERSION,
        "endpoints": ["/health", "/api/hello"]
    })

@app.get("/health")
def health():
    # Prueba de salud: si SHOULD_FAIL=true simula version defectuosa
    if SHOULD_FAIL:
        return jsonify({"status": "fail", "version": VERSION, "reason": "simulated defect"}), 500
    return jsonify({"status": "ok", "version": VERSION})

@app.get("/api/hello")
def hello():
    if SHOULD_FAIL:
        return jsonify({"error": "simulated functional failure"}), 500
    return jsonify({"message": "Hola THE ODYSSEY", "version": VERSION})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
