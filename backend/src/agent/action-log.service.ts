import { AgentActionStatus, Prisma, PrismaClient } from '@prisma/client';

export class ActionLogService {
  constructor(private readonly prisma: PrismaClient) {}

  async record(input: {
    userId: string;
    conversationId?: string;
    actionType: string;
    toolName?: string;
    input?: unknown;
    output?: unknown;
    status: AgentActionStatus;
  }) {
    return this.prisma.agentAction.create({
      data: {
        userId: input.userId,
        conversationId: input.conversationId,
        actionType: input.actionType,
        toolName: input.toolName,
        input: input.input as Prisma.InputJsonValue,
        output: input.output as Prisma.InputJsonValue,
        status: input.status,
      },
    });
  }
}