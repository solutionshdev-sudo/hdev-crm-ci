import { frontendURL } from '../../../../helper/URLHelper';

import SettingsWrapper from '../SettingsWrapper.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/chatbots'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          name: 'chatbots_list',
          meta: {
            permissions: ['administrator'],
          },
          component: () => import('./Index.vue'),
        },
      ],
    },
    {
      // Builder em tela cheia, fora do SettingsWrapper — o canvas precisa da
      // área toda. Lazy: o chunk do @vue-flow só carrega aqui.
      path: frontendURL('accounts/:accountId/settings/chatbots/:chatbotId/builder'),
      name: 'chatbots_builder',
      meta: {
        permissions: ['administrator'],
      },
      component: () => import('./FlowBuilder.vue'),
    },
  ],
};
