#!/bin/bash

###########################################
# Bootstrap action for Sahara clusters
###########################################

# Usage
# bootstrap:https://raw.githubusercontent.com/CyberAgent/adtech-ganesha-public/master/bootstrap_action.sh bootstrap_args:${acl_access_token},${consul_dc_name},${consul_server_ipv4}
# e.g. consul_dc_name=diana-dev
# e.g. consul_server_ipv4=10.x.x.x

# Install consul
sudo mkdir -p /opt/consul/etc
sudo mkdir -p /opt/consul/bin
sudo mkdir -p /opt/consul/data

sudo wget https://releases.hashicorp.com/consul/0.6.4/consul_0.6.4_linux_amd64.zip
sudo unzip consul_0.6.4_linux_amd64.zip
sudo install consul /opt/consul/bin/
sudo rm -rf consul*

sudo cat <<EOF > /opt/consul/etc/consul.json
{
  "bind_addr": "$(ip -f inet -o addr show eth0|cut -d\  -f 7 | cut -d/ -f 1)",
  "client_addr": "0.0.0.0",
  "data_dir": "/opt/consul/data",
  "acl_default_policy": "deny",
  "http_api_response_headers": {
    "Access-Control-Allow-Origin": "*"
  }
}
EOF

sudo cat <<EOF > /opt/consul/etc/acl_token.json
{"acl_token":"$1"}
EOF

sudo cat <<EOF | sudo tee /etc/systemd/system/consul.service
[Unit]
Description=consul agent
Requires=network-online.target
After=network-online.target

[Service]
Environment=GOMAXPROCS=2
Restart=on-failure
ExecStart=/opt/consul/bin/consul agent -config-dir=/opt/consul/etc -dc $2 -join $3
ExecReload=/bin/kill -HUP \$MAINPID
KillSignal=SIGINT

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable consul
sudo systemctl start consul

# Setup dnsmasq
sudo sh -c "echo 'server=/consul/127.0.0.1#8600' >> /etc/dnsmasq.conf"
sudo sh -c "echo 'strict-order' >> /etc/dnsmasq.conf"
sudo sed -i -e "/^search.*$/a nameserver 127.0.0.1" /etc/resolv.conf
sudo systemctl enable dnsmasq.service
sudo systemctl start dnsmasq.service
