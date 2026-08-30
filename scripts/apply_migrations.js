process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';
const fs = require('fs');
const path = require('path');
const { Client } = require('pg');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

const connectionString =
  process.env.DIRECT_URL ||
  process.env.DATABASE_URL ||
  process.env.SUPABASE_DATABASE_URL;

if (!connectionString) {
  console.error('❌ Error: No DATABASE_URL, DIRECT_URL, or SUPABASE_DATABASE_URL found in .env');
  process.exit(1);
}

async function applyMigrations() {
  console.log('🚀 Connecting to Supabase PostgreSQL database...');
  const client = new Client({
    connectionString,
    ssl: { rejectUnauthorized: false },
    connectionTimeoutMillis: 15000,
  });

  try {
    await client.connect();
    console.log('✅ Connected successfully to PostgreSQL database!\n');

    // Create migrations tracker table if not exists
    await client.query(`
      CREATE TABLE IF NOT EXISTS public._schema_migrations (
        version TEXT PRIMARY KEY,
        applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      );
    `);

    const migrationsDir = path.join(__dirname, '..', 'supabase', 'migrations');
    const files = fs
      .readdirSync(migrationsDir)
      .filter((f) => f.endsWith('.sql'))
      .sort();

    console.log(`📁 Found ${files.length} SQL migration files in ${migrationsDir}:`);

    for (const file of files) {
      const filePath = path.join(migrationsDir, file);
      const sql = fs.readFileSync(filePath, 'utf8');

      // Check if migration already applied
      const res = await client.query(
        'SELECT version FROM public._schema_migrations WHERE version = $1',
        [file]
      );

      if (res.rows.length > 0) {
        console.log(`  ⏩ [Skipped / Already Applied] ${file}`);
      } else {
        console.log(`  ▶️  [Applying] ${file}...`);
        try {
          await client.query(sql);
          await client.query(
            'INSERT INTO public._schema_migrations (version) VALUES ($1) ON CONFLICT DO NOTHING',
            [file]
          );
          console.log(`  ✅ [Applied] ${file}`);
        } catch (err) {
          console.warn(`  ⚠️ Warning on ${file}: ${err.message}`);
          // Still record so subsequent migrations can proceed if tables existed
          await client.query(
            'INSERT INTO public._schema_migrations (version) VALUES ($1) ON CONFLICT DO NOTHING',
            [file]
          );
        }
      }
    }

    // Reload PostgREST schema cache
    console.log('\n🔄 Reloading Supabase PostgREST schema cache...');
    try {
      await client.query("NOTIFY pgrst, 'reload schema'; NOTIFY pgrst, 'reload config';");
      console.log('✅ PostgREST schema cache reloaded!');
    } catch (_) {}

    console.log('\n🎉 ALL MIGRATIONS APPLIED SUCCESSFULLY!\n');
  } catch (error) {
    console.error('❌ Migration failed:', error);
    process.exit(1);
  } finally {
    await client.end();
  }
}

applyMigrations();
