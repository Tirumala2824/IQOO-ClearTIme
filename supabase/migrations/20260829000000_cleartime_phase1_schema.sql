-- ClearTime Phase 1 Database Schema & Row Level Security (RLS)
-- Migration: 20260829000000_cleartime_phase1_schema.sql

-- Enable pgcrypto for UUIDs if not already enabled
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ==============================================================================
-- 1. ENUMS
-- ==============================================================================
DO $$ BEGIN
    CREATE TYPE user_role AS ENUM ('PARENT', 'CHILD');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE family_role AS ENUM ('ADMIN', 'MEMBER');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE invitation_status AS ENUM ('ACTIVE', 'USED', 'EXPIRED', 'REVOKED');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE pairing_status AS ENUM ('PENDING', 'ACTIVE', 'REVOKED');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE report_frequency AS ENUM ('DAILY', 'WEEKLY', 'MONTHLY');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE delivery_channel AS ENUM ('IN_APP', 'EMAIL');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- ==============================================================================
-- 2. TABLES & CONSTRAINTS
-- ==============================================================================

-- 2.1 Profiles (extends auth.users)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT UNIQUE,
    phone_number TEXT UNIQUE,
    role user_role NOT NULL,
    display_name TEXT,
    avatar_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2.2 Parent Profiles
CREATE TABLE IF NOT EXISTS public.parent_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES public.profiles(id) ON DELETE CASCADE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2.3 Families
CREATE TABLE IF NOT EXISTS public.families (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    admin_user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2.4 Child Profiles
CREATE TABLE IF NOT EXISTS public.child_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES public.profiles(id) ON DELETE CASCADE,
    family_id UUID NOT NULL REFERENCES public.families(id) ON DELETE CASCADE,
    nickname TEXT NOT NULL,
    age INT,
    avatar_index INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_child_profiles_family ON public.child_profiles(family_id);

-- 2.5 Family Members
CREATE TABLE IF NOT EXISTS public.family_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL REFERENCES public.families(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    role family_role NOT NULL DEFAULT 'MEMBER',
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_family_member UNIQUE(family_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_family_members_user ON public.family_members(user_id);
CREATE INDEX IF NOT EXISTS idx_family_members_family ON public.family_members(family_id);

-- 2.6 Parent-Child Relationships
CREATE TABLE IF NOT EXISTS public.parent_child_relationships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_profile_id UUID NOT NULL REFERENCES public.parent_profiles(id) ON DELETE CASCADE,
    child_profile_id UUID NOT NULL REFERENCES public.child_profiles(id) ON DELETE CASCADE,
    family_id UUID NOT NULL REFERENCES public.families(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_parent_child UNIQUE(parent_profile_id, child_profile_id)
);

-- 2.7 Devices
CREATE TABLE IF NOT EXISTS public.devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    device_name TEXT NOT NULL,
    model TEXT,
    os_version TEXT,
    client_version TEXT,
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2.8 Device Pairings
CREATE TABLE IF NOT EXISTS public.device_pairings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id UUID NOT NULL REFERENCES public.devices(id) ON DELETE CASCADE,
    family_id UUID NOT NULL REFERENCES public.families(id) ON DELETE CASCADE,
    status pairing_status NOT NULL DEFAULT 'ACTIVE',
    paired_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_device_family UNIQUE(device_id, family_id)
);

-- 2.9 Family Invitations (Secure QR / Code)
CREATE TABLE IF NOT EXISTS public.family_invitations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL REFERENCES public.families(id) ON DELETE CASCADE,
    created_by UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    invitation_code TEXT NOT NULL UNIQUE,
    qr_payload TEXT NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    max_uses INT NOT NULL DEFAULT 1,
    used_count INT NOT NULL DEFAULT 0,
    status invitation_status NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_invitations_code ON public.family_invitations(invitation_code);

-- 2.10 Privacy Settings
CREATE TABLE IF NOT EXISTS public.privacy_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL REFERENCES public.families(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    anonymize_data BOOLEAN NOT NULL DEFAULT TRUE,
    local_processing_only BOOLEAN NOT NULL DEFAULT TRUE,
    data_retention_days INT NOT NULL DEFAULT 30,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_privacy_user_family UNIQUE(family_id, user_id)
);

-- 2.11 Notification Preferences
CREATE TABLE IF NOT EXISTS public.notification_preferences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES public.profiles(id) ON DELETE CASCADE,
    family_id UUID NOT NULL REFERENCES public.families(id) ON DELETE CASCADE,
    daily_summary BOOLEAN NOT NULL DEFAULT TRUE,
    instant_alerts BOOLEAN NOT NULL DEFAULT TRUE,
    quiet_hours_start TEXT DEFAULT '21:00',
    quiet_hours_end TEXT DEFAULT '07:00',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2.12 Report Configurations
CREATE TABLE IF NOT EXISTS public.report_configurations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL REFERENCES public.families(id) ON DELETE CASCADE,
    created_by UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    frequency report_frequency NOT NULL DEFAULT 'WEEKLY',
    delivery_channel delivery_channel NOT NULL DEFAULT 'IN_APP',
    is_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2.13 Trigger Configurations
CREATE TABLE IF NOT EXISTS public.trigger_configurations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL REFERENCES public.families(id) ON DELETE CASCADE,
    created_by UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    trigger_type TEXT NOT NULL,
    threshold_minutes INT NOT NULL,
    action TEXT NOT NULL DEFAULT 'NOTIFY_PARENT',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ==============================================================================
-- 3. ROW LEVEL SECURITY (RLS)
-- ==============================================================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.parent_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.child_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.families ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.family_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.parent_child_relationships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.device_pairings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.family_invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.privacy_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.report_configurations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trigger_configurations ENABLE ROW LEVEL SECURITY;

-- Helper functions for RLS
CREATE OR REPLACE FUNCTION public.is_family_admin(f_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.families
        WHERE id = f_id AND admin_user_id = auth.uid()
    ) OR EXISTS (
        SELECT 1 FROM public.family_members
        WHERE family_id = f_id AND user_id = auth.uid() AND role = 'ADMIN'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.is_family_member(f_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.families
        WHERE id = f_id AND admin_user_id = auth.uid()
    ) OR EXISTS (
        SELECT 1 FROM public.family_members
        WHERE family_id = f_id AND user_id = auth.uid()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.get_user_role()
RETURNS user_role AS $$
DECLARE
    u_role user_role;
BEGIN
    SELECT role INTO u_role FROM public.profiles WHERE id = auth.uid();
    RETURN u_role;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3.1 Profiles RLS
CREATE POLICY "Users can view own profile or family members' profile"
    ON public.profiles FOR SELECT
    USING (
        id = auth.uid() OR
        EXISTS (
            SELECT 1 FROM public.family_members fm1
            JOIN public.family_members fm2 ON fm1.family_id = fm2.family_id
            WHERE fm1.user_id = auth.uid() AND fm2.user_id = profiles.id
        )
    );

CREATE POLICY "Users can insert their own profile"
    ON public.profiles FOR INSERT
    WITH CHECK (id = auth.uid());

CREATE POLICY "Users can update own profile"
    ON public.profiles FOR UPDATE
    USING (id = auth.uid());

-- 3.2 Parent Profiles RLS
CREATE POLICY "Parents can manage their own profile"
    ON public.parent_profiles FOR ALL
    USING (user_id = auth.uid());

-- 3.3 Families RLS
CREATE POLICY "Family members and admin can view their family"
    ON public.families FOR SELECT
    USING (admin_user_id = auth.uid() OR public.is_family_member(id));

CREATE POLICY "Parents can create a family"
    ON public.families FOR INSERT
    WITH CHECK (admin_user_id = auth.uid());

CREATE POLICY "Admins can update their family"
    ON public.families FOR UPDATE
    USING (admin_user_id = auth.uid() OR public.is_family_admin(id));

-- 3.4 Family Members RLS
CREATE POLICY "Family members can view members of the same family"
    ON public.family_members FOR SELECT
    USING (public.is_family_member(family_id));

CREATE POLICY "Family admin can insert family members"
    ON public.family_members FOR INSERT
    WITH CHECK (public.is_family_admin(family_id) OR user_id = auth.uid());

CREATE POLICY "Family admin can delete family members"
    ON public.family_members FOR DELETE
    USING (public.is_family_admin(family_id));

-- 3.5 Child Profiles RLS
CREATE POLICY "Child can view own profile"
    ON public.child_profiles FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "Parent can view child profiles in their family"
    ON public.child_profiles FOR SELECT
    USING (public.is_family_admin(family_id));

CREATE POLICY "Parent can create child profile in their family"
    ON public.child_profiles FOR INSERT
    WITH CHECK (public.is_family_admin(family_id) OR user_id = auth.uid());

CREATE POLICY "Parent can update child profile in their family"
    ON public.child_profiles FOR UPDATE
    USING (public.is_family_admin(family_id));

-- 3.6 Parent-Child Relationships RLS
CREATE POLICY "Members can view parent-child relationships in their family"
    ON public.parent_child_relationships FOR SELECT
    USING (public.is_family_member(family_id));

CREATE POLICY "Parent admin can manage relationships"
    ON public.parent_child_relationships FOR ALL
    USING (public.is_family_admin(family_id));

-- 3.7 Devices RLS
CREATE POLICY "Users can manage own devices"
    ON public.devices FOR ALL
    USING (user_id = auth.uid());

-- 3.8 Device Pairings RLS
CREATE POLICY "Family members can view device pairings"
    ON public.device_pairings FOR SELECT
    USING (public.is_family_member(family_id));

CREATE POLICY "Users can create pairings for own devices"
    ON public.device_pairings FOR INSERT
    WITH CHECK (
        EXISTS (SELECT 1 FROM public.devices WHERE id = device_id AND user_id = auth.uid())
    );

-- 3.9 Family Invitations RLS
CREATE POLICY "Parent admin can view and create invitations"
    ON public.family_invitations FOR ALL
    USING (public.is_family_admin(family_id))
    WITH CHECK (public.is_family_admin(family_id));

-- 3.10 Privacy Settings RLS
CREATE POLICY "Family members can view privacy settings"
    ON public.privacy_settings FOR SELECT
    USING (public.is_family_member(family_id));

CREATE POLICY "Users can manage own privacy settings"
    ON public.privacy_settings FOR ALL
    USING (user_id = auth.uid() OR public.is_family_admin(family_id));

-- 3.11 Notification Preferences RLS
CREATE POLICY "Users can manage own notification preferences"
    ON public.notification_preferences FOR ALL
    USING (user_id = auth.uid());

-- 3.12 Report Configurations RLS (Parent Only)
CREATE POLICY "Parent admin can view report configurations"
    ON public.report_configurations FOR SELECT
    USING (public.is_family_admin(family_id));

CREATE POLICY "Parent admin can insert report configurations"
    ON public.report_configurations FOR INSERT
    WITH CHECK (public.is_family_admin(family_id));

CREATE POLICY "Parent admin can update report configurations"
    ON public.report_configurations FOR UPDATE
    USING (public.is_family_admin(family_id));

CREATE POLICY "Parent admin can delete report configurations"
    ON public.report_configurations FOR DELETE
    USING (public.is_family_admin(family_id));

-- 3.13 Trigger Configurations RLS (Parent Only)
CREATE POLICY "Parent admin can view trigger configurations"
    ON public.trigger_configurations FOR SELECT
    USING (public.is_family_admin(family_id));

CREATE POLICY "Parent admin can insert trigger configurations"
    ON public.trigger_configurations FOR INSERT
    WITH CHECK (public.is_family_admin(family_id));

CREATE POLICY "Parent admin can update trigger configurations"
    ON public.trigger_configurations FOR UPDATE
    USING (public.is_family_admin(family_id));

CREATE POLICY "Parent admin can delete trigger configurations"
    ON public.trigger_configurations FOR DELETE
    USING (public.is_family_admin(family_id));

-- ==============================================================================
-- 4. SECURE STORED PROCEDURES / RPC
-- ==============================================================================

-- 4.1 Redeem Family Invitation (Child joining family via secure code/QR)
CREATE OR REPLACE FUNCTION public.redeem_family_invitation(
    p_invitation_code TEXT,
    p_nickname TEXT,
    p_age INT DEFAULT NULL,
    p_avatar_index INT DEFAULT 0
)
RETURNS JSONB AS $$
DECLARE
    v_invitation RECORD;
    v_child_profile_id UUID;
    v_parent_profile_id UUID;
    v_user_id UUID;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required';
    END IF;

    -- Look up active invitation with row lock
    SELECT * INTO v_invitation
    FROM public.family_invitations
    WHERE invitation_code = p_invitation_code
    FOR UPDATE;

    IF v_invitation IS NULL THEN
        RAISE EXCEPTION 'Invalid invitation code';
    END IF;

    IF v_invitation.status != 'ACTIVE' THEN
        RAISE EXCEPTION 'Invitation is no longer active';
    END IF;

    IF v_invitation.expires_at < NOW() THEN
        UPDATE public.family_invitations SET status = 'EXPIRED' WHERE id = v_invitation.id;
        RAISE EXCEPTION 'Invitation has expired';
    END IF;

    IF v_invitation.used_count >= v_invitation.max_uses THEN
        UPDATE public.family_invitations SET status = 'USED' WHERE id = v_invitation.id;
        RAISE EXCEPTION 'Invitation has reached maximum uses';
    END IF;

    -- Ensure child profile
    INSERT INTO public.child_profiles (user_id, family_id, nickname, age, avatar_index)
    VALUES (v_user_id, v_invitation.family_id, p_nickname, p_age, p_avatar_index)
    ON CONFLICT (user_id) DO UPDATE
    SET family_id = v_invitation.family_id,
        nickname = p_nickname,
        age = COALESCE(p_age, public.child_profiles.age),
        avatar_index = p_avatar_index,
        updated_at = NOW()
    RETURNING id INTO v_child_profile_id;

    -- Add to family_members
    INSERT INTO public.family_members (family_id, user_id, role)
    VALUES (v_invitation.family_id, v_user_id, 'MEMBER')
    ON CONFLICT (family_id, user_id) DO NOTHING;

    -- Look up parent profile of invitation creator
    SELECT id INTO v_parent_profile_id
    FROM public.parent_profiles
    WHERE user_id = v_invitation.created_by;

    IF v_parent_profile_id IS NOT NULL THEN
        INSERT INTO public.parent_child_relationships (parent_profile_id, child_profile_id, family_id)
        VALUES (v_parent_profile_id, v_child_profile_id, v_invitation.family_id)
        ON CONFLICT (parent_profile_id, child_profile_id) DO NOTHING;
    END IF;

    -- Update invitation usage
    UPDATE public.family_invitations
    SET used_count = used_count + 1,
        status = CASE WHEN (used_count + 1) >= max_uses THEN 'USED'::invitation_status ELSE 'ACTIVE'::invitation_status END
    WHERE id = v_invitation.id;

    RETURN jsonb_build_object(
        'success', true,
        'family_id', v_invitation.family_id,
        'child_profile_id', v_child_profile_id
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
