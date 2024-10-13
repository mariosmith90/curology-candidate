FROM ubuntu:latest

## These values are supplied within our containerized environment. Terraform defines these variables and ####
## are exported for our application to consume within ECS during runtime. ###################################
ENV DB_NAME=${DB_NAME}
ENV DB_USER=${DB_USER}
ENV DB_HOST=${DB_HOST}
ENV DB_PASSWORD=${DB_PASSWORD}

### This is where we load the appropriate python dependencies necessary for this application's function #####
### We can further enhance this by supplying our own base image containing these and other dependencies #####
RUN apt-get update && apt-get install -y python3 python3-pip python3-venv libpq-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN python3 -m venv venv
ENV PATH="/app/venv/bin:$PATH"

COPY . .
RUN pip install --no-cache-dir -r requirements.txt

EXPOSE 3000
#### Following best practice, gunicorn is used for production servers. Gevent is added to support aynchronous connection ####
##### Log levels are set appropriately to ensure we have adequate visibility in to the behavior of our application ##########
CMD ["gunicorn", "--worker-class", "gevent", "--workers", "4", "--log-level", "info", "--bind", "0.0.0.0:3000", "helloworld:app"]
