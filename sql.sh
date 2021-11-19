#!/bin/bash
set -eu -o pipefail

sudo docker container run \
  --name sqlcl$$ \
  --rm \
  -i \
  -t \
  -v /opt/containers/rac_host_file:/etc/hosts:ro \
  --network=rac_pub1_nw \
  container-registry.oracle.com/database/sqlcl:latest "$@"
