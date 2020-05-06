#!/bin/bash

PrintPink () {
    printf "%b" "\e[1;35m" "$1" "\e[0m"
}

PrintGreen () {
    printf "%b" "\e[1;36m" "$1" "\e[0m"
}

UpdateRepository () {
    if [[ $(git rev-parse --abbrev-ref HEAD) != 'build' ]]; then
        echo 'Not on branch "build", checking out.'
        git checkout -B build
    fi

    if [[ $(git remote update --prune | wc -l) -gt 1 ]]; then
        echo 'Repository updated.'
        PUSH_REQUIRED=true
    fi

    git reset --hard origin/build && \
    git clean -df && \
    return 0 || \
    return 1
}

ZipSrc () {

    if [[ $1 == 'back' ]]; then
        7z a ../back-src.zip \
        pom.xml \
        src && \
        return 0
    elif [[ $1 == 'front' ]]; then
        7z a ../front-src.zip \
          package.json \
          package-lock.json \
          public \
          src && \
        return 0
    fi
    return 1
}

main () {
    PROJECT_ROOT=$(pwd)
    cd Blog-Frontend && \
    UpdateRepository && \
    ZipSrc 'front' && \

    cd ../Blog-Backend && \
    UpdateRepository && \
    ZipSrc 'back' && \

    ./mvnw clean package "-Dversion=release" && \

    echo "$PROJECT_ROOT/blog-release.jar" && \
    cp "$(find . -name "blog*.jar" -type f)" "$PROJECT_ROOT/blog-release.jar" && \
    PrintGreen "\nProject successfully packaged.\n" && \
    PrintGreen "\nGenerated files:\n" && \
    printf "%s/blog-backend-src.zip\n" "$PROJECT_ROOT" && \
    printf "%s/blog-frontend-src.zip\n" "$PROJECT_ROOT" && \
    printf "%s/blog-release.jar\n" "$PROJECT_ROOT" || \
    PrintPink "\nFailed to package the project."
}

main
