#
# Cookbook:: osl-mailstore
# Recipe:: default
#
# Copyright:: 2022, Oregon State University
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

# Install PHP + Modules
node.default['php']['version'] = '7.4'
node.default['osl-php']['use_ius'] = true
node.default['osl-php']['use_opcache'] = true
node.default['osl-php']['php_packages'] =
  %w(
    fpm
    cli
    imap
    json
    mysqlnd
    mbstring
  )

include_recipe 'osl-php'
include_recipe 'osl-apache'
include_recipe 'osl-apache::mod_php'
include_recipe 'osl-mysql::client'

# Certificate (wildcard is placeholder for now)
cert_path = '/etc/pki/tls/certs/wildcard.pem'
key_path = '/etc/pki/tls/certs/wildcard.key'

# Following this tutorial: https://linuxize.com/post/set-up-an-email-server-with-postfixadmin/

group 'vmail' do
  gid 5000
end

user 'vmail' do
  comment 'Owner of all mailboxes. Used to access emails on this server'
  home    '/var/mail/vmail'
  group   'vmail'
  shell   '/usr/sbin/nologin'
end

# Download Postfixadmin
# postfixadmin_download_location = "#{Chef::Config[:file_cache_path]}/postfixadmin.tar.gz"

ark 'postfixadmin' do
  url postfixadmin_source
  path '/var/www/postfixadmin'
  checksum postfixadmin_checksum
  owner 'apache'
  strip_components 1
  action :cherry_pick
end

# Local Postfix config
template '/var/www/postfixadmin/config.local.php' do
  source 'config.local.php.erb'
  sensitive true
  variables(
    db: data_bag_item('mailstore', 'config_mysql')
  )
end

# Cache Directory
directory '/var/www/templates_c' do
  owner 'apache'
end

# Postfix
node.default['osl-postfix']['main'].tap do |main|
  main['virtual_mailbox_domains'] = 'proxy:mysql:/etc/postfix/sql/mysql_virtual_domains_maps.cf'
  main['virtual_alias_maps'] = %w(
    mysql-virtual-alias-maps.cf
    mysql-virtual-alias-domain-maps.cf
    mysql-virtual-alias-domain-catchall-maps.cf
  ).map { |file| 'proxy:mysql:/etc/postfix/sql/' + file }.join(',')
  main['virtual_mailbox_maps'] = %w(
    mysql-virtual-mailbox-maps.cf
    mysql-virtual-alias-domain-mailbox-maps.cf
  ).map { |file| 'proxy:mysql:/etc/postfix/sql/' + file }.join(',')
  main['relay_domains'] = 'proxy:mysql:/etc/postfix/sql/mysql-relay-domains.cf'
  main['transport_maps'] = 'proxy:mysql:/etc/postfix/sql/mysql-transport-maps.cf'
  main['virtual_mailbox_base'] = '/var/mail/vmail'
end

include_recipe 'osl-postfix'

directory '/etc/postfix/sql'

# Postfix - MySQL configs
creds = data_bag_item('sql_creds', 'mysql')
{
  'virtual-alias-maps' => "SELECT goto FROM alias WHERE address='%s' AND active'1'",
  'virtual-alias-domain_maps' => "SELECT goto FROM alias,alias_domain WHERE alias_domain.alias_domain='%d' and alias.address=CONCAT('%u', '@', alias_domain.target_domain AND alias.active=1 AND alias_domain.active='1'",
  'virtual-alias-domain-catchall_maps' => "SELECT goto FROM alias,alias_domain WHERE alias_domain.alias_domain = '%d' and alias.address = CONCAT('@', alias_domain.target_domain) AND alias.active = 1 AND alias_domain.active='1'",
  'virtual-domains-maps' => "SELECT domain FROM domain WHERE domain='%s' AND active = '1'",
  'virtual-mailbox-maps' => "SELECT maildir FROM mailbox WHERE username='%s' AND active='1'",
  'virtual-alias-domain-mailbox-maps' => "SELECT maildir FROM mailbox,alias_domain WHERE alias_domain.alias_domain = '%d' and mailbox.username = CONCAT('%u', '@', alias_domain.target_domain) AND mailbox.active = 1 AND alias_domain.active='1'",
  'relay-domains' => "SELECT domain FROM domain WHERE domain='%s' AND active = '1' AND (transport LIKE 'smtp%%' OR transport LIKE 'relay%%')",
  'transport-maps' => "SELECT REPLACE(transport, 'virtual', ':') AS transport FROM domain WHERE domain='%s' AND active = '1'",
  'virtual-mailbox-limit-maps' => "SELECT quota FROM mailbox WHERE username='%s' AND active='1'",
}.each do |file, query|
  template "#{node['postfix']['conf_dir']}/mysql-#{file}.cf" do
    owner 'root'
    mode '0640'
    source 'mysql.cf.erb'
    variables creds: creds, query: query
    sensitive true
    notifies :restart, 'service[postfix]'
  end
end

# Dovecot
node.default['dovecot']['conf']['mail_location'] = 'maildir:/var/mail/vmail/%u/'
node.default['dovecot']['namespaces'] = [
  {
    'name' => 'inbox',
    'inbox' => true,
    'mailboxes' => {
      'Drafts' => {
        'special_use' => '\Drafts',
      },
      'Junk' => {
        'special_use' => '\Junk',
      },
      'Sent' => {
        'special_use' => '\Sent',
      },
      'Sent Messages' => {
        'special_use' => '\Sent',
      },
      'Trash' => {
        'special_use' => '\Trash',
      },
    },
  },
]
node.default['dovecot']['conf']['ssl'] = 'required'
node.default['dovecot']['conf']['ssl_cert'] = '<' + cert_path
node.default['dovecot']['conf']['ssl_key'] = '<' + key_path
node.default['dovecot']['conf']['auth_mechanisms'] = 'plain login'
# node.default['dovecot']['first_valid_uid'] = '5000'
node.default['dovecot']['disable_plaintext_auth'] = 'no'

node.default['dovecot']['conf']['sql']['default_pass_scheme'] = 'MD5-CRYPT'
node.default['dovecot']['conf']['sql']['password_query'] = "SELECT username AS user,password FROM mailbox WHERE username = '%u' AND active='1'"
node.default['dovecot']['conf']['sql']['user_query'] = "SELECT CONCAT('/var/mail/vmail/', maildir) AS home, 1001 AS uid, 1001 AS gid, CONCAT('*:bytes=', quota) AS quota_rule FROM mailbox WHERE username = '%u' AND active='1'"
node.default['dovecot']['conf']['sql']['iterate_query'] = "SELECT username as user FROM mailbox WHERE active = '1'"

node.default['dovecot']['auth']['sql']['userdb']['args'] = '/etc/dovecot/dovecot-sql.conf'
node.default['dovecot']['auth']['sql']['passdb']['args'] = '/etc/dovecot/dovecot-sql.conf'
node.default['osl-imap']['auth_sql']['data_bag'] = 'sql_creds'
node.default['osl-imap']['auth_sql']['data_bag_item'] = 'mysql'
node.default['osl-imap']['auth_sql']['enable_passdb'] = true

include_recipe 'osl-imap'
