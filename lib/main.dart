import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

import 'package:go_router/go_router.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'services/notification_service.dart';
import 'screens/settings/notifications_screen.dart';

// Screens
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/navigation/main_navigation_screen.dart';
import 'screens/onboarding/login_screen.dart';
import 'screens/navigation/profile_screen.dart';
import 'screens/social/group_challenges_screen.dart';
import 'screens/onboarding/whats_new_screen.dart';

// Providers
import 'providers/routine_provider.dart';
import 'providers/auth_provider.dart'; // Adjust path if needed based on your structure
import 'providers/ai_fairy_provider.dart'; // Adjust path if needed based on your structure
import 'providers/atmosphere_provider.dart'; // Adjust path if needed based on your structure
import 'providers/telemetry_provider.dart'; // Adjust path if needed based on your structure

import 'theme/app_theme.dart';
import 'theme/orbit_colors.dart';
import 'theme/nebula_themes.dart';

// Services
import 'services/cosmic_mirror_service.dart'; // For generating the weekly legend

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

const String globalAppVersion =
    '1.1.0'; // Update this whenever you want to trigger What's New!

// 1. This must be a top-level function (outside of any class)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized before using it in the background
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Handling a background message: ${message.messageId}");
}

// --- REACTIVE AUTHENTICATION WRAPPER ---
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppAuthProvider>().user;
    if (user == null) return const LoginScreen();

    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(backgroundColor: Color(0xFF050112));
        }
        final prefs = snapshot.data!;
        final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
        final lastSeenVersion = prefs.getString('last_seen_version') ?? '1.0.0';
        final showWhatsNew =
            hasSeenOnboarding && (lastSeenVersion != globalAppVersion);

        if (!hasSeenOnboarding) return const OnboardingScreen();
        if (showWhatsNew) {
          return const WhatsNewScreen(currentVersion: globalAppVersion);
        }
        return const MainNavigationScreen();
      },
    );
  }
}

void main() async {
  // 2. Capture the binding
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  // Set the iOS App Group ID here! HomeWidget has no web implementation, and
  // this runs before runApp() with nothing to catch it — on web it threw
  // MissingPluginException and aborted startup entirely, leaving the app
  // stuck on the splash screen forever.
  try {
    await HomeWidget.setAppGroupId('group.com.orbitroutine.orbit');
  } catch (e) {
    debugPrint('HomeWidget.setAppGroupId unsupported on this platform: $e');
  }

  // 3. Keep the splash screen visible while loading
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // --- INITIALIZE CORE SERVICES ---
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize app check with debug providers. No webProvider is configured
  // (would need a ReCAPTCHA site key), so activate() throws
  // [app-check/no-provider] on web — caught here so it doesn't abort startup
  // before runApp() the way the HomeWidget call above used to.
  try {
    await FirebaseAppCheck.instance.activate(
      // //webProvider: ReCaptchaEnterpriseProvider('YOUR_RECAPTCHA_SITE_KEY'),

      // debugging
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode
          ? const AppleDebugProvider()
          : const AppleDeviceCheckProvider(),
    );
  } catch (e) {
    debugPrint('FirebaseAppCheck.activate failed on this platform: $e');
  }

  // --- JUST AUDIO BACKGROUND ---
  // Must be called before any AudioPlayer is created.  Without this the
  // Android MediaSessionService is never registered, the media3 codec-query
  // path is hit without a proper foreground context, and you get the
  // c2.android.mp3.decoder BAD_INDEX spam in logcat.
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.invokerlab.orbit.audio',
    androidNotificationChannelName: 'Orbit Audio',
    androidNotificationOngoing: true,
    notificationColor: const Color(0xFF050112),
  );
  // 1. Catch Flutter framework errors (like layout issues or build crashes)
  // --- CRASHLYTICS SETUP ---

  // Pipe standard debug prints into Crashlytics session logs
  final originalDebugPrint = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null) {
      FirebaseCrashlytics.instance.log(message);
    }
    originalDebugPrint(message, wrapWidth: wrapWidth);
  };

  // Pass all uncaught "fatal" errors from the framework to Crashlytics.
  // Chained onto whatever handler was already installed (the default is
  // FlutterError.presentError, so this preserves that in production)
  // rather than replacing it outright — flutter_test/integration_test
  // install their own FlutterError.onError to detect test failures, and
  // clobbering it here made every test using this app's real main()
  // fail with a binding assertion regardless of what the test did.
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    previousOnError?.call(details);
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  };
  // 2. Catch asynchronous Dart errors (like unhandled Futures)
  // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
  // Optionally, you can also catch Dart errors that aren't caught by Flutter's error handling
  final previousPlatformOnError = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (error, stack) {
    previousPlatformOnError?.call(error, stack);
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true; // Return true to indicate that the error has been handled
  };

  // 3. Graceful UI fallback (Error Boundary Widget)
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Color(0xFF051024), // Your app's dark background
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.orangeAccent,
                size: 48,
              ),
              SizedBox(height: 16),
              Text(
                'A cosmic anomaly occurred.\nMission control has been notified.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  };

  // --- FIREBASE MESSAGING SETUP ---
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Removed global onMessage listener to prevent duplicate logs on Hot Restart.
  // Handle this inside the stateful OrbitApp widget instead!

  // --- DOTENV SETUP ---
  try {
    // 4. Wrap secondary awaits in a timeout or try-catch so they can't freeze the app
    await dotenv.load(fileName: ".env").timeout(const Duration(seconds: 3));
  } catch (e) {
    debugPrint("Dotenv failed to load: $e");
  }

  // --- LOCAL NOTIFICATIONS SETUP ---
  await NotificationService.init();

  // ... [Keep your communication, Error Handling, and Notifications logic here] ...

  // --- REVENUECAT PRODUCTION INITIALIZATION ---
  if (!kIsWeb) {
    try {
      // 🚀 Only verbose log billing queries when explicitly running in local debug arrays
      if (kDebugMode) {
        await Purchases.setLogLevel(LogLevel.debug);
      } else {
        await Purchases.setLogLevel(
          LogLevel.error,
        ); // Silences framework noise for users
      }

      PurchasesConfiguration? configuration;

      if (Platform.isIOS) {
        configuration = PurchasesConfiguration(
          dotenv.env['REVENUECAT_APPLE_KEY'] ??
              "appl_hxLkpOfXfWtRdmoJPbTSwipirfu",
        );
      } else if (Platform.isAndroid) {
        // Fetches your secure production credential properties out of the env mapping layer
        configuration = PurchasesConfiguration(
          dotenv.env['REVENUECAT_ANDROID_KEY'] ??
              "goog_SjLHJvbjsMSeHipGzTIDUuxlbQl",
        );
      }

      if (configuration != null) {
        await Purchases.configure(configuration);
        debugPrint(
          "RevenueCat engine securely attached to Orbit's purchase nodes.",
        );
      }
    } catch (e) {
      // Crashlytics tracking hooks ensure you know if the store handshake fails out in the wild
      FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: "RevenueCat Init Failure",
      );
    }
  }
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => RoutineProvider()),
        ChangeNotifierProvider(create: (_) => AppAuthProvider()),
        ChangeNotifierProvider(create: (_) => AIFairyProvider()), // AI Brain!
        ChangeNotifierProvider(create: (_) => AtmosphereProvider()),
        ChangeNotifierProvider(create: (_) => TelemetryProvider()),
        Provider(create: (_) => CosmicMirrorService()), // For the Weekly Legend
      ],
      child: const OrbitApp(),
    ),
  );

  // 5. THIS IS THE KEY: Tell the splash screen to go away once the UI is ready
  FlutterNativeSplash.remove();
}

// This flag prevents re-initializing push notification listeners on hot restart.
bool _pushNotificationsInitialized = false;

// --- GOROUTER CONFIGURATION ---
final GoRouter _router = GoRouter(
  navigatorKey: navigatorKey, // Re-use your global navigator key!
  initialLocation: '/',
  // '/' goes through AuthWrapper, which gates on signed-in state and
  // onboarding completion -- but '/profile', '/journey', and '/habit'
  // build their target screens directly with no such check. A widget
  // tap or push-notification deep link (_handleWidgetNavigation,
  // cold-start FCM taps) pushes straight onto one of those routes, which
  // used to let a signed-out user land on the main app/profile screen
  // without ever going through login. Route everyone else back through
  // AuthWrapper first.
  redirect: (context, state) {
    if (state.matchedLocation == '/') return null;
    final user = FirebaseAuth.instance.currentUser;
    return user == null ? '/' : null;
  },
  routes: [
    GoRoute(path: '/', builder: (context, state) => const AuthWrapper()),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: '/journey',
      builder: (context, state) =>
          const MainNavigationScreen(initialTab: 'journey'),
    ),
    GoRoute(
      path: '/habit',
      builder: (context, state) {
        final title = state.uri.queryParameters['title'];
        if (title != null) {
          return MainNavigationScreen(
            key: ValueKey('MainNavWithHighlight_$title'),
            highlightHabit: title,
            initialTab: 'habits',
          );
        }
        return const MainNavigationScreen(initialTab: 'habits');
      },
    ),
  ],
);

class OrbitApp extends StatefulWidget {
  const OrbitApp({super.key});

  @override
  State<OrbitApp> createState() => _OrbitAppState();
}

class _OrbitAppState extends State<OrbitApp> {
  StreamSubscription<RemoteMessage>? _fcmForegroundSub;
  StreamSubscription<RemoteMessage>? _fcmOpenedAppSub;
  StreamSubscription<User?>? _authChangesSub;
  StreamSubscription<String>? _tokenRefreshSub;

  @override
  void initState() {
    super.initState();
    _setupWidgetListener();
    // This check prevents creating duplicate listeners on hot restart.
    if (!_pushNotificationsInitialized) {
      _setupPushNotifications();
      _pushNotificationsInitialized = true;
      // Clean up old channels once on app boot!
      NotificationService.deleteOldChannels();
    }
    _setupRevenueCatListener();
  }

  @override
  void dispose() {
    _fcmForegroundSub?.cancel();
    _fcmOpenedAppSub?.cancel();
    _authChangesSub?.cancel();
    _tokenRefreshSub?.cancel();

    if (!kIsWeb) {
      Purchases.removeCustomerInfoUpdateListener(_customerInfoUpdateListener);
    }
    super.dispose();
  }

  void _customerInfoUpdateListener(CustomerInfo customerInfo) {
    final isPro = customerInfo.entitlements.all["Orbit Pro"]?.isActive == true;
    debugPrint('RevenueCat Global Sync: isPro = $isPro');
    // The SDK fires this synchronously while addCustomerInfoUpdateListener
    // is called from initState — mid-build. Notifying providers there throws
    // "setState() or markNeedsBuild() called during build" on every cold
    // start, so defer the notification to after the current frame.
    Future.microtask(() {
      if (mounted) {
        context.read<AppAuthProvider>().updateProStatus(isPro);
      }
    });
  }

  void _setupRevenueCatListener() async {
    if (!kIsWeb) {
      Purchases.addCustomerInfoUpdateListener(_customerInfoUpdateListener);
      try {
        final customerInfo = await Purchases.getCustomerInfo();
        _customerInfoUpdateListener(customerInfo);
      } catch (e) {
        debugPrint("Failed to fetch initial RC info: $e");
      }
    }
  }

  void _setupWidgetListener() {
    // Handle app launch from widget tap
    HomeWidget.initiallyLaunchedFromHomeWidget().then((Uri? uri) {
      if (uri != null) {
        _handleWidgetNavigation(uri);
      }
    });

    // Handle app opened from widget when app is already in the background
    HomeWidget.widgetClicked.listen((Uri? uri) {
      if (uri != null) {
        _handleWidgetNavigation(uri);
      }
    });
  }

  void _handleWidgetNavigation(Uri uri) {
    // Extract host and path gracefully so `orbit://habit?title=x` becomes `/habit?title=x`
    String path = uri.path;
    if (uri.host.isNotEmpty) {
      path = '/${uri.host}$path';
    }
    if (path.isEmpty) path = '/';
    final query = uri.hasQuery ? '?${uri.query}' : '';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _router.push('$path$query');
    });
  }

  Future<void> _setupPushNotifications() async {
    if (kIsWeb) return;

    // 1. Request permissions globally (Catches existing users who skipped Onboarding!)
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 1.5 Fetch and save the token whenever the user logs in or the app starts
    _authChangesSub = FirebaseAuth.instance.authStateChanges().listen((
      user,
    ) async {
      if (user != null) {
        // Throws on simulators (and real devices before APNS has
        // provisioned a token) — was previously unguarded, an uncaught
        // error inside this stream listener that only Crashlytics'
        // global handlers happened to absorb silently in production.
        try {
          final token = await FirebaseMessaging.instance.getToken();
          if (token != null) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .set({'fcmToken': token}, SetOptions(merge: true));
          }
        } catch (e) {
          debugPrint('FirebaseMessaging.getToken error: $e');
        }

        // Sync RevenueCat with Firebase Auth User to ensure subscriptions work cross-device
        if (!kIsWeb) {
          try {
            await Purchases.logIn(user.uid);
          } on PlatformException catch (e) {
            // RevenueCat often throws a 404 PlatformException for brand new anonymous users
            // because they have no history. We can safely ignore this!
            debugPrint("RevenueCat setup complete (New guest user): $e");
          } catch (e) {
            debugPrint("RevenueCat logIn error: $e");
          }
        }
      } else {
        // Log out of RevenueCat when user logs out of Firebase
        if (!kIsWeb) {
          try {
            await Purchases.logOut();
          } catch (e) {
            debugPrint("RevenueCat logOut error: $e");
          }
        }
      }
    });

    // 2. Listen for the token. Once APNs is ready, this fires and saves to Firestore!
    _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((
      newToken,
    ) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'fcmToken': newToken,
        }, SetOptions(merge: true));
      }
    });

    // 3. Handle tapping a notification when the app is completely closed
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _handleNotificationTap(initialMessage),
      );
    }

    // 4. Handle tapping a notification when the app is running in the background
    _fcmOpenedAppSub = FirebaseMessaging.onMessageOpenedApp.listen(
      _handleNotificationTap,
    );

    // 4.5 Handle foreground messages properly without duplicate ghost listeners
    _fcmForegroundSub = FirebaseMessaging.onMessage.listen((
      RemoteMessage message,
    ) {
      if (message.notification != null) {
        debugPrint('Foreground Notification: ${message.notification?.title}');

        // THE FIX: if you want to show a clean banner to the user inside the app, use a local snackbar instead of writing back to Firestore over the network!
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (rootScaffoldMessengerKey.currentState != null) {
            rootScaffoldMessengerKey.currentState!.showSnackBar(
              SnackBar(
                content: Text(
                  "${message.notification!.title}: ${message.notification!.body}",
                ),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        });
      }
    });

    // 5. Schedule local 9 AM reminder (will check daily) -- this used to
    // fire unconditionally regardless of the Settings > "Enable All
    // Notifications" master toggle, which only ever gated routine alarms.
    if (mounted && context.read<RoutineProvider>().allNotifsEnabled) {
      // Capture before the awaits so we don't read context across async gaps.
      final currentStreak = context.read<RoutineProvider>().currentStreak;
      await NotificationService.scheduleDailyReminder();
      // Opening the app is a "user is active" signal -- slide the lapsed-user
      // re-engagement nudge ladder forward so it only fires after real silence.
      await NotificationService.scheduleReEngagementNudges(
        currentStreak: currentStreak,
      );
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    // Check the custom data payload you sent from Firebase/Cloud Functions
    final screen = message.data['screen'];
    if (screen == 'dashboard') {
      // notifyPartnerOnHabitComplete, notifyOnPartnerLinked, and the
      // inactive-account nudge all send screen: "dashboard", but this
      // value was never handled here and fell through to the generic
      // Notifications inbox below instead. Pop back to the root, which is
      // MainNavigationScreen showing the Home tab -- the actual dashboard.
      navigatorKey.currentState?.popUntil((route) => route.isFirst);
    } else if (screen == 'profile') {
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (context) => const ProfileScreen()),
      );
    } else if (screen == 'challenges') {
      // notifyOnChallengeCreated sends screen: "challenges" on a Group
      // Challenge invite -- route straight to it like 'profile' above,
      // instead of falling through to the generic Notifications inbox.
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (context) => const GroupChallengesScreen()),
      );
    } else if (screen == 'path_detail' || message.data['type'] == 'milestone') {
      // Route them directly to the Notifications Inbox to see their new reward!
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (context) => const NotificationsScreen()),
      );
    } else {
      // Fallback for general system notifications
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (context) => const NotificationsScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // context.select rebuilds OrbitApp (and therefore MaterialApp) ONLY when
    // themeMode changes — not on every RoutineProvider.notifyListeners() call.
    //
    // The previous Consumer<RoutineProvider> wrapper never used the
    // `routineProvider` value it received, so MaterialApp was rebuilt on every
    // provider notification (habit completions, audio state changes, etc.).
    // That caused InheritedElement.notifyClients() to traverse stale
    // parent-chain references mid-frame → assertion failure at framework.dart
    // line 6417.
    context.select<RoutineProvider, String>((p) => p.themeMode);

    // Selected separately so a Nebula Theme purchase/switch (see
    // RoutineProvider.setActiveNebulaTheme) restyles the app's OrbitColors
    // accent without rebuilding on unrelated provider notifications.
    final activeNebulaTheme = context.select<RoutineProvider, String>(
      (p) => p.activeNebulaTheme,
    );
    final nebulaColors = OrbitColors(
      orbColor1: NebulaThemes.byName(activeNebulaTheme).orbColor1,
      orbColor2: NebulaThemes.byName(activeNebulaTheme).orbColor2,
    );

    return MaterialApp.router(
      title: 'Orbit',

      scaffoldMessengerKey: rootScaffoldMessengerKey,

      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark, // Forces Dark Mode permanently
      // --- THEMES ---
      theme: AppTheme.lightTheme.copyWith(extensions: [nebulaColors]),
      darkTheme: AppTheme.darkTheme.copyWith(extensions: [nebulaColors]),

      // --- LOCALIZATION ---
      // Infrastructure + Settings screen fully wired as a proof of concept
      // (lib/l10n/app_en.arb / app_es.arb) -- most of the rest of the app is
      // still hardcoded English text, not yet extracted to .arb. Falls back
      // to English for any locale without an .arb file via localeResolutionCallback below.
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      localeResolutionCallback: (deviceLocale, supported) {
        if (deviceLocale != null &&
            supported.any((l) => l.languageCode == deviceLocale.languageCode)) {
          return deviceLocale;
        }
        return const Locale('en');
      },

      // --- ROUTING ENGINE ---
      routerConfig: _router,
    );
  }
}
