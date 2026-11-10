import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/admin/presentation/admin_notifications_screen.dart';
import '../../features/admin/presentation/admin_screen.dart';
import '../../features/badges/presentation/admin_badges_screen.dart';
import '../../features/auth/presentation/change_password_screen.dart';
import '../../features/blocks/presentation/blocked_users_screen.dart';
import '../../features/auth/presentation/check_email_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/reset_password_screen.dart';
import '../../features/auth/presentation/sign_in_screen.dart';
import '../../features/auth/presentation/sign_up_screen.dart';
import '../../features/chat/data/chat_models.dart';
import '../../features/chat/presentation/chat_list_screen.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/coach/presentation/coach_screen.dart';
import '../../features/connections/presentation/sent_connections_screen.dart';
import '../../features/discover/presentation/discover_screen.dart';
import '../../features/feed/data/feed_models.dart';
import '../../features/feed/presentation/feed_screen.dart';
import '../../features/feed/presentation/post_detail_screen.dart';
import '../../features/help/presentation/help_screen.dart';
import '../../features/matches/presentation/matches_screen.dart';
import '../../features/notifications/presentation/notification_preferences_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/onboarding/presentation/consent_screen.dart';
import '../../features/onboarding/presentation/preferences_screen.dart';
import '../../features/onboarding/presentation/tutorial_screen.dart';
import '../../features/onboarding/presentation/welcome_screen.dart';
import '../../features/profile/presentation/profile_checklist_screen.dart';
import '../../features/profile/presentation/profile_edit_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/studies/presentation/admin_studies_screen.dart';
import '../../features/studies/presentation/study_discipline_screen.dart';
import '../../features/studies/presentation/study_material_detail_screen.dart';
import '../../features/studies/presentation/study_upload_screen.dart';
import '../../features/subscription/presentation/subscription_screen.dart';
import '../../features/verification/presentation/verification_screen.dart';
import 'consent_gate.dart';
import 'go_router_refresh.dart';
import 'main_shell.dart';

const _publicPaths = {
  '/welcome',
  '/sign-up',
  '/sign-in',
  '/check-email',
  '/forgot-password',
  '/reset-password',
};

final GoRouter appRouter = GoRouter(
  initialLocation: '/welcome',
  refreshListenable: GoRouterRefreshStream(
    Supabase.instance.client.auth.onAuthStateChange,
  ),
  redirect: (context, state) async {
    final loggedIn = Supabase.instance.client.auth.currentSession != null;
    final path = state.uri.path;
    final isPublic = _publicPaths.contains(path);

    if (!loggedIn) return isPublic ? null : '/welcome';

    if (path == '/welcome' || path == '/sign-up') {
      final accepted = await ConsentGate.hasConsents();
      return accepted ? '/feed' : '/consent';
    }

    if (path == '/consent') {
      final accepted = await ConsentGate.hasConsents();
      return accepted ? '/feed' : null;
    }

    if (!isPublic) {
      final accepted = await ConsentGate.hasConsents();
      if (!accepted) return '/consent';
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
    GoRoute(
      path: '/change-password',
      builder: (_, _) => const ChangePasswordScreen(),
    ),
    GoRoute(
      path: '/reset-password',
      builder: (_, _) => const ResetPasswordScreen(),
    ),
    GoRoute(path: '/consent', builder: (_, _) => const ConsentScreen()),
    GoRoute(
      path: '/verification',
      builder: (_, _) => const VerificationScreen(),
    ),
    GoRoute(
      path: '/profile-setup',
      builder: (_, _) => const ProfileEditScreen(),
    ),
    GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
    GoRoute(
      path: '/profile/:id',
      builder: (_, state) => ProfileScreen(userId: state.pathParameters['id']),
    ),
    GoRoute(path: '/preferences', builder: (_, _) => const PreferencesScreen()),
    ShellRoute(
      builder: (_, _, child) => MainShell(child: child),
      routes: [
        GoRoute(path: '/feed', builder: (_, _) => const FeedScreen()),
        GoRoute(path: '/discover', builder: (_, _) => const DiscoverScreen()),
        GoRoute(path: '/matches', builder: (_, _) => const MatchesScreen()),
        GoRoute(
          path: '/chats',
          builder: (_, state) {
            final tab = switch (state.uri.queryParameters['tab']) {
              'requests' => 1,
              'connections' => 2,
              _ => 0,
            };
            return ChatListScreen(initialTab: tab);
          },
        ),
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
      builder: (_, state) => ChatScreen(
        id: state.pathParameters['id'] ?? '',
        summary: state.extra is ConversationSummary
            ? state.extra as ConversationSummary
            : null,
      ),
    ),
    GoRoute(
      path: '/connections/sent',
      builder: (_, _) => const SentConnectionsScreen(),
    ),
    GoRoute(
      path: '/subscription',
      builder: (_, _) => const SubscriptionScreen(),
    ),
    GoRoute(path: '/admin', builder: (_, _) => const AdminScreen()),
    GoRoute(
      path: '/admin/badges',
      builder: (_, _) => const AdminBadgesScreen(),
    ),
    GoRoute(
      path: '/admin/studies',
      builder: (_, _) => const AdminStudiesScreen(),
    ),
    GoRoute(
      path: '/admin/notifications',
      builder: (_, _) => const AdminNotificationsScreen(),
    ),
    GoRoute(
      path: '/studies/discipline/:id',
      builder: (_, state) =>
          StudyDisciplineScreen(disciplineId: state.pathParameters['id'] ?? ''),
    ),
    GoRoute(
      path: '/studies/material/:id',
      builder: (_, state) => StudyMaterialDetailScreen(
        materialId: state.pathParameters['id'] ?? '',
      ),
    ),
    GoRoute(
      path: '/studies/upload',
      builder: (_, state) => StudyUploadScreen(
        initialDisciplineId: state.uri.queryParameters['discipline'],
      ),
    ),
    GoRoute(
      path: '/blocked-users',
      builder: (_, _) => const BlockedUsersScreen(),
    ),
    GoRoute(
      path: '/notifications',
      builder: (_, _) => const NotificationsScreen(),
    ),
    GoRoute(
      path: '/notification-preferences',
      builder: (_, _) => const NotificationPreferencesScreen(),
    ),
    GoRoute(path: '/tutorial', builder: (_, _) => const TutorialScreen()),
    GoRoute(path: '/help', builder: (_, _) => const HelpScreen()),
    GoRoute(
      path: '/profile-checklist',
      builder: (_, _) => const ProfileChecklistScreen(),
    ),
  ],
);
