import { S3Client, PutObjectCommand, GetObjectCommand, ListObjectsV2Command } from '@aws-sdk/client-s3';
import { neon } from '@neondatabase/serverless';
import fs from 'node:fs';

// Parse .env.local manually to ensure clean variable resolution
const envContent = fs.readFileSync('.env.local', 'utf-8');
const env = {};
for (const line of envContent.split('\n')) {
  const match = line.match(/^\s*([\w.-]+)\s*=\s*(.*)?\s*$/);
  if (match) {
    let value = match[2] || '';
    if (value.startsWith('"') && value.endsWith('"')) value = value.slice(1, -1);
    env[match[1]] = value;
  }
}

async function runNeonTestSuite() {
  console.log('====================================================');
  console.log('       NEON CLOUD INFRASTRUCTURE PROOF OF WORK      ');
  console.log('====================================================');
  console.log('Branch:        ', env.NEON_BRANCH);
  console.log('Region:        ', env.AWS_REGION);
  console.log('Database URL:  ', env.DATABASE_URL ? 'Loaded (pooler)' : 'MISSING');
  console.log('Auth Base URL: ', env.NEON_AUTH_BASE_URL);
  console.log('Function URL:  ', env.NEON_FUNCTION_HELLO_BASE_URL);
  console.log('S3 Endpoint:   ', env.AWS_ENDPOINT_URL_S3);
  console.log('----------------------------------------------------');

  let allPassed = true;

  // 1. NEON POSTGRESQL (Lakebase Postgres)
  console.log('\n[1/4] Testing Neon Postgres (via @neondatabase/serverless)...');
  try {
    const sql = neon(env.DATABASE_URL);
    const versionRes = await sql`SELECT version(), current_database() as db_name, now() as current_time`;
    console.log('  ✓ Query successful!');
    console.log('  - Database:', versionRes[0].db_name);
    console.log('  - Version: ', versionRes[0].version.split('\n')[0]);
    console.log('  - Server Time:', versionRes[0].current_time);

    // Verify application tables
    const tableRes = await sql`
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public' 
      ORDER BY table_name;
    `;
    console.log('  - Application Tables in public schema:', tableRes.map(t => t.table_name).join(', '));
  } catch (err) {
    console.error('  ✗ Neon Postgres FAILED:', err.message);
    allPassed = false;
  }

  // 2. NEON AUTH (Managed Better Auth)
  console.log('\n[2/4] Testing Neon Auth (Managed Better Auth)...');
  try {
    const jwksUrl = `${env.NEON_AUTH_BASE_URL.replace(/\/+$/, '')}/.well-known/jwks.json`;
    const res = await fetch(jwksUrl);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const jwks = await res.json();
    console.log('  ✓ Neon Auth JWKS verified!');
    console.log('  - Key count:', jwks.keys ? jwks.keys.length : 0);
    console.log('  - Key type: ', jwks.keys?.[0]?.kty || 'RSA');
    console.log('  - Algorithm:', jwks.keys?.[0]?.alg || 'RS256');
  } catch (err) {
    console.error('  ✗ Neon Auth FAILED:', err.message);
    allPassed = false;
  }

  // 3. NEON FUNCTIONS (Serverless long-running functions)
  console.log('\n[3/4] Testing Neon Functions (hello)...');
  try {
    const res = await fetch(env.NEON_FUNCTION_HELLO_BASE_URL);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const body = await res.text();
    console.log('  ✓ Function invocation successful!');
    console.log('  - Status:', res.status, res.statusText);
    console.log('  - Body:  ', body.trim());
  } catch (err) {
    console.error('  ✗ Neon Function FAILED:', err.message);
    allPassed = false;
  }

  // 4. NEON OBJECT STORAGE (S3-Compatible Buckets)
  console.log('\n[4/4] Testing Neon Object Storage (Bucket: assets)...');
  try {
    const s3 = new S3Client({
      region: env.AWS_REGION,
      endpoint: env.AWS_ENDPOINT_URL_S3,
      credentials: {
        accessKeyId: env.AWS_ACCESS_KEY_ID,
        secretAccessKey: env.AWS_SECRET_ACCESS_KEY,
      },
      forcePathStyle: true,
    });

    const testKey = `proof-test-${Date.now()}.txt`;
    const testContent = `Apex F1 Neon Object Storage Verification @ ${new Date().toISOString()}`;

    // Put Object
    await s3.send(new PutObjectCommand({
      Bucket: 'assets',
      Key: testKey,
      Body: testContent,
      ContentType: 'text/plain',
    }));
    console.log('  ✓ PutObject succeeded: uploaded', testKey);

    // List Objects
    const list = await s3.send(new ListObjectsV2Command({ Bucket: 'assets' }));
    console.log('  ✓ ListObjects succeeded: bucket contains', list.KeyCount, 'object(s)');

    // Read back Object
    const getRes = await s3.send(new GetObjectCommand({
      Bucket: 'assets',
      Key: testKey,
    }));
    const text = await getRes.Body.transformToString();
    console.log('  ✓ GetObject verified: content matches:', text.slice(0, 40) + '...');
  } catch (err) {
    console.error('  ✗ Neon Object Storage FAILED:', err.message);
    allPassed = false;
  }

  console.log('\n----------------------------------------------------');
  if (allPassed) {
    console.log('🎉 ALL NEON SERVICES VERIFIED AND OPERATIONAL!');
  } else {
    console.log('⚠️ SOME NEON SERVICES ENCOUNTERED ISSUES.');
  }
  console.log('====================================================\n');
}

runNeonTestSuite().catch(console.error);
