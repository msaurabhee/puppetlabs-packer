#!/bin/bash

# These should be passed in via custom_provisioning_env
#VERSION='2018.1.15'
#PLATFORM='el-7-x86_64'

PE_TARBALL_URL="https://artifactory.delivery.puppetlabs.net/artifactory/generic_enterprise__local/archives/releases/${VERSION}"
EXT='.tar'
TMP_DIR='/tmp'
PUPPET_BIN='/opt/puppetlabs/bin'

set -e
set -x

# This isn't really used since we use %{::trusted.certname} below,
# but sometimes we end up getting a spicy-proton name here due to
# some sort of IP reuse thing, and it could cause weirdness.
HOSTNAME=$(hostname -f)
echo "### HOSTNAME = ${HOSTNAME} ###"

NAME="puppet-enterprise-${VERSION}-${PLATFORM}"
TARBALL="${NAME}${EXT}"
FULL_TARBALL_URL="${PE_TARBALL_URL}/${TARBALL}"

echo "### Downloading PE tarball from ${FULL_TARBALL_URL} and saving to ${TMP_DIR} ###"
wget -q -O ${TMP_DIR}/${TARBALL} ${FULL_TARBALL_URL} 
echo '### Exploding tarball ###'
tar -xf ${TMP_DIR}/${TARBALL} --directory ${TMP_DIR}
echo '### Removing tarball ###'
rm -f ${TMP_DIR}/${TARBALL}

echo '### Setting up pe.conf ###'
cat << EOF > ${TMP_DIR}/pe.conf
{
  "puppet_enterprise::puppet_master_host": "%{::trusted.certname}",
  "console_admin_password": "puppetlabs"
}
EOF

echo '### Running installer ###'
${TMP_DIR}/${NAME}/puppet-enterprise-installer -y -c ${TMP_DIR}/pe.conf

# Puppet runs with changes exit 2
set +e

echo '### First puppet run post-install ###'
${PUPPET_BIN}/puppet agent -t

echo '### Second puppet run post-install ###'
${PUPPET_BIN}/puppet agent -t

# The refresh_master_hostname plan requires user_data.conf to be present
echo '### Running puppet infra recover_configuration to generate user_data.conf ###'
${PUPPET_BIN}/puppet-infrastructure recover_configuration

echo '### Creating refresh_hostname script ###'
echo BOLT_DISABLE_ANALYTICS=true /opt/puppetlabs/installer/bin/bolt --boltdir=/opt/puppetlabs/installer/share/Boltdir plan run enterprise_tasks::testing::refresh_master_hostname > /root/refresh_hostname.sh
chmod +x /root/refresh_hostname.sh

echo '### Setup complete ###'
