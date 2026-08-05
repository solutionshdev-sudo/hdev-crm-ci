import { frontendURL } from '../../../helper/URLHelper';

export const routes = [
  {
    path: frontendURL('accounts/:accountId/deals'),
    name: 'deals_board_index',
    component: () => import('./Index.vue'),
    meta: {
      permissions: ['administrator', 'agent'],
    },
  },
];
