//ZWECSVPX JOB
//*
//* This program and the accompanying materials are made available
//* under the terms of the Eclipse Public License v2.0 which
//* accompanies this distribution, and is available at
//* https://www.eclipse.org/legal/epl-v20.html
//*
//* SPDX-License-Identifier: EPL-2.0
//*
//* Copyright Contributors to the Zowe Project. 2020, 2020
//*
//*********************************************************************
//*
//* Zowe Open Source Project
//* This JCL can be used to create VSAM data set for Caching Service.
//*
//* NOTE: The data set is suitable for Parallel Sysplex and you
//*       have Storage Class defined.
//*
//* CAUTION: This is neither a JCL procedure nor a complete job.
//* Before using this JCL, you will have to make the following
//* modifications:
//*
//* 1) Add job name and job parameters to the JOB statement, to
//*    meet your system requirements.
//*
//* 2) Update the SET statement to match your environment.
//*
//*********************************************************************
//*      * Name of the data set
//         SET   DSNAME=
//*      * Storage class of the data set
//         SET   STORCLAS=
//*      * Recoverable log of the data set
//         SET   RECLOG=NONE
//********************************************************************
//S1    EXEC PGM=IDCAMS,REGION=0M
//SYSPRINT DD SYSOUT=*
//SYSIN   DD *
  DEFINE CLUSTER -
   (NAME(&DSNAME.) -
   STORCLAS(&STORCLAS.) -
   LOG(&RECLOG.) -
   REC(80 20) -
   INDEXED) -
   DATA(NAME(&DSNAME..DATA) -
    RECSZ(80 4096) -
    UNIQUE -
    KEYS(128 0)) -
   INDEX(NAME(&DSNAME..INDEX) -
    UNIQUE)
/*
