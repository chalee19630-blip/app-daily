
-- Restrict direct execution of SECURITY DEFINER functions.
-- Keep the required helper functions available to authenticated users
-- because RLS policies call them.

REVOKE EXECUTE ON FUNCTION public.add_workspace_owner(UUID, UUID)
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.can_access_project(UUID)
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.count_workspace_owners(UUID)
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.get_project_workspace(UUID)
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.get_user_workspace_ids()
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.get_workspace_role(UUID)
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.handle_new_user()
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.handle_new_workspace()
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.handle_updated_at()
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.is_user_workspace_member(UUID, UUID)
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.is_workspace_admin_or_owner(UUID)
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.is_workspace_member(UUID)
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.is_workspace_owner(UUID)
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.prevent_direct_owner_change()
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.prevent_last_owner_removal()
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.prevent_project_workspace_change()
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.prevent_task_cross_workspace_move()
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.transfer_workspace_ownership(UUID, UUID)
  FROM PUBLIC, anon, authenticated;

-- RLS helper functions required by policies.
GRANT EXECUTE ON FUNCTION public.can_access_project(UUID)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_project_workspace(UUID)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_workspace_ids()
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_user_workspace_member(UUID, UUID)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_workspace_admin_or_owner(UUID)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_workspace_member(UUID)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_workspace_owner(UUID)
  TO authenticated;

-- Explicitly permitted ownership-management RPCs.
GRANT EXECUTE ON FUNCTION public.add_workspace_owner(UUID, UUID)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.transfer_workspace_ownership(UUID, UUID)
  TO authenticated;
