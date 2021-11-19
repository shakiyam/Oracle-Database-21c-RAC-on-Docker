#!/bin/bash
set -eu -o pipefail

function log {
  if [[ -t 1 ]]; then
    tput setaf 2
    tput bold
  fi
  echo "$(date --rfc-3339=seconds) $*"
  if [[ -t 1 ]]; then
    tput sgr0
  fi
}

function wait_to_ready {
  while true; do
    if sudo docker logs "$1" | grep -q 'ORACLE RAC DATABASE IS READY TO USE!'; then
      break
    fi
    sleep 60
    echo -n .
  done
  echo
  log 'ORACLE RAC DATABASE IS READY TO USE!'
}

log 'Load environment variables from .env'
if [[ -e .env ]]; then
  # shellcheck disable=SC1091
  . .env
else
  log 'Environment file .env not found.'
  exit 1
fi

# shellcheck disable=SC1091
OS_ID=$(
  . /etc/os-release
  echo "$ID"
)
readonly OS_ID
# shellcheck disable=SC1091
OS_VERSION=$(
  . /etc/os-release
  echo "$VERSION"
)
readonly OS_VERSION
if [[ ${OS_ID:-} != 'ol' || ${OS_VERSION%%.*} -ne 7 || $(uname -m) != 'x86_64' ]]; then
  echo 'Host must be Oracle Linux 7 (x86_64).'
  exit 1
fi

path="$DEVICE"
while [[ -L "${path}" ]]; do
  path="$(readlink -f "$path")"
done
if [[ ! -b "${path}" ]]; then
  log "$DEVICE is not block device."
  exit 1
fi

log 'Configure kernel parameter'
cat <<EOT | sudo tee -a /etc/sysctl.conf >/dev/null
fs.aio-max-nr = 1048576
fs.file-max = 6815744
net.core.rmem_max = 4194304
net.core.rmem_default = 262144
net.core.wmem_max = 1048576
net.core.wmem_default = 262144
net.core.rmem_default = 262144
EOT
sudo sysctl -p

log 'Install Docker Engine'
sudo yum -y --enablerepo ol7_addons install docker-engine

log 'Setup Docker Engine'
readonly EXEC_START='ExecStart=/usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock'
readonly EXEC_OPTIONS='--cpu-rt-runtime=950000'
sudo sed -i -e "s@$EXEC_START@$EXEC_START $EXEC_OPTIONS@g" /usr/lib/systemd/system/docker.service
sudo systemctl daemon-reload
sudo systemctl restart docker
sudo systemctl enable docker

log 'Create networks'
sudo docker network create --driver=bridge --subnet=172.16.1.0/24 rac_pub1_nw
sudo docker network create --driver=bridge --subnet=192.168.17.0/24 rac_priv1_nw

log 'Create the shared host file'
sudo mkdir /opt/containers
sudo touch /opt/containers/rac_host_file

log 'Password management'
sudo mkdir /opt/.secrets/
sudo openssl rand -hex 64 -out /opt/.secrets/pwd.key
echo 'oracle' | sudo tee /opt/.secrets/common_os_pwdfile >/dev/null
sudo openssl enc -aes-256-cbc -salt -in /opt/.secrets/common_os_pwdfile -out /opt/.secrets/common_os_pwdfile.enc -pass file:/opt/.secrets/pwd.key
sudo rm -f /opt/.secrets/common_os_pwdfile

log 'Login Oracle Container Registry'
sudo docker login container-registry.oracle.com -u "$REGISTRY_USERNAME" -p "$REGISTRY_PASSWORD"

log 'Pull RAC container image'
sudo docker pull container-registry.oracle.com/database/rac:21.3.0.0

log 'Deploying first RAC container with block device'
sudo dd if=/dev/zero of="$DEVICE" bs=8k count=100000
sudo docker create -t -i \
  --hostname racnode1 \
  --volume /boot:/boot:ro \
  --volume /dev/shm \
  --tmpfs /dev/shm:rw,exec,size=4G \
  --volume /opt/containers/rac_host_file:/etc/hosts \
  --volume /opt/.secrets:/run/secrets:ro \
  --volume /etc/localtime:/etc/localtime:ro \
  --memory 8G \
  --memory-swap 16G \
  --sysctl kernel.shmall=2097152 \
  --sysctl 'kernel.sem=250 32000 100 128' \
  --sysctl kernel.shmmax=8589934592 \
  --sysctl kernel.shmmni=4096 \
  --dns-search=example.com \
  --device="$DEVICE":/dev/asm_disk1 \
  --privileged=false \
  --cap-add=SYS_NICE \
  --cap-add=SYS_RESOURCE \
  --cap-add=NET_ADMIN \
  -e NODE_VIP=172.16.1.160 \
  -e VIP_HOSTNAME=racnode1-vip \
  -e PRIV_IP=192.168.17.150 \
  -e PRIV_HOSTNAME=racnode1-priv \
  -e PUBLIC_IP=172.16.1.150 \
  -e PUBLIC_HOSTNAME=racnode1 \
  -e SCAN_NAME=racnode-scan \
  -e SCAN_IP=172.16.1.70 \
  -e OP_TYPE=INSTALL \
  -e DOMAIN=example.com \
  -e ASM_DEVICE_LIST=/dev/asm_disk1 \
  -e ASM_DISCOVERY_DIR=/dev \
  -e CMAN_HOSTNAME=racnode-cman1 \
  -e CMAN_IP=172.16.1.15 \
  -e COMMON_OS_PWD_FILE=common_os_pwdfile.enc \
  -e PWD_KEY=pwd.key \
  --restart=always --tmpfs=/run -v /sys/fs/cgroup:/sys/fs/cgroup:ro \
  --cpu-rt-runtime=95000 --ulimit rtprio=99 \
  --name racnode1 \
  container-registry.oracle.com/database/rac:21.3.0.0

log 'Assign networks to first RAC container'
sudo docker network disconnect bridge racnode1
sudo docker network connect rac_pub1_nw --ip 172.16.1.150 racnode1
sudo docker network connect rac_priv1_nw --ip 192.168.17.150 racnode1

log 'Start the first RAC container'
log 'It can take at least 20 minutes or longer to create the first node of the cluster.'
sudo docker start racnode1
wait_to_ready racnode1
sudo docker exec -i -t racnode1 /u01/app/21.3.0/grid/bin/crsctl stat res -t

log 'Deploying additional RAC container with block device'
sudo docker create -t -i \
  --hostname racnode2 \
  --volume /dev/shm \
  --tmpfs /dev/shm:rw,exec,size=4G \
  --volume /boot:/boot:ro \
  --volume /etc/localtime:/etc/localtime:ro \
  --memory 8G \
  --memory-swap 16G \
  --sysctl kernel.shmall=2097152 \
  --sysctl 'kernel.sem=250 32000 100 128' \
  --sysctl kernel.shmmax=8589934592 \
  --sysctl kernel.shmmni=4096 \
  --dns-search=example.com \
  --volume /opt/containers/rac_host_file:/etc/hosts \
  --volume /opt/.secrets:/run/secrets:ro \
  --device="$DEVICE":/dev/asm_disk1 \
  --privileged=false \
  --cap-add=SYS_NICE \
  --cap-add=SYS_RESOURCE \
  --cap-add=NET_ADMIN \
  -e EXISTING_CLS_NODES=racnode1 \
  -e NODE_VIP=172.16.1.161 \
  -e VIP_HOSTNAME=racnode2-vip \
  -e PRIV_IP=192.168.17.151 \
  -e PRIV_HOSTNAME=racnode2-priv \
  -e PUBLIC_IP=172.16.1.151 \
  -e PUBLIC_HOSTNAME=racnode2 \
  -e DOMAIN=example.com \
  -e SCAN_NAME=racnode-scan \
  -e SCAN_IP=172.16.1.70 \
  -e ASM_DISCOVERY_DIR=/dev \
  -e ASM_DEVICE_LIST=/dev/asm_disk1 \
  -e ORACLE_SID=ORCLCDB \
  -e OP_TYPE=ADDNODE \
  -e COMMON_OS_PWD_FILE=common_os_pwdfile.enc \
  -e PWD_KEY=pwd.key \
  --tmpfs=/run -v /sys/fs/cgroup:/sys/fs/cgroup:ro \
  --cpu-rt-runtime=95000 \
  --ulimit rtprio=99 \
  --restart=always \
  --name racnode2 \
  container-registry.oracle.com/database/rac:21.3.0.0

log 'Assign networks to additional RAC container'
sudo docker network disconnect bridge racnode2
sudo docker network connect rac_pub1_nw --ip 172.16.1.151 racnode2
sudo docker network connect rac_priv1_nw --ip 192.168.17.151 racnode2

log 'Start additional RAC container'
log 'It can take at least 10 minutes or longer to create additional node of the cluster.'
sudo docker start racnode2
wait_to_ready racnode2
sudo docker exec -i -t racnode2 /u01/app/21.3.0/grid/bin/crsctl stat res -t

log 'You can install sample schemas with the following command.'
log './install-sample.sh'
log 'You can connect to Oracle RAC Database with the following command.'
log './sql.sh system/oracle@racnode-scan/ORCLCDB'
