-- db_space_usage.sql
--  Space Usage Report for Oracle Multitenant Databases
--    Shows usage for the Root Container as well as each Pluggable Database

set verify off
set trimspool on
set linesize 250
set tab off
set feedback off
set pagesize 250
set newpage 0

prompt Database Space Usage Report for &&1

clear columns

column ts       format a30         heading 'Tablespace'
column used_mb  format 999,999,999 heading 'Used (MB)'
column free_mb  format 999,999,999 heading 'Free (MB)'
column total_mb format 999,999,999 heading 'Total (MB)'
column pct_free format 999         heading 'Pct|Free'
column max_size format 999,999,999 heading "Max Size (MB)"
column max_free format 999,999,999 heading "Max Free (MB)"
column con_name format a30         heading "Container"

clear breaks
clear computes

break on con_name skip 1
compute sum of used_mb on con_name
compute sum of free_mb on con_name
compute sum of total_mb on con_name
compute sum of max_free on con_name
compute sum of max_size on con_name

select nvl(p.name,'CDB$ROOT') con_name
  ,df.tablespace_name ts
  ,(df.total_space - nvl(fs.free_space,0)) used_mb
  ,nvl(fs.free_space,0) free_mb
  ,(nvl(fs.free_space,0) + df.free_space) max_free
  ,df.total_space total_mb
  ,df.max_size
  ,round(100 * ((nvl(fs.free_space,0)+df.free_space) / df.max_size)) pct_free
from (
  select con_id
    ,tablespace_name
    ,round(sum(bytes)/1024/1024) total_space
    ,round(sum(decode(autoextensible,'NO',bytes,maxbytes))/1024/1024) max_size
    ,(round(sum(decode(autoextensible,'NO',bytes,maxbytes))/1024/1024)) - (round(sum(bytes)/1024/1024)) free_space
  from cdb_data_files
  group by con_id,tablespace_name) df
left outer join (
  select con_id
    ,tablespace_name
    ,round(sum(bytes)/1024/1024) free_space 
  from cdb_free_space
  group by con_id
    ,tablespace_name) fs
on fs.tablespace_name = df.tablespace_name  
  and fs.con_id(+) = df.con_id
left outer join v$pdbs p
on p.con_id = df.con_id
union
select nvl(p.name,'CDB$ROOT') con_name
  ,df.tablespace_name ts
  ,df.total_space used_mb
  ,0 free_mb
  ,0 max_free
  ,df.total_space total_mb
  ,df.max_size
  ,0 pct_free
from (
  select con_id
    ,tablespace_name
    ,round(sum(bytes)/1024/1024) total_space
    ,round(sum(decode(autoextensible,'NO',bytes,maxbytes))/1024/1024) max_size
    ,0 free_space
  from cdb_temp_files
  group by con_id,tablespace_name) df
left outer join v$pdbs p
on p.con_id = df.con_id
order by con_name
  ,pct_free;

clear breaks
clear computes
clear columns

column db_total    format 999,999,999  heading "Total DB (MB)"
column total_space format 999,999,999  heading "Data (MB)"
column temp_space  format 999,999,999  heading "Temp (MB)"
column total_free  format 999,999,999  heading "Data Free (MB)"
column total_usage format 999          heading "Data Usage|(%)"
column con_name    format a30          heading "Container Name"

select nvl(p.name,'CDB$ROOT') con_name
  ,round(df.total_space/1024/1024) total_space
  ,round(tf.total_temp/1024/1024) temp_space
  ,round((df.total_space + tf.total_temp)/1024/1024) db_total
  ,nvl(fs.total_free,0)/1024/1024 total_free
  ,round( 100 * ((df.total_space - nvl(fs.total_free,0))/df.total_space)) total_usage
from (
  select con_id
    ,nvl(sum(bytes),0) total_space
  from cdb_data_files
  group by con_id) df
join (
  select con_id
    ,nvl(sum(bytes),0) total_free
  from cdb_free_space
  group by con_id) fs
on df.con_id = fs.con_id 
join (
  select con_id
    ,nvl(sum(bytes),0) total_temp
  from cdb_temp_files
  group by con_id) tf
on fs.con_id = tf.con_id
left outer join v$pdbs p
on p.con_id = df.con_id
order by con_name;

clear columns
clear breaks
clear computes