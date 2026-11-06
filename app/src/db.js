import pg from 'pg';

export function createPool(env = process.env) {
  return new pg.Pool({
    host: env.DB_HOST ?? 'postgres',
    port: Number(env.DB_PORT ?? 5432),
    database: env.DB_NAME ?? 'demo',
    user: env.DB_USER ?? 'demo',
    password: env.DB_PASSWORD,
    connectionTimeoutMillis: 3000,
    max: 5,
  });
}

export async function initializeDatabase(pool) {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS notes (
      id BIGSERIAL PRIMARY KEY,
      text VARCHAR(200) NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
}
