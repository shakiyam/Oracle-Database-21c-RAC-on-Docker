#!/bin/bash
set -eu -o pipefail

curl -sSL https://github.com/oracle/db-sample-schemas/archive/refs/tags/v21.1.tar.gz | tar xzf -
pushd db-sample-schemas-21.1
perl -p -i.bak -e 's#__SUB__CWD__#'/home/oracle/db-sample-schemas-21.1'#g' ./*.sql ./*/*.sql ./*/*.dat
popd
sudo docker container run \
  --name install-sample \
  --rm \
  --entrypoint /bin/bash \
  -i \
  -v /opt/containers/rac_host_file:/etc/hosts:ro \
  -v "$PWD"/db-sample-schemas-21.1:/home/oracle/db-sample-schemas-21.1 \
  -v "$PWD"/log:/home/oracle/log \
  -w /home/oracle/db-sample-schemas-21.1 \
  --network=rac_pub1_nw \
  container-registry.oracle.com/database/sqlcl:latest <<EOT
echo "@mksample oracle oracle oracle oracle oracle oracle oracle oracle users temp /home/oracle/log/ racnode-scan/ORCLPDB" \
  | sql /nolog
EOT
