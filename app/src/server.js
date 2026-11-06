import { createPool, initializeDatabase } from './db.js';
import { createApp } from './app.js';

const pool = createPool();
const port = Number(process.env.PORT ?? 3000);

// La tabla se crea al iniciar: el almacenamiento persistente está en PostgreSQL.
await initializeDatabase(pool);
const server = createApp(pool).listen(port, '0.0.0.0', () => {
  console.log(JSON.stringify({ level: 'info', component: 'api', message: 'listening', port }));
});

async function shutdown() {
  server.close(async () => { await pool.end(); process.exit(0); });
}
process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);
