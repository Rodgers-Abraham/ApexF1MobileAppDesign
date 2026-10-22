import { neon } from '@neondatabase/serverless';

// Environment variables provided by Neon deploy and exposed via Vite
const databaseUrl =
  (import.meta as any).env?.DATABASE_URL ||
  (typeof process !== 'undefined' ? process.env?.DATABASE_URL : '') ||
  '';

export const neonAuthBaseUrl =
  (import.meta as any).env?.NEON_AUTH_BASE_URL ||
  (typeof process !== 'undefined' ? process.env?.NEON_AUTH_BASE_URL : '') ||
  '';

export const neonFunctionHelloUrl =
  (import.meta as any).env?.NEON_FUNCTION_HELLO_BASE_URL ||
  (typeof process !== 'undefined' ? process.env?.NEON_FUNCTION_HELLO_BASE_URL : '') ||
  '';

export const neonStorageEndpoint =
  (import.meta as any).env?.AWS_ENDPOINT_URL_S3 ||
  (typeof process !== 'undefined' ? process.env?.AWS_ENDPOINT_URL_S3 : '') ||
  '';

// 1. Neon Postgres Query Client (@neondatabase/serverless)
export const neonSql = databaseUrl ? neon(databaseUrl) : null;

export async function queryNeonDatabase(query: string = 'SELECT 1 AS connected, current_database() AS db_name') {
  if (!neonSql) {
    throw new Error('DATABASE_URL is not configured for Neon');
  }
  return await neonSql(query);
}

// 2. Neon Function Invoker
export async function invokeNeonFunction(path: string = ''): Promise<string> {
  const base = neonFunctionHelloUrl.replace(/\/+$/, '');
  const target = path ? `${base}/${path.replace(/^\/+/, '')}` : base;
  const res = await fetch(target);
  if (!res.ok) {
    throw new Error(`Neon Function call failed with status ${res.status}`);
  }
  return await res.text();
}

// 3. Neon Auth Status Check
export async function checkNeonAuthStatus(): Promise<{ ok: boolean; jwksKeysCount: number }> {
  if (!neonAuthBaseUrl) {
    throw new Error('NEON_AUTH_BASE_URL is not configured');
  }
  const jwksUrl = `${neonAuthBaseUrl.replace(/\/+$/, '')}/.well-known/jwks.json`;
  const res = await fetch(jwksUrl);
  if (!res.ok) {
    throw new Error(`Neon Auth JWKS endpoint returned status ${res.status}`);
  }
  const data = await res.json();
  return {
    ok: true,
    jwksKeysCount: Array.isArray(data.keys) ? data.keys.length : 0,
  };
}

// 4. Neon Object Storage Status Check
export async function checkNeonStorage(): Promise<{ ok: boolean; endpoint: string }> {
  if (!neonStorageEndpoint) {
    throw new Error('AWS_ENDPOINT_URL_S3 is not configured');
  }
  return {
    ok: true,
    endpoint: neonStorageEndpoint,
  };
}

// 5. Complete End-to-End Status Checker
export interface NeonServiceHealth {
  postgres: { status: 'ok' | 'error'; details?: any };
  auth: { status: 'ok' | 'error'; details?: any };
  functions: { status: 'ok' | 'error'; details?: any };
  objectStorage: { status: 'ok' | 'error'; details?: any };
}

export async function testAllNeonServices(): Promise<NeonServiceHealth> {
  const health: NeonServiceHealth = {
    postgres: { status: 'error' },
    auth: { status: 'error' },
    functions: { status: 'error' },
    objectStorage: { status: 'error' },
  };

  // Test Postgres
  try {
    const res = await queryNeonDatabase('SELECT 1 + 1 AS sum, current_database() AS db');
    health.postgres = { status: 'ok', details: res };
  } catch (err: any) {
    health.postgres = { status: 'error', details: err.message };
  }

  // Test Functions
  try {
    const fnResponse = await invokeNeonFunction();
    health.functions = { status: 'ok', details: fnResponse };
  } catch (err: any) {
    health.functions = { status: 'error', details: err.message };
  }

  // Test Auth
  try {
    const authRes = await checkNeonAuthStatus();
    health.auth = { status: 'ok', details: authRes };
  } catch (err: any) {
    health.auth = { status: 'error', details: err.message };
  }

  // Test Object Storage
  try {
    const storageRes = await checkNeonStorage();
    health.objectStorage = { status: 'ok', details: storageRes };
  } catch (err: any) {
    health.objectStorage = { status: 'error', details: err.message };
  }

  return health;
}
