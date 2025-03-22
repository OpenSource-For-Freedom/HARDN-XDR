FROM python:3.8-slim

RUN apt-get update && apt-get install -y \
    ufw \
    && rm -rf /var/lib/apt/lists/*

# UFW UPDATE
RUN ufw default deny incoming && \
    ufw default allow outgoing && \
    ufw allow 2375/tcp && \
    ufw allow 2376/tcp && \
    ufw --force enable

COPY . /app
WORKDIR /app
RUN pip install --no-cache-dir -r requirements.txt

ENV PYTHONUNBUFFERED=1
ENV NAME Hardn


RUN groupadd -r appuser && useradd -r -g appuser appuser

RUN chown -R root:root /app

# non-root
USER appuser 
EXPOSE 80
CMD ["python", "HARDN.py"]
