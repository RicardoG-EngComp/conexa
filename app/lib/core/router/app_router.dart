import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/admin/presentation/admin_feedback_screen.dart';
import '../../features/admin/presentation/admin_appeals_screen.dart';
import '../../features/admin/presentation/admin_campus_screen.dart';
import '../../features/admin/presentation/admin_groups_screen.dart';
import '../../features/admin/presentation/admin_moderation_terms_screen.dart';
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
import '../../features/campus/presentation/campus_map_screen.dart';
import '../../features/connections/presentation/people_screen.dart';
import '../../features/connections/presentation/sent_connections_screen.dart';
import '../../features/feed/data/feed_models.dart';
import '../../features/feed/presentation/compose_post_screen.dart';
import '../../features/feed/presentation/custom_feed_screen.dart';
import '../../features/feed/presentation/custom_feeds_screen.dart';
import '../../features/feed/presentation/feed_screen.dart';
import '../../features/feed/presentation/hidden_posts_screen.dart';
import '../../features/feed/presentation/insights_screen.dart';
import '../../features/feed/presentation/post_detail_screen.dart';
import '../../features/feed/presentation/saved_posts_screen.dart';
import '../../features/feed/presentation/scheduled_posts_screen.dart';
import '../../features/feed/presentation/search_screen.dart';
import '../../features/groups/presentation/group_create_screen.dart';
import '../../features/groups/presentation/group_manage_screen.dart';
import '../../features/groups/presentation/group_profile_screen.dart';
import '../../features/groups/presentation/group_insights_screen.dart';
import '../../features/groups/presentation/group_invites_received_screen.dart';
import '../../features/groups/presentation/groups_discover_screen.dart';
import '../../features/groups/presentation/groups_home_screen.dart';
import '../../features/feedback/presentation/bug_report_screen.dart';
import '../../features/feedback/presentation/feedback_screen.dart';
import '../../features/feedback/presentation/suggestion_screen.dart';
import '../../features/help/presentation/help_screen.dart';
import '../../features/curtidas/presentation/curtidas_screen.dart';
import '../../features/notifications/presentation/notification_preferences_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/onboarding/presentation/consent_screen.dart';
import '../../features/onboarding/presentation/preferences_screen.dart';
import '../../features/onboarding/presentation/tutorial_screen.dart';
import '../../features/onboarding/presentation/welcome_screen.dart';
import '../../features/profile/presentation/profile_checklist_screen.dart';
import '../../features/profile/presentation/profile_edit_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/reports/presentation/my_reports_screen.dart';
import '../../features/search/presentation/study_search_screen.dart';
import '../../features/security/presentation/muted_users_screen.dart';
import '../../features/security/presentation/muted_words_screen.dart';
import '../../features/security/presentation/security_screen.dart';
import '../../features/settings/presentation/appearance_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/studies/presentation/admin_studies_screen.dart';
import '../../features/studies/presentation/saved_materials_screen.dart';
import '../../features/studies/presentation/study_discipline_screen.dart';
import '../../features/studies/presentation/study_material_detail_screen.dart';
import '../../features/studies/presentation/study_question_detail_screen.dart';
import '../../features/studies/presentation/study_questions_screen.dart';
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
    GoRoute(path: '/appearance', builder: (_, _) => const AppearanceScreen()),
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
    StatefulShellRoute.indexedStack(
      builder: (_, _, navigationShell) =>
          MainShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/feed', builder: (_, _) => const FeedScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/discover',
              builder: (_, _) => const StudySearchScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/map', builder: (_, _) => const CampusMapScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/notifications',
              builder: (_, _) => const NotificationsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/chats',
              builder: (_, state) {
                final tab = switch (state.uri.queryParameters['tab']) {
                  'requests' => 1,
                  _ => 0,
                };
                return ChatListScreen(initialTab: tab);
              },
            ),
          ],
        ),
      ],
    ),
    GoRoute(path: '/curtidas', builder: (_, _) => const CurtidasScreen()),
    GoRoute(path: '/coach', builder: (_, _) => const CoachScreen()),
    GoRoute(path: '/people', builder: (_, _) => const PeopleScreen()),
    GoRoute(path: '/groups', builder: (_, _) => const GroupsHomeScreen()),
    GoRoute(
      path: '/groups/discover',
      builder: (_, _) => const GroupsDiscoverScreen(),
    ),
    GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
    GoRoute(
      path: '/feed/compose',
      builder: (_, state) => ComposePostScreen(
        groupId: state.uri.queryParameters['group'],
        initialText: state.uri.queryParameters['text'],
        quoted: state.extra is FeedPost ? state.extra as FeedPost : null,
        initialDraft: state.extra is Map
            ? (state.extra as Map).cast<String, dynamic>()
            : null,
      ),
    ),
    GoRoute(path: '/feed/saved', builder: (_, _) => const SavedPostsScreen()),
    GoRoute(
      path: '/feed/scheduled',
      builder: (_, _) => const ScheduledPostsScreen(),
    ),
    GoRoute(path: '/feed/hidden', builder: (_, _) => const HiddenPostsScreen()),
    GoRoute(path: '/feed/search', builder: (_, _) => const SearchScreen()),
    GoRoute(path: '/feed/feeds', builder: (_, _) => const CustomFeedsScreen()),
    GoRoute(
      path: '/feed/feeds/:id',
      builder: (_, state) => CustomFeedScreen(
        feedId: state.pathParameters['id'] ?? '',
        feed: state.extra is CustomFeed ? state.extra as CustomFeed : null,
      ),
    ),
    GoRoute(path: '/insights', builder: (_, _) => const InsightsScreen()),
    GoRoute(
      path: '/feed/:id',
      builder: (_, state) => PostDetailScreen(
        postId: state.pathParameters['id'] ?? '',
        post: state.extra is FeedPost ? state.extra as FeedPost : null,
      ),
    ),
    GoRoute(
      path: '/invites',
      builder: (_, _) => const GroupInvitesReceivedScreen(),
    ),
    GoRoute(
      path: '/groups/create',
      builder: (_, _) => const GroupCreateScreen(),
    ),
    GoRoute(
      path: '/groups/:id',
      builder: (_, state) =>
          GroupProfileScreen(groupId: state.pathParameters['id'] ?? ''),
    ),
    GoRoute(
      path: '/groups/:id/manage',
      builder: (_, state) =>
          GroupManageScreen(groupId: state.pathParameters['id'] ?? ''),
    ),
    GoRoute(
      path: '/groups/:id/insights',
      builder: (_, state) =>
          GroupInsightsScreen(groupId: state.pathParameters['id'] ?? ''),
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
      path: '/admin/groups',
      builder: (_, _) => const AdminGroupsScreen(),
    ),
    GoRoute(
      path: '/admin/campus',
      builder: (_, _) => const AdminCampusScreen(),
    ),
    GoRoute(
      path: '/admin/appeals',
      builder: (_, _) => const AdminAppealsScreen(),
    ),
    GoRoute(
      path: '/admin/moderation-terms',
      builder: (_, _) => const AdminModerationTermsScreen(),
    ),
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
      path: '/admin/feedback',
      builder: (_, _) => const AdminFeedbackScreen(),
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
      path: '/studies/questions',
      builder: (_, state) => StudyQuestionsScreen(
        disciplineId: state.uri.queryParameters['discipline'] ?? '',
      ),
    ),
    GoRoute(
      path: '/studies/questions/:id',
      builder: (_, state) => StudyQuestionDetailScreen(
        questionId: state.pathParameters['id'] ?? '',
      ),
    ),
    GoRoute(
      path: '/studies/saved',
      builder: (_, _) => const SavedMaterialsScreen(),
    ),
    GoRoute(
      path: '/blocked-users',
      builder: (_, _) => const BlockedUsersScreen(),
    ),
    GoRoute(path: '/security', builder: (_, _) => const SecurityScreen()),
    GoRoute(path: '/muted-users', builder: (_, _) => const MutedUsersScreen()),
    GoRoute(path: '/muted-words', builder: (_, _) => const MutedWordsScreen()),
    GoRoute(path: '/my-reports', builder: (_, _) => const MyReportsScreen()),
    GoRoute(
      path: '/notification-preferences',
      builder: (_, _) => const NotificationPreferencesScreen(),
    ),
    GoRoute(path: '/tutorial', builder: (_, _) => const TutorialScreen()),
    GoRoute(path: '/help', builder: (_, _) => const HelpScreen()),
    GoRoute(path: '/feedback', builder: (_, _) => const FeedbackScreen()),
    GoRoute(path: '/feedback/bug', builder: (_, _) => const BugReportScreen()),
    GoRoute(
      path: '/feedback/suggestion',
      builder: (_, _) => const SuggestionScreen(),
    ),
    GoRoute(
      path: '/profile-checklist',
      builder: (_, _) => const ProfileChecklistScreen(),
    ),
  ],
);
