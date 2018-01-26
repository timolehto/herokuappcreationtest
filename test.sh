#!/usr/bin/env sh

set -e


wait_app_available() {
  local app="$1"
  printf "Waiting for $app app to fully deploy..."
  while ! curl --silent --fail "https://$app.herokuapp.com" >/dev/null; do
    printf '.'
    sleep 1
  done; echo " DONE"
}

cleanup() {
  heroku apps:destroy $BASE_APP --confirm $BASE_APP || :
  heroku apps:destroy $TEST_APP --confirm $TEST_APP || :
  # heroku pipelines:destroy hello-app-test-pipeline || :
  git remote rm heroku || :
}
trap cleanup INT TERM EXIT


REGION="$1"
BASE_APP="hello-app-base-$REGION"
TEST_APP="hello-app-lul-$REGION"

if [ -z "$REGION" ]; then 1>&2 echo "ERROR: Specify REGION to test as the first argument!"; exit 89; fi

cleanup >/dev/null 2>&1

heroku apps:create $BASE_APP --region "$REGION"
heroku pipelines:create hello-app-test-pipeline -a $BASE_APP -s production
#heroku pipelines:add hello-app-test-pipeline -a hello-app-base

git subtree push --prefix hello-app heroku master

( time wait_app_available $BASE_APP ) 2>&1 | tee timing-$REGION.log

heroku apps:create -a $TEST_APP --region "$REGION" --no-remote
heroku pipelines:add hello-app-test-pipeline -a "$TEST_APP" -s production
heroku pipelines:promote -a $BASE_APP --to $TEST_APP

( time wait_app_available $TEST_APP ) 2>&1 | tee -a timing-$REGION.log
