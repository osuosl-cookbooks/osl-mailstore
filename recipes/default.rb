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

# include_recipe php
# include_recipe mysql

# Following this tutorial: https://linuxize.com/post/set-up-an-email-server-with-postfixadmin/

group 'vmail' do
  gid 5000
end  

user 'vmail' do
  comment 'Owner of all mailboxes. Used to access emails on this server'
  home    '/var/mail/vmail'
  uid     5000
  gid     5000
  shell   '/usr/sbin/nologin'
end

# For testing

user 'www-data' do
  comment 'Php user'
  uid     5001
  gid     5000
end

directory '/var/www'

remote_file '/var/www/postfixadmin.tar.gz' do
  source "https://downloads.sourceforge.net/project/postfixadmin/postfixadmin/postfixadmin-#{node['postfixadmin']['version']}/postfixadmin-#{node['postfixadmin']['version']}.tar.gz"
  mode '0755'
end

archive_file '/var/www/postfixadmin.tar.gz' do
  destination '/var/www/tmp'
  owner 'www-data'
  not_if { ::File.exist?('/var/www/postfixadmin') }
end

bash "Move and rename postfixadmin" do
  code <<-EOL
  mv /var/www/tmp/postfixadmin-#{node['postfixadmin']['version']} /var/www/postfixadmin
  EOL
  not_if { ::File.exist?('/var/www/postfixadmin') }
end
  
template "/var/www/postfixadmin/config.local.php" do
  source 'config.local.php.erb'
end


