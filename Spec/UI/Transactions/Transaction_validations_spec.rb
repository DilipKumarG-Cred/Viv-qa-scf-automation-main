require './spec_helper'
describe 'Transactions: Inititation Validations', :scf, :transactions, :inititation_validations do
  before(:all) do
    @anchor_gstn = $conf['myntra_gstn']
    @counterparty_gstn = $conf['libas_gstn']
    @invoice_file = "#{Dir.pwd}/test-data/attachments/anchor_invoice.pdf"
    @file_name = 'anchor_invoice.pdf'
    @erb_file = File.read("#{Dir.pwd}/test-data/erb/testbed_data.erb")
    @vendor_gstn = $conf['users']['vendor']['gstn']
  end

  before(:each) do
    @driver = Tarspect::Browser.new($conf['browser']).invoke
    @tarspect_methods = Common::Methods.new(@driver)
    @common_pages = Pages::CommonMethods.new(@driver)
    @transactions_page = Pages::Trasactions.new(@driver)
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
  end

  after(:each) do |e| # Captures screenshot of the current page when failure happens
    snap_screenshot(e)
    quit_browser
  end

  it 'Transactions: Inititation Validations' do |e|
    e.run_step 'Login as Anchor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users']['anchor']['email'], $conf['users']['anchor']['password'])).to be true
    end

    e.run_step "Verify 'Due Date' option is enabled and tenor is calculated properly" do
      @common_pages.click_menu(MENU_INOICE_FINANCING)
      @tarspect_methods.click_button('Add Transaction')
      @transactions_page.select_transaction_program('Vendor Financing', 1)
      @transactions_page.select_transaction_program('Invoice', 2)
      @testdata['Invoice Details']['Due Date'] = (Date.today + 151).strftime('%d-%b-%Y')
      @transactions_page.upload_invoice(@invoice_file, @testdata['Invoice Details'])
      @tarspect_methods.DYNAMIC_LOCATOR('GRN').click # For data reflection in due date field
      sleep 5
      expect(@transactions_page.tenor_computed.get_attribute('disabled')).to eq('true'), 'Tenor value is editable after entering Due Date'
      tenor_value = @transactions_page.tenor_computed.get_attribute('value')
      expect(tenor_value).to eq('151'), "Tenor value should be 151, but getting #{tenor_value}"
    end

    e.run_step "Verify 'Due Date' option is enabled for PO transactions" do
      @transactions_page.select_transaction_program('Vendor Financing', 1)
      @transactions_page.select_transaction_program('PO', 2)
      expect(@transactions_page.due_date.is_present?).to eq(true), 'Due date field is not present'
      expect(@tarspect_methods.DYNAMIC_LOCATOR('Due Date').is_present?).to eq(true), 'Due date field is not present'
    end

    e.run_step "Verify 'Due Date' is calculated properly based on tenor" do
      @common_pages.click_back_button
      @transactions_page.select_transaction_program('Vendor Financing', 1)
      @transactions_page.select_transaction_program('Invoice', 2)
      @testdata['Invoice Details'].delete('Due Date')
      @testdata['Invoice Details']['Tenor'] = 151
      @transactions_page.upload_invoice(@invoice_file, @testdata['Invoice Details'])
      @tarspect_methods.DYNAMIC_LOCATOR('Due Date').click # For data reflection in due date field
      sleep 5
      expect(@transactions_page.due_date_computed.get_attribute('disabled')).to eq('true'), 'Tenor value is editable after entering Due Date'
      due_date_value = @transactions_page.due_date_computed.get_attribute('value')
      expect(due_date_value).to eq((Date.today + 151).strftime('%d %b, %Y')), "Due Date value should be '#{(Date.today + 151).strftime('%d %b, %Y')}', but getting #{due_date_value}"
    end

    e.run_step 'Verify Tenor cannot be greater than 200' do
      @transactions_page.tenor.fill(202, true)
      expect(@common_pages.ERROR_MESSAGE('Tenor').text).to eq('Tenor must be in range of 1-200 days')
    end

    e.run_step 'Verify transactions can be disbursed if the derived tenor is greater than BD tenor' do
      @counterparty_gstn = $conf['myntra_gstn']
      @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
      @testdata['Vendor Invoice Details'].merge!(
        'Invoice Date' => (Date.today - 45).strftime('%d-%b-%Y'),
        'Due Date Computed' => (Date.today + 151).strftime('%d-%b-%Y'),
        'tenor' => 151
      )
      @transaction_id = seed_transaction({
                                           actor: 'vendor',
                                           counter_party: 'anchor',
                                           invoice_details: @testdata['Vendor Invoice Details'],
                                           invoice_file: @invoice_file,
                                           program: 'Invoice Financing - Vendor',
                                           investor_id: 7,
                                           program_group: 'invoice'
                                         })
      expect(@transaction_id).not_to include('Error while creating transaction')
      @current_due_date = (Date.today + 151).strftime('%d-%b-%Y')
      @details = disburse_transaction({
                                        transaction_id: @transaction_id,
                                        invoice_value: @testdata['Vendor Invoice Details']['Invoice Value'],
                                        type: 'frontend',
                                        date_of_payment: @current_due_date,
                                        payment_proof: @payment_proof,
                                        program: 'Invoice Financing - Vendor',
                                        tenor: 151,
                                        yield: 10,
                                        strategy: 'simple_interest'
                                      })
      expect(@details).not_to include('Error while disbursements')
    end

    e.run_step 'Verify Interest Chargeable is calculated based on derived Tenor' do
      resp = get_transaction_details(@transaction_id)
      transaction_values = calculate_transaction_values({
        invoice_value: @testdata['Vendor Invoice Details']['Invoice Value'],
        margin: 10,
        yield: 10,
        tenor: 151,
        type: 'frontend',
        strategy: 'simple_interest'
      })
      expect(resp[:body][:estimated_interest]).to eq(transaction_values[2])
    end
  end
end
