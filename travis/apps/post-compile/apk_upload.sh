#!/bin/bash
set -e

source $HOME/proof-bin/dev-tools/travis/detect_build_type.sh;
if [ -n "$SKIP_UPLOAD" ]; then
    -e "\033[1;33mSkipping artifact upload\033[0m";
    exit 0;
fi

if [ -z "$APP_VERSION" ]; then
    APP_VERSION="$(grep -e 'VERSION\ =' $TARGET_NAME.pro | sed 's/^VERSION\ =\ \(.*\)/\1/')";
fi

echo -e "\033[1;32mApp version: $APP_VERSION\033[0m";
if [ -n "$RELEASE_BUILD" ]; then
    echo -e "\033[1;32mWill be uploaded as release to __releases/$TARGET_NAME/$TARGET_NAME-$APP_VERSION.apk\033[0m";
else
    echo -e "\033[1;32mWill be uploaded to $TRAVIS_BRANCH/$TARGET_NAME-$APP_VERSION-$TRAVIS_BRANCH.apk\033[0m";
fi
echo " ";

travis_fold start "prepare.awscli" && travis_time_start;
echo -e "\033[1;33mInstalling awscli...\033[0m";
pip install --user awscli;
travis_time_finish && travis_fold end "prepare.awscli";
echo " ";

travis_time_start;
echo -e "\033[1;33mUploading to AWS S3...\033[0m";
if [ -n "$RELEASE_BUILD" ]; then
    $HOME/proof-bin/dev-tools/travis/s3_upload.sh $HOME/full_build/debug/$TARGET_NAME.apk __releases/$TARGET_NAME $TARGET_NAME-$APP_VERSION.apk;
else
    $HOME/proof-bin/dev-tools/travis/s3_upload.sh $HOME/full_build/debug/$TARGET_NAME.apk $TRAVIS_BRANCH $TARGET_NAME-$APP_VERSION-$TRAVIS_BRANCH.apk;
fi
travis_time_finish
