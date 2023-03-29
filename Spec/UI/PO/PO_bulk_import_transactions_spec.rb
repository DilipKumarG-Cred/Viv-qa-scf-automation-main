require './spec_helper'
describe 'PO Transactions: Bulk import', :scf, :po, :transactions, :bulk_import, :bulk do
  before(:each) do
    @download_path = "#{Dir.pwd}/test-data/downloaded/po_bulk_import"
    @driver = Tarspect::Browser.new($conf['browser'], @download_path).invoke
    @tarspect_methods = Common::Methods.new(@driver)
    @common_pages = Pages::CommonMethods.new(@driver)
    @transactions_page = Pages::Trasactions.new(@driver)
    flush_directory(@download_path)
    # clear_all_overdues(anchor: $conf['grn_anchor_name'], vendor: $conf['users']['po_dealer']['name'])
  end

  after(:each) do |e| # Captures screenshot of the current page when failure happens
    snap_screenshot(e)
    quit_browser
  end

  it 'PO Bulk import: Anchor' do |e|
    e.run_step 'Login as anchor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['grn_anchor']['email'], $conf['users']['grn_anchor']['password'])).to eq true
    end

    e.run_step 'Import bulk transaction and verify summary report' do
      expected_results = @transactions_page.add_po_bulk_transaction('grn_anchor', 'Vendor Financing', 'PO')
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
      expect(@transactions_page.download_summary_report(@download_path)).to eq true
      @report_link = @transactions_page.get_summary_report_link
      actual_results = @transactions_page.verify_summary_report(@report_link)
      expect(actual_results).to eq expected_results
    end

    e.run_step 'Verify summary report modal after bulk import' do
      expect(@transactions_page.transaction_summary_present?).to eq true
      expect(@transactions_page.verify_summary('Total Transactions')).to eq '10'
      expect(@transactions_page.verify_summary('Accepted Transactions')).to eq '2'
      expect(@transactions_page.verify_summary('Rejected Transactions')).to eq '8'
      expect(@transactions_page.verify_summary('Total Value')).to eq '15000'
      @tarspect_methods.click_button('close')
    end

    e.run_step 'Verify transactions created for the valid records' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      expect(@transactions_page.verify_valid_po_transactions('grn_anchor', page: :anchor)).to eq true
    end

    e.run_step 'Verify invoices are uploaded to transactions' do
      errors = @transactions_page.validate_doc_uploaded('po', @report_link)
      expect(errors.size).to eq(1), "Documents are not uploaded properly #{errors}"
      flush_directory(@download_path)
    end
  end

  it 'PO Bulk import: Vendor' do |e|
    e.run_step 'Login as Vendor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['po_vendor']['email'], $conf['users']['po_vendor']['password'])).to eq true
    end

    e.run_step 'Import bulk transaction and verify summary report' do
      navigate_to($conf['transactions_url'])
      expected_results = @transactions_page.add_po_bulk_transaction('po_vendor', 'Vendor Financing', 'PO')
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
      expect(@transactions_page.download_summary_report(@download_path)).to eq true
      report_link = @transactions_page.get_summary_report_link
      actual_results = @transactions_page.verify_summary_report(report_link)
      expect(actual_results).to eq expected_results
    end

    e.run_step 'Verify summary report modal after bulk import' do
      expect(@transactions_page.transaction_summary_present?).to eq true
      expect(@transactions_page.verify_summary('Total Transactions')).to eq '10'
      expect(@transactions_page.verify_summary('Accepted Transactions')).to eq '2'
      expect(@transactions_page.verify_summary('Rejected Transactions')).to eq '8'
      expect(@transactions_page.verify_summary('Total Value')).to eq '15000'
      @tarspect_methods.click_button('close')
    end

    e.run_step 'Verify transactions created for the valid records' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      expect(@transactions_page.verify_valid_po_transactions('po_vendor', page: :vendor)).to eq true
      flush_directory(@download_path)
    end
  end

  it 'PO Bulk import: Dealer', :po_bulk_import_dealer do |e|
    e.run_step 'Login as Dealer' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['po_dealer']['email'], $conf['users']['po_dealer']['password'])).to eq true
    end

    e.run_step 'Import bulk transaction and verify summary report' do
      navigate_to($conf['transactions_url'])
      expected_results = @transactions_page.add_po_bulk_transaction('po_dealer', 'Dealer Financing', 'PO')
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
      expect(@transactions_page.download_summary_report(@download_path)).to eq true
      @report_link = @transactions_page.get_summary_report_link
      actual_results = @transactions_page.verify_summary_report(@report_link)
      expect(actual_results).to eq expected_results
    end

    e.run_step 'Verify summary report modal after bulk import' do
      expect(@transactions_page.transaction_summary_present?).to eq true
      expect(@transactions_page.verify_summary('Total Transactions')).to eq '10'
      expect(@transactions_page.verify_summary('Accepted Transactions')).to eq '2'
      expect(@transactions_page.verify_summary('Rejected Transactions')).to eq '8'
      expect(@transactions_page.verify_summary('Total Value')).to eq '15000'
      @tarspect_methods.click_button('close')
    end

    e.run_step 'Verify transactions created for the valid records' do
      @common_pages.click_menu(MENU_PO_FINANCING)
      expect(@transactions_page.verify_valid_po_transactions('po_dealer', page: :vendor)).to eq true
    end

    e.run_step 'Verify invoices are uploaded to transactions' do
      errors = @transactions_page.validate_doc_uploaded('po', @report_link)
      expect(errors.size).to eq(1), "Documents are not uploaded properly #{errors}"
      flush_directory(@download_path)
    end
  end
end
