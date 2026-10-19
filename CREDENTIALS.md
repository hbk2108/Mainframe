# HealthCare+ Hospital Management System — Mainframe Edition
# Login Credentials Reference

## 🔐 Admin Account

| Username | Password | Role  |
|----------|----------|-------|
| admin    | admin123 | Admin |

**Access:** Full system control — staff management, ward management, doctor oversight, feedback review, DB2 statistics

---

## 👨‍⚕️ Doctor Accounts

All doctors use password: **doc123**

| Name                | Email                   | Specialization | Department   | Contact     |
|---------------------|-------------------------|----------------|--------------|-------------|
| Dr. Sarah Johnson   | sarah@hospital.com      | Cardiology     | Cardiology   | 555-0101    |
| Dr. Michael Chen    | michael@hospital.com    | Orthopedics    | Orthopedics  | 555-0102    |
| Dr. Emily Rodriguez | emily@hospital.com      | Neurology      | Neurology    | 555-0103    |
| Dr. James Wilson    | james@hospital.com      | Pediatrics     | Pediatrics   | 555-0104    |

**Access:** View appointments, update status (COMPLETED/CANCELLED), add prescriptions, view profile

---

## 👤 Patient Account

| Name     | Email           | Password   | Age | Gender |
|----------|-----------------|------------|-----|--------|
| John Doe | john@email.com  | patient123 | 35  | Male   |

**Access:** Book appointments, view health records & prescriptions, submit feedback

> **New patients** can self-register through the landing page → "Register" button

---

## 👥 Staff (View Only — Managed via Admin Panel)

| Name        | Role         | Contact  | Department |
|-------------|--------------|----------|------------|
| Alice Brown | Nurse        | 555-2001 | Cardiology |
| Bob Smith   | Nurse        | 555-2002 | Emergency  |
| Carol Davis | Receptionist | 555-2003 | Reception  |

---

## 🏥 Hospital Wards (DB2: HMS_WARDS table)

| Ward Type | Total Beds | Default Occupied | Tablespace  |
|-----------|------------|-----------------|-------------|
| ICU       | 20         | 5               | HMSDB.WRDTSPC |
| GENERAL   | 50         | 15              | HMSDB.WRDTSPC |
| EMERGENCY | 30         | 10              | HMSDB.WRDTSPC |

---

## 📝 Mainframe-Specific Notes

1. **Data is stored in SQLite (DB2 simulation for local dev)**
   - Production: IBM DB2 z/OS via `ibm_db` driver
   - Each API route maps to a COBOL program paragraph
   - DB2 table names: `HMS_PATIENTS`, `HMS_DOCTORS`, etc.

2. **COBOL Program Mapping**
   | User Action              | COBOL Program | Paragraph            |
   |--------------------------|---------------|----------------------|
   | Login (any role)         | HMSAUTH.cbl   | LOGIN-*-PARA         |
   | Register patient         | HMSAUTH.cbl   | PROCESS-REGISTER-PARA|
   | Book appointment         | HMSAPPT.cbl   | BOOK-APPT-PARA       |
   | View appointments        | HMSAPPT.cbl   | GET-PAT-APPTS-PARA   |
   | Add prescription         | HMSAPPT.cbl   | ADD-PRESC-PARA       |
   | Admin stats              | HMSADMIN.cbl  | GET-ADMIN-STATS-PARA |
   | Add staff                | HMSADMIN.cbl  | ADD-STAFF-PARA       |
   | Update ward              | HMSADMIN.cbl  | UPDATE-WARD-PARA     |

3. **Password Security**
   - Currently using plain text for demonstration
   - Production: RACF-managed passwords, DB2 column masks

4. **Role Selection on Login**
   - Always select the correct role tab (Patient / Doctor / Admin) before logging in
   - Admin uses **username** (`admin`), Doctors and Patients use **email**

---

## 🔄 How to Add New Users

### Add New Doctor (via DB2 / SQLite):
```sql
-- DB2 z/OS syntax:
INSERT INTO HMS.DOCTORS (DOC_NAME, SPECIALIZ, DOC_EMAIL, DOC_PASSWORD, DEPARTMENT, DOC_CONTACT)
VALUES ('Dr. New Doctor', 'Cardiology', 'newdoc@hospital.com', 'doc123', 'Cardiology', '555-0105');

-- Local SQLite simulation:
INSERT INTO HMS_DOCTORS (DOC_NAME, SPECIALIZ, DOC_EMAIL, DOC_PASSWORD, DEPARTMENT, DOC_CONTACT)
VALUES ('Dr. New Doctor', 'Cardiology', 'newdoc@hospital.com', 'doc123', 'Cardiology', '555-0105');
```

### Add New Staff (via Admin Dashboard):
1. Login as admin (`admin` / `admin123`)
2. Go to **Staff** tab
3. Fill in the "Add New Staff Member" form
4. Click **Add Staff Member** → calls `HMSADMIN: ADD-STAFF-PARA` → `INSERT INTO HMS.STAFF`

### Add New Patient:
- Self-register via the landing page Register button, OR
- Use DB2 INSERT directly into `HMS.PATIENTS`

---

## 🚀 Quick Start

```powershell
# Start the mainframe bridge server
node server.js

# Visit:
http://localhost:8080
```

---

*Data managed by IBM DB2 z/OS (local: SQLite simulation) — HealthCare+ Mainframe HMS*