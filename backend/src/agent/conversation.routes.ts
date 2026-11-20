import { Router } from 'express';

import { asUserRequest } from '../middleware/user-context';
import { ConversationService } from './conversation.service';

export function createConversationRouter(conversations: ConversationService) {
  const router = Router();

  // GET /api/conversations - list recent conversations for the user
  router.get('/', async (request, response) => {
    const userId = asUserRequest(request).userId;
    const limit = Math.min(
      Math.max(Number(request.query.limit) || 20, 1),
      100,
    );
    const items = await conversations.listForUser(userId, limit);
    response.json({ data: items });
  });

  // GET /api/conversations/:id/messages - messages in a conversation
  router.get('/:id/messages', async (request, response) => {
    const userId = asUserRequest(request).userId;
    const limit = Math.min(
      Math.max(Number(request.query.limit) || 200, 1),
      500,
    );
    const messages = await conversations.getMessages(
      userId,
      request.params.id,
      limit,
    );
    response.json({ data: messages });
  });

  return router;
}