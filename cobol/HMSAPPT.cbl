      *================================================================*
      * PROGRAM:   HMSAPPT                                            *
      * PURPOSE:   Hospital Management System - Appointment Module     *
      * LANGUAGE:  COBOL with Embedded DB2 SQL (DB2 z/OS)            *
      * AUTHOR:    HMS Team | VIT University                          *
      * REPLACES:  C++ HospitalSystem appointment methods             *
      *                                                                *
      * FUNCTIONALITY:                                                 *
      *   - Book new appointments                                      *
      *   - Get patient appointments list                              *
      *   - Get doctor appointments list                               *
      *   - Update appointment status (COMPLETED / CANCELLED)         *
      *   - Get/Add prescriptions                                      *
      *   - Patient and Doctor dashboard statistics                    *
      *================================================================*
       IDENTIFICATION DIVISION.
       PROGRAM-ID. HMSAPPT.
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
       FD  OUTPUT-FILE RECORD CONTAINS 4000 CHARACTERS.
       01  OUTPUT-RECORD PIC X(4000).

       WORKING-STORAGE SECTION.
           EXEC SQL INCLUDE SQLCA END-EXEC.

       01  WS-ACTION          PIC X(30) VALUE SPACES.
       01  WS-OUTPUT          PIC X(4000) VALUE SPACES.
       01  WS-JSON-ARRAY      PIC X(3000) VALUE SPACES.
       01  WS-FIRST-ROW       PIC X VALUE 'Y'.

      *--- HOST VARIABLES: APPOINTMENTS ---
       01  HV-APPT-ID         PIC S9(9) COMP.
       01  HV-PATIENT-ID      PIC S9(9) COMP.
       01  HV-DOCTOR-ID       PIC S9(9) COMP.
       01  HV-APPT-DATE       PIC X(10).
       01  HV-APPT-TIME       PIC X(8).
       01  HV-APPT-STATUS     PIC X(15).
       01  HV-APPT-NOTES      PIC X(500).

      *--- HOST VARIABLES: PATIENTS ---
       01  HV-PAT-NAME        PIC X(255).
       01  HV-PAT-AGE         PIC S9(4) COMP.
       01  HV-PAT-CONTACT     PIC X(20).

      *--- HOST VARIABLES: DOCTORS ---
       01  HV-DOC-NAME        PIC X(255).
       01  HV-DOC-EMAIL       PIC X(255).
       01  HV-SPECIALIZ       PIC X(100).
       01  HV-DEPARTMENT      PIC X(100).
       01  HV-DOC-CONTACT     PIC X(20).

      *--- HOST VARIABLES: PRESCRIPTIONS ---
       01  HV-PRESC-ID        PIC S9(9) COMP.
       01  HV-APPT-REF-ID     PIC S9(9) COMP.
       01  HV-PAT-REF-ID      PIC S9(9) COMP.
       01  HV-DOC-REF-ID      PIC S9(9) COMP.
       01  HV-MEDICINE        PIC X(255).
       01  HV-DOSAGE          PIC X(100).
       01  HV-DURATION        PIC X(100).
       01  HV-DIAGNOSIS       PIC X(500).
       01  HV-PRESC-NOTES     PIC X(500).
       01  HV-PRESC-DATE      PIC X(26).

      *--- HOST VARIABLES: BILLING ---
       01  HV-BILL-AMOUNT     PIC S9(10)V99 COMP-3.
       01  HV-BILL-STATUS     PIC X(10).

      *--- HOST VARIABLES: STATS ---
       01  HV-COUNT           PIC S9(9) COMP.
       01  HV-SUM             PIC S9(10)V99 COMP-3.

      *--- CURSORS ---
           EXEC SQL DECLARE PAT-APPT-CUR CURSOR FOR
               SELECT A.APPT_ID, A.APPT_DATE, A.APPT_TIME,
                      A.APPT_STATUS, A.APPT_NOTES, A.PATIENT_ID,
                      D.DOC_NAME, D.SPECIALIZ
               FROM   HMS.APPOINTMENTS A
               JOIN   HMS.DOCTORS D ON A.DOCTOR_ID = D.DOCTOR_ID
               WHERE  A.PATIENT_ID = :HV-PATIENT-ID
               ORDER BY A.APPT_DATE DESC, A.APPT_TIME DESC
           END-EXEC.

           EXEC SQL DECLARE DOC-APPT-CUR CURSOR FOR
               SELECT A.APPT_ID, A.APPT_DATE, A.APPT_TIME,
                      A.APPT_STATUS, A.APPT_NOTES, A.PATIENT_ID,
                      P.PAT_NAME, P.PAT_AGE, P.PAT_CONTACT
               FROM   HMS.APPOINTMENTS A
               JOIN   HMS.PATIENTS P ON A.PATIENT_ID = P.PATIENT_ID
               WHERE  A.DOCTOR_ID = :HV-DOCTOR-ID
               ORDER BY A.APPT_DATE DESC, A.APPT_TIME DESC
           END-EXEC.

           EXEC SQL DECLARE PRESC-CUR CURSOR FOR
               SELECT PR.PRESC_ID, PR.MEDICINE, PR.DOSAGE,
                      PR.DURATION, PR.DIAGNOSIS, PR.PRESC_NOTES,
                      CHAR(PR.CREATED_AT),
                      D.DOC_NAME, A.APPT_DATE, A.APPT_TIME
               FROM   HMS.PRESCRIPTIONS PR
               JOIN   HMS.DOCTORS D ON PR.DOCTOR_ID = D.DOCTOR_ID
               JOIN   HMS.APPOINTMENTS A ON PR.APPT_ID = A.APPT_ID
               WHERE  PR.PATIENT_ID = :HV-PAT-REF-ID
               ORDER BY PR.CREATED_AT DESC
           END-EXEC.

       PROCEDURE DIVISION.
       MAIN-PARA.
           PERFORM READ-INPUT-PARA
           EVALUATE WS-ACTION
               WHEN 'BOOK_APPOINTMENT'
                   PERFORM BOOK-APPT-PARA
               WHEN 'PATIENT_APPOINTMENTS'
                   PERFORM GET-PAT-APPTS-PARA
               WHEN 'DOCTOR_APPOINTMENTS'
                   PERFORM GET-DOC-APPTS-PARA
               WHEN 'UPDATE_APPOINTMENT'
                   PERFORM UPDATE-APPT-PARA
               WHEN 'ADD_PRESCRIPTION'
                   PERFORM ADD-PRESC-PARA
               WHEN 'PATIENT_PRESCRIPTIONS'
                   PERFORM GET-PRESC-PARA
               WHEN 'PATIENT_DASHBOARD'
                   PERFORM GET-PAT-DASH-PARA
               WHEN 'DOCTOR_PROFILE'
                   PERFORM GET-DOC-PROFILE-PARA
               WHEN OTHER
                   MOVE '{"success":false,"error":"UNKNOWN ACTION"}'
                       TO WS-OUTPUT
           END-EVALUATE
           PERFORM WRITE-OUTPUT-PARA
           STOP RUN.

      *================================================================*
       READ-INPUT-PARA.
           OPEN INPUT INPUT-FILE
           READ INPUT-FILE INTO INPUT-RECORD
               AT END CONTINUE
           END-READ
           CLOSE INPUT-FILE
           MOVE FUNCTION UPPER-CASE(WS-ACTION) TO WS-ACTION.

      *================================================================*
       BOOK-APPT-PARA.
           EXEC SQL
               INSERT INTO HMS.APPOINTMENTS
                   (PATIENT_ID, DOCTOR_ID, APPT_DATE, APPT_TIME, APPT_STATUS)
               VALUES
                   (:HV-PATIENT-ID, :HV-DOCTOR-ID,
                    :HV-APPT-DATE, :HV-APPT-TIME, 'SCHEDULED')
           END-EXEC
           IF SQLCODE = 0
               EXEC SQL
                   SELECT IDENTITY_VAL_LOCAL()
                   INTO :HV-APPT-ID
                   FROM SYSIBM.SYSDUMMY1
               END-EXEC
               EXEC SQL COMMIT END-EXEC
               STRING '{"success":true,"appointment_id":'
                          DELIMITED SIZE
                          HV-APPT-ID DELIMITED SIZE
                          '}' DELIMITED SIZE
                   INTO WS-OUTPUT
           ELSE
               EXEC SQL ROLLBACK END-EXEC
               MOVE '{"success":false,"error":"Booking failed"}'
                   TO WS-OUTPUT
           END-IF.

      *================================================================*
       GET-PAT-APPTS-PARA.
           MOVE '[' TO WS-JSON-ARRAY
           MOVE 'Y' TO WS-FIRST-ROW
           EXEC SQL OPEN PAT-APPT-CUR END-EXEC
           PERFORM UNTIL SQLCODE NOT = 0
               EXEC SQL
                   FETCH PAT-APPT-CUR
                   INTO :HV-APPT-ID, :HV-APPT-DATE, :HV-APPT-TIME,
                        :HV-APPT-STATUS, :HV-APPT-NOTES, :HV-PATIENT-ID,
                        :HV-DOC-NAME, :HV-SPECIALIZ
               END-EXEC
               IF SQLCODE = 0
                   IF WS-FIRST-ROW = 'N'
                       STRING FUNCTION TRIM(WS-JSON-ARRAY)
                              ',' DELIMITED SIZE
                           INTO WS-JSON-ARRAY
                   END-IF
                   MOVE 'N' TO WS-FIRST-ROW
                   STRING FUNCTION TRIM(WS-JSON-ARRAY)
                          '{"id":' DELIMITED SIZE
                          HV-APPT-ID DELIMITED SIZE
                          ',"date":"' DELIMITED SIZE
                          FUNCTION TRIM(HV-APPT-DATE) DELIMITED SIZE
                          '","time":"' DELIMITED SIZE
                          FUNCTION TRIM(HV-APPT-TIME) DELIMITED SIZE
                          '","status":"' DELIMITED SIZE
                          FUNCTION TRIM(HV-APPT-STATUS) DELIMITED SIZE
                          '","doctor_name":"' DELIMITED SIZE
                          FUNCTION TRIM(HV-DOC-NAME) DELIMITED SIZE
                          '","specialization":"' DELIMITED SIZE
                          FUNCTION TRIM(HV-SPECIALIZ) DELIMITED SIZE
                          '","notes":"' DELIMITED SIZE
                          FUNCTION TRIM(HV-APPT-NOTES) DELIMITED SIZE
                          '"}' DELIMITED SIZE
                       INTO WS-JSON-ARRAY
               END-IF
           END-PERFORM
           EXEC SQL CLOSE PAT-APPT-CUR END-EXEC
           STRING FUNCTION TRIM(WS-JSON-ARRAY) ']' DELIMITED SIZE
               INTO WS-OUTPUT.

      *================================================================*
       GET-DOC-APPTS-PARA.
           MOVE '[' TO WS-JSON-ARRAY
           MOVE 'Y' TO WS-FIRST-ROW
           EXEC SQL OPEN DOC-APPT-CUR END-EXEC
           PERFORM UNTIL SQLCODE NOT = 0
               EXEC SQL
                   FETCH DOC-APPT-CUR
                   INTO :HV-APPT-ID, :HV-APPT-DATE, :HV-APPT-TIME,
                        :HV-APPT-STATUS, :HV-APPT-NOTES, :HV-PATIENT-ID,
                        :HV-PAT-NAME, :HV-PAT-AGE, :HV-PAT-CONTACT
               END-EXEC
               IF SQLCODE = 0
                   IF WS-FIRST-ROW = 'N'
                       STRING FUNCTION TRIM(WS-JSON-ARRAY) ','
                              DELIMITED SIZE INTO WS-JSON-ARRAY
                   END-IF
                   MOVE 'N' TO WS-FIRST-ROW
                   STRING FUNCTION TRIM(WS-JSON-ARRAY)
                          '{"id":' DELIMITED SIZE
                          HV-APPT-ID DELIMITED SIZE
                          ',"patient_name":"' DELIMITED SIZE
                          FUNCTION TRIM(HV-PAT-NAME) DELIMITED SIZE
                          '","date":"' DELIMITED SIZE
                          FUNCTION TRIM(HV-APPT-DATE) DELIMITED SIZE
                          '","time":"' DELIMITED SIZE
                          FUNCTION TRIM(HV-APPT-TIME) DELIMITED SIZE
                          '","status":"' DELIMITED SIZE
                          FUNCTION TRIM(HV-APPT-STATUS) DELIMITED SIZE
                          '","patient_id":' DELIMITED SIZE
                          HV-PATIENT-ID DELIMITED SIZE
                          ',"contact":"' DELIMITED SIZE
                          FUNCTION TRIM(HV-PAT-CONTACT) DELIMITED SIZE
                          '","notes":"' DELIMITED SIZE
                          FUNCTION TRIM(HV-APPT-NOTES) DELIMITED SIZE
                          '"}' DELIMITED SIZE
                       INTO WS-JSON-ARRAY
               END-IF
           END-PERFORM
           EXEC SQL CLOSE DOC-APPT-CUR END-EXEC
           STRING FUNCTION TRIM(WS-JSON-ARRAY) ']' DELIMITED SIZE
               INTO WS-OUTPUT.

      *================================================================*
       UPDATE-APPT-PARA.
           EXEC SQL
               UPDATE HMS.APPOINTMENTS
               SET    APPT_STATUS = :HV-APPT-STATUS,
                      APPT_NOTES  = :HV-APPT-NOTES
               WHERE  APPT_ID = :HV-APPT-ID
           END-EXEC
           IF SQLCODE = 0
               EXEC SQL COMMIT END-EXEC
               MOVE '{"success":true}' TO WS-OUTPUT
           ELSE
               EXEC SQL ROLLBACK END-EXEC
               MOVE '{"success":false}' TO WS-OUTPUT
           END-IF.

      *================================================================*
       ADD-PRESC-PARA.
           EXEC SQL
               INSERT INTO HMS.PRESCRIPTIONS
                   (APPT_ID, PATIENT_ID, DOCTOR_ID,
                    MEDICINE, DOSAGE, DURATION, DIAGNOSIS, PRESC_NOTES)
               VALUES
                   (:HV-APPT-REF-ID, :HV-PAT-REF-ID, :HV-DOC-REF-ID,
                    :HV-MEDICINE, :HV-DOSAGE, :HV-DURATION,
                    :HV-DIAGNOSIS, :HV-PRESC-NOTES)
           END-EXEC
           IF SQLCODE = 0
               EXEC SQL
                   SELECT IDENTITY_VAL_LOCAL()
                   INTO :HV-PRESC-ID
                   FROM SYSIBM.SYSDUMMY1
               END-EXEC
               EXEC SQL COMMIT END-EXEC
               STRING '{"success":true,"prescription_id":'
                          DELIMITED SIZE
                          HV-PRESC-ID DELIMITED SIZE
                          '}' DELIMITED SIZE
                   INTO WS-OUTPUT
           ELSE
               EXEC SQL ROLLBACK END-EXEC
               MOVE '{"success":false,"error":"Prescription failed"}'
                   TO WS-OUTPUT
           END-IF.

      *================================================================*
       GET-PRESC-PARA.
           MOVE '[' TO WS-JSON-ARRAY
           MOVE 'Y' TO WS-FIRST-ROW
           EXEC SQL OPEN PRESC-CUR END-EXEC
           PERFORM UNTIL SQLCODE NOT = 0
               EXEC SQL
                   FETCH PRESC-CUR
                   INTO :HV-PRESC-ID, :HV-MEDICINE, :HV-DOSAGE,
                        :HV-DURATION, :HV-DIAGNOSIS, :HV-PRESC-NOTES,
                        :HV-PRESC-DATE, :HV-DOC-NAME,
                        :HV-APPT-DATE, :HV-APPT-TIME
               END-EXEC
               IF SQLCODE = 0
                   IF WS-FIRST-ROW = 'N'
                       STRING FUNCTION TRIM(WS-JSON-ARRAY) ','
                              DELIMITED SIZE INTO WS-JSON-ARRAY
                   END-IF
                   MOVE 'N' TO WS-FIRST-ROW
                   STRING FUNCTION TRIM(WS-JSON-ARRAY)
                          '{"id":' DELIMITED SIZE
                          HV-PRESC-ID DELIMITED SIZE
                          ',"doctor_name":"' DELIMITED SIZE
                          FUNCTION TRIM(HV-DOC-NAME) DELIMITED SIZE
                          '","date":"' DELIMITED SIZE
                          FUNCTION TRIM(HV-APPT-DATE) DELIMITED SIZE
                          '","time":"' DELIMITED SIZE
                          FUNCTION TRIM(HV-APPT-TIME) DELIMITED SIZE
                          '","medicine":"' DELIMITED SIZE
                          FUNCTION TRIM(HV-MEDICINE) DELIMITED SIZE
                          '","dosage":"' DELIMITED SIZE
                          FUNCTION TRIM(HV-DOSAGE) DELIMITED SIZE
                          '","duration":"' DELIMITED SIZE
                          FUNCTION TRIM(HV-DURATION) DELIMITED SIZE
                          '","diagnosis":"' DELIMITED SIZE
                          FUNCTION TRIM(HV-DIAGNOSIS) DELIMITED SIZE
                          '","notes":"' DELIMITED SIZE
                          FUNCTION TRIM(HV-PRESC-NOTES) DELIMITED SIZE
                          '"}' DELIMITED SIZE
                       INTO WS-JSON-ARRAY
               END-IF
           END-PERFORM
           EXEC SQL CLOSE PRESC-CUR END-EXEC
           STRING FUNCTION TRIM(WS-JSON-ARRAY) ']' DELIMITED SIZE
               INTO WS-OUTPUT.

      *================================================================*
       GET-PAT-DASH-PARA.
           EXEC SQL
               SELECT COUNT(*) INTO :HV-COUNT
               FROM   HMS.APPOINTMENTS
               WHERE  PATIENT_ID = :HV-PATIENT-ID
           END-EXEC
           MOVE HV-COUNT TO HV-PAT-AGE
           EXEC SQL
               SELECT COUNT(*) INTO :HV-COUNT
               FROM   HMS.PRESCRIPTIONS
               WHERE  PATIENT_ID = :HV-PATIENT-ID
           END-EXEC
           STRING '{"total_appointments":' DELIMITED SIZE
                  HV-PAT-AGE DELIMITED SIZE
                  ',"total_prescriptions":' DELIMITED SIZE
                  HV-COUNT DELIMITED SIZE
                  ',"pending_bills":"0"}' DELIMITED SIZE
               INTO WS-OUTPUT.

      *================================================================*
       GET-DOC-PROFILE-PARA.
           EXEC SQL
               SELECT DOCTOR_ID, DOC_NAME, SPECIALIZ,
                      DEPARTMENT, DOC_CONTACT, DOC_EMAIL
               INTO  :HV-DOCTOR-ID, :HV-DOC-NAME, :HV-SPECIALIZ,
                     :HV-DEPARTMENT, :HV-DOC-CONTACT, :HV-DOC-EMAIL
               FROM  HMS.DOCTORS
               WHERE  DOCTOR_ID = :HV-DOCTOR-ID
           END-EXEC
           IF SQLCODE = 0
               STRING '{"id":' DELIMITED SIZE
                      HV-DOCTOR-ID DELIMITED SIZE
                      ',"name":"' DELIMITED SIZE
                      FUNCTION TRIM(HV-DOC-NAME) DELIMITED SIZE
                      '","specialization":"' DELIMITED SIZE
                      FUNCTION TRIM(HV-SPECIALIZ) DELIMITED SIZE
                      '","department":"' DELIMITED SIZE
                      FUNCTION TRIM(HV-DEPARTMENT) DELIMITED SIZE
                      '","contact":"' DELIMITED SIZE
                      FUNCTION TRIM(HV-DOC-CONTACT) DELIMITED SIZE
                      '","email":"' DELIMITED SIZE
                      FUNCTION TRIM(HV-DOC-EMAIL) DELIMITED SIZE
                      '"}' DELIMITED SIZE
                   INTO WS-OUTPUT
           ELSE
               MOVE '{}' TO WS-OUTPUT
           END-IF.

      *================================================================*
       WRITE-OUTPUT-PARA.
           OPEN OUTPUT OUTPUT-FILE
           MOVE WS-OUTPUT TO OUTPUT-RECORD
           WRITE OUTPUT-RECORD
           CLOSE OUTPUT-FILE.

       END PROGRAM HMSAPPT.
