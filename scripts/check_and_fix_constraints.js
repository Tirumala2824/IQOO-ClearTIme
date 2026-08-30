process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';
const { Client } = require('pg');

const connectionString = process.env.SUPABASE_DATABASE_URL;
if (!connectionString) {
  console.error("SUPABASE_DATABASE_URL environment variable is required.");
  process.exit(1);
}

async function run() {
  const client = new Client({
    connectionString,
    ssl: { rejectUnauthorized: false },
    connectionTimeoutMillis: 10000
  });

  await client.connect();
  console.log("Connected to Supabase PostgreSQL!");

  // Ensure unique constraints on all junction/settings tables
  const sql = `
    -- 1. Family Members unique constraint
    DO $$ BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'uq_family_members_family_user'
      ) THEN
        ALTER TABLE public.family_members ADD CONSTRAINT uq_family_members_family_user UNIQUE (family_id, user_id);
      END IF;
    EXCEPTION WHEN duplicate_table OR duplicate_object THEN null;
    END $$;

    -- 2. Privacy Settings unique constraint
    DO $$ BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'uq_privacy_settings_family_user'
      ) THEN
        ALTER TABLE public.privacy_settings ADD CONSTRAINT uq_privacy_settings_family_user UNIQUE (family_id, user_id);
      END IF;
    EXCEPTION WHEN duplicate_table OR duplicate_object THEN null;
    END $$;

    -- 3. Notification Preferences unique constraint
    DO $$ BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'uq_notification_prefs_family_user'
      ) THEN
        ALTER TABLE public.notification_preferences ADD CONSTRAINT uq_notification_prefs_family_user UNIQUE (family_id, user_id);
      END IF;
    EXCEPTION WHEN duplicate_table OR duplicate_object THEN null;
    END $$;

    -- 4. Also unique on user_id for notification_preferences if needed
    DO $$ BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'uq_notification_prefs_user'
      ) THEN
        ALTER TABLE public.notification_preferences ADD CONSTRAINT uq_notification_prefs_user UNIQUE (user_id);
      END IF;
    EXCEPTION WHEN duplicate_table OR duplicate_object THEN null;
    END $$;

    -- 5. Child Profiles unique on (family_id, nickname)
    DO $$ BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'uq_child_profiles_user'
      ) THEN
        ALTER TABLE public.child_profiles ADD CONSTRAINT uq_child_profiles_user UNIQUE (user_id);
      END IF;
    EXCEPTION WHEN duplicate_table OR duplicate_object THEN null;
    END $$;

    -- 6. Trigger / function update
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
        ON CONFLICT (user_id) DO NOTHING;

        RETURN NEW;
    END;
    $$ LANGUAGE plpgsql SECURITY DEFINER;

    DROP TRIGGER IF EXISTS on_family_created ON public.families;
    CREATE TRIGGER on_family_created
        AFTER INSERT ON public.families
        FOR EACH ROW
        EXECUTE FUNCTION public.handle_new_family();

    -- 7. Atomic RPC function for Creating a Family Hub
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

        INSERT INTO public.family_members (family_id, user_id, role)
        VALUES (v_family.id, v_user_id, 'ADMIN')
        ON CONFLICT (family_id, user_id) DO NOTHING;

        INSERT INTO public.privacy_settings (family_id, user_id, anonymize_data, local_processing_only, data_retention_days)
        VALUES (v_family.id, v_user_id, true, true, 30)
        ON CONFLICT (family_id, user_id) DO NOTHING;

        INSERT INTO public.notification_preferences (family_id, user_id, daily_summary, instant_alerts, quiet_hours_start, quiet_hours_end)
        VALUES (v_family.id, v_user_id, true, true, '21:00', '07:00')
        ON CONFLICT (user_id) DO NOTHING;

        RETURN to_jsonb(v_family);
    END;
    $$ LANGUAGE plpgsql SECURITY DEFINER;

    -- Reload PostgREST Cache
    NOTIFY pgrst, 'reload schema';
    NOTIFY pgrst, 'reload config';
  `;

  await client.query(sql);
  console.log("ALL UNIQUE CONSTRAINTS, RPC, AND TRIGGERS FIXED AND VERIFIED!");

  // List constraints
  const res = await client.query(`
    SELECT conname, conrelid::regclass AS table_name, pg_get_constraintdef(c.oid)
    FROM pg_constraint c
    JOIN pg_namespace n ON n.oid = c.connamespace
    WHERE n.nspname = 'public'
    ORDER BY conrelid::regclass::text;
  `);
  console.log("Active Constraints:", res.rows);

  await client.end();
}

run().catch(e => {
  console.error("Error:", e);
  process.exit(1);
});
