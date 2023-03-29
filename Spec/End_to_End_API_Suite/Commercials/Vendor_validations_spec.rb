require './spec_helper'
describe 'Commercials: Vendor Reject', :scf, :commercials, :onboarding, :vendor_reject, :mails do
  before(:all) do
    @anchor_actor = 'anchor'
    @erb_file = File.read("#{Dir.pwd}/test-data/erb/commercials_data.erb")
    @borrowing_document = "#{Dir.pwd}/test-data/attachments/borrowing_document.pdf"
    @program_name = 'Invoice Financing - Vendor Program'
    @created_vendors = []
  end

  after(:each) do
    delete_channel_partner('Vendor', @created_vendors)
  end

  it 'Commercials : Onboard Existing Vendors' do |e|
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
    @commercials_data = @testdata['Commercials']
    @commercials_data['Entity Name'] = 'Libas Impex'
    @commercials_data['GSTN'] = $conf['libas_gstn']
    @commercials_data['PAN'] = $conf['libas_gstn'][2..11]

    e.run_step 'Verify adding existing vendor in same anchor' do
      resp = create_channel_partner(@commercials_data)
      expect(resp[:code]).to eq(422)
      expect(resp[:body][:error][:message]).to eq("Invalid data - #{@commercials_data['Entity Name']} is already associated in INVOICE-VENDOR program")
    end

    e.run_step 'Verify adding existing vendor in different anchor' do
      delete_channel_partner('Vendor', [['Exide', 'INVOICE FINANCING']], 'anchor')
      @commercials_data['Entity Name'] = 'Exide'
      @commercials_data['GSTN'] = $conf['users']['po_vendor']['gstn']
      @created_response = create_channel_partner(@commercials_data)
      expect(@created_response[:code]).to eq(200)
    end

    e.run_step 'Remove Vendor from anchor' do
      sleep 5
      program_id = get_anchor_program_id('Invoice Financing', 'Vendor', 4)
      values = {
        program_id: program_id,
        program_type: 'Vendor',
        actor: @anchor_actor,
        vendors: [@commercials_data['Entity Name']]
      }
      expect(delete_vendor(values)).to eq true
    end

    e.run_step 'Verify vendor should not be present after removal' do
      @vendor_response = fetch_list_all_vendors('Vendor', @anchor_actor, @commercials_data['Entity Name'])
      expect(@vendor_response).to match_array([])
    end
  end

  it 'Commercials : Vendor Onboarding Validations' do |e|
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
    @commercials_data = @testdata['Commercials']
    @company_info = @testdata['Company Info']
    @promoter_info = @testdata['Promoter Info']
    @km_person_info = @testdata['Key Managing Person Info']

    @commercials_data['GSTN'] = "#{Faker::Number.number(digits: 2)}#{@commercials_data['PAN']}#{Faker::Number.number(digits: 1)}Z#{Faker::Internet.user_name(specifier: 1..1).upcase}"
    actual_email = @commercials_data['Email']
    actual_gstn = @commercials_data['GSTN']
    @created_vendors << @commercials_data['Entity Name']

    e.run_step 'Add vendor with invalid GSTN data' do
      @commercials_data['GSTN'] = "#{Faker::Number.number(digits: 1)}#{@commercials_data['PAN']}#{Faker::Number.number(digits: 2)}Z#{Faker::Internet.user_name(specifier: 1..1).upcase}"
      resp = create_channel_partner(@commercials_data)
      expect(resp[:code]).to eq(400), resp.to_s
      expect(resp[:body][:error][:message]).to eq('Please provide a valid GSTN')
    end

    e.run_step 'Add vendor with invalid Email data' do
      @commercials_data['GSTN'] = actual_gstn
      @commercials_data['Email'] = 'aksdnfkajdnfandf.kndkfnaoinefa'
      resp = create_channel_partner(@commercials_data)
      expect(resp[:code]).to eq(400), resp.to_s
      expect(resp[:body][:error][:message]).to eq('Please provide a valid email')
    end

    e.run_step 'Create a vendor' do
      @commercials_data['Email'] = actual_email
      resp = create_channel_partner(@commercials_data)
      expect(resp[:code]).to eq(200)
    end

    e.run_step 'Activate a Channel Partner' do
      resp = api_activate_channel_partner(@commercials_data['Email'])
      expect(resp[:code]).to eq(200), resp.to_s
    end

    e.run_step 'Verify Anchor can be selected in Vendor Onboarding Page' do
      @vendor = @commercials_data['Email'].split('@')[0]
      sleep 10
      set_cookies_api(@vendor, @commercials_data['Email'], $conf['users']['anchor']['password'])
      resp = get_invitation_details(@vendor, @commercials_data['Email'])
      invitation = resp[:body][:invitation_details].select { |detail| detail[:anchor_program][:anchor_name] == 'Myntra' }
      expect(invitation.empty?).to eq(false), "Invitation details is empty #{resp[:body]}"
    end

    e.run_step 'Verify Pre-filled company details' do
      resp = api_get_vendor_details(@vendor)
      expect(resp[:body][:pan]).to eq(@commercials_data['PAN'])
      expect(resp[:body][:vendor_detail][:gstn]).to eq(@commercials_data['GSTN'])
      expect(resp[:body][:vendor_detail][:name]).to eq(@commercials_data['Entity Name'])
      %i[city entity_type geography sector].each do |field|
        expect(resp[:body][:vendor_detail][field]).to eq(nil)
      end
      %i[relation_from msme uam sector].each do |field|
        expect(resp[:body][:anchor_program_vendor_detail][field]).to eq(nil)
      end
    end

    e.run_step 'Add Single Promoter and verify details' do
      resp = add_promoter_info(@vendor, @promoter_info)
      expect(resp[:code]).to eq(200), resp.to_s
      # Promoter 1 Validation
      resp = api_get_vendor_details(@vendor)
      promoter_info = resp[:body][:promoters].select { |promoter| promoter[:name] == @promoter_info['Full Name'] }
      expect(promoter_info[0][:contact]).to eq(@promoter_info['Phone Number'].to_s)
      expect(promoter_info[0][:shareholding_percentage].to_f).to eq(@promoter_info['Shareholding'].to_f)
    end
    e.run_step 'Add Multiple Promoters, Edit and Delete' do
      @promoter_info2 = {
        'Full Name' => "#{Faker::Name.first_name} #{Faker::Name.last_name}",
        'Phone Number' => Faker::Number.number(digits: 10),
        'Shareholding' => 10
      }
      promoter_info2 = @promoter_info.dup.merge!(@promoter_info2)
      resp = add_promoter_info(@vendor, promoter_info2)
      expect(resp[:code]).to eq(200)
      # Promoter 2 Validation
      promoter_info = resp[:body][:promoters].select { |promoter| promoter[:name] == promoter_info2['Full Name'] }
      expect(promoter_info[0][:contact]).to eq(promoter_info2['Phone Number'].to_s)
      expect(promoter_info[0][:shareholding_percentage].to_f).to eq(promoter_info2['Shareholding'].to_f)
      @promoter_id = promoter_info[0][:id]
    end

    e.run_step 'Update Promoter Information and verify details' do
      promoter_info2 = {
        'Full Name' => "#{Faker::Name.first_name} #{Faker::Name.last_name}",
        'Phone Number' => Faker::Number.number(digits: 10),
        'Shareholding' => 8
      }
      @promoter_info2 = @promoter_info.dup.merge!(promoter_info2)
      values = {
        actor: @vendor,
        name: @promoter_info2['Full Name'],
        contact: @promoter_info2['Phone Number'],
        shareholding_percentage: @promoter_info2['Shareholding'],
        salutation: @promoter_info2['Salutation'].downcase,
        pan: @promoter_info2['PAN'],
        email: @promoter_info2['Email Id'],
        address: @promoter_info2['Address'],
        state: @promoter_info2['State'],
        city: @promoter_info2['City'],
        zipcode: @promoter_info2['Zipcode'],
        address_type: @promoter_info2['Address Type'].downcase,
        gender: @promoter_info2['Gender'].downcase,
        dob: @promoter_info2['DOB'],
        marital_status: @promoter_info2['Marital Status'].downcase,
        promoter_id: @promoter_id
      }
      resp = update_promoter_information(values)
      expect(resp[:code]).to eq(200), resp.to_s
      # Updated Promoter 2 Validation
      resp = api_get_vendor_details(@vendor)
      promoter_info = resp[:body][:promoters].select { |promoter| promoter[:name] == @promoter_info2['Full Name'] }
      expect(promoter_info[0][:contact]).to eq(@promoter_info2['Phone Number'].to_s)
      expect(promoter_info[0][:shareholding_percentage].to_f).to eq(@promoter_info2['Shareholding'].to_f)
    end

    e.run_step 'Add Single KM Person and Verify details' do
      @km_values = { anchor_actor: 'anchor', actor: @vendor, program: @commercials_data['Program'], km_person_info: @km_person_info }
      resp = add_key_manager_info(@km_values)
      expect(resp[:code]).to eq(200), resp.to_s
      resp = api_get_vendor_details(@vendor)
      key_managing_person_info = resp[:body][:key_managing_persons_info].select { |key_managing_person| key_managing_person[:name] == @km_person_info['Full Name'] }
      expect(key_managing_person_info[0][:email]).to eq(@km_person_info['Email Id'])
      expect(key_managing_person_info[0][:contact]).to eq(@km_person_info['Phone Number'])
      expect(key_managing_person_info[0][:designation]).to eq(@km_person_info['Designation'])
    end

    e.run_step 'Add another KM Person and verify details' do
      km_person_info2 = {
        'Full Name' => "#{Faker::Name.first_name} #{Faker::Name.last_name}",
        'Phone Number' => Faker::Number.number(digits: 10),
        'Designation' => Faker::Company.profession,
        'Email Id' => "#{Faker::Internet.user_name(specifier: 5..5)}@yopmail.com"
      }
      km_person_info2['Full Name'] = km_person_info2['Full Name'].delete("'")
      @km_values.merge!(km_person_info: [@km_person_info, km_person_info2])
      resp = add_key_manager_info(@km_values)
      expect(resp[:code]).to eq(200), resp.to_s

      resp = api_get_vendor_details(@vendor)
      key_managing_person_info = resp[:body][:key_managing_persons_info].select { |key_managing_person| key_managing_person[:name] == km_person_info2['Full Name'] }
      expect(key_managing_person_info[0][:email]).to eq(km_person_info2['Email Id'])
      expect(key_managing_person_info[0][:contact].to_i).to eq(km_person_info2['Phone Number'].to_i)
      expect(key_managing_person_info[0][:designation]).to eq(km_person_info2['Designation'])
    end

    e.run_step 'Update KM Person details and verify details' do
      updated_km_person_info2 = {
        'Full Name' => "#{Faker::Name.first_name} #{Faker::Name.last_name}",
        'Phone Number' => Faker::Number.number(digits: 10),
        'Designation' => Faker::Company.profession,
        'Email Id' => "#{Faker::Internet.user_name(specifier: 5..5)}@yopmail.com"
      }
      updated_km_person_info2['Full Name'] = updated_km_person_info2['Full Name'].delete("'")
      @km_values.merge!(km_person_info: [@km_person_info, updated_km_person_info2])
      resp = add_key_manager_info(@km_values)
      expect(resp[:code]).to eq(200), resp.to_s

      resp = api_get_vendor_details(@vendor)
      key_managing_person_info = resp[:body][:key_managing_persons_info].select { |key_managing_person| key_managing_person[:name] == updated_km_person_info2['Full Name'] }
      expect(key_managing_person_info[0][:email]).to eq(updated_km_person_info2['Email Id'])
      expect(key_managing_person_info[0][:contact].to_i).to eq(updated_km_person_info2['Phone Number'].to_i)
      expect(key_managing_person_info[0][:designation]).to eq(updated_km_person_info2['Designation'])
    end

    e.run_step 'Upload onboarding documents' do
      values = { actor: @vendor, type: 'mandatory_docs', sub_type: nil }
      resp = upload_onbaording_documents(values)
      expect(resp).to eq(true)
    end

    e.run_step 'Remove uploaded documents' do
      expect(review_all_docs({ actor: @vendor, doc_type: 'mandatory_docs' }, action: :remove)).to eq(true)
    end
  end

  it 'Commercials : Reject Documents, Reject Vendor by Platform', :document_reject do |e|
    @testdata = JSON.parse(ERB.new(@erb_file).result(binding))
    @testdata['Commercials']['GSTN'] = "#{Faker::Number.number(digits: 2)}#{@testdata['Commercials']['PAN']}#{Faker::Number.number(digits: 1)}Z#{Faker::Internet.user_name(specifier: 1..1).upcase}"
    @commercials_data = @testdata['Commercials']
    @company_kyc_docs = @testdata['Documents']['Company KYC Documents']
    @created_vendors << @commercials_data['Entity Name']
    @sub_type = ['entity_pan', 'gst_certificate', 'promoter_pan', 'promoter_aadhar'].sample

    e.run_step 'Create a registered vendor' do
      expect(api_create_registered_channel_partner(@testdata)).to eq true
    end

    e.run_step 'Reject Vendor documents as Plaform - Company KYC documents' do
      @vendor = @commercials_data['Email'].split('@')[0]
      sleep 5
      set_cookies_api(@vendor, @commercials_data['Email'], $conf['users']['anchor']['password'])
      values = { actor: @vendor, doc_type: 'mandatory_docs', doc_sub_type: @sub_type, reject_reason: @testdata['Reject Reason'] }
      expect(review_all_docs(values, action: :reject)).to eq(true)
    end

    e.run_step 'Verify mail received for rejected document' do
      sleep MAX_LOADER_TIME
      doc = get_required_docs('mandatory_docs', @sub_type)
      doc_title = doc['mandatory_docs'][@sub_type]
      email_values = { mail_box: $conf['notification_mailbox'], subject: 'Rejected Document Notification', body: [@commercials_data['Entity Name'], doc_title] }
      email = $mail_helper.fetch_mail(email_values)
      expect(email).to include('https://tf-stg.credavenue.in/profile/documents')
    end

    e.run_step 'Re-Upload Company KYC docs' do
      values = { actor: @vendor, type: 'mandatory_docs', sub_type: @sub_type }
      expect(upload_onbaording_documents(values)).to eq(true)
    end

    e.run_step 'Verify Company KYC docs for broken links' do
      expect(review_all_docs({ actor: @vendor, doc_type: 'mandatory_docs', sub_type: @sub_type }, action: :verify)).to eq(true)
    end

    e.run_step 'Verify Channel Partner registeration can be submitted again' do
      resp = submit_for_review(@vendor)
      expect(resp[:code]).to eq(200), resp.to_s
    end

    e.run_step 'Verify all documents by platforms team' do
      expect(review_all_docs({ actor: @vendor, doc_type: 'mandatory_docs' }, action: :approve)).to eq(true)
    end

    e.run_step 'Reject vendor by PLATFORMS' do
      resp = review_vendor(@vendor, 'rejected', @testdata['Reject Reason'])
      expect(resp[:code]).to eq(200), resp.to_s
    end

    e.run_step 'Verify status as ANCHOR' do
      @vendor_response = fetch_list_all_vendors('Vendor', @anchor_actor, @commercials_data['Entity Name'])
      expect(@vendor_response[0][:state]).to eq('rejected')
    end
  end
end
