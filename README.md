# 🖥️ Hospital Management System — IBM Mainframe Edition

> A production-grade Hospital Management System migrated from C++/MySQL to **IBM Mainframe technologies**: DB2, COBOL, and JCL — with the same modern HTML/CSS/JavaScript frontend.

---

## 🏛️ Technology Stack

| Layer | Original (C++ OOP) | **Mainframe Edition** |
|-------|--------------------|-----------------------|
| **Database** | MySQL 8.0 | **IBM DB2 for z/OS** |
| **Business Logic** | C++ classes (`hms.cpp`) | **COBOL programs** (`HMSAUTH`, `HMSAPPT`, `HMSADMIN`) |
| **Batch Processing** | None | **JCL jobs** (`HMSBATCH`, `HMSLOAD`, `HMSLOGIN`) |
| **Middleware / API** | Node.js + C++ exec | **Node.js REST → DB2 bridge** |
| **Frontend** | HTML5 + Tailwind CSS | HTML5 + Tailwind CSS (unchanged) |
| **Platform** | Windows / Linux | **IBM z/OS** |

---

## 📁 Project Structure

```
PROJECT_MF/
├── 📂 cobol/                          # COBOL Business Logic Programs
│   ├── HMSAUTH.cbl                    # Authentication (Login/Register)
│   ├── HMSAPPT.cbl                    # Appointment & Prescription Module
│   └── HMSADMIN.cbl                   # Admin: Ward, Staff, Feedback, Stats
│
├── 📂 db2/                            # IBM DB2 DDL Scripts
│   └── HMS_DDL.sql                    # Full DB2 schema (replaces hospital_schema.sql)
│
├── 📂 jcl/                            # JCL Job Control Language
│   ├── HMSBATCH.jcl                   # Master daily batch job
│   ├── HMSLOAD.jcl                    # Initial DB2 data load
│   └── HMSLOGIN.jcl                   # Login processing via COBOL
│
├── hospital_index.html                # Landing page (login/register)
├── patient.html                       # Patient portal
├── doctor.html                        # Doctor portal
├── admin.html                         # Admin panel
├── server.js                          # Node.js mainframe bridge server ⭐
├── package.json                       # Node.js dependencies
├── hms_mainframe.db                   # SQLite (local DB2 simulation)
├── .env                               # Environment configuration
├── README.md                          # This file
└── WHY_MAINFRAME.md                   # Why mainframe is the better choice
```

> **Legacy files preserved**: `hms.cpp`, `hms_classes.h`, `hospital_schema.sql` — the original C++ OOP codebase is kept for reference.

---

## ✨ Features

### 🏥 Three User Roles (Same as Original)

#### Patient Portal
- Dashboard with appointment & prescription stats
- Book appointments with doctors
- View health records and prescriptions
- Submit feedback

#### Doctor Portal
- Daily appointment management
- Update appointment status (COMPLETED / CANCELLED)
- Add prescriptions for patients
- Dashboard with statistics

#### Admin Panel
- Hospital overview with real-time stats
- Ward management (ICU, General, Emergency)
- Staff management (add/view)
- Doctor directory
- Patient feedback monitoring

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│             FRONTEND (Browser)                           │
│   hospital_index.html | patient.html | doctor.html       │
│   admin.html — HTML5 + TailwindCSS + JavaScript          │
└─────────────────────┬───────────────────────────────────┘
                       │ REST API (HTTP/JSON)
                       ▼
┌─────────────────────────────────────────────────────────┐
│         NODE.JS MAINFRAME BRIDGE (server.js)             │
│   Express REST API Gateway                               │
│   Routes map to COBOL program paragraphs:               │
│     POST /api/login    → HMSAUTH: LOGIN-*-PARA           │
│     GET  /api/doctors  → HMSADMIN: GET-DOCTORS-PARA      │
│     POST /api/appt/... → HMSAPPT: BOOK-APPT-PARA        │
└─────────────────────┬───────────────────────────────────┘
                       │ ibm_db (production) / SQLite (dev)
                       ▼
┌─────────────────────────────────────────────────────────┐
│              IBM DB2 z/OS (HMSDB)                        │
│   Tables: HMS_PATIENTS, HMS_DOCTORS, HMS_APPOINTMENTS   │
│           HMS_PRESCRIPTIONS, HMS_WARDS, HMS_STAFF        │
│           HMS_BILLING, HMS_FEEDBACK, HMS_ADMIN           │
│   Views:  V_APPT_DETAIL, V_PRESC_DETAIL                 │
│   Indexes: XPAT001, XDOC001, XAPT002, XPRX002 ...      │
└─────────────────────┬───────────────────────────────────┘
                       │ DB2 Catalog
                       ▼
┌─────────────────────────────────────────────────────────┐
│         JCL BATCH PROCESSING (HMSBATCH.jcl)             │
│   STEP010: Daily appointment report (HMSRPT01)          │
│   STEP020: Billing status update (HMSBILL01)            │
│   STEP030: Statistics aggregation (HMSSTAT01)           │
│   STEP040: DB2 RUNSTATS (optimizer statistics)          │
│   STEP050: IMAGE COPY (incremental backup to tape)      │
└─────────────────────────────────────────────────────────┘
```

---

## 🚀 Quick Start

### Prerequisites

- **Node.js** v18+ (for local development)
- **IBM z/OS** with DB2 (for production mainframe deployment)
- Web Browser (Chrome, Firefox, Edge)

### Step 1: Install Dependencies

```powershell
# From the project directory
D:\Softwares\nodeJS\npm.cmd install
```

### Step 2: Configure Environment

Copy `.env.example` to `.env` and update:

```env
# Local development (SQLite simulation)
DB_PATH=./hms_mainframe.db
PORT=8080

# Production mainframe (DB2 z/OS via ibm_db)
# DB_DSN=DATABASE=HMSDB;HOSTNAME=mainframe.hospital.com;PORT=50000;PROTOCOL=TCPIP;UID=HMSUSER;PWD=*****;
```

### Step 3: Start the Server

```powershell
node server.js
```

### Step 4: Open the Application

Visit: **http://localhost:8080**

---

## 🔐 Default Credentials

### Admin
- **Username**: `admin`
- **Password**: `admin123`

### Sample Doctors
| Name | Email | Password |
|------|-------|----------|
| Dr. Sarah Johnson | sarah@hospital.com | doc123 |
| Dr. Michael Chen | michael@hospital.com | doc123 |
| Dr. Emily Rodriguez | emily@hospital.com | doc123 |
| Dr. James Wilson | james@hospital.com | doc123 |

### Sample Patient
- **Email**: `john@email.com`
- **Password**: `patient123`

---

## 🗄️ DB2 Schema

### Tables (HMS Schema)

| Table | Columns | Key Constraints |
|-------|---------|----------------|
| `HMS.PATIENTS` | PATIENT_ID, PAT_NAME, PAT_AGE, PAT_GENDER, PAT_CONTACT, PAT_EMAIL, PAT_PASSWORD | PK, UQ(PAT_EMAIL), CK(AGE 1-120) |
| `HMS.DOCTORS` | DOCTOR_ID, DOC_NAME, SPECIALIZ, DOC_EMAIL, DOC_PASSWORD, DEPARTMENT, DOC_CONTACT, DOC_STATUS | PK, UQ(DOC_EMAIL), CK(STATUS) |
| `HMS.ADMIN` | ADMIN_ID, ADM_USERNAME, ADM_PASSWORD | PK, UQ(ADM_USERNAME) |
| `HMS.APPOINTMENTS` | APPT_ID, PATIENT_ID, DOCTOR_ID, APPT_DATE, APPT_TIME, APPT_STATUS, APPT_NOTES | PK, FK×2, CK(STATUS) |
| `HMS.PRESCRIPTIONS` | PRESC_ID, APPT_ID, PATIENT_ID, DOCTOR_ID, MEDICINE, DOSAGE, DURATION, DIAGNOSIS | PK, FK×3 |
| `HMS.WARDS` | WARD_ID, WARD_TYPE, TOTAL_BEDS, OCCPD_BEDS | PK, CK(beds ≥ 0) |
| `HMS.STAFF` | STAFF_ID, STF_NAME, STF_ROLE, STF_CONTACT, STF_DEPT, STF_STATUS | PK |
| `HMS.BILLING` | BILL_ID, PATIENT_ID, AMOUNT, BILL_STATUS, DESCRIPTION | PK, FK |
| `HMS.FEEDBACK` | FDBK_ID, PATIENT_ID, FDBK_MESSAGE, FDBK_DATE, FDBK_STATUS | PK, FK |

### Views
- `HMS.V_APPT_DETAIL` — Appointments with patient & doctor names
- `HMS.V_PRESC_DETAIL` — Prescriptions with doctor name and appointment date
- `HMS.V_FEEDBACK_DETAIL` — Feedback with patient names

---

## 📟 COBOL Programs

### HMSAUTH.cbl — Authentication Module

| Paragraph | Replaces (C++) | Function |
|-----------|---------------|----------|
| `LOGIN-PATIENT-PARA` | `HospitalSystem::login()` | Validate patient credentials via DB2 |
| `LOGIN-DOCTOR-PARA` | `HospitalSystem::login()` | Validate doctor credentials via DB2 |
| `LOGIN-ADMIN-PARA` | `HospitalSystem::login()` | Validate admin credentials via DB2 |
| `PROCESS-REGISTER-PARA` | `HospitalSystem::registerPatient()` | Insert new patient row |

### HMSAPPT.cbl — Appointment Module

| Paragraph | Replaces (C++) | Function |
|-----------|---------------|----------|
| `BOOK-APPT-PARA` | `bookAppointment()` | INSERT into HMS_APPOINTMENTS |
| `GET-PAT-APPTS-PARA` | `getPatientAppointments()` | Cursor over PAT-APPT-CUR |
| `GET-DOC-APPTS-PARA` | `getDoctorAppointments()` | Cursor over DOC-APPT-CUR |
| `UPDATE-APPT-PARA` | `updateAppointment()` | UPDATE appointment status |
| `ADD-PRESC-PARA` | `addPrescription()` | INSERT into HMS_PRESCRIPTIONS |
| `GET-PRESC-PARA` | `getPatientPrescriptions()` | Cursor over PRESC-CUR |
| `GET-PAT-DASH-PARA` | `getPatientDashboard()` | COUNT stats queries |
| `GET-DOC-PROFILE-PARA` | `getDoctorProfile()` | SELECT doctor row |

### HMSADMIN.cbl — Admin Module

| Paragraph | Replaces (C++) | Function |
|-----------|---------------|----------|
| `GET-ADMIN-STATS-PARA` | `getAdminStats()` | COUNT patients/doctors/appointments |
| `GET-DOCTORS-PARA` | `getAllDoctors()` | Cursor over DOC-CUR |
| `GET-STAFF-PARA` | `getAllStaff()` | Cursor over STAFF-CUR |
| `ADD-STAFF-PARA` | `addStaff()` | INSERT into HMS_STAFF |
| `UPDATE-WARD-PARA` | `updateWard()` | UPDATE HMS_WARDS |
| `GET-FEEDBACK-PARA` | `getAllFeedback()` | Cursor over FDBK-CUR |
| `ADD-FEEDBACK-PARA` | `addFeedback()` | INSERT into HMS_FEEDBACK |

---

## 📋 JCL Jobs

### HMSBATCH.jcl — Daily Batch Job
Scheduled at **23:00 daily** via JES2 scheduler:
1. **STEP010**: Daily appointment summary report → `HMS.RPT.APPT.D&DATE`
2. **STEP020**: Billing overdue status update
3. **STEP030**: Patient statistics aggregation
4. **STEP040**: DB2 RUNSTATS (keeps query optimizer current)
5. **STEP050**: Incremental IMAGE COPY backup to tape cartridge

### HMSLOAD.jcl — Initial Data Load
Run once to initialize DB2 tables with seed data via DB2 LOAD utility.

### HMSLOGIN.jcl — Login Processing
Submitted on demand for batch authentication processing via COBOL HMSAUTH.

---

## 🌐 API Reference

### Authentication
| Method | Endpoint | COBOL Program |
|--------|----------|--------------|
| POST | `/api/login` | HMSAUTH: LOGIN-*-PARA |
| POST | `/api/register` | HMSAUTH: PROCESS-REGISTER-PARA |

### Patient APIs
| Method | Endpoint | COBOL Program |
|--------|----------|--------------|
| GET | `/api/patient/dashboard?patient_id=` | HMSAPPT: GET-PAT-DASH-PARA |
| GET | `/api/patient/appointments?patient_id=` | HMSAPPT: GET-PAT-APPTS-PARA |
| GET | `/api/patient/prescriptions?patient_id=` | HMSAPPT: GET-PRESC-PARA |

### Doctor APIs
| Method | Endpoint | COBOL Program |
|--------|----------|--------------|
| GET | `/api/doctor/appointments?doctor_id=` | HMSAPPT: GET-DOC-APPTS-PARA |
| GET | `/api/doctor/profile?doctor_id=` | HMSAPPT: GET-DOC-PROFILE-PARA |
| POST | `/api/prescription/add` | HMSAPPT: ADD-PRESC-PARA |

### Appointment APIs
| Method | Endpoint | COBOL Program |
|--------|----------|--------------|
| POST | `/api/appointment/book` | HMSAPPT: BOOK-APPT-PARA |
| POST | `/api/appointment/update` | HMSAPPT: UPDATE-APPT-PARA |

### Admin APIs
| Method | Endpoint | COBOL Program |
|--------|----------|--------------|
| GET | `/api/admin/stats` | HMSADMIN: GET-ADMIN-STATS-PARA |
| GET | `/api/doctors` | HMSADMIN: GET-DOCTORS-PARA |
| GET | `/api/staff` | HMSADMIN: GET-STAFF-PARA |
| POST | `/api/staff/add` | HMSADMIN: ADD-STAFF-PARA |
| POST | `/api/ward/update` | HMSADMIN: UPDATE-WARD-PARA |
| GET | `/api/feedback` | HMSADMIN: GET-FEEDBACK-PARA |
| POST | `/api/feedback/submit` | HMSADMIN: ADD-FEEDBACK-PARA |

---

## 🔄 Production Deployment on z/OS

### 1. Compile COBOL Programs
```jcl
//COMPILE EXEC PROC=IGYWCL
//COBOL.SYSIN  DD DSN=HMS.SOURCE(HMSAUTH),DISP=SHR
//COBOL.SYSLIB DD DSN=HMS.COPYLIB,DISP=SHR
//LKED.SYSLMOD DD DSN=HMS.LOADLIB(HMSAUTH),DISP=SHR
```

### 2. DB2 BIND
```jcl
//BIND EXEC PGM=IKJEFT01
//SYSTSIN DD *
  DSN SYSTEM(DB2PROD)
  BIND PACKAGE(HMSPKG) MEMBER(HMSAUTH) ISOLATION(CS) VALIDATE(BIND)
  BIND PLAN(HMSPLAN) PKLIST(HMSPKG.*)
  END
```

### 3. Run DB2 Schema (HMS_DDL.sql)
Submit via SPUFI or DSN command processor.

### 4. Submit HMSLOAD.jcl to seed initial data

### 5. Deploy Node.js server on z/OS USS (Unix System Services)
```bash
cd /u/hms/app
node server.js &
```

### 6. Configure CICS REST for COBOL calls (optional)
CICS provides a production-grade COBOL invocation framework with built-in:
- Transaction monitoring
- Thread management
- Error isolation

---

## 🛠️ Troubleshooting

### Server won't start
- Check `hms_mainframe.db` is writable in project directory
- Ensure Node.js is in PATH or use full path to `node.exe`
- Check `.env` for correct configuration

### DB2 connection issues (production)
- Verify `ibm_db` is installed: `npm install ibm_db`
- Check DB2 connection string in `.env`
- Ensure z/OS DB2 subsystem is active

### COBOL compilation errors
- Check COBOL source member LRECL = 80
- Ensure DB2 DCLGEN copybooks are in SYSLIB
- Run with `CHECK(SYNTAX)` first

---

## 📚 Further Reading

- [WHY_MAINFRAME.md](./WHY_MAINFRAME.md) — Detailed justification for mainframe migration
- [IBM DB2 for z/OS Documentation](https://www.ibm.com/docs/en/db2-for-zos)
- [Enterprise COBOL Language Reference](https://www.ibm.com/docs/en/cobol-zos)
- [z/OS JCL Reference](https://www.ibm.com/docs/en/zos/2.5.0?topic=reference-zos-jcl)

---

## 📝 License

This project is created for educational purposes at VIT University.

---