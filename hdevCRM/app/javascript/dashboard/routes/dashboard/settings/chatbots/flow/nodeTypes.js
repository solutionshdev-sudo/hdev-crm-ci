// Registro type -> aparência, handles de saída e data default. Um único
// componente FlowNode.vue renderiza todos os tipos a partir desta config.
// (Os handles dinâmicos do `question` — um por opção — são calculados no
// componente, a partir de node.data.options.)
export const NODE_TYPES = {
  start: {
    icon: 'i-lucide-play',
    color: '#00875A',
    handles: ['out'],
    data: () => ({}),
  },
  message: {
    icon: 'i-lucide-message-square-text',
    color: '#0EA5E9',
    handles: ['out'],
    data: () => ({ content: '' }),
  },
  question: {
    icon: 'i-lucide-list-checks',
    color: '#8B5CF6',
    handles: [], // dinâmicos: options[].id + fallback + timeout
    data: () => ({
      content: '',
      input_type: 'buttons',
      options: [
        { id: 'opt_1', title: 'Opção 1' },
        { id: 'opt_2', title: 'Opção 2' },
      ],
      save_as: '',
      invalid_message: '',
      max_retries: 2,
    }),
  },
  condition: {
    icon: 'i-lucide-git-branch',
    color: '#F59E0B',
    handles: ['true', 'false'],
    data: () => ({
      mode: 'all',
      rules: [{ left: '{{vars.resposta}}', operator: 'equals', right: '' }],
    }),
  },
  collect: {
    icon: 'i-lucide-clipboard-pen',
    color: '#14B8A6',
    handles: ['out', 'fallback'],
    data: () => ({
      content: '',
      validation: 'none',
      save_as: '',
      map_to: '',
      invalid_message: '',
      max_retries: 2,
    }),
  },
  delay: {
    icon: 'i-lucide-clock',
    color: '#64748B',
    handles: ['out'],
    data: () => ({ seconds: 60 }),
  },
  handoff: {
    icon: 'i-lucide-user-round',
    color: '#E5484D',
    handles: [],
    data: () => ({ message: '', note: '', assign_to: 'none', team_id: null, agent_id: null }),
  },
  tag: {
    icon: 'i-lucide-tags',
    color: '#EC4899',
    handles: ['out'],
    data: () => ({ add: [], remove: [] }),
  },
  webhook: {
    icon: 'i-lucide-webhook',
    color: '#6366F1',
    handles: ['out', 'error'],
    data: () => ({ method: 'post', url: '', save_as: '' }),
  },
  ai: {
    icon: 'i-lucide-sparkles',
    color: '#A855F7',
    handles: ['out', 'handoff'],
    data: () => ({ prompt: '', send_reply: true, save_as: '' }),
  },
  deal: {
    icon: 'i-lucide-circle-dollar-sign',
    color: '#00875A',
    handles: ['out'],
    data: () => ({ pipeline_id: null, stage_id: null, title_template: '', value_template: '' }),
  },
  end: {
    icon: 'i-lucide-flag',
    color: '#334155',
    handles: [],
    data: () => ({ message: '', resolve_conversation: false }),
  },
};

// Tipos que o usuário pode arrastar da paleta (start já existe no fluxo novo).
export const PALETTE_TYPES = Object.keys(NODE_TYPES).filter(
  type => type !== 'start'
);

let counter = 0;
export const newNodeId = type => {
  counter += 1;
  return `${type}_${Date.now().toString(36)}_${counter}`;
};

export const outputHandles = node => {
  if (node.type === 'question') {
    const options = node.data?.options || [];
    return [...options.map(option => option.id), 'fallback', 'timeout'];
  }
  return NODE_TYPES[node.type]?.handles || [];
};

export const emptyFlow = () => ({
  version: 1,
  viewport: { x: 0, y: 0, zoom: 1 },
  nodes: [
    {
      id: 'start',
      type: 'start',
      position: { x: 80, y: 200 },
      data: {},
    },
  ],
  edges: [],
});
