# InSpec test for recipe osl-mailstore::default

# The InSpec reference, with examples and extensive documentation, can be
# found at https://docs.chef.io/inspec/resources/

describe file('/var/www/postfixadmin') do
    it { should exist }
end

describe file('/var/www/postfixadmin/config.local.php') do
    it { should exist }
end