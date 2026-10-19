/**
 * ================================================================
 * HMS - Hospital Management System
 * Mainframe Middleware Bridge Server
 * ================================================================
 * Technology Stack:
 *   - Node.js (REST API Gateway / Web Server)
 *   - IBM DB2 via ibm_db driver (simulated with sqlite3 for dev)
 *   - COBOL business logic programs (HMSAUTH, HMSAPPT, HMSADMIN)
 *   - JCL batch job invocation via child_process
 *
 * Architecture:
 *   Frontend (HTML/JS) ← REST API → Node.js Middleware
 *                                       ↓
 *                              IBM DB2 z/OS via ibm_db
 *                                       ↓
 *                           COBOL Programs (HMSAUTH, HMSAPPT, HMSADMIN)
 *
 * COBOL programs are simulated here in Node.js for local dev.
 * In production on z/OS: Node.js calls DB2 directly via ibm_db
 * or invokes COBOL programs via CICS REST services / MVS console.
 * ================================================================
 */

const express    = require('express');
const cors       = require('cors');
const path       = require('path');
const Database   = require('better-sqlite3');
require('dotenv').config();

const app = express();
app.use(cors());
app.use(express.json());
app.use(express.static(__dirname));  // Serve HTML files

// ================================================================
// DB2 SIMULATION LAYER
// In production: replace with ibm_db connection to z/OS DB2
// Connection string: DATABASE=HMSDB;HOSTNAME=mainframe;PORT=50000;
//                    PROTOCOL=TCPIP;UID=HMSUSER;PWD=*****;
// ================================================================
const DB_PATH = process.env.DB_PATH || path.join(__dirname, 'hms_mainframe.db');
let db;

try {
    db = new Database(DB_PATH);
    db.pragma('journal_mode = WAL');
    db.pragma('foreign_keys = ON');
    initializeDB();
    console.log('\n✅ DB2 Simulation Layer: SQLite (local dev mode)');
    console.log('   Production: ibm_db → IBM DB2 z/OS HMSDB subsystem\n');
} catch (err) {
    console.error('❌ Database initialization failed:', err.message);
    process.exit(1);
}

// ================================================================
// DATABASE INITIALIZATION (Mirrors DB2 DDL - HMS_DDL.sql)
// ================================================================
function initializeDB() {
    db.exec(`
        CREATE TABLE IF NOT EXISTS HMS_PATIENTS (
            PATIENT_ID   INTEGER PRIMARY KEY AUTOINCREMENT,
            PAT_NAME     TEXT    NOT NULL,
            PAT_AGE      INTEGER NOT NULL CHECK(PAT_AGE BETWEEN 1 AND 120),
            PAT_GENDER   TEXT    NOT NULL CHECK(PAT_GENDER IN ('Male','Female','Other')),
            PAT_CONTACT  TEXT    NOT NULL,
            PAT_EMAIL    TEXT    NOT NULL UNIQUE,
            PAT_PASSWORD TEXT    NOT NULL,
            CREATED_AT   TEXT    DEFAULT (datetime('now'))
        );
        CREATE TABLE IF NOT EXISTS HMS_DOCTORS (
            DOCTOR_ID    INTEGER PRIMARY KEY AUTOINCREMENT,
            DOC_NAME     TEXT    NOT NULL,
            SPECIALIZ    TEXT    NOT NULL,
            DOC_EMAIL    TEXT    NOT NULL UNIQUE,
            DOC_PASSWORD TEXT    NOT NULL,
            DEPARTMENT   TEXT    NOT NULL,
            DOC_CONTACT  TEXT    NOT NULL,
            DOC_STATUS   TEXT    NOT NULL DEFAULT 'ACTIVE'
                             CHECK(DOC_STATUS IN ('ACTIVE','INACTIVE')),
            CREATED_AT   TEXT    DEFAULT (datetime('now'))
        );
        CREATE TABLE IF NOT EXISTS HMS_ADMIN (
            ADMIN_ID     INTEGER PRIMARY KEY AUTOINCREMENT,
            ADM_USERNAME TEXT    NOT NULL UNIQUE,
            ADM_PASSWORD TEXT    NOT NULL,
            CREATED_AT   TEXT    DEFAULT (datetime('now'))
        );
        CREATE TABLE IF NOT EXISTS HMS_APPOINTMENTS (
            APPT_ID      INTEGER PRIMARY KEY AUTOINCREMENT,
            PATIENT_ID   INTEGER NOT NULL REFERENCES HMS_PATIENTS(PATIENT_ID),
            DOCTOR_ID    INTEGER NOT NULL REFERENCES HMS_DOCTORS(DOCTOR_ID),
            APPT_DATE    TEXT    NOT NULL,
            APPT_TIME    TEXT    NOT NULL,
            APPT_STATUS  TEXT    NOT NULL DEFAULT 'SCHEDULED'
                             CHECK(APPT_STATUS IN ('SCHEDULED','COMPLETED','CANCELLED')),
            APPT_NOTES   TEXT,
            CREATED_AT   TEXT    DEFAULT (datetime('now'))
        );
        CREATE TABLE IF NOT EXISTS HMS_PRESCRIPTIONS (
            PRESC_ID     INTEGER PRIMARY KEY AUTOINCREMENT,
            APPT_ID      INTEGER NOT NULL REFERENCES HMS_APPOINTMENTS(APPT_ID),
            PATIENT_ID   INTEGER NOT NULL REFERENCES HMS_PATIENTS(PATIENT_ID),
            DOCTOR_ID    INTEGER NOT NULL REFERENCES HMS_DOCTORS(DOCTOR_ID),
            MEDICINE     TEXT    NOT NULL,
            DOSAGE       TEXT    NOT NULL,
            DURATION     TEXT    NOT NULL,
            DIAGNOSIS    TEXT,
            PRESC_NOTES  TEXT,
            CREATED_AT   TEXT    DEFAULT (datetime('now'))
        );
        CREATE TABLE IF NOT EXISTS HMS_WARDS (
            WARD_ID      INTEGER PRIMARY KEY AUTOINCREMENT,
            WARD_TYPE    TEXT    NOT NULL,
            TOTAL_BEDS   INTEGER NOT NULL,
            OCCPD_BEDS   INTEGER NOT NULL DEFAULT 0,
            CREATED_AT   TEXT    DEFAULT (datetime('now'))
        );
        CREATE TABLE IF NOT EXISTS HMS_STAFF (
            STAFF_ID     INTEGER PRIMARY KEY AUTOINCREMENT,
            STF_NAME     TEXT    NOT NULL,
            STF_ROLE     TEXT    NOT NULL,
            STF_CONTACT  TEXT    NOT NULL,
            STF_EMAIL    TEXT,
            STF_DEPT     TEXT,
            STF_STATUS   TEXT    NOT NULL DEFAULT 'ACTIVE',
            CREATED_AT   TEXT    DEFAULT (datetime('now'))
        );
        CREATE TABLE IF NOT EXISTS HMS_BILLING (
            BILL_ID      INTEGER PRIMARY KEY AUTOINCREMENT,
            PATIENT_ID   INTEGER NOT NULL REFERENCES HMS_PATIENTS(PATIENT_ID),
            AMOUNT       REAL    NOT NULL,
            BILL_STATUS  TEXT    NOT NULL DEFAULT 'PENDING',
            DESCRIPTION  TEXT,
            PAYMENT_DATE TEXT,
            CREATED_AT   TEXT    DEFAULT (datetime('now'))
        );
        CREATE TABLE IF NOT EXISTS HMS_FEEDBACK (
            FDBK_ID      INTEGER PRIMARY KEY AUTOINCREMENT,
            PATIENT_ID   INTEGER NOT NULL REFERENCES HMS_PATIENTS(PATIENT_ID),
            FDBK_MESSAGE TEXT    NOT NULL,
            FDBK_DATE    TEXT    NOT NULL,
            FDBK_STATUS  TEXT    NOT NULL DEFAULT 'UNREAD',
            CREATED_AT   TEXT    DEFAULT (datetime('now'))
        );
    `);

    // Seed data — mirrors DB2 INSERT statements in HMS_DDL.sql
    const adminExists = db.prepare('SELECT 1 FROM HMS_ADMIN LIMIT 1').get();
    if (!adminExists) {
        db.exec(`
            INSERT INTO HMS_ADMIN (ADM_USERNAME, ADM_PASSWORD) VALUES ('admin', 'admin123');
            INSERT INTO HMS_WARDS (WARD_TYPE, TOTAL_BEDS, OCCPD_BEDS) VALUES ('ICU', 20, 5);
            INSERT INTO HMS_WARDS (WARD_TYPE, TOTAL_BEDS, OCCPD_BEDS) VALUES ('GENERAL', 50, 15);
            INSERT INTO HMS_WARDS (WARD_TYPE, TOTAL_BEDS, OCCPD_BEDS) VALUES ('EMERGENCY', 30, 10);
            INSERT INTO HMS_DOCTORS (DOC_NAME, SPECIALIZ, DOC_EMAIL, DOC_PASSWORD, DEPARTMENT, DOC_CONTACT)
                VALUES ('Dr. Sarah Johnson', 'Cardiology', 'sarah@hospital.com', 'doc123', 'Cardiology', '555-0101');
            INSERT INTO HMS_DOCTORS (DOC_NAME, SPECIALIZ, DOC_EMAIL, DOC_PASSWORD, DEPARTMENT, DOC_CONTACT)
                VALUES ('Dr. Michael Chen', 'Orthopedics', 'michael@hospital.com', 'doc123', 'Orthopedics', '555-0102');
            INSERT INTO HMS_DOCTORS (DOC_NAME, SPECIALIZ, DOC_EMAIL, DOC_PASSWORD, DEPARTMENT, DOC_CONTACT)
                VALUES ('Dr. Emily Rodriguez', 'Neurology', 'emily@hospital.com', 'doc123', 'Neurology', '555-0103');
            INSERT INTO HMS_DOCTORS (DOC_NAME, SPECIALIZ, DOC_EMAIL, DOC_PASSWORD, DEPARTMENT, DOC_CONTACT)
                VALUES ('Dr. James Wilson', 'Pediatrics', 'james@hospital.com', 'doc123', 'Pediatrics', '555-0104');
            INSERT INTO HMS_PATIENTS (PAT_NAME, PAT_AGE, PAT_GENDER, PAT_CONTACT, PAT_EMAIL, PAT_PASSWORD)
                VALUES ('John Doe', 35, 'Male', '555-1234', 'john@email.com', 'patient123');
            INSERT INTO HMS_STAFF (STF_NAME, STF_ROLE, STF_CONTACT, STF_DEPT)
                VALUES ('Alice Brown', 'Nurse', '555-2001', 'Cardiology');
            INSERT INTO HMS_STAFF (STF_NAME, STF_ROLE, STF_CONTACT, STF_DEPT)
                VALUES ('Bob Smith', 'Nurse', '555-2002', 'Emergency');
            INSERT INTO HMS_STAFF (STF_NAME, STF_ROLE, STF_CONTACT, STF_DEPT)
                VALUES ('Carol Davis', 'Receptionist', '555-2003', 'Reception');
        `);
        console.log('✅ DB2 Schema seeded with initial data\n');
    }
}

// ================================================================
// COBOL HMSAUTH - LOGIN / REGISTER
// In production: CICS REST → COBOL HMSAUTH program on z/OS
// ================================================================

// POST /api/login
app.post('/api/login', (req, res) => {
    const { email, password, role } = req.body;
    // Simulates COBOL HMSAUTH LOGIN-PATIENT-PARA / LOGIN-DOCTOR-PARA / LOGIN-ADMIN-PARA
    try {
        let row;
        if (role === 'patient') {
            row = db.prepare(
                `SELECT PATIENT_ID AS id, PAT_NAME AS name, PAT_EMAIL AS email
                 FROM HMS_PATIENTS
                 WHERE PAT_EMAIL = ? AND PAT_PASSWORD = ?`
            ).get(email, password);
            if (row) return res.json({ success: true, role: 'patient', user: row });
        } else if (role === 'doctor') {
            row = db.prepare(
                `SELECT DOCTOR_ID AS id, DOC_NAME AS name, DOC_EMAIL AS email,
                        SPECIALIZ AS specialization, DEPARTMENT AS department
                 FROM HMS_DOCTORS
                 WHERE DOC_EMAIL = ? AND DOC_PASSWORD = ? AND DOC_STATUS = 'ACTIVE'`
            ).get(email, password);
            if (row) return res.json({ success: true, role: 'doctor', user: row });
        } else if (role === 'admin') {
            row = db.prepare(
                `SELECT ADMIN_ID AS id, ADM_USERNAME AS username
                 FROM HMS_ADMIN
                 WHERE ADM_USERNAME = ? AND ADM_PASSWORD = ?`
            ).get(email, password);
            if (row) return res.json({ success: true, role: 'admin', user: row });
        } else {
            return res.json({ success: false, error: 'Invalid role' });
        }
        res.json({ success: false, error: 'Invalid credentials' });
    } catch (err) {
        res.json({ success: false, error: err.message });
    }
});

// POST /api/register  → COBOL HMSAUTH PROCESS-REGISTER-PARA
app.post('/api/register', (req, res) => {
    const { name, age, gender, contact, email, password } = req.body;
    try {
        const stmt = db.prepare(
            `INSERT INTO HMS_PATIENTS (PAT_NAME, PAT_AGE, PAT_GENDER, PAT_CONTACT, PAT_EMAIL, PAT_PASSWORD)
             VALUES (?, ?, ?, ?, ?, ?)`
        );
        const result = stmt.run(name, age, gender, contact, email, password);
        res.json({ success: true, patient_id: result.lastInsertRowid });
    } catch (err) {
        if (err.message.includes('UNIQUE')) {
            res.json({ success: false, error: 'Email already registered' });
        } else {
            res.json({ success: false, error: err.message });
        }
    }
});

// ================================================================
// COBOL HMSAPPT - APPOINTMENT / PRESCRIPTION MODULE
// ================================================================

// GET /api/doctors  → COBOL HMSADMIN GET-DOCTORS-PARA
app.get('/api/doctors', (req, res) => {
    try {
        const rows = db.prepare(
            `SELECT DOCTOR_ID AS id, DOC_NAME AS name,
                    SPECIALIZ AS specialization, DEPARTMENT AS department,
                    DOC_CONTACT AS contact
             FROM HMS_DOCTORS WHERE DOC_STATUS = 'ACTIVE'
             ORDER BY SPECIALIZ, DOC_NAME`
        ).all();
        res.json(rows);
    } catch (err) { res.json({ error: err.message }); }
});

// GET /api/patient/dashboard  → COBOL HMSAPPT GET-PAT-DASH-PARA
app.get('/api/patient/dashboard', (req, res) => {
    const { patient_id } = req.query;
    try {
        const apptCount = db.prepare(
            `SELECT COUNT(*) AS cnt FROM HMS_APPOINTMENTS WHERE PATIENT_ID = ?`
        ).get(patient_id);
        const presCount = db.prepare(
            `SELECT COUNT(*) AS cnt FROM HMS_PRESCRIPTIONS WHERE PATIENT_ID = ?`
        ).get(patient_id);
        res.json({
            total_appointments: apptCount.cnt,
            total_prescriptions: presCount.cnt,
            pending_bills: '0'
        });
    } catch (err) { res.json({ error: err.message }); }
});

// GET /api/patient/appointments  → COBOL HMSAPPT GET-PAT-APPTS-PARA (PAT-APPT-CUR)
app.get('/api/patient/appointments', (req, res) => {
    const { patient_id } = req.query;
    try {
        const rows = db.prepare(
            `SELECT A.APPT_ID AS id, A.APPT_DATE AS date, A.APPT_TIME AS time,
                    A.APPT_STATUS AS status, A.APPT_NOTES AS notes, A.PATIENT_ID AS patient_id,
                    D.DOC_NAME AS doctor_name, D.SPECIALIZ AS specialization
             FROM HMS_APPOINTMENTS A
             JOIN HMS_DOCTORS D ON A.DOCTOR_ID = D.DOCTOR_ID
             WHERE A.PATIENT_ID = ?
             ORDER BY A.APPT_DATE DESC, A.APPT_TIME DESC`
        ).all(patient_id);
        res.json(rows);
    } catch (err) { res.json({ error: err.message }); }
});

// GET /api/patient/prescriptions  → COBOL HMSAPPT GET-PRESC-PARA (PRESC-CUR)
app.get('/api/patient/prescriptions', (req, res) => {
    const { patient_id } = req.query;
    try {
        const rows = db.prepare(
            `SELECT PR.PRESC_ID AS id, PR.MEDICINE AS medicine, PR.DOSAGE AS dosage,
                    PR.DURATION AS duration, PR.DIAGNOSIS AS diagnosis,
                    PR.PRESC_NOTES AS notes, PR.CREATED_AT AS created_at,
                    D.DOC_NAME AS doctor_name,
                    A.APPT_DATE AS date, A.APPT_TIME AS time
             FROM HMS_PRESCRIPTIONS PR
             JOIN HMS_DOCTORS D ON PR.DOCTOR_ID = D.DOCTOR_ID
             JOIN HMS_APPOINTMENTS A ON PR.APPT_ID = A.APPT_ID
             WHERE PR.PATIENT_ID = ?
             ORDER BY PR.CREATED_AT DESC`
        ).all(patient_id);
        res.json(rows);
    } catch (err) { res.json({ error: err.message }); }
});

// POST /api/appointment/book  → COBOL HMSAPPT BOOK-APPT-PARA
app.post('/api/appointment/book', (req, res) => {
    const { patient_id, doctor_id, date, time } = req.body;
    try {
        const result = db.prepare(
            `INSERT INTO HMS_APPOINTMENTS (PATIENT_ID, DOCTOR_ID, APPT_DATE, APPT_TIME, APPT_STATUS)
             VALUES (?, ?, ?, ?, 'SCHEDULED')`
        ).run(patient_id, doctor_id, date, time);
        res.json({ success: true, appointment_id: result.lastInsertRowid });
    } catch (err) {
        res.json({ success: false, error: err.message });
    }
});

// POST /api/appointment/update  → COBOL HMSAPPT UPDATE-APPT-PARA
app.post('/api/appointment/update', (req, res) => {
    const { appointment_id, status, notes } = req.body;
    try {
        db.prepare(
            `UPDATE HMS_APPOINTMENTS SET APPT_STATUS = ?, APPT_NOTES = ? WHERE APPT_ID = ?`
        ).run(status.toUpperCase(), notes || '', appointment_id);
        res.json({ success: true });
    } catch (err) {
        res.json({ success: false, error: err.message });
    }
});

// GET /api/doctor/appointments  → COBOL HMSAPPT GET-DOC-APPTS-PARA (DOC-APPT-CUR)
app.get('/api/doctor/appointments', (req, res) => {
    const { doctor_id } = req.query;
    try {
        const rows = db.prepare(
            `SELECT A.APPT_ID AS id, A.APPT_DATE AS date, A.APPT_TIME AS time,
                    A.APPT_STATUS AS status, A.APPT_NOTES AS notes, A.PATIENT_ID AS patient_id,
                    P.PAT_NAME AS patient_name, P.PAT_AGE AS age, P.PAT_CONTACT AS contact
             FROM HMS_APPOINTMENTS A
             JOIN HMS_PATIENTS P ON A.PATIENT_ID = P.PATIENT_ID
             WHERE A.DOCTOR_ID = ?
             ORDER BY A.APPT_DATE DESC, A.APPT_TIME DESC`
        ).all(doctor_id);
        res.json(rows);
    } catch (err) { res.json({ error: err.message }); }
});

// GET /api/doctor/profile  → COBOL HMSAPPT GET-DOC-PROFILE-PARA
app.get('/api/doctor/profile', (req, res) => {
    const { doctor_id } = req.query;
    try {
        const row = db.prepare(
            `SELECT DOCTOR_ID AS id, DOC_NAME AS name, SPECIALIZ AS specialization,
                    DEPARTMENT AS department, DOC_CONTACT AS contact, DOC_EMAIL AS email
             FROM HMS_DOCTORS WHERE DOCTOR_ID = ?`
        ).get(doctor_id);
        res.json(row || {});
    } catch (err) { res.json({}); }
});

// POST /api/prescription/add  → COBOL HMSAPPT ADD-PRESC-PARA
app.post('/api/prescription/add', (req, res) => {
    const { appointment_id, patient_id, doctor_id, medicine, dosage, duration, diagnosis, notes } = req.body;
    try {
        const result = db.prepare(
            `INSERT INTO HMS_PRESCRIPTIONS
                 (APPT_ID, PATIENT_ID, DOCTOR_ID, MEDICINE, DOSAGE, DURATION, DIAGNOSIS, PRESC_NOTES)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?)`
        ).run(appointment_id, patient_id, doctor_id, medicine, dosage, duration, diagnosis, notes || '');
        res.json({ success: true, prescription_id: result.lastInsertRowid });
    } catch (err) {
        res.json({ success: false, error: err.message });
    }
});

// ================================================================
// COBOL HMSADMIN - ADMIN MODULE
// ================================================================

// GET /api/admin/stats  → COBOL HMSADMIN GET-ADMIN-STATS-PARA
app.get('/api/admin/stats', (req, res) => {
    try {
        const pats  = db.prepare(`SELECT COUNT(*) AS cnt FROM HMS_PATIENTS`).get();
        const docs  = db.prepare(`SELECT COUNT(*) AS cnt FROM HMS_DOCTORS WHERE DOC_STATUS = 'ACTIVE'`).get();
        const today = db.prepare(`SELECT COUNT(*) AS cnt FROM HMS_APPOINTMENTS WHERE APPT_DATE = date('now')`).get();
        const wards = db.prepare(
            `SELECT WARD_ID AS ward_id, WARD_TYPE AS type, TOTAL_BEDS AS total_beds, OCCPD_BEDS AS occupied_beds
             FROM HMS_WARDS ORDER BY WARD_ID`
        ).all();
        res.json({
            total_patients:      pats.cnt,
            total_doctors:       docs.cnt,
            today_appointments:  today.cnt,
            wards
        });
    } catch (err) { res.json({ error: err.message }); }
});

// GET /api/staff  → COBOL HMSADMIN GET-STAFF-PARA (STAFF-CUR)
app.get('/api/staff', (req, res) => {
    try {
        const rows = db.prepare(
            `SELECT STAFF_ID AS id, STF_NAME AS name, STF_ROLE AS role,
                    STF_CONTACT AS contact, STF_DEPT AS department, STF_STATUS AS status
             FROM HMS_STAFF WHERE STF_STATUS = 'ACTIVE' ORDER BY STF_ROLE, STF_NAME`
        ).all();
        res.json(rows);
    } catch (err) { res.json([]); }
});

// POST /api/staff/add  → COBOL HMSADMIN ADD-STAFF-PARA
app.post('/api/staff/add', (req, res) => {
    const { name, role, contact, department } = req.body;
    try {
        const result = db.prepare(
            `INSERT INTO HMS_STAFF (STF_NAME, STF_ROLE, STF_CONTACT, STF_DEPT) VALUES (?, ?, ?, ?)`
        ).run(name, role, contact, department || '');
        res.json({ success: true, staff_id: result.lastInsertRowid });
    } catch (err) {
        res.json({ success: false, error: err.message });
    }
});

// POST /api/ward/update  → COBOL HMSADMIN UPDATE-WARD-PARA
app.post('/api/ward/update', (req, res) => {
    const { ward_id, occupied_beds } = req.body;
    try {
        db.prepare(
            `UPDATE HMS_WARDS SET OCCPD_BEDS = ? WHERE WARD_ID = ?`
        ).run(occupied_beds, ward_id);
        res.json({ success: true });
    } catch (err) {
        res.json({ success: false, error: err.message });
    }
});

// GET /api/feedback  → COBOL HMSADMIN GET-FEEDBACK-PARA (FDBK-CUR)
app.get('/api/feedback', (req, res) => {
    try {
        const rows = db.prepare(
            `SELECT F.FDBK_ID AS id, F.PATIENT_ID AS patient_id,
                    F.FDBK_MESSAGE AS message, F.FDBK_DATE AS date,
                    F.FDBK_STATUS AS status, P.PAT_NAME AS patient_name
             FROM HMS_FEEDBACK F
             JOIN HMS_PATIENTS P ON F.PATIENT_ID = P.PATIENT_ID
             ORDER BY F.CREATED_AT DESC`
        ).all();
        res.json(rows);
    } catch (err) { res.json([]); }
});

// POST /api/feedback/submit  → COBOL HMSADMIN ADD-FEEDBACK-PARA
app.post('/api/feedback/submit', (req, res) => {
    const { patient_id, message } = req.body;
    try {
        const today = new Date().toISOString().split('T')[0];
        const result = db.prepare(
            `INSERT INTO HMS_FEEDBACK (PATIENT_ID, FDBK_MESSAGE, FDBK_DATE) VALUES (?, ?, ?)`
        ).run(patient_id, message, today);
        res.json({ success: true, feedback_id: result.lastInsertRowid });
    } catch (err) {
        res.json({ success: false, error: err.message });
    }
});

// Serve landing page
app.get('/', (req, res) => res.sendFile(path.join(__dirname, 'hospital_index.html')));

// ================================================================
// START SERVER
// ================================================================
const PORT = process.env.PORT || 8080;
app.listen(PORT, () => {
    console.log('\n╔═══════════════════════════════════════════════════════╗');
    console.log('║    HMS - HOSPITAL MANAGEMENT SYSTEM (MAINFRAME)       ║');
    console.log('╠═══════════════════════════════════════════════════════╣');
    console.log(`║  🖥️  Web Server   : http://localhost:${PORT}             ║`);
    console.log('║  🗄️  DB2 Engine   : IBM DB2 z/OS (simulated: SQLite)  ║');
    console.log('║  📟 COBOL Progs  : HMSAUTH, HMSAPPT, HMSADMIN        ║');
    console.log('║  📋 JCL Jobs     : HMSBATCH, HMSLOAD, HMSLOGIN       ║');
    console.log('║  ✅ All API endpoints ready                           ║');
    console.log('╚═══════════════════════════════════════════════════════╝\n');
});