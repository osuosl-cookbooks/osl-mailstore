# InSpec test for recipe osl-mailstore::default

# The InSpec reference, with examples and extensive documentation, can be
# found at https://docs.chef.io/inspec/resources/

describe group('vmail') do
  its('gid') { should eq 5000 }
end

describe user('vmail') do
  its('home') { should eq '/var/mail/vmail' }
  its('group') { should eq 'vmail' }
  its('shell') { should eq '/usr/sbin/nologin' }
end

describe file('/var/www/postfixadmin') do
  it { should exist }
end

describe parse_config_file('/var/www/postfixadmin/config.local.php') do
  its('$CONF[\'database_type\']') { should include 'mysqli' }
  its('$CONF[\'database_host\']') { should include 'localhost' }
  its('$CONF[\'database_user\']') { should include 'postfixadmin' }
  its('$CONF[\'database_password\']') { should include 'password' }
  its('$CONF[\'database_name\']') { should include 'postfixadmin' }
end

describe file('/var/www/templates_c') do
  its('owner') { should eq 'www-data' }
end

%w(postfix dovecot).each do |pkg|
  describe package(pkg) do
    it { should be_installed }
  end
end

describe file('/etc/postfix/main.cf') do
  it { should exist }
end

describe postfix_conf do
  its('relay_domains') { should eq 'proxy:mysql:/etc/postfix/sql/mysql_relay_domains.cf' }
  its('transport_maps') { should eq 'proxy:mysql:/etc/postfix/sql/mysql_transport_maps.cf' }
  its('virtual_mailbox_domains') { should eq 'proxy:mysql:/etc/postfix/sql/mysql_virtual_domains_map.cf' }
  its('virtual_alias_maps') { should eq 'proxy:mysql:/etc/postfix/sql/mysql_virtual_alias_maps.cf,proxy:mysql:/etc/postfix/sql/mysql_virtual_alias_domain_maps.cf,proxy:mysql:/etc/postfix/sql/mysql_virtual_alias_domain_catchall_maps.cf' }
  its('virtual_mailbox_maps') { should eq 'proxy:mysql:/etc/postfix/sql/mysql_virtual_mailbox_maps.cf,proxy:mysql:/etc/postfix/sql/mysql_virtual_alias_domain_mailbox_maps.cf' }
end

describe parse_config_file('/etc/dovecot/conf.d/10-mail.conf') do
  its('mail_location') { should cmp 'maildir:/var/mail/vmail/%u/' }
  its('mail_uid') { should cmp 'vmail' }
  its('mail_gid') { should cmp 'vmail' }
end

describe parse_config_file('/etc/dovecot/conf.d/10-ssl.conf') do
  its('ssl') { should cmp 'required' }
  its('ssl_cert') { should cmp '</etc/pki/tls/certs/wildcard.pem' }
  its('ssl_key') { should cmp '</etc/pki/tls/private/wildcard.key' }
end

describe parse_config_file('/etc/dovecot/dovecot-sql.conf.ext') do
  its('driver') { should cmp 'mysql' }
  its('default_pass_scheme') { should cmp 'PLAIN-MD5' }
  its('password-query') { should cmp 'SELECT username AS user,password FROM mailbox WHERE username=\'%u\' AND active=\'1\'' }
end
