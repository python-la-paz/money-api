# ---------- Build stage for PyTorch CPU-only + EasyOCR models ----------
FROM public.ecr.aws/lambda/python:3.12 AS builder

# Install system libs needed to build opencv / numpy wheels
RUN dnf install -y mesa-libGL gcc gcc-c++ && dnf clean all

COPY app/requirements.txt /tmp/requirements.txt

# Install CPU-only PyTorch first (avoids pulling CUDA – saves ~1.5 GB)
RUN pip install --no-cache-dir \
    torch torchvision --index-url https://download.pytorch.org/whl/cpu

# Install the rest of the dependencies
RUN pip install --no-cache-dir -r /tmp/requirements.txt
RUN pip install --no-cache-dir mangum

# Pre-download EasyOCR model files so cold starts don't hit the network
RUN python -c "import easyocr; easyocr.Reader(['en'], gpu=False, verbose=False)"

# ---------- Final image ----------
FROM public.ecr.aws/lambda/python:3.12

# Runtime lib for OpenCV
RUN dnf install -y mesa-libGL && dnf clean all

# Copy installed packages from builder
COPY --from=builder /var/lang/lib/python3.12/site-packages \
    /var/lang/lib/python3.12/site-packages

# Copy pre-downloaded EasyOCR models
COPY --from=builder /root/.EasyOCR /root/.EasyOCR

# Copy application code
COPY app/ ${LAMBDA_TASK_ROOT}/money_api/

# Lambda handler entry point
CMD ["money_api.lambda_handler.handler"]
