FROM dart:stable

RUN apt-get update \
	&& apt-get install -y --no-install-recommends libsqlite3-dev \
	&& rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . .

RUN dart pub get

CMD ["sh", "-c", "dart bin/main.dart server --host 0.0.0.0 --port ${PORT:-8080}"]