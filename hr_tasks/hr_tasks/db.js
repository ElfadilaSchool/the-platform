const { Pool } = require('pg');
const path = require('path');
require('dotenv').config();
// Also load root-level .env (HR platform) if present
try { require('dotenv').config({ path: path.resolve(__dirname, '../../.env') }); } catch(_) {}

const pool = new Pool({
  user: process.env.DB_USER,
  host: process.env.DB_HOST,
  database: process.env.DB_NAME,
  password: process.env.DB_PASSWORD,
  port: process.env.DB_PORT,
});

pool.query('SELECT NOW()')
  .then(res => {
    console.log('✅ Connecté à PostgreSQL, date/heure serveur:', res.rows[0]);
  })
  .catch(err => {
    console.error('❌ Erreur connexion DB:', err);
  });

module.exports = pool;
