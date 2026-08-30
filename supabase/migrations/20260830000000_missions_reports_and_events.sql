-- ClearTime Phase 2: durable cross-device activities, lifecycle events, and
-- privacy-safe report requests. Raw device activity and private reflections
-- are deliberately not represented in this schema.

CREATE TABLE IF NOT EXISTS public.missions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL REFERENCES public.families(id) ON DELETE CASCADE,
    assigned_by_user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    assigned_to_child_id UUID NOT NULL REFERENCES public.child_profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL CHECK (length(trim(title)) > 0),
    description TEXT NOT NULL DEFAULT '',
    source TEXT NOT NULL DEFAULT 'parent' CHECK (source IN ('parent', 'local_ai')),
    target_minutes INTEGER NOT NULL CHECK (target_minutes > 0),
    current_minutes INTEGER NOT NULL DEFAULT 0 CHECK (current_minutes >= 0),
    status TEXT NOT NULL DEFAULT 'assigned' CHECK (status IN ('assigned', 'started', 'submitted', 'approved', 'needs_retry', 'expired')),
    due_at TIMESTAMPTZ,
    proof_requirement TEXT NOT NULL DEFAULT 'noProof',
    proof_media_path TEXT,
    proof_media_type TEXT,
    submission_notes TEXT,
    parent_feedback TEXT,
    started_at TIMESTAMPTZ,
    submitted_at TIMESTAMPTZ,
    approved_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    state_version INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_missions_child_status
    ON public.missions(assigned_to_child_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_missions_parent_status
    ON public.missions(assigned_by_user_id, status, created_at DESC);

CREATE TABLE IF NOT EXISTS public.mission_rewards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    mission_id UUID NOT NULL UNIQUE REFERENCES public.missions(id) ON DELETE CASCADE,
    parent_user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    child_id UUID NOT NULL REFERENCES public.child_profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL CHECK (length(trim(title)) > 0),
    description TEXT,
    status TEXT NOT NULL DEFAULT 'locked' CHECK (status IN ('locked', 'unlocked', 'redeemed', 'cancelled')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    unlocked_at TIMESTAMPTZ,
    redeemed_at TIMESTAMPTZ,
    redeemed_by_user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    cancelled_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_mission_rewards_child ON public.mission_rewards(child_id, status);

CREATE TABLE IF NOT EXISTS public.mission_lifecycle_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    mission_id UUID NOT NULL REFERENCES public.missions(id) ON DELETE CASCADE,
    family_id UUID NOT NULL REFERENCES public.families(id) ON DELETE CASCADE,
    recipient_user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    event_type TEXT NOT NULL CHECK (event_type IN ('NEW_TASK', 'TASK_STARTED', 'TASK_COMPLETED', 'TASK_APPROVED', 'TASK_NEEDS_RETRY', 'REWARD_UNLOCKED')),
    idempotency_key TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    read_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_mission_events_recipient
    ON public.mission_lifecycle_events(recipient_user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS public.report_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL REFERENCES public.families(id) ON DELETE CASCADE,
    child_id UUID NOT NULL REFERENCES public.child_profiles(id) ON DELETE CASCADE,
    requested_by_user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    period TEXT NOT NULL CHECK (period IN ('daily', 'weekly', 'monthly')),
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'ready', 'unavailable', 'failed')),
    requested_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at TIMESTAMPTZ,
    report_id TEXT,
    failure_reason TEXT
);
CREATE INDEX IF NOT EXISTS idx_report_requests_child_status
    ON public.report_requests(child_id, status, requested_at DESC);

ALTER TABLE public.missions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mission_rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mission_lifecycle_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.report_requests ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.can_access_child(p_child_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (SELECT 1 FROM public.child_profiles cp WHERE cp.id = p_child_id AND cp.user_id = auth.uid())
      OR EXISTS (
          SELECT 1
          FROM public.parent_child_relationships rel
          JOIN public.parent_profiles pp ON pp.id = rel.parent_profile_id
          WHERE rel.child_profile_id = p_child_id AND pp.user_id = auth.uid()
      );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

CREATE POLICY "Assigned child or linked parent can read missions"
    ON public.missions FOR SELECT
    USING (public.can_access_child(assigned_to_child_id));

CREATE POLICY "Assigned child or linked parent can read mission rewards"
    ON public.mission_rewards FOR SELECT
    USING (public.can_access_child(child_id));

CREATE POLICY "Recipients can read their own mission events"
    ON public.mission_lifecycle_events FOR SELECT
    USING (recipient_user_id = auth.uid());

CREATE POLICY "Linked parents can request approved reports"
    ON public.report_requests FOR SELECT
    USING (public.can_access_child(child_id));

-- Each lifecycle operation is an authenticated database command. It prevents
-- cross-child changes and creates the matching durable event only after the
-- mission write succeeds.
CREATE OR REPLACE FUNCTION public.create_parent_mission(p_mission JSONB)
RETURNS public.missions AS $$
DECLARE
    v_mission public.missions;
    v_child_user_id UUID;
BEGIN
    IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;
    IF NOT EXISTS (
      SELECT 1 FROM public.parent_child_relationships rel
      JOIN public.parent_profiles pp ON pp.id = rel.parent_profile_id
      WHERE pp.user_id = auth.uid()
        AND rel.child_profile_id = (p_mission->>'assigned_to_child_id')::UUID
    ) THEN RAISE EXCEPTION 'Parent is not linked to this child'; END IF;

    INSERT INTO public.missions (
      family_id, assigned_by_user_id, assigned_to_child_id, title, description,
      source, target_minutes, due_at, proof_requirement
    ) VALUES (
      (p_mission->>'family_id')::UUID, auth.uid(),
      (p_mission->>'assigned_to_child_id')::UUID, trim(p_mission->>'title'),
      COALESCE(p_mission->>'description', ''), 'parent',
      (p_mission->>'target_minutes')::INTEGER,
      NULLIF(p_mission->>'due_at', '')::TIMESTAMPTZ,
      COALESCE(p_mission->>'proof_requirement', 'noProof')
    ) RETURNING * INTO v_mission;

    SELECT user_id INTO v_child_user_id FROM public.child_profiles WHERE id = v_mission.assigned_to_child_id;
    INSERT INTO public.mission_lifecycle_events (mission_id, family_id, recipient_user_id, event_type, idempotency_key)
    VALUES (v_mission.id, v_mission.family_id, v_child_user_id, 'NEW_TASK', 'NEW_TASK:' || v_mission.id)
    ON CONFLICT (idempotency_key) DO NOTHING;
    RETURN v_mission;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.start_child_mission(p_mission_id UUID)
RETURNS public.missions AS $$
DECLARE v_mission public.missions;
BEGIN
    UPDATE public.missions
    SET status = 'started', started_at = now(), state_version = state_version + 1, updated_at = now()
    WHERE id = p_mission_id
      AND assigned_to_child_id IN (SELECT id FROM public.child_profiles WHERE user_id = auth.uid())
      AND status IN ('assigned', 'needs_retry')
      AND (due_at IS NULL OR due_at >= now())
    RETURNING * INTO v_mission;
    IF v_mission.id IS NULL THEN RAISE EXCEPTION 'Mission cannot be started'; END IF;
    INSERT INTO public.mission_lifecycle_events (mission_id, family_id, recipient_user_id, event_type, idempotency_key)
    VALUES (v_mission.id, v_mission.family_id, v_mission.assigned_by_user_id, 'TASK_STARTED', 'TASK_STARTED:' || v_mission.id || ':' || v_mission.state_version)
    ON CONFLICT (idempotency_key) DO NOTHING;
    RETURN v_mission;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.submit_child_mission(
    p_mission_id UUID, p_media_path TEXT DEFAULT NULL, p_media_type TEXT DEFAULT NULL, p_notes TEXT DEFAULT NULL
)
RETURNS public.missions AS $$
DECLARE v_mission public.missions;
BEGIN
    UPDATE public.missions
    SET status = 'submitted', proof_media_path = p_media_path, proof_media_type = p_media_type,
        submission_notes = p_notes, submitted_at = now(), state_version = state_version + 1, updated_at = now()
    WHERE id = p_mission_id
      AND assigned_to_child_id IN (SELECT id FROM public.child_profiles WHERE user_id = auth.uid())
      AND status = 'started'
      AND (due_at IS NULL OR due_at >= now())
    RETURNING * INTO v_mission;
    IF v_mission.id IS NULL THEN RAISE EXCEPTION 'Mission cannot be submitted'; END IF;
    IF v_mission.proof_requirement IN ('photo', 'video', 'photoVideoParentApproval') AND p_media_path IS NULL THEN
      RAISE EXCEPTION 'Required proof is missing';
    END IF;
    INSERT INTO public.mission_lifecycle_events (mission_id, family_id, recipient_user_id, event_type, idempotency_key)
    VALUES (v_mission.id, v_mission.family_id, v_mission.assigned_by_user_id, 'TASK_COMPLETED', 'TASK_COMPLETED:' || v_mission.id || ':' || v_mission.state_version)
    ON CONFLICT (idempotency_key) DO NOTHING;
    RETURN v_mission;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.review_mission(p_mission_id UUID, p_approved BOOLEAN, p_feedback TEXT DEFAULT NULL)
RETURNS public.missions AS $$
DECLARE v_mission public.missions; v_child_user_id UUID; v_event TEXT;
BEGIN
    UPDATE public.missions m
    SET status = CASE WHEN p_approved THEN 'approved' ELSE 'needs_retry' END,
        parent_feedback = NULLIF(trim(p_feedback), ''),
        approved_at = CASE WHEN p_approved THEN now() ELSE NULL END,
        completed_at = CASE WHEN p_approved THEN now() ELSE NULL END,
        current_minutes = CASE WHEN p_approved THEN m.target_minutes ELSE m.current_minutes END,
        state_version = m.state_version + 1, updated_at = now()
    WHERE m.id = p_mission_id AND m.status = 'submitted'
      AND EXISTS (
        SELECT 1 FROM public.parent_child_relationships rel
        JOIN public.parent_profiles pp ON pp.id = rel.parent_profile_id
        WHERE rel.child_profile_id = m.assigned_to_child_id AND pp.user_id = auth.uid()
      )
    RETURNING * INTO v_mission;
    IF v_mission.id IS NULL THEN RAISE EXCEPTION 'Mission cannot be reviewed'; END IF;
    SELECT user_id INTO v_child_user_id FROM public.child_profiles WHERE id = v_mission.assigned_to_child_id;
    v_event := CASE WHEN p_approved THEN 'TASK_APPROVED' ELSE 'TASK_NEEDS_RETRY' END;
    INSERT INTO public.mission_lifecycle_events (mission_id, family_id, recipient_user_id, event_type, idempotency_key)
    VALUES (v_mission.id, v_mission.family_id, v_child_user_id, v_event, v_event || ':' || v_mission.id || ':' || v_mission.state_version)
    ON CONFLICT (idempotency_key) DO NOTHING;
    RETURN v_mission;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.create_mission_reward(
    p_mission_id UUID, p_title TEXT, p_description TEXT DEFAULT NULL
)
RETURNS public.mission_rewards AS $$
DECLARE v_reward public.mission_rewards; v_mission public.missions;
BEGIN
    SELECT * INTO v_mission FROM public.missions
      WHERE id = p_mission_id AND assigned_by_user_id = auth.uid();
    IF v_mission.id IS NULL THEN RAISE EXCEPTION 'Only the assigning parent can configure this reward'; END IF;
    INSERT INTO public.mission_rewards (mission_id, parent_user_id, child_id, title, description)
      VALUES (v_mission.id, auth.uid(), v_mission.assigned_to_child_id, trim(p_title), NULLIF(trim(p_description), ''))
      RETURNING * INTO v_reward;
    RETURN v_reward;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.unlock_mission_reward(p_mission_id UUID)
RETURNS public.mission_rewards AS $$
DECLARE v_reward public.mission_rewards;
BEGIN
    UPDATE public.mission_rewards r
    SET status = 'unlocked', unlocked_at = now()
    FROM public.missions m
    WHERE r.mission_id = p_mission_id AND m.id = r.mission_id
      AND m.status = 'approved' AND r.status = 'locked'
      AND EXISTS (
        SELECT 1 FROM public.parent_child_relationships rel
        JOIN public.parent_profiles pp ON pp.id = rel.parent_profile_id
        WHERE rel.child_profile_id = m.assigned_to_child_id AND pp.user_id = auth.uid()
      )
    RETURNING r.* INTO v_reward;
    IF v_reward.id IS NULL THEN RAISE EXCEPTION 'Reward cannot be unlocked'; END IF;
    INSERT INTO public.mission_lifecycle_events (mission_id, family_id, recipient_user_id, event_type, idempotency_key)
      SELECT m.id, m.family_id, cp.user_id, 'REWARD_UNLOCKED', 'REWARD_UNLOCKED:' || r.id
      FROM public.mission_rewards r JOIN public.missions m ON m.id = r.mission_id
      JOIN public.child_profiles cp ON cp.id = r.child_id WHERE r.id = v_reward.id
      ON CONFLICT (idempotency_key) DO NOTHING;
    RETURN v_reward;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.redeem_mission_reward(p_reward_id UUID)
RETURNS public.mission_rewards AS $$
DECLARE v_reward public.mission_rewards;
BEGIN
    UPDATE public.mission_rewards r SET status = 'redeemed', redeemed_at = now(), redeemed_by_user_id = auth.uid()
    WHERE r.id = p_reward_id AND r.status = 'unlocked' AND public.can_access_child(r.child_id)
    RETURNING * INTO v_reward;
    IF v_reward.id IS NULL THEN RAISE EXCEPTION 'Reward cannot be redeemed'; END IF;
    RETURN v_reward;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
