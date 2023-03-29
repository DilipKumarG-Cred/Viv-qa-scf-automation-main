require './spec_helper'
describe 'Reports : Report Access to Product User', :scf, :reports, :report_access, :mails do
  before(:all) do
    @anchor_actor = 'grn_anchor'
    @vendor_actor = 'tranclub_vendor'
    @party_gstn = $conf['users'][@anchor_actor]['gstn']
    @counterparty_gstn = $conf['users'][@vendor_actor]['gstn']
    @vendor_name = $conf['users'][@vendor_actor]['name']
    @oneplus_anchor_id = '308'
  end

  it 'Reports: Report Access to Product User - Verification of Data population' do |e|
    e.run_step 'Verify report types are properly populated for Anchor' do
      expected_report_types = ['statement_of_accounts', 'tranche_overdue', 'utilization_report']
      report_types = fetch_report_types('anchor')
      expect(report_types).to eq(expected_report_types)
    end

    e.run_step 'Verify report types are properly populated for Vendor' do
      expected_report_types = ['statement_of_accounts', 'tranche_overdue']
      report_types = fetch_report_types('vendor')
      expect(report_types).to eq(expected_report_types)
    end

    e.run_step 'Verify known Anchors are populated as well on selecting anchor' do
      anchors = ['Snapdeal', 'Myntra', 'Tvs']
      values = { actors: anchors, type_of_actor: 'anchors' }
      expect(validate_associated_actors_present(values)).to eq(true)
    end

    e.run_step 'Verify known Vendors are populated as well on selecting Vendor/Dealer' do
      vendors = ['99 Stores', 'Exide', 'Soa Dealer']
      values = { actors: vendors, type_of_actor: 'vendors' }
      expect(validate_associated_actors_present(values)).to eq(true)
    end

    e.run_step 'Verify programs are populated for corresponding anchor' do
      exp_programs = ['Invoice Financing-Vendor', 'Invoice Financing-Dealer']
      resp = fetch_anchor_programs('product', anchor_id: @oneplus_anchor_id)
      programs = []
      resp[:body].select { |program| programs << "#{program[:program_group]}-#{program[:program_type]}" if program[:anchor_program_id].nil? == false }
      expect(programs).to eq(exp_programs)
    end

    e.run_step 'Verify programs are populated for corresponding vendor' do
      exp_programs = ['Invoice Financing-Vendor']
      resp = fetch_anchor_programs('product', vendor_id: $conf['users']['assignment_vendor']['id'])
      programs = []
      resp[:body].select { |program| programs << "#{program[:program_group]}-#{program[:program_type]}" }
      expect(programs).to eq(exp_programs)
    end

    e.run_step 'Verify known vendors are populated as well for corresponding anchor' do
      vendors = ['West Store As', 'Trends', 'Campus Sutra']
      values = { actors: vendors, type_of_actor: 'vendors', program_id: 1, anchor_id: $conf['users']['anchor_summary_anchor']['id'] }
      expect(validate_associated_actors_present(values)).to eq(true)
    end

    e.run_step 'Verify known anchors are populated as well for corresponding Vendor/Dealer' do
      anchors = ['Myntra']
      values = { actors: anchors, type_of_actor: 'anchors', program_id: 2, vendor_id: $conf['users']['soa_dealer']['id'] }
      expect(validate_associated_actors_present(values)).to eq(true)
    end

    e.run_step 'Verify known investors are populated as well for corresponding anchor, vendor' do
      investors = ['Kotak', 'PNB']
      values = { actors: investors, type_of_actor: 'investors', program_id: 1, anchor_id: $conf['users']['anchor_summary_anchor']['id'], vendor_id: $conf['users']['anchor_summary_vendor']['id'] }
      expect(validate_associated_actors_present(values)).to eq(true)
    end
  end
end
