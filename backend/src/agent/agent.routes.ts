import { Router } from 'express';

import { UserRequest } from '../middleware/user-context';
import { AgentService } from './agent.service';

export function createAgentRouter(agent: AgentService) {
  const router = Router();

  router.post('/chat', async (request, response) => {
    const body = request.body as {
      message?: unknown;
      conversationId?: unknown;
    };

    if (typeof body.message !== 'string' || !body.message.trim()) {
      response.status(400).json({ error: 'message is required.' });
      return;
    }

    const conversationId =
      typeof body.conversationId === 'string' && body.conversationId.trim()
        ? body.conversationId.trim()
        : undefined;

    const result = await agent.chat(
      (request as UserRequest).userId,
      body.message,
      conversationId,
    );

    response.json(result);
  });

  router.post('/chat/stream', async (request, response) => {
    const body = request.body as {
      message?: unknown;
      conversationId?: unknown;
    };

    if (typeof body.message !== 'string' || !body.message.trim()) {
      response.status(400).json({ error: 'message is required.' });
      return;
    }

    const conversationId =
      typeof body.conversationId === 'string' && body.conversationId.trim()
        ? body.conversationId.trim()
        : undefined;

    response.setHeader('Content-Type', 'text/event-stream');
    response.setHeader('Cache-Control', 'no-cache, no-transform');
    response.setHeader('Connection', 'keep-alive');
    response.setHeader('X-Accel-Buffering', 'no');
    response.flushHeaders?.();

    const userId = (request as UserRequest).userId;

    try {
      for await (const event of agent.chatStream(
        userId,
        body.message,
        conversationId,
      )) {
        console.log(
          '[stream-event]',
          event.type,
          event.type === 'text'
              ? `delta=${(event as { delta?: string }).delta?.slice(0, 30)}`
              : event.type === 'tool'
                  ? (event as { name?: string }).name
                  : event.type === 'error'
                      ? (event as { message?: string }).message
                      : '',
        );
        response.write(`data: ${JSON.stringify(event)}\n\n`);
      }
    } catch (error) {
      console.error('[stream-route-error]', {
        message: error instanceof Error ? error.message : String(error),
        stack: error instanceof Error ? error.stack : undefined,
      });
      response.write(
        `data: ${JSON.stringify({
          type: 'error',
          message:
            error instanceof Error ? error.message : 'Stream failed.',
        })}\n\n`,
      );
    } finally {
      response.end();
    }
  });

  return router;
}