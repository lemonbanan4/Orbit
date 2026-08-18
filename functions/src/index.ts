/**
 * Import function triggers from their respective submodules:
 *
 * import {onCall} from "firebase-functions/v2/https";
 * import {onDocumentWritten} from "firebase-functions/v2/firestore";
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

import {onDocumentCreated, onDocumentUpdated}
  from "firebase-functions/v2/firestore";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {onRequest, onCall, HttpsError} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import * as functions from "firebase-functions/v1";
import {setGlobalOptions} from "firebase-functions/v2";
import * as crypto from "crypto";

admin.initializeApp();

// Set all v2 functions to deploy to Europe (matching your eur3 Firestore)
setGlobalOptions({region: "europe-west1"});

/**
 * Settings screen's "Enable All Notifications" toggle (subtitle: "Temporarily
 * pause or resume All Orbit reminders") only ever stopped *local* alarms --
 * every server-pushed FCM notification (friend requests, partner links,
 * milestones, challenge invites, the 3-day re-engagement nudge, etc.) had no
 * concept of it at all, so disabling it in Settings didn't actually stop
 * pushes from arriving. Defaults to true to match the client's own default
 * (RoutineProvider._allNotifsEnabled starts true) for users who never
 * touched the toggle.
 * @param {FirebaseFirestore.DocumentData | undefined} userData The
 * recipient's user document data.
 * @return {boolean} Whether server-pushed notifications should be sent.
 */
function isNotifsEnabled(userData: FirebaseFirestore.DocumentData | undefined) {
  return userData?.all_notifs !== false;
}

// GEMINI_API_KEY used to be embedded directly in the Flutter client (loaded
// from a bundled .env asset and used by lib/services/ai_coach_service.dart,
// ai_fairy_service.dart, cosmic_mirror_service.dart to call Gemini straight
// from the device). That key shipped in plaintext inside every app binary --
// anyone who downloaded the app could unzip it and pull the key out, which
// is exactly what got the backing Google Cloud project suspended for
// "abusive activity consistent with hijacking". Stored here via
// defineSecret (Secret Manager-backed, never bundled into any client
// artifact) and only ever used server-side.
const geminiApiKey = defineSecret("GEMINI_API_KEY");

// Was ported verbatim from the old client-side chain (gemini_gateway.dart),
// which had gone stale: gemini-2.5-flash-lite now 404s with "no longer
// available to new users" on this (rotated) key/project, confirmed via
// v1beta/models against the live key -- gemini-2.5-flash-lite is still
// listed there but evidently not actually callable for a new project.
// Replaced with currently-callable models, verified the same way.
const GEMINI_MODEL_CHAIN = [
  "gemini-2.5-flash",
  "gemini-flash-lite-latest",
  "gemini-3.5-flash-lite",
];

/**
 * Whether a failed Gemini response looks like transient capacity pressure
 * (worth falling back to the next model in the chain) rather than a real
 * error (bad request, blocked content, etc. -- worth surfacing immediately).
 * @param {number} status HTTP status code from the Gemini API response.
 * @param {string} bodyText Raw response body text.
 * @return {boolean} True if this looks like a capacity-related failure.
 */
function isGeminiCapacityError(status: number, bodyText: string): boolean {
  return status === 503 || status === 429 ||
    bodyText.includes("UNAVAILABLE") ||
    bodyText.includes("overloaded") ||
    bodyText.includes("high demand") ||
    bodyText.includes("Resource has been exhausted");
}

// Generic text(+optional image)-in, text-out proxy for every Gemini call
// the app makes -- prompts, system instructions, and response parsing all
// still live in the Dart call sites exactly as before; only the network
// call and the API key moved server-side.
export const generateWithGemini = onCall(
  {secrets: [geminiApiKey]},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Must be logged in to use AI features."
      );
    }

    const prompt = request.data?.prompt;
    if (!prompt || typeof prompt !== "string" || prompt.length > 12000) {
      throw new HttpsError("invalid-argument", "Invalid prompt.");
    }
    const systemInstruction = request.data?.systemInstruction;
    if (
      systemInstruction !== undefined &&
      (typeof systemInstruction !== "string" || systemInstruction.length > 4000)
    ) {
      throw new HttpsError("invalid-argument", "Invalid systemInstruction.");
    }
    const jsonMode = request.data?.jsonMode === true;
    const imageBase64 = request.data?.imageBase64;
    const imageMimeType = request.data?.imageMimeType;
    if (imageBase64 !== undefined) {
      if (
        typeof imageBase64 !== "string" ||
        // Base64 is ~1.37x the raw byte size -- this caps the raw image
        // around 6MB, comfortably above what a habit-icon photo needs.
        imageBase64.length > 8_000_000 ||
        typeof imageMimeType !== "string"
      ) {
        throw new HttpsError("invalid-argument", "Invalid image payload.");
      }
    }

    const parts: Array<Record<string, unknown>> = [{text: prompt}];
    if (imageBase64 && imageMimeType) {
      parts.push({inlineData: {mimeType: imageMimeType, data: imageBase64}});
    }

    const requestBody: Record<string, unknown> = {
      contents: [{role: "user", parts}],
    };
    if (systemInstruction) {
      requestBody.systemInstruction = {parts: [{text: systemInstruction}]};
    }
    if (jsonMode) {
      requestBody.generationConfig = {responseMimeType: "application/json"};
    }

    const apiKey = geminiApiKey.value();
    let lastErrorMessage = "No Gemini model responded.";

    for (const model of GEMINI_MODEL_CHAIN) {
      try {
        const url =
          "https://generativelanguage.googleapis.com/v1beta/models/" +
          `${model}:generateContent?key=${apiKey}`;
        const response = await fetch(url, {
          method: "POST",
          headers: {"Content-Type": "application/json"},
          body: JSON.stringify(requestBody),
        });
        const bodyText = await response.text();
        if (!response.ok) {
          if (isGeminiCapacityError(response.status, bodyText)) {
            lastErrorMessage = bodyText;
            continue;
          }
          logger.error(`Gemini error (${model}):`, bodyText);
          throw new HttpsError("internal", "Gemini request failed.");
        }
        const data = JSON.parse(bodyText);
        const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
        if (typeof text !== "string" || text.length === 0) {
          lastErrorMessage = "Empty response from Gemini.";
          continue;
        }
        return {text};
      } catch (e) {
        if (e instanceof HttpsError) throw e;
        lastErrorMessage = String(e);
      }
    }
    logger.error("All Gemini models exhausted:", lastErrorMessage);
    throw new HttpsError("unavailable", "AI is temporarily unavailable.");
  }
);

export const sendPushNotificationOnNewMessage = onDocumentCreated(
  "users/{userId}/notifications/{notificationId}",
  async (event) => {
    const snap = event.data;
    if (!snap) {
      return;
    }
    const notificationData = snap.data() || {};
    const userId = event.params.userId;

    // 1. Fetch the user's FCM token from their Firestore document
    const userDoc = await admin
      .firestore()
      .collection("users")
      .doc(userId)
      .get();
    const userData = userDoc.data();

    if (!userData || !userData.fcmToken) {
      logger.info(`No FCM token found for user: ${userId}`);
      return;
    }
    if (!isNotifsEnabled(userData)) return;

    // 2. Build the push notification payload
    const payload = {
      notification: {
        title: String(notificationData.title || "Orbit Update"),
        body: String(
          notificationData.body || "You have a new message in your inbox.",
        ),
      },
      android: {
        notification: {
          sound: "orbit_chime", // Uses your custom Android sound!
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "orbit_chime.wav", // Uses your custom iOS sound!
          },
        },
      },
      data: {
        // Lets a specific writer (e.g. onFreezeConsumed) route the tap
        // somewhere other than the default Inbox by setting a 'screen'
        // field on the notification doc itself.
        screen: String(notificationData.screen || "notifications"),
      },
      token: String(userData.fcmToken),
    };

    // 3. Send the message via Firebase Cloud Messaging
    try {
      await admin.messaging().send(payload);
      logger.info("Push notification sent successfully!");
    } catch (error) {
      logger.error("Error sending push notification:", error);
    }
  },
);

// Triggered when a user's document is updated, checking for new milestones
export const notifyOnMilestoneUnlocked = onDocumentUpdated(
  "users/{userId}",
  async (event) => {
    const beforeData = event.data?.before?.data();
    const afterData = event.data?.after?.data();

    if (!beforeData || !afterData) return;

    const beforeMilestones = beforeData.unlocked_milestones || [];
    const afterMilestones = afterData.unlocked_milestones || [];

    // Check if a new milestone was added to the array
    if (afterMilestones.length > beforeMilestones.length) {
      const userId = event.params.userId;

      const newMilestones = afterMilestones.filter(
        (m: string) => !beforeMilestones.includes(m)
      );
      // TelemetryProvider.checkMilestoneUnlocks (lib/providers/
      // telemetry_provider.dart) stores the *index* into this same
      // streak-threshold table, not a day count or name -- without this
      // mapping the push read "You've unlocked: 2" instead of a real
      // streak-day milestone.
      const streakThresholds = [
        3, 7, 14, 21, 30, 45, 60, 90, 120, 150, 180, 210, 250, 300, 365,
      ];
      let bodyText =
        "You just reached a new milestone. Keep up the great work!";
      if (newMilestones.length > 0) {
        const days = streakThresholds[newMilestones[0]];
        const label = days ? `${days}-Day Streak` : "a new milestone";
        bodyText = `You've unlocked: ${label}. Keep up the great work!`;
        // Writing this doc is enough -- sendPushNotificationOnNewMessage
        // (this file, top) already fires on every create under
        // users/{userId}/notifications and sends the actual push. This
        // function used to *also* call admin.messaging().send() directly
        // below, so every milestone sent two near-identical pushes.
        try {
          await admin.firestore()
            .collection(`users/${userId}/notifications`)
            .add({
              title: "Milestone Unlocked! 🌟",
              body: bodyText,
              type: "milestone",
              timestamp: admin.firestore.FieldValue.serverTimestamp(),
              isArchived: false,
            });
        } catch (error) {
          logger.error("Error saving in-app milestone notification:", error);
        }
      }
    }
  }
);

// Triggered when a new friend request is created for a user
export const notifyOnFriendRequest = onDocumentCreated(
  "users/{userId}/friend_requests/{requestId}",
  async (event) => {
    const requestData = event.data?.data();
    const userId = event.params.userId;

    if (!requestData) return;

    // Fetch target user's FCM token
    const userDoc = await admin.firestore()
      .collection("users")
      .doc(userId)
      .get();
    const userData = userDoc.data();

    if (!userData || !userData.fcmToken) return;
    if (!isNotifsEnabled(userData)) return;

    const senderName = requestData.senderName || "A fellow astronaut";

    const payload = {
      notification: {
        title: "New Friend Request! 👋",
        body: `${senderName} wants to connect with you in Orbit.`,
      },
      android: {
        notification: {sound: "orbit_chime"},
      },
      apns: {
        payload: {aps: {sound: "orbit_chime.wav"}},
      },
      data: {
        screen: "profile", // Routes them to the profile screen
      },
      token: String(userData.fcmToken),
    };

    try {
      await admin.messaging().send(payload);
      logger.info(`Friend request notification sent to user ${userId}`);
    } catch (error) {
      logger.error("Error sending friend request notification:", error);
    }
  }
);

// Triggered when a habit is marked as completed to notify their partner
export const notifyPartnerOnHabitComplete = onDocumentUpdated(
  "users/{userId}/habits/{habitId}",
  async (event) => {
    const beforeData = event.data?.before?.data();
    const afterData = event.data?.after?.data();

    if (!beforeData || !afterData) return;

    // Check if the habit just transitioned from incomplete to complete
    if (beforeData.isCompleted === false && afterData.isCompleted === true) {
      const userId = event.params.userId;
      const habitTitle = afterData.title || "a habit";

      // 1. Find if this user is linked to a partner
      const linksAsA = await admin.firestore()
        .collection("links")
        .where("userA", "==", userId)
        .get();
      const linksAsB = await admin.firestore()
        .collection("links")
        .where("userB", "==", userId)
        .get();

      let linkDocRef = null;
      let partnerUid: string | null = null;
      if (!linksAsA.empty) {
        linkDocRef = linksAsA.docs[0].ref;
        partnerUid = linksAsA.docs[0]
          .data().userB;
      } else if (!linksAsB.empty) {
        linkDocRef = linksAsB.docs[0].ref;
        partnerUid = linksAsB.docs[0]
          .data().userA;
      }

      // Increment the Shared Sun XP for both users!
      if (linkDocRef) {
        await linkDocRef.update({
          sharedXP: admin.firestore.FieldValue.increment(10),
        });
      }

      if (!partnerUid) return; // Not linked to anyone

      // 2. Fetch the partner's FCM token
      const partnerDoc = await admin
        .firestore()
        .collection("users")
        .doc(partnerUid)
        .get();
      const partnerData = partnerDoc.data();

      if (!partnerData||!partnerData.fcmToken) return;
      if (!isNotifsEnabled(partnerData)) return;

      // 3. Send the push notification
      const payload = {
        notification: {title: "Habit Completed! 🔥",
          body: `Your partner just checked off "${habitTitle}".
        Don't fall behind!`},
        android: {notification: {sound: "orbit_chime"}},
        apns: {payload: {aps: {sound: "orbit_chime.wav"}}},
        data: {screen: "dashboard"},
        token: String(partnerData.fcmToken),
      };

      try {
        await admin.messaging().send(payload);
        logger.info(`Partner notification sent for habit: ${habitTitle}`);
      } catch (error) {
        logger.error("Error sending partner habit notification:", error);
      }
    }
  }
);

// Triggered when a friend request is accepted
export const notifyOnFriendRequestAccepted = onDocumentUpdated(
  "users/{userId}/friend_requests/{requestId}",
  async (event) => {
    const beforeData = event.data?.before?.data();
    const afterData = event.data?.after?.data();

    if (!beforeData || !afterData) return;

    // Check if status changed from something else to 'accepted'
    if (beforeData.status !== "accepted" && afterData.status === "accepted") {
      const targetUserId = event.params.userId;
      const senderId = afterData.senderId;

      if (!senderId) return;

      const db = admin.firestore();

      // 1. Establish the mutual friendship server-side. Clients can only
      // write their own user document (isOwner-only security rules), so
      // this cross-user write has to happen here via the Admin SDK, which
      // bypasses Firestore rules. Also clean up the now-resolved request.
      const batch = db.batch();
      batch.update(db.collection("users").doc(targetUserId), {
        friends: admin.firestore.FieldValue.arrayUnion(senderId),
      });
      batch.update(db.collection("users").doc(senderId), {
        friends: admin.firestore.FieldValue.arrayUnion(targetUserId),
      });
      batch.delete(
        db.collection("users").doc(targetUserId)
          .collection("friend_requests").doc(event.params.requestId)
      );
      await batch.commit();

      // 2. Fetch the user who accepted the request
      const targetUserDoc =
        await db.collection("users").doc(targetUserId).get();
      // 'name' is the field actually shown/edited in the app; 'displayName'
      // is a stale FirebaseAuth-mirrored field usually null (see the same
      // fix already applied to searchUsers/getPartnerInfo below).
      const acceptorName =
        targetUserDoc.data()?.name || "A user";

      // 3. Fetch the sender to get their FCM token
      const senderDoc = await db.collection("users").doc(senderId).get();

      const senderData = senderDoc.data();

      if (!senderData || !senderData.fcmToken) return;
      if (!isNotifsEnabled(senderData)) return;

      const payload = {notification: {title:
        "Request Accepted! 🎉",
      body: `${acceptorName} accepted your friend request.`,
      },
      android: {notification: {sound: "orbit_chime"}},
      apns: {payload: {aps: {sound: "orbit_chime.wav"}}},
      data: {screen: "profile"},
      token: String(senderData.fcmToken),
      };

      try {
        await admin.messaging().send(payload);
        logger
          .info(`Friend request accepted notification
            sent to user ${senderId}`);
      } catch (error) {
        logger
          .error("Error sending friend request accepted notification:", error);
      }
    }
  }
);

// Triggered when a new partner link is created (via 6-digit code)
export const notifyOnPartnerLinked = onDocumentCreated(
  "links/{linkId}",
  async (event) => {
    const linkData = event.data?.data();
    if (!linkData) return;

    // userA is the person who typed the code. userB receive link
    const userAId = linkData.userA;
    const userBId = linkData.userB;
    if (!userAId || !userBId) return;

    const userADoc = await admin
      .firestore().collection("users").doc(userAId).get();
    const userBDoc = await admin
      .firestore().collection("users").doc(userBId).get();

    // 'name' is the field actually shown/edited in the app; 'displayName'
    // is a stale FirebaseAuth-mirrored field usually null (see the same
    // fix already applied to searchUsers/getPartnerInfo below).
    const nameA = userADoc.data()?.name || "A fellow astronaut";
    const tokenB = userBDoc.data()?.fcmToken;

    if (tokenB && isNotifsEnabled(userBDoc.data())) {
      const payload = {notification:
            {title: "Orbits Linked! 🚀",
              body: `${nameA} successfully linked accounts with you!`},
      android: {notification: {sound: "orbit_chime"}},
      apns: {payload: {aps: {sound: "orbit_chime.wav"}}},
      data: {screen: "dashboard"},
      token: String(tokenB),
      };
      await admin.messaging()
        .send(payload)
        .catch((e) => (logger.error("Error sending link notification:", e)));
    }
  }
);

// Triggered when a Group Challenge is created (via the createChallenge
// callable above) to notify every invited participant -- every other
// social event (friend request, friend accepted, partner linked) already
// has a matching trigger; this one didn't.
export const notifyOnChallengeCreated = onDocumentCreated(
  "challenges/{challengeId}",
  async (event) => {
    const challengeData = event.data?.data();
    if (!challengeData) return;

    const creatorId = challengeData.creatorId;
    const title = challengeData.title || "a challenge";
    const participantIds: string[] = challengeData.participantIds ?? [];
    const inviteeIds = participantIds.filter((id) => id !== creatorId);
    if (!creatorId || inviteeIds.length === 0) return;

    const db = admin.firestore();
    const creatorDoc = await db.collection("users").doc(creatorId).get();
    const creatorName = creatorDoc.data()?.name || "A fellow astronaut";

    const inviteeDocs = await Promise.all(
      inviteeIds.map((id) => db.collection("users").doc(id).get())
    );

    await Promise.all(inviteeDocs.map(async (doc) => {
      const fcmToken = doc.data()?.fcmToken;
      if (!fcmToken || !isNotifsEnabled(doc.data())) return;

      const payload = {
        notification: {
          title: "New Group Challenge! 🚀",
          body: `${creatorName} invited you to "${title}".`,
        },
        android: {notification: {sound: "orbit_chime"}},
        apns: {payload: {aps: {sound: "orbit_chime.wav"}}},
        data: {screen: "challenges"},
        token: String(fcmToken),
      };

      try {
        await admin.messaging().send(payload);
      } catch (error) {
        logger.error(
          `Error sending challenge invite notification to ${doc.id}:`, error
        );
      }
    }));
  }
);

// Triggered automatically when a new user signs up via Firebase Auth
export const onUserSignUp = functions
  .region("europe-west1")
  .auth.user()
  .onCreate(async (user) => {
    const userId = user.uid;

    try {
      await admin
        .firestore()
        .collection("users")
        .doc(userId)
        .collection("notifications")
        .add({
          title: "Welcome to Orbit! 🚀",
          body: "Your journey starts here. Start building habits " +
            "and mastering your day.",
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          isArchived: false,
        });
      logger.info(`Welcome notification sent to new user: ${userId}`);
    } catch (error) {
      logger.error("Error sending welcome notification:", error);
    }
  });

// Resets weekly progress for all users every Sunday at midnight
// Triggered automatically when a user deletes their Firebase Auth account
export const cleanupUserAccount = functions
  .region("europe-west1")
  .auth.user()
  .onDelete(async (user) => {
    const userId = user.uid;
    try {
      const userRef = admin.firestore().collection("users").doc(userId);

      // 1. Delete known subcollections to avoid orphaned documents.
      // Must cover every subcollection under users/{userId} (see the
      // `match` blocks in firestore.rules) -- this previously missed
      // coaching_notes, journal_entries, cache, fairy_history, and
      // skipped_sessions, so deleting a Firebase Auth account left all of
      // that personal data behind forever instead of actually purging it.
      const subcollections = [
        "habits",
        "notifications",
        "friend_requests",
        "coaching_notes",
        "journal_entries",
        "cache",
        "fairy_history",
        "skipped_sessions",
      ];
      for (const subcollection of subcollections) {
        const snapshot = await userRef.collection(subcollection).get();
        if (snapshot.empty) {
          continue;
        }

        // Batches can only hold 500 writes. Chunk the deletions!
        const chunks = [];
        for (let i = 0; i < snapshot.docs.length; i += 499) {
          chunks.push(snapshot.docs.slice(i, i + 499));
        }
        for (const chunk of chunks) {
          const batch = admin.firestore().batch();
          chunk.forEach((doc) => batch.delete(doc.ref));
          await batch.commit();
        }
      }

      // 2. Scrub this user out of everyone else's data — otherwise a
      // friend/partner is left permanently pointing at a ghost account
      // with no way to clear it (there's no unlink function at all, and
      // removeFriend only ever runs when the *other* side is still around
      // to call it).
      const linksRef = admin.firestore().collection("links");
      const [friendsOf, linksAsA, linksAsB] = await Promise.all([
        admin.firestore().collection("users")
          .where("friends", "array-contains", userId).get(),
        linksRef.where("userA", "==", userId).get(),
        linksRef.where("userB", "==", userId).get(),
      ]);

      const cleanupBatch = admin.firestore().batch();
      friendsOf.docs.forEach((doc) => {
        cleanupBatch.update(doc.ref, {
          friends: admin.firestore.FieldValue.arrayRemove(userId),
        });
      });
      [...linksAsA.docs, ...linksAsB.docs].forEach((doc) => {
        cleanupBatch.delete(doc.ref);
      });
      await cleanupBatch.commit();

      // 3. Delete the main user document
      await userRef.delete();
      logger.info(`Successfully deleted data for user: ${userId}`);
    } catch (error) {
      logger.error(`Error deleting data for user ${userId}:`, error);
    }
  });

// Cleans up notifications older than 30 days every night at 2:00 AM
//
// Paginated rather than a single .get() -- this query was silently failing
// with FAILED_PRECONDITION (missing collection-group index on `timestamp`)
// on every single run since this function was first deployed, so nothing
// was ever actually deleted. Once the missing index was added, the first
// real run tried to load the entire multi-month backlog into memory at
// once and hit an OOM (258 MiB used against a 256 MiB limit). Processing
// in bounded pages, with a wall-clock budget per invocation, fixes both
// the immediate backlog and protects against this ever recurring --
// today's run clears what it can within the time budget, and whatever's
// left gets picked up by tomorrow's run.
export const deleteOldNotifications = onSchedule(
  "every day 02:00",
  async () => {
    const PAGE_SIZE = 300;
    const TIME_BUDGET_MS = 50_000; // leaves headroom under the 60s timeout
    const startedAt = Date.now();

    try {
      const thirtyDaysAgo = new Date();
      thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

      let totalDeleted = 0;
      let lastDoc: FirebaseFirestore.QueryDocumentSnapshot | undefined;

      while (Date.now() - startedAt < TIME_BUDGET_MS) {
        let query = admin
          .firestore()
          .collectionGroup("notifications")
          .where("timestamp", "<=", thirtyDaysAgo)
          .orderBy("timestamp")
          .limit(PAGE_SIZE);
        if (lastDoc) {
          query = query.startAfter(lastDoc);
        }

        const pageSnap = await query.get();
        if (pageSnap.empty) break;

        const batch = admin.firestore().batch();
        pageSnap.docs.forEach((doc) => batch.delete(doc.ref));
        await batch.commit();

        totalDeleted += pageSnap.size;
        lastDoc = pageSnap.docs[pageSnap.docs.length - 1];

        if (pageSnap.size < PAGE_SIZE) break; // last page was partial -- done
      }

      logger.info(`Deleted ${totalDeleted} old notifications.`);
    } catch (error) {
      logger.error("Error deleting old notifications:", error);
    }
  },
);

// Sends a daily summary at 8 PM UTC
export const sendDailySummary = onSchedule(
  "every day 20:00",
  async () => {
    try {
      const usersSnapshot = await admin.firestore().collection("users").get();
      const promises: Promise<unknown>[] = [];

      usersSnapshot.docs.forEach((doc) => {
        const userData = doc.data();
        if (!userData.fcmToken) return;
        // Respect user settings (defaults to true)
        if (userData.daily_summary_notifs === false) return;
        if (!isNotifsEnabled(userData)) return;

        // RoutineProvider._saveToCloud() writes 'habits' as
        // Map<habitId, bool> (habitId -> isCompleted) -- comparing the
        // habitId key against the boolean value can never be true, so
        // completedCount was always 0 regardless of actual completions,
        // and "Perfect Orbit Achieved!" never fired for anyone.
        const habits = userData.habits || {};
        let completedCount = 0;
        let totalCount = 0;

        for (const isCompleted of Object.values(habits)) {
          totalCount++;
          if (isCompleted === true) completedCount++;
        }

        // Only send if they had habits assigned today
        if (totalCount > 0) {
          const title = completedCount === totalCount ?
            "Perfect Orbit Achieved! 🌌" :
            "Daily Orbit Summary 🌠";
          const body = completedCount === totalCount ?
            `Incredible! You completed all ${totalCount} habits today.` :
            `You completed ${completedCount} out of ${totalCount} habits today.
            Ready to try again tomorrow?`;

          const payload = {notification: {title, body},
            android: {notification: {sound: "orbit_chime"}},
            apns: {payload: {aps: {sound: "orbit_chime.wav"}}},
            token: String(userData.fcmToken),
          };

          promises.push(
            admin.messaging().send(payload).catch((e) =>
              logger.error("FCM error", e))
          );
        }
      });

      await Promise.all(promises);
      logger.info(`Sent daily summaries to ${promises.length} users.`);
    } catch (error) {
      logger.error("Error sending daily summaries:", error);
    }
  }
);

// Triggered when a streak freeze is consumed
export const onFreezeConsumed = onDocumentUpdated(
  "users/{userId}",
  async (event) => {
    const beforeData = event.data?.before?.data();
    const afterData = event.data?.after?.data();

    if (!beforeData || !afterData) return;

    // Trigger when a freeze is actively consumed (isStreakFrozen flips to true)
    if (
      afterData.isStreakFrozen === true &&
      beforeData.isStreakFrozen !== true
    ) {
      const userId = event.params.userId;

      const title = "Streak Freeze Activated! ❄️";
      const body = "You missed a habit, but your Streak Freeze saved your " +
        "streak! Check in today to keep it going.";

      // Writing this doc is enough -- sendPushNotificationOnNewMessage
      // (this file, top) already fires on every create under
      // users/{userId}/notifications and sends the actual push, reading
      // 'screen' off the doc for tap routing. This function used to *also*
      // call admin.messaging().send() directly, so every freeze-consumed
      // event sent two near-identical pushes.
      await admin.firestore()
        .collection(`users/${userId}/notifications`)
        .add({
          title: title,
          body: body, // Named 'body' instead of 'message' to match the schema
          type: "system",
          screen: "profile",
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          isArchived: false,
        });
    }
  }
);

export const revenueCatWebhook = onRequest(async (req, res) => {
  // This endpoint sets isPro=true on whatever app_user_id the request body
  // names, trusting only this header — it was a hardcoded, git-committed
  // string, meaning anyone who ever saw this repo could forge
  // "INITIAL_PURCHASE" events and grant themselves free Pro. Now read from
  // the environment and hard-fail if unset, matching REVENUECAT_SECRET_KEY.
  const webhookSecret = process.env.RC_WEBHOOK_SECRET;
  if (!webhookSecret) {
    logger.error("RC_WEBHOOK_SECRET is not configured.");
    res.status(500).send("Server misconfigured");
    return;
  }

  // 🚀 EXTRACT THE HEADER VALUE FROM REVENUECAT
  const authHeader = req.headers.authorization;
  const expectedToken = `Bearer ${webhookSecret}`;

  // 🛡️ SECURITY GUARD CHECK
  if (!authHeader || authHeader !== expectedToken) {
    logger.error("❌ Unauthorized webhook access attempt blocked.");
    res.status(401).send("Unauthorized");
    return;
  }

  try {
    const event = req.body.event;
    if (!event) {
      res.status(400).send("No event found");
      return;
    }

    const uid = event.app_user_id;
    const eventType = event.type;

    const updateData: Record<string, unknown> = {};
    if (eventType === "INITIAL_PURCHASE" || eventType === "RENEWAL") {
      updateData.isPro = true;
      updateData.willRenew = true;
      updateData.retentionEmailSent = false; // Reset if they return
    } else if (eventType === "CANCELLATION") {
      updateData.willRenew = false;
    } else if (eventType === "EXPIRATION") {
      updateData.isPro = false;
      updateData.willRenew = false;
    }

    if (event.expiration_at_ms) {
      updateData.proExpirationDate = admin.firestore.Timestamp
        .fromMillis(event.expiration_at_ms);
    }

    if (Object.keys(updateData).length > 0 && uid) {
      await admin.firestore().collection("users").doc(uid)
        .set(updateData, {merge: true});
    }

    // NEW: Queue the Welcome Email via Firebase Extension
    if (eventType === "INITIAL_PURCHASE" && uid) {
      try {
        const userRecord = await admin.auth().getUser(uid);
        const email = userRecord.email;
        if (email) {
          await admin.firestore().collection("mail").add({
            to: email,
            message: {
              subject: "Welcome to Orbit Pro! 🚀",
              html: [
                "<div style=\"font-family: sans-serif; max-width: 600px; ",
                "margin: 0 auto; padding: 24px; background-color: #050112; ",
                "color: #ffffff; border-radius: 16px;\">",
                "<div style=\"text-align: center; margin-bottom: 20px;\">",
                "<h2 style=\"color: #ffffff;\">🌌 Orbit</h2></div>",
                "<h1 style=\"color: #00E5FF; text-align: center;\">",
                "Welcome to Orbit Pro! 🚀</h1>",
                "<p style=\"font-size: 16px; line-height: 1.6;\">",
                "Thank you for upgrading! Your journey to mastering your ",
                "habits and unlocking your full potential begins now.</p>",
                "<p style=\"font-size: 16px;\">Keep your momentum going!</p>",
                "<div style=\"text-align: center; margin-top: 32px;\">",
                "<a href=\"https://orbitroutine.com\" style=\"background-color: ",
                "#00E5FF; color: #000; padding: 14px 28px; ",
                "text-decoration: none; font-weight: bold; ",
                "border-radius: 12px; display: inline-block;\">",
                "Launch Orbit</a>",
                "</div></div>",
              ].join(""),
            },
          });
          logger.info(`Welcome email successfully queued for: ${email}`);
        }
      } catch (e) {
        logger.error("Error fetching user email for webhook:", e);
      }
    }

    // NEW: Queue the Billing Issue Email
    if (eventType === "BILLING_ISSUE" && uid) {
      try {
        const userRecord = await admin.auth().getUser(uid);
        const email = userRecord.email;
        if (email) {
          await admin.firestore().collection("mail").add({
            to: email,
            message: {
              subject: "Action Required: Orbit Pro Billing Issue",
              html: [
                "<div style=\"font-family: sans-serif; max-width: 600px; ",
                "margin: 0 auto; padding: 24px; background-color: #050112; ",
                "color: #ffffff; border-radius: 16px;\">",
                "<h2 style=\"color: #FF5252; text-align: center;\">",
                "Orbit Pro Renewal Failed</h2>",
                "<p style=\"font-size: 16px; line-height: 1.6;\">We tried ",
                "to renew your Orbit Pro subscription, but the payment ",
                "failed. To keep your streak and Pro features active, ",
                "please update your payment method in your device ",
                "settings.</p>",
                "</div>",
              ].join(""),
            },
          });
          logger.info(`Billing issue email successfully queued for: ${email}`);
        }
      } catch (e) {
        logger.error(
          "Error fetching user email for billing issue webhook:",
          e,
        );
      }
    }

    // NEW: Queue the Cancellation Email
    if (eventType === "CANCELLATION" && uid) {
      try {
        const userRecord = await admin.auth().getUser(uid);
        const email = userRecord.email;
        if (email) {
          await admin.firestore().collection("mail").add({
            to: email,
            message: {
              subject: "Sorry to see you go - Orbit Pro",
              html: [
                "<div style=\"font-family: sans-serif; max-width: 600px; ",
                "margin: 0 auto; padding: 24px; background-color: #050112; ",
                "color: #ffffff; border-radius: 16px;\">",
                "<h2 style=\"color: #00E5FF; text-align: center;\">",
                "We'll miss you in Orbit!</h2>",
                "<p style=\"font-size: 16px; line-height: 1.6;\">",
                "Your Orbit Pro subscription has been cancelled. ",
                "You will continue to have access to all Pro features until ",
                "the end of your current billing period.</p>",
                "<p style=\"font-size: 16px;\">",
                "We hope to see you back soon!</p>",
                "</div>",
              ].join(""),
            },
          });
          logger.info(`Cancellation email successfully queued for: ${email}`);
        }
      } catch (e) {
        logger.error(
          "Error fetching user email for cancellation webhook:",
          e,
        );
      }
    }

    res.status(200).send("Webhook processed successfully");
  } catch (error) {
    logger.error("Webhook error:", error);
    res.status(500).send("Internal Server Error");
  }
});

export const redeemReferralCode = onCall(async (request) => {
  // Ensure the user calling this is authenticated
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "Must be logged in to redeem a code."
    );
  }

  const refereeUid = request.auth.uid;
  const referralCode = request.data.code;

  if (!referralCode || typeof referralCode !== "string" ||
      referralCode.length < 6) {
    throw new HttpsError(
      "invalid-argument",
      "Invalid referral code provided.",
    );
  }

  // For simplicity, find the referrer by checking if UID prefix matches code
  const usersRef = admin.firestore().collection("users");
  const snapshot = await usersRef.get();
  let referrerUid: string | null = null;
  snapshot.docs.forEach((doc) => {
    if (doc.id.substring(0, 6).toUpperCase() === referralCode.toUpperCase()) {
      referrerUid = doc.id;
    }
  });

  if (!referrerUid || referrerUid === refereeUid) {
    throw new HttpsError("not-found", "Referral code not found or invalid.");
  }

  // Reserve the redemption transactionally before granting anything --
  // without this, nothing stopped a user from calling this callable
  // repeatedly with any valid code and stacking unlimited free 30-day Pro
  // grants for themselves (and their referrer) every time.
  const refereeRef = admin.firestore().collection("users").doc(refereeUid);
  await admin.firestore().runTransaction(async (transaction) => {
    const refereeDoc = await transaction.get(refereeRef);
    if (refereeDoc.exists && refereeDoc.data()?.referredBy) {
      throw new HttpsError(
        "already-exists",
        "You've already redeemed a referral code."
      );
    }
    transaction.set(
      refereeRef,
      {referredBy: referrerUid},
      {merge: true}
    );
  });

  const REVENUECAT_SECRET = process.env.REVENUECAT_SECRET_KEY;
  if (!REVENUECAT_SECRET) {
    throw new HttpsError(
      "failed-precondition",
      "RevenueCat secret key is not configured."
    );
  }
  // Must match the entitlement identifier in RevenueCat — the app checks
  // "Orbit Pro" everywhere (paywall, premium gates, webhook).
  const ENTITLEMENT_ID = "Orbit Pro";

  const grantPro = async (uid: string) => {
    const url = `https://api.revenuecat.com/v1/subscribers/${uid}` +
      `/entitlements/${encodeURIComponent(ENTITLEMENT_ID)}/promotional`;
    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${REVENUECAT_SECRET}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({duration: "monthly"}), // Grants exactly 30 days
    });
    const body = await response.json();
    // RevenueCat returns a valid JSON body on 4xx/5xx too (an error object,
    // not a thrown exception), so this previously reported success back to
    // the client even when nothing was actually granted.
    if (!response.ok) {
      throw new Error(
        `RevenueCat grant failed for ${uid}: ${response.status} ` +
        `${JSON.stringify(body)}`
      );
    }
    return body;
  };

  try {
    // Grant PRO status to both the inviter and the invitee!
    await grantPro(refereeUid);
    await grantPro(referrerUid);

    // Alert the referrer that their code was successfully used
    await admin.firestore()
      .collection(`users/${referrerUid}/notifications`)
      .add({
        title: "Referral Successful! 🎉",
        body: "A friend used your invite code. " +
            "You earned 30 Days of Orbit Pro!",
        type: "system",
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        isArchived: false,
      });

    return {success: true, message: "30 Days of Pro unlocked!"};
  } catch (error) {
    logger.error("RC API Error:", error);
    // The redemption was already reserved transactionally above (to block
    // replay) before either grant was attempted -- if the grant itself
    // failed, roll that reservation back so the user isn't permanently
    // locked out of ever redeeming a code just because RevenueCat had a
    // transient failure.
    await refereeRef.update({
      referredBy: admin.firestore.FieldValue.delete(),
    }).catch((e) => logger.error("Failed to roll back referredBy:", e));
    throw new HttpsError("internal", "Failed to communicate with RevenueCat.");
  }
});

export const buyStreakFreeze = onCall(async (request) => {
  // Ensure the user calling this is authenticated
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "Must be logged in to purchase items."
    );
  }

  const uid = request.auth.uid;
  const userRef = admin.firestore().collection("users").doc(uid);

  return admin.firestore().runTransaction(async (transaction) => {
    const userDoc = await transaction.get(userRef);
    if (!userDoc.exists) {
      throw new HttpsError("not-found", "User profile not found.");
    }

    const currentXp = userDoc.data()?.xp || 0;
    const cost = 200; // Orbit Store cost

    if (currentXp < cost) {
      throw new HttpsError(
        "failed-precondition",
        "Not enough XP to purchase this item."
      );
    }

    transaction.update(userRef, {
      xp: admin.firestore.FieldValue.increment(-cost),
      streakFreezes: admin.firestore.FieldValue.increment(1),
    });

    // Return the updated state so the client Dart code can resolve the Future
    return {success: true, newXp: currentXp - cost};
  });
});

// Costs must match lib/theme/nebula_themes.dart's NebulaThemes.all — kept
// server-side too so a client can't grant itself a theme by editing local
// state (unlocked_themes is a client-writable field in firestore.rules).
const NEBULA_THEME_COSTS: Record<string, number> = {
  "Aurora": 500,
  "Solstice": 500,
};

export const unlockNebulaTheme = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "Must be logged in to purchase items."
    );
  }

  const theme = request.data?.theme;
  const cost = NEBULA_THEME_COSTS[theme];
  if (typeof theme !== "string" || !cost) {
    throw new HttpsError("invalid-argument", "Unknown nebula theme.");
  }

  const uid = request.auth.uid;
  const userRef = admin.firestore().collection("users").doc(uid);

  return admin.firestore().runTransaction(async (transaction) => {
    const userDoc = await transaction.get(userRef);
    if (!userDoc.exists) {
      throw new HttpsError("not-found", "User profile not found.");
    }

    const currentXp = userDoc.data()?.xp || 0;
    const unlocked: string[] = userDoc.data()?.unlocked_themes || ["Default"];

    if (unlocked.includes(theme)) {
      return {success: true, newXp: currentXp};
    }

    if (currentXp < cost) {
      throw new HttpsError(
        "failed-precondition",
        "Not enough XP to purchase this item."
      );
    }

    transaction.update(userRef, {
      xp: admin.firestore.FieldValue.increment(-cost),
      unlocked_themes: admin.firestore.FieldValue.arrayUnion(theme),
    });

    return {success: true, newXp: currentXp - cost};
  });
});

export const linkPartner = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "Must be logged in to link a partner."
    );
  }

  const userAUid = request.auth.uid;
  const partnerCode = request.data.code;

  if (!partnerCode || typeof partnerCode !== "string" ||
      partnerCode.length < 6) {
    throw new HttpsError("invalid-argument", "Invalid partner code provided.");
  }

  // Same "match the code against a UID prefix" approach as
  // redeemReferralCode — done server-side because firestore.rules only
  // allows a user to read their own document, so a client-side scan of
  // the whole users collection is always denied.
  const usersRef = admin.firestore().collection("users");
  const snapshot = await usersRef.get();
  let userBUid: string | null = null;
  snapshot.docs.forEach((doc) => {
    if (doc.id.substring(0, 6).toUpperCase() === partnerCode.toUpperCase()) {
      userBUid = doc.id;
    }
  });

  if (!userBUid || userBUid === userAUid) {
    throw new HttpsError("not-found", "Partner code not found or invalid.");
  }

  // notifyPartnerOnHabitComplete only ever reads the first matching link
  // doc for a user, so the app's model is one partner at a time. The old
  // check here only looked for an existing link with this *specific*
  // partner, not whether either side already had *any* partner at all —
  // so a user could accumulate multiple ambiguous `links` docs. Checking
  // and writing inside a transaction also closes the race where two
  // concurrent calls both pass the "not already linked" check.
  const linksRef = admin.firestore().collection("links");
  await admin.firestore().runTransaction(async (transaction) => {
    const aAsA = await transaction.get(
      linksRef.where("userA", "==", userAUid)
    );
    const aAsB = await transaction.get(
      linksRef.where("userB", "==", userAUid)
    );
    if (!aAsA.empty || !aAsB.empty) {
      throw new HttpsError(
        "already-exists",
        "You're already linked with a partner."
      );
    }
    const bAsA = await transaction.get(
      linksRef.where("userA", "==", userBUid)
    );
    const bAsB = await transaction.get(
      linksRef.where("userB", "==", userBUid)
    );
    if (!bAsA.empty || !bAsB.empty) {
      throw new HttpsError(
        "already-exists",
        "That user is already linked with a partner."
      );
    }

    transaction.set(linksRef.doc(), {
      userA: userAUid,
      userB: userBUid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      sharedXP: 0,
    });
  });

  return {success: true, message: "Successfully linked orbits!"};
});

// Lets a user search for others to friend by display name, without
// exposing a raw client-side query over the whole users collection —
// firestore.rules only allows a user to read their own document (see the
// leaderboard fix below for why: freely-editable display names exposed to
// strangers with no report/block mechanism is an App Store Guideline 1.2
// risk), so this runs the query server-side via the Admin SDK and returns
// only the minimal public-safe fields a friend-search result needs.
export const searchUsers = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be logged in to search.");
  }

  const query = request.data.query;
  if (
    !query || typeof query !== "string" ||
    query.trim().length === 0 || query.length > 60
  ) {
    return {results: []};
  }

  // 'name' is the field the app actually shows and lets users edit
  // (profile_screen.dart, leaderboard_screen.dart, Settings' profile
  // editor) -- 'displayName' is a separate field _saveToCloud() overwrites
  // on every save with FirebaseAuth's own displayName property (usually
  // null, falling back to "Commander"), so querying it here would return
  // the wrong name for most users even though the query itself succeeds.
  const snapshot = await admin.firestore()
    .collection("users")
    .where("name", ">=", query)
    .where("name", "<=", query + "\uf8ff")
    .limit(20)
    .get();

  const results = snapshot.docs
    .filter((doc) => doc.id !== request.auth?.uid)
    .map((doc) => {
      const data = doc.data();
      return {
        uid: doc.id,
        displayName: data.name || "Unknown",
        // 'xp' is RoutineProvider's spendable currency (decreases when a
        // user buys streak freezes/themes) -- leaderboard_screen.dart was
        // already fixed to rank/display 'global_xp' instead for this exact
        // reason. This callable backs add_friend_screen.dart's search
        // results, which show this value as "$xp XP" under each user, so
        // it needs the same fix.
        xp: data.global_xp || 0,
      };
    });

  return {results};
});

// The client has no way to see the effect of linkPartner()'s work — no
// screen ever reads the 'links' collection (blocked outright by
// firestore.rules' default-deny, same reason linkPartner itself needed
// to move server-side) or shows the sharedXP the notifyPartnerOnHabitComplete
// trigger has been quietly accumulating. This surfaces it.
export const getPartnerInfo = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be logged in.");
  }

  const uid = request.auth.uid;
  const db = admin.firestore();

  const linksAsA = await db.collection("links")
    .where("userA", "==", uid).limit(1).get();
  const linksAsB = await db.collection("links")
    .where("userB", "==", uid).limit(1).get();

  let linkDoc = null;
  let partnerUid: string | null = null;
  if (!linksAsA.empty) {
    linkDoc = linksAsA.docs[0];
    partnerUid = linkDoc.data().userB;
  } else if (!linksAsB.empty) {
    linkDoc = linksAsB.docs[0];
    partnerUid = linkDoc.data().userA;
  }

  if (!linkDoc || !partnerUid) {
    return {linked: false};
  }

  const partnerDoc = await db.collection("users").doc(partnerUid).get();
  const partnerData = partnerDoc.data() || {};

  return {
    linked: true,
    partnerName: partnerData.name || "Your Partner",
    partnerStreak: partnerData.current_streak || 0,
    sharedXP: linkDoc.data().sharedXP || 0,
  };
});

// There has never been a way to remove a friend — the mutual friends[]
// arrays can only be written server-side (same isOwner-only reasoning as
// notifyOnFriendRequestAccepted's add path), and nothing calls a
// removal equivalent.
export const removeFriend = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be logged in.");
  }

  const friendUid = request.data?.friendUid;
  if (!friendUid || typeof friendUid !== "string") {
    throw new HttpsError("invalid-argument", "Missing friendUid.");
  }

  const uid = request.auth.uid;
  const db = admin.firestore();
  const batch = db.batch();
  batch.update(db.collection("users").doc(uid), {
    friends: admin.firestore.FieldValue.arrayRemove(friendUid),
  });
  batch.update(db.collection("users").doc(friendUid), {
    friends: admin.firestore.FieldValue.arrayRemove(uid),
  });
  await batch.commit();

  return {success: true};
});

// Creates a Group Challenge (a time-boxed shared commitment among mutual
// friends -- see lib/models/challenge.dart). Server-side because it needs
// to verify every invitee is actually a mutual friend of the creator by
// reading the creator's own `friends` array, something firestore.rules
// can't cheaply check against a document being newly created (there's no
// `resource.data` yet to compare against, and rules can't easily assert
// "every element of this array is present in that other document's array"
// without per-element get() calls) -- same reasoning as linkPartner/
// removeFriend already being callables rather than direct client writes.
export const createChallenge = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "Must be logged in to create a challenge."
    );
  }

  const uid = request.auth.uid;
  const title = request.data?.title;
  const goal = request.data?.goal;
  const durationDays = request.data?.durationDays;
  const inviteeUids = request.data?.inviteeUids;

  if (
    !title ||
    typeof title !== "string" ||
    title.trim().length === 0 ||
    title.length > 100
  ) {
    throw new HttpsError("invalid-argument", "Invalid title.");
  }
  if (goal !== undefined && goal !== null &&
      (typeof goal !== "string" || goal.length > 300)) {
    throw new HttpsError("invalid-argument", "Invalid goal.");
  }
  if (![7, 14, 30].includes(durationDays)) {
    throw new HttpsError("invalid-argument", "Invalid duration.");
  }
  if (
    !Array.isArray(inviteeUids) ||
    inviteeUids.length === 0 ||
    inviteeUids.length > 9 ||
    inviteeUids.some((id: unknown) => typeof id !== "string")
  ) {
    throw new HttpsError(
      "invalid-argument",
      "Invite between 1 and 9 friends."
    );
  }

  // Only allow inviting mutual friends -- read the creator's own doc
  // (never another user's, keeping this consistent with firestore.rules'
  // owner-only read model) and verify every invitee is already in it.
  const creatorSnap = await admin
    .firestore()
    .collection("users")
    .doc(uid)
    .get();
  const friends: string[] = creatorSnap.data()?.friends ?? [];
  const hasStranger = inviteeUids.some(
    (id: string) => !friends.includes(id)
  );
  if (hasStranger) {
    throw new HttpsError(
      "permission-denied",
      "You can only invite mutual friends."
    );
  }

  const participantIds = Array.from(new Set([uid, ...inviteeUids]));
  const now = admin.firestore.Timestamp.now();
  const endDate = admin.firestore.Timestamp.fromMillis(
    now.toMillis() + durationDays * 24 * 60 * 60 * 1000
  );

  const challengeRef = admin.firestore().collection("challenges").doc();
  await challengeRef.set({
    creatorId: uid,
    title: title.trim(),
    goal: (goal ?? "").trim(),
    participantIds,
    startDate: now,
    endDate,
    createdAt: now,
  });

  return {success: true, challengeId: challengeRef.id};
});

// Cleans up guest accounts that are older than 30 days
export const deleteOrphanedGuestAccounts = onSchedule(
  "every day 03:00",
  async () => {
    try {
      const thirtyDaysAgo = new Date();
      thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

      // createdAt alone previously decided deletion -- a guest who kept
      // using the app daily past the 30-day mark, without ever linking to
      // a permanent account, got their Firestore data AND Firebase Auth
      // user silently deleted out from under them the next time this ran,
      // mid-session, with no warning (surfaced as permission-denied errors
      // on their very next write once their session was invalidated).
      // lastActiveAt (stamped on every app boot/sign-in, see main.dart) is
      // filtered in-memory below rather than as a second query clause so
      // pre-migration accounts that never got a lastActiveAt stamp still
      // fall back to createdAt instead of silently never matching.
      const candidatesSnap = await admin
        .firestore()
        .collection("users")
        .where("isGuest", "==", true)
        .where("createdAt", "<=", thirtyDaysAgo)
        .get();

      const orphanedGuestDocs = candidatesSnap.docs.filter((doc) => {
        const lastActiveAt = doc.data().lastActiveAt ?? doc.data().createdAt;
        return lastActiveAt.toMillis() <= thirtyDaysAgo.getTime();
      });

      if (orphanedGuestDocs.length === 0) {
        logger.info("No orphaned guest accounts to delete.");
        return;
      }

      let currentBatch = admin.firestore().batch();
      const batches: typeof currentBatch[] = [];
      let operationCount = 0;

      // Must cover every subcollection under users/{userId} (see the
      // `match` blocks in firestore.rules) -- this previously missed
      // journal_entries, cache, fairy_history, and skipped_sessions, the
      // same gap already fixed for cleanupUserAccount and the guest->
      // permanent account migration.
      const subcollections = [
        "habits",
        "notifications",
        "friend_requests",
        "coaching_notes",
        "journal_entries",
        "cache",
        "fairy_history",
        "skipped_sessions",
      ];

      for (const doc of orphanedGuestDocs) {
        // Read all subcollections for this doc in parallel instead of one
        // await per subcollection -- this loop already runs once daily
        // against every guest account 30+ days old, so runtime scaled
        // linearly with both orphaned-guest count and subcollection count.
        const subSnaps = await Promise.all(
          subcollections.map((subcollection) =>
            doc.ref.collection(subcollection).get()
          )
        );
        for (const subSnap of subSnaps) {
          subSnap.docs.forEach((subDoc) => {
            currentBatch.delete(subDoc.ref);
            operationCount++;
            if (operationCount === 499) {
              batches.push(currentBatch);
              currentBatch = admin.firestore().batch();
              operationCount = 0;
            }
          });
        }

        // Delete the main user document
        currentBatch.delete(doc.ref);
        operationCount++;
      }

      if (operationCount > 0) batches.push(currentBatch);

      await Promise.all(batches.map((batch) => batch.commit()));

      // Delete the Firebase Auth accounts in parallel, after the Firestore
      // data is gone (avoids the previous ordering, where an Auth account
      // could be deleted before its Firestore batches had even started
      // committing).
      await Promise.all(
        orphanedGuestDocs.map((doc) =>
          admin.auth().deleteUser(doc.id).catch((e) =>
            logger.error(`Failed to delete auth for ${doc.id}`, e)
          )
        )
      );

      logger.info(
        `Deleted ${orphanedGuestDocs.length} orphaned guest accounts.`
      );
    } catch (error) {
      logger.error("Error deleting orphaned guest accounts:", error);
    }
  }
);

// Sends an automated retention email 3 days before a cancelled
// subscription expires
export const sendRetentionEmails = onSchedule(
  "every day 14:00", // Runs daily at 2:00 PM UTC
  async () => {
    try {
      const usersSnap = await admin.firestore().collection("users")
        .where("isPro", "==", true)
        .where("willRenew", "==", false)
        .get();

      const now = Date.now();
      const threeDaysMs = 3 * 24 * 60 * 60 * 1000;
      let currentBatch = admin.firestore().batch();
      let operationCount = 0;
      const batches: typeof currentBatch[] = [];

      for (const doc of usersSnap.docs) {
        const data = doc.data();
        if (data.retentionEmailSent) continue;
        if (!data.proExpirationDate) continue;

        const expirationTime = data.proExpirationDate.toMillis();
        const timeUntilExpiration = expirationTime - now;

        // If expiring in exactly 3 days (or less, but greater than 0)
        if (timeUntilExpiration > 0 && timeUntilExpiration <= threeDaysMs) {
          try {
            const userRecord = await admin.auth().getUser(doc.id);
            if (userRecord.email) {
              const mailRef = admin.firestore().collection("mail").doc();
              currentBatch.set(mailRef, {
                to: userRecord.email,
                message: {
                  subject: "Don't lose your Orbit Pro streak! 🎁",
                  html: [
                    "<div style=\"font-family: sans-serif; ",
                    "max-width: 600px; margin: 0 auto; padding: 24px; ",
                    "background-color: #050112; ",
                    "color: #ffffff; border-radius: 16px;\">",
                    "<h2 style=\"color: #00E5FF; text-align: center;\">",
                    "Special offer to stay in Orbit!</h2>",
                    "<p style=\"font-size: 16px; line-height: 1.6;\">",
                    "Your Orbit Pro subscription will expire in 3 days! ",
                    "We'd love to keep you on board. Use the promo code ",
                    "<strong>STAY50</strong> in the app to claim a 50% ",
                    "discount on your next month!</p>",
                    "</div>",
                  ].join(""),
                },
              });

              currentBatch.update(doc.ref, {retentionEmailSent: true});
              operationCount += 2;

              if (operationCount >= 498) {
                batches.push(currentBatch);
                currentBatch = admin.firestore().batch();
                operationCount = 0;
              }
            }
          } catch (authErr) {
            logger.error(`Could not fetch email for ${doc.id}`, authErr);
          }
        }
      }

      if (operationCount > 0) batches.push(currentBatch);
      await Promise.all(batches.map((batch) => batch.commit()));
      logger.info(`Processed ${batches.length} batches for retention emails.`);
    } catch (error) {
      logger.error("Error sending retention emails:", error);
    }
  }
);

// Manages inactive accounts: Warns at 358 days, deletes at 365 days
export const manageInactiveAccounts = onSchedule(
  "every day 04:00",
  async () => {
    const now = Date.now();
    const oneYearMs = 365 * 24 * 60 * 60 * 1000;
    const warningMs = 358 * 24 * 60 * 60 * 1000; // 7 days before
    const threeDaysMs = 3 * 24 * 60 * 60 * 1000; // 3 days inactive
    const oneDayMs = 24 * 60 * 60 * 1000;

    try {
      let nextPageToken: string | undefined;
      let deletedCount = 0;
      let warningCount = 0;
      let reengagedCount = 0;

      do {
        const listUsersResult = await admin.auth()
          .listUsers(1000, nextPageToken);

        for (const userRecord of listUsersResult.users) {
          const lastSignInStr = userRecord.metadata.lastSignInTime;
          if (!lastSignInStr) continue;

          const lastSignIn = new Date(lastSignInStr).getTime();
          const timeInactive = now - lastSignIn;

          // 1. Delete if inactive for >= 1 year
          if (timeInactive >= oneYearMs) {
            try {
              // lastSignInTime is a Firebase Auth concept -- it has nothing
              // to do with whether an Apple/Google subscription is still
              // active and auto-renewing (RevenueCat billing is entirely
              // independent of Firebase Auth activity). Without this check,
              // a paying Pro subscriber who simply hadn't opened the app in
              // a year got their Firebase Auth user AND all their Firestore
              // data (via cleanupUserAccount's onDelete trigger) permanently
              // deleted while still being billed, with no way back in under
              // that identity.
              const userDoc = await admin.firestore()
                .collection("users").doc(userRecord.uid).get();
              if (userDoc.data()?.isPro === true) {
                continue;
              }

              await admin.auth().deleteUser(userRecord.uid);
              deletedCount++;

              if (userRecord.email) {
                await admin.firestore().collection("mail").add({
                  to: userRecord.email,
                  message: {
                    subject: "Your Orbit Account Has Been Deleted",
                    html: [
                      "<div style=\"font-family: sans-serif; ",
                      "max-width: 600px; margin: 0 auto; padding: 24px; ",
                      "background-color: #050112; ",
                      "color: #ffffff; border-radius: 16px;\">",
                      "<h2 style=\"color: #FF5252; text-align: center;\">",
                      "Account Deleted</h2>",
                      "<p style=\"font-size: 16px; line-height: 1.6;\">",
                      "As per our inactivity policy, your Orbit account ",
                      "has been permanently ",
                      "deleted after 365 days of inactivity.</p>",
                      "<p style=\"font-size: 16px;\">",
                      "We're sorry to see you go! If you ever want to ",
                      "build healthy habits again, ",
                      "you can always create a new account.</p>",
                      "</div>",
                    ].join(""),
                  },
                });
              }
            } catch (e) {
              logger.error(`Error deleting user ${userRecord.uid}`, e);
            }
          } else if (
            // 2. Warn if inactive for exactly 358 days (between 358 and 359)
            timeInactive >= warningMs &&
            timeInactive < warningMs + oneDayMs
          ) {
            if (userRecord.email) {
              // Random per-send token, not the guessable/enumerable uid --
              // trackEmailOpen requires this to match before it'll write
              // anything, so a forged request against an arbitrary uid
              // can't poison that user's document.
              const trackingToken = crypto.randomBytes(16).toString("hex");
              await admin.firestore().collection("users")
                .doc(userRecord.uid)
                .set({emailTrackingToken: trackingToken}, {merge: true});

              await admin.firestore().collection("mail").add({
                to: userRecord.email,
                message: {
                  subject: "Action Required: Your Orbit account will be " +
                    "deleted soon",
                  html: [
                    "<div style=\"font-family: sans-serif; ",
                    "max-width: 600px; margin: 0 auto; padding: 24px; ",
                    "background-color: #050112; ",
                    "color: #ffffff; border-radius: 16px;\">",
                    "<h2 style=\"color: #FF5252; text-align: center;\">",
                    "Account Deletion Warning</h2>",
                    "<p style=\"font-size: 16px; line-height: 1.6;\">",
                    "We noticed you haven't logged into Orbit in almost ",
                    "a year. ",
                    "To protect your privacy and free up space, your account ",
                    "and all associated data will be permanently deleted ",
                    "in 7 days.</p>",
                    "<p style=\"font-size: 16px;\">",
                    "If you'd like to keep your account, simply open the ",
                    "Orbit app and log in before the deadline!</p>",
                    "<div style=\"text-align: center; margin-top: 32px;\">",
                    "<img src=\"https://europe-west1-",
                    `${process.env.GCLOUD_PROJECT}.cloudfunctions.net/`,
                    `trackEmailOpen?uid=${userRecord.uid}` +
                    `&token=${trackingToken}" `,
                    "width=\"1\" height=\"1\" style=\"display:none;\" />",
                    "</div>",
                  ].join(""),
                },
              });
              warningCount++;
            }
          } else if (
            // 3. Re-engage if inactive for exactly 3 days
            timeInactive >= threeDaysMs &&
            timeInactive < threeDaysMs + oneDayMs
          ) {
            const userDoc = await admin.firestore().collection("users")
              .doc(userRecord.uid).get();
            const fcmToken = userDoc.data()?.fcmToken;

            if (fcmToken && isNotifsEnabled(userDoc.data())) {
              const payload = {
                notification: {
                  title: "We miss you in Orbit! 🚀",
                  body: "It's been 3 days since your last orbit. " +
                    "Tap here to launch the app and keep your momentum going!",
                },
                android: {notification: {sound: "orbit_chime"}},
                apns: {payload: {aps: {sound: "orbit_chime.wav"}}},
                data: {screen: "dashboard"},
                token: String(fcmToken),
              };

              try {
                await admin.messaging().send(payload);
                reengagedCount++;
              } catch (e) {
                logger.error(
                  `Error sending 3-day push to ${userRecord.uid}:`, e
                );
              }
            }
          }
        }
        nextPageToken = listUsersResult.pageToken;
      } while (nextPageToken);

      logger.info(
        `Deleted ${deletedCount} users. Warned ${warningCount} users. ` +
        `Re-engaged ${reengagedCount} users.`
      );
    } catch (error) {
      logger.error("Error deleting inactive users:", error);
    }
  }
);

export const trackEmailOpen = onRequest(async (req, res) => {
  const uid = req.query.uid as string;
  const token = req.query.token as string;

  // uid is guessable/enumerable (e.g. via searchUsers), so without a
  // per-send secret token check anyone could hit this endpoint for an
  // arbitrary uid and write to that user's document.
  if (uid && token) {
    try {
      const userDoc = await admin.firestore().collection("users")
        .doc(uid).get();
      const expectedToken = userDoc.data()?.emailTrackingToken as
        string | undefined;

      const providedBuf = Buffer.from(token);
      const expectedBuf = Buffer.from(expectedToken ?? "");
      const tokenMatches = expectedToken !== undefined &&
        providedBuf.length === expectedBuf.length &&
        crypto.timingSafeEqual(providedBuf, expectedBuf);

      if (tokenMatches) {
        await admin.firestore().collection("users").doc(uid).set({
          hasReadWarningEmail: true,
          warningEmailOpenedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {merge: true});
        logger.info(`Email open tracked for user: ${uid}`);
      } else {
        logger.warn(`Rejected trackEmailOpen: bad token for uid ${uid}`);
      }
    } catch (error) {
      logger.error(`Error tracking email open for user ${uid}:`, error);
    }
  }

  // A standard 1x1 transparent GIF encoded in base64
  const pixel = Buffer.from(
    "R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7",
    "base64"
  );

  res.set("Content-Type", "image/gif");
  res.set("Cache-Control", "no-store, no-cache, must-revalidate, private");
  res.status(200).send(pixel);
});
// import {setGlobalOptions
// import * as logger from "firebase-functions/logger";

// Start writing functions
// https://firebase.google.com/docs/functions/typescript

// For cost control, you can set the maximum number of containers that can be
// running at the same time. This helps mitigate the impact of unexpected
// traffic spikes by instead downgrading performance. This limit is a
// per-function limit. You can override the limit for each function using the
// `maxInstances` option in the function's options, e.g.
// `onRequest({ maxInstances: 5 }, (req, res) => { ... })`.
// NOTE: setGlobalOptions does not apply to functions using the v1 API. V1
// functions should each use functions.runWith({ maxInstances: 10 }) instead.
// In the v1 API, each function can only serve one request per container, so
// this will be the maximum concurrent request count.
// setGlobalOptions({ maxInstances: 10 });

// export const helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });
