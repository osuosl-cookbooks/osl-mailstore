node.default['percona']['server']['root_password'] = 'password'
node.default['percona']['backup']['password'] = 'insecure'

include_recipe 'osl-mysql::server'

mail_secrets = data_bag_item('mailstore', 'secrets')

db = mail_secrets['postfixadmin']

puts db
puts db['db_user']

percona_mysql_user db['db_user'] do
  host 'localhost'
  password db['db_password']
  ctrl_password 'password'
  database_name db['db_name']
  privileges [:all]
  table '*'
  action [:create, :grant]
end

percona_mysql_database db['db_name'] do
  password 'password'
end
