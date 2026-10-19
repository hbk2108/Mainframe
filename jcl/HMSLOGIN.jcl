//HMSLOGIN JOB (ACCT001),'HMS LOGIN PROC',
//         CLASS=A,MSGCLASS=X,MSGLEVEL=(1,1),
//         NOTIFY=&SYSUID,REGION=4M
//*
//* ============================================================
//* JCL JOB: HMSLOGIN
//* PURPOSE: Authenticate user (Patient / Doctor / Admin)
//* INPUT:   SYSIN - JSON params (email, password, role)
//* OUTPUT:  SYSOUT - JSON result
//* PROGRAM: HMSAUTH  (COBOL/DB2 program)
//* ============================================================
//*
//JOBLIB   DD  DSN=HMS.LOADLIB,DISP=SHR
//*
//STEP010  EXEC PGM=HMSAUTH,
//         PARM='LOGIN'
//STEPLIB  DD  DSN=HMS.LOADLIB,DISP=SHR
//SYSOUT   DD  SYSOUT=*
//SYSPRINT DD  SYSOUT=*
//SYSTSPRT DD  SYSOUT=*
//SYSABEND DD  SYSOUT=*
//DB2PLAN  DD  DSN=HMS.DBRM(HMSAUTH),DISP=SHR
//PARMFILE DD  DSN=&&LOGINPRM,DISP=(NEW,PASS),
//             UNIT=VIO,SPACE=(TRK,(1,1))
//OUTFILE  DD  DSN=&&LOGINOUT,DISP=(NEW,PASS),
//             UNIT=VIO,SPACE=(TRK,(1,1))
//SYSIN    DD  *
{"action":"LOGIN","role":"PATIENT"}
/*
//*
//STEP020  EXEC PGM=IDCAMS
//SYSPRINT DD  SYSOUT=*
//SYSIN    DD  *
  PRINT INFILE(&&LOGINOUT) CHARACTER
/*
//
