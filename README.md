Oracle-Database-21c-RAC-on-Docker
=================================

A set of scripts for using Oracle Database 21c RAC docker image in [Oracle Container Registry](https://container-registry.oracle.com/ords/f?p=113:1).

Configuration
-------------

Copy the file `dotenv.sample` to a file named `.env` and rewrite the contents.

```shell
# shared block storage
DEVICE=/dev/oracleoci/oraclevdb  
# Oracle Container Registry username and password
REGISTRY_USERNAME=xxxxxxxx@xxxxxx.xxx
REGISTRY_PASSWORD=xxxxxxxx  
```

Example of use
--------------

### [deploy-single-host.sh](deploy-single-host.sh) ###

Deploy on a single host using block storage.

```console
[opc@instance-20211119-1731 ~]$ ./deploy-on-single-host.sh
2021-11-19 08:36:05+00:00 Load environment variables from .env
2021-11-19 08:36:05+00:00 Configure kernel parameter
kernel.unknown_nmi_panic = 1
fs.aio-max-nr = 1048576
fs.file-max = 6815744
net.core.rmem_max = 4194304
net.core.rmem_default = 262144
net.core.wmem_max = 1048576
net.core.wmem_default = 262144
net.core.rmem_default = 262144
2021-11-19 08:36:05+00:00 Install Docker Engine
Loaded plugins: langpacks, ulninfo
ol7_MySQL80                                                                                                                                                           | 3.0 kB  00:00:00
...
...
ora.racnode2.vip
      1        ONLINE  ONLINE       racnode2                 STABLE
ora.scan1.vip
      1        ONLINE  ONLINE       racnode1                 STABLE
--------------------------------------------------------------------------------
2021-11-19 09:20:28+00:00 You can install sample schemas with the following command.
2021-11-19 09:20:28+00:00 ./install-sample.sh
2021-11-19 09:20:28+00:00 You can connect to Oracle RAC Database with the following command.
2021-11-19 09:20:28+00:00 ./sql.sh system/oracle@racnode-scan/ORCLCDB
```

### [install-sample.sh](install-sample.sh) ###

Install sample schemas.

```console
[opc@instance-20211119-1731 ~]$ ./install-sample.sh
~/db-sample-schemas-21.1 ~
~
Unable to find image 'container-registry.oracle.com/database/sqlcl:latest' locally
Trying to pull repository container-registry.oracle.com/database/sqlcl ...
latest: Pulling from container-registry.oracle.com/database/sqlcl
7627bfb99533: Pull complete
cb71b39cbb3d: Pull complete
0149c86271c9: Pull complete
Digest: sha256:012114d68e602db62c1ebcd00cb171373891c59f6235d9fff98ed50754c8bb95
Status: Downloaded newer image for container-registry.oracle.com/database/sqlcl:latest
...
...
SH       SUP_TEXT_IDX
SH       TIMES_PK                                    0           0

70 rows selected.

Disconnected from Oracle Database 21c Enterprise Edition Release 21.0.0.0.0 - Production
Version 21.3.0.0.0
[opc@instance-20211119-1731 ~]$
```

### [sql.sh](sql.sh) ###

Connect to CDB root and confirm the connection.

```console
[opc@instance-20211119-1731 ~]$ ./sql.sh system/oracle@racnode-scan/ORCLCDB


SQLcl: Release 21.3 Production on Fri Nov 19 09:52:11 2021

Copyright (c) 1982, 2021, Oracle.  All rights reserved.

Last Successful login time: Fri Nov 19 2021 09:52:12 +00:00

Connected to:
Oracle Database 21c Enterprise Edition Release 21.0.0.0.0 - Production
Version 21.3.0.0.0

SQL> SHOW CON_NAME
CON_NAME
------------------------------
CDB$ROOT
SQL> SELECT instance_name, host_name FROM v$instance;

   INSTANCE_NAME    HOST_NAME
________________ ____________
ORCLCDB1         racnode1

SQL> SELECT instance_name, host_name FROM gv$instance;

   INSTANCE_NAME    HOST_NAME
________________ ____________
ORCLCDB1         racnode1
ORCLCDB2         racnode2

SQL> exit
Disconnected from Oracle Database 21c Enterprise Edition Release 21.0.0.0.0 - Production
Version 21.3.0.0.0
[opc@instance-20211119-1731 ~]$
```

Connect to PDB and confirm the connection. If you have sample schemas installed, browse to the sample table.

```console
[opc@instance-20211119-1731 ~]$ ./sql.sh system/oracle@racnode-scan/ORCLPDB


SQLcl: Release 21.3 Production on Fri Nov 19 09:53:17 2021

Copyright (c) 1982, 2021, Oracle.  All rights reserved.

Last Successful login time: Fri Nov 19 2021 09:53:18 +00:00

Connected to:
Oracle Database 21c Enterprise Edition Release 21.0.0.0.0 - Production
Version 21.3.0.0.0

SQL> SHOW CON_NAME
CON_NAME
------------------------------
ORCLPDB
SQL> SELECT JSON_OBJECT(*) FROM hr.employees WHERE rownum <= 3;

                                                                                                                                                                                                                                JSON_OBJECT(*)
______________________________________________________________________________________________________________________________________________________________________________________________________________________________________________
{"EMPLOYEE_ID":100,"FIRST_NAME":"Steven","LAST_NAME":"King","EMAIL":"SKING","PHONE_NUMBER":"515.123.4567","HIRE_DATE":"2003-06-17T00:00:00","JOB_ID":"AD_PRES","SALARY":24000,"COMMISSION_PCT":null,"MANAGER_ID":null,"DEPARTMENT_ID":90}
{"EMPLOYEE_ID":101,"FIRST_NAME":"Neena","LAST_NAME":"Kochhar","EMAIL":"NKOCHHAR","PHONE_NUMBER":"515.123.4568","HIRE_DATE":"2005-09-21T00:00:00","JOB_ID":"AD_VP","SALARY":17000,"COMMISSION_PCT":null,"MANAGER_ID":100,"DEPARTMENT_ID":90}
{"EMPLOYEE_ID":102,"FIRST_NAME":"Lex","LAST_NAME":"De Haan","EMAIL":"LDEHAAN","PHONE_NUMBER":"515.123.4569","HIRE_DATE":"2001-01-13T00:00:00","JOB_ID":"AD_VP","SALARY":17000,"COMMISSION_PCT":null,"MANAGER_ID":100,"DEPARTMENT_ID":90}

SQL> exit
Disconnected from Oracle Database 21c Enterprise Edition Release 21.0.0.0.0 - Production
Version 21.3.0.0.0
[opc@instance-20211119-1731 ~]$
```

Reference Information
---------------------

* [Oracle Container Registry](https://container-registry.oracle.com/ords/f?p=113:1)
* [Oracle RAC Database on Container](https://github.com/oracle/docker-images/tree/main/OracleDatabase/RAC/OracleRealApplicationClusters)
* [Best Practices for Deploying Oracle RAC on Docker](https://www.oracle.com/technetwork/database/options/clustering/rac-ondocker-bp-wp-5458685.pdf)

Author
------

[Shinichi Akiyama](https://github.com/shakiyam)

License
-------

[MIT License](https://opensource.org/licenses/MIT)
