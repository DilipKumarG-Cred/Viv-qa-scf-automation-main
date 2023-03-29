require './spec_helper'
describe 'Anchor Commercials:', :scf, :commercials, :anchor_commercials do
  before(:all) do
    @mou = "#{Dir.pwd}/test-data/attachments/borrowing_document.pdf"
    @reupload_mou = "#{Dir.pwd}/test-data/attachments/reinitiate_invoice.pdf"
    @anchor_actor = 'commercials_anchor'
    @anchor_name = $conf['users'][@anchor_actor]['name']
    @anchor_id = $conf['users'][@anchor_actor]['id']
    @investor_actor = 'investor'
    @investor_id = $conf['users'][@investor_actor]['id']
    @commercials_data_erb = File.read("#{Dir.pwd}/test-data/erb/commercials_data.erb")
    @set_commercial_values = JSON.parse(ERB.new(@commercials_data_erb).result(binding))['Anchor Commercials'].transform_keys(&:to_sym)
    @set_commercial_values[:investor_id] = @investor_id
    @set_commercial_values[:actor] = @investor_actor
  end

  before(:each) do
    values = {
      investor_actor: 'investor',
      investor_id: @investor_id,
      anchor_id: @anchor_id,
      program_id: $conf['programs']['Invoice Financing - Vendor']
    }
    expect(force_delete_anchor_commercials(values)).to eq 200
  end

  it 'Anchor Commercials: Setup Commercials' do |e|
    e.run_step 'Verify commercials can be set' do
      @anchor_program_id = get_anchor_program_id('Invoice Financing', 'Vendor', @anchor_id)
      @set_commercial_values[:anchor_program_id] = @anchor_program_id
      @set_commercial_values[:valid_till] = get_todays_date(300, '%Y-%m-%d')
      resp = set_anchor_commercials(@set_commercial_values)
      expect(resp[:code]).to eq(200), resp.to_s
      expect(resp[:body][:result][:status]).to eq('pending_document')
    end

    e.run_step 'Verify anchor commercial data after settig up' do
      resp = get_anchor_commercials(investor_actor: @investor_actor, investor_id: @investor_id, anchor_program_id: @anchor_program_id)
      commercial = resp[:body][:result]
      expect(commercial[:max_tenor]).to eq(@set_commercial_values[:max_tenor].to_i)
      expect(commercial[:recourse_percentage]).to eq(@set_commercial_values[:recourse_percentage].to_i)
    end

    e.run_step 'Verify Investor can edit Commercials before Uploading MOU' do
      @set_commercial_values[:recourse_percentage] = 90
      @set_commercial_values[:max_tenor] = 30
      resp = set_anchor_commercials(@set_commercial_values, action: :edit)
      expect(resp[:code]).to eq(200)
      expect(resp[:body][:result][:status]).to eq('pending_document')
    end

    e.run_step 'Verify anchor commercial data after editing' do
      resp = get_anchor_commercials(investor_actor: @investor_actor, investor_id: @investor_id, anchor_program_id: @anchor_program_id)
      commercial = resp[:body][:result]
      @commercial_id = commercial[:id]
      expect(commercial[:max_tenor]).to eq(@set_commercial_values[:max_tenor].to_i)
      expect(commercial[:recourse_percentage]).to eq(@set_commercial_values[:recourse_percentage].to_i)
    end

    e.run_step 'Verify Investor can Upload MOU' do
      values = { actor: @investor_actor, borr_doc: @mou, id: @commercial_id }
      resp = upload_anchor_mou(values)
      expect(resp[:code]).to eq(200), resp.to_s
      expect(resp[:body][:result][:status]).to eq('pending_document')
    end

    e.run_step 'Verify Investor can submit commercials' do
      resp = set_anchor_commercials(@set_commercial_values, action: :submit)
      expect(resp[:code]).to eq(200)
      expect(resp[:body][:result][:status]).to eq('pending_effective_date')
      sleep 5
      resp = get_anchor_commercials(investor_actor: @investor_actor, investor_id: @investor_id, anchor_program_id: @anchor_program_id)
      expect(resp[:body][:result][:status]).to eq('approved')
    end

    e.run_step 'Verify anchor commercial data as PRODUCT' do
      resp = get_anchor_commercials(investor_actor: 'product', investor_id: @investor_id, anchor_program_id: @anchor_program_id)
      commercial = resp[:body][:result]
      @commercial_id = commercial[:id]
      expect(commercial[:max_tenor]).to eq(@set_commercial_values[:max_tenor].to_i)
      expect(commercial[:recourse_percentage]).to eq(@set_commercial_values[:recourse_percentage].to_i)
    end

    e.run_step 'Remove anchor commercials' do
      values = {
        investor_actor: @investor_actor,
        investor_id: @investor_id,
        anchor_id: @anchor_id,
        program_id: $conf['programs']['Invoice Financing - Vendor']
      }
      expect(force_delete_anchor_commercials(values)).to eq 200
    end
  end
end
