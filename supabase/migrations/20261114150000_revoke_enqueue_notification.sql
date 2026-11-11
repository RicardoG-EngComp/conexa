-- Revoga de PUBLIC funcoes internas de notificacao (default do Postgres).
-- Triggers e RPCs security definer continuam podendo chama-las.

revoke all on function public.enqueue_notification(
  uuid, text, text, text, jsonb
) from public, anon, authenticated;

revoke all on function public.notification_type_enabled(uuid, text)
  from public, anon, authenticated;
