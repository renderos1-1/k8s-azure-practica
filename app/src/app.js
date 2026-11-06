import express from 'express';

export function createApp(pool, env = process.env) {
  const app = express();
  app.use(express.json({ limit: '16kb' }));

  app.get('/health', (_req, res) => res.json({ status: 'ok', component: 'api' }));
  app.get('/config', (_req, res) => res.json({ environment: env.APP_ENV ?? 'local', databaseHost: env.DB_HOST ?? 'postgres' }));

  app.get('/notes', async (_req, res, next) => {
    try {
      const result = await pool.query('SELECT id, text, created_at FROM notes ORDER BY id');
      res.json({ notes: result.rows });
    } catch (err) { next(err); }
  });

  app.post('/notes', async (req, res, next) => {
    const text = req.body?.text;
    if (typeof text !== 'string' || !text.trim() || text.trim().length > 200) {
      return res.status(400).json({ error: 'text debe tener entre 1 y 200 caracteres' });
    }
    try {
      const result = await pool.query('INSERT INTO notes(text) VALUES($1) RETURNING id, text, created_at', [text.trim()]);
      res.status(201).json(result.rows[0]);
    } catch (err) { next(err); }
  });

  app.use((err, _req, res, _next) => {
    console.error(JSON.stringify({ level: 'error', component: 'api', message: err.message }));
    res.status(503).json({ error: 'No se pudo completar la operación' });
  });
  return app;
}
