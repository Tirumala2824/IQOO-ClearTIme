process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';
const { Client } = require('pg');

const regions = [
  'ap-south-1',
  'ap-southeast-1',
  'ap-southeast-2',
  'ap-northeast-1',
  'ap-northeast-2',
  'eu-west-1',
  'eu-west-2',
  'eu-west-3',
  'eu-central-1',
  'eu-north-1',
  'us-east-1',
  'us-east-2',
  'us-west-1',
  'us-west-2',
  'sa-east-1',
  'ca-central-1',
  'me-south-1',
  'af-south-1'
];

async function testRegions() {
  if (!process.env.SUPABASE_DATABASE_URL) {
    console.error('SUPABASE_DATABASE_URL environment variable is required.');
    process.exit(1);
  }
  for (const r of regions) {
    const cs = process.env.SUPABASE_DATABASE_URL.replace(
      'aws-0-ap-northeast-1',
      `aws-0-${r}`,
    );
    const client = new Client({
      connectionString: cs,
      ssl: { rejectUnauthorized: false },
      connectionTimeoutMillis: 3000
    });

    try {
      await client.connect();
      console.log(`FOUND REGION! -> aws-0-${r}.pooler.supabase.com`);
      const res = await client.query('SELECT 1 as test');
      console.log('Query result:', res.rows);
      return { client, region: r };
    } catch (e) {
      if (!e.message.includes('not found')) {
        console.log(`${r} -> ${e.message}`);
      }
      await client.end().catch(() => {});
    }
  }
  console.log('No region matched.');
  return null;
}

testRegions();
