require './spec_helper'
describe 'Download Documents: Verification', :scf, :commercials, :download_all do
  before(:all) do
    @investor = 'mclr_investor'
    @vendor_name = 'West Store AS'
    @investor_id = $conf['users']['investor_profile_investor']['id']
    @anchor_id = $conf['users']['anchor_summary_anchor']['id']
    @anchor_name = $conf['users']['anchor_summary_anchor']['name']
    @erb_file = File.read("#{Dir.pwd}/test-data/erb/commercials_data.erb")
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
    @download_path = "#{Dir.pwd}/test-data/downloaded/download_docs_verification"
  end

  before(:each) do
    @driver = Tarspect::Browser.new($conf['browser'], @download_path).invoke
    @tarspect_methods = Common::Methods.new(@driver)
    @common_pages = Pages::CommonMethods.new(@driver)
    @investor_page = Pages::Investor.new(@driver)
    @commercials_page = Pages::Commercials.new(@driver)
    @program = 'Vendor Financing'
    flush_directory(@download_path)
  end

  after(:each) do |e|
    snap_screenshot(e)
    flush_directory(@download_path)
    quit_browser
  end

  it 'Verification of Download All documents - Investor' do |e|
    e.run_step 'Login as Investor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users'][@investor]['email'], $conf['users'][@investor]['password'])).to be true
    end

    e.run_step 'Verify all files can be downloaded' do
      @investor_page.go_to_program(anchor: @anchor_name, program: @program)
      @investor_page.click_download_all_docs(@vendor_name)
      expect(@common_pages.alert_message.text).to eq('The file has been downloaded')
    end

    e.run_step 'Verify Downloaded zip file' do
      zip_file = @common_pages.get_zip_file(@download_path)
      files_list = @common_pages.unzip_file("#{@download_path}/#{zip_file}")
      exp_files_list = @testdata['Validate_all_docs']
      expect(files_list).to eq(exp_files_list)
    end

    e.run_step 'Verify all files can be downloaded in detail page' do
      flush_directory(@download_path)
      @investor_page.go_to_commercials(@vendor_name)
      @investor_page.click_download_all_docs(@vendor_name, details_page: true)
      expect(@common_pages.alert_message.text).to eq('The file has been downloaded.')
    end

    e.run_step 'Verify Downloaded zip file' do
      zip_file = @common_pages.get_zip_file(@download_path)
      files_list = @common_pages.unzip_file("#{@download_path}/#{zip_file}")
      exp_files_list = @testdata['Validate_all_docs']
      expect(files_list).to eq(exp_files_list)
    end
  end

  it 'Verification of Download All documents - Product' do |e|
    e.run_step 'Login as Product' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['product']['email'], $conf['users']['product']['password'])).to be true
    end

    e.run_step 'Verify documents can be downloaded from Vendor' do
      @common_pages.click_menu('Vendors')
      @common_pages.search_program(@vendor_name)
      @commercials_page.navigate_to_entity(@vendor_name, 'Details')
      @investor_page.click_download_all_docs(@vendor_name, details_page: true)
      expect(@common_pages.alert_message.text).to eq('The file has been downloaded.')
    end

    e.run_step 'Verify Downloaded zip file' do
      zip_file = @common_pages.get_zip_file(@download_path)
      files_list = @common_pages.unzip_file("#{@download_path}/#{zip_file}")
      exp_files_list = @testdata['Validate_all_docs']
      expect(files_list).to eq(exp_files_list)
    end
  end
end
