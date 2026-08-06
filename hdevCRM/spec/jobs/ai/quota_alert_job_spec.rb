require 'rails_helper'

RSpec.describe Ai::QuotaAlertJob do
  it 'runs the threshold check for the account' do
    account = create(:account)
    service = instance_double(Ai::QuotaService, check_thresholds!: nil)
    allow(Ai::QuotaService).to receive(:new).with(account: account).and_return(service)

    described_class.perform_now(account.id)

    expect(service).to have_received(:check_thresholds!)
  end

  it 'does nothing when the account no longer exists' do
    expect { described_class.perform_now(0) }.not_to raise_error
  end
end
