FROM debian:bookworm-slim

ARG FLUTTER_VERSION=3.44.0

# Flutter web に必要な最小パッケージ
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash curl git unzip xz-utils zip ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Flutter SDK（git clone でバージョン固定）
ENV FLUTTER_HOME=/opt/flutter
ENV PATH="${FLUTTER_HOME}/bin:${PATH}"
RUN git clone --depth 1 --branch ${FLUTTER_VERSION} \
        https://github.com/flutter/flutter.git "${FLUTTER_HOME}" \
    && flutter config --no-analytics --no-cli-animations \
    && flutter precache --web

# Firebase CLI
RUN curl -sL https://firebase.tools | bash

WORKDIR /app

COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["bash"]
