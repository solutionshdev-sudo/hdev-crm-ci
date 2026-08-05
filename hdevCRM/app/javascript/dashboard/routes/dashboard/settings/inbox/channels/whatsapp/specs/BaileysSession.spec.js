import { flushPromises, mount } from '@vue/test-utils';
import BaileysAPI from 'dashboard/api/inbox/baileys';
import BaileysSession from '../BaileysSession.vue';

vi.mock('dashboard/api/inbox/baileys', () => ({
  default: {
    getStatus: vi.fn(),
    connect: vi.fn(),
    logout: vi.fn(),
  },
}));

vi.mock('qrcode', () => ({
  default: {
    toDataURL: vi.fn(() => Promise.resolve('data:image/png;base64,x')),
  },
}));

vi.mock('dashboard/composables', () => ({
  useAlert: vi.fn(),
}));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

const mountSession = () =>
  mount(BaileysSession, {
    props: { inboxId: 1 },
    global: {
      stubs: { NextButton: true, Dialog: true },
      mocks: { $t: key => key },
    },
  });

describe('BaileysSession', () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
    vi.clearAllMocks();
  });

  // Regressão: emitir na primeira leitura fecha um ciclo infinito com o pai
  // (dispatch inboxes/get -> spinner na raiz -> desmonta -> remonta -> repete).
  it('does not emit connected when the session is already connected on mount', async () => {
    BaileysAPI.getStatus.mockResolvedValue({ data: { status: 'connected' } });

    const wrapper = mountSession();
    await flushPromises();

    expect(wrapper.emitted('connected')).toBeUndefined();
    wrapper.unmount();
  });

  it('emits connected when the session opens while mounted', async () => {
    BaileysAPI.getStatus
      .mockResolvedValueOnce({ data: { status: 'qr', qr: 'ref' } })
      .mockResolvedValue({ data: { status: 'connected' } });

    const wrapper = mountSession();
    await flushPromises();
    expect(wrapper.emitted('connected')).toBeUndefined();

    await vi.advanceTimersByTimeAsync(3000);
    await flushPromises();

    expect(wrapper.emitted('connected')).toHaveLength(1);
    wrapper.unmount();
  });
});
