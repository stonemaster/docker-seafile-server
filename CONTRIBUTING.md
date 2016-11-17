# Contribute to docker-seafile-server

There are not many guidelines to follow, but theses:
 1. Adapt to the style of the existing scripts. If spaces
    are used, use spaces. If tabs are used, use tabs.
 2. This container includes unittests using
    [bats](https://github.com/sstephenson/bats). Make sure
    that unittests are added where appropriate.

Builds land in the Docker Hub as follows:
 * Travis is configured to run the Makefile which builds
   the container and runs the unittests using bats
 * The Docker Hub is used to build everything and pushes
   everything in `master` to the `latest` tags - as
   well as each branch `branch` to the tag `branch`.

# Things needed to develop locally

 * Docker, of course
 * `jq` and `curl` for the unittests

