      *================================================================*
      * PROGRAM:   HMSAUTH                                            *
      * PURPOSE:   Hospital Management System - Authentication Module  *
      * LANGUAGE:  COBOL with Embedded DB2 SQL (DB2 z/OS)            *
      * AUTHOR:    HMS Team | VIT University                          *
      * REPLACES:  C++ HospitalSystem::login() method                *
      *                                                                *
      * FUNCTIONALITY:                                                 *
      *   - Login validation for Patient, Doctor, and Admin roles     *
      *   - Patient registration                                       *
      *   - Returns JSON-formatted output for Node.js middleware       *
      *================================================================*
       IDENTIFICATION DIVISION.
       PROGRAM-ID. HMSAUTH.
       AUTHOR. HMS-TEAM.
       DATE-WRITTEN. 2026-10-13.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-Z16.
       OBJECT-COMPUTER. IBM-Z16.

       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT INPUT-FILE  ASSIGN TO SYSIN
               ORGANIZATION IS SEQUENTIAL
               ACCESS MODE  IS SEQUENTIAL.
           SELECT OUTPUT-FILE ASSIGN TO SYSOUT
               ORGANIZATION IS SEQUENTIAL
               ACCESS MODE  IS SEQUENTIAL.

       DATA DIVISION.
       FILE SECTION.
       FD  INPUT-FILE
           RECORDING MODE IS F
           BLOCK CONTAINS 0 RECORDS
           RECORD CONTAINS 500 CHARACTERS.
       01  INPUT-RECORD    PIC X(500).

       FD  OUTPUT-FILE
           RECORDING MODE IS F
           BLOCK CONTAINS 0 RECORDS
           RECORD CONTAINS 2000 CHARACTERS.
       01  OUTPUT-RECORD   PIC X(2000).

       WORKING-STORAGE SECTION.
      *-----------------------------------------------------------------
      * DB2 SQL COMMUNICATION AREA
      *-----------------------------------------------------------------
           EXEC SQL INCLUDE SQLCA END-EXEC.

      *-----------------------------------------------------------------
      * WORKING FIELDS
      *-----------------------------------------------------------------
       01  WS-PARM-ACTION     PIC X(20)  VALUE SPACES.
       01  WS-ROLE            PIC X(15)  VALUE SPACES.
       01  WS-EMAIL           PIC X(255) VALUE SPACES.
       01  WS-PASSWORD        PIC X(255) VALUE SPACES.
       01  WS-NAME            PIC X(255) VALUE SPACES.
       01  WS-AGE             PIC 9(3)   VALUE ZEROS.
       01  WS-GENDER          PIC X(10)  VALUE SPACES.
       01  WS-CONTACT         PIC X(20)  VALUE SPACES.

       01  WS-OUTPUT          PIC X(2000) VALUE SPACES.
       01  WS-RETURN-CODE     PIC S9(4)  VALUE ZEROS.

      *-----------------------------------------------------------------
      * HOST VARIABLES FOR DB2 - PATIENTS
      *-----------------------------------------------------------------
       01  HV-PATIENT-ID      PIC S9(9) COMP.
       01  HV-PAT-NAME        PIC X(255).
       01  HV-PAT-AGE         PIC S9(4) COMP.
       01  HV-PAT-GENDER      PIC X(10).
       01  HV-PAT-CONTACT     PIC X(20).
       01  HV-PAT-EMAIL       PIC X(255).
       01  HV-PAT-PASSWORD    PIC X(255).

      *-----------------------------------------------------------------
      * HOST VARIABLES FOR DB2 - DOCTORS
      *-----------------------------------------------------------------
       01  HV-DOCTOR-ID       PIC S9(9) COMP.
       01  HV-DOC-NAME        PIC X(255).
       01  HV-SPECIALIZ       PIC X(100).
       01  HV-DOC-EMAIL       PIC X(255).
       01  HV-DOC-PASSWORD    PIC X(255).
       01  HV-DEPARTMENT      PIC X(100).
       01  HV-DOC-CONTACT     PIC X(20).

      *-----------------------------------------------------------------
      * HOST VARIABLES FOR DB2 - ADMIN
      *-----------------------------------------------------------------
       01  HV-ADMIN-ID        PIC S9(9) COMP.
       01  HV-ADM-USERNAME    PIC X(100).
       01  HV-ADM-PASSWORD    PIC X(255).

      *-----------------------------------------------------------------
      * CONSTANTS
      *-----------------------------------------------------------------
       01  WS-TRUE            PIC X     VALUE 'T'.
       01  WS-FALSE           PIC X     VALUE 'F'.
       01  WS-FOUND           PIC X     VALUE WS-FALSE.

       PROCEDURE DIVISION.
      *================================================================*
       MAIN-PARA.
           PERFORM INITIALIZE-PARA
           PERFORM READ-INPUT-PARA
           EVALUATE WS-PARM-ACTION
               WHEN 'LOGIN'
                   PERFORM PROCESS-LOGIN-PARA
               WHEN 'REGISTER'
                   PERFORM PROCESS-REGISTER-PARA
               WHEN OTHER
                   MOVE '{"success":false,"error":"INVALID ACTION"}'
                       TO WS-OUTPUT
           END-EVALUATE
           PERFORM WRITE-OUTPUT-PARA
           STOP RUN.

      *================================================================*
       INITIALIZE-PARA.
           INITIALIZE WS-PARM-ACTION
                      WS-ROLE
                      WS-EMAIL
                      WS-PASSWORD
                      WS-NAME
                      WS-AGE
                      WS-GENDER
                      WS-CONTACT
                      WS-OUTPUT
                      HV-PATIENT-ID
                      HV-PAT-NAME
                      HV-PAT-EMAIL
                      HV-DOCTOR-ID
                      HV-DOC-NAME
                      HV-DOC-EMAIL
                      HV-ADMIN-ID
                      HV-ADM-USERNAME.

      *================================================================*
       READ-INPUT-PARA.
           OPEN INPUT INPUT-FILE
           READ INPUT-FILE INTO INPUT-RECORD
               AT END MOVE 'EOF' TO WS-PARM-ACTION
           END-READ
           CLOSE INPUT-FILE
      *    Simple JSON parsing - extract fields from SYSIN record
      *    In production: use CICS or JSON API (z/OS V2R3+)
           UNSTRING INPUT-RECORD DELIMITED BY '"action":"'
               INTO WS-OUTPUT
               DELIMITER IN WS-OUTPUT
               COUNT IN WS-RETURN-CODE
           END-UNSTRING
           UNSTRING INPUT-RECORD DELIMITED BY '"action":"'
                    DELIMITED BY '"'
               INTO WS-OUTPUT
               INTO WS-PARM-ACTION
           END-UNSTRING
           MOVE FUNCTION UPPER-CASE(WS-PARM-ACTION)
               TO WS-PARM-ACTION.

      *================================================================*
       PROCESS-LOGIN-PARA.
           EVALUATE WS-ROLE
               WHEN 'PATIENT'
                   PERFORM LOGIN-PATIENT-PARA
               WHEN 'DOCTOR'
                   PERFORM LOGIN-DOCTOR-PARA
               WHEN 'ADMIN'
                   PERFORM LOGIN-ADMIN-PARA
               WHEN OTHER
                   MOVE '{"success":false,"error":"INVALID ROLE"}'
                       TO WS-OUTPUT
           END-EVALUATE.

      *================================================================*
       LOGIN-PATIENT-PARA.
           EXEC SQL
               SELECT PATIENT_ID, PAT_NAME, PAT_EMAIL
               INTO   :HV-PATIENT-ID, :HV-PAT-NAME, :HV-PAT-EMAIL
               FROM   HMS.PATIENTS
               WHERE  PAT_EMAIL    = :HV-PAT-EMAIL
               AND    PAT_PASSWORD = :HV-PAT-PASSWORD
               FETCH FIRST 1 ROW ONLY
           END-EXEC

           IF SQLCODE = 0
               MOVE WS-TRUE TO WS-FOUND
               STRING '{"success":true,"role":"patient","user":{'
                          '"id":' DELIMITED SIZE
                          HV-PATIENT-ID DELIMITED SIZE
                          ',"name":"' DELIMITED SIZE
                          FUNCTION TRIM(HV-PAT-NAME) DELIMITED SIZE
                          '","email":"' DELIMITED SIZE
                          FUNCTION TRIM(HV-PAT-EMAIL) DELIMITED SIZE
                          '"}}' DELIMITED SIZE
                   INTO WS-OUTPUT
           ELSE
               MOVE '{"success":false,"error":"Invalid credentials"}'
                   TO WS-OUTPUT
           END-IF.

      *================================================================*
       LOGIN-DOCTOR-PARA.
           EXEC SQL
               SELECT DOCTOR_ID, DOC_NAME, DOC_EMAIL,
                      SPECIALIZ,  DEPARTMENT
               INTO   :HV-DOCTOR-ID, :HV-DOC-NAME, :HV-DOC-EMAIL,
                      :HV-SPECIALIZ, :HV-DEPARTMENT
               FROM   HMS.DOCTORS
               WHERE  DOC_EMAIL    = :HV-DOC-EMAIL
               AND    DOC_PASSWORD = :HV-DOC-PASSWORD
               AND    DOC_STATUS   = 'ACTIVE'
               FETCH FIRST 1 ROW ONLY
           END-EXEC

           IF SQLCODE = 0
               STRING '{"success":true,"role":"doctor","user":{'
                          '"id":' DELIMITED SIZE
                          HV-DOCTOR-ID DELIMITED SIZE
                          ',"name":"' DELIMITED SIZE
                          FUNCTION TRIM(HV-DOC-NAME) DELIMITED SIZE
                          '","email":"' DELIMITED SIZE
                          FUNCTION TRIM(HV-DOC-EMAIL) DELIMITED SIZE
                          '","specialization":"' DELIMITED SIZE
                          FUNCTION TRIM(HV-SPECIALIZ) DELIMITED SIZE
                          '","department":"' DELIMITED SIZE
                          FUNCTION TRIM(HV-DEPARTMENT) DELIMITED SIZE
                          '"}}' DELIMITED SIZE
                   INTO WS-OUTPUT
           ELSE
               MOVE '{"success":false,"error":"Invalid credentials"}'
                   TO WS-OUTPUT
           END-IF.

      *================================================================*
       LOGIN-ADMIN-PARA.
           EXEC SQL
               SELECT ADMIN_ID, ADM_USERNAME
               INTO   :HV-ADMIN-ID, :HV-ADM-USERNAME
               FROM   HMS.ADMIN
               WHERE  ADM_USERNAME = :HV-ADM-USERNAME
               AND    ADM_PASSWORD = :HV-ADM-PASSWORD
               FETCH FIRST 1 ROW ONLY
           END-EXEC

           IF SQLCODE = 0
               STRING '{"success":true,"role":"admin","user":{'
                          '"id":' DELIMITED SIZE
                          HV-ADMIN-ID DELIMITED SIZE
                          ',"username":"' DELIMITED SIZE
                          FUNCTION TRIM(HV-ADM-USERNAME) DELIMITED SIZE
                          '"}}' DELIMITED SIZE
                   INTO WS-OUTPUT
           ELSE
               MOVE '{"success":false,"error":"Invalid credentials"}'
                   TO WS-OUTPUT
           END-IF.

      *================================================================*
       PROCESS-REGISTER-PARA.
           EXEC SQL
               INSERT INTO HMS.PATIENTS
                   (PAT_NAME, PAT_AGE, PAT_GENDER,
                    PAT_CONTACT, PAT_EMAIL, PAT_PASSWORD)
               VALUES
                   (:HV-PAT-NAME, :HV-PAT-AGE, :HV-PAT-GENDER,
                    :HV-PAT-CONTACT, :HV-PAT-EMAIL, :HV-PAT-PASSWORD)
           END-EXEC

           IF SQLCODE = 0
               EXEC SQL
                   SELECT IDENTITY_VAL_LOCAL()
                   INTO :HV-PATIENT-ID
                   FROM SYSIBM.SYSDUMMY1
               END-EXEC
               STRING '{"success":true,"patient_id":'
                          DELIMITED SIZE
                          HV-PATIENT-ID DELIMITED SIZE
                          '}' DELIMITED SIZE
                   INTO WS-OUTPUT
               EXEC SQL COMMIT END-EXEC
           ELSE IF SQLCODE = -803
               MOVE '{"success":false,"error":"Email already registered"}'
                   TO WS-OUTPUT
               EXEC SQL ROLLBACK END-EXEC
           ELSE
               MOVE '{"success":false,"error":"Registration failed"}'
                   TO WS-OUTPUT
               EXEC SQL ROLLBACK END-EXEC
           END-IF.

      *================================================================*
       WRITE-OUTPUT-PARA.
           OPEN OUTPUT OUTPUT-FILE
           MOVE WS-OUTPUT TO OUTPUT-RECORD
           WRITE OUTPUT-RECORD
           CLOSE OUTPUT-FILE.

       END PROGRAM HMSAUTH.
