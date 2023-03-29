require './spec_helper'
describe 'Commercials: Vendor Bulk Import', :scf, :commercials, :vendor_bulk_import, :onboarding, :bulk do
  before(:all) do
    @created_vendors = []
    @created_dealers = []
    @po_vendors = []
    @po_dealers = []
  end

  before(:each) do
    @download_path = "#{Dir.pwd}/test-data/downloaded/vendor_bulk_import"
    @driver = Tarspect::Browser.new($conf['browser'], @download_path).invoke
    @tarspect_methods = Common::Methods.new(@driver)
    @common_pages = Pages::CommonMethods.new(@driver)
    @commercials_page = Pages::Commercials.new(@driver)
    flush_directory(@download_path)
    delete_channel_partner('Vendor', [['Maruthi Motors', 'PO FINANCING'], ['Dozco', 'PO FINANCING']], 'grn_anchor')
    delete_channel_partner('Dealer', [['Exide', 'PO FINANCING'], ['Ramkay TVS', 'PO FINANCING']], 'grn_anchor')
    delete_channel_partner('Vendor', [['Exide', 'INVOICE FINANCING']], 'anchor')
  end

  after(:each) do |e| # Captures screenshot of the current page when failure happens
    snap_screenshot(e)
    quit_browser
    delete_channel_partner('Vendor', @created_vendors, 'anchor')
    delete_channel_partner('Dealer', @created_dealers, 'anchor')
    delete_channel_partner('Vendor', @po_vendors, 'grn_anchor')
    delete_channel_partner('Dealer', @po_dealers, 'grn_anchor')
    flush_directory(@download_path)
  end

  it 'Commercials: Bulk Import: Invoice Financing Vendor Program' do |e|
    e.run_step 'Login as Anchor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['anchor']['email'], $conf['users']['anchor']['password'])).to be true
    end

    e.run_step 'Bulk import vendor and verify summary report' do
      @common_pages.click_menu(MENU_VENDORS)
      @output = @commercials_page.bulk_import_vendors('Invoice Financing - Vendor Program')
      @created_vendors << @output[0]
      expected_results = @output[1]
      @created_vendors.flatten!
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq(true), 'Broken links present'
      expect(@commercials_page.download_summary_report(@download_path)).to eq(true), 'Summary report could not be downloaded'
      @report_link = @commercials_page.get_summary_report_link
      actual_results = @commercials_page.verify_vendor_import_summary_report(@report_link)
      expect(actual_results).to eq expected_results
    end

    e.run_step 'Verify summary report modal after bulk import' do
      expect(@commercials_page.verify_no_of_invitations(2)).to eq true
      expect(@commercials_page.SUMMARY('Accepted').text).to eq '2'
      expect(@commercials_page.SUMMARY('Rejected').text).to eq '4'
      expect(@commercials_page.SUMMARY('Total').text).to eq '6'
      @tarspect_methods.click_button('close')
    end

    e.run_step 'Verify new vendors present in the vendors list' do
      @output[0].each do |vendor|
        channel_partner = vendor.is_a?(Array) ? vendor[0] : vendor
        expect(@commercials_page.entity_listed?(channel_partner)).to eq true
      end
    end
  end

  it 'Commercials: Bulk Import: Invoice Financing Dealer Program' do |e|
    e.run_step 'Login as Anchor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['anchor']['email'], $conf['users']['anchor']['password'])).to be true
    end

    e.run_step 'Bulk import vendor and verify summary report' do
      @common_pages.click_menu(MENU_DEALERS)
      @output = @commercials_page.bulk_import_vendors('Invoice Financing - Dealer Program')
      @created_dealers << @output[0]
      expected_results = @output[1]
      @created_dealers.flatten!
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq(true), 'Broken links present'
      expect(@commercials_page.download_summary_report(@download_path)).to eq(true), 'Summary report could not be downloaded'
      @report_link = @commercials_page.get_summary_report_link
      actual_results = @commercials_page.verify_vendor_import_summary_report(@report_link)
      expect(actual_results).to eq expected_results
    end

    e.run_step 'Verify summary report modal after bulk import' do
      expect(@commercials_page.verify_no_of_invitations(2)).to eq true
      expect(@commercials_page.SUMMARY('Accepted').text).to eq '2'
      expect(@commercials_page.SUMMARY('Rejected').text).to eq '4'
      expect(@commercials_page.SUMMARY('Total').text).to eq '6'
      @tarspect_methods.click_button('close')
    end

    e.run_step 'Verify new vendors present in the vendors list' do
      @common_pages.click_menu(MENU_DEALERS)
      @common_pages.apply_list_filter({ 'Vendor Status ' => 'Awaiting Vendor Acceptance'.upcase })
      @output[0].each do |dealer|
        channel_partner = dealer.is_a?(Array) ? dealer[0] : dealer
        expect(@commercials_page.entity_listed?(channel_partner)).to eq true
      end
    end
  end

  it 'Commercials: Bulk Import: PO Financing Vendor Program' do |e|
    e.run_step 'Login as Anchor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['grn_anchor']['email'], $conf['users']['grn_anchor']['password'])).to be true
    end

    e.run_step 'Bulk import vendor and verify summary report' do
      @common_pages.click_menu(MENU_VENDORS)
      @output = @commercials_page.bulk_import_vendors('PO Financing - Vendor Program')
      @po_vendors << @output[0]
      expected_results = @output[1]
      @po_vendors.flatten!
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq(true), 'Broken links present'
      expect(@commercials_page.download_summary_report(@download_path)).to eq(true), 'Summary report could not be downloaded'
      @report_link = @commercials_page.get_summary_report_link
      actual_results = @commercials_page.verify_vendor_import_summary_report(@report_link)
      expect(actual_results).to eq expected_results
    end

    e.run_step 'Verify summary report modal after bulk import' do
      expect(@commercials_page.verify_no_of_invitations(3)).to eq true
      expect(@commercials_page.SUMMARY('Accepted').text).to eq '3'
      expect(@commercials_page.SUMMARY('Rejected').text).to eq '4'
      expect(@commercials_page.SUMMARY('Total').text).to eq '7'
      @tarspect_methods.click_button('close')
    end

    e.run_step 'Verify new vendors present in the vendors list' do
      @output[0].each do |vendor|
        channel_partner = vendor.is_a?(Array) ? vendor[0] : vendor
        expect(@commercials_page.entity_listed?(channel_partner)).to eq true
      end
    end
  end

  it 'Commercials: Bulk Import: PO Financing Dealer Program' do |e|
    e.run_step 'Login as Anchor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['grn_anchor']['email'], $conf['users']['grn_anchor']['password'])).to be true
    end

    e.run_step 'Bulk import vendor and verify summary report' do
      @common_pages.click_menu(MENU_DEALERS)
      @po_dealers, expected_results = @commercials_page.bulk_import_vendors('PO Financing - Dealer Program')
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq(true), 'Broken links present'
      expect(@commercials_page.download_summary_report(@download_path)).to eq(true), 'Summary report could not be downloaded'
      @report_link = @commercials_page.get_summary_report_link
      actual_results = @commercials_page.verify_vendor_import_summary_report(@report_link)
      expect(actual_results).to eq expected_results
    end

    e.run_step 'Verify summary report modal after bulk import' do
      expect(@commercials_page.verify_no_of_invitations(3)).to eq true
      expect(@commercials_page.SUMMARY('Accepted').text).to eq '3'
      expect(@commercials_page.SUMMARY('Rejected').text).to eq '4'
      expect(@commercials_page.SUMMARY('Total').text).to eq '7'
      @tarspect_methods.click_button('close')
    end

    e.run_step 'Verify new vendors present in the vendors list' do
      @po_dealers.each do |dealer|
        channel_partner = dealer.is_a?(Array) ? dealer[0] : dealer
        expect(@commercials_page.entity_listed?(channel_partner)).to eq true
      end
    end
  end

  it 'Commercials: Bulk Import by Product User' do |e|
    e.run_step 'Login as Product' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['product']['email'], $conf['users']['product']['password'])).to be true
    end

    e.run_step 'Bulk import vendor and verify summary report' do
      @common_pages.click_menu(MENU_ANCHOR_LIST)
      @common_pages.navigate_to_anchor('TVS')
      @common_pages.select_program('PO Financing', 'Dealer')
      @po_dealers, expected_results, file, _menu = generate_bulk_vendor('PO Financing - Dealer Program')
      @commercials_page.bulk_import_by_product_user(file)
      expect(@commercials_page.download_summary_report(@download_path)).to eq(true), 'Summary report could not be downloaded'
      @report_link = @commercials_page.get_summary_report_link
      actual_results = @commercials_page.verify_vendor_import_summary_report(@report_link)
      expect(actual_results).to eq expected_results
    end

    e.run_step 'Verify summary report modal after bulk import' do
      expect(@commercials_page.verify_no_of_invitations(3)).to eq true
      expect(@commercials_page.SUMMARY('Accepted').text).to eq '3'
      expect(@commercials_page.SUMMARY('Rejected').text).to eq '4'
      expect(@commercials_page.SUMMARY('Total').text).to eq '7'
      @tarspect_methods.click_button('close')
    end

    e.run_step 'Logout as Product' do
      expect(@common_pages.logout).to eq true
    end

    e.run_step 'Login as Anchor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['grn_anchor']['email'], $conf['users']['grn_anchor']['password'])).to be true
    end

    e.run_step 'Verify new vendors present in the vendors list' do
      @common_pages.click_menu(MENU_DEALERS)
      @po_dealers.each do |dealer|
        channel_partner = dealer.is_a?(Array) ? dealer[0] : dealer
        expect(@commercials_page.entity_listed?(channel_partner)).to eq true
      end
    end
  end

  it 'Commercials: Bulk Import Validations:', :bulk_import_validations do |e|
    e.run_step 'Login as Anchor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['anchor']['email'], $conf['users']['anchor']['password'])).to be true
    end

    e.run_step 'Bulk import different file for the program - Sheet name mismatch' do
      @common_pages.click_menu(MENU_VENDORS)
      file = "#{Dir.pwd}/test-data/attachments/bulk_import_inv_vendor.xlsx"
      @output = @commercials_page.initiate_bulk_import(file, 'PO Financing - Vendor Program')
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq(true), 'Broken links present'
      expect(@commercials_page.download_summary_report(@download_path)).to eq(true), 'Summary report could not be downloaded'
      @report_link = @commercials_page.get_summary_report_link
      actual_results = @commercials_page.verify_vendor_import_summary_report(@report_link).keys
      expect(actual_results[0]).to eq 'Sheet name is invalid. Please verify with the existing template.'
    end

    e.run_step 'Verify summary modal when Sheet name mismatch' do
      expect(@commercials_page.verify_no_of_invitations(0)).to eq true
      expect(@commercials_page.SUMMARY('Accepted').text).to eq '0'
      expect(@commercials_page.SUMMARY('Rejected').text).to eq '0'
      expect(@commercials_page.SUMMARY('Total').text).to eq '0'
      @tarspect_methods.click_button('close')
    end

    e.run_step 'Bulk import file with wrong headers' do
      flush_directory(@download_path)
      file = "#{Dir.pwd}/test-data/attachments/bulk_import_wrong_headers.xlsx"
      @output = @commercials_page.initiate_bulk_import(file, 'PO Financing - Vendor Program')
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq(true), 'Broken links present'
      expect(@commercials_page.download_summary_report(@download_path)).to eq(true), 'Summary report could not be downloaded'
      @report_link = @commercials_page.get_summary_report_link
      actual_results = @commercials_page.verify_vendor_import_summary_report(@report_link).keys
      expect(actual_results[0]).to include 'Invalid Columns found in the sheet - ["GST Number"]'
      expect(actual_results[0]).to include 'Missing Columns found in the sheet - ["GSTN"].'
      expect(actual_results[0]).to include 'Please verify with the existing template.'
    end

    e.run_step 'Verify summary modal when headers missing' do
      expect(@commercials_page.verify_no_of_invitations(0)).to eq true
      expect(@commercials_page.SUMMARY('Accepted').text).to eq '0'
      expect(@commercials_page.SUMMARY('Rejected').text).to eq '0'
      expect(@commercials_page.SUMMARY('Total').text).to eq '0'
      @tarspect_methods.click_button('close')
    end

    e.run_step 'Verify anchor can able to download template for bulk vendor import - Invoice Vendor' do
      @common_pages.click_menu(MENU_VENDORS)
      @commercials_page.download_bulk_import_template('Invoice Financing - Vendor Program')
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq(true), 'Broken links present'
      expect(@tarspect_methods.file_downloaded?("#{@download_path}/invoice_vendor_bulk_upload.xlsx")).to eq true
      @common_pages.close_modal
    end

    e.run_step 'Verify anchor can able to download template for bulk vendor import - PO Vendor' do
      @commercials_page.download_bulk_import_template('PO Financing - Vendor Program')
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq(true), 'Broken links present'
      expect(@tarspect_methods.file_downloaded?("#{@download_path}/po_vendor_bulk_upload.xlsx")).to eq true
      @common_pages.close_modal
    end

    e.run_step 'Verify anchor can able to download template for bulk vendor import - Invoice Dealer' do
      @common_pages.click_menu(MENU_DEALERS)
      @commercials_page.download_bulk_import_template('Invoice Financing - Dealer Program')
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq(true), 'Broken links present'
      expect(@tarspect_methods.file_downloaded?("#{@download_path}/invoice_dealer_bulk_upload.xlsx")).to eq true
      @common_pages.close_modal
    end

    e.run_step 'Verify anchor can able to download template for bulk vendor import - PO Dealer' do
      @commercials_page.download_bulk_import_template('PO Financing - Dealer Program')
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq(true), 'Broken links present'
      expect(@tarspect_methods.file_downloaded?("#{@download_path}/po_dealer_bulk_upload.xlsx")).to eq true
      @common_pages.close_modal
    end
  end
end
