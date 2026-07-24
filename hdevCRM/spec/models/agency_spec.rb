require 'rails_helper'

RSpec.describe Agency do
  context 'with validations' do
    it { is_expected.to validate_presence_of(:name) }
  end

  describe 'associations' do
    it { is_expected.to have_many(:accounts) }
  end

  describe 'slug generation' do
    it 'generates a slug from the name when blank' do
      agency = create(:agency, name: 'Minha Agência Digital', slug: nil)
      expect(agency.slug).to eq('minha-agencia-digital')
    end

    it 'keeps an explicit slug' do
      agency = create(:agency, name: 'Minha Agência', slug: 'custom-slug')
      expect(agency.slug).to eq('custom-slug')
    end
  end

  describe 'custom_domain' do
    it 'normalizes the domain to lowercase' do
      agency = create(:agency, custom_domain: 'Painel.Agencia.COM')
      expect(agency.custom_domain).to eq('painel.agencia.com')
    end

    it 'enforces uniqueness' do
      create(:agency, custom_domain: 'painel.agencia.com')
      duplicate = build(:agency, custom_domain: 'painel.agencia.com')
      expect(duplicate).not_to be_valid
    end

    it 'allows multiple agencies without a domain' do
      create(:agency, custom_domain: nil)
      expect(build(:agency, custom_domain: nil)).to be_valid
    end
  end

  describe 'primary_color' do
    it 'accepts valid hex colors' do
      expect(build(:agency, primary_color: '#ff5500')).to be_valid
      expect(build(:agency, primary_color: '#f50')).to be_valid
    end

    it 'rejects invalid colors' do
      expect(build(:agency, primary_color: 'red')).not_to be_valid
      expect(build(:agency, primary_color: '#zzzzzz')).not_to be_valid
    end
  end

  describe '.resolve_by_host' do
    let!(:agency) { create(:agency, custom_domain: 'painel.agencia.com') }

    it 'finds an active agency by domain' do
      expect(described_class.resolve_by_host('painel.agencia.com')).to eq(agency)
    end

    it 'returns nil for unknown hosts' do
      expect(described_class.resolve_by_host('outro.dominio.com')).to be_nil
    end

    it 'returns nil for blank hosts' do
      expect(described_class.resolve_by_host(nil)).to be_nil
      expect(described_class.resolve_by_host('')).to be_nil
    end

    it 'ignores suspended agencies' do
      agency.update!(status: 'suspended')
      expect(described_class.resolve_by_host('painel.agencia.com')).to be_nil
    end
  end

  describe '#global_config_overrides' do
    it 'falls back to the agency name for installation and brand names' do
      agency = create(:agency, name: 'Agência X')
      overrides = agency.global_config_overrides
      expect(overrides['INSTALLATION_NAME']).to eq('Agência X')
      expect(overrides['BRAND_NAME']).to eq('Agência X')
    end

    it 'omits unset keys so platform defaults apply' do
      agency = create(:agency)
      overrides = agency.global_config_overrides
      expect(overrides).not_to have_key('LOGO')
      expect(overrides).not_to have_key('TERMS_URL')
      expect(overrides).not_to have_key('BRAND_URL')
    end

    it 'uses configured values when present' do
      agency = create(:agency,
                      installation_name: 'Painel Pro',
                      brand_name: 'Pro Brand',
                      brand_url: 'https://agencia.com',
                      terms_url: 'https://agencia.com/termos')
      overrides = agency.global_config_overrides
      expect(overrides['INSTALLATION_NAME']).to eq('Painel Pro')
      expect(overrides['BRAND_NAME']).to eq('Pro Brand')
      expect(overrides['BRAND_URL']).to eq('https://agencia.com')
      expect(overrides['WIDGET_BRAND_URL']).to eq('https://agencia.com')
      expect(overrides['TERMS_URL']).to eq('https://agencia.com/termos')
    end
  end

  describe '#brand_rgb' do
    it 'converts the hex color to a space separated RGB triplet' do
      agency = build(:agency, primary_color: '#2781F6')
      expect(agency.brand_rgb).to eq('39 129 246')
    end

    it 'expands shorthand hex colors' do
      agency = build(:agency, primary_color: '#f50')
      expect(agency.brand_rgb).to eq('255 85 0')
    end

    it 'darkens the color by the given percentage' do
      agency = build(:agency, primary_color: '#ffffff')
      expect(agency.brand_rgb(10)).to eq('230 230 230')
    end

    it 'uses the default color when none is set' do
      agency = build(:agency, primary_color: nil)
      expect(agency.brand_rgb).to eq('31 147 255')
    end
  end

  describe '#primary_color_or_default' do
    it 'returns the default when unset' do
      expect(build(:agency).primary_color_or_default).to eq(described_class::DEFAULT_COLOR)
    end
  end
end
