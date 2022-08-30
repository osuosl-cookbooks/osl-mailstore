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
  owner 'www-data'
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
  owner 'www-data'
end

# Postfix
node.default['osl-postfix']['main'].tap do |main|
  main['relay_domains'] = 'proxy:mysql:/etc/postfix/sql/mysql_relay_domains.cf'
  main['transport_maps'] = 'proxy:mysql:/etc/postfix/sql/mysql_transport_maps.cf'
  main['virtual_mailbox_domains'] = 'proxy:mysql:/etc/postfix/sql/mysql_virtual_domains_map.cf'
  main['virtual_alias_maps'] = %w(
    mysql_virtual_alias_maps.cf
    mysql_virtual_alias_domain_maps.cf
    mysql_virtual_alias_domain_catchall_maps.cf
  ).map { |file| 'proxy:mysql:/etc/postfix/sql/' + file }.join(',')
  main['virtual_mailbox_maps'] = %w(
    mysql_virtual_mailbox_maps.cf
    mysql_virtual_alias_domain_mailbox_maps.cf
  ).map { |file| 'proxy:mysql:/etc/postfix/sql/' + file }.join(',')
end

include_recipe 'osl-postfix'

# Dovecot
node.default['dovecot']['conf']['mail_location'] = 'maildir:/var/mail/vmail/%u/'
node.default['dovecot']['conf']['mail_uid'] = 'vmail'
node.default['dovecot']['conf']['mail_gid'] = 'vmail'

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
node.default['dovecot']['conf']['ssl_cert'] = '</etc/dovecot/private/dovecot.pem'
node.default['dovecot']['conf']['ssl_key'] = '</etc/dovecot/private/dovecot.pem'

node.default['dovecot']['conf']['auth_mechanisms'] = 'plain login'
node.default['dovecot']['auth']['sql']['userdb']['args'] = '/etc/dovecot/dovecot-sql.conf'
node.default['dovecot']['auth']['sql']['passdb']['args'] = '/etc/dovecot/dovecot-sql.conf'

node.force_default['dovecot']['conf']['sql']['default_pass_scheme'] = 'PLAIN-MD5'
node.force_default['dovecot']['conf']['sql']['password_query'] = "SELECT username AS user,password FROM mailbox WHERE username='%u' AND active='1'"
