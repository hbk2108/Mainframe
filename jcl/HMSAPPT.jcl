//HMSAPPT JOB (ACCT001),'HMS APPT REPORT',
//         CLASS=A,MSGCLASS=X,MSGLEVEL=(1,1),
//         NOTIFY=&SYSUID,REGION=4M
//*
//* ============================================================
//* JCL JOB: HMSAPPT
//* PURPOSE: Hospital Management System - Appointment Processing
//*          Generates scheduled / upcoming appointment lists
//*          per doctor and per ward for operational planning
//* SCHEDULE: On-demand or daily via JES2
//* INPUT:   SYSIN - Date range parameter
//* OUTPUT:  RPTOUT - Formatted report
//* PROGRAM: HMSAPPT  (COBOL/DB2 program)
//* ============================================================
//*
//JOBLIB   DD  DSN=HMS.LOADLIB,DISP=SHR
//*
//* ---------------------------------------------------------
//* STEP 1: Generate Daily Appointment Schedule Report
//* ---------------------------------------------------------
//STEP010  EXEC PGM=IKJEFT01,DYNAMNBR=20
//STEPLIB  DD  DSN=SYS1.DSNLOAD,DISP=SHR
//SYSTSPRT DD  SYSOUT=*
//SYSPRINT DD  SYSOUT=*
//SYSUDUMP DD  SYSOUT=*
//SYSTSIN  DD  *
  DSN SYSTEM(DB2PROD)
  RUN PROGRAM(HMSAPPT) PLAN(HMSPLAN) PARMS('DOCTOR_APPOINTMENTS') -
      LIB(HMS.LOADLIB)
  END
/*
//SYSIN    DD  *
{"action":"DOCTOR_APPOINTMENTS","DOCTOR_ID":"ALL","DATE":"TODAY"}
/*
//*
//* ---------------------------------------------------------
//* STEP 2: Sort appointment report by Doctor / Time
//* ---------------------------------------------------------
//STEP020  EXEC PGM=SORT,
//         COND=(4,LT,STEP010)
//STEPLIB  DD  DSN=SYS1.SORTLIB,DISP=SHR
//SYSOUT   DD  SYSOUT=*
//SORTIN   DD  DSN=&&APPTWORK,DISP=(OLD,DELETE)
//SORTOUT  DD  DSN=HMS.RPT.APPTSCHEDULE.D&DATE,
//             DISP=(NEW,CATLG,DELETE),
//             UNIT=SYSDA,
//             SPACE=(CYL,(2,1),RLSE),
//             DCB=(RECFM=FB,LRECL=133,BLKSIZE=13300)
//SYSIN    DD  *
  SORT FIELDS=(5,10,CH,A,16,8,CH,A),FORMAT=CH
  RECORD TYPE=F,LENGTH=(133)
/*
//*
//* ---------------------------------------------------------
//* STEP 3: Print report via JES2
//* ---------------------------------------------------------
//STEP030  EXEC PGM=IEBGENER,
//         COND=(4,LT,STEP020)
//SYSPRINT DD  SYSOUT=*
//SYSUT1   DD  DSN=HMS.RPT.APPTSCHEDULE.D&DATE,DISP=SHR
//SYSUT2   DD  SYSOUT=(*,,,RPTQ)
//SYSIN    DD  DUMMY
//*
//* ---------------------------------------------------------
//* STEP 4: Archive previous day appointment reports (30-day)
//* ---------------------------------------------------------
//STEP040  EXEC PGM=IDCAMS,
//         COND=(4,LT,STEP030)
//SYSPRINT DD  SYSOUT=*
//SYSIN    DD  *
  DELETE HMS.RPT.APPTSCHEDULE.D&PREVDATE PURGE
  IF LASTCC = 8 THEN SET MAXCC = 0
/*
//
