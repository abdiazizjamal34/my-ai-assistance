import { AIProvider, ProviderRequest, ProviderResponse } from '../../agent.types';

export class CapturingProvider implements AIProvider {
  public lastRequest?: ProviderRequest;
  public requests: ProviderRequest[] = [];

  constructor(
    private readonly response: ProviderResponse = {
      message: 'Captured.',
      toolCalls: [],
    },
  ) {}

  async generateResponse(request: ProviderRequest): Promise<ProviderResponse> {
    this.lastRequest = request;
    this.requests.push(request);
    return this.response;
  }
}