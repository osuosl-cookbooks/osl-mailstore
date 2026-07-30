# Rake tasks

require 'rake'

require 'fileutils'
require 'base64'
require 'chef/encrypted_data_bag_item'
require 'json'
require 'openssl'

wildcard_file_path = 'test/integration/data_bags/certificates/wildcard.json'
encrypted_data_bag_secret_path = 'test/integration/encrypted_data_bag_secret'

##
# Run command wrapper
def run_command(command)
  if File.exist?('Gemfile.lock')
    sh %(bundle exec #{command})
  else
    sh %(chef exec #{command})
  end
end

##
# Create a self-signed SSL certificate
#
def gen_ssl_cert
  name = OpenSSL::X509::Name.new [
    %w(C US),
    %w(ST Oregon),
    ['CN', 'OSU Open Source Lab'],
    %w(DC example),
  ]
  key = OpenSSL::PKey::RSA.new 2048

  cert = OpenSSL::X509::Certificate.new
  cert.version = 2
  cert.serial = 2
  cert.subject = name
  cert.public_key = key.public_key
  cert.not_before = Time.now
  cert.not_after = cert.not_before + 1 * 365 * 24 * 60 * 60 # 1 years validity

  # Self-sign the Certificate
  cert.issuer = name
  cert.sign(key, OpenSSL::Digest.new('SHA1'))

  [cert, key]
end

##
# Create a data bag item (with the id of wildcard) containing a self-signed SSL
#  certificate
#
def ssl_data_bag_item
  cert, key = gen_ssl_cert
  Chef::DataBagItem.from_hash(
    'id' => 'wildcard',
    'cert' => cert.to_pem,
    'key' => key.to_pem
  )
end

##
# Create the integration tests directory if it doesn't exist
#
directory 'test/integration'

##
# Generates a 512 byte random sequence and write it to
#  'test/integration/encrypted_data_bag_secret'
#
file encrypted_data_bag_secret_path => 'test/integration' do
  data_bag = OpenSSL::Random.random_bytes(512)
  open encrypted_data_bag_secret, 'w' do |io|
    io.write Base64.encode64(data_bag)
  end
end

##
# Create the certificates data bag if it doesn't exist
#
directory 'test/integration/data_bags/certificates' => 'test/integration'

##
# Create the encrypted wildcard certificate under
#  test/integration/data_bags/certificates
#
file wildcard_file_path => [
  'test/integration/data_bags/certificates',
  'test/integration/encrypted_data_bag_secret',
] do
  encrypted_data_bag_secret = Chef::EncryptedDataBagItem.load_secret(
    encrypted_data_bag_secret_path
  )

  encrypted_wildcard_cert = Chef::EncryptedDataBagItem.encrypt_data_bag_item(
    ssl_data_bag_item, encrypt_data_bag_secret
  )

  open wildcard_file_path, 'w' do |io|
    io.write JSON.pretty_generate(encrypted_wildcard_cert)
  end
end

desc 'Create an Encrypted Databag Wildcard SSL Certificate'
task wildcard: wildcard_file_path

desc 'Create an Encrypted Databag Secret'
task secret_file: encrypted_data_bag_secret_path

require 'cookstyle'
require 'rubocop/rake_task'
desc 'Run RuboCop (cookstyle) tests'
RuboCop::RakeTask.new(:style) do |task|
  task.options << '--display-cop-names'
end

desc 'Run RSpec (unit) tests'
task :unit do
  run_command('rm -f Berksfile.lock')
  run_command('rspec')
end

desc 'Run all tests'
task test: [:style, :unit]

task default: :test
