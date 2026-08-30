-- ClearTime Database Migration: Family Deletion, RLS and CRUD Fixes
-- Migration: 20260901000000_fix_family_deletion_and_crud.sql

-- ==============================================================================
-- 1. FAMILIES TABLE: RLS DELETE POLICY & ATOMIC DELETE RPC
-- ==============================================================================

DROP POLICY IF EXISTS "Admins can delete their family" ON public.families;
CREATE POLICY "Admins can delete their family"
    ON public.families FOR DELETE
    USING (admin_user_id = auth.uid() OR public.is_family_admin(id));

-- Atomic procedure to safely and completely delete a family hub and its dependencies
CREATE OR REPLACE FUNCTION public.delete_family_hub(
    p_family_id UUID
)
RETURNS BOOLEAN AS $$
DECLARE
    v_user_id UUID;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required';
    END IF;

    -- Security Check: Caller must be the family creator or an ADMIN member
    IF NOT (
        EXISTS (SELECT 1 FROM public.families WHERE id = p_family_id AND admin_user_id = v_user_id)
        OR EXISTS (SELECT 1 FROM public.family_members WHERE family_id = p_family_id AND user_id = v_user_id AND role = 'ADMIN')
    ) THEN
        RAISE EXCEPTION 'Only family administrators are authorized to delete this family group';
    END IF;

    -- Explicit cascade cleanup for safety
    DELETE FROM public.mission_lifecycle_events WHERE family_id = p_family_id;
    DELETE FROM public.report_requests WHERE family_id = p_family_id;
    DELETE FROM public.approved_reports WHERE family_id = p_family_id;
    DELETE FROM public.mission_rewards WHERE child_id IN (SELECT id FROM public.child_profiles WHERE family_id = p_family_id);
    DELETE FROM public.missions WHERE family_id = p_family_id;
    DELETE FROM public.trigger_configurations WHERE family_id = p_family_id;
    DELETE FROM public.report_configurations WHERE family_id = p_family_id;
    DELETE FROM public.privacy_settings WHERE family_id = p_family_id;
    DELETE FROM public.device_pairings WHERE family_id = p_family_id;
    DELETE FROM public.family_invitations WHERE family_id = p_family_id;
    DELETE FROM public.parent_child_relationships WHERE family_id = p_family_id;
    DELETE FROM public.child_profiles WHERE family_id = p_family_id;
    DELETE FROM public.family_members WHERE family_id = p_family_id;
    DELETE FROM public.families WHERE id = p_family_id;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==============================================================================
-- 2. MISSIONS & REWARDS RLS POLICIES & PROCEDURES
-- ==============================================================================

DROP POLICY IF EXISTS "Linked parent or assigned child can delete missions" ON public.missions;
CREATE POLICY "Linked parent or assigned child can delete missions"
    ON public.missions FOR DELETE
    USING (
        assigned_by_user_id = auth.uid()
        OR public.can_access_child(assigned_to_child_id)
    );

DROP POLICY IF EXISTS "Linked parent or assigned child can update missions" ON public.missions;
CREATE POLICY "Linked parent or assigned child can update missions"
    ON public.missions FOR UPDATE
    USING (
        assigned_by_user_id = auth.uid()
        OR public.can_access_child(assigned_to_child_id)
    );

DROP POLICY IF EXISTS "Linked parent can insert missions" ON public.missions;
CREATE POLICY "Linked parent can insert missions"
    ON public.missions FOR INSERT
    WITH CHECK (
        assigned_by_user_id = auth.uid()
        OR public.can_access_child(assigned_to_child_id)
    );

-- Reward cancellation RPC
CREATE OR REPLACE FUNCTION public.cancel_mission_reward(
    p_reward_id UUID
)
RETURNS public.mission_rewards AS $$
DECLARE
    v_reward public.mission_rewards;
BEGIN
    IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;

    UPDATE public.mission_rewards
    SET status = 'cancelled',
        cancelled_at = now()
    WHERE id = p_reward_id
      AND parent_user_id = auth.uid()
      AND status = 'locked'
    RETURNING * INTO v_reward;

    IF v_reward.id IS NULL THEN
        RAISE EXCEPTION 'Reward not found or cannot be cancelled';
    END IF;

    RETURN v_reward;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==============================================================================
-- 3. CHILD PROFILES DELETE RLS & RPC
-- ==============================================================================

DROP POLICY IF EXISTS "Parent admin can delete child profile" ON public.child_profiles;
CREATE POLICY "Parent admin can delete child profile"
    ON public.child_profiles FOR DELETE
    USING (public.is_family_admin(family_id));

-- Stored procedure to delete child profile and cascade cleanly
CREATE OR REPLACE FUNCTION public.delete_child_profile(
    p_child_id UUID
)
RETURNS BOOLEAN AS $$
DECLARE
    v_user_id UUID;
    v_family_id UUID;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;

    SELECT family_id INTO v_family_id FROM public.child_profiles WHERE id = p_child_id;
    IF v_family_id IS NULL THEN RAISE EXCEPTION 'Child profile not found'; END IF;

    IF NOT (public.is_family_admin(v_family_id) OR EXISTS (
        SELECT 1 FROM public.child_profiles WHERE id = p_child_id AND user_id = v_user_id
    )) THEN
        RAISE EXCEPTION 'Unauthorized to delete child profile';
    END IF;

    DELETE FROM public.mission_lifecycle_events WHERE mission_id IN (SELECT id FROM public.missions WHERE assigned_to_child_id = p_child_id);
    DELETE FROM public.mission_rewards WHERE child_id = p_child_id;
    DELETE FROM public.missions WHERE assigned_to_child_id = p_child_id;
    DELETE FROM public.report_requests WHERE child_id = p_child_id;
    DELETE FROM public.approved_reports WHERE child_id = p_child_id;
    DELETE FROM public.parent_child_relationships WHERE child_profile_id = p_child_id;
    DELETE FROM public.child_profiles WHERE id = p_child_id;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==============================================================================
-- 4. RELOAD POSTGREST CACHE
-- ==============================================================================
NOTIFY pgrst, 'reload schema';
NOTIFY pgrst, 'reload config';
