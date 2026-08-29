process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';
const { Client } = require('pg');

const connectionString = "postgresql://postgres.bmtadgpkckkgcmvnqobg:IQoobengaluru2908@aws-0-ap-northeast-1.pooler.supabase.com:5432/postgres";

async function run() {
  const client = new Client({
    connectionString,
    ssl: { rejectUnauthorized: false },
    connectionTimeoutMillis: 10000
  });

  console.log("Connecting to Supabase (ap-northeast-1)...");
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

    -- 2. Families RLS
    DROP POLICY IF EXISTS "Family members can view their family" ON public.families;
    DROP POLICY IF EXISTS "Family members and admin can view their family" ON public.families;
    DROP POLICY IF EXISTS "Parents can create a family" ON public.families;
    DROP POLICY IF EXISTS "Admins can update their family" ON public.families;

    CREATE POLICY "Family members and admin can view their family"
        ON public.families FOR SELECT
        USING (admin_user_id = auth.uid() OR public.is_family_member(id));

    CREATE POLICY "Parents can create a family"
        ON public.families FOR INSERT
        WITH CHECK (admin_user_id = auth.uid());

    CREATE POLICY "Admins can update their family"
        ON public.families FOR UPDATE
        USING (admin_user_id = auth.uid() OR public.is_family_admin(id));

    -- 3. Family Members RLS
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

    -- 4. Privacy Settings RLS
    DROP POLICY IF EXISTS "Users can manage own privacy settings" ON public.privacy_settings;
    DROP POLICY IF EXISTS "Family members can view privacy settings" ON public.privacy_settings;

    CREATE POLICY "Family members can view privacy settings"
        ON public.privacy_settings FOR SELECT
        USING (user_id = auth.uid() OR public.is_family_member(family_id));

    CREATE POLICY "Users can manage own privacy settings"
        ON public.privacy_settings FOR ALL
        USING (user_id = auth.uid() OR public.is_family_admin(family_id))
        WITH CHECK (user_id = auth.uid() OR public.is_family_admin(family_id));

    -- 5. Notification Preferences RLS
    DROP POLICY IF EXISTS "Users can manage own notification preferences" ON public.notification_preferences;

    CREATE POLICY "Users can manage own notification preferences"
        ON public.notification_preferences FOR ALL
        USING (user_id = auth.uid())
        WITH CHECK (user_id = auth.uid());

    -- 6. Child Profiles RLS
    DROP POLICY IF EXISTS "Child can view own profile" ON public.child_profiles;
    DROP POLICY IF EXISTS "Parent can view child profiles in their family" ON public.child_profiles;
    DROP POLICY IF EXISTS "Parent can create child profile in their family" ON public.child_profiles;
    DROP POLICY IF EXISTS "Parent can update child profile in their family" ON public.child_profiles;
    DROP POLICY IF EXISTS "Child and Parent can view child profiles" ON public.child_profiles;
    DROP POLICY IF EXISTS "Parent and child can create child profile" ON public.child_profiles;

    CREATE POLICY "Child and Parent can view child profiles"
        ON public.child_profiles FOR SELECT
        USING (user_id = auth.uid() OR public.is_family_admin(family_id));

    CREATE POLICY "Parent and child can create child profile"
        ON public.child_profiles FOR INSERT
        WITH CHECK (user_id = auth.uid() OR public.is_family_admin(family_id));

    CREATE POLICY "Parent can update child profile in their family"
        ON public.child_profiles FOR UPDATE
        USING (public.is_family_admin(family_id));

    -- 7. Devices & Device Pairings RLS
    DROP POLICY IF EXISTS "Users can manage own devices" ON public.devices;
    CREATE POLICY "Users can manage own devices"
        ON public.devices FOR ALL
        USING (user_id = auth.uid())
        WITH CHECK (user_id = auth.uid());

    DROP POLICY IF EXISTS "Family members can view device pairings" ON public.device_pairings;
    DROP POLICY IF EXISTS "Users can create pairings for own devices" ON public.device_pairings;

    CREATE POLICY "Family members can view device pairings"
        ON public.device_pairings FOR SELECT
        USING (public.is_family_member(family_id));

    CREATE POLICY "Users can create pairings for own devices"
        ON public.device_pairings FOR ALL
        USING (public.is_family_admin(family_id) OR EXISTS (SELECT 1 FROM public.devices WHERE id = device_id AND user_id = auth.uid()))
        WITH CHECK (public.is_family_admin(family_id) OR EXISTS (SELECT 1 FROM public.devices WHERE id = device_id AND user_id = auth.uid()));

    -- 8. Report & Trigger Configurations RLS
    DROP POLICY IF EXISTS "Parent admin can view report configurations" ON public.report_configurations;
    DROP POLICY IF EXISTS "Parent admin can insert report configurations" ON public.report_configurations;
    DROP POLICY IF EXISTS "Parent admin can update report configurations" ON public.report_configurations;
    DROP POLICY IF EXISTS "Parent admin can delete report configurations" ON public.report_configurations;
    DROP POLICY IF EXISTS "Parent admin can manage report configurations" ON public.report_configurations;

    CREATE POLICY "Parent admin can manage report configurations"
        ON public.report_configurations FOR ALL
        USING (public.is_family_admin(family_id))
        WITH CHECK (public.is_family_admin(family_id));

    DROP POLICY IF EXISTS "Parent admin can view trigger configurations" ON public.trigger_configurations;
    DROP POLICY IF EXISTS "Parent admin can insert trigger configurations" ON public.trigger_configurations;
    DROP POLICY IF EXISTS "Parent admin can update trigger configurations" ON public.trigger_configurations;
    DROP POLICY IF EXISTS "Parent admin can delete trigger configurations" ON public.trigger_configurations;
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
        ON CONFLICT (family_id, user_id) DO NOTHING;

        RETURN NEW;
    END;
    $$ LANGUAGE plpgsql SECURITY DEFINER;

    DROP TRIGGER IF EXISTS on_family_created ON public.families;
    CREATE TRIGGER on_family_created
        AFTER INSERT ON public.families
        FOR EACH ROW
        EXECUTE FUNCTION public.handle_new_family();

    -- 10. Atomic RPC function for Creating a Family Hub
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
