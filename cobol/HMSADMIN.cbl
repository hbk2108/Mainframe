      *================================================================*
      * PROGRAM:   HMSADMIN                                           *
      * PURPOSE:   Hospital Management System - Admin Module           *
      * LANGUAGE:  COBOL with Embedded DB2 SQL (DB2 z/OS)            *
      * AUTHOR:    HMS Team | VIT University                          *
      * REPLACES:  C++ HospitalSystem admin methods                   *
      *                                                                *
      * FUNCTIONALITY:                                                 *
      *   - Admin statistics (patient, doctor, appointment counts)    *
      *   - Ward management (list, update occupancy)                  *
      *   - Staff management (list, add)                              *
      *   - Get all doctors list                                       *
      *   - Feedback management (get all, add)                        *
      *================================================================*
       IDENTIFICATION DIVISION.
       PROGRAM-ID. HMSADMIN.
       AUTHOR. HMS-TEAM.
       DATE-WRITTEN. 2026-10-13.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-Z16.
       OBJECT-COMPUTER. IBM-Z16.

       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT INPUT-FILE  ASSIGN TO SYSIN
               ORGANIZATION IS SEQUENTIAL.
           SELECT OUTPUT-FILE ASSIGN TO SYSOUT
               ORGANIZATION IS SEQUENTIAL.

       DATA DIVISION.
       FILE SECTION.
       FD  INPUT-FILE  RECORD CONTAINS 500 CHARACTERS.
       01  INPUT-RECORD  PIC X(500).
       FD  OUTPUT-FILE RECORD CONTAINS 8000 CHARACTERS.
       01  OUTPUT-RECORD PIC X(8000).

       WORKING-STORAGE SECTION.
           EXEC SQL INCLUDE SQLCA END-EXEC.

       01  WS-ACTION          PIC X(30) VALUE SPACES.
       01  WS-OUTPUT          PIC X(8000) VALUE SPACES.
       01  WS-JSON-ARRAY      PIC X(6000) VALUE SPACES.
       01  WS-FIRST-ROW       PIC X VALUE 'Y'.

      *--- STATS HOST VARIABLES ---
       01  HV-PAT-COUNT       PIC S9(9) COMP.
       01  HV-DOC-COUNT       PIC S9(9) COMP.
       01  HV-APPT-TODAY      PIC S9(9) COMP.
       01  HV-WARD-JSON       PIC X(1000) VALUE SPACES.

      *--- WARD HOST VARIABLES ---
       01  HV-WARD-ID         PIC S9(9) COMP.
       01  HV-WARD-TYPE       PIC X(50).
       01  HV-TOTAL-BEDS      PIC S9(4) COMP.
       01  HV-OCCPD-BEDS      PIC S9(4) COMP.

      *--- STAFF HOST VARIABLES ---
       01  HV-STAFF-ID        PIC S9(9) COMP.
       01  HV-STF-NAME        PIC X(255).
       01  HV-STF-ROLE        PIC X(100).
       01  HV-STF-CONTACT     PIC X(20).
       01  HV-STF-EMAIL       PIC X(255).
       01  HV-STF-DEPT        PIC X(100).
       01  HV-STF-STATUS      PIC X(10).

      *--- DOCTOR HOST VARIABLES ---
       01  HV-DOCTOR-ID       PIC S9(9) COMP.
       01  HV-DOC-NAME        PIC X(255).
       01  HV-SPECIALIZ       PIC X(100).
       01  HV-DEPARTMENT      PIC X(100).
       01  HV-DOC-CONTACT     PIC X(20).
       01  HV-DOC-EMAIL       PIC X(255).

      *--- FEEDBACK HOST VARIABLES ---
       01  HV-FDBK-ID         PIC S9(9) COMP.
       01  HV-PATIENT-ID      PIC S9(9) COMP.
       01  HV-FDBK-MSG        PIC X(2000).
       01  HV-FDBK-DATE       PIC X(10).
       01  HV-FDBK-STATUS     PIC X(10).
       01  HV-PAT-NAME        PIC X(255).

      *--- CURSORS ---
           EXEC SQL DECLARE WARD-CUR CURSOR FOR
               SELECT WARD_ID, WARD_TYPE, TOTAL_BEDS, OCCPD_BEDS
               FROM   HMS.WARDS
               ORDER BY WARD_ID
           END-EXEC.

           EXEC SQL DECLARE STAFF-CUR CURSOR FOR
               SELECT STAFF_ID, STF_NAME, STF_ROLE,
                      STF_CONTACT, STF_DEPT, STF_STATUS
               FROM   HMS.STAFF
               WHERE  STF_STATUS = 'ACTIVE'
               ORDER BY STF_ROLE, STF_NAME
           END-EXEC.

           EXEC SQL DECLARE DOC-CUR CURSOR FOR
               SELECT DOCTOR_ID, DOC_NAME, SPECIALIZ,
                      DEPARTMENT, DOC_CONTACT
               FROM   HMS.DOCTORS
               WHERE  DOC_STATUS = 'ACTIVE'
               ORDER BY SPECIALIZ, DOC_NAME
           END-EXEC.

           EXEC SQL DECLARE FDBK-CUR CURSOR FOR
               SELECT F.FDBK_ID, F.PATIENT_ID, F.FDBK_MESSAGE,
                      CHAR(F.FDBK_DATE), F.FDBK_STATUS,
                      P.PAT_NAME
               FROM   HMS.FEEDBACK F
               JOIN   HMS.PATIENTS P ON F.PATIENT_ID = P.PATIENT_ID
               ORDER BY F.CREATED_AT DESC
           END-EXEC.

       PROCEDURE DIVISION.
       MAIN-PARA.
           PERFORM READ-INPUT-PARA
           EVALUATE WS-ACTION
               WHEN 'ADMIN_STATS'
                   PERFORM GET-ADMIN-STATS-PARA
               WHEN 'DOCTORS'
                   PERFORM GET-DOCTORS-PARA
               WHEN 'STAFF'
                   PERFORM GET-STAFF-PARA
               WHEN 'ADD_STAFF'
                   PERFORM ADD-STAFF-PARA
               WHEN 'UPDATE_WARD'
                   PERFORM UPDATE-WARD-PARA
               WHEN 'FEEDBACK'
                   PERFORM GET-FEEDBACK-PARA
               WHEN 'ADD_FEEDBACK'
                   PERFORM ADD-FEEDBACK-PARA
               WHEN OTHER
                   MOVE '{"success":false,"error":"UNKNOWN ACTION"}'
                       TO WS-OUTPUT
           END-EVALUATE
           PERFORM WRITE-OUTPUT-PARA
           STOP RUN.

      *================================================================*
       READ-INPUT-PARA.
           OPEN INPUT INPUT-FILE
           READ INPUT-FILE INTO INPUT-RECORD AT END CONTINUE END-READ
           CLOSE INPUT-FILE
           MOVE FUNCTION UPPER-CASE(WS-ACTION) TO WS-ACTION.

      *================================================================*
       GET-ADMIN-STATS-PARA.
           EXEC SQL
               SELECT COUNT(*) INTO :HV-PAT-COUNT
               FROM   HMS.PATIENTS
           END-EXEC
           EXEC SQL
               SELECT COUNT(*) INTO :HV-DOC-COUNT
               FROM   HMS.DOCTORS
               WHERE  DOC_STATUS = 'ACTIVE'
           END-EXEC
           EXEC SQL
               SELECT COUNT(*) INTO :HV-APPT-TODAY
               FROM   HMS.APPOINTMENTS
               WHERE  APPT_DATE = CURRENT DATE
           END-EXEC
           MOVE '[' TO WS-WARD-JSON
           MOVE 'Y' TO WS-FIRST-ROW
           EXEC SQL OPEN WARD-CUR END-EXEC
           PERFORM UNTIL SQLCODE NOT = 0
               EXEC SQL
                   FETCH WARD-CUR
                   INTO :HV-WARD-ID, :HV-WARD-TYPE,
                        :HV-TOTAL-BEDS, :HV-OCCPD-BEDS
               END-EXEC
               IF SQLCODE = 0
                   IF WS-FIRST-ROW = 'N'
                       STRING FUNCTION TRIM(WS-WARD-JSON) ','
                              DELIMITED SIZE INTO WS-WARD-JSON
                   END-IF
                   MOVE 'N' TO WS-FIRST-ROW
                   STRING FUNCTION TRIM(WS-WARD-JSON)
                          '{"ward_id":' DELIMITED SIZE
                          HV-WARD-ID DELIMITED SIZE
                          ',"type":"' DELIMITED SIZE
                          FUNCTION TRIM(HV-WARD-TYPE) DELIMITED SIZE
                          '","total_beds":' DELIMITED SIZE
                          HV-TOTAL-BEDS DELIMITED SIZE
                          ',"occupied_beds":' DELIMITED SIZE
                          HV-OCCPD-BEDS DELIMITED SIZE
                          '}' DELIMITED SIZE
                       INTO WS-WARD-JSON
               END-IF
           END-PERFORM
           EXEC SQL CLOSE WARD-CUR END-EXEC
           STRING FUNCTION TRIM(WS-WARD-JSON) ']' DELIMITED SIZE
               INTO WS-WARD-JSON
           STRING '{"total_patients":' DELIMITED SIZE
                  HV-PAT-COUNT DELIMITED SIZE
                  ',"total_doctors":' DELIMITED SIZE
                  HV-DOC-COUNT DELIMITED SIZE
                  ',"today_appointments":' DELIMITED SIZE
                  HV-APPT-TODAY DELIMITED SIZE
                  ',"wards":' DELIMITED SIZE
                  FUNCTION TRIM(WS-WARD-JSON) DELIMITED SIZE
                  '}' DELIMITED SIZE
               INTO WS-OUTPUT.

       01  WS-WARD-JSON       PIC X(1000) VALUE SPACES.

      *================================================================*
       GET-DOCTORS-PARA.
           MOVE '[' TO WS-JSON-ARRAY
           MOVE 'Y' TO WS-FIRST-ROW
           EXEC SQL OPEN DOC-CUR END-EXEC
           PERFORM UNTIL SQLCODE NOT = 0
               EXEC SQL
                   FETCH DOC-CUR
                   INTO :HV-DOCTOR-ID, :HV-DOC-NAME, :HV-SPECIALIZ,
                        :HV-DEPARTMENT, :HV-DOC-CONTACT
               END-EXEC
               IF SQLCODE = 0
                   IF WS-FIRST-ROW = 'N'
                       STRING FUNCTION TRIM(WS-JSON-ARRAY) ','
                              DELIMITED SIZE INTO WS-JSON-ARRAY
                   END-IF
                   MOVE 'N' TO WS-FIRST-ROW
                   STRING FUNCTION TRIM(WS-JSON-ARRAY)
                          '{"id":' DELIMITED SIZE
                          HV-DOCTOR-ID DELIMITED SIZE
                          ',"name":"' DELIMITED SIZE
                          FUNCTION TRIM(HV-DOC-NAME) DELIMITED SIZE
                          '","specialization":"' DELIMITED SIZE
                          FUNCTION TRIM(HV-SPECIALIZ) DELIMITED SIZE
                          '","department":"' DELIMITED SIZE
                          FUNCTION TRIM(HV-DEPARTMENT) DELIMITED SIZE
                          '","contact":"' DELIMITED SIZE
                          FUNCTION TRIM(HV-DOC-CONTACT) DELIMITED SIZE
                          '"}' DELIMITED SIZE
                       INTO WS-JSON-ARRAY
               END-IF
           END-PERFORM
           EXEC SQL CLOSE DOC-CUR END-EXEC
           STRING FUNCTION TRIM(WS-JSON-ARRAY) ']' DELIMITED SIZE
               INTO WS-OUTPUT.

      *================================================================*
       GET-STAFF-PARA.
           MOVE '[' TO WS-JSON-ARRAY
           MOVE 'Y' TO WS-FIRST-ROW
           EXEC SQL OPEN STAFF-CUR END-EXEC
           PERFORM UNTIL SQLCODE NOT = 0
               EXEC SQL
                   FETCH STAFF-CUR
                   INTO :HV-STAFF-ID, :HV-STF-NAME, :HV-STF-ROLE,
                        :HV-STF-CONTACT, :HV-STF-DEPT, :HV-STF-STATUS
               END-EXEC
               IF SQLCODE = 0
                   IF WS-FIRST-ROW = 'N'
                       STRING FUNCTION TRIM(WS-JSON-ARRAY) ','
                              DELIMITED SIZE INTO WS-JSON-ARRAY
                   END-IF
                   MOVE 'N' TO WS-FIRST-ROW
                   STRING FUNCTION TRIM(WS-JSON-ARRAY)
                          '{"id":' DELIMITED SIZE
                          HV-STAFF-ID DELIMITED SIZE
                          ',"name":"' DELIMITED SIZE
                          FUNCTION TRIM(HV-STF-NAME) DELIMITED SIZE
                          '","role":"' DELIMITED SIZE
                          FUNCTION TRIM(HV-STF-ROLE) DELIMITED SIZE
                          '","contact":"' DELIMITED SIZE
                          FUNCTION TRIM(HV-STF-CONTACT) DELIMITED SIZE
                          '","department":"' DELIMITED SIZE
                          FUNCTION TRIM(HV-STF-DEPT) DELIMITED SIZE
                          '","status":"' DELIMITED SIZE
                          FUNCTION TRIM(HV-STF-STATUS) DELIMITED SIZE
                          '"}' DELIMITED SIZE
                       INTO WS-JSON-ARRAY
               END-IF
           END-PERFORM
           EXEC SQL CLOSE STAFF-CUR END-EXEC
           STRING FUNCTION TRIM(WS-JSON-ARRAY) ']' DELIMITED SIZE
               INTO WS-OUTPUT.

      *================================================================*
       ADD-STAFF-PARA.
           EXEC SQL
               INSERT INTO HMS.STAFF
                   (STF_NAME, STF_ROLE, STF_CONTACT, STF_DEPT)
               VALUES
                   (:HV-STF-NAME, :HV-STF-ROLE,
                    :HV-STF-CONTACT, :HV-STF-DEPT)
           END-EXEC
           IF SQLCODE = 0
               EXEC SQL
                   SELECT IDENTITY_VAL_LOCAL()
                   INTO :HV-STAFF-ID
                   FROM SYSIBM.SYSDUMMY1
               END-EXEC
               EXEC SQL COMMIT END-EXEC
               STRING '{"success":true,"staff_id":' DELIMITED SIZE
                      HV-STAFF-ID DELIMITED SIZE
                      '}' DELIMITED SIZE
                   INTO WS-OUTPUT
           ELSE
               EXEC SQL ROLLBACK END-EXEC
               MOVE '{"success":false,"error":"Add staff failed"}'
                   TO WS-OUTPUT
           END-IF.

      *================================================================*
       UPDATE-WARD-PARA.
           EXEC SQL
               UPDATE HMS.WARDS
               SET    OCCPD_BEDS = :HV-OCCPD-BEDS
               WHERE  WARD_ID    = :HV-WARD-ID
           END-EXEC
           IF SQLCODE = 0
               EXEC SQL COMMIT END-EXEC
               MOVE '{"success":true}' TO WS-OUTPUT
           ELSE
               EXEC SQL ROLLBACK END-EXEC
               MOVE '{"success":false}' TO WS-OUTPUT
           END-IF.

      *================================================================*
       GET-FEEDBACK-PARA.
           MOVE '[' TO WS-JSON-ARRAY
           MOVE 'Y' TO WS-FIRST-ROW
           EXEC SQL OPEN FDBK-CUR END-EXEC
           PERFORM UNTIL SQLCODE NOT = 0
               EXEC SQL
                   FETCH FDBK-CUR
                   INTO :HV-FDBK-ID, :HV-PATIENT-ID, :HV-FDBK-MSG,
                        :HV-FDBK-DATE, :HV-FDBK-STATUS, :HV-PAT-NAME
               END-EXEC
               IF SQLCODE = 0
                   IF WS-FIRST-ROW = 'N'
                       STRING FUNCTION TRIM(WS-JSON-ARRAY) ','
                              DELIMITED SIZE INTO WS-JSON-ARRAY
                   END-IF
                   MOVE 'N' TO WS-FIRST-ROW
                   STRING FUNCTION TRIM(WS-JSON-ARRAY)
                          '{"id":' DELIMITED SIZE
                          HV-FDBK-ID DELIMITED SIZE
                          ',"patient_name":"' DELIMITED SIZE
                          FUNCTION TRIM(HV-PAT-NAME) DELIMITED SIZE
                          '","message":"' DELIMITED SIZE
                          FUNCTION TRIM(HV-FDBK-MSG) DELIMITED SIZE
                          '","date":"' DELIMITED SIZE
                          FUNCTION TRIM(HV-FDBK-DATE) DELIMITED SIZE
                          '","status":"' DELIMITED SIZE
                          FUNCTION TRIM(HV-FDBK-STATUS) DELIMITED SIZE
                          '"}' DELIMITED SIZE
                       INTO WS-JSON-ARRAY
               END-IF
           END-PERFORM
           EXEC SQL CLOSE FDBK-CUR END-EXEC
           STRING FUNCTION TRIM(WS-JSON-ARRAY) ']' DELIMITED SIZE
               INTO WS-OUTPUT.

      *================================================================*
       ADD-FEEDBACK-PARA.
           EXEC SQL
               INSERT INTO HMS.FEEDBACK
                   (PATIENT_ID, FDBK_MESSAGE, FDBK_DATE)
               VALUES
                   (:HV-PATIENT-ID, :HV-FDBK-MSG, CURRENT DATE)
           END-EXEC
           IF SQLCODE = 0
               EXEC SQL
                   SELECT IDENTITY_VAL_LOCAL()
                   INTO :HV-FDBK-ID
                   FROM SYSIBM.SYSDUMMY1
               END-EXEC
               EXEC SQL COMMIT END-EXEC
               STRING '{"success":true,"feedback_id":' DELIMITED SIZE
                      HV-FDBK-ID DELIMITED SIZE
                      '}' DELIMITED SIZE
                   INTO WS-OUTPUT
           ELSE
               EXEC SQL ROLLBACK END-EXEC
               MOVE '{"success":false,"error":"Feedback failed"}'
                   TO WS-OUTPUT
           END-IF.

      *================================================================*
       WRITE-OUTPUT-PARA.
           OPEN OUTPUT OUTPUT-FILE
           MOVE WS-OUTPUT TO OUTPUT-RECORD
           WRITE OUTPUT-RECORD
           CLOSE OUTPUT-FILE.

       END PROGRAM HMSADMIN.
