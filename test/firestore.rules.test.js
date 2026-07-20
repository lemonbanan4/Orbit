const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { readFileSync } = require('fs');

let testEnv;

beforeAll(async () => {
  // Load your local firestore.rules file
  testEnv = await initializeTestEnvironment({
    projectId: "orbit-mvp-54642",
    firestore: { 
      rules: readFileSync("firestore.rules", "utf8"),
      host: "127.0.0.1",
      port: 8080
    },
  });
});

afterAll(async () => {
  // Clean up the emulator after tests
  if (testEnv) {
    await testEnv.cleanup();
  }
});

describe("Orbit Firestore Security Rules", () => {
  beforeEach(async () => {
    // Clear the database before each test
    await testEnv.clearFirestore();
  });

  it("Allows authenticated user to update their own non-restricted fields", async () => {
    const db = testEnv.authenticatedContext("user123").firestore();
    const userDoc = db.collection("users").doc("user123");
    
    // Simulate setting up the initial document
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection("users").doc("user123").set({ isGuest: false, streakCount: 5 });
    });

    // Valid update
    await assertSucceeds(userDoc.update({ name: "Commander Lemon" }));
  });

  it("Allows a user to update their streak freeze fields", async () => {
    const db = testEnv.authenticatedContext("user123").firestore();
    const userDoc = db.collection("users").doc("user123");

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection("users").doc("user123").set({ isGuest: false, streakFreezes: 0 });
    });

    await assertSucceeds(
      userDoc.update({ streakFreezes: 1, isStreakFrozen: true })
    );
  });

  it("Allows a normal update on a doc that already has a friends array", async () => {
    // Regression check: hasOnly() evaluates the full *merged* resulting
    // document, not just this write's delta -- 'friends' must stay in
    // isValidUser's allowedKeys or every future write for any user who's
    // ever added a friend would be permanently rejected.
    const db = testEnv.authenticatedContext("user123").firestore();
    const userDoc = db.collection("users").doc("user123");

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection("users").doc("user123").set({
        isGuest: false,
        friends: ["existingFriend456"],
      });
    });

    await assertSucceeds(userDoc.update({ xp: 50 }));
  });

  it("Denies a client directly writing to their own friends array", async () => {
    const db = testEnv.authenticatedContext("user123").firestore();
    const userDoc = db.collection("users").doc("user123");

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection("users").doc("user123").set({ isGuest: false });
    });

    // 'friends' may only be written server-side (Admin SDK) by
    // notifyOnFriendRequestAccepted/removeFriend/cleanupUserAccount -- a
    // client forging this would let it read a stranger's data via the
    // leaderboard's users-where-in-friends query with no accept step.
    await assertFails(userDoc.update({ friends: ["victimUid"] }));
  });

  it("Denies including friends in the initial account-creation write", async () => {
    const db = testEnv.authenticatedContext("user123").firestore();
    const userDoc = db.collection("users").doc("user123");

    await assertFails(userDoc.set({ isGuest: false, friends: ["victimUid"] }));
  });

  it("Denies setting xp to a negative or wrong-typed value", async () => {
    const db = testEnv.authenticatedContext("user123").firestore();
    const userDoc = db.collection("users").doc("user123");

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection("users").doc("user123").set({ isGuest: false, xp: 100 });
    });

    await assertFails(userDoc.update({ xp: -50 }));
    await assertFails(userDoc.update({ xp: "999999" }));
    await assertSucceeds(userDoc.update({ xp: 150 }));
  });

  it("Denies setting current_level below 1", async () => {
    const db = testEnv.authenticatedContext("user123").firestore();
    const userDoc = db.collection("users").doc("user123");

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection("users").doc("user123").set({ isGuest: false, current_level: 1 });
    });

    await assertFails(userDoc.update({ current_level: 0 }));
    await assertSucceeds(userDoc.update({ current_level: 2 }));
  });

  it("Denies a Guest from modifying their streakCount", async () => {
    // Create an authenticated context simulating an anonymous provider
    const guestDb = testEnv.authenticatedContext("guest123", {
      firebase: { sign_in_provider: 'anonymous' }
    }).firestore();
    
    const guestDoc = guestDb.collection("users").doc("guest123");

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection("users").doc("guest123").set({ isGuest: true, streakCount: 0 });
    });

    // Attempting to cheat the streak counter should FAIL
    await assertFails(guestDoc.update({ streakCount: 100 }));
  });

  it("Allows a user to write and read their own coaching note", async () => {
    const db = testEnv.authenticatedContext("user123").firestore();
    const notesRef = db
      .collection("users")
      .doc("user123")
      .collection("coaching_notes");

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection("users").doc("user123").set({ isGuest: false });
    });

    await assertSucceeds(
      notesRef.add({
        text: "Felt good about today's routine.",
        mood: "Calm",
        createdAt: new Date(),
      })
    );
    await assertSucceeds(notesRef.get());
  });

  it("Allows a normal fairy_history entry but denies an oversized one", async () => {
    const db = testEnv.authenticatedContext("user123").firestore();
    const historyRef = db
      .collection("users")
      .doc("user123")
      .collection("fairy_history");

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection("users").doc("user123").set({ isGuest: false });
    });

    await assertSucceeds(
      historyRef.add({
        context: "Morning Meditation",
        fairyMessage: "You're glowing! That streak is legendary!",
        userReply: "Heck yes!",
        timestamp: new Date(),
      })
    );

    await assertFails(
      historyRef.add({
        context: "x",
        fairyMessage: "y".repeat(3000),
        userReply: "z",
        timestamp: new Date(),
      })
    );
  });

  it("Denies another user from reading someone else's coaching notes", async () => {
    const aliceDb = testEnv.authenticatedContext("alice123").firestore();
    const bobNotesRef = aliceDb
      .collection("users")
      .doc("bob456")
      .collection("coaching_notes");

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection("users").doc("bob456").set({ isGuest: false });
      await context
        .firestore()
        .collection("users")
        .doc("bob456")
        .collection("coaching_notes")
        .add({ text: "Private reflection", timestamp: new Date() });
    });

    await assertFails(bobNotesRef.get());
  });

  it("Allows a user to log a skipped session with a habit title", async () => {
    const db = testEnv.authenticatedContext("user123").firestore();
    const sessionsRef = db
      .collection("users")
      .doc("user123")
      .collection("skipped_sessions");

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection("users").doc("user123").set({ isGuest: false });
    });

    await assertSucceeds(
      sessionsRef.add({
        habitTitle: "Morning Meditation",
        reason: "Skipped without a reason",
        timestamp: new Date(),
      })
    );
  });

  it("Denies a skipped session without a habit title", async () => {
    const db = testEnv.authenticatedContext("user123").firestore();
    const sessionsRef = db
      .collection("users")
      .doc("user123")
      .collection("skipped_sessions");

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection("users").doc("user123").set({ isGuest: false });
    });

    await assertFails(
      sessionsRef.add({ reason: "Skipped without a reason", timestamp: new Date() })
    );
  });

  it("Allows a user to write per-day history onto their own habit", async () => {
    const db = testEnv.authenticatedContext("user123").firestore();
    const habitDoc = db
      .collection("users")
      .doc("user123")
      .collection("habits")
      .doc("habit1");

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection("users").doc("user123").set({ isGuest: false });
      await context
        .firestore()
        .collection("users")
        .doc("user123")
        .collection("habits")
        .doc("habit1")
        .set({ title: "Meditate", routine: "Morning", completedDays: 0, totalDays: 0 });
    });

    // Dot-notation update on a nested map field — this is how
    // RoutineProvider._checkDailyReset() records a single day without
    // clobbering the rest of the history map.
    await assertSucceeds(
      habitDoc.update({
        totalDays: 1,
        completedDays: 1,
        "history.2026-07-17": true,
      })
    );
  });

  it("Allows a user to mark their own habit as a goal", async () => {
    const db = testEnv.authenticatedContext("user123").firestore();
    const habitDoc = db
      .collection("users")
      .doc("user123")
      .collection("habits")
      .doc("habit1");

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection("users").doc("user123").set({ isGuest: false });
      await context
        .firestore()
        .collection("users")
        .doc("user123")
        .collection("habits")
        .doc("habit1")
        .set({ title: "Meditate", routine: "Morning", completedDays: 0, totalDays: 0 });
    });

    await assertSucceeds(habitDoc.update({ isGoal: true }));
  });

  it("Allows a user to set their habit's Focus Journey category", async () => {
    const db = testEnv.authenticatedContext("user123").firestore();
    const habitDoc = db
      .collection("users")
      .doc("user123")
      .collection("habits")
      .doc("habit1");

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection("users").doc("user123").set({ isGuest: false });
      await context
        .firestore()
        .collection("users")
        .doc("user123")
        .collection("habits")
        .doc("habit1")
        .set({ title: "Meditate", routine: "Morning", completedDays: 0, totalDays: 0 });
    });

    await assertSucceeds(habitDoc.update({ category: "mind" }));
  });

  it("Allows a valid 7-day activeDays but denies a wrong-length one", async () => {
    const db = testEnv.authenticatedContext("user123").firestore();
    const habitDoc = db
      .collection("users")
      .doc("user123")
      .collection("habits")
      .doc("habit1");

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection("users").doc("user123").set({ isGuest: false });
      await context
        .firestore()
        .collection("users")
        .doc("user123")
        .collection("habits")
        .doc("habit1")
        .set({ title: "Meditate", routine: "Morning", completedDays: 0, totalDays: 0 });
    });

    await assertSucceeds(
      habitDoc.update({
        activeDays: [true, false, true, false, true, false, false],
      })
    );
    await assertFails(habitDoc.update({ activeDays: [true, false, true] }));
  });

  it("Allows valid count-based habit fields but denies out-of-range ones", async () => {
    const db = testEnv.authenticatedContext("user123").firestore();
    const habitDoc = db
      .collection("users")
      .doc("user123")
      .collection("habits")
      .doc("habit1");

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection("users").doc("user123").set({ isGuest: false });
      await context
        .firestore()
        .collection("users")
        .doc("user123")
        .collection("habits")
        .doc("habit1")
        .set({ title: "Drink Water", routine: "Morning", completedDays: 0, totalDays: 0 });
    });

    await assertSucceeds(
      habitDoc.update({ targetCount: 8, unit: "glasses", currentCount: 3 })
    );
    await assertFails(habitDoc.update({ targetCount: 0 }));
    await assertFails(habitDoc.update({ targetCount: -1 }));
    await assertFails(habitDoc.update({ currentCount: -1 }));
  });

  it("Allows toggling isArchived but denies a non-boolean value", async () => {
    const db = testEnv.authenticatedContext("user123").firestore();
    const habitDoc = db
      .collection("users")
      .doc("user123")
      .collection("habits")
      .doc("habit1");

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection("users").doc("user123").set({ isGuest: false });
      await context
        .firestore()
        .collection("users")
        .doc("user123")
        .collection("habits")
        .doc("habit1")
        .set({ title: "Shovel Snow", routine: "Morning", completedDays: 0, totalDays: 0 });
    });

    await assertSucceeds(habitDoc.update({ isArchived: true }));
    await assertSucceeds(habitDoc.update({ isArchived: false }));
    await assertFails(habitDoc.update({ isArchived: "yes" }));
  });

  it("Allows setting featured_habit_id to a valid string but denies a non-string value", async () => {
    const db = testEnv.authenticatedContext("user123").firestore();
    const userDoc = db.collection("users").doc("user123");

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection("users").doc("user123").set({ isGuest: false });
    });

    await assertSucceeds(userDoc.update({ featured_habit_id: "habit1" }));
    await assertFails(userDoc.update({ featured_habit_id: 12345 }));
  });

  it("Denies a habit write with a field outside the allowlist", async () => {
    const db = testEnv.authenticatedContext("user123").firestore();
    const habitDoc = db
      .collection("users")
      .doc("user123")
      .collection("habits")
      .doc("habit1");

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection("users").doc("user123").set({ isGuest: false });
      await context
        .firestore()
        .collection("users")
        .doc("user123")
        .collection("habits")
        .doc("habit1")
        .set({ title: "Meditate", routine: "Morning", completedDays: 0, totalDays: 0 });
    });

    await assertFails(habitDoc.update({ description: "not allowed" }));
  });

  it("Denies a user from reading another user's document", async () => {
    // Alice tries to snoop on Bob's data
    const aliceDb = testEnv.authenticatedContext("alice123").firestore();
    const bobDoc = aliceDb.collection("users").doc("bob456");

    // Simulate Bob's document existing
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection("users").doc("bob456").set({ name: "Bob", isGuest: false });
    });

    // Alice attempting to read Bob's document should FAIL
    await assertFails(bobDoc.get());
    await assertFails(bobDoc.update({ name: "Hacked by Alice" }));
  });
});