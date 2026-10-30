import 'package:go_router/go_router.dart';

import '../../features/chat/presentation/chat_list_screen.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/coach/presentation/coach_screen.dart';
import '../../features/discover/presentation/discover_screen.dart';
import '../../features/matches/presentation/matches_screen.dart';
import '../../features/onboarding/presentation/consent_screen.dart';
import '../../features/onboarding/presentation/preferences_screen.dart';
import '../../features/onboarding/presentation/profile_setup_screen.dart';
import '../../features/onboarding/presentation/sign_up_screen.dart';
import '../../features/onboarding/presentation/verification_screen.dart';
import '../../features/onboarding/presentation/welcome_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/subscription/presentation/subscription_screen.dart';
import 'main_shell.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/welcome',
  routes: [
    GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
    GoRoute(path: '/sign-up', builder: (_, _) => const SignUpScreen()),
    GoRoute(path: '/consent', builder: (_, _) => const ConsentScreen()),
    GoRoute(
      path: '/verification',
      builder: (_, _) => const VerificationScreen(),
    ),
    GoRoute(
      path: '/profile-setup',
      builder: (_, _) => const ProfileSetupScreen(),
    ),
    GoRoute(path: '/preferences', builder: (_, _) => const PreferencesScreen()),
    ShellRoute(
      builder: (_, _, child) => MainShell(child: child),
      routes: [
        GoRoute(path: '/discover', builder: (_, _) => const DiscoverScreen()),
        GoRoute(path: '/matches', builder: (_, _) => const MatchesScreen()),
        GoRoute(path: '/chats', builder: (_, _) => const ChatListScreen()),
        GoRoute(path: '/coach', builder: (_, _) => const CoachScreen()),
        GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      ],
    ),
    GoRoute(
      path: '/chats/:id',
      builder: (_, state) => ChatScreen(id: state.pathParameters['id'] ?? ''),
    ),
    GoRoute(
      path: '/subscription',
      builder: (_, _) => const SubscriptionScreen(),
    ),
  ],
);
