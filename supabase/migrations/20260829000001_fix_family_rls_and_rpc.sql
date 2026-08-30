-- Fix Family RLS Policies and Stored Procedures
-- Migration: 20260829000001_fix_family_rls_and_rpc.sql

-- 1. Helper Functions: Include family admin directly from families table
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

-- 2. Drop and Recreate Families RLS Policies
DROP POLICY IF EXISTS "Family members can view their family" ON public.families;
DROP POLICY IF EXISTS "Family members and admin can view their family" ON public.families;
DROP POLICY IF EXISTS "Parents can create a family" ON public.families;
DROP POLICY IF EXISTS "Admins can update their family" ON public.families;

-- Allow creator/admin and members to view the family (critical for INSERT ... RETURNING / .select())
CREATE POLICY "Family members and admin can view their family"
    ON public.families FOR SELECT
    USING (admin_user_id = auth.uid() OR public.is_family_member(id));

CREATE POLICY "Parents can create a family"
    ON public.families FOR INSERT
    WITH CHECK (admin_user_id = auth.uid());

CREATE POLICY "Admins can update their family"
    ON public.families FOR UPDATE
    USING (admin_user_id = auth.uid() OR public.is_family_admin(id));

-- 3. Automatic Trigger to attach admin into family_members & default settings
CREATE OR REPLACE FUNCTION public.handle_new_family()
RETURNS TRIGGER AS $$
BEGIN
    -- Add creator as ADMIN in family_members
    INSERT INTO public.family_members (family_id, user_id, role)
    VALUES (NEW.id, NEW.admin_user_id, 'ADMIN')
    ON CONFLICT (family_id, user_id) DO NOTHING;

    -- Default Privacy Settings
    INSERT INTO public.privacy_settings (family_id, user_id, anonymize_data, local_processing_only, data_retention_days)
    VALUES (NEW.id, NEW.admin_user_id, true, true, 30)
    ON CONFLICT (family_id, user_id) DO NOTHING;

    -- Default Notification Preferences
    INSERT INTO public.notification_preferences (family_id, user_id, daily_summary, instant_alerts, quiet_hours_start, quiet_hours_end)
    VALUES (NEW.id, NEW.admin_user_id, true, true, '21:00', '07:00')
    ON CONFLICT (user_id) DO UPDATE SET family_id = EXCLUDED.family_id, updated_at = NOW();

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_family_created ON public.families;
CREATE TRIGGER on_family_created
    AFTER INSERT ON public.families
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_family();

-- 4. Atomic RPC function for Creating a Family Hub
CREATE OR REPLACE FUNCTION public.create_family_hub(
    p_name TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID;
    v_family RECORD;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required';
    END IF;

    INSERT INTO public.families (name, admin_user_id)
    VALUES (p_name, v_user_id)
    RETURNING * INTO v_family;

    RETURN to_jsonb(v_family);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
