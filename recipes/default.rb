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

group 'vmail' do
  system  true
end

user 'vmail' do
  comment 'Owner of all mailboxes. Used to access emails on this server'
  home    '/var/mail/vmail'
  group   'vmail'
  shell   '/usr/sbin/nologin'
  system  true
end

ark 'postfixadmin' do
  url postfixadmin_source
  path '/var/www/postfixadmin'
  checksum postfixadmin_checksum
  strip_components 1
  action :cherry_pick
end

# Local Postfix config
template '/var/www/postfixadmin/config.local.php' do
  source 'config.local.php.erb'
  sensitive true
  variables(
    db: data_bag_item('mailstore', 'sql_creds')
  )
end

# Cache Directory
directory '/var/www/postfixadmin/templates_c' do
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
creds = data_bag_item('mailstore', 'sql_creds')

postfix_queries.each do |file, query|
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
node.default['dovecot']['disable_plaintext_auth'] = 'no'

node.default['dovecot']['auth']['sql']['userdb']['args'] = '/etc/dovecot/dovecot-sql.conf'
node.default['dovecot']['auth']['sql']['passdb']['args'] = '/etc/dovecot/dovecot-sql.conf'
node.default['osl-imap']['auth_sql']['data_bag'] = 'mailstore'
node.default['osl-imap']['auth_sql']['data_bag_item'] = 'sql_creds'
node.default['osl-imap']['auth_sql']['enable_passdb'] = true

node.force_default['dovecot']['conf']['sql']['default_pass_scheme'] = 'PLAIN-MD5'
node.default['dovecot']['conf']['sql']['password_query'] = dovecot_password_query
node.default['dovecot']['conf']['sql']['user_query'] = dovecot_user_query
node.default['dovecot']['conf']['sql']['iterate_query'] = dovecot_iterate_query

include_recipe 'osl-imap'

apache_app 'postfixadmin' do
  server_name 'postfixadmin'
  directory '/var/www/postfixadmin'
  ssl_enable true
end

directory '/var/www/postfixadmin' do
  owner 'apache'
  group 'apache'
  recursive true
end

selinux_fcontext "/var/www/postfixadmin(/.*)?" do
  secontext 'httpd_sys_content_t'
end

selinux_fcontext "/var/www/postfixadmin/templates_c(/.*)?" do
  secontext 'httpd_sys_rw_content_t'
end
