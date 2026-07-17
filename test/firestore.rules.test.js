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