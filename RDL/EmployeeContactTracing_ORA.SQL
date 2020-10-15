Create global temporary table ECT_SelectedEmp(
Employeeid integer,
EventDTM date,
StartDtm date,
LaborAcctid integer,
L1ID integer,
L2ID integer,
L3ID integer,
L4ID integer,
L5ID integer,
L6ID integer,
L7ID integer,
EndDtm date
) on commit preserve rows
/
create or replace public synonym ECT_SelectedEmp for ECT_SelectedEmp
/
grant select,insert,update,delete on ECT_SelectedEmp to kronosuser,kronosruser
/
Create global temporary table ECT_Trace_Emps(
Employeeid integer,
EventDTM date,
StartDtm date,
LaborAcctid integer,
L1ID integer,
L2ID integer,
L3ID integer,
L4ID integer,
L5ID integer,
L6ID integer,
L7ID integer,
EndDtm date, 
MatchECE nvarchar2(1)
) on commit preserve rows
/
create or replace public synonym ECT_Trace_Emps for ECT_Trace_Emps
/
grant select,insert,update,delete on ECT_Trace_Emps to kronosuser,kronosruser
/
Create global temporary table ECT_Out(
RecType integer,
Employeeid integer,
Personnum nvarchar2(200),
FullName nvarchar2(200),
Eventdtm date,
SegStartOverlap date,
Labor1 nvarchar2(100),
Labor2 nvarchar2(100),
Labor3 nvarchar2(100),
Labor4 nvarchar2(100),
Labor5 nvarchar2(100),
Labor6 nvarchar2(100),
Labor7 nvarchar2(100),
SegEndOverlap date,
SelEmpSegStart date,
SelEmpSegEnd date,
PhoneNums nvarchar2(2000),
Emails nvarchar2(2000)
) on commit preserve rows
/
create or replace public synonym ECT_Out for ECT_Out
/
grant select,insert,update,delete on ECT_Out to kronosuser,kronosruser
/
Create global temporary table ECT_Sel_Labor(
LaborNum integer)
on commit preserve rows
/
Create global temporary table ECT_Labor(
Labor nvarchar2(500)
) on commit preserve rows
/
create or replace public synonym ECT_Labor for ECT_Labor
/
grant select,insert,update,delete on ECT_Labor to kronosuser,kronosruser
/
--------CREATE SYNONYM
create or replace public synonym ECT_Sel_Labor for ECT_Sel_Labor
/
grant select,insert,update,delete on ECT_Sel_Labor to kronosuser,kronosruser
/
Create global temporary table ECT_Contact(
PersonID integer,
ContactInfo nvarchar2(200),
ContactType nvarchar2(25)
)
on commit preserve rows
/
create or replace public synonym ECT_Contact for ECT_Contact
/
grant select,insert,update,delete on ECT_Contact to kronosuser,kronosruser
/
-------------CREATE PACKAGE
CREATE OR REPLACE PACKAGE TKCSOWNER.ECTTraceRpt
AS
   TYPE Out_REC IS REF CURSOR
      RETURN ECT_out%ROWTYPE;
END ECTTraceRpt;
/
create or replace public synonym ECTTraceRpt for ECTTraceRpt
/
grant execute on ECTTraceRpt to kronosuser,kronosruser
/
--------CREATE FUNCTIONS
CREATE OR REPLACE Function TKCSOWNER.RPTSF_GET_EMAIL
( P_PERSONID IN NUMBER)
RETURN NVARCHAR2
IS
RETURNVALUE  NVARCHAR2(4000) := ' ' ;
PH_NUM  NVARCHAR2(4000);


  CURSOR c1 IS
        SELECT
            SUBSTR( T.SHORTNM, 2 ) || ':' || EM.EMAILADDRESSTXT
        FROM 
            EMAILADDRESS EM
            INNER JOIN  CONTACTTYPE T ON EM.CONTACTTYPEID = T.CONTACTTYPEID
        WHERE 
            EM.PERSONID = P_PERSONID;      

BEGIN
    OPEN c1;
    LOOP
            FETCH c1 INTO PH_NUM;
        EXIT WHEN C1%NOTFOUND;
            IF RETURNVALUE = ' ' THEN 
                    RETURNVALUE := PH_NUM;
              ELSE 
                    RETURNVALUE := RETURNVALUE || '*'  || PH_NUM;
            END IF;
    END LOOP;
      CLOSE c1;

    RETURN RETURNVALUE;
END;
/
create or replace public synonym RPTSF_GET_EMAIL for RPTSF_GET_EMAIL
/
grant execute on RPTSF_GET_EMAIL to kronosuser,kronosruser
/
------------------------Phone #s
CREATE OR REPLACE Function TKCSOWNER.RPTSF_GET_PHONE_NUM
( P_PERSONID IN NUMBER)
RETURN NVARCHAR2
IS
RETURNVALUE  NVARCHAR2(4000) := ' ' ;
PH_NUM  NVARCHAR2(4000);

  CURSOR c1 IS
        SELECT
            T.SHORTNM || ':' || PN.PHONENUM
        FROM 
            PHONENUMBER PN
            INNER JOIN  CONTACTTYPE T ON PN.CONTACTTYPEID = T.CONTACTTYPEID
        WHERE 
            PN.PERSONID = P_PERSONID and pn.phonenum is not null;      


BEGIN
    OPEN c1;
    LOOP
            FETCH c1 INTO PH_NUM;
        EXIT WHEN C1%NOTFOUND;
            IF RETURNVALUE = ' ' THEN 
                    RETURNVALUE := PH_NUM;
              ELSE 
                    RETURNVALUE := RETURNVALUE || '*'  || PH_NUM;
            END IF;
    END LOOP;
      CLOSE c1;

    RETURN RETURNVALUE;
END;
/
create or replace public synonym RPTSF_GET_PHONE_NUM for RPTSF_GET_PHONE_NUM
/
grant execute on RPTSF_GET_PHONE_NUM to kronosuser,kronosruser
/
---NOW CREATE SP
---NOW CREATE SP
Create or replace procedure KSS_EmployeeContact_Tracing (c_out OUT ECTTraceRpt.Out_REC,
PID in nvarchar2,from_timeframe in date,to_timeframe in date,
LaborLevs IN nvarchar2
)
as
Cursor cSelEmp is
Select * from ECT_SelectedEmp;

Cursor cLabor is
Select * from ECT_Sel_Labor;

vLabNum integer;

begin
--000939249
--1,2,3,4,5,6,7
execute immediate 'truncate table ECT_SelectedEmp';
execute immediate 'truncate table ECT_Trace_Emps';
execute immediate 'truncate table ECT_sel_labor';
execute immediate 'truncate table ECT_Out';
execute immediate 'truncate table ECT_Contact';
execute immediate 'truncate table ECT_Labor';
insert into ECT_SelectedEmp
Select 
t.EMPLOYEEID, t.EVENTDTM, t.STARTDTM, NVL(t.laboracctid, h.laboracctid) as WorkedAcctID
, nvl(wl.laborlev1id,l.laborlev1ID), nvl(wl.laborlev2id,l.laborlev2ID), nvl(wl.laborlev3id,l.laborlev3ID),
 nvl(wl.laborlev4id,l.laborlev4ID), nvl(wl.laborlev5id,l.laborlev5ID), nvl(wl.laborlev6id,l.laborlev6ID)
 , nvl(wl.laborlev7id,l.laborlev7ID)
, NVL(t.enddtm, t.startdtm + numTODSInterval(t.durationsecsqty, 'second')) as ENDDTM
from timesheetitem t
    join person p on t.employeeid = p.personid
        join homeaccthist h on t.employeeid = h.employeeid and t.eventDTM >= h.effectivedtm and t.eventdtm <= h.expirationdtm
                   left outer join laboracct l on h.laboracctid = l.laboracctid
                   left outer JOin laboracct wl on t.laboracctid = wl.laboracctid
where p.personnum = PID
and t.eventdtm >= from_timeframe and eventdtm < to_timeframe and t.deletedsw=0
and t.paycodeid is null;

insert into ECT_Trace_Emps
Select 
t.EMPLOYEEID, t.EVENTDTM, t.STARTDTM, NVL(t.laboracctid, h.laboracctid) as WorkedAcctID
, nvl(wl.laborlev1id,l.laborlev1ID), nvl(wl.laborlev2id,l.laborlev2ID), nvl(wl.laborlev3id,l.laborlev3ID),
 nvl(wl.laborlev4id,l.laborlev4ID), nvl(wl.laborlev5id,l.laborlev5ID), nvl(wl.laborlev6id,l.laborlev6ID)
 , nvl(wl.laborlev7id,l.laborlev7ID)
, NVL(t.enddtm, t.startdtm + numTODSInterval(t.durationsecsqty, 'second')) as ENDDTM
, null
from 
ECT_SelectedEmp c
join timesheetitem t on t.eventdtm -1 <= c.EVENTDTM and t.eventdtm +1 >= c.EVENTDTM--t.eventdtm = c.EVENTDTM
       join homeaccthist h on t.employeeid = h.employeeid and t.eventDTM >= h.effectivedtm and t.eventdtm <= h.expirationdtm
            left outer join laboracct l on h.laboracctid = l.laboracctid
                   left outer JOin laboracct wl on t.laboracctid = wl.laboracctid
where  t.eventdtm +1 >= from_timeframe and t.eventdtm -1 < to_timeframe and t.DELETEDSW=0
and t.paycodeid is null;
--WL
	Update ECT_Trace_Emps
		set matchECE = (Select 'Y' from ect_selectedEmp ESE where ect_Trace_Emps.startdtm between ESE.startdtm and ESE.endDTM  and rownum = 1);
	Update ECT_Trace_Emps
		set matchECE = (Select 'Y' from ect_selectedEmp ESE where ect_Trace_Emps.Enddtm between ESE.startdtm and ESE.endDTM and rownum = 1)
		where matchECE is null;
	Update ECT_Trace_Emps
		set matchECE = (Select 'Y' from ect_selectedEmp ESE where ESE.startdtm between ect_Trace_Emps.startdtm and ect_Trace_Emps.endDTM and rownum = 1)
		where matchECE is null;
	Update ECT_Trace_Emps
		set matchECE = (Select 'Y' from ect_selectedEmp ESE where ESE.Enddtm between ect_Trace_Emps.startdtm and ect_Trace_Emps.endDTM and rownum = 1)
		where matchECE is null;
delete from ECT_Trace_Emps where matchECE is null;
--
insert into ECT_sel_labor
Select * from table(fn_integerinlist(replace(LaborLevs, '`', ',')));
--
Delete from ECT_Trace_emps where employeeid in (Select employeeid from ECT_SelectedEmp);
for emprec in cSelEmp
loop
    for lval in cLABOR
    loop
        if lval.LaborNum=1 then
         --vLabNum := emprec.L1ID; 
                        delete from ECT_Labor;
             insert into ECT_Labor select L1ID from ECT_SelectedEmp where Employeeid = emprec.Employeeid and EventDTM = emprec.EventDTM;
              Delete from ECT_Trace_Emps where (l1ID not in (select labor from ECT_Labor) or l1id is null) and startdtm between emprec.StartDtm and emprec.EndDtm;--and EventDTM = emprec.EventDTM and startdtm <= emprec.EndDtm and enddtm >= emprec.StartDtm;
                Delete from ECT_Trace_Emps where (l1ID not in (select labor from ECT_Labor) or l1id is null) and enddtm between emprec.StartDtm and emprec.EndDtm;
                    Delete from ECT_Trace_Emps where (l1ID not in (select labor from ECT_Labor) or l1id is null) and emprec.startdtm between StartDtm and EndDtm;
                        Delete from ECT_Trace_Emps where (l1ID not in (select labor from ECT_Labor) or l1id is null) and emprec.ENDdtm between StartDtm and EndDtm;
 --Delete from ECT_Trace_Emps where l1ID <> emprec.L1ID or l1id is null;
        elsif lval.LaborNum=2 then
             --vLabNum := emprec.L1ID; 
             delete from ECT_Labor;
                          insert into ECT_Labor select L2ID from ECT_SelectedEmp where Employeeid = emprec.Employeeid and EventDTM = emprec.EventDTM;
              Delete from ECT_Trace_Emps where (l2ID not in (select labor from ECT_Labor) or l2id is null) and startdtm between emprec.StartDtm and emprec.EndDtm;
                Delete from ECT_Trace_Emps where (l2ID not in (select labor from ECT_Labor) or l2id is null) and enddtm between emprec.StartDtm and emprec.EndDtm;
                    Delete from ECT_Trace_Emps where (l2ID not in (select labor from ECT_Labor) or l2id is null) and emprec.startdtm between StartDtm and EndDtm;
                        Delete from ECT_Trace_Emps where (l2ID not in (select labor from ECT_Labor) or l2id is null) and emprec.ENDdtm between StartDtm and EndDtm;
                    elsif lval.LaborNum=3 then
             --vLabNum := emprec.L1ID; 
                       delete from ECT_Labor;
             insert into ECT_Labor select L3ID from ECT_SelectedEmp where Employeeid = emprec.Employeeid and EventDTM = emprec.EventDTM;
              Delete from ECT_Trace_Emps where (l3ID not in (select labor from ECT_Labor) or l3id is null) and startdtm between emprec.StartDtm and emprec.EndDtm;
                Delete from ECT_Trace_Emps where (l3ID not in (select labor from ECT_Labor) or l3id is null) and enddtm between emprec.StartDtm and emprec.EndDtm;
                    Delete from ECT_Trace_Emps where (l3ID not in (select labor from ECT_Labor) or l3id is null) and emprec.startdtm between StartDtm and EndDtm;
                        Delete from ECT_Trace_Emps where (l3ID not in (select labor from ECT_Labor) or l3id is null) and emprec.ENDdtm between StartDtm and EndDtm;
        elsif lval.LaborNum=4 then
             --vLabNum := emprec.L1ID;
               delete from ECT_Labor;
             insert into ECT_Labor select L4ID from ECT_SelectedEmp where Employeeid = emprec.Employeeid and EventDTM = emprec.EventDTM;
               Delete from ECT_Trace_Emps where (l4ID not in (select labor from ECT_Labor) or l4id is null) and startdtm between emprec.StartDtm and emprec.EndDtm;
                Delete from ECT_Trace_Emps where (l4ID not in (select labor from ECT_Labor) or l4id is null) and enddtm between emprec.StartDtm and emprec.EndDtm;
                    Delete from ECT_Trace_Emps where (l4ID not in (select labor from ECT_Labor) or l4id is null) and emprec.startdtm between StartDtm and EndDtm;
                        Delete from ECT_Trace_Emps where (l4ID not in (select labor from ECT_Labor) or l4id is null) and emprec.ENDdtm between StartDtm and EndDtm;
        elsif lval.LaborNum=5 then
             --vLabNum := emprec.L1ID; 
                       delete from ECT_Labor;
             insert into ECT_Labor select L5ID from ECT_SelectedEmp where Employeeid = emprec.Employeeid and EventDTM = emprec.EventDTM;
               Delete from ECT_Trace_Emps where (l5ID not in (select labor from ECT_Labor) or l5id is null) and startdtm between emprec.StartDtm and emprec.EndDtm;
                Delete from ECT_Trace_Emps where (l5ID not in (select labor from ECT_Labor) or l5id is null) and enddtm between emprec.StartDtm and emprec.EndDtm;
                    Delete from ECT_Trace_Emps where (l5ID not in (select labor from ECT_Labor) or l5id is null) and emprec.startdtm between StartDtm and EndDtm;
                        Delete from ECT_Trace_Emps where (l5ID not in (select labor from ECT_Labor) or l5id is null) and emprec.ENDdtm between StartDtm and EndDtm;
        elsif lval.LaborNum=6 then
             --vLabNum := emprec.L1ID; 
               delete from ECT_Labor;
             insert into ECT_Labor select L6ID from ECT_SelectedEmp where Employeeid = emprec.Employeeid and EventDTM = emprec.EventDTM;
                 Delete from ECT_Trace_Emps where (l6ID not in (select labor from ECT_Labor) or l6id is null) and startdtm between emprec.StartDtm and emprec.EndDtm;
                Delete from ECT_Trace_Emps where (l6ID not in (select labor from ECT_Labor) or l6id is null) and enddtm between emprec.StartDtm and emprec.EndDtm;
                    Delete from ECT_Trace_Emps where (l6ID not in (select labor from ECT_Labor) or l6id is null) and emprec.startdtm between StartDtm and EndDtm;
                        Delete from ECT_Trace_Emps where (l6ID not in (select labor from ECT_Labor) or l6id is null) and emprec.ENDdtm between StartDtm and EndDtm;
        elsif lval.LaborNum=7 then
             --vLabNum := emprec.L1ID; 
                         delete from ECT_Labor;
             insert into ECT_Labor select L7ID from ECT_SelectedEmp where Employeeid = emprec.Employeeid and EventDTM = emprec.EventDTM;
                  Delete from ECT_Trace_Emps where (l7ID not in (select labor from ECT_Labor) or l7id is null) and startdtm between emprec.StartDtm and emprec.EndDtm;
                Delete from ECT_Trace_Emps where (l7ID not in (select labor from ECT_Labor) or l7id is null) and enddtm between emprec.StartDtm and emprec.EndDtm;
                    Delete from ECT_Trace_Emps where (l7ID not in (select labor from ECT_Labor) or l7id is null) and emprec.startdtm between StartDtm and EndDtm;
                        Delete from ECT_Trace_Emps where (l7ID not in (select labor from ECT_Labor) or l7id is null) and emprec.ENDdtm between StartDtm and EndDtm;
         

        end if;
        
    end loop;

end loop;


insert into ECT_out
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
ect_selectedEmp t
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

insert into ECT_out
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
ect_trace_emps t
join ect_selectedemp s on t.STARTDTM <= s.enddtm and t.enddtm >= s.startdtm
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
order by 5,6,3 ;

open c_Out for
--Select * from ECT_out order by 1,5,6,3;
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
 RPTSF_GET_PHONE_NUM(EMPLOYEEID) PHONENUMS,            
 RPTSF_GET_EMAIL(EMPLOYEEID) EMAILS
FROM
    ect_OUT
    order by 1,5,6,3;

end;
/
create or replace public synonym ECT_Trace for ECT_trace
/
grant execute on KSS_EmployeeContact_Tracing to Kronosuser,kronosruser
/

