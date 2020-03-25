#!/bin/bash
# Author: Heikki Kangas <heikki.kangas@tuni.fi>

# This script builds both back- and frontend projects of Blog project.
# This script can also push new release to GitHub.
# If following parameters are given and GitHub access token has been set.
# -v=<version>
# -m="release message>"
# AND
#   -r for release
#   OR
#   -pre for pre-release

# To be able to push releases, you have to:
#  - Create personal access token
#    (Go to GitHub -> Settings -> Developer Settings
#    -> Personal access tokens -> Generate new token)
#  - Run "git config --global blog-build-token <generated token>" command.
#  - Give version number and release message as parameters.
#    e.g. ./package.sh -r -v=1.0 -m="First release."
#    if you want to create pre-release instead of release, replace '-r' with '-pre'
#
# This script will execute following steps:
#  Frontend:
#  1. Pull latest changes from branch "build" of frontend repo.
#  2. Build frontend project.
#  3. Create zip archive of frontend source code.
#  Backend:
#  4. Pull latest changes from branch "build" of frontend repo.
#  5. Build backend project with built frontend project.
#  6. Create zip archive of backend source code.
#  7. Let the user know if the build was successful or not.
#
#  8. Push updated back- and frontend commit references to GitHub if updated.
#  9. Depending on parameters, may or may not push new release to GitHub.

# Commands are chained so if one command fails,
# the rest of the commands will not be executed.

# About parameters in bash:
#
# VARIABLE="value": Setting a value to variable.
# VARIABLE=$( < command > ): Sets output of command to variable.
# e.g. FILES=$(ls -la)
# echo "$VARIABLE": Accessing the value saved to variable.
# (Command 'echo' prints given arguments.)
#
# Built-in variables:
# $1 = First parameter given to function or the program.
# $@ = All given parameters.
# $# = Count of the given variables.

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
    
    # '|' passes command output to next command.
    # wc -l counts how many lines given input has.
    if [[ $(git remote update --prune | wc -l) -gt 1 ]]; then
        echo 'Repository updated.'
        PUSH_REQUIRED=true
    fi

    git reset --hard origin/build && \
    git clean -df && \
    return 0 || \
    return 1
}

PushUpdatedProject () {
    git add . && \
    git commit -m "Update repository references." && \
    git push && \
    return 0
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

ValidateParameters () {
    for PARAMETER in "$@"
    do
        # Check if we should do a release or pre-release.
        case $PARAMETER in
            '-r')
                RELEASE=true
                ;;
            '-pre')
                PRE_RELEASE=true
                ;;
        esac

        # Use regex match group to capture given parameter values.
        if [[ $PARAMETER =~ -v=(.+) ]]; then
            VERSION=${BASH_REMATCH[1]}
        elif [[ $PARAMETER =~ -m=(.+) ]]; then
            MESSAGE=${BASH_REMATCH[1]}
        fi
    done
    if [[ "$RELEASE" != "$PRE_RELEASE" && ("$MESSAGE" && "$VERSION") ]]; then
        if $RELEASE; then
            PRE_RELEASE='false'
        elif $PRE_RELEASE; then
            PRE_RELEASE='true'
        fi
        return 0
    else
        return 1
    fi
}

GenerateReleaseRequestData () {
cat <<EOF
{
"tag_name": "$VERSION",
"target_commitish": "$BRANCH",
"name": "$VERSION",
"body": "$MESSAGE",
"draft": false,
"prerelease": $PRE_RELEASE
}
EOF
}

main () {
    PROJECT_ROOT=$(pwd)

    if ValidateParameters "$@"; then CREATE_RELEASE=true; fi

    # Update frontend repository and zip source files to root.
    cd Blog-Frontend && \
    UpdateRepository && \
    ZipSrc 'front' && \

    # Update backend repository and zip source files to root.
    cd ../Blog-Backend && \
    UpdateRepository && \
    ZipSrc 'back' && \

    # Package backend project:
    #  - Install node to project build dir.
    #  - Build frontend project.
    #  - Build backend project.
    #  - Package frontend project inside built backend project.
    #  - Move built JAR from backend build dir to project root.
    #  - Let the user know if build was successfull.
    
    if [[ $CREATE_RELEASE -eq 0 ]]; then
        mvn clean package "-Dversion=release"
    else
        mvn clean package "-Dversion=$VERSION"
    fi
    
    if [[ $? -eq 0 ]]; then
        cp "$(find . -name "blog*.jar" -type f)" "$PROJECT_ROOT/blog-release.jar" && \
        PrintGreen "\nProject successfully packaged.\n" && \
        PrintGreen "\nGenerated files:\n" && \
        printf "%s/blog-backend-src.zip\n" "$PROJECT_ROOT" && \
        printf "%s/blog-frontend-src.zip\n" "$PROJECT_ROOT" && \
        printf "%s/blog-release.jar\n" "$PROJECT_ROOT" || \
        PrintPink "\nFailed to package the project."
    fi

    # Push updated commit references to GitHub if there's changes.
    cd "$PROJECT_ROOT"
    if [[ $? -eq 0 && "$PUSH_REQUIRED" ]]; then
        echo "Submodule refs updated, pushing."
        PushUpdatedProject
        if [[ $? -eq 0 ]]; then
            PrintGreen "\nUpdated repository references pushed to GitHub."
        else
            PrintPink "Failed to push updated repository references to GitHub."
        fi
    fi

    if [[ $CREATE_RELEASE == true ]]; then
        BRANCH=$(git rev-parse --abbrev-ref HEAD)
        REPO=$(git config --get remote.origin.url | sed 's/.*:\/\/github.com\///;s/.git$//')
        TOKEN=$(git config --global github.token)
        echo "Create release $VERSION for repo: $REPO branch: $BRANCH"
        curl --data "$(GenerateReleaseRequestData)" "https://api.github.com/repos/$REPO/releases?access_token=$TOKEN"
        for FILE in $(find . -maxdepth 1 -name "./(*.zip)" -type f); do
        curl -v \
          -H "Authorization: token $TOKEN" \
          -H "Content-Type: $(file -b --mime-type $FILE)" \
          --data-binary @$FILE \
          "https://uploads.github.com/repos/hubot/singularity/releases/123/assets?name=$(basename $FILE)"
        done
        FILE='./blog-release.jar'
        curl -v \
          -H "Authorization: token $TOKEN" \
          -H "Content-Type: $(file -b --mime-type $FILE)" \
          --data-binary @$FILE \
          "https://uploads.github.com/repos/hubot/singularity/releases/123/assets?name=$(basename $FILE)"
    fi
}
main "$@"

# End of file
