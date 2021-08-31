*Bruce Decker Final SAS 224 Project;
options validvarname=v7;
/* this creates an empty library to save all the data to */
libname project base "/home/u55486647/Assignments first term/Final Project";

DATA project.final;
	infile "/home/u55486647/Second Term/Final Project/*.txt" dlm="@";
	length ID $5. Date $3. Course $10.;
	input ID $ Date $ Course $ Credit Grade $;
	*We need grade to be a number grade in order to calculate GPA;
	IF Grade = "A" THEN GPAgrade = 4.0;
	ELSE IF Grade = "A-" THEN GPAgrade = 3.7;
	ELSE IF Grade = "B+" THEN GPAgrade = 3.5;
	ELSE IF Grade = "B" THEN GPAgrade = 3.0;
	ELSE IF Grade = "B-" THEN GPAgrade = 2.7;
	ELSE IF Grade = "C+" THEN GPAgrade = 2.5;
	ELSE IF Grade = "C" THEN GPAgrade = 2.0;
	ELSE IF Grade = "C-" THEN GPAgrade = 1.7;
	ELSE IF Grade = "D+" THEN GPAgrade = 1.5;
	ELSE IF Grade = "D" THEN GPAgrade = 1.0;
	ELSE IF Grade = "D-" THEN GPAgrade = 0.7;
	ELSE GPAgrade = 0;
	Year = substr(Date, 2, 2);
	Semester = substr(Date,1,1);
run;

/* this macro will be used to sort the data and tables I create */
%MACRO clean(x= );

PROC SORT data=&x;
	by ID Year Semester;
run;

%MEND clean;

%clean(x=project.final);


/* Now lets try to make this into a macro program to do the first 2 reports report (previous code was moved to another sas file in case this didn't work) */
%MACRO reports (table=, num=);
		
		/* Calculate GPA for each semester */
	PROC SQL;
		Create table project.&num.SemesterGPA as
		select DISTINCT ID, Date, Year, Semester, round(sum(GPAgrade*Credit)/sum(Credit), .01) as SemGPA
		from &table
		where Grade not in ("P", "W", "T", "I")
		group by ID, Date
		;
	quit;
	
	%clean(x=project.&num.SemesterGPA);
		
	/* Calculate Accumulating GPA */
	/* First lets get some information together I can manipulate in a data step */
	PROC SQL;
		Create table project.&num.pointscredits as
		select DISTINCT ID, Date, Year, Semester, sum(credit) as credits, round(sum(GPAgrade*credit)) as points
		from &table
		where Grade not in ("P", "W", "T", "I")
		group by ID, Date
		;
	quit;
	
	%clean(x=project.&num.pointscredits);
	
	/* Now lets manipulate this data and use an accumulated variable */
	DATA project.&num.accugpa;
		set project.&num.pointscredits;
		By ID;
		Retain tcredits 0 tpoints 0;
		IF first.ID then tpoints = 0;
		tpoints= tpoints + points;
		IF first.ID then tcredits = 0;
		tcredits = tcredits + credits;
		CumGPA = round(tpoints/tcredits, .01);
	run;
	
	%clean(x=project.&num.accugpa);
	
	/* Lets find credit hours earned */
	PROC SQL;
		Create table project.&num.earnedhours as
		Select DISTINCT ID, Date, Year, Semester, sum(credit) as ehours
		from &table
		where Grade not in ("W", "UW", "E", "IE", "I", "WE", "T")
		Group by ID, Date
		;
	quit;
	
	%clean(x=project.&num.earnedhours);
	
	/* Lets find graded hours */
	PROC SQL;
		Create table project.&num.gradedhours as
		Select DISTINCT ID, Date, Year, Semester, sum(credit) as ghours
		from &table
		where Grade in ("A", "A-", "B+", "B", "B-", "C+", "C", "C-", "D+", "D", "D-")
		Group by ID, Date
		;
	quit;
	
	%clean(x=project.&num.gradedhours);
	
	/* Discover Class standing */
	DATA project.&num.standing;
		set project.&num.earnedhours;
		by ID;
		Retain tcredits 0 xcredits 0;
		if first.ID then tcredits=0;
		tcredits= tcredits + ehours;
		IF first.ID then xcredits=0;
		xcredits= tcredits-ehours;
		IF xcredits <= 29.9 then standing = "FRESHMAN";
		ELSE IF xcredits >= 30 and xcredits <= 59.9 then standing = "SOPHOMORE";
		ELSE IF xcredits >= 60 and xcredits <= 89.9 then standing = "JUNIOR";
		ELSE standing = "SENIOR";
	run;
	
	%clean(x=project.&num.standing);
	
	/* Calculate student's overall GPA, I think this means their final accumulated GPA */
	DATA project.&num.overallgpa;
		set project.&num.accugpa;
		By ID;
		if last.ID then GPA = CumGPA;
		ELSE GPA = 0;
	run;
	
	PROC SQL;
		Create table project.&num.overallgpaclean as
		Select ID, Date, Year, Semester, GPA
		from project.&num.overallgpa
		where GPA > 0
		;
	quit;
	
	/* Calculate Overall credit hours earned */
	DATA project.&num.overallhours;
		set project.&num.earnedhours;
		By ID;
		Retain tehours 0;
		IF first.ID then tehours = 0;
		tehours = tehours + ehours;
		if last.ID then Hours = tehours;
		ELSE Hours = 0;
	run;
	
	PROC SQL;
		Create table project.&num.overallhoursclean as
		Select ID, Date, Year, Semester, Hours
		from project.&num.overallhours
		where Hours > 0
		;
	quit;
	
	%clean(x=project.&num.overallhoursclean);
	
	/* Calculate overall graded hours earned */
	DATA project.&num.overallghours;
		set project.&num.gradedhours;
		by ID;
		Retain tghours 0;
		IF first.ID then tghours = 0;
		tghours = tghours + ghours;
		if last.ID then GradedHours = tghours;
		ELSE GradedHours = 0;
	run;
	
	PROC SQL;
		Create table project.&num.overallghoursclean as
		Select ID, Date, Year, Semester, GradedHours
		from project.&num.overallghours
		where GradedHours > 0
		;
	quit;
	
	%clean(x=project.&num.overallghoursclean);
	
	/* Calculate number of repeat classes for each student */
	PROC SQL;
		Create Table project.&num.rcourses AS
		Select ID, Course, Count(Course)-1 as Repeats
		From &table
		Where Course not like '%R'
		Group BY ID, Course
		Having Count(Course)>1
		;
	quit;
	/* subtracting 1 from the count(course) above puts the number of times a course is repeated as the correct value, as it does not include the original time the class was taken.  */
	PROC SQL;
		Create Table project.&num.totrcourses AS
		Select ID, sum(Repeats) as TotalRepeats
		From project.&num.rcourses
		GROUP BY ID
		;
	quit;
	/* Calculate number of letter grades for each student */
	PROC SQL;
		Create Table project.&num.Agrades AS
		Select ID, Grade, Count(Grade) as A
		From &table
		Where Grade = "A"
		Group BY ID, Grade
		Having Count(Grade)
		;
	quit;
	
	PROC SQL;
		Create Table project.&num.Amingrades AS
		Select ID, Grade, Count(Grade) as Amin
		From &table
		Where Grade = "A-"
		Group BY ID, Grade
		Having Count(Grade)
		;
	quit;
	PROC SQL;
		Create Table project.&num.Bpgrades AS
		Select ID, Grade, Count(Grade) as Bp
		From &table
		Where Grade = "B+"
		Group BY ID, Grade
		Having Count(Grade)
		;
	quit;
	PROC SQL;
		Create Table project.&num.Bgrades AS
		Select ID, Grade, Count(Grade) as B
		From &table
		Where Grade = "B"
		Group BY ID, Grade
		Having Count(Grade)
		;
	quit;	
	PROC SQL;
		Create Table project.&num.Bmingrades AS
		Select ID, Grade, Count(Grade) as Bmin
		From &table
		Where Grade = "B-"
		Group BY ID, Grade
		Having Count(Grade)
		;
	quit;	
	PROC SQL;
		Create Table project.&num.Cpgrades AS
		Select ID, Grade, Count(Grade) as Cp
		From &table
		Where Grade = "C+"
		Group BY ID, Grade
		Having Count(Grade)
		;
	quit;	
	PROC SQL;
		Create Table project.&num.Cgrades AS
		Select ID, Grade, Count(Grade) as C
		From &table
		Where Grade = "C"
		Group BY ID, Grade
		Having Count(Grade)
		;
	quit;	
	PROC SQL;
		Create Table project.&num.Cmingrades AS
		Select ID, Grade, Count(Grade) as Cmin
		From &table
		Where Grade = "C-"
		Group BY ID, Grade
		Having Count(Grade)
		;
	quit;	
	PROC SQL;
		Create Table project.&num.Dpgrades AS
		Select ID, Grade, Count(Grade) as Dp
		From &table
		Where Grade = "D+"
		Group BY ID, Grade
		Having Count(Grade)
		;
	quit;	
	PROC SQL;
		Create Table project.&num.Dgrades AS
		Select ID, Grade, Count(Grade) as D
		From &table
		Where Grade = "D"
		Group BY ID, Grade
		Having Count(Grade)
		;
	quit;	
	PROC SQL;
		Create Table project.&num.Dmingrades AS
		Select ID, Grade, Count(Grade) as Dmin
		From &table
		Where Grade = "D-"
		Group BY ID, Grade
		Having Count(Grade)
		;
	quit;	
	PROC SQL;
		Create Table project.&num.Failgrades AS
		Select ID, Grade, Count(Grade) as Failing
		From &table
		Where Grade in ("E", "UW", "WE", "IE")
		Group BY ID, Grade
		Having Count(Grade)
		;
	quit;
		PROC SQL;
		Create Table project.&num.Wgrades AS
		Select ID, Grade, Count(Grade) as W
		From &table
		Where Grade in ("W")
		Group BY ID, Grade
		Having Count(Grade)
		;
	quit;
/* 	Put all of the letter grades together for the Student ID */
	Data project.&num.lgrades;
		MERGE project.&num.Agrades project.&num.Amingrades project.&num.Bpgrades
		project.&num.Bgrades project.&num.Bmingrades project.&num.Cpgrades
		project.&num.Cgrades project.&num.Cmingrades project.&num.Dpgrades
		project.&num.Dgrades project.&num.Dmingrades project.&num.Failgrades
		project.&num.Wgrades;
	BY ID;
	run;
	
%MEND reports;

/* Report 1 */

%reports(table= project.final, num= Rep1);

/* Everything should be the same as the first report save the original table should be one where only math and stat courses are given as data */
/* So let's filter out the original table */

/* Report 2 */
PROC SQL;
	Create Table project.statmath AS
	Select *
	from project.final
	where Course LIKE '%STAT%' OR Course LIKE '%MATH%'
	;
quit;

/* Now lets make the second report tables with a few extra */
%reports(table= project.statmath, num= Rep2);

/* Time to put the different tables together into the two reports */

%MACRO finishedreport(x=,num=);
DATA project.Report&x;
	MERGE project.&num.semestergpa project.&num.accugpa 
	project.&num.earnedhours project.&num.gradedhours 
	project.&num.standing project.&num.overallgpaclean 
	project.&num.overallhoursclean project.&num.overallghoursclean;
	BY ID Year Semester;
	DROP Date Credits points tcredits tpoints xcredits;
run;

DATA project.Report&x;
	MERGE project.Report&x project.&num.totrcourses project.&num.lgrades;
	BY ID;
/* 	Clean the data up some */
	IF last.ID then Rcourse = TotalRepeats;
	Else Rcourse = ".";
	IF last.ID then A_ = A;
	Else A_ = ".";
	IF last.ID then Am = Amin;
	Else Am = ".";
	IF last.ID then Bpl = Bp;
	Else Bpl = ".";
	IF last.ID then B_ = B;
	Else B_ = ".";
	IF last.ID then Bm = Bmin;
	Else Bm = ".";
	IF last.ID then Cpl = Cp;
	Else Cpl = ".";
	IF last.ID then C_ = C;
	Else C_ = ".";
	IF last.ID then Cm = Cmin;
	Else Cm = ".";
	IF last.ID then Dpl = Dp;
	Else Dpl = ".";
	IF last.ID then D_ = D;
	Else D_ = ".";
	IF last.ID then Dm = Dmin;
	Else Dm = ".";
	IF last.ID then E = Failing;
	Else E = ".";
	IF last.ID then W_ = W;
	Else W_ = ".";
	
/* 	Make it pretty */
	Label ID='Student ID' Year='School Year' Semester='School Semester'
	SemGPA='Semester GPA' CumGPA='Cumulative GPA' ehours='Earned Credit Hours' ghours='Graded Credit Hours'
	standing='Class Standing' GPA='Overall GPA' Hours='Total Hours Earned' GradedHours='Total Graded Hours Earned'
	Rcourse='Number of Repeated Courses' A_="A's Received" Am="A-'s Received" Bpl="B+'s Received"
	B_="B's Received" Bm="B-'s Received" Cpl="C+'s Received" C_="C's Received" Cm="C-'s Received"
	Dpl="D+'s Received" D_="D's Received" Dm="D-'s Received" E="E,IE,UW,WE's Received" W_="W's Received";
	DROP Grade TotalRepeats A Amin Bp B Bmin Cp C Cmin Dp D Dmin Failing W;
run;

%MEND finishedreport;

/* Finished Report 1 */

%finishedreport(x=1,num=rep1);

/* Finished Report 2 */

%finishedreport(x=2,num=rep2);
/* this will gather the information that I want */
DATA work.Report2 ;
	set project.Report2;
	DROP Year Semester SemGPA CumGPA ghours ehours standing;
run;
PROC SQL;
	Create Table project.Report2 AS
	Select *
	FROM work.Report2
	WHERE GPA is not NULL
	;
quit;

DATA work.Report1;
	set project.Report1;
	DROP Year Semester SemGPA CumGPA ghours ehours standing;
run;
PROC SQL;
	Create Table work.Reportsecond AS
	Select *
	FROM work.Report1
	WHERE GPA is not NULL
	;
quit;
/* Put the overall information together */

DATA project.Report2;
	set project.Report2;
	RENAME GPA=MSGPA Hours=MSHours GradedHours=MSGradedHours Rcourse=MSRcourse A_=A
	Am=Amin Bpl=Bp B_=B Bm=Bmin Cpl=Cp C_=C Cm=Cmin Dpl=Dp D_=D Dm=Dmin E=Failing W_=W;
run;
PROC SQL;
	Create Table project.finishedreport2 AS
	Select *
	FROM work.reportsecond
	Inner Join project.report2 ON report2.ID = reportsecond.ID
	;
quit;
/* this will clean up the finished reports labels */
DATA project.finishedreport2;
	set project.finishedreport2;
	LABEL MSGPA='Math/Stat Overall GPA' MSHours='Math/Stat Total Earned Hours' MSGradedHours='Math/Stat Earned Graded Hours'
	MSRcourse='Math/Stat Total Repeated Courses' A="Math/Stat A's" Amin="Math/Stat A-'s" Bp="Math/Stat B+'s"
	B="Math/Stat B's" Bmin="Math/Stat B-'s" Cp="Math/Stat C+'s" C="Math/Stat C's" Cmin="Math/Stat C-'s"
	Dp="Math/Stat D+'s" D="Math/Stat D's" Dmin="Math/Stat D-'s" Failing="Math/Stat A's" W="Math/Stat W's";
run;


/* Okay lets move onto report 3 */
/* this report needs the overall information of the students which is already in a table and then sorted
 by GPA. This must use a MACRO that can then be easily applied to Report 4*/

%MACRO report3_4(table=, report=,Hours=,GPA=,where=);

/* I need to know what 10% is of the number of students once the tables are limited */
/*  between 60 and 130 total credits or more than 20 M/S credits */
	PROC SQL;
		Create Table project.&report AS
		Select*
		FROM project.&table
		WHERE &Hours. &where.
		ORDER BY &GPA desc
		;
	quit;

%MEND report3_4;

%report3_4(table=finishedreport2, report=report3,Hours=Hours,GPA=GPA, where=between 60 AND 130);
%report3_4(table=finishedreport2, report=report4, Hours=MSHours,GPA=MSGPA, where=>20);

/* finish report 3 and 4 */
PROC SQL OUTOBS=12;
	CREATE TABLE project.topreport3 AS
	SELECT ID, GPA
	FROM project.report3
	;
quit;
PROC SQL OUTOBS=15;
	CREATE TABLE project.topreport4 AS
	SELECT ID, MSGPA
	FROM project.report4
	;
quit;

/* Use PROC report for the results */
ods html file= "/home/u55486647/Second Term/Final Project/finaloutput.html";

title "Report 1: Semester and Overall Student Report";
PROC REPORT DATA=project.Report1 BOX HEADLINE;
run;
title;
title "Report 2: Overall Student with Math and Statistics Course Overall Student Report";
PROC REPORT DATA=project.finishedReport2 BOX HEADLINE;
run;
title;
title "Report 3: Top 10% of Students with Credits Earned between 60 and 130 upon Graduating";
PROC REPORT DATA=project.topReport3 BOX;
run;
title;
title "Report 4: Top 10% of Students with at least 20 Credits earned in Math or Stat classes";
PROC REPORT DATA=project.topReport4 BOX;
run;
title;

ods html close;

ods graphics on;
PROC SGPLOT data=project.finishedreport2;
	histogram GPA / showbins;
	density GPA / curvelabel='Density Curve for GPA';
run;


libname project clear;
