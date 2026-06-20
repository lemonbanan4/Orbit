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
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import * as functions from "firebase-functions/v1";
import {setGlobalOptions} from "firebase-functions/v2";

admin.initializeApp();

// Set all v2 functions to deploy to Europe (matching your eur3 Firestore)
setGlobalOptions({region: "europe-west1"});

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
        screen: "notifications", // app to route the user to the Inbox screen
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
      const fcmToken = afterData.fcmToken;

      const newMilestones = afterMilestones.filter(
        (m: string) => !beforeMilestones.includes(m)
      );
      let bodyText =
        "You just reached a new milestone. Keep up the great work!";
      if (newMilestones.length > 0) {
        bodyText =
          `You've unlocked: ${newMilestones[0]}. Keep up the great work!`;
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

      if (!fcmToken) return;

      const payload = {
        notification: {
          title: "Milestone Unlocked! 🌟",
          body: bodyText,
        },
        android: {
          notification: {sound: "orbit_chime"},
        },
        apns: {
          payload: {aps: {sound: "orbit_chime.wav"}},
        },
        data: {
          screen: "path_detail",
          type: "milestone", // Routes per logic in main.dart
        },
        token: String(fcmToken),
      };

      try {
        await admin.messaging().send(payload);
        logger.info(`Milestone notification sent to user ${userId}`);
      } catch (error) {
        logger.error("Error sending milestone notification:", error);
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

      // 1. Fetch the user who accepted the request
      const targetUserDoc =
        await admin.firestore()
          .collection("users")
          .doc(targetUserId).get();
      const acceptorName =
        targetUserDoc.data()?.displayName || "A user";

      // 2. Fetch the sender to get their FCM token
      const senderDoc = await admin
        .firestore()
        .collection("users")
        .doc(senderId).get();

      const senderData = senderDoc.data();

      if (!senderData || !senderData.fcmToken) return;

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

    const nameA = userADoc.data()?.displayName || "A fellow astronaut";
    const tokenB = userBDoc.data()?.fcmToken;

    if (tokenB) {
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
export const resetWeeklyProgress = onSchedule(
  "every sunday 00:00",
  async () => {
    try {
      const usersSnapshot = await admin.firestore().collection("users").get();

      // Firestore batches can only handle 500 operations at a time
      let currentBatch = admin.firestore().batch();
      const batches: typeof currentBatch[] = [];
      let operationCount = 0;

      usersSnapshot.docs.forEach((doc) => {
        // Example: Reset weekly-specific fields
        // (Customize these to match your exact DB fields)
        currentBatch.update(doc.ref, {
          weeklyProgress: 0,
          weeklyXp: 0,
        });
        operationCount++;

        if (operationCount === 499) {
          batches.push(currentBatch);
          currentBatch = admin.firestore().batch();
          operationCount = 0;
        }
      });

      if (operationCount > 0) {
        batches.push(currentBatch);
      }

      await Promise.all(batches.map((batch) => batch.commit()));
      logger.info(
        `Successfully reset weekly progress for ${usersSnapshot.size} users.`,
      );
    } catch (error) {
      logger.error("Error resetting weekly progress:", error);
    }
  },
);

// Triggered automatically when a user deletes their Firebase Auth account
export const cleanupUserAccount = functions
  .region("europe-west1")
  .auth.user()
  .onDelete(async (user) => {
    const userId = user.uid;
    try {
      const userRef = admin.firestore().collection("users").doc(userId);

      // 1. Delete known subcollections to avoid orphaned documents
      const subcollections = ["habits", "notifications", "friend_requests"];
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

      // 2. Delete the main user document
      await userRef.delete();
      logger.info(`Successfully deleted data for user: ${userId}`);
    } catch (error) {
      logger.error(`Error deleting data for user ${userId}:`, error);
    }
  });

// Cleans up notifications older than 30 days every night at 2:00 AM
export const deleteOldNotifications = onSchedule(
  "every day 02:00",
  async () => {
    try {
      const thirtyDaysAgo = new Date();
      thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

      // Use collectionGroup to query 'notifications' across ALL users
      const oldNotificationsSnap = await admin
        .firestore()
        .collectionGroup("notifications")
        .where("timestamp", "<=", thirtyDaysAgo)
        .get();

      if (oldNotificationsSnap.empty) {
        logger.info("No old notifications to delete.");
        return;
      }

      let currentBatch = admin.firestore().batch();
      const batches: typeof currentBatch[] = [];
      let operationCount = 0;

      oldNotificationsSnap.docs.forEach((doc) => {
        currentBatch.delete(doc.ref);
        operationCount++;

        if (operationCount === 499) {
          batches.push(currentBatch);
          currentBatch = admin.firestore().batch();
          operationCount = 0;
        }
      });

      if (operationCount > 0) {
        batches.push(currentBatch);
      }

      await Promise.all(batches.map((batch) => batch.commit()));
      logger.info(`Deleted ${oldNotificationsSnap.size} old notifications.`);
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

        const habits = userData.habits || {};
        let completedCount = 0;
        let totalCount = 0;

        for (const [habitId, isCompleted] of Object.entries(habits)) {
          totalCount++;
          if (habitId === isCompleted) completedCount++;
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
      const fcmToken = afterData.fcmToken;
      const userId = event.params.userId;

      const title = "Streak Freeze Activated! ❄️";
      const body = "You missed a habit, but your Streak Freeze saved your " +
        "streak! Check in today to keep it going.";

      await admin.firestore()
        .collection(`users/${userId}/notifications`)
        .add({
          title: title,
          body: body, // Named 'body' instead of 'message' to match the schema
          type: "system",
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          isArchived: false,
        });

      if (fcmToken) {
        const payload = {
          notification: {title, body},
          android: {notification: {sound: "orbit_chime"}},
          apns: {payload: {aps: {sound: "orbit_chime.wav"}}},
          data: {screen: "profile"},
          token: String(fcmToken),
        };
        try {
          await admin.messaging().send(payload);
          logger.info(`Freeze push notification sent to ${userId}`);
        } catch (error) {
          logger.error("Error sending freeze push notification:", error);
        }
      }
    }
  }
);

export const revenueCatWebhook = onRequest(async (req, res) => {
  // 🚀 EXTRACT THE HEADER VALUE FROM REVENUECAT
  const authHeader = req.headers.authorization;
  const expectedToken = "Bearer OrbitSecretToken2026SecurePass";

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

  // TODO: Use your actual RevenueCat Secret Key from the RevenueCat dashboard
  const REVENUECAT_SECRET = process.env.REVENUECAT_SECRET_KEY ||
    "sk_rFbReytCRoXEhdpmCBLfYegMgeGUD";
  const ENTITLEMENT_ID = "pro"; // Should match the entitlement identifier in RC

  const grantPro = async (uid: string) => {
    const url = `https://api.revenuecat.com/v1/subscribers/${uid}` +
      `/entitlements/${ENTITLEMENT_ID}/promotional`;
    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${REVENUECAT_SECRET}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({duration: "monthly"}), // Grants exactly 30 days
    });
    return response.json();
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
    throw new HttpsError("internal", "Failed to communicate with RevenueCat.");
    throw new HttpsError(
      "internal",
      "Failed to communicate with RevenueCat."
    );
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

// Cleans up guest accounts that are older than 30 days
export const deleteOrphanedGuestAccounts = onSchedule(
  "every day 03:00",
  async () => {
    try {
      const thirtyDaysAgo = new Date();
      thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

      const orphanedGuestsSnap = await admin
        .firestore()
        .collection("users")
        .where("isGuest", "==", true)
        .where("createdAt", "<=", thirtyDaysAgo)
        .get();

      if (orphanedGuestsSnap.empty) {
        logger.info("No orphaned guest accounts to delete.");
        return;
      }

      let currentBatch = admin.firestore().batch();
      const batches: typeof currentBatch[] = [];
      let operationCount = 0;

      for (const doc of orphanedGuestsSnap.docs) {
        // Delete user's subcollections first
        const subcollections = [
          "habits",
          "notifications",
          "friend_requests",
          "coaching_notes",
        ];
        for (const subcollection of subcollections) {
          const subSnap = await doc.ref.collection(subcollection).get();
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

        // Try to delete the actual Firebase Auth account
        await admin.auth().deleteUser(doc.id).catch((e) =>
          logger.error(`Failed to delete auth for ${doc.id}`, e)
        );
      }

      if (operationCount > 0) batches.push(currentBatch);

      await Promise.all(batches.map((batch) => batch.commit()));
      logger.info(
        `Deleted ${orphanedGuestsSnap.size} orphaned guest accounts.`
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
                    `trackEmailOpen?uid=${userRecord.uid}" `,
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

            if (fcmToken) {
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

  if (uid) {
    try {
      // Record that the user opened the email
      await admin.firestore().collection("users").doc(uid).set({
        hasReadWarningEmail: true,
        warningEmailOpenedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
      logger.info(`Email open tracked for user: ${uid}`);
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
