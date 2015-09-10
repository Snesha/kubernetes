#!/bin/bash

# Copyright 2014 The Kubernetes Authors All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Prepopulate the name of the Master
mkdir -p /etc/salt/minion.d
echo "master: $MASTER_NAME" > /etc/salt/minion.d/master.conf

cat <<EOF >/etc/salt/minion.d/grains.conf
grains:
  roles:
    - kubernetes-master
  cloud: azure
EOF
if [[ -n "${DOCKER_OPTS}" ]]; then
  cat <<EOF >>/etc/salt/minion.d/grains.conf
  docker_opts: '$(echo "$DOCKER_OPTS" | sed -e "s/'/''/g")'
EOF
fi

if [[ -n "${DOCKER_ROOT}" ]]; then
  cat <<EOF >>/etc/salt/minion.d/grains.conf
  docker_root: '$(echo "$DOCKER_ROOT" | sed -e "s/'/''/g")'
EOF
fi

if [[ -n "${KUBELET_ROOT}" ]]; then
  cat <<EOF >>/etc/salt/minion.d/grains.conf
  kubelet_root: '$(echo "$KUBELET_ROOT" | sed -e "s/'/''/g")'
EOF
fi

if [[ -n "${MASTER_EXTRA_SANS}" ]]; then
  cat <<EOF >>/etc/salt/minion.d/grains.conf
  master_extra_sans: '$(echo "$MASTER_EXTRA_SANS" | sed -e "s/'/''/g")'
EOF
fi

# Auto accept all keys from minions that try to join
mkdir -p /etc/salt/master.d
cat <<EOF >/etc/salt/master.d/auto-accept.conf
auto_accept: True
EOF

cat <<EOF >/etc/salt/master.d/reactor.conf
# React to new minions starting by running highstate on them.
reactor:
  - 'salt/minion/*/start':
    - /srv/reactor/highstate-new.sls
EOF

mkdir -p /etc/openvpn
umask=$(umask)
umask 0066
echo "$CA_CRT" > /etc/openvpn/ca.crt
echo "$SERVER_CRT" > /etc/openvpn/server.crt
echo "$SERVER_KEY" > /etc/openvpn/server.key
umask $umask

cat <<EOF >/etc/salt/minion.d/log-level-debug.conf
log_level: debug
log_level_logfile: debug
EOF

cat <<EOF >/etc/salt/master.d/log-level-debug.conf
log_level: debug
log_level_logfile: debug
EOF

install-salt --master

service salt-master start
service salt-minion start

# Wait a few minutes and trigger another Salt run to better recover from
# any transient errors.
echo "Sleeping 180"
sleep 180
salt-call state.highstate || true
