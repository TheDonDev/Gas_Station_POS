# Stage 1: Build Flutter Web
FROM debian:latest AS build-env

RUN apt-get update && apt-get install -y curl git wget unzip xz-utils libglu1-mesa

# Install Flutter
RUN git clone https://github.com/flutter/flutter.git /usr/local/flutter
ENV PATH="/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:${PATH}"
RUN flutter doctor
RUN flutter config --enable-web

WORKDIR /app
COPY . .
RUN flutter build web --release

# Stage 2: Serve with Nginx
FROM nginx:alpine

# Copy the build output from the first stage
COPY --from=build-env /app/build/web /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]