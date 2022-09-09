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
  its('owner') { should eq 'apache' }
end

%w(postfix dovecot dovecot-mysql).each do |pkg|
  describe package(pkg) do
    it { should be_installed }
  end
end

describe file('/etc/postfix/main.cf') do
  it { should exist }
end

describe postfix_conf do
  its('virtual_mailbox_domains') { should eq 'proxy:mysql:/etc/postfix/sql/mysql_virtual_domains_maps.cf' }
  its('virtual_alias_maps') { should eq 'proxy:mysql:/etc/postfix/sql/mysql-virtual-alias-maps.cf,proxy:mysql:/etc/postfix/sql/mysql-virtual-alias-domain-maps.cf,proxy:mysql:/etc/postfix/sql/mysql-virtual-alias-domain-catchall-maps.cf' }
  its('virtual_mailbox_maps') { should eq 'proxy:mysql:/etc/postfix/sql/mysql-virtual-mailbox-maps.cf,proxy:mysql:/etc/postfix/sql/mysql-virtual-alias-domain-mailbox-maps.cf' }
  its('relay_domains') { should eq 'proxy:mysql:/etc/postfix/sql/mysql-relay-domains.cf' }
  its('transport_maps') { should eq 'proxy:mysql:/etc/postfix/sql/mysql-transport-maps.cf' }
  its('virtual_mailbox_base') { should eq '/var/mail/vmail' }
end

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
  describe postfix_conf("/etc/postfix/mysql-#{file}.cf") do
    its('user') { should eq 'postfixadmin' }
    its('password') { should eq 'password' }
    its('hosts') { should eq 'localhost' }
    its('dbname') { should eq 'postfixadmin' }
    its('query') { should match(query) }
  end
end

describe parse_config_file('/etc/dovecot/conf.d/10-mail.conf') do
  its('mail_location') { should cmp 'maildir:/var/mail/vmail/%u/' }
end

describe parse_config_file('/etc/dovecot/conf.d/10-ssl.conf') do
  its('ssl') { should cmp 'required' }
  its('ssl_cert') { should cmp '</etc/pki/tls/certs/wildcard.pem' }
  its('ssl_key') { should cmp '</etc/pki/tls/private/wildcard.key' }
end

describe parse_config_file('/etc/dovecot/conf.d/10-auth.conf') do
  its('auth_mechanisms') { should cmp 'plain login' }
end

describe parse_config_file('/etc/dovecot/dovecot-sql.conf.ext') do
  its('driver') { should cmp 'mysql' }
  its('default_pass_scheme') { should cmp 'PLAIN-MD5' }
  its('password_query') { should cmp "SELECT username AS user,password FROM mailbox WHERE username = '%u' AND active='1'" }
  its('user_query') { should cmp "SELECT CONCAT('/var/mail/vmail/', maildir) AS home, 1001 AS uid, 1001 AS gid, CONCAT('*:bytes=', quota) AS quota_rule FROM mailbox WHERE username = '%u' AND active='1'" }
  its('iterate_query') { should cmp "SELECT username as user FROM mailbox WHERE active = '1'" }
end
