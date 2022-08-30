node.default['percona']['server']['root_password'] = 'password'
node.default['percona']['backup']['password'] = 'insecure'

include_recipe 'osl-mysql::server'

mail_secrets = data_bag_item('mailstore', 'config_mysql')

percona_mysql_user mail_secrets['user'] do
  host 'localhost'
  password mail_secrets['password']
  ctrl_password 'password'
  database_name mail_secrets['name']
  privileges [:all]
  table '*'
  action [:create, :grant]
end

percona_mysql_database mail_secrets['name'] do
  password 'password'
end
