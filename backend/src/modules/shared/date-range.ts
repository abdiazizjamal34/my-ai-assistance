const defaultTimezone = 'Africa/Nairobi';

function partsForZone(date: Date, timezone: string) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: timezone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(date);
  return Object.fromEntries(parts.map((part) => [part.type, part.value]));
}

export function localDateKey(date: Date, timezone: string): string {
  const parts = partsForZone(date, timezone);
  return `${parts.year}-${parts.month}-${parts.day}`;
}

function zonedLocalDateToUtc(localDate: string, timezone: string): Date {
  const [year, month, day] = localDate.split('-').map(Number);
  const guess = new Date(Date.UTC(year, month - 1, day));
  const parts = partsForZone(guess, timezone);
  const asUtc = Date.UTC(
    Number(parts.year),
    Number(parts.month) - 1,
    Number(parts.day),
    Number(parts.hour),
    Number(parts.minute),
    Number(parts.second),
  );
  const offset = asUtc - guess.getTime();
  return new Date(guess.getTime() - offset);
}

function shiftDateKey(dateKey: string, days: number): string {
  const date = new Date(`${dateKey}T00:00:00Z`);
  date.setUTCDate(date.getUTCDate() + days);
  return date.toISOString().slice(0, 10);
}

export async function getUserTimezone(prisma: { userPreferences: { findUnique: Function }; user: { findUnique: Function } }, userId: string): Promise<string> {
  const preferences = await prisma.userPreferences.findUnique({ where: { userId }, select: { timezone: true } });
  if (preferences?.timezone) return preferences.timezone;
  const user = await prisma.user.findUnique({ where: { id: userId }, select: { timezone: true } });
  return user?.timezone ?? defaultTimezone;
}

export function getLocalDayRange(date: Date, timezone: string): { start: Date; end: Date } {
  const today = localDateKey(date, timezone);
  return {
    start: zonedLocalDateToUtc(today, timezone),
    end: zonedLocalDateToUtc(shiftDateKey(today, 1), timezone),
  };
}