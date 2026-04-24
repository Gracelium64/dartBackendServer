FROM dart:stable

WORKDIR /app
COPY . .

RUN dart pub get

CMD ["dart", "bin/main.dart", "server", "--host", "0.0.0.0", "--port", "${PORT}"]