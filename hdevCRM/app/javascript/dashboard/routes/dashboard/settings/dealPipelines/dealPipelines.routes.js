import { frontendURL } from '../../../../helper/URLHelper';

import SettingsWrapper from '../SettingsWrapper.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/deal-pipelines'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          name: 'deal_pipelines_list',
          meta: {
            permissions: ['administrator'],
          },
          component: () => import('./Index.vue'),
        },
      ],
    },
  ],
};
