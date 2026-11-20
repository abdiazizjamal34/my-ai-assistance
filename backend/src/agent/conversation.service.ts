import { PrismaClient } from "@prisma/client";

import { HttpError } from "../middleware/error-handler";
import type { HistoryTurn } from "./agent.types";

export type AppendMessageInput = {
  conversationId: string;
  role: "user" | "assistant" | "system";
  content: string;
  metadata?: Record<string, unknown>;
};

export class ConversationService {
  constructor(private readonly prisma: PrismaClient) {}

  async ensureConversation(
    userId: string,
    conversationId: string | undefined,
    firstMessage: string,
  ): Promise<{ id: string; created: boolean }> {
    if (conversationId) {
      const existing = await this.prisma.conversation.findFirst({
        where: { id: conversationId, userId },
        select: { id: true },
      });
      if (existing) return { id: existing.id, created: false };
      // Fall through to create if the id doesn't belong to this user.
    }

    const title = firstMessage.trim().slice(0, 80);
    const created = await this.prisma.conversation.create({
      data: { userId, title: title || null },
      select: { id: true },
    });
    return { id: created.id, created: true };
  }

  async appendMessage(input: AppendMessageInput): Promise<void> {
    await this.prisma.conversationMessage.create({
      data: {
        conversationId: input.conversationId,
        role: input.role,
        content: input.content,
        metadata: (input.metadata ?? {}) as never,
      },
    });
    await this.prisma.conversation.update({
      where: { id: input.conversationId },
      data: { updatedAt: new Date() },
    });
  }
  async listForUser(
    userId: string,
    limit = 20,
  ): Promise<
    Array<{
      id: string;
      title: string | null;
      updatedAt: Date;
      messageCount: number;
    }>
  > {
    const conversations = await this.prisma.conversation.findMany({
      where: { userId },
      orderBy: { updatedAt: "desc" },
      take: limit,
      select: {
        id: true,
        title: true,
        updatedAt: true,
        _count: { select: { messages: true } },
      },
    });

    return conversations.map((c) => ({
      id: c.id,
      title: c.title,
      updatedAt: c.updatedAt,
      messageCount: c._count.messages,
    }));
  }

  async getMessages(
    userId: string,
    conversationId: string,
    limit = 100,
  ): Promise<
    Array<{
      id: string;
      role: string;
      content: string;
      createdAt: Date;
      metadata: unknown;
    }>
  > {
    // Verify ownership first
    const conversation = await this.prisma.conversation.findFirst({
      where: { id: conversationId, userId },
      select: { id: true },
    });
    if (!conversation) {
      throw new HttpError(404, "Conversation not found.");
    }

    return this.prisma.conversationMessage.findMany({
      where: { conversationId },
      orderBy: { createdAt: "asc" },
      take: limit,
      select: {
        id: true,
        role: true,
        content: true,
        createdAt: true,
        metadata: true,
      },
    });
  }

  async getRecentMessages(
    conversationId: string,
    limit = 10,
  ): Promise<HistoryTurn[]> {
    const rows = await this.prisma.conversationMessage.findMany({
      where: { conversationId },
      orderBy: { createdAt: "desc" },
      take: limit,
      select: { role: true, content: true },
    });

    // Reverse to chronological order and exclude system messages.
    return rows.reverse().flatMap((row): HistoryTurn[] => {
      if (row.role !== "user" && row.role !== "assistant") {
        return [];
      }

      return [
        {
          role: row.role,
          content: row.content,
        },
      ];
    });
  }
}
