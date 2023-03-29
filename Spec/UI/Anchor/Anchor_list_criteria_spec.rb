require './spec_helper'
describe 'Anchor list criteria', :scf, :anchor, :anchor_list_criteria do
  before(:all) do
    @anchor = $conf['users']['anchor_critieria_test']
    @program_type = 'Invoice Financing - Dealer'
    delete_live_program('Invoice Financing', 'Dealer', @anchor['id'])
    delete_draft_program('Invoice Financing - Dealer', 'anchor_critieria_test')
  end

  it 'Verification of Anchor list criteria for Investors' do |e|
    e.run_step 'Verify anchor list are displayed WITH criteria for Kotak' do
      actor = 'investor'
      anchors_list = retrieve_anchors_without_published_programs(actor)
      expect(anchors_list).to eq([]), "List of anchors without anchor list criteria #{anchors_list}"
    end
    e.run_step 'Verify anchor list are displayed WITH criteria for DCB' do
      actor = 'user_feedback_investor'
      anchors_list = retrieve_anchors_without_published_programs(actor)
      expect(anchors_list).to eq([]), "List of anchors without anchor list criteria #{anchors_list}"
    end
  end

  it 'Verification of Anchor list criteria for an anchor' do |e|
    e.run_step 'Verify anchor list does not show anchor who did not publish a program' do
      actor = 'user_feedback_investor'
      expect(verify_whether_anchor_present_in_anchor_list(actor, @anchor['name'])).to eq(false), 'Anchor is present'
    end

    e.run_step 'Publish a program for Anchor' do
      @create_values = {
        max_tranche: 60,
        program_size: 600_000_000,
        exposure: [0, 600_000_000],
        price_expectation: [0, 11],
        type: @program_type,
        actor: 'anchor_critieria_test'
      }
      draft_program = create_anchor_program(@create_values)
      expect(draft_program[:code]).to eq(200)
      expect(draft_program[:body][:anchor_programs][0][:status]).to eq('draft')
      @program_id = draft_program[:body][:anchor_programs][0][:id]
      resp = publish_anchor_program('commercials_anchor', @program_id)
      expect(resp[:body][:available_programs][:published_programs][0][:id]).to eq(@program_id)
    end

    e.run_step 'Verify anchor list shows anchor who published a program' do
      actor = 'user_feedback_investor'
      expect(verify_whether_anchor_present_in_anchor_list(actor, @anchor['name'])).to eq(true), 'Anchor is not present'
    end
  end
end
