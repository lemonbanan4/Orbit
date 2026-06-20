/// <reference types="jest" />
import * as admin from "firebase-admin";
import fft = require("firebase-functions-test");

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
    // Arrange: Mock Firestore to return a user with all habits completed
    // (Based on the logic: habitId === isCompleted)
      firestoreGetMock.mockResolvedValue({
        docs: [
          {
            data: () => ({
              fcmToken: "mock-token-1",
              daily_summary_notifs: true,
              habits: {habit1: "habit1", habit2: "habit2"},
            }),
          },
        ],
      });
      messagingSendMock.mockResolvedValue("message-id");

      // Act: Wrap the v2 scheduled function and invoke it
      const wrapped = testEnv.wrap(sendDailySummary);
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
      const wrapped = testEnv.wrap(sendDailySummary);
      const event = {scheduleTime: new Date().toISOString()};
      await wrapped(event as any);

      // Assert
      expect(messagingSendMock).not.toHaveBeenCalled();
    });
});

describe("deleteOldNotifications", () => {
  let firestoreWhereMock: jest.Mock;
  let firestoreGetMock: jest.Mock;

  beforeEach(() => {
    // Get references to the specific mocked chain components
    firestoreWhereMock = admin.firestore()
      .collectionGroup("").where as jest.Mock;
    firestoreGetMock = admin.firestore()
      .collectionGroup("").get as jest.Mock;
    jest.clearAllMocks();
  });

  it(
    "should query for and delete notifications exactly 30 days old",
    async () => {
    // 1. Mock the system time exactly to May 31, 2024
      jest.useFakeTimers();
      const mockNow = new Date("2024-05-31T02:00:00Z");
      jest.setSystemTime(mockNow);

      // 2. Setup mock data
      firestoreGetMock.mockResolvedValue({
        empty: false,
        size: 1,
        docs: [{ref: "mock-doc-ref"}],
      });

      // 3. Execute scheduled function
      const wrapped = testEnv.wrap(deleteOldNotifications);
      const event = {scheduleTime: mockNow.toISOString()};
      await wrapped(event as any);

      // 4. Assert correct date was calculated (May 31 - 30 days = May 1)
      const expectedDate = new Date("2024-05-01T02:00:00.000Z");
      expect(firestoreWhereMock).toHaveBeenCalledWith(
        "timestamp",
        "<=",
        expectedDate
      );

      // 5. Restore timers so other tests aren't affected
      jest.useRealTimers();
    });
});
