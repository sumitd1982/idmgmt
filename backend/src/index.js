// ============================================================
// ID MANAGEMENT SYSTEM — Main Express Server
// ============================================================
require('dotenv').config();
const express      = require('express');
const cors         = require('cors');
const helmet       = require('helmet');
const compression  = require('compression');
const morgan       = require('morgan');
const rateLimit    = require('express-rate-limit');
const path         = require('path');
const http         = require('http');
const { Server }   = require('socket.io');
const logger       = require('./utils/logger');
const { initDb }   = require('./models/db');

// ─── Routes ──────────────────────────────────────────────────
const authRoutes      = require('./routes/auth');
const schoolRoutes    = require('./routes/schools');
const branchRoutes    = require('./routes/branches');
const employeeRoutes  = require('./routes/employees');
const studentRoutes   = require('./routes/students');
const orgRoutes       = require('./routes/org');
const idCardRoutes    = require('./routes/idcards');
const reportRoutes    = require('./routes/reports');
const parentRoutes    = require('./routes/parent');
const requestRoutes   = require('./routes/requests');
const notifRoutes     = require('./routes/notifications');
const uploadRoutes    = require('./routes/uploads');
const inviteRoutes       = require('./routes/invites');
const idTemplateRoutes   = require('./routes/id_templates');
const attendanceRoutes   = require('./routes/attendance');
const messagingRoutes    = require('./routes/messaging');
const dashboardRoutes    = require('./routes/dashboard');
const userRoutes        = require('./routes/users');
const settingsRoutes    = require('./routes/settings');

const app    = express();
const server = http.createServer(app);
const io     = new Server(server, {
  cors: { origin: '*', methods: ['GET', 'POST'] },
  path: '/idmgmt/socket.io'
});

// ─── Socket.IO ───────────────────────────────────────────────
io.on('connection', (socket) => {
  logger.info(`Socket connected: ${socket.id}`);
  socket.on('join_school', (schoolId) => socket.join(`school:${schoolId}`));
  socket.on('join_branch', (branchId) => socket.join(`branch:${branchId}`));
  socket.on('disconnect', () => logger.info(`Socket disconnected: ${socket.id}`));
});
app.set('io', io);

// Trust nginx reverse proxy
app.set('trust proxy', 1);

// ─── Security & Middleware ────────────────────────────────────
app.use(helmet({
  contentSecurityPolicy: false,
  crossOriginEmbedderPolicy: false
}));
app.use(compression());
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || '*',
  credentials: true
}));
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));
app.use(morgan('combined', {
  stream: { write: (msg) => logger.info(msg.trim()) }
}));

// ─── Rate Limiting ────────────────────────────────────────────
const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 300,
  standardHeaders: true,
  legacyHeaders: false,
  message: { success: false, message: 'Too many requests, please try again later.' }
});

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10000, // Significantly increased for testing all roles (Staff/Parent/SuperAdmin)
  skip: (req) => {
    const phone = req.body.phone?.replace(/\D/g, '') || '';
    const superAdminSfx = ['8826756777', '9818190050', '98181190050'];
    return superAdminSfx.some(sfx => phone.endsWith(sfx));
  },
  message: { success: false, message: 'Too many auth attempts, please try again later.' }
});

// ─── Static uploads ──────────────────────────────────────────
app.use('/idmgmt/api/static', express.static(path.join(__dirname, '../uploads')));

// ─── Health Check ─────────────────────────────────────────────
app.get('/idmgmt/api/health', (req, res) => {
  res.json({
    success: true,
    service: 'idmgmt-api',
    version: '1.0.0',
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

// ─── API Routes (all prefixed with /idmgmt/api) ──────────────
const base = '/idmgmt/api';
app.use(`${base}/auth`,          authLimiter, authRoutes);
app.use(`${base}/schools`,       apiLimiter,  schoolRoutes);
app.use(`${base}/branches`,      apiLimiter,  branchRoutes);
app.use(`${base}/employees`,     apiLimiter,  employeeRoutes);
app.use(`${base}/students`,      apiLimiter,  studentRoutes);
app.use(`${base}/org`,           apiLimiter,  orgRoutes);
app.use(`${base}/id-cards`,      apiLimiter,  idCardRoutes);
app.use(`${base}/reports`,       apiLimiter,  reportRoutes);
app.use(`${base}/parent`,        apiLimiter,  parentRoutes);
app.use(`${base}/requests`,      apiLimiter,  requestRoutes);
app.use(`${base}/notifications`, apiLimiter,  notifRoutes);
app.use(`${base}/uploads`,       apiLimiter,  uploadRoutes);
app.use(`${base}/invites`,       apiLimiter,  inviteRoutes);
app.use(`${base}/id-templates`,  apiLimiter,  idTemplateRoutes);
app.use(`${base}/attendance`,    apiLimiter,  attendanceRoutes);
app.use(`${base}/messaging`,     apiLimiter,  messagingRoutes);
app.use(`${base}/dashboard`,     apiLimiter,  dashboardRoutes);
app.use(`${base}/users`,         apiLimiter,  userRoutes);
app.use(`${base}/settings`,      apiLimiter,  settingsRoutes);

// ─── Error Handler ───────────────────────────────────────────
app.use((err, req, res, next) => {
  logger.error(`${err.message} — ${req.method} ${req.path}`, { stack: err.stack });
  const status = err.status || err.statusCode || 500;
  res.status(status).json({
    success: false,
    message: err.message || 'Internal Server Error',
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack })
  });
});

app.use((req, res) => {
  res.status(404).json({ success: false, message: `Route not found: ${req.path}` });
});

// ─── Boot ─────────────────────────────────────────────────────
const PORT = process.env.PORT || 3001;

(async () => {
  try {
    await initDb();
    logger.info('✅ Database connected');
    server.listen(PORT, '0.0.0.0', () => {
      logger.info(`🚀 IDMgmt API running on port ${PORT}`);
    });
  } catch (err) {
    logger.error('Failed to start server:', err);
    process.exit(1);
  }
})();

module.exports = { app, io };
