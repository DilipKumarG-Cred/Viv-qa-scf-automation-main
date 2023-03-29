require 'selenium-webdriver'
require 'require_all'
require 'pathname'
require 'rspec'
require 'date'
require 'yaml'
require 'rest-client'
require 'allure-rspec'
require 'faker'
require 'gmail'
require 'parallel_tests'
require 'rspec/retry'
require 'pry'
require 'deep_enumerable'
require 'rubyXL'
require 'tarspect'
require 'os'
require 'roo'
require 'erb'

require_all 'Pages'
require_all 'Api'
require_all 'Utils'
require_all 'test-data/constants_helper.rb'
include ApiActions
include Api::Trasactions
include Api::Payments
include Api::VendorOnboarding
include Api::AnchorCommercials
include Api::VendorCommercials
include Api::CommonApi
include Api::DynamicDiscounting
include Api::AnchorApi
include Api::InvestorApi
include Utils::XLS
include Utils::Calculations
include Utils::Mails

$download_path = "#{Pathname.pwd}/test-data/downloaded"
flush_directory("#{$download_path}*") #Flushing downloaded docs before suite starts
flush_directory("./Screenshots") #Flushing Screenshots of previous builds

# ENV['headless'] = 'true'
branch = (ENV['branch'] == nil) ? 'STAGING' : ENV['branch'].upcase
$notifications = YAML.load_file('./test-data/notifications.yml')
$endpoints = YAML.load_file("#{Dir.pwd}/Api/endpoints.yml")
$gmail_helper = GmailHelper.new

case branch
when 'QA'
  $conf = YAML.load_file('./test-data/qa_deliverables.yml')
  p '>>>>>>>>>>>>>>> Loading QA deliverables >>>>>>>>>>>>>>>'
when 'STAGING'
  $conf = YAML.load_file('./test-data/staging_deliverables.yml')
  p '>>>>>>>>>>>>>>> Loading Staging deliverables >>>>>>>>>>>>>>>'
when 'DEMO'
  $conf = YAML.load_file('./test-data/demo_deliverables.yml')
  p '>>>>>>>>>>>>>>> Loading DEMO env deliverables >>>>>>>>>>>>>>>'
when 'DOCKER-QA'
  $conf = YAML.load_file('./test-data/qa_deliverables.yml')
  $conf['base_url'] = 'http://mp-local.vivriti.in:5000'
  $conf['cra_url'] = 'http://cra-local.vivriti.in:5000'
  $conf['cra_signup_url'] = 'http://cra-local.vivriti.in:5000/client/sign-up'
  p '>>>>>>>>>>>>>>> Loading Docker QA deliverables >>>>>>>>>>>>>>>'
when 'DOCKER-STAGING'
  $conf = YAML.load_file('./test-data/staging_deliverables.yml')
  $conf['base_url'] = 'http://mp-local.vivriti.in:5000'
  $conf['cra_url'] = 'http://cra-local.vivriti.in:5000'
  $conf['cra_signup_url'] = 'http://cra-local.vivriti.in:5000/client/sign-up'
  p '>>>>>>>>>>>>>>> Loading Docker Staging deliverables >>>>>>>>>>>>>>>'
else
  p "(((((((((((((((((((())))))))))))))))))))"
  p ">>>>>>>>>>>>>>> Enter a valid environment variable >>>>>>>>>>>>>>>"
  p "(((((((((((((((((((())))))))))))))))))))"
end

# $yopmail_helper = YopmailHelper::Yopmail.new($conf['notification_mailbox'])
# $yopmail_activation_helper = YopmailHelper::Yopmail.new($conf['activation_mailbox'])
values = {
  server: $conf['mailbox_config']['server'],
  port: $conf['mailbox_config']['port'],
  username: $conf['notification_mailbox'],
  password: $conf['mailbox_config']['password']
}
$mail_helper = MailHelper.new(values)
values.merge!(username: $conf['activation_mailbox'])
$activation_mail_helper = MailHelper.new(values)

@spec_opts = (ENV['SPEC_OPTS'] == nil) ? false : ENV['SPEC_OPTS']
failed_ex_file = "examples.txt"

# unless [@spec_opts, ARGV[-1]].include? "--only-failures" #Flushing out examples.txt
#   p ">>>>>>>>>>> Deleting Examples.txt >>>>>>>>>>>"
#   File.delete(failed_ex_file) if File.exist?(failed_ex_file)
#   p ">>>>>>>>>>> Deleting Examples.txt -->> Success >>>>>>>>>>>"
# end

RSpec.configure do |c|
  c.formatter = AllureRspecFormatter
  c.example_status_persistence_file_path = failed_ex_file
  c.after(:suite) do
    $gmail_helper.sign_out_instance unless $gmail_helper.nil?
    env_variables_generator
  end
end

AllureRspec.configure do |c|
  (File.exists? './Report') ? 0:(Dir.mkdir './Report')
  c.results_directory = "./Report" # default: gen/allure-results

  c.clean_results_directory = !([@spec_opts, ARGV[-1]].include? "--only-failures") # clean the output directory first? (default: true)
  c.logging_level = Logger::DEBUG # logging level (default: INFO)
end

def env_variables_generator
  builder = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
    xml.environment {
      xml.parameter {
        xml.key "Environment"
        xml.value "#{(ENV['branch'] == nil) ? 'Staging' : ENV['branch'].capitalize}"
      }
      xml.parameter {
        xml.key "Browser"
        xml.value "#{$conf['browser'].capitalize}"
      }
    }
  end
  xml_content = builder.to_xml

  file = File.open("#{Pathname.pwd}/Report/environment.xml", "w")
  file.puts(xml_content)
  file.close
end
