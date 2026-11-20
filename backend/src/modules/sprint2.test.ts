import 'dotenv/config';

import assert from 'node:assert/strict';
import { after, before, describe, test } from 'node:test';

import { prisma } from '../config/database';
import { getAssistantProfile, updateAssistantProfile } from './assistant/assistant.service';
import { createGoal, getGoal, listGoals, updateGoal, cancelGoal } from './goals/goals.service';
import { getPreferences, updatePreferences } from './preferences/preferences.service';
import { getProfile, updateProfile } from './profile/profile.service';

const primaryUserId = '00000000-0000-4000-8000-000000000101';
const otherUserId = '00000000-0000-4000-8000-000000000102';
let goalId = '';

before(async () => {
  await prisma.user.deleteMany({ where: { id: { in: [primaryUserId, otherUserId] } } });
});

after(async () => {
  await prisma.user.deleteMany({ where: { id: { in: [primaryUserId, otherUserId] } } });
  await prisma.$disconnect();
});

describe('Sprint 2 personal context services', () => {
  test('gets a profile with defaults', async () => {
    const profile = await getProfile(prisma, primaryUserId);
    assert.equal(profile.id, primaryUserId);
    assert.equal(profile.timezone, 'Africa/Nairobi');
  });

  test('updates a profile', async () => {
    const profile = await updateProfile(prisma, primaryUserId, {
      firstName: 'Amina',
      displayName: 'Amina',
      email: 'amina@example.com',
    });
    assert.equal(profile.firstName, 'Amina');
    assert.equal(profile.email, 'amina@example.com');
  });

  test('gets preferences with planning defaults', async () => {
    const preferences = await getPreferences(prisma, primaryUserId);
    assert.equal(preferences.timezone, 'Africa/Nairobi');
    assert.equal(preferences.morningPlanningTime, '07:30');
    assert.equal(preferences.eveningReviewTime, '20:00');
  });

  test('updates preferences', async () => {
    const preferences = await updatePreferences(prisma, primaryUserId, {
      timezone: 'Europe/London',
      morningPlanningEnabled: false,
      morningPlanningTime: '08:00',
    });
    assert.equal(preferences.timezone, 'Europe/London');
    assert.equal(preferences.morningPlanningEnabled, false);
  });

  test('gets assistant profile with defaults', async () => {
    const profile = await getAssistantProfile(prisma, primaryUserId);
    assert.equal(profile.name, 'Chief');
    assert.equal(profile.proactivity, 'MEDIUM');
  });

  test('updates assistant profile', async () => {
    const profile = await updateAssistantProfile(prisma, primaryUserId, {
      name: 'Maya',
      personality: 'STRATEGIC',
      proactivity: 'HIGH',
    });
    assert.equal(profile.name, 'Maya');
    assert.equal(profile.personality, 'STRATEGIC');
  });

  test('rejects invalid profile input', async () => {
    await assert.rejects(
      () => updateProfile(prisma, primaryUserId, { email: 'invalid' }),
      /valid email address/,
    );
  });

  test('creates a goal', async () => {
    const goal = await createGoal(prisma, primaryUserId, {
      title: 'Build a sustainable routine',
      category: 'PERSONAL',
      priority: 'HIGH',
    });
    goalId = goal.id;
    assert.equal(goal.status, 'ACTIVE');
  });

  test('lists goals for the owning user', async () => {
    const goals = await listGoals(prisma, primaryUserId);
    assert.equal(goals.length, 1);
    assert.equal(goals[0]?.id, goalId);
  });

  test('updates a goal', async () => {
    const goal = await updateGoal(prisma, primaryUserId, goalId, {
      description: 'A foundation for future planning.',
      priority: 'MEDIUM',
    });
    assert.equal(goal.priority, 'MEDIUM');
    assert.equal(goal.description, 'A foundation for future planning.');
  });

  test('enforces goal ownership', async () => {
    await assert.rejects(
      () => getGoal(prisma, otherUserId, goalId),
      /Goal not found/,
    );
    assert.deepEqual(await listGoals(prisma, otherUserId), []);
  });

  test('cancels a goal', async () => {
    const goal = await cancelGoal(prisma, primaryUserId, goalId);
    assert.equal(goal.status, 'CANCELLED');
  });
});