import AiAgentAPI from '../aiAgent';
import ApiClient from '../ApiClient';

describe('#AiAgentAPI', () => {
  it('creates correct instance', () => {
    expect(AiAgentAPI).toBeInstanceOf(ApiClient);
    expect(AiAgentAPI).toHaveProperty('getConfig');
    expect(AiAgentAPI).toHaveProperty('updateConfig');
    expect(AiAgentAPI).toHaveProperty('getUsage');
    expect(AiAgentAPI).toHaveProperty('getModels');
  });
});
