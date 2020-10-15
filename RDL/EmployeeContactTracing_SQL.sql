Create FUNCTION [dbo].[fn_RPTSF_GET_EMAIL] (@PersonIDno integer)
RETURNS nvarchar(max) 

AS
BEGIN

DECLARE @EMAIl NVARCHAR(200)
Declare @RTN nvarchar(max)  

Set @RTN = ''

DECLARE C1 CURSOR for
SELECT
             SUBSTRING(T.SHORTNM, 1, 2 ) + ':' + EM.EMAILADDRESSTXT
        FROM 
            EMAILADDRESS EM
            INNER JOIN  CONTACTTYPE T ON EM.CONTACTTYPEID = T.CONTACTTYPEID
        WHERE 
            EM.PERSONID = @PersonIDNo
  

OPEN C1
FETCH NEXT FROM C1 into @EMAIL
WHILE @@Fetch_Status = 0
  BEGIN

IF @RTN <> ''
 Begin
 set @RTN =  @RTN + '`'
 End 
 
 set @RTN = @RTN + @EMAIL 
     
FETCH NEXT FROM c1 into @EMAIL
  END
CLOSE c1
DEALLOCATE c1
return @RTN
        END
Go
		grant execute on fn_RPTSF_GET_EMAIL to kronosgroup,kronosrgroup
Go

------------------------------------PHONE #s----------------------------------------------------------------

Create FUNCTION [dbo].[fn_RPTSF_GET_PHONE] (@PersonIDno integer)
RETURNS nvarchar(max) 

AS
BEGIN

DECLARE @PHONE NVARCHAR(200)
Declare @RTN nvarchar(max)  

Set @RTN = ''

DECLARE C1 CURSOR for
 SELECT
            T.SHORTNM + ':' + PN.PHONENUM
        FROM 
            PHONENUMBER PN
            INNER JOIN  CONTACTTYPE T ON PN.CONTACTTYPEID = T.CONTACTTYPEID
        WHERE 
            PN.PERSONID = @PersonIDno and pn.phonenum is not null; 
  

OPEN C1
FETCH NEXT FROM C1 into @PHONE
WHILE @@Fetch_Status = 0
  BEGIN

IF @RTN <> ''
 Begin
 set @RTN =  @RTN + '`'
 End 
 
 set @RTN = @RTN + @PHONE 
     
FETCH NEXT FROM c1 into @PHONE
  END
CLOSE c1
DEALLOCATE c1
return @RTN
        END
Go
		grant execute on fn_RPTSF_GET_PHONE to kronosgroup,kronosrgroup
Go

----------------------------------------------------------------------------------------------------
GO
/****** Object:  StoredProcedure [dbo].[KSS_EmployeeContact_Tracing]    Script Date: 8/28/2020 2:21:52 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
Create PROCEDURE [dbo].[KSS_EmployeeContact_Tracing] (@PID varchar(50), @from_timeframe datetime, @to_timeframe datetime, @LaborLevs varchar(200))
  AS
  BEGIN
--select personnum from person
---------------------------------------------Start Create Tables--------------------------------------------------------------------------------------------------
CREATE TABLE #ECT_SelectedEmp(
Employeeid integer,
EventDTM datetime,
StartDtm datetime,
LaborAcctid integer,
L1ID integer,
L2ID integer,
L3ID integer,
L4ID integer,
L5ID integer,
L6ID integer,
L7ID integer,
EndDtm datetime
)

Create table #ECT_Trace_Emps(
Employeeid integer,
EventDTM datetime,
StartDtm datetime,
LaborAcctid integer,
L1ID integer,
L2ID integer,
L3ID integer,
L4ID integer,
L5ID integer,
L6ID integer,
L7ID integer,
EndDtm datetime,
--wl
matchECE varchar(1)
) 

Create table #ECT_Out(
RecType integer,
Employeeid integer,
Personnum varchar(100),
FullName varchar(200),
Eventdtm datetime,
SegStartOverlap datetime,
Labor1 varchar(100),
Labor2 varchar(100),
Labor3 varchar(100),
Labor4 varchar(100),
Labor5 varchar(100),
Labor6 varchar(100),
Labor7 varchar(100),
SegEndOverlap datetime,
SelEmpSegStart datetime,
SelEmpSegEnd datetime,
PhoneNums varchar(100),
Emails varchar(100)
) 

Create table #ECT_Sel_Labor(
LaborNum integer)

--------------------------------------------------------------End Create Tables------------------------------------------------------------------



--------------------------------------------------------------Begin Insert-----------------------------------------------------------------------

insert into #ECT_SelectedEmp
Select 
t.EMPLOYEEID, t.EVENTDTM, t.STARTDTM, isnull(t.laboracctid, h.laboracctid) as WorkedAcctID
, isnull(wl.laborlev1id,l.laborlev1ID), isnull(wl.laborlev2id,l.laborlev2ID), isnull(wl.laborlev3id,l.laborlev3ID),
 isnull(wl.laborlev4id,l.laborlev4ID), isnull(wl.laborlev5id,l.laborlev5ID),isnull(wl.laborlev6id,l.laborlev6ID)
 , isnull(wl.laborlev7id,l.laborlev7ID)
,  isnull(t.enddtm, dateadd(second,  t.durationsecsqty,  t.startdtm)) as ENDDTM
from timesheetitem t
    join person p on t.employeeid = p.personid and t.deletedsw <> 1 and t.tmshtitemtypeid = 40
        join homeaccthist h on t.employeeid = h.employeeid and t.eventDTM >= h.effectivedtm and t.eventdtm <= h.expirationdtm
                   left outer join laboracct l on h.laboracctid = l.laboracctid
                   left outer JOin laboracct wl on t.laboracctid = wl.laboracctid
where p.personnum = @PID
and t.eventdtm >= @from_timeframe and eventdtm < @to_timeframe and t.deletedsw=0
and t.paycodeid is null;

--select * from #ECT_SelectedEmp

insert into #ECT_Trace_Emps
Select 
t.EMPLOYEEID, t.EVENTDTM, t.STARTDTM, isnull(t.laboracctid, h.laboracctid) as WorkedAcctID
, isnull(wl.laborlev1id,l.laborlev1ID), isnull(wl.laborlev2id,l.laborlev2ID), isnull(wl.laborlev3id,l.laborlev3ID),
 isnull(wl.laborlev4id,l.laborlev4ID), isnull(wl.laborlev5id,l.laborlev5ID), isnull(wl.laborlev6id,l.laborlev6ID)
 , isnull(wl.laborlev7id,l.laborlev7ID)
,  isnull(t.enddtm, dateadd(second,  t.durationsecsqty,  t.startdtm)) as ENDDTM
--WL
, null
from 
#ECT_SelectedEmp c
join timesheetitem t on t.eventdtm -1 <= c.EVENTDTM and t.eventdtm +1 >= c.EVENTDTM-- t.eventdtm = c.EVENTDTM
       join homeaccthist h on t.employeeid = h.employeeid and t.eventDTM >= h.effectivedtm and t.eventdtm <= h.expirationdtm
            left outer join laboracct l on h.laboracctid = l.laboracctid
                   left outer JOin laboracct wl on t.laboracctid = wl.laboracctid
where  t.eventdtm +1 >= @from_timeframe and t.eventdtm -1 < @to_timeframe and t.DELETEDSW=0
and t.paycodeid is null;
--WL
	Update #ect_Trace_Emps
		set matchECE = (Select Top 1 'Y' from #ect_selectedEmp ESE where #ect_Trace_Emps.startdtm between ESE.startdtm and ESE.endDTM )
	Update #ect_Trace_Emps
		set matchECE = (Select Top 1 'Y' from #ect_selectedEmp ESE where #ect_Trace_Emps.Enddtm between ESE.startdtm and ESE.endDTM)
		where matchECE is null
	Update #ect_Trace_Emps
		set matchECE = (Select Top 1 'Y' from #ect_selectedEmp ESE where ESE.startdtm between #ect_Trace_Emps.startdtm and #ect_Trace_Emps.endDTM)
		where matchECE is null
	Update #ect_Trace_Emps
		set matchECE = (Select Top 1 'Y' from #ect_selectedEmp ESE where ESE.Enddtm between #ect_Trace_Emps.startdtm and #ect_Trace_Emps.endDTM)
		where matchECE is null

delete from #ect_Trace_Emps where matchECE is null

---Delete out the employee who was selected in the beginning.
Delete from #ECT_Trace_emps where employeeid in (Select employeeid from #ECT_SelectedEmp);


 --select * from #ECT_Trace_Emps

 declare @Employeeid integer
declare @EventDTM datetime
declare @StartDtm datetime
declare @LaborAcctid integer
declare @L1ID integer
declare @L2ID integer
declare @L3ID integer
declare @L4ID integer
declare @L5ID integer
declare @L6ID integer
declare @L7ID integer
declare @EndDtm datetime

 declare cselemp cursor for 
 Select * from #ECT_SelectedEmp;

 insert into #ECT_Sel_Labor
Select InListID from dbo.fn_integerinlist(replace(@LaborLevs, '`', ','))

  declare @LL table (Labor nvarchar(500))
  
 open cSelEmp
 fetch next from cSelEmp
 into @Employeeid, @EventDTM, @StartDTM, @LaborAcctID, @L1ID, @L2ID, @L3ID,@L4ID,@L5ID,@L6ID,@L7ID, @EndDTM

 While @@FETCH_STATUS = 0
  Begin
 ----LL1
  if 1 in (select LaborNum from #ECT_Sel_Labor)
  begin
   delete from @LL
  insert into @LL select L1ID from #ECT_SelectedEmp where Employeeid = @Employeeid and EventDTM = @EventDTM
   Delete from #ECT_Trace_Emps where (l1ID not in (select labor from @ll) or l1id is null) and startdtm between @StartDTm and @EndDTm--and EventDTM = @EventDTM and startdtm <= @EndDtm and enddtm >= @StartDtm
   	Delete from #ECT_Trace_Emps where (l1ID not in (select labor from @ll) or l1id is null) and enddtm between @StartDTm and @EndDTm
	  	       Delete from #ECT_Trace_Emps where (l1ID not in (select labor from @ll) or l1id is null) and  @StartDTM between Startdtm and EndDTM
   Delete from #ECT_Trace_Emps where (l1ID not in (select labor from @ll) or l1id is null) and  @enddtm between startDTm and EndDTm
	 	 end
 -----LL2
 if 2 in (select LaborNum from #ECT_Sel_Labor)
  begin
 delete from @LL
  insert into @LL select L2ID from #ECT_SelectedEmp where Employeeid = @Employeeid and EventDTM = @EventDTM
   Delete from #ECT_Trace_Emps where (l2ID not in (select labor from @ll) or l2id is null)  and startdtm between @StartDTm and @EndDTm--and EventDTM = @EventDTM and startdtm <= @EndDtm and enddtm >= @StartDtm
   Delete from #ECT_Trace_Emps where (l2ID not in (select labor from @ll) or l2id is null)  and enddtm between @StartDTm and @EndDTm
 	 	       Delete from #ECT_Trace_Emps where (l2ID not in (select labor from @ll) or l2id is null) and  @StartDTM between Startdtm and EndDTM
   Delete from #ECT_Trace_Emps where (l2ID not in (select labor from @ll) or l2id is null) and  @enddtm between startDTm and EndDTm
	 end
-----LL3
 if 3 in (select LaborNum from #ECT_Sel_Labor)
   begin
    delete from @LL
  insert into @LL select L3ID from #ECT_SelectedEmp where Employeeid = @Employeeid and EventDTM = @EventDTM
   Delete from #ECT_Trace_Emps where (l3ID not in (select labor from @ll) or l3id is null) and startdtm between @StartDTm and @EndDTm--and EventDTM = @EventDTM and startdtm <= @EndDtm and enddtm >= @StartDtm
   Delete from #ECT_Trace_Emps where (l3ID not in (select labor from @ll) or l3id is null) and enddtm between @StartDTm and @EndDTm 
		       Delete from #ECT_Trace_Emps where (l3ID not in (select labor from @ll) or l3id is null) and  @StartDTM between Startdtm and EndDTM
   Delete from #ECT_Trace_Emps where (l3ID not in (select labor from @ll) or l3id is null) and  @enddtm between startDTm and EndDTm
		 end
 ----LL4
 if 4 in (select LaborNum from #ECT_Sel_Labor)
  begin
   delete from @LL
  insert into @LL select L4ID from #ECT_SelectedEmp where Employeeid = @Employeeid and EventDTM = @EventDTM
   Delete from #ECT_Trace_Emps where (l4ID not in (select labor from @ll) or l4id is null) and  startdtm between @StartDTm and @EndDTm--and EventDTM = @EventDTM and startdtm <= @EndDtm and enddtm >= @StartDtm;
   Delete from #ECT_Trace_Emps where (l4ID not in (select labor from @ll) or l4id is null) and  enddtm between @StartDTm and @EndDTm 
	       Delete from #ECT_Trace_Emps where (l4ID not in (select labor from @ll) or l4id is null) and  @StartDTM between Startdtm and EndDTM
   Delete from #ECT_Trace_Emps where (l4ID not in (select labor from @ll) or l4id is null) and  @enddtm between startDTm and EndDTm
	   end
----LL5
if 5 in (select LaborNum from #ECT_Sel_Labor)
  begin
delete from @LL
  insert into @LL select L5ID from #ECT_SelectedEmp where Employeeid = @Employeeid and EventDTM = @EventDTM
   Delete from #ECT_Trace_Emps where (l5ID not in (select labor from @ll) or l5id is null) and  startdtm between @StartDTm and @EndDTm--and EventDTM = @EventDTM and startdtm <= @EndDtm and enddtm >= @StartDtm
   Delete from #ECT_Trace_Emps where (l5ID not in (select labor from @ll) or l5id is null) and  enddtm between @StartDTm and @EndDTm
       Delete from #ECT_Trace_Emps where (l5ID not in (select labor from @ll) or l5id is null) and  @StartDTM between Startdtm and EndDTM
   Delete from #ECT_Trace_Emps where (l5ID not in (select labor from @ll) or l5id is null) and  @enddtm between startDTm and EndDTm
	
	 end
----LL6
if 6 in (select LaborNum from #ECT_Sel_Labor)
  begin
delete from @LL
  insert into @LL select L6ID from #ECT_SelectedEmp where Employeeid = @Employeeid and EventDTM = @EventDTM
   Delete from #ECT_Trace_Emps where (l6ID not in (select labor from @ll) or l6id is null) and  startdtm between @StartDTm and @EndDTm--and EventDTM = @EventDTM and startdtm <= @EndDtm and enddtm >= @StartDtm
   Delete from #ECT_Trace_Emps where (l6ID not in (select labor from @ll) or l6id is null) and  enddtm between @StartDTm and @EndDTm
     end
----LL7
if 7 in (select LaborNum from #ECT_Sel_Labor)
  begin
delete from @LL
  insert into @LL select L7ID from #ECT_SelectedEmp where Employeeid = @Employeeid and EventDTM = @EventDTM
   Delete from #ECT_Trace_Emps where (l7ID not in (select labor from @ll) or l7id is null) and  startdtm between @StartDTm and @EndDTm--and EventDTM = @EventDTM and startdtm <= @EndDtm and enddtm >= @StartDtm
   Delete from #ECT_Trace_Emps where (l7ID not in (select labor from @ll) or l7id is null) and  enddtm between @StartDTm and @EndDTm
     end

	 ---REPEAT FOR ALL 7	 
  --fetch next into @Employeeid, @EventDTM, @StartDTM, @LaborAcctID, @L1ID, @L2ID, @L3ID,@L4ID,@L5ID,@L6ID,@L7ID, @EndDTM
   fetch next from cSelEmp
 into @Employeeid, @EventDTM, @StartDTM, @LaborAcctID, @L1ID, @L2ID, @L3ID,@L4ID,@L5ID,@L6ID,@L7ID, @EndDTM
  
  End

  Close CSelEmp
  Deallocate CSelEmp
  
  -- select * from #ect_trace_emps

insert into #ECT_out
Select
1,
p.personid,
p.PERSONNUM,
p.fullnm,
t.eventdtm,
min(t.startdtm),
la1.NAME,
la2.NAME,
la3.NAME,
la4.NAME,
la5.NAME,
la6.NAME,
la7.NAME,
max(t.enddtm),
null,null,
null,null
from 
#ECT_selectedEmp t
join person p on p.personid = t.employeeid
left outer join laborlevelentry la1 on la1.LABORLEVELENTRYID = t.L1ID
left outer join laborlevelentry la2 on la2.LABORLEVELENTRYID = t.L2ID
left outer join laborlevelentry la3 on la3.LABORLEVELENTRYID = t.L3ID
left outer join laborlevelentry la4 on la4.LABORLEVELENTRYID = t.L4ID
left outer join laborlevelentry la5 on la5.LABORLEVELENTRYID = t.L5ID
left outer join laborlevelentry la6 on la6.LABORLEVELENTRYID = t.L6ID
left outer join laborlevelentry la7 on la7.LABORLEVELENTRYID = t.L7ID 
group by 
p.personid,
personnum,
p.fullnm,
t.eventdtm,
la1.NAME,
la2.NAME,
la3.NAME,
la4.NAME,
la5.NAME,
la6.NAME,
la7.NAME
order by 5,6 ;

 insert into #ECT_out
Select 
2,
p.personid,
p.PERSONNUM,
p.fullnm,
t.eventdtm,
min(t.startdtm),
la1.NAME,
la2.NAME,
la3.NAME,
la4.NAME,
la5.NAME,
la6.NAME,
la7.NAME,
max(t.enddtm),
min(s.startdtm),max(s.enddtm),
null,null
from 
#ECT_trace_emps t
join #ECT_SelectedEmp s on t.STARTDTM <= s.enddtm and t.enddtm >= s.startdtm
join person p on p.personid = t.employeeid
left outer join laborlevelentry la1 on la1.LABORLEVELENTRYID = t.L1ID
left outer join laborlevelentry la2 on la2.LABORLEVELENTRYID = t.L2ID
left outer join laborlevelentry la3 on la3.LABORLEVELENTRYID = t.L3ID
left outer join laborlevelentry la4 on la4.LABORLEVELENTRYID = t.L4ID
left outer join laborlevelentry la5 on la5.LABORLEVELENTRYID = t.L5ID
left outer join laborlevelentry la6 on la6.LABORLEVELENTRYID = t.L6ID
left outer join laborlevelentry la7 on la7.LABORLEVELENTRYID = t.L7ID    
--where Match = 'MATCH' 
group by 
p.personid,
personnum,
p.fullnm,
t.eventdtm,
la1.NAME,
la2.NAME,
la3.NAME,
la4.NAME,
la5.NAME,
la6.NAME,
la7.NAME
order by 5,6,3 ;

----------------------------LOOP

SELECT
 RECTYPE,                 
 EMPLOYEEID,                 
 PERSONNUM,             
 FULLNAME,             
 EVENTDTM,                       
 SEGSTARTOVERLAP,                       
 LABOR1,             
 LABOR2,             
 LABOR3,             
 LABOR4,             
 LABOR5,             
 LABOR6,             
 LABOR7,             
 SEGENDOVERLAP,                       
 SELEMPSEGSTART,                       
 SELEMPSEGEND,                       
 dbo.fn_RPTSF_GET_PHONE(EMPLOYEEID) PHONENUMS,            
 dbo.fn_RPTSF_GET_EMAIL(EMPLOYEEID) EMAILS
FROM
    #ECT_OUT
    order by 1,5,6,3;
	
------------------------------------------------------------TROUBLESHOOTING------------------------------------------------------------------------------
--select * from #ect_SelectedEmp
--select * from #ect_Trace_Emps order by 1
--select * from  #ect_Out
--select * from #ect_Sel_Labor

END
