export const APP_BASE_URL = '';

export const MESSAGE_STATUS = {
  FAILED: 'failed',
  SUCCESS: 'success',
  PROGRESS: 'progress',
};

export const MESSAGE_TYPE = {
  INCOMING: 0,
  OUTGOING: 1,
  ACTIVITY: 2,
  TEMPLATE: 3,
};

// ponytail: o prefixo está duplicado como literal em utils.js (escrita) e em
// sdk/IFrameHelper.js (os dois lados do postMessage). Unificar tudo aqui se
// desincronizar de novo — a falha é silenciosa, o iframe só para de responder.
export const WOOT_PREFIX = 'hdev-widget:';
