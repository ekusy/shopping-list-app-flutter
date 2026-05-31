# JDK 21 を含むベースイメージ（AGP 9.x が要求）。Ubuntu noble = 24.04 LTS。
FROM eclipse-temurin:21-jdk-noble

ARG FLUTTER_VERSION=3.44.0
# Android command-line tools のビルド番号。
# 最新は https://developer.android.com/studio#command-line-tools-only 参照。
ARG ANDROID_CMDLINE_TOOLS_VERSION=11076708
# プリインストールするプラットフォーム / build-tools。
# Gradle は必要に応じて追加バージョンを自動 DL するので、起点だけ用意しておく。
ARG ANDROID_PLATFORM=35
ARG ANDROID_BUILD_TOOLS=35.0.0

RUN apt-get update && apt-get install -y --no-install-recommends \
        bash curl git unzip xz-utils zip ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Flutter SDK（git clone でバージョン固定）
ENV FLUTTER_HOME=/opt/flutter
ENV PATH="${FLUTTER_HOME}/bin:${PATH}"
RUN git clone --depth 1 --branch ${FLUTTER_VERSION} \
        https://github.com/flutter/flutter.git "${FLUTTER_HOME}" \
    && flutter config --no-analytics --no-cli-animations

# Android SDK（command-line tools 経由でヘッドレス導入）
ENV ANDROID_HOME=/opt/android-sdk
ENV ANDROID_SDK_ROOT=${ANDROID_HOME}
ENV PATH="${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${PATH}"
RUN mkdir -p ${ANDROID_HOME}/cmdline-tools \
    && curl -fsSL -o /tmp/cmdtools.zip \
        "https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS_VERSION}_latest.zip" \
    && unzip -q /tmp/cmdtools.zip -d ${ANDROID_HOME}/cmdline-tools \
    && mv ${ANDROID_HOME}/cmdline-tools/cmdline-tools ${ANDROID_HOME}/cmdline-tools/latest \
    && rm /tmp/cmdtools.zip \
    && yes | sdkmanager --licenses > /dev/null \
    && sdkmanager --install \
        "platform-tools" \
        "platforms;android-${ANDROID_PLATFORM}" \
        "build-tools;${ANDROID_BUILD_TOOLS}"

# Flutter 用アーティファクトを事前 DL（web + android のみ）
RUN flutter precache --web --android \
        --no-linux --no-macos --no-windows --no-ios --no-fuchsia

# Firebase CLI
RUN curl -sL https://firebase.tools | bash

WORKDIR /app

COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["bash"]
