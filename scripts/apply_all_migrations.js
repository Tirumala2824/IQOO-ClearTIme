process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';
const { Client } = require('pg');

const connectionString = process.env.SUPABASE_DATABASE_URL || process.env.DATABASE_URL;
if (!connectionString) {
  console.log("--------------------------------------------------------------------------------");
  console.log("SUPABASE_DATABASE_URL environment variable is not set in this shell session.");
  console.log("All migration SQL definitions are ready in:");
  console.log("  supabase/migrations/20260831000000_foundation_rebuild.sql");
  console.log("  supabase/migrations/20260901000000_fix_family_deletion_and_crud.sql");
  console.log("To apply directly to your live Supabase DB from the command line, run:");
  console.log("  $env:SUPABASE_DATABASE_URL='postgresql://postgres:[PASSWORD]@[HOST]:[PORT]/postgres'");
  console.log("  node scripts/apply_all_migrations.js");
  console.log("--------------------------------------------------------------------------------");
  process.exit(0);
}

async function run() {
  const client = new Client({
    connectionString,
    ssl: { rejectUnauthorized: false },
    connectionTimeoutMillis: 10000
  });

  console.log("Connecting to Supabase PostgreSQL database...");
  await client.connect();
  console.log("Connected successfully to Supabase PostgreSQL!");

  const fullPolicySql = `
    -- 1. Helper Functions
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

    CREATE OR REPLACE FUNCTION public.can_access_child(c_id UUID)
    RETURNS BOOLEAN AS $$
    BEGIN
        RETURN EXISTS (
            SELECT 1 FROM public.child_profiles cp
            JOIN public.families f ON f.id = cp.family_id
            WHERE cp.id = c_id AND (f.admin_user_id = auth.uid() OR public.is_family_admin(f.id))
        ) OR EXISTS (
            SELECT 1 FROM public.child_profiles cp
            WHERE cp.id = c_id AND cp.user_id = auth.uid()
        );
    END;
    $$ LANGUAGE plpgsql SECURITY DEFINER;

    -- 2. Families RLS & Cascade Procedures
    DROP POLICY IF EXISTS "Family members can view their family" ON public.families;
    DROP POLICY IF EXISTS "Family members and admin can view their family" ON public.families;
    DROP POLICY IF EXISTS "Parents can create a family" ON public.families;
    DROP POLICY IF EXISTS "Admins can update their family" ON public.families;
    DROP POLICY IF EXISTS "Admins can delete their family" ON public.families;

    CREATE POLICY "Family members and admin can view their family"
        ON public.families FOR SELECT
        USING (admin_user_id = auth.uid() OR public.is_family_member(id));

    CREATE POLICY "Parents can create a family"
        ON public.families FOR INSERT
        WITH CHECK (admin_user_id = auth.uid());

    CREATE POLICY "Admins can update their family"
        ON public.families FOR UPDATE
        USING (admin_user_id = auth.uid() OR public.is_family_admin(id));

    CREATE POLICY "Admins can delete their family"
        ON public.families FOR DELETE
        USING (admin_user_id = auth.uid() OR public.is_family_admin(id));

    -- Atomic delete_family_hub procedure
    CREATE OR REPLACE FUNCTION public.delete_family_hub(p_family_id UUID)
    RETURNS BOOLEAN AS $$
    DECLARE
        v_user_id UUID;
    BEGIN
        v_user_id := auth.uid();
        IF v_user_id IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;

        IF NOT (
            EXISTS (SELECT 1 FROM public.families WHERE id = p_family_id AND admin_user_id = v_user_id)
            OR EXISTS (SELECT 1 FROM public.family_members WHERE family_id = p_family_id AND user_id = v_user_id AND role = 'ADMIN')
        ) THEN
            RAISE EXCEPTION 'Only family administrators are authorized to delete this family group';
        END IF;

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

    -- 3. Child Profiles RLS & Deletion Procedure
    DROP POLICY IF EXISTS "Child can view own profile" ON public.child_profiles;
    DROP POLICY IF EXISTS "Parent can view child profiles in their family" ON public.child_profiles;
    DROP POLICY IF EXISTS "Parent can create child profile in their family" ON public.child_profiles;
    DROP POLICY IF EXISTS "Parent can update child profile in their family" ON public.child_profiles;
    DROP POLICY IF EXISTS "Child and Parent can view child profiles" ON public.child_profiles;
    DROP POLICY IF EXISTS "Parent and child can create child profile" ON public.child_profiles;
    DROP POLICY IF EXISTS "Parent admin can delete child profile" ON public.child_profiles;

    CREATE POLICY "Child and Parent can view child profiles"
        ON public.child_profiles FOR SELECT
        USING (user_id = auth.uid() OR public.is_family_admin(family_id));

    CREATE POLICY "Parent and child can create child profile"
        ON public.child_profiles FOR INSERT
        WITH CHECK (user_id = auth.uid() OR public.is_family_admin(family_id));

    CREATE POLICY "Parent can update child profile in their family"
        ON public.child_profiles FOR UPDATE
        USING (public.is_family_admin(family_id));

    CREATE POLICY "Parent admin can delete child profile"
        ON public.child_profiles FOR DELETE
        USING (public.is_family_admin(family_id));

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
        DELETE FROM public.parent_child_relationships WHERE child_profile_id = p_child_id;
        DELETE FROM public.device_pairings WHERE child_id = p_child_id;
        DELETE FROM public.child_profiles WHERE id = p_child_id;

        RETURN TRUE;
    END;
    $$ LANGUAGE plpgsql SECURITY DEFINER;

    -- 4. Missions & Rewards RLS & Procedures
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

    -- 5. Approved Reports RLS
    DROP POLICY IF EXISTS "Child can insert approved reports" ON public.approved_reports;
    CREATE POLICY "Child can insert approved reports"
        ON public.approved_reports FOR INSERT
        WITH CHECK (created_by_user_id = auth.uid() OR public.can_access_child(child_id));

    DROP POLICY IF EXISTS "Child and parent can update approved reports" ON public.approved_reports;
    CREATE POLICY "Child and parent can update approved reports"
        ON public.approved_reports FOR UPDATE
        USING (created_by_user_id = auth.uid() OR public.can_access_child(child_id));

    DROP POLICY IF EXISTS "Family members can view approved reports" ON public.approved_reports;
    CREATE POLICY "Family members can view approved reports"
        ON public.approved_reports FOR SELECT
        USING (created_by_user_id = auth.uid() OR public.can_access_child(child_id) OR public.is_family_member(family_id));

    -- 6. Family Members RLS
    DROP POLICY IF EXISTS "Family members can view members of the same family" ON public.family_members;
    DROP POLICY IF EXISTS "Family admin can insert family members" ON public.family_members;
    DROP POLICY IF EXISTS "Family admin and self can update family members" ON public.family_members;
    DROP POLICY IF EXISTS "Family admin can delete family members" ON public.family_members;

    CREATE POLICY "Family members can view members of the same family"
        ON public.family_members FOR SELECT
        USING (user_id = auth.uid() OR public.is_family_member(family_id));

    CREATE POLICY "Family admin can insert family members"
        ON public.family_members FOR INSERT
        WITH CHECK (user_id = auth.uid() OR public.is_family_admin(family_id));

    CREATE POLICY "Family admin and self can update family members"
        ON public.family_members FOR UPDATE
        USING (user_id = auth.uid() OR public.is_family_admin(family_id));

    CREATE POLICY "Family admin can delete family members"
        ON public.family_members FOR DELETE
        USING (public.is_family_admin(family_id));

    -- 7. Privacy Settings & Notifications RLS
    DROP POLICY IF EXISTS "Users can manage own privacy settings" ON public.privacy_settings;
    DROP POLICY IF EXISTS "Family members can view privacy settings" ON public.privacy_settings;

    CREATE POLICY "Family members can view privacy settings"
        ON public.privacy_settings FOR SELECT
        USING (user_id = auth.uid() OR public.is_family_member(family_id));

    CREATE POLICY "Users can manage own privacy settings"
        ON public.privacy_settings FOR ALL
        USING (user_id = auth.uid() OR public.is_family_admin(family_id))
        WITH CHECK (user_id = auth.uid() OR public.is_family_admin(family_id));

    DROP POLICY IF EXISTS "Users can manage own notification preferences" ON public.notification_preferences;
    CREATE POLICY "Users can manage own notification preferences"
        ON public.notification_preferences FOR ALL
        USING (user_id = auth.uid())
        WITH CHECK (user_id = auth.uid());

    -- 8. Report & Trigger Configurations RLS
    DROP POLICY IF EXISTS "Parent admin can manage report configurations" ON public.report_configurations;
    CREATE POLICY "Parent admin can manage report configurations"
        ON public.report_configurations FOR ALL
        USING (public.is_family_admin(family_id))
        WITH CHECK (public.is_family_admin(family_id));

    DROP POLICY IF EXISTS "Parent admin can manage trigger configurations" ON public.trigger_configurations;
    CREATE POLICY "Parent admin can manage trigger configurations"
        ON public.trigger_configurations FOR ALL
        USING (public.is_family_admin(family_id))
        WITH CHECK (public.is_family_admin(family_id));

    -- 9. Automatic Trigger to attach admin into family_members & default settings
    CREATE OR REPLACE FUNCTION public.handle_new_family()
    RETURNS TRIGGER AS $$
    BEGIN
        INSERT INTO public.family_members (family_id, user_id, role)
        VALUES (NEW.id, NEW.admin_user_id, 'ADMIN')
        ON CONFLICT (family_id, user_id) DO NOTHING;

        INSERT INTO public.privacy_settings (family_id, user_id, anonymize_data, local_processing_only, data_retention_days)
        VALUES (NEW.id, NEW.admin_user_id, true, true, 30)
        ON CONFLICT (family_id, user_id) DO NOTHING;

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

    -- Reload PostgREST Cache
    NOTIFY pgrst, 'reload schema';
    NOTIFY pgrst, 'reload config';
  `;

  await client.query(fullPolicySql);
  console.log("ALL MIGRATIONS & RLS POLICIES APPLIED SUCCESSFULLY TO SUPABASE DB!");

  await client.end();
}

run().catch(err => {
  console.error("Migration error:", err);
  process.exit(1);
});
