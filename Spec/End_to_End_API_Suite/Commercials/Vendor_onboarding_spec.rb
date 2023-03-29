require './spec_helper'
describe 'Commercials: Vendor Onboarding', :scf, :commercials, :onboarding, :vendor_onboarding, :mails do
  before(:all) do
    @anchor_actor = 'anchor'
    @erb_file = File.read("#{Dir.pwd}/test-data/erb/commercials_data.erb")
    @borrowing_document = "#{Dir.pwd}/test-data/attachments/borrowing_document.pdf"
    @program_name = 'Invoice Financing - Vendor Program'
    @created_vendors = []
  end

  after(:all) do
    delete_channel_partner('Vendor', @created_vendors)
  end

  it 'Commercials: Vendor Invitation and Commercials Setup', :new_vendor_onboard do |e|
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
    @testdata['Commercials']['GSTN'] = "#{Faker::Number.number(digits: 2)}#{@testdata['Commercials']['PAN']}#{Faker::Number.number(digits: 1)}Z#{Faker::Internet.user_name(specifier: 1..1).upcase}"
    @commercials_data = @testdata['Commercials']
    @company_info = @testdata['Company Info']
    @promoter_info = @testdata['Promoter Info']
    @km_person_info = @testdata['Key Managing Person Info']
    @bank_details = @testdata['Bank Details']
    @company_kyc_docs = @testdata['Documents']['Company KYC Documents']
    @promoter_kyc_docs = @testdata['Documents']['Promoter KYC Documents']
    @financial_docs = @testdata['Documents']['Financials']
    @bank_statements = @testdata['Documents']['Bank Statements']
    @gst_returns = @testdata['Documents']['GST Returns']
    @created_vendors << @commercials_data['Entity Name']

    e.run_step 'Create a Channel Partner' do
      resp = create_channel_partner(@commercials_data)
      @commercials_data['Name'] = @commercials_data['Entity Name']
      expect(resp[:code]).to eq(200)
    end

    e.run_step 'Verify vendor status as awaiting_vendor_acceptance' do
      @vendor_response = fetch_list_all_vendors('Vendor', @anchor_actor, @commercials_data['Name'])
      expect(@vendor_response[0][:state]).to eq('awaiting_vendor_acceptance')
    end

    e.run_step 'Activate a Channel Partner' do
      resp = api_activate_channel_partner(@commercials_data['Email'])
      expect(resp[:code]).to eq(200)
    end

    e.run_step 'Verify vendor status as awaiting_vendor_acceptance' do
      @vendor_response = fetch_list_all_vendors('Vendor', @anchor_actor, @commercials_data['Name'])
      expect(@vendor_response[0][:state]).to eq('awaiting_vendor_acceptance')
    end

    e.run_step 'Verify Company information can be added' do
      @vendor = @commercials_data['Email'].split('@')[0]
      sleep 5
      set_cookies_api(@vendor, @commercials_data['Email'], $conf['users']['anchor']['password'])
      resp = add_company_info(@vendor, @company_info)
      expect(resp[:code]).to eq(200), resp.to_s
    end

    e.run_step 'Verify Promoter Information can be added' do
      resp = add_promoter_info(@vendor, @promoter_info)
      expect(resp[:code]).to eq(200), resp.to_s
    end

    e.run_step 'Verify Key Manager Information can be added' do
      @values = { anchor_actor: 'anchor', actor: @vendor, program: @commercials_data['Program'], km_person_info: @km_person_info }
      resp = add_key_manager_info(@values)
      expect(resp[:code]).to eq(200), resp.to_s
    end

    e.run_step 'Verify Bank details can be added' do
      @values.merge!(program: @commercials_data['Program'], bank_details: @bank_details)
      resp = add_bank_details(@values)
      expect(resp[:code]).to eq(200), resp.to_s
    end

    e.run_step 'Verify documents can be uploaded' do
      resp = upload_onbaording_documents({ actor: @vendor, type: 'mandatory_docs' })
      expect(resp).to eq(true)
    end

    e.run_step 'Verify vendor status as pending_registeration' do
      @vendor_response = fetch_list_all_vendors('Vendor', @anchor_actor, @commercials_data['Name'])
      expect(@vendor_response[0][:state]).to eq('pending_registration')
    end

    e.run_step 'Verify Channel Partner registeration can be submitted' do
      resp = submit_for_review(@vendor)
      expect(resp[:code]).to eq(200), resp.to_s
      expect(resp[:body][:kyc_status]).to eq('review_pending')
    end

    e.run_step 'Verify vendor status as awaiting_platform_verification' do
      @vendor_response = fetch_list_all_vendors('Vendor', @anchor_actor, @commercials_data['Name'])
      expect(@vendor_response[0][:state]).to eq('awaiting_platform_verification')
    end

    e.run_step 'Verify all documents can be approved as a platform team' do
      result = review_all_docs({ actor: @vendor, doc_type: 'mandatory_docs' }, action: :approve)
      expect(result).to eq true
    end

    e.run_step 'Verify Channel Partner can be approved' do
      resp = review_vendor(@vendor, 'approved')
      expect(resp[:code]).to eq(200), resp.to_s
    end

    e.run_step 'Verify client profile page after submit for approval - Company Info' do
      @vendor_response = api_get_vendor_details(@vendor)
      expect(@vendor_response[:body][:vendor_detail][:city]).to eq(@company_info['City'])
      expect(@vendor_response[:body][:vendor_detail][:geography]).to eq(@company_info['Geography'].downcase)
      expect(@vendor_response[:body][:vendor_detail][:entity_type]).to eq(@company_info['Entity Type'].gsub(' ', '_').downcase)
      expect(@vendor_response[:body][:anchor_program_vendor_detail][:contact_no]).to eq(@company_info['Phone Number'])
      expect(@vendor_response[:body][:pan]).to eq(@commercials_data['PAN'])
    end

    e.run_step 'Verify client profile page after submit for approval - Promoter Info' do
      promoter_details = @vendor_response[:body][:promoters][0]
      expect(promoter_details[:name]).to eq(@promoter_info['Full Name'])
      expect(promoter_details[:contact]).to eq(@promoter_info['Phone Number'])
      expect(promoter_details[:shareholding_percentage].to_i).to eq(@promoter_info['Shareholding'].to_i)
    end

    e.run_step 'Verify client profile page after submit for approval - Key managing person Info' do
      key_managing_persons_info = @vendor_response[:body][:key_managing_persons_info][0]
      expect(key_managing_persons_info[:name]).to eq(@km_person_info['Full Name'])
      expect(key_managing_persons_info[:email]).to eq(@km_person_info['Email Id'])
      expect(key_managing_persons_info[:contact]).to eq(@km_person_info['Phone Number'])
      expect(key_managing_persons_info[:designation]).to eq(@km_person_info['Designation'])
    end

    e.run_step 'Verify client documents after submit for approval - Mandatory KYC documents' do
      expect(review_all_docs({ actor: @vendor, doc_type: 'mandatory_docs' }, action: :verify)).to eq(true)
    end

    e.run_step 'Verify vendor status as approved' do
      @vendor_response = fetch_list_all_vendors('Vendor', @anchor_actor, @commercials_data['Name'])
      expect(@vendor_response[0][:state]).to eq('approved')
    end
  end
end
