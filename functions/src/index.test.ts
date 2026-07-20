/// <reference types="jest" />
import * as admin from "firebase-admin";
import fft = require("firebase-functions-test");
// firebase-functions-test's testEnv.wrap() picks v1 vs v2 wrapping by
// checking the wrapped callback's arity (cloudFunction.run.length === 1) --
// every onSchedule() handler in this codebase is `async () => {...}` (no
// event param needed, a deliberate convention used consistently across all
// six scheduled functions here), so that heuristic misdetects them as v1
// and rejects the v2-shaped {scheduleTime} test event. wrapV2 skips the
// heuristic and wraps unconditionally as v2.
import {wrapV2} from "firebase-functions-test/lib/v2";

// 1. Mock the Firebase Admin SDK before importing the function
jest.mock("firebase-admin", () => {
  const batchMock = {
    delete: jest.fn(),
    commit: jest.fn().mockResolvedValue(undefined),
  };
  const firestoreMock = {
    collection: jest.fn().mockReturnThis(),
    collectionGroup: jest.fn().mockReturnThis(),
    where: jest.fn().mockReturnThis(),
    orderBy: jest.fn().mockReturnThis(),
    limit: jest.fn().mockReturnThis(),
    startAfter: jest.fn().mockReturnThis(),
    get: jest.fn(),
    batch: jest.fn(() => batchMock),
  };
  const messagingMock = {
    send: jest.fn(),
  };

  // Create a mock that supports both admin.firestore() and admin.firestore.FieldValue
  const firestoreNamespace: any = () => firestoreMock;
  firestoreNamespace.FieldValue = {
    serverTimestamp: jest.fn(),
    increment: jest.fn(),
  };

  return {
    initializeApp: jest.fn(),
    firestore: firestoreNamespace,
    messaging: () => messagingMock,
  };
});

import {sendDailySummary, deleteOldNotifications} from "./index";

const testEnv = fft();

describe("sendDailySummary", () => {
  let firestoreGetMock: jest.Mock;
  let messagingSendMock: jest.Mock;

  beforeEach(() => {
    // Get references to our mocked functions
    firestoreGetMock = admin.firestore().collection("users").get as jest.Mock;
    messagingSendMock = admin.messaging().send as jest.Mock;

    // Clear previous mock calls
    jest.clearAllMocks();
  });

  afterAll(() => {
    testEnv.cleanup();
  });

  it(
    "should send 'Perfect Orbit' summary when all habits are completed",
    async () => {
    // Arrange: Mock Firestore to return a user with all habits completed.
    // RoutineProvider._saveToCloud() writes 'habits' as
    // Map<habitId, bool> -- habit1/habit2 completed (true).
      firestoreGetMock.mockResolvedValue({
        docs: [
          {
            data: () => ({
              fcmToken: "mock-token-1",
              daily_summary_notifs: true,
              habits: {habit1: true, habit2: true},
            }),
          },
        ],
      });
      messagingSendMock.mockResolvedValue("message-id");

      // Act: wrap the v2 scheduled function and invoke it (see the wrapV2
      // import comment above for why this isn't testEnv.wrap()).
      const wrapped = wrapV2(sendDailySummary as any);
      const event = {scheduleTime: new Date().toISOString()};
      await wrapped(event as any);

      // Assert: Strictly verify exact messaging payload matches expectations
      expect(messagingSendMock).toHaveBeenCalledTimes(1);
      expect(messagingSendMock).toHaveBeenCalledWith({
        notification: {
          title: "Perfect Orbit Achieved! 🌌",
          body: "Incredible! You completed all 2 habits today.",
        },
        android: {notification: {sound: "orbit_chime"}},
        apns: {payload: {aps: {sound: "orbit_chime.wav"}}},
        token: "mock-token-1",
      });
    });

  it(
    "should send a partial-completion summary with the real completed count",
    async () => {
    // Regression test: completedCount used to compare the habitId key
    // against the boolean value (habitId === isCompleted), which can
    // never be true -- this always reported 0 completions regardless of
    // real progress. habit1 done, habit2/habit3 not.
      firestoreGetMock.mockResolvedValue({
        docs: [
          {
            data: () => ({
              fcmToken: "mock-token-3",
              daily_summary_notifs: true,
              habits: {habit1: true, habit2: false, habit3: false},
            }),
          },
        ],
      });
      messagingSendMock.mockResolvedValue("message-id");

      const wrapped = wrapV2(sendDailySummary as any);
      const event = {scheduleTime: new Date().toISOString()};
      await wrapped(event as any);

      expect(messagingSendMock).toHaveBeenCalledTimes(1);
      expect(messagingSendMock).toHaveBeenCalledWith({
        notification: {
          title: "Daily Orbit Summary 🌠",
          body: "You completed 1 out of 3 habits today.\n            " +
            "Ready to try again tomorrow?",
        },
        android: {notification: {sound: "orbit_chime"}},
        apns: {payload: {aps: {sound: "orbit_chime.wav"}}},
        token: "mock-token-3",
      });
    });

  it(
    "should not send notification if daily_summary_notifs is false",
    async () => {
    // Arrange: Mock Firestore to return a user who opted out of notifications
      firestoreGetMock.mockResolvedValue({
        docs: [
          {
            data: () => ({
              fcmToken: "mock-token-2",
              daily_summary_notifs: false,
              habits: {habit1: "habit1"},
            }),
          },
        ],
      });

      // Act
      const wrapped = wrapV2(sendDailySummary as any);
      const event = {scheduleTime: new Date().toISOString()};
      await wrapped(event as any);

      // Assert
      expect(messagingSendMock).not.toHaveBeenCalled();
    });
});

describe("deleteOldNotifications", () => {
  let firestoreWhereMock: jest.Mock;
  let firestoreGetMock: jest.Mock;
  let batchDeleteMock: jest.Mock;

  beforeEach(() => {
    // Get references to the specific mocked chain components
    firestoreWhereMock = admin.firestore()
      .collectionGroup("").where as jest.Mock;
    firestoreGetMock = admin.firestore()
      .collectionGroup("").get as jest.Mock;
    batchDeleteMock = admin.firestore().batch().delete as jest.Mock;
    jest.clearAllMocks();
  });

  it(
    "should query for and delete notifications exactly 30 days old, " +
      "one page at a time",
    async () => {
    // 1. Mock the system time exactly to May 31, 2024
      jest.useFakeTimers();
      const mockNow = new Date("2024-05-31T02:00:00Z");
      jest.setSystemTime(mockNow);

      // 2. A single page smaller than PAGE_SIZE (300) so the pagination
      // loop in deleteOldNotifications terminates after one iteration.
      const mockDocRef = {ref: "mock-doc-ref"};
      firestoreGetMock.mockResolvedValue({
        empty: false,
        size: 1,
        docs: [mockDocRef],
      });

      // 3. Execute scheduled function
      const wrapped = wrapV2(deleteOldNotifications as any);
      const event = {scheduleTime: mockNow.toISOString()};
      await wrapped(event as any);

      // 4. Assert correct date was calculated (May 31 - 30 days = May 1)
      const expectedDate = new Date("2024-05-01T02:00:00.000Z");
      expect(firestoreWhereMock).toHaveBeenCalledWith(
        "timestamp",
        "<=",
        expectedDate
      );

      // 5. Assert the matched doc was actually queued for deletion --
      // this is what regressed silently when the pagination rewrite
      // switched to .orderBy()/.limit()/.startAfter(), none of which the
      // mock previously implemented (calls just threw, swallowed by the
      // function's own try/catch, and the test still reported green).
      expect(batchDeleteMock).toHaveBeenCalledWith(mockDocRef.ref);

      // 6. Restore timers so other tests aren't affected
      jest.useRealTimers();
    });
});
