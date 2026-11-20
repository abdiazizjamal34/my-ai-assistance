import { AIProvider, ProviderRequest, ProviderResponse } from '../agent.types';

export class RuleBasedProvider implements AIProvider {
  async generateResponse(request: ProviderRequest): Promise<ProviderResponse> {
    if (request.toolResults?.length) {
      const successful = request.toolResults.filter((result) => result.ok);
      if (!successful.length) return { message: 'I could not complete that action right now.', toolCalls: [] };
      const first = successful[0]?.output as any;
      if (Array.isArray(first)) {
        const lower = request.userMessage.toLowerCase();
        if (lower.includes('what do you remember') || lower.includes('what do you know about me')) {
          const memories = first
            .map((item: any) => typeof item?.content === 'string' ? `• ${item.content}` : null)
            .filter(Boolean)
            .join('\n');
          return { message: memories ? `Here are some things I remember:\n\n${memories}\n\nYou can ask me to forget or update any of these.` : 'I do not have any relevant memories for that yet.', toolCalls: [] };
        }
        return { message: `I found ${first.length} item${first.length === 1 ? '' : 's'} for you.`, toolCalls: [] };
      }
      if (first?.title) return { message: `Done. ${first.title} is now updated.`, toolCalls: [] };
      return { message: 'Done. I completed that action successfully.', toolCalls: [] };
    }

    const message = request.userMessage.trim();
    const lower = message.toLowerCase();
    if (lower.includes('forget')) return { message: '', toolCalls: [{ name: 'search_memories', arguments: { query: message } }] };
    if (lower.includes('what do you remember') || lower.includes('what do you know about me')) return { message: '', toolCalls: [{ name: 'get_relevant_memory', arguments: { query: message } }] };
    const rememberMatch = message.match(/remember(?: that| this)?\s+(.+)/i);
    if (rememberMatch?.[1]) {
      return {
        message: '',
        toolCalls: [{
          name: 'save_memory',
          arguments: {
            category: lower.includes('prefer') ? 'PREFERENCE' : 'IMPORTANT_CONTEXT',
            title: lower.includes('prefer') ? 'Communication preference' : 'Remembered context',
            content: rememberMatch[1].trim(),
            importance: 'MEDIUM',
            source: 'USER',
            confidence: 1,
          },
        }],
      };
    }
    if (lower.includes('today')) return { message: '', toolCalls: [{ name: 'get_today_tasks', arguments: {} }, { name: 'get_goals', arguments: {} }] };
    if (lower.includes('overdue')) return { message: '', toolCalls: [{ name: 'get_overdue_tasks', arguments: {} }] };
    if (lower.includes('goal')) return { message: '', toolCalls: [{ name: 'get_goals', arguments: {} }] };
    const taskMatch = message.match(/(?:create|add) (?:a )?task(?: called| to)?\s+(.+)/i);
    if (taskMatch?.[1]) return { message: '', toolCalls: [{ name: 'create_task', arguments: { title: taskMatch[1].trim() } }] };
    const reminderMatch = message.match(/remind me(?: tomorrow)?(?: at ([0-9: ]+(?:am|pm)?))?(?: to)?\s+(.+)/i);
    if (reminderMatch?.[2]) {
      const remindAt = this.parseReminderTime(message, reminderMatch[1]);
      return { message: '', toolCalls: [{ name: 'create_reminder', arguments: { title: reminderMatch[2].trim(), remindAt } }] };
    }
    return { message: 'I can help with your profile, goals, tasks, and reminders. What would you like to do?', toolCalls: [] };
  }

  private parseReminderTime(message: string, timeText?: string): string {
    const date = new Date();
    if (message.toLowerCase().includes('tomorrow')) date.setDate(date.getDate() + 1);
    const match = timeText?.trim().match(/(\d{1,2})(?::(\d{2}))?\s*(am|pm)?/i);
    if (!match) return new Date(Date.now() + 60 * 60 * 1000).toISOString();
    let hour = Number(match[1]);
    const minute = Number(match[2] ?? 0);
    const meridiem = match[3]?.toLowerCase();
    if (meridiem === 'pm' && hour < 12) hour += 12;
    if (meridiem === 'am' && hour === 12) hour = 0;
    date.setHours(hour, minute, 0, 0);
    return date.toISOString();
  }
}