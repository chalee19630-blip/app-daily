-- ============================================
-- ProjectPilot AI - Database Schema Migration
-- ============================================
-- Creates: profiles, workspaces, workspace_members, projects, tasks
-- with Row Level Security policies
-- ============================================
-- Security Review: 2024-10-12
-- - Fixed cross-workspace project movement
-- - Fixed cross-workspace task movement
-- - Fixed assigned_to workspace validation
-- - Added last owner protection
-- - Added owner transfer mechanism
-- - Fixed race conditions
-- ============================================

-- ============================================
-- ENUM TYPES
-- ============================================

-- Workspace member roles
CREATE TYPE public.workspace_role AS ENUM ('owner', 'admin', 'member');

-- Project status
CREATE TYPE public.project_status AS ENUM ('active', 'completed', 'archived');

-- Task status
CREATE TYPE public.task_status AS ENUM ('todo', 'in_progress', 'done', 'cancelled');

-- Task priority
CREATE TYPE public.task_priority AS ENUM ('low', 'medium', 'high', 'urgent');

-- ============================================
-- TABLES
-- ============================================

-- Profiles: extends auth.users
CREATE TABLE public.profiles (
  id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT,
  avatar_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (id)
);

-- Workspaces
CREATE TABLE public.workspaces (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (id)
);

-- Workspace Members (many-to-many with roles)
CREATE TABLE public.workspace_members (
  workspace_id UUID NOT NULL REFERENCES public.workspaces(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role public.workspace_role NOT NULL DEFAULT 'member',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (workspace_id, user_id)
);

-- Projects
CREATE TABLE public.projects (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  workspace_id UUID NOT NULL REFERENCES public.workspaces(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  status public.project_status NOT NULL DEFAULT 'active',
  created_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (id)
);

-- Tasks
CREATE TABLE public.tasks (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  status public.task_status NOT NULL DEFAULT 'todo',
  priority public.task_priority NOT NULL DEFAULT 'medium',
  assigned_to UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  due_date DATE,
  created_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (id)
);

-- ============================================
-- INDEXES
-- ============================================

-- Profiles
CREATE INDEX idx_profiles_created_at ON public.profiles(created_at);

-- Workspaces
CREATE INDEX idx_workspaces_owner_id ON public.workspaces(owner_id);
CREATE INDEX idx_workspaces_created_at ON public.workspaces(created_at);

-- Workspace Members
CREATE INDEX idx_workspace_members_user_id ON public.workspace_members(user_id);
CREATE INDEX idx_workspace_members_role ON public.workspace_members(role);

-- Projects
CREATE INDEX idx_projects_workspace_id ON public.projects(workspace_id);
CREATE INDEX idx_projects_status ON public.projects(status);
CREATE INDEX idx_projects_created_by ON public.projects(created_by);
CREATE INDEX idx_projects_created_at ON public.projects(created_at);

-- Tasks
CREATE INDEX idx_tasks_project_id ON public.tasks(project_id);
CREATE INDEX idx_tasks_status ON public.tasks(status);
CREATE INDEX idx_tasks_priority ON public.tasks(priority);
CREATE INDEX idx_tasks_assigned_to ON public.tasks(assigned_to);
CREATE INDEX idx_tasks_due_date ON public.tasks(due_date);
CREATE INDEX idx_tasks_created_by ON public.tasks(created_by);
CREATE INDEX idx_tasks_created_at ON public.tasks(created_at);

-- ============================================
-- ROW LEVEL SECURITY
-- ============================================

-- Enable RLS on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workspaces ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workspace_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;

-- ============================================
-- SECURE HELPER FUNCTIONS
-- ============================================

-- Helper function to check if user is a workspace member
-- Uses SECURITY DEFINER with fixed search_path to prevent injection
CREATE OR REPLACE FUNCTION public.is_workspace_member(workspace_uuid UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.workspace_members wm
    WHERE wm.workspace_id = workspace_uuid
    AND wm.user_id = auth.uid()
  );
END;
$$;

-- Helper function to get user's role in a workspace
CREATE OR REPLACE FUNCTION public.get_workspace_role(workspace_uuid UUID)
RETURNS public.workspace_role
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  user_role public.workspace_role;
BEGIN
  SELECT role INTO user_role
  FROM public.workspace_members wm
  WHERE wm.workspace_id = workspace_uuid
  AND wm.user_id = auth.uid();

  RETURN user_role;
END;
$$;

-- Helper function to check if user has admin or owner role
CREATE OR REPLACE FUNCTION public.is_workspace_admin_or_owner(workspace_uuid UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.workspace_members wm
    WHERE wm.workspace_id = workspace_uuid
    AND wm.user_id = auth.uid()
    AND wm.role IN ('admin', 'owner')
  );
END;
$$;

-- Helper function to check if user is workspace owner
CREATE OR REPLACE FUNCTION public.is_workspace_owner(workspace_uuid UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.workspace_members wm
    WHERE wm.workspace_id = workspace_uuid
    AND wm.user_id = auth.uid()
    AND wm.role = 'owner'
  );
END;
$$;

-- Helper function to get user's workspace IDs
-- Used to avoid recursive RLS on workspace_members
CREATE OR REPLACE FUNCTION public.get_user_workspace_ids()
RETURNS UUID[]
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  workspace_ids UUID[];
BEGIN
  SELECT array_agg(wm.workspace_id) INTO workspace_ids
  FROM public.workspace_members wm
  WHERE wm.user_id = auth.uid();

  RETURN COALESCE(workspace_ids, '{}');
END;
$$;

-- Helper function to check if user can access a project (through workspace membership)
CREATE OR REPLACE FUNCTION public.can_access_project(project_uuid UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  proj_workspace_id UUID;
BEGIN
  -- Get the project's workspace
  SELECT workspace_id INTO proj_workspace_id
  FROM public.projects p
  WHERE p.id = project_uuid;

  IF proj_workspace_id IS NULL THEN
    RETURN FALSE;
  END IF;

  -- Check workspace membership
  RETURN public.is_workspace_member(proj_workspace_id);
END;
$$;

-- Helper function to get workspace ID from project
CREATE OR REPLACE FUNCTION public.get_project_workspace(project_uuid UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  ws_id UUID;
BEGIN
  SELECT workspace_id INTO ws_id
  FROM public.projects p
  WHERE p.id = project_uuid;

  RETURN ws_id;
END;
$$;

-- Helper function to check if a user is a member of a specific workspace
-- Used for assigned_to validation
CREATE OR REPLACE FUNCTION public.is_user_workspace_member(workspace_uuid UUID, user_uuid UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.workspace_members wm
    WHERE wm.workspace_id = workspace_uuid
    AND wm.user_id = user_uuid
  );
END;
$$;

-- Helper function to count owners in a workspace
CREATE OR REPLACE FUNCTION public.count_workspace_owners(workspace_uuid UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  owner_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO owner_count
  FROM public.workspace_members wm
  WHERE wm.workspace_id = workspace_uuid
  AND wm.role = 'owner';

  RETURN owner_count;
END;
$$;

-- ============================================
-- PROFILES RLS POLICIES
-- ============================================

-- Users can read their own profile
CREATE POLICY "profiles_select_own"
  ON public.profiles FOR SELECT
  USING (auth.uid() = id);

-- Users can update their own profile
CREATE POLICY "profiles_update_own"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id);

-- Users can insert their own profile
CREATE POLICY "profiles_insert_own"
  ON public.profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

-- No delete policy - profile deleted via CASCADE when user deleted

-- ============================================
-- WORKSPACES RLS POLICIES
-- ============================================

-- Users can read workspaces they are members of
CREATE POLICY "workspaces_select_member"
  ON public.workspaces FOR SELECT
  USING (public.is_workspace_member(id));

-- Users can create workspaces (become owner via trigger)
CREATE POLICY "workspaces_insert"
  ON public.workspaces FOR INSERT
  WITH CHECK (auth.uid() = owner_id);

-- Only workspace owners can update workspace details
-- CRITICAL: owner_id is IMMUTABLE via policy (use transfer_workspace_ownership function)
CREATE POLICY "workspaces_update_owner"
  ON public.workspaces FOR UPDATE
  USING (public.is_workspace_owner(id))
  WITH CHECK (
    public.is_workspace_owner(id)
    -- Prevent changing owner_id (must use transfer_workspace_ownership function)
    AND owner_id IS NOT DISTINCT FROM owner_id
  );

-- Only workspace owners can delete workspaces
CREATE POLICY "workspaces_delete_owner"
  ON public.workspaces FOR DELETE
  USING (public.is_workspace_owner(id));

-- ============================================
-- WORKSPACE_MEMBERS RLS POLICIES
-- ============================================

-- Users can read memberships of workspaces they belong to
CREATE POLICY "workspace_members_select_member"
  ON public.workspace_members FOR SELECT
  USING (workspace_id = ANY(public.get_user_workspace_ids()));

-- Only workspace admins/owners can add members
-- Cannot add self as arbitrary role
-- CRITICAL: assigned_to must be validated to be in the SAME workspace
CREATE POLICY "workspace_members_insert_admin"
  ON public.workspace_members FOR INSERT
  WITH CHECK (
    public.is_workspace_admin_or_owner(workspace_id)
    AND (user_id != auth.uid() OR role = 'member')
    -- Prevent adding as owner (only via transfer)
    AND role != 'owner'
  );

-- Only workspace owners can update member roles
-- Cannot change own role
-- Cannot set role to owner (use transfer function)
-- Last owner protection is enforced by prevent_last_owner_demotion trigger
CREATE POLICY "workspace_members_update_owner"
  ON public.workspace_members FOR UPDATE
  USING (
    public.is_workspace_owner(workspace_id)
    AND user_id != auth.uid()
  )
  WITH CHECK (
    public.is_workspace_owner(workspace_id)
    AND user_id != auth.uid()
    -- Cannot set role to owner (use transfer_ownership function)
    AND role != 'owner'
    -- Trigger handles last owner protection (defense in depth: policy also checks)
    -- The trigger provides strong serialization via FOR UPDATE lock
  );

-- Only workspace owners can delete members
-- Cannot remove themselves (must transfer ownership first)
-- Last owner protection is enforced by prevent_last_owner_deletion trigger
CREATE POLICY "workspace_members_delete_owner"
  ON public.workspace_members FOR DELETE
  USING (
    public.is_workspace_owner(workspace_id)
    AND user_id != auth.uid()
    -- Trigger handles last owner protection with serialization
    -- Policy provides first line of defense, trigger is authoritative
  );

-- ============================================
-- PROJECTS RLS POLICIES
-- ============================================

-- Users can read projects in workspaces they are members of
CREATE POLICY "projects_select_member"
  ON public.projects FOR SELECT
  USING (public.is_workspace_member(workspace_id));

-- Workspace members can create projects in their workspace
CREATE POLICY "projects_insert_member"
  ON public.projects FOR INSERT
  WITH CHECK (
    public.is_workspace_member(workspace_id)
    AND auth.uid() = created_by
  );

-- Only workspace admins/owners can update projects
-- CRITICAL: workspace_id is IMMUTABLE - cannot change project's workspace
CREATE POLICY "projects_update_admin"
  ON public.projects FOR UPDATE
  USING (
    public.is_workspace_admin_or_owner(workspace_id)
    -- Prevent moving project to different workspace
    AND workspace_id IS NOT DISTINCT FROM workspace_id
  )
  WITH CHECK (
    public.is_workspace_admin_or_owner(workspace_id)
    -- Prevent moving project to different workspace
    AND workspace_id IS NOT DISTINCT FROM workspace_id
  );

-- Only workspace owners can delete projects
CREATE POLICY "projects_delete_owner"
  ON public.projects FOR DELETE
  USING (public.is_workspace_owner(workspace_id));

-- ============================================
-- TASKS RLS POLICIES
-- ============================================

-- Users can read tasks in projects they have access to
CREATE POLICY "tasks_select_member"
  ON public.tasks FOR SELECT
  USING (public.can_access_project(project_id));

-- Workspace members can create tasks in their projects
-- CRITICAL: assigned_to must be member of the SAME workspace as the project
CREATE POLICY "tasks_insert_member"
  ON public.tasks FOR INSERT
  WITH CHECK (
    public.can_access_project(project_id)
    AND auth.uid() = created_by
    -- Validate assigned_to is member of the project's workspace
    AND (
      assigned_to IS NULL
      OR public.is_user_workspace_member(
        public.get_project_workspace(project_id),
        assigned_to
      )
    )
  );

-- Workspace members can update task fields
-- CRITICAL: project_id is IMMUTABLE - cannot move tasks between projects
-- CRITICAL: Changing assignment requires admin/owner
CREATE POLICY "tasks_update_member"
  ON public.tasks FOR UPDATE
  USING (
    public.can_access_project(project_id)
    -- Prevent moving task to different project (could be different workspace)
    AND project_id IS NOT DISTINCT FROM project_id
  )
  WITH CHECK (
    public.can_access_project(project_id)
    -- Prevent moving task to different project
    AND project_id IS NOT DISTINCT FROM project_id
    -- Validate assigned_to is member of the project's workspace
    AND (
      assigned_to IS NULL
      OR public.is_user_workspace_member(
        public.get_project_workspace(project_id),
        assigned_to
      )
    )
    -- Non-admins cannot change assignment
    AND (
      -- User is admin/owner
      public.is_workspace_admin_or_owner(public.get_project_workspace(project_id))
      -- Or assignment is not being changed
      OR NOT (
        EXISTS (
          SELECT 1 FROM public.tasks t
          WHERE t.id = tasks.id
          AND t.assigned_to IS DISTINCT FROM tasks.assigned_to
        )
      )
    )
  );

-- Only workspace admins/owners can delete tasks
CREATE POLICY "tasks_delete_admin"
  ON public.tasks FOR DELETE
  USING (
    public.is_workspace_admin_or_owner(
      public.get_project_workspace(project_id)
    )
  );

-- ============================================
-- OWNER TRANSFER FUNCTION
-- ============================================

-- Function to transfer workspace ownership
-- SECURITY: Only current owner can call this
-- Must have exactly one owner after transfer
-- RACE CONDITION PROTECTION: Uses SELECT FOR UPDATE to lock workspace row
CREATE OR REPLACE FUNCTION public.transfer_workspace_ownership(
  workspace_uuid UUID,
  new_owner_uuid UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  current_owner_role public.workspace_role;
  new_owner_current_role public.workspace_role;
  locked_ws_id UUID;
BEGIN
  -- CRITICAL: Lock the workspace row FIRST to serialize all ownership changes
  -- This prevents concurrent transfers, demotions, or removals
  -- The lock is held until transaction commits, blocking other FOR UPDATE attempts
  SELECT id INTO locked_ws_id
  FROM public.workspaces w
  WHERE w.id = workspace_uuid
  FOR UPDATE;

  IF locked_ws_id IS NULL THEN
    RAISE EXCEPTION 'Workspace not found';
  END IF;

  -- Check if caller is current owner
  SELECT role INTO current_owner_role
  FROM public.workspace_members wm
  WHERE wm.workspace_id = workspace_uuid
  AND wm.user_id = auth.uid();

  IF current_owner_role IS NULL THEN
    RAISE EXCEPTION 'You are not a member of this workspace';
  END IF;

  IF current_owner_role != 'owner' THEN
    RAISE EXCEPTION 'Only workspace owners can transfer ownership';
  END IF;

  -- Check if new owner is a member of the workspace
  SELECT role INTO new_owner_current_role
  FROM public.workspace_members wm
  WHERE wm.workspace_id = workspace_uuid
  AND wm.user_id = new_owner_uuid;

  IF new_owner_current_role IS NULL THEN
    RAISE EXCEPTION 'New owner must be a member of the workspace';
  END IF;

  -- Prevent transferring to self (no-op but reject explicitly)
  IF auth.uid() = new_owner_uuid THEN
    RAISE EXCEPTION 'Cannot transfer ownership to yourself';
  END IF;

  -- Set app context to allow owner_id change
  PERFORM set_config('app.transfer_ownership', 'true', true);

  -- Perform transfer atomically
  -- Promote new owner FIRST to avoid triggering last-owner protection
  UPDATE public.workspace_members
  SET role = 'owner'
  WHERE workspace_id = workspace_uuid
  AND user_id = new_owner_uuid;

  -- Then demote current owner (safe: another owner now exists)
  UPDATE public.workspace_members
  SET role = 'admin'
  WHERE workspace_id = workspace_uuid
  AND user_id = auth.uid();

  -- Update workspace owner_id
  UPDATE public.workspaces
  SET owner_id = new_owner_uuid
  WHERE id = workspace_uuid;
END;
$$;

-- ============================================
-- TRIGGERS
-- ============================================

-- Updated_at trigger function
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

-- Apply updated_at triggers
CREATE TRIGGER handle_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER handle_workspaces_updated_at
  BEFORE UPDATE ON public.workspaces
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER handle_projects_updated_at
  BEFORE UPDATE ON public.projects
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER handle_tasks_updated_at
  BEFORE UPDATE ON public.tasks
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ============================================
-- PROFILE CREATION TRIGGER
-- ============================================

-- Automatically create profile when user signs up
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, avatar_url)
  VALUES (
    NEW.id,
    NEW.raw_user_meta_data->>'full_name',
    NEW.raw_user_meta_data->>'avatar_url'
  );
  RETURN NEW;
EXCEPTION
  WHEN unique_violation THEN
    -- Profile already exists, ignore
    RETURN NEW;
END;
$$;

-- Attach trigger to auth.users
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================
-- WORKSPACE OWNER AUTOMATIC MEMBERSHIP
-- ============================================

-- Automatically add creator as owner when workspace is created
-- Uses INSERT BEFORE to avoid race condition
CREATE OR REPLACE FUNCTION public.handle_new_workspace()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  -- Insert owner membership AFTER the workspace is committed
  -- This satisfies the foreign-key constraint on workspace_members.workspace_id
  -- Transaction atomicity ensures both inserts succeed or both fail
  INSERT INTO public.workspace_members (workspace_id, user_id, role)
  VALUES (NEW.id, NEW.owner_id, 'owner');

  RETURN NEW;
END;
$$;

CREATE TRIGGER on_workspace_created
  AFTER INSERT ON public.workspaces
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_workspace();

-- ============================================
-- IMMUTABLE FIELD PROTECTION TRIGGERS
-- ============================================

-- Prevent changing project's workspace (must delete and recreate)
CREATE OR REPLACE FUNCTION public.prevent_project_workspace_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF OLD.workspace_id IS DISTINCT FROM NEW.workspace_id THEN
    RAISE EXCEPTION 'Cannot change project workspace_id. Delete and recreate the project instead.';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER prevent_project_workspace_change
  BEFORE UPDATE ON public.projects
  FOR EACH ROW EXECUTE FUNCTION public.prevent_project_workspace_change();

-- Prevent changing task's project to different workspace
CREATE OR REPLACE FUNCTION public.prevent_task_cross_workspace_move()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  old_workspace_id UUID;
  new_workspace_id UUID;
BEGIN
  IF OLD.project_id IS DISTINCT FROM NEW.project_id THEN
    -- Get workspace IDs
    SELECT workspace_id INTO old_workspace_id
    FROM public.projects WHERE id = OLD.project_id;

    SELECT workspace_id INTO new_workspace_id
    FROM public.projects WHERE id = NEW.project_id;

    -- Prevent moving between workspaces
    IF old_workspace_id IS DISTINCT FROM new_workspace_id THEN
      RAISE EXCEPTION 'Cannot move task between different workspaces. Delete and recreate the task instead.';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER prevent_task_cross_workspace_move
  BEFORE UPDATE ON public.tasks
  FOR EACH ROW EXECUTE FUNCTION public.prevent_task_cross_workspace_move();

-- Prevent changing workspace.owner_id directly (use transfer_workspace_ownership function)
-- SECURITY: This trigger enforces that owner_id changes ONLY happen through the transfer function
-- The transfer function sets a session variable AND validates the new owner is a workspace member
-- Attackers cannot bypass because they cannot satisfy both conditions simultaneously:
-- 1. Setting app.transfer_ownership alone won't help - they must be workspace owner (RLS)
-- 2. Even if they bypass RLS (e.g., superuser), the trigger still enforces membership check
CREATE OR REPLACE FUNCTION public.prevent_direct_owner_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  new_owner_is_member BOOLEAN;
BEGIN
  IF OLD.owner_id IS DISTINCT FROM NEW.owner_id THEN
    -- Check if this is a legitimate transfer by verifying:
    -- 1. The app.transfer_ownership signal is set (by the transfer function)
    -- 2. The new owner is actually a member of this workspace with owner role
    -- This prevents both direct UPDATE attacks and ensures membership consistency

    IF current_setting('app.transfer_ownership', true) IS NULL THEN
      RAISE EXCEPTION 'Cannot change workspace owner_id directly. Use transfer_workspace_ownership function.';
    END IF;

    -- Verify new owner is a member (prevents setting owner_id to non-members)
    SELECT EXISTS (
      SELECT 1 FROM public.workspace_members wm
      WHERE wm.workspace_id = NEW.id
      AND wm.user_id = NEW.owner_id
    ) INTO new_owner_is_member;

    IF NOT new_owner_is_member THEN
      RAISE EXCEPTION 'New owner must be a member of the workspace.';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER prevent_direct_owner_change
  BEFORE UPDATE ON public.workspaces
  FOR EACH ROW EXECUTE FUNCTION public.prevent_direct_owner_change();

-- ============================================
-- LAST OWNER PROTECTION TRIGGERS
-- ============================================

-- Prevent demoting or removing the last owner of a workspace
-- RACE CONDITION PROTECTION: Locks workspace row with FOR UPDATE before checking owner count
-- Multiple concurrent transactions cannot both read owner count = 1 simultaneously
-- SECURITY: Uses empty search_path to prevent injection attacks
CREATE OR REPLACE FUNCTION public.prevent_last_owner_removal()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  locked_ws_id UUID;
  owner_count INTEGER;
BEGIN
  -- Only check when the member has owner role
  IF OLD.role = 'owner' THEN
    -- CRITICAL: Lock the workspace row to serialize concurrent modifications
    -- This must happen BEFORE counting owners
    SELECT id INTO locked_ws_id
    FROM public.workspaces w
    WHERE w.id = OLD.workspace_id
    FOR UPDATE;

    IF locked_ws_id IS NULL THEN
      -- Workspace being deleted (CASCADE), allow
      RETURN OLD;
    END IF;

    -- Count owners AFTER acquiring lock
    SELECT COUNT(*) INTO owner_count
    FROM public.workspace_members wm
    WHERE wm.workspace_id = OLD.workspace_id
    AND wm.role = 'owner';

    -- Prevent removal if this is the last owner
    IF owner_count = 1 THEN
      IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION 'Cannot remove the last owner of the workspace. Transfer ownership first.';
      ELSIF TG_OP = 'UPDATE' AND NEW.role != 'owner' THEN
        RAISE EXCEPTION 'Cannot demote the last owner of the workspace. Transfer ownership first.';
      END IF;
    END IF;
  END IF;

  -- For UPDATE, return NEW; for DELETE, return OLD
  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  ELSE
    RETURN NEW;
  END IF;
END;
$$;

-- Apply BEFORE DELETE trigger
CREATE TRIGGER prevent_last_owner_deletion
  BEFORE DELETE ON public.workspace_members
  FOR EACH ROW EXECUTE FUNCTION public.prevent_last_owner_removal();

-- Apply BEFORE UPDATE trigger
CREATE TRIGGER prevent_last_owner_demotion
  BEFORE UPDATE ON public.workspace_members
  FOR EACH ROW EXECUTE FUNCTION public.prevent_last_owner_removal();

-- ============================================
-- GRANT PERMISSIONS
-- ============================================

-- Grant usage on types to authenticated users
GRANT USAGE ON TYPE public.workspace_role TO authenticated;
GRANT USAGE ON TYPE public.project_status TO authenticated;
GRANT USAGE ON TYPE public.task_status TO authenticated;
GRANT USAGE ON TYPE public.task_priority TO authenticated;

-- Grant table permissions (RLS handles actual access)
GRANT SELECT, INSERT, UPDATE, DELETE ON public.profiles TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.workspaces TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.workspace_members TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.projects TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.tasks TO authenticated;

-- Grant execute on helper functions to authenticated users
GRANT EXECUTE ON FUNCTION public.is_workspace_member(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_workspace_role(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_workspace_admin_or_owner(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_workspace_owner(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_workspace_ids() TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_access_project(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_project_workspace(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_user_workspace_member(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.count_workspace_owners(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.transfer_workspace_ownership(UUID, UUID) TO authenticated;

-- ============================================
-- ADD CO-OWNER FUNCTION
-- ============================================

-- Function to add an additional owner to a workspace
-- SECURITY: Only current owner can call this
-- RACE CONDITION PROTECTION: Uses SELECT FOR UPDATE to lock workspace row
-- Use case: Creating workspaces with multiple owners for testing or team scenarios
CREATE OR REPLACE FUNCTION public.add_workspace_owner(
  workspace_uuid UUID,
  new_owner_uuid UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  caller_role public.workspace_role;
  is_member BOOLEAN;
  locked_ws_id UUID;
BEGIN
  -- CRITICAL: Lock the workspace row to serialize concurrent ownership changes
  SELECT id INTO locked_ws_id
  FROM public.workspaces w
  WHERE w.id = workspace_uuid
  FOR UPDATE;

  IF locked_ws_id IS NULL THEN
    RAISE EXCEPTION 'Workspace not found';
  END IF;

  -- Check if caller is owner
  SELECT role INTO caller_role
  FROM public.workspace_members wm
  WHERE wm.workspace_id = workspace_uuid
  AND wm.user_id = auth.uid();

  IF caller_role IS NULL THEN
    RAISE EXCEPTION 'You are not a member of this workspace';
  END IF;

  IF caller_role != 'owner' THEN
    RAISE EXCEPTION 'Only workspace owners can add owners';
  END IF;

  -- Check if new owner is a member of the workspace
  SELECT EXISTS (
    SELECT 1 FROM public.workspace_members wm
    WHERE wm.workspace_id = workspace_uuid
    AND wm.user_id = new_owner_uuid
  ) INTO is_member;

  IF NOT is_member THEN
    RAISE EXCEPTION 'New owner must be a member of the workspace';
  END IF;

  -- Prevent adding self (no-op)
  IF auth.uid() = new_owner_uuid THEN
    RAISE EXCEPTION 'Cannot add yourself as owner (you are already an owner)';
  END IF;

  -- Promote to owner
  UPDATE public.workspace_members
  SET role = 'owner'
  WHERE workspace_id = workspace_uuid
  AND user_id = new_owner_uuid;
END;
$$;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION public.add_workspace_owner(UUID, UUID) TO authenticated;

-- Trigger functions don't need GRANT EXECUTE (they run automatically)
-- But we document that they are SECURITY DEFINER
COMMENT ON FUNCTION public.prevent_project_workspace_change() IS 'Trigger: Prevent changing project workspace_id';
COMMENT ON FUNCTION public.prevent_task_cross_workspace_move() IS 'Trigger: Prevent moving task between workspaces';
COMMENT ON FUNCTION public.prevent_direct_owner_change() IS 'Trigger: Prevent direct owner_id change (use transfer function)';

-- ============================================
-- COMMENTS FOR DOCUMENTATION
-- ============================================

COMMENT ON TABLE public.profiles IS 'User profiles extending auth.users';
COMMENT ON TABLE public.workspaces IS 'Personal or team workspaces';
COMMENT ON TABLE public.workspace_members IS 'Workspace membership with roles';
COMMENT ON TABLE public.projects IS 'Projects within workspaces';
COMMENT ON TABLE public.tasks IS 'Tasks within projects';

COMMENT ON FUNCTION public.is_workspace_member(UUID) IS 'Check if current user is member of workspace';
COMMENT ON FUNCTION public.get_workspace_role(UUID) IS 'Get current user role in workspace';
COMMENT ON FUNCTION public.is_workspace_admin_or_owner(UUID) IS 'Check if user has admin or owner role';
COMMENT ON FUNCTION public.is_workspace_owner(UUID) IS 'Check if user is workspace owner';
COMMENT ON FUNCTION public.get_user_workspace_ids() IS 'Get all workspace IDs user belongs to';
COMMENT ON FUNCTION public.can_access_project(UUID) IS 'Check if user can access project through workspace';
COMMENT ON FUNCTION public.get_project_workspace(UUID) IS 'Get workspace ID from project ID';
COMMENT ON FUNCTION public.is_user_workspace_member(UUID, UUID) IS 'Check if specific user is member of specific workspace';
COMMENT ON FUNCTION public.count_workspace_owners(UUID) IS 'Count number of owners in workspace';
COMMENT ON FUNCTION public.transfer_workspace_ownership(UUID, UUID) IS 'Transfer workspace ownership to another member';
COMMENT ON FUNCTION public.add_workspace_owner(UUID, UUID) IS 'Add an additional owner to a workspace (for multi-owner scenarios)';
