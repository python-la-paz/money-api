FROM python:3.12-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends libgl1 libglib2.0-0 && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY app/requirements.txt .
RUN pip install --no-cache-dir torch torchvision  --index-url https://download.pytorch.org/whl/cpu && \
    pip install --no-cache-dir -r requirements.txt

# Pre-download EasyOCR models into a fixed path inside the image
ENV EASYOCR_MODEL_DIR=/app/models
RUN mkdir -p $EASYOCR_MODEL_DIR && \
    python -c "import easyocr; easyocr.Reader(['en'], gpu=False, verbose=False, model_storage_directory='/app/models')"

COPY app/ .

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
