-- ClearTime Foundation Rebuild
-- 1. Local-AI activities (child-owned, one per day), overdue expiration.
-- 2. Approved report snapshots shared with linked parents only.
-- 3. Private proof storage bucket with per-mission policies.
-- 4. Report request queue (durable) with authenticated, idempotent commands.
-- 5. Realtime publication for missions, lifecycle events, report requests,
--    and approved reports.
-- Raw usage, private chats, and reflections are deliberately NOT represented
-- here and never sync.

-- ==============================================================================
-- 1. Local-AI activities
-- ==============================================================================

-- Mark a child's overdue activities as expired. Only the child's own
-- activities are affected.
CREATE OR REPLACE FUNCTION public.expire_overdue_missions()
RETURNS SETOF public.missions AS $$
BEGIN
    RETURN QUERY
    UPDATE public.missions m
    SET status = 'expired', state_version = m.state_version + 1, updated_at = now()
    WHERE m.due_at IS NOT NULL AND m.due_at < now()
      AND m.status IN ('assigned', 'started', 'needs_retry')
      AND m.assigned_to_child_id IN (
          SELECT id FROM public.child_profiles WHERE user_id = auth.uid()
      )
    RETURNING m.*;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Child-owned AI activity. Direct auto-assignment: no default reward, no
-- proof requirement. Limited to one new AI activity per child per day unless
-- the previous one is finished or expired.
CREATE OR REPLACE FUNCTION public.create_local_ai_mission(
    p_title TEXT,
    p_description TEXT DEFAULT '',
    p_target_minutes INTEGER DEFAULT 30,
    p_due_at TIMESTAMPTZ DEFAULT NULL
)
RETURNS public.missions AS $$
DECLARE
    v_child_id UUID;
    v_mission public.missions;
BEGIN
    IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;

    SELECT id INTO v_child_id FROM public.child_profiles WHERE user_id = auth.uid();
    IF v_child_id IS NULL THEN RAISE EXCEPTION 'Only a child device can create an AI activity'; END IF;

    IF EXISTS (
        SELECT 1 FROM public.missions
        WHERE assigned_to_child_id = v_child_id
          AND source = 'local_ai'
          AND created_at::date = CURRENT_DATE
          AND status NOT IN ('approved', 'expired')
          AND NOT (due_at IS NOT NULL AND due_at < now())
    ) THEN
        RAISE EXCEPTION 'A new AI activity was already created today';
    END IF;

    INSERT INTO public.missions (
        family_id, assigned_by_user_id, assigned_to_child_id, title, description,
        source, target_minutes, due_at, proof_requirement
    ) VALUES (
        (SELECT family_id FROM public.child_profiles WHERE id = v_child_id),
        auth.uid(), v_child_id, trim(p_title), COALESCE(p_description, ''),
        'local_ai', GREATEST(p_target_minutes, 1), p_due_at, 'noProof'
    ) RETURNING * INTO v_mission;

    INSERT INTO public.mission_lifecycle_events
        (mission_id, family_id, recipient_user_id, event_type, idempotency_key)
    VALUES (v_mission.id, v_mission.family_id, auth.uid(), 'NEW_TASK',
            'NEW_TASK:' || v_mission.id)
    ON CONFLICT (idempotency_key) DO NOTHING;

    RETURN v_mission;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Authorized child profile edits (nickname/age/avatar only).
CREATE OR REPLACE FUNCTION public.update_child_profile(
    p_nickname TEXT DEFAULT NULL,
    p_age INTEGER DEFAULT NULL,
    p_avatar_index INTEGER DEFAULT NULL
)
RETURNS public.child_profiles AS $$
DECLARE
    v_profile public.child_profiles;
BEGIN
    IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;
    UPDATE public.child_profiles
    SET nickname = CASE WHEN p_nickname IS NOT NULL AND length(trim(p_nickname)) > 0
                        THEN trim(p_nickname) ELSE nickname END,
        age = COALESCE(p_age, age),
        avatar_index = COALESCE(p_avatar_index, avatar_index),
        updated_at = now()
    WHERE user_id = auth.uid()
    RETURNING * INTO v_profile;
    IF v_profile.id IS NULL THEN RAISE EXCEPTION 'Child profile not found'; END IF;
    RETURN v_profile;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==============================================================================
-- 2. Approved reports (privacy-filtered snapshots shared with linked parents)
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.approved_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL REFERENCES public.families(id) ON DELETE CASCADE,
    child_id UUID NOT NULL REFERENCES public.child_profiles(id) ON DELETE CASCADE,
    created_by_user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    period TEXT NOT NULL CHECK (period IN ('daily', 'weekly', 'monthly')),
    period_start TIMESTAMPTZ NOT NULL,
    period_end TIMESTAMPTZ NOT NULL,
    detail_level TEXT NOT NULL DEFAULT 'summary',
    facts JSONB NOT NULL DEFAULT '{}',
    understand_act JSONB NOT NULL DEFAULT '{}',
    categories TEXT[] NOT NULL DEFAULT '{}',
    versions JSONB NOT NULL DEFAULT '{}',
    is_snapshot BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_approved_report UNIQUE (child_id, period, period_start)
);
CREATE INDEX IF NOT EXISTS idx_approved_reports_child
    ON public.approved_reports(child_id, period, created_at DESC);

ALTER TABLE public.approved_reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Child or linked parent can read approved reports"
    ON public.approved_reports FOR SELECT
    USING (public.can_access_child(child_id));

CREATE POLICY "Child device uploads own approved reports"
    ON public.approved_reports FOR INSERT
    WITH CHECK (
        created_by_user_id = auth.uid()
        AND EXISTS (
            SELECT 1 FROM public.child_profiles cp
            WHERE cp.id = child_id AND cp.user_id = auth.uid()
        )
    );

-- ==============================================================================
-- 3. Private proof storage bucket
--    Object path convention: {mission_id}/{file_name}
-- ==============================================================================

INSERT INTO storage.buckets (id, name, public)
VALUES ('mission-proofs', 'mission-proofs', false)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "Child uploads proof for own missions"
    ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (
        bucket_id = 'mission-proofs'
        AND EXISTS (
            SELECT 1
            FROM public.missions m
            JOIN public.child_profiles cp ON cp.id = m.assigned_to_child_id
            WHERE m.id = ((storage.foldername(name))[1])::uuid
              AND cp.user_id = auth.uid()
        )
    );

CREATE POLICY "Child replaces proof for own missions"
    ON storage.objects FOR UPDATE TO authenticated
    USING (
        bucket_id = 'mission-proofs'
        AND EXISTS (
            SELECT 1
            FROM public.missions m
            JOIN public.child_profiles cp ON cp.id = m.assigned_to_child_id
            WHERE m.id = ((storage.foldername(name))[1])::uuid
              AND cp.user_id = auth.uid()
        )
    )
    WITH CHECK (
        bucket_id = 'mission-proofs'
        AND EXISTS (
            SELECT 1
            FROM public.missions m
            JOIN public.child_profiles cp ON cp.id = m.assigned_to_child_id
            WHERE m.id = ((storage.foldername(name))[1])::uuid
              AND cp.user_id = auth.uid()
        )
    );

CREATE POLICY "Child deletes proof for own missions"
    ON storage.objects FOR DELETE TO authenticated
    USING (
        bucket_id = 'mission-proofs'
        AND EXISTS (
            SELECT 1
            FROM public.missions m
            JOIN public.child_profiles cp ON cp.id = m.assigned_to_child_id
            WHERE m.id = ((storage.foldername(name))[1])::uuid
              AND cp.user_id = auth.uid()
        )
    );

CREATE POLICY "Linked parent reads mission proof"
    ON storage.objects FOR SELECT TO authenticated
    USING (
        bucket_id = 'mission-proofs'
        AND public.can_access_child((
            SELECT m.assigned_to_child_id
            FROM public.missions m
            WHERE m.id = ((storage.foldername(name))[1])::uuid
        ))
    );

-- ==============================================================================
-- 4. Report requests (durable queue)
-- ==============================================================================

ALTER TABLE public.report_requests DROP CONSTRAINT IF EXISTS report_requests_status_check;
UPDATE public.report_requests SET status = 'preparing' WHERE status = 'pending';
UPDATE public.report_requests SET status = 'waiting_for_child' WHERE status = 'processing';
ALTER TABLE public.report_requests ADD CONSTRAINT report_requests_status_check
    CHECK (status IN ('preparing', 'waiting_for_child', 'ready', 'unavailable', 'failed'));

-- Linked parent requests a report for a child. Idempotent: an open request
-- for the same child and period on the same day is returned instead of
-- duplicated.
CREATE OR REPLACE FUNCTION public.request_approved_report(
    p_child_id UUID,
    p_period TEXT DEFAULT 'daily'
)
RETURNS public.report_requests AS $$
DECLARE
    v_request public.report_requests;
BEGIN
    IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;
    IF p_period NOT IN ('daily', 'weekly', 'monthly') THEN
        RAISE EXCEPTION 'Invalid report period';
    END IF;
    IF NOT public.can_access_child(p_child_id) THEN
        RAISE EXCEPTION 'Requester is not linked to this child';
    END IF;

    SELECT * INTO v_request FROM public.report_requests
    WHERE child_id = p_child_id AND period = p_period
      AND status IN ('preparing', 'waiting_for_child')
      AND requested_at::date = CURRENT_DATE
    ORDER BY requested_at DESC LIMIT 1;
    IF v_request.id IS NOT NULL THEN RETURN v_request; END IF;

    INSERT INTO public.report_requests
        (family_id, child_id, requested_by_user_id, period, status)
    VALUES (
        (SELECT family_id FROM public.child_profiles WHERE id = p_child_id),
        p_child_id, auth.uid(), p_period, 'preparing'
    )
    RETURNING * INTO v_request;
    RETURN v_request;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Child device acknowledges the request (it is now waiting on generation).
CREATE OR REPLACE FUNCTION public.ack_report_request(p_request_id UUID)
RETURNS public.report_requests AS $$
DECLARE
    v_request public.report_requests;
BEGIN
    IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;
    UPDATE public.report_requests
    SET status = 'waiting_for_child'
    WHERE id = p_request_id
      AND status = 'preparing'
      AND child_id IN (SELECT id FROM public.child_profiles WHERE user_id = auth.uid())
    RETURNING * INTO v_request;
    IF v_request.id IS NULL THEN RAISE EXCEPTION 'Report request cannot be acknowledged'; END IF;
    RETURN v_request;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Child device finishes the request with a truthful outcome.
CREATE OR REPLACE FUNCTION public.complete_report_request(
    p_request_id UUID,
    p_status TEXT,
    p_report_id TEXT DEFAULT NULL,
    p_failure_reason TEXT DEFAULT NULL
)
RETURNS public.report_requests AS $$
DECLARE
    v_request public.report_requests;
BEGIN
    IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;
    IF p_status NOT IN ('ready', 'unavailable', 'failed') THEN
        RAISE EXCEPTION 'Invalid completion status';
    END IF;
    UPDATE public.report_requests
    SET status = p_status,
        completed_at = now(),
        report_id = COALESCE(p_report_id, report_id),
        failure_reason = NULLIF(trim(COALESCE(p_failure_reason, '')), '')
    WHERE id = p_request_id
      AND child_id IN (SELECT id FROM public.child_profiles WHERE user_id = auth.uid())
    RETURNING * INTO v_request;
    IF v_request.id IS NULL THEN RAISE EXCEPTION 'Report request cannot be completed'; END IF;
    RETURN v_request;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==============================================================================
-- 5. Realtime publication
-- ==============================================================================

DO $$
BEGIN
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.missions;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.mission_lifecycle_events;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.report_requests;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.approved_reports;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
END $$;
