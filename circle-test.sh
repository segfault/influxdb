#!/bin/bash
#
# This is the InfluxDB CircleCI test script. Using this script allows total control
# the environment in which the build and test is run, and matches the official
# build process for InfluxDB.

GORACE="halt_on_error=1"
BUILD_DIR=$HOME/influxdb-build
GO_VERSION=go1.4
PARALLELISM="-parallel 256"
TIMEOUT="-timeout 300s"

# Executes the given statement, and exits if the command returns a non-zero code.
function exit_if_fail {
    command=$@
    echo "Executing '$command'"
    $command
    rc=$?
    if [ $rc -ne 0 ]; then
        echo "'$command' returned $rc."
        exit $rc
    fi
}


source $HOME/.gvm/scripts/gvm
exit_if_fail gvm use $GO_VERSION
exit_if_fail go get golang.org/x/tools/cmd/vet

# Set up the build directory, and then GOPATH.
exit_if_fail mkdir $BUILD_DIR
export GOPATH=$BUILD_DIR
exit_if_fail mkdir -p $GOPATH/src/github.com/influxdb

# Move the checked-out source to a better location.
exit_if_fail mv $HOME/influxdb $GOPATH/src/github.com/influxdb
exit_if_fail cd $GOPATH/src/github.com/influxdb/influxdb
exit_if_fail git branch --set-upstream-to=origin/$CIRCLE_BRANCH $CIRCLE_BRANCH

# Install the code.
exit_if_fail cd $GOPATH/src/github.com/influxdb/influxdb
exit_if_fail go get -f -u -v ./...
exit_if_fail git checkout $CIRCLE_BRANCH # 'go get' switches to master. Who knew? Switch back.
exit_if_fail go build -v ./...

# Run the tests.
exit_if_fail go tool vet .
case $CIRCLE_NODE_INDEX in
    0)
        exit_if_fail go test $PARALLELISM $TIMEOUT ./... 2>&1 | tee $CIRCLE_ARTIFACTS/test_logs.txt
        ;;
    1)
        exit_if_fail go test $PARALLELISM $TIMEOUT -race ./... 2>&1 | tee $CIRCLE_ARTIFACTS/test_race_logs_1.txt
        ;;
esac

# Just to be nice.
exit 0
