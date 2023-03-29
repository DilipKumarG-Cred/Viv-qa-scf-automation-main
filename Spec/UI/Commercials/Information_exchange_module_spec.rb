require './spec_helper'
describe 'Information Exchange Module: Data Verification', :scf, :commercials, :iem, :mails do
  before(:all) do
    @anchor_actor = 'iem_anchor'
    @investor_actor = 'user_feedback_investor'
    @channel_partner_actor = 'iem_vendor'
    @anchor_name = $conf['users'][@anchor_actor]['name']
    @anchor_id = $conf['users'][@anchor_actor]['id']
    @investor_name = $conf['users'][@investor_actor]['name']
    @channel_partner_name = $conf['users'][@channel_partner_actor]['name']
    @program_type = 'Invoice Financing - Dealer'
    @file_to_upload = "#{Dir.pwd}/test-data/attachments/anchor_invoice.pdf"
    @download_path = "#{Dir.pwd}/test-data/downloaded/iem_data_verification"
  end

  before(:each) do
    @driver = Tarspect::Browser.new($conf['browser'], @download_path).invoke
    @tarspect_methods = Common::Methods.new(@driver)
    @common_pages = Pages::CommonMethods.new(@driver)
    @investor_page = Pages::Investor.new(@driver)
    @programs_page = Pages::Programs.new(@driver)
    @commercials_page = Pages::Commercials.new(@driver)
    delete_draft_program('Invoice Financing - Dealer', @anchor_actor)
    delete_live_program('Invoice Financing', 'Dealer', @anchor_id)
    flush_directory(@download_path)
  end

  after(:each) do |e|
    snap_screenshot(e)
    quit_browser
  end

  it 'Information Exchange Module: Investor raises Query against Anchor', :no_run do |e|
    e.run_step 'Create & Publish a program' do
      @create_values = {
        max_tranche: 60,
        program_size: 600_000_000,
        exposure: [0, 600_000_000],
        price_expectation: [0, 11],
        type: @program_type,
        actor: @anchor_actor
      }
      draft_program = create_anchor_program(@create_values)
      expect(draft_program[:code]).to eq(200)
      expect(draft_program[:body][:anchor_programs][0][:status]).to eq('draft')
      @program_id = draft_program[:body][:anchor_programs][0][:id]
      resp = publish_anchor_program(@anchor_actor, @program_id)
      expect(resp[:body][:available_programs][:published_programs][0][:id]).to eq(@program_id)
    end

    e.run_step 'Express Interest on Program' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users'][@investor_actor]['email'], $conf['users'][@investor_actor]['password'])).to be true
      @common_pages.click_menu(MENU_EXPLORE_PROGRAMS)
      @common_pages.search_program(@anchor_name)
      @choose_program_values = {
        header: 'Explore Programs',
        where: 'investor_explore',
        anchor: @anchor_name,
        validate_only: false,
        type: @program_type
      }
      expect(@programs_page.investor_choose_program(@choose_program_values)).to eq(true), "#{@program_type}, #{@anchor_name} not found"
      @tarspect_methods.click_button('Express Interest')
      @tarspect_methods.wait_for_loader_to_disappear
      expect(@programs_page.pending_review_available?(@anchor_name)).to eq true
    end

    e.run_step 'Verify query can be added' do
      @investor_page.add_query_btn.click
      @query = { type: 'Financials', query: 'Can you upload docs related to your products' }
      notifications = @investor_page.add_query(@query)
      expect(notifications[0]).to eq('Query created successfully')
      expect(notifications[1][0]).to eq('Your query has been posted successfully!')
      expect(notifications[1][1]).to eq('Your Anchor also notified on the same!')
    end

    e.run_step 'Logout as Investor' do
      expect(@common_pages.logout).to eq(true)
    end

    e.run_step 'Verify mail intimation on query raised' do
      email_values = {
        mail_box: $conf['notification_mailbox'],
        subject: "#{$notifications['YubiFlowAlert']}: #{@investor_name} requested some information from you",
        body: [@anchor_name, @query[:query]],
        link_text: 'programs'
      }
      @login_link = @common_pages.get_link_from_mail(email_values, new_tab: false)
      expect(@login_link.empty?).to eq(false)
    end

    e.run_step 'Navigate to link & Login as Anchor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users'][@anchor_actor]['email'], $conf['users'][@anchor_actor]['password'])).to be true
      @tarspect_methods.wait_for_loader_to_disappear
      navigate_to(@login_link)
      link = @login_link.gsub('credavenue', 'go-yubi')
      expect(@driver.current_url).to eq(link)
    end

    e.run_step 'Reply on the Query' do
      @answer = { query: @query[:query], answer: 'Here you go!', file: @file_to_upload }
      notifications = @investor_page.respond_query(@answer, resolve: false)
      expect(notifications[0]).to eq('Message sent')
    end

    e.run_step 'Logout as Anchor' do
      expect(@common_pages.logout).to eq(true)
    end

    e.run_step 'Verify mail intimation on query reply' do
      email_values = {
        mail_box: $conf['notification_mailbox'],
        subject: "#{$notifications['YubiFlowAlert']}: #{@anchor_name} has responded for your query",
        body: [@investor_name, "has provided the below response to your query on #{Date.today.strftime('%Y-%m-%d')}", @answer[:answer]],
        link_text: 'stg'
      }
      links = @common_pages.get_link_from_mail(email_values, new_tab: false)
      @doc_link = links[0]
      expect(@doc_link.empty?).to eq(false)
      @login_link = links[1]
      expect(@login_link.empty?).to eq(false)
    end

    e.run_step 'Navigate to link & Login as Investor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users'][@investor_actor]['email'], $conf['users'][@investor_actor]['password'])).to be true
      @tarspect_methods.wait_for_loader_to_disappear
      navigate_to(@login_link)
      link = @login_link.gsub('credavenue', 'go-yubi')
      expect(@driver.current_url).to eq(link)
    end

    e.run_step 'Verify response to the query' do
      response = "#{@answer[:answer]}\nanchor_invoice.pdf (43.63 KB)"
      expect(@investor_page.get_query_response(@answer)).to eq(response)
    end

    e.run_step 'Verify documents uploaded by anchor' do
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
      @common_pages.download_button.click
      expect(@tarspect_methods.file_downloaded?("#{@download_path}/anchor_invoice.pdf")).to eq(true)
    end

    e.run_step 'Respond to the query response' do
      @answer[:answer] = 'Thanks'
      @investor_page.comment_on_query(@answer[:answer])
      @tarspect_methods.click_button('Send')
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq('Message sent')
    end

    e.run_step 'Logout as Investor' do
      expect(@common_pages.logout).to eq(true)
    end

    e.run_step 'Login as Anchor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users'][@anchor_actor]['email'], $conf['users'][@anchor_actor]['password'])).to be true
      @tarspect_methods.wait_for_loader_to_disappear
    end

    e.run_step 'Verify mail received' do
      email_values = {
        mail_box: $conf['notification_mailbox'],
        subject: "#{$notifications['YubiFlowAlert']}: #{@investor_name} has responded for your query",
        body: [@anchor_name, @answer[:answer]],
        link_text: 'programs'
      }
      @login_link = @common_pages.get_link_from_mail(email_values, new_tab: false)
      expect(@login_link.empty?).to eq(false)
    end

    e.run_step 'Navigate to link as anchor' do
      link = @login_link.gsub('credavenue', 'go-yubi')
      expect(@driver.current_url).to eq(link)
    end

    e.run_step 'Verify query can be resolved' do
      @answer[:answer] = 'Closing the query..'
      @answer.delete(:file)
      notifications = @investor_page.respond_query(@answer, resolve: true)
      expect(notifications[0]).to eq('Message sent')
      expect(notifications[1]).to eq('Query resolved!')
    end

    e.run_step 'Verify query moved to resolved state' do
      expect(@common_pages.SIMPLE_XPATH('No Queries').is_displayed?).to eq(true)
      @common_pages.SIMPLE_XPATH('Resolved').click
      expect(@investor_page.QUERY_BOX(@answer[:query]).is_displayed?).to eq(true)
      expect(@investor_page.fetch_resolved_state(@answer[:query])).to eq(true)
    end
  end

  it 'Information Exchange Module: Investor raises Query against Channel Partner' do |e|
    e.run_step 'Verify Query can be added to channel partner' do
      @program_type = 'Invoice Financing - Vendor'
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users'][@investor_actor]['email'], $conf['users'][@investor_actor]['password'])).to be true
      @common_pages.click_menu(MENU_ANCHOR_LIST)
      @common_pages.apply_filter({ 'Anchor Name' => @anchor_name })
      @common_pages.navigate_to_anchor(@anchor_name)
      @common_pages.select_program('Invoice Financing', 'Vendor')
      @commercials_page.navigate_to_vendor(@channel_partner_name)
      @query = { type: 'Financials', query: "Can you upload docs related to your products #{Date.today}" }
      @tarspect_methods.wait_for_loader_to_disappear
      @commercials_page.query_tab.click
      @tarspect_methods.wait_for_loader_to_disappear
      @investor_page.add_query_btn.click
      notifications = @investor_page.add_query(@query)
      expect(notifications[0]).to eq('Query created successfully')
      expect(notifications[1][0]).to eq('Your query has been posted successfully!')
      expect(notifications[1][1]).to eq('Your Channel Partner also notified on the same!')
    end

    e.run_step 'Logout as Investor' do
      expect(@common_pages.logout).to eq(true)
    end

    e.run_step 'Login as Channel Partner' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users'][@channel_partner_actor]['email'], $conf['users'][@channel_partner_actor]['password'])).to be true
      @tarspect_methods.wait_for_loader_to_disappear
    end

    e.run_step 'Verify mail intimation on query raised' do
      email_values = {
        mail_box: $conf['notification_mailbox'],
        subject: "#{$notifications['YubiFlowAlert']}: #{@investor_name} requested some information from you",
        body: [@channel_partner_name, @query[:query]],
        link_text: 'Vendor'
      }
      @login_link = @common_pages.get_link_from_mail(email_values, new_tab: false)
      expect(@login_link.empty?).to eq(false)
    end

    e.run_step 'Navigate to link & Login as Channel Partner' do
      # navigate_to(@login_link)
      link = @login_link.gsub('credavenue', 'go-yubi')
      expect(@driver.current_url).to eq(link)
    end

    e.run_step 'Channel Partner Reply on the Investor Query' do
      @investor_page.select_investor(@investor_name)
      second_file_to_upload = "#{Dir.pwd}/test-data/attachments/dealer_invoice.pdf"
      @answer = { query: @query[:query], answer: 'Here you go!', file: [@file_to_upload, second_file_to_upload] }
      notifications = @investor_page.respond_query(@answer, resolve: false)
      expect(notifications[0]).to eq('Message sent')
    end

    e.run_step 'Logout as Channel Partner' do
      expect(@common_pages.logout).to eq(true)
    end

    e.run_step 'Login as Investor' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users'][@investor_actor]['email'], $conf['users'][@investor_actor]['password'])).to be true
    end

    e.run_step 'Verify mail intimation on on channel partner query response' do
      email_values = {
        mail_box: $conf['notification_mailbox'],
        subject: "#{$notifications['YubiFlowAlert']}: #{@channel_partner_name} has responded for your query",
        body: [@investor_name, "has provided the below response to your query on #{Date.today.strftime('%Y-%m-%d')}", @answer[:answer]],
        link_text: 'stg'
      }
      links = @common_pages.get_link_from_mail(email_values, new_tab: false)
      @doc_link = links[0]
      expect(@doc_link.empty?).to eq(false)
      @login_link = links[1]
      expect(@login_link.empty?).to eq(false)
    end

    e.run_step 'Verify zip file is downloaded' do
      @tarspect_methods.wait_for_loader_to_disappear
      navigate_to(@doc_link)
      sleep 5
      @zip_file = @common_pages.get_zip_file(@download_path)
      expect(@zip_file.empty?).to eq(false), 'File not downloaded'
    end

    e.run_step 'Verify ZIP file' do
      files_list = @common_pages.unzip_file("#{@download_path}/#{@zip_file}")
      expect(files_list).to eq(['dealer_invoice.pdf', 'anchor_invoice.pdf'])
    end

    e.run_step 'Navigate to link' do
      @login_link = @login_link.gsub('credavenue', 'go-yubi')
      navigate_to(@login_link)
      expect(@driver.current_url).to eq(@login_link)
    end

    e.run_step 'Verify response to the query' do
      response = "#{@answer[:answer]}\ndealer_invoice.pdf (43.63 KB)\nanchor_invoice.pdf (43.63 KB)"
      expect(@investor_page.get_query_response(@answer)).to eq(response)
    end

    e.run_step 'Verify documents uploaded by channel partner' do
      expect(@tarspect_methods.check_for_broken_links('billdiscounting')).to eq true
      @common_pages.download_button.fetch_elements.each(&:click)
      expect(@tarspect_methods.file_downloaded?("#{@download_path}/anchor_invoice.pdf")).to eq(true)
      expect(@tarspect_methods.file_downloaded?("#{@download_path}/dealer_invoice.pdf")).to eq(true)
    end

    e.run_step 'Respond to the query response' do
      @answer[:answer] = 'Thanks'
      @investor_page.comment_on_query(@answer[:answer])
      @tarspect_methods.click_button('Send')
      expect(@tarspect_methods.assert_and_close_toaster(MIN_LOADER_TIME)).to eq('Message sent')
    end

    e.run_step 'Logout as Investor' do
      expect(@common_pages.logout).to eq(true)
    end

    e.run_step 'Login as Channel Partner' do
      navigate_to($conf['base_url'])
      expect(@tarspect_methods.login($conf['users'][@channel_partner_actor]['email'], $conf['users'][@channel_partner_actor]['password'])).to be true
      @tarspect_methods.wait_for_loader_to_disappear
    end

    e.run_step 'Verify mail received' do
      email_values = {
        mail_box: $conf['notification_mailbox'],
        subject: "#{$notifications['YubiFlowAlert']}: #{@investor_name} has responded for your query",
        body: [@channel_partner_name, @answer[:answer]],
        link_text: 'Vendor'
      }
      @login_link = @common_pages.get_link_from_mail(email_values, new_tab: false)
      expect(@login_link.empty?).to eq(false)
    end

    e.run_step 'Navigate to link as channel partner' do
      link = @login_link.gsub('credavenue', 'go-yubi')
      expect(@driver.current_url).to eq(link)
    end

    e.run_step 'Verify query can be resolved' do
      @answer[:answer] = 'Closing the query..'
      @answer.delete(:file)
      @investor_page.select_investor(@investor_name)
      notifications = @investor_page.respond_query(@answer, resolve: true)
      expect(notifications[0]).to eq('Message sent')
      expect(notifications[1]).to eq('Query resolved!')
    end

    e.run_step 'Verify query moved to resolved state' do
      refresh_page
      @investor_page.select_investor(@investor_name)
      expect(@investor_page.QUERY_BOX(@answer[:query]).is_displayed?).to eq(false)
      @common_pages.SIMPLE_XPATH('Resolved').click
      expect(@investor_page.QUERY_BOX(@answer[:query]).is_displayed?).to eq(true)
      expect(@investor_page.fetch_resolved_state(@answer[:query])).to eq(true)
    end
  end
end
