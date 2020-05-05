FROM openjdk:8-jdk-alpine AS build
WORKDIR /build
RUN apk add p7zip git bash
RUN git clone https://github.com/HeikkiKangas/Blog.git
WORKDIR /build/Blog
RUN git submodule update --init --recursive
RUN chmod +x package.sh
RUN cat package.sh
RUN ["/bin/bash", "-c", "./package.sh"]

FROM openjdk:8-jre-alpine
WORKDIR /app
COPY --from=build /build/Blog/blog-release.jar /app/blog-release.jar
CMD ["java", "-jar", "blog-release.jar"]