// Apontavam para a documentação do Chatwoot (chwt.app). O Hdev CRM ainda não
// tem documentação própria, e mandar o cliente da agência para o site do
// upstream é pior do que não ter link: o `BaseSettingsHeader` já esconde o
// link quando a URL é undefined, então com o mapa vazio ele some da tela
// sozinho. Preencher conforme os artigos saírem no Help Center.
const FEATURE_HELP_URLS = {};

export function getHelpUrlForFeature(featureName) {
  return FEATURE_HELP_URLS[featureName];
}
