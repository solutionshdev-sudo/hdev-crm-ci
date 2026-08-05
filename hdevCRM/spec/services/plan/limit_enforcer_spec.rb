require 'rails_helper'

RSpec.describe Plan::LimitEnforcer do
  describe 'inicialização' do
    it 'exige exatamente um dono (account: ou agency:)' do
      expect { described_class.new }.to raise_error(ArgumentError)
      expect { described_class.new(account: build(:account), agency: build(:agency)) }.to raise_error(ArgumentError)
    end
  end

  describe 'cadeia de resolução (modo conta)' do
    let(:account) { create(:account) }
    let(:enforcer) { described_class.new(account: account) }

    it 'é ilimitado sem plano em lugar nenhum e nunca bloqueia' do
      expect(enforcer.limit_for(:inbox)).to be_nil
      expect(enforcer.remaining(:inbox)).to be_nil
      expect(enforcer.allow?(:inbox)).to be(true)
      expect(enforcer.allow!(:inbox)).to be(true)
    end

    it 'usa o plano da assinatura direta vigente' do
      plan = create(:plan, max_inboxes: 3)
      create(:subscription, owner: account, plan: plan, status: 'active')

      expect(enforcer.limit_for(:inbox)).to eq(3)
    end

    it 'mantém o plano válido em past_due (dunning do Stripe ainda cobra)' do
      plan = create(:plan, max_inboxes: 3)
      create(:subscription, owner: account, plan: plan, status: 'past_due')

      expect(enforcer.limit_for(:inbox)).to eq(3)
    end

    it 'ignora assinatura que não concede plano (pending/canceled)' do
      plan = create(:plan, max_inboxes: 1)
      create(:subscription, owner: account, plan: plan, status: 'pending')

      expect(enforcer.limit_for(:inbox)).to be_nil
    end

    context 'com agência' do
      let(:agency) { create(:agency) }
      let(:account) { create(:account, agency: agency) }

      it 'herda o plano da agência quando a conta não tem assinatura própria' do
        agency_plan = create(:plan, :agency, max_inboxes: 2)
        create(:subscription, owner: agency, plan: agency_plan, status: 'active')

        expect(enforcer.limit_for(:inbox)).to eq(2)
      end

      it 'a assinatura direta vigente decide sozinha: coluna nula é ilimitado, sem cair pro plano da agência' do
        direct_plan = create(:plan, max_inboxes: nil)
        create(:subscription, owner: account, plan: direct_plan, status: 'active')
        agency_plan = create(:plan, :agency, max_inboxes: 1)
        create(:subscription, owner: agency, plan: agency_plan, status: 'active')

        expect(enforcer.limit_for(:inbox)).to be_nil
      end

      it 'alocação da agência vence o plano' do
        agency_plan = create(:plan, :agency, max_inboxes: 10)
        create(:subscription, owner: agency, plan: agency_plan, status: 'active')
        account.update!(plan_allocations: { 'max_inboxes' => 1 })

        expect(enforcer.limit_for(:inbox)).to eq(1)
      end

      it 'alocação com null é ilimitado explícito' do
        agency_plan = create(:plan, :agency, max_inboxes: 1)
        create(:subscription, owner: agency, plan: agency_plan, status: 'active')
        account.update!(plan_allocations: { 'max_inboxes' => nil })

        expect(enforcer.limit_for(:inbox)).to be_nil
      end

      it 'resolve por chave: alocação parcial deixa as demais chaves no plano' do
        agency_plan = create(:plan, :agency, max_inboxes: 7, max_agents: 9)
        create(:subscription, owner: agency, plan: agency_plan, status: 'active')
        account.update!(plan_allocations: { 'max_agents' => 2 })

        expect(enforcer.limit_for(:agent)).to eq(2)
        expect(enforcer.limit_for(:inbox)).to eq(7)
      end
    end
  end

  describe 'limites por tipo de canal' do
    let(:account) { create(:account) }
    let(:enforcer) { described_class.new(account: account) }

    it 'é ilimitado quando o plano não define a chave do canal' do
      plan = create(:plan, channel_limits: {})
      create(:subscription, owner: account, plan: plan, status: 'active')

      expect(enforcer.channel_limit_for('Channel::Whatsapp')).to be_nil
      expect(enforcer.allow?(:inbox, channel_type: 'Channel::Whatsapp')).to be(true)
    end

    it 'aplica o teto do plano pro tipo de canal' do
      plan = create(:plan, channel_limits: { 'Channel::Whatsapp' => 1 })
      create(:subscription, owner: account, plan: plan, status: 'active')
      # o factory de channel_whatsapp já cria a inbox no after(:create)
      create(:channel_whatsapp, account: account, provider: 'baileys', validate_provider_config: false, sync_templates: false)

      expect(enforcer.allow?(:inbox, channel_type: 'Channel::Whatsapp')).to be(false)
      expect(enforcer.allow?(:inbox, channel_type: 'Channel::WebWidget')).to be(true)
      expect { enforcer.allow!(:inbox, channel_type: 'Channel::Whatsapp') }
        .to raise_error(Plan::LimitExceededError, I18n.t('errors.plan_limits.channel'))
    end

    it 'alocação de channel_limits vence a do plano' do
      plan = create(:plan, channel_limits: { 'Channel::Whatsapp' => 5 })
      create(:subscription, owner: account, plan: plan, status: 'active')
      account.update!(plan_allocations: { 'channel_limits' => { 'Channel::Whatsapp' => 0 } })

      expect(enforcer.channel_limit_for('Channel::Whatsapp')).to eq(0)
      expect(enforcer.allow?(:inbox, channel_type: 'Channel::Whatsapp')).to be(false)
    end
  end

  describe 'contagem de uso e borda' do
    let(:account) { create(:account) }
    let(:enforcer) { described_class.new(account: account) }

    it 'aceita até o teto e recusa a criação que excede' do
      plan = create(:plan, max_inboxes: 1)
      create(:subscription, owner: account, plan: plan, status: 'active')

      expect(enforcer.allow!(:inbox)).to be(true)
      create(:inbox, account: account)

      expect(described_class.new(account: account).allow?(:inbox)).to be(false)
      expect { described_class.new(account: account).allow!(:inbox) }.to raise_error(Plan::LimitExceededError) do |error|
        expect(error.http_status).to eq(:payment_required)
        expect(error.to_hash).to eq(error: I18n.t('errors.plan_limits.inbox'))
      end
    end

    it 'conta só canais whatsapp provider baileys em :baileys_instance' do
      plan = create(:plan, max_baileys_instances: 1)
      create(:subscription, owner: account, plan: plan, status: 'active')
      create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', validate_provider_config: false, sync_templates: false)

      expect(enforcer.allow?(:baileys_instance)).to be(true)

      create(:channel_whatsapp, account: account, provider: 'baileys', validate_provider_config: false, sync_templates: false)

      expect(described_class.new(account: account).allow?(:baileys_instance)).to be(false)
    end

    it 'expõe remaining com piso em zero' do
      plan = create(:plan, max_inboxes: 1)
      create(:subscription, owner: account, plan: plan, status: 'active')
      create_list(:inbox, 2, account: account)

      expect(enforcer.remaining(:inbox)).to eq(0)
    end
  end

  describe 'modo agência (:client_account)' do
    let(:agency) { create(:agency) }
    let(:enforcer) { described_class.new(agency: agency) }

    it 'é ilimitado sem assinatura vigente' do
      expect(enforcer.limit_for(:client_account)).to be_nil
      expect(enforcer.allow!(:client_account)).to be(true)
    end

    it 'recusa na borda do max_client_accounts' do
      plan = create(:plan, :agency, max_client_accounts: 1)
      create(:subscription, owner: agency, plan: plan, status: 'active')
      create(:account, agency: agency)

      expect { enforcer.allow!(:client_account) }
        .to raise_error(Plan::LimitExceededError, I18n.t('errors.plan_limits.client_account'))
    end
  end
end
