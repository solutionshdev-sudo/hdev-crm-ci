import { flushPromises, mount } from '@vue/test-utils';
import { useAlert } from 'dashboard/composables';
import LeadCaptureSection from '../LeadCaptureSection.vue';

vi.mock('dashboard/composables', () => ({
  useAlert: vi.fn(),
}));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params) => (params ? `${key}::${JSON.stringify(params)}` : key),
  }),
}));

const IDENTIFIER = 'inbox-xyz-123';
const EXPECTED_URL = `${window.location.origin}/public/api/v1/inboxes/${IDENTIFIER}/leads`;

const mountSection = () =>
  mount(LeadCaptureSection, {
    props: { identifier: IDENTIFIER },
    global: {
      stubs: {
        SettingsFieldSection: {
          props: ['label', 'helpText'],
          template: '<div><slot /></div>',
        },
        'woot-code': {
          props: ['script', 'lang'],
          template: '<pre>{{ script }}</pre>',
        },
      },
    },
  });

describe('LeadCaptureSection', () => {
  beforeEach(() => {
    global.fetch = vi.fn();
  });

  afterEach(() => {
    vi.clearAllMocks();
  });

  it('renders the ready-to-use endpoint URL with the inbox identifier', () => {
    const wrapper = mountSection();

    expect(wrapper.text()).toContain(EXPECTED_URL);
  });

  it('includes the real URL inside the pasteable form snippet', () => {
    const wrapper = mountSection();

    expect(wrapper.text()).toContain(`action="${EXPECTED_URL}"`);
    expect(wrapper.text()).toContain('name="nome"');
    expect(wrapper.text()).toContain('name="mensagem"');
  });

  it('sends a test lead with the expected payload and shows a success alert', async () => {
    global.fetch.mockResolvedValue({
      ok: true,
      json: () =>
        Promise.resolve({
          contact_id: 42,
          conversation_id: 7,
          source_id: 's1',
        }),
    });

    const wrapper = mountSection();
    await wrapper
      .get('[data-test="lead-capture-test-button"]')
      .trigger('click');
    await flushPromises();

    expect(global.fetch).toHaveBeenCalledTimes(1);
    const [url, options] = global.fetch.mock.calls[0];
    expect(url).toBe(EXPECTED_URL);
    expect(options.method).toBe('POST');
    expect(options.credentials).toBe('omit');
    expect(options.headers['Content-Type']).toBe('application/json');

    const body = JSON.parse(options.body);
    expect(body.nome).toBe('Lead de teste');
    expect(body.mensagem).toBe(
      'Lead de teste enviado pela tela de configurações.'
    );
    expect(body.external_id).toMatch(/^test-\d+$/);

    expect(useAlert).toHaveBeenCalledWith(
      `INBOX_MGMT.LEAD_CAPTURE.TEST_SUCCESS::${JSON.stringify({
        contactId: 42,
        conversationId: 7,
      })}`
    );
  });

  it('shows an error alert when the request fails', async () => {
    global.fetch.mockRejectedValue(new Error('network down'));

    const wrapper = mountSection();
    await wrapper
      .get('[data-test="lead-capture-test-button"]')
      .trigger('click');
    await flushPromises();

    expect(useAlert).toHaveBeenCalledWith('INBOX_MGMT.LEAD_CAPTURE.TEST_ERROR');
  });

  // Mock com `.json()` funcional de propósito: sem o guard `if (!response.ok)`
  // o código seguiria até `useAlert` de sucesso normalmente (o response.json()
  // resolveria igual), então só o guard é que faz esse teste discriminar --
  // um mock sem `.json` faria o mesmo teste passar mesmo com o guard removido
  // (o `await response.json()` estouraria e caberia no mesmo catch).
  it('shows an error alert when the endpoint responds with a non-ok status', async () => {
    global.fetch.mockResolvedValue({
      ok: false,
      status: 422,
      json: () => Promise.resolve({ contact_id: 1, conversation_id: 1 }),
    });

    const wrapper = mountSection();
    await wrapper
      .get('[data-test="lead-capture-test-button"]')
      .trigger('click');
    await flushPromises();

    expect(useAlert).toHaveBeenCalledWith('INBOX_MGMT.LEAD_CAPTURE.TEST_ERROR');
  });
});
