require './spec_helper'
require 'erb'

describe 'Invoice expiry verification', :scf, :transactions, :invoice_date_expiry do
  before(:all) do
    @anchor_gstn = $conf['myntra_gstn']
    @counterparty_gstn = $conf['libas_gstn']
    @vendor_name = $conf['vendor_name']
    @anchor_name = $conf['anchor_name']
    @invoice_file = "#{Dir.pwd}/test-data/attachments/anchor_invoice.pdf"
    @erb_file = File.read("#{Dir.pwd}/test-data/erb/testbed_data.erb")
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
  end

  before(:each) do
    @driver = Tarspect::Browser.new($conf['browser']).invoke
    @tarspect_methods = Common::Methods.new(@driver)
    @common_pages = Pages::CommonMethods.new(@driver)
    @disbursement_page = Pages::Disbursement.new(@driver)
  end

  after(:each) do |e| # Captures screenshot of the current page when failure happens
    snap_screenshot(e)
    quit_browser
  end

  it 'Invoice Date expiry Verification with tooltip', :sanity, :no_run do |e|
    e.run_step 'Create a complete transaction as Anchor(Draft -> Released)' do
      @testdata['Invoice Details']['Invoice Date'] = (Date.today - 90).strftime('%d-%b-%Y')
      puts "Updated Invoice Date #{@testdata['Invoice Details']['Invoice Date']}"
      @transaction_id = seed_transaction({
                                           actor: 'anchor',
                                           counter_party: 'vendor',
                                           invoice_details: @testdata['Invoice Details'],
                                           invoice_file: @invoice_file,
                                           program: 'Invoice Financing - Vendor',
                                           program_group: 'invoice'
                                         })
      expect(@transaction_id).not_to include('Error while creating transaction')
    end

    e.run_step 'Login as Investor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['investor']['email'], $conf['users']['investor']['password'])).to eq true
    end

    e.run_step "Select vendor in 'Up For Disbursement'" do
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @common_pages.click_transactions_tab(UP_FOR_DISBURSEMENT)
      @disbursement_page.select_vendor_in_disbursement(@vendor_name, @testdata['Invoice Details']['Invoice Date'])
      @disbursement_page.scroll_till_transaction(@vendor_name, @transaction_id)
    end

    e.run_step 'Verify tool tip is present for expired invoices' do
      expect(@disbursement_page.select_transaction_and_get_tooltip_text(@transaction_id)).to eq 'This invoice has surpassed your invoice ageing threshold.'
    end
  end
end
