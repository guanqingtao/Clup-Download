-- 在主库上执行
CREATE DATABASE cs_sys_ha;

CREATE TABLE cs_sys_heartbeat(
  hb_time TIMESTAMP
);

--在proxydb中执行下面的内容
CREATE OR REPLACE FUNCTION csha_update_plp_server(in_serv_name text, in_db_list text, in_host_list text)
  RETURNS text AS
$BODY$
DECLARE
    v_ddl text;
    v_srv_opt text;
    v_db_array text[];
    v_host_array text[];
    i int;
    x text;
    rec RECORD;
BEGIN
    v_srv_opt := '';
    FOR rec IN (select split_part(opt, '=', 1) as part from (select unnest(srvoptions) as opt from pg_foreign_server where srvname=in_serv_name) t where t.opt like 'p%') LOOP
        IF length(v_srv_opt) =0 THEN
            v_srv_opt := 'drop '||rec.part;
        ELSE
            v_srv_opt := 'drop '||rec.part||','||v_srv_opt;
        END IF;
    END LOOP;

    v_db_array := string_to_array(in_db_list, ',');
    v_host_array := string_to_array(in_host_list, ',');
    i := 0;
    FOREACH x IN ARRAY v_db_array
    LOOP
        v_srv_opt = v_srv_opt || format(',add p%s ''dbname=%s host=%s''', i, x, v_host_array[i+1]);
        i := i + 1;
    END LOOP;
    v_ddl = 'ALTER SERVER '|| in_serv_name ||' OPTIONS('|| v_srv_opt ||');';
    EXECUTE v_ddl;
    return v_ddl;
END;
$BODY$
LANGUAGE 'plpgsql';