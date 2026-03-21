// ============================================================
// Database connection pool (MySQL2)
// ============================================================
const mysql  = require('mysql2/promise');
const logger = require('../utils/logger');

let pool;

const initDb = async () => {
  pool = mysql.createPool({
    host:               process.env.DB_HOST || 'idmgmt_db',
    port:               parseInt(process.env.DB_PORT || '3306'),
    user:               process.env.DB_USER || 'idmgmt',
    password:           process.env.DB_PASSWORD || 'idmgmt_pass',
    database:           process.env.DB_NAME || 'idmgmt',
    waitForConnections: true,
    connectionLimit:    20,
    queueLimit:         0,
    timezone:           '+05:30',
    charset:            'utf8mb4',
    multipleStatements: false,
    namedPlaceholders:  true,
  });

  // Test connection
  const conn = await pool.getConnection();
  await conn.ping();
  conn.release();
  return pool;
};

const getPool = () => {
  if (!pool) throw new Error('Database not initialized. Call initDb() first.');
  return pool;
};

/**
 * Execute a query and return rows.
 * @param {string}  sql
 * @param {Array|Object} params
 */
const query = async (sql, params = []) => {
  const [rows] = await getPool().query(sql, params);
  return rows;
};

/**
 * Execute inside a transaction.
 * @param {Function} fn — receives `conn` and must return a value
 */
const transaction = async (fn) => {
  const conn = await getPool().getConnection();
  await conn.beginTransaction();
  try {
    const result = await fn(conn);
    await conn.commit();
    return result;
  } catch (err) {
    await conn.rollback();
    throw err;
  } finally {
    conn.release();
  }
};

module.exports = { initDb, getPool, query, transaction };
