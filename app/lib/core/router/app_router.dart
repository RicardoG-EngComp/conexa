import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/presentation/check_email_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/sign_in_screen.dart';
import '../../features/auth/presentation/sign_up_screen.dart';
import '../../features/chat/presentation/chat_list_screen.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/coach/presentation/coach_screen.dart';
import '../../features/discover/presentation/discover_screen.dart';
import '../../features/feed/data/feed_models.dart';
import '../../features/feed/presentation/feed_screen.dart';
import '../../features/feed/presentation/post_detail_screen.dart';
import '../../features/matches/presentation/matches_screen.dart';
import '../../features/onboarding/presentation/consent_screen.dart';
import '../../features/onboarding/presentation/preferences_screen.dart';
import '../../features/onboarding/presentation/profile_setup_screen.dart';
import '../../features/onboarding/presentation/welcome_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/subscription/presentation/subscription_screen.dart';
import '../../features/verification/presentation/verification_screen.dart';
import 'go_router_refresh.dart';
import 'main_shell.dart';

const _publicPaths = {
  '/welcome',
  '/sign-up',
  '/sign-in',
  '/check-email',
  '/forgot-password',
};

final GoRouter appRouter = GoRouter(
  initialLocation: '/welcome',
  refreshListenable: GoRouterRefreshStream(
    Supabase.instance.client.auth.onAuthStateChange,
  ),
  redirect: (context, state) {
    final loggedIn = Supabase.instance.client.auth.currentSession != null;
    final path = state.uri.path;
    final isPublic = _publicPaths.contains(path);

    if (!loggedIn && !isPublic) return '/welcome';
    if (loggedIn && (path == '/welcome' || path == '/sign-up')) {
      return '/feed';
    }
    return null;
  },
  routes: [
    GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
    GoRoute(path: '/sign-up', builder: (_, _) => const SignUpScreen()),
    GoRoute(path: '/sign-in', builder: (_, _) => const SignInScreen()),
    GoRoute(path: '/check-email', builder: (_, _) => const CheckEmailScreen()),
    GoRoute(
      path: '/forgot-password',
      builder: (_, _) => const ForgotPasswordScreen(),
    ),
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
        GoRoute(path: '/feed', builder: (_, _) => const FeedScreen()),
        GoRoute(path: '/discover', builder: (_, _) => const DiscoverScreen()),
        GoRoute(path: '/matches', builder: (_, _) => const MatchesScreen()),
        GoRoute(path: '/chats', builder: (_, _) => const ChatListScreen()),
        GoRoute(path: '/coach', builder: (_, _) => const CoachScreen()),
        GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      ],
    ),
    GoRoute(
      path: '/feed/:id',
      builder: (_, state) => PostDetailScreen(
        postId: state.pathParameters['id'] ?? '',
        post: state.extra is FeedPost ? state.extra as FeedPost : null,
      ),
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
