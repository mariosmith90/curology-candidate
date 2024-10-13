FROM ubuntu:latest

ENV DB_NAME=${DB_NAME}
ENV DB_USER=${DB_USER}
ENV DB_HOST=${DB_HOST}
ENV DB_PASSWORD=${DB_PASSWORD}

RUN apt-get update && apt-get install -y python3 python3-pip python3-venv libpq-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN python3 -m venv venv
ENV PATH="/app/venv/bin:$PATH"

COPY . .
RUN pip install --no-cache-dir -r requirements.txt

EXPOSE 3000
# Use Gunicorn to run the Flask app in production
CMD ["gunicorn", "--worker-class", "gevent", "--workers", "4", "--log-level", "info", "--bind", "0.0.0.0:3000", "helloworld:app"]
