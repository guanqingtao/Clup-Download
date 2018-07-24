# 乘数Cluster for PostgreSQL用户手册

## 1. 功能与原理简介

### 1.1 功能

乘数Cluster for PostgreSQL软件在PostgreSQL数据库集群中实现了一种高可用及读写分离的解决方案。

clup可以管理多个主备流复制的集群，每个集群的使用场景为：

1. 有一个主库
2. 有多个Standby库，Standby库与主库通过streaming replication进行同步。streaming replication的同步模式可以设置为同步或异步。
3. 有一个write vip，这个write vip通常在主库所在的机器上。
4. 有一个read vip，read vip通常是在一台Standby库所在的机器上。
5. 应用如果需要执行写数据的操作，需要连接write vip，通过write vip访问主库。当然对于读延迟敏感的应用也需要通过write vip访问主库。应用可以通过访问read vip访问只读的备库。当有多个备库时，使用乘数科技的负载均衡软件cstlb，可以把读分发到多台的只读库上。
6. 当主库坏的时候，clup会自动把其中一台Standby库提升为主库，从而实现高可用。同时会通知负载均衡软件cstlb中把这台提升为主库的Standby库从负载均衡中去掉。
7. 当一台Standby库出现问题时，当read vip也在这台机器上时，clup会把read vip切换到另一台机器上。同时也会把这台Standby库从负载均衡cstlb中去掉。


## 2. 安装配置

### 2.1 安装要求

每台机器上需要安装arping包，因为此软件需要用到arping命令。

PostgreSQL的版本要求在9.5以上。


### 2.2 软件安装

本软件需要有一台独立的机器，配置不需要高，具体需求如下：

* X86服务器
* CPU PIII 800M以上
* 1G内存以上
* 硬盘20G以上

在本示例中，这台机器的主机名为clup，ip地址为：192.168.56.49

clup软件是安装在root用户下，也运行root用户下。

安装包主要有两个：

* clupX.Y.Z.tar.gz: 其中X.Y.Z是版本号，如1.0.0
* python3.6.tar.gz

把安装包clupX.Y.Z.tar.gz和python3.6.tar.gz解压到/opt目录下即可。

会形成以下目录：

```
/opt/clup1.X.X目录。
```

然后建软链接：

```
cd /opt
ln -sf clup1.0.0 clup
```


clupserver正常启动，需要license文件，这时需要把机器第一块网卡的mac地址上报给乘数科技，乘数科技会根据mac地址生成license文件，把生成的license文件cstech.lic拷贝到/opt/clup/conf目录下即可。

注意：上面的操作需要在每台机器上都执行。

为了方便运行命令，可以把/opt/clup/bin目录加入PATH环境变量中：

如在.bash_profile文件中添加：

```
PATH=$PATH:/opt/clup/bin
export PATH
```

在其中的两台备库上安装cstlb，cstlb安装包只有一个可执行程序cstlb，把cstlb程序拷贝到/opt/cstlb目录下即完成安装：

```
mkdir -p /opt/cstlb
cp cstlb /opt/cstlb
```


             
### 2.2 配置

#### 2.2.1 主机配置

每台机器上在/etc/hosts中添加主机名与ip地址的对应关系：

```
192.168.0.49 clup
192.168.0.41 pg01
192.168.0.42 pg02
192.168.0.43 pg03
192.168.0.44 pg04
```

上面的配置中“192.168.0.49 clup”是clup软件所安装的机器的主机名和IP地址，剩下的配置项是各台数据库的主机名和IP地址。

这样/etc/hosts的内容类似如下：

```
[root@pg01 ~]# cat /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6

192.168.0.49 clup
192.168.0.41 pg01
192.168.0.42 pg02
192.168.0.43 pg03
192.168.0.44 pg04
```

clup需要通过无需提供密码的ssh去操作各台数据库，所以需要打通clup机器以及各台数据库机器之间root用户的ssh通道，以便能用ssh连接各台机器而不需要密码，ssh自己也不需要密码。

其中一个简单的方法为：

在第一台机器上生成ssh的key:

```
ssh-keygen
```

运行的实际情况如下：

```
[root@clup ~]# ssh-keygen
Generating public/private rsa key pair.
Enter file in which to save the key (/root/.ssh/id_rsa):
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
Your identification has been saved in /root/.ssh/id_rsa.
Your public key has been saved in /root/.ssh/id_rsa.pub.
The key fingerprint is:
02:74:f1:34:f9:cb:47:da:ff:95:c3:78:ba:e6:37:1a root@pg04
The key's randomart image is:
+--[ RSA 2048]----+
|    . o.o.       |
|   . . o..       |
|    .   ..       |
|     .    . .    |
|      . S. =     |
|       .  + o o .|
|           . E =.|
|             .=oo|
|            o=+.o|
+-----------------+
```

然后进入.ssh目录下，把id_rsa.pub的内容添加到

```
cd .ssh
cat id_rsa.pub >> authorized_keys
chmod 600 authorized_keys
```

这时应该ssh自己应该不需要密码了：

```
[root@clup ~]# ssh 127.0.0.1
Last login: Sat Oct 28 15:06:03 2017 from 127.0.0.1
[root@clup ~]# exit
logout
Connection to 127.0.0.1 closed.
```

然后把这台机器的.ssh目录拷贝到所有的机器上：

```
[root@clup ~]# scp -r .ssh root@192.168.0.41:/root/.
root@192.168.0.42's password:
id_rsa                                                                                                                                       100% 1679     1.6KB/s   00:00
id_rsa.pub                                                                                                                                   100%  391     0.4KB/s   00:00
authorized_keys                                                                                                                              100% 1011     1.0KB/s   00:00
known_hosts
```

为了方便，用相同的方法把数据库用户postgres的ssh通道也打通。

还有其它的一些打通各台机器互相ssh不需要密码的方法可以参见网上的一些文章，这里就不在赘述了。

#### 2.2.2 配置数据库


首先需要把主备数据库搭建起来：

备库的recovery.conf文件的内容类似如下：

```
standby_mode = 'on'
recovery_target_timeline = 'latest'
primary_conninfo = 'application_name=stb42 user=postgres host=192.168.0.41 port=5432 password=postgres sslmode=disable sslcompression=1'
```

其中“primary_conninfo”中的：

* application_name=stb42,每台备库上这个都不能相同，可以用“stb”加上ip地址的最后一部分，如ip地址为192.168.0.42，就用stb42，这个名称需要与后面的init.json中“db_list”中的“repl_app_name”的值相同。
* “user=postgres password=postgres”需要与配置文件ha_adm.conf中的配置项db_repl_user和db_repl_pass保持相同。
* host=192.168.0.41 port=5432这是主库的IP地址和端口

主备库搭建好了，需要在主库上查询select * from pg_stat_replication;来确定备库都正常工作：

```
postgres@pg01:~/pgdata$ psql postgres
psql (9.6.2)
Type "help" for help.

postgres=# select * from pg_stat_replication;
  pid  | usesysid | usename  | application_name |  client_addr   | client_hostname | client_port |         backend_start         | backend_xmin |   state   | sent_location | w
rite_location | flush_location | replay_location | sync_priority | sync_state
-------+----------+----------+------------------+----------------+-----------------+-------------+-------------------------------+--------------+-----------+---------------+--
--------------+----------------+-----------------+---------------+------------
 25541 |       10 | postgres | stb42            | 192.168.0.42  |                 |       56529 | 2017-10-26 04:05:31.10155+08  |              | streaming | 0/1B018140    | 0
/1B018140     | 0/1B018140     | 0/1B018140      |             0 | async
 25573 |       10 | postgres | stb43            | 192.168.0.43  |                 |       48956 | 2017-10-26 04:05:36.088541+08 |              | streaming | 0/1B018140    | 0
/1B018140     | 0/1B018140     | 0/1B018140      |             0 | async
 25605 |       10 | postgres | stb44            | 192.168.0.44  |                 |       40505 | 2017-10-26 04:05:40.938398+08 |              | streaming | 0/1B018140    | 0
/1B018140     | 0/1B018140     | 0/1B018140      |             0 | async
(3 rows)
```


在主库中建探测库cs_sys_ha，注意此库的名称“cs_sys_ha”需要与clup.conf中的配置项probe_db_name的值保证一致（见后面clup.conf中的介绍 ）：

```
CREATE DATABASE cs_sys_ha;
```

然后在探测库cs_sys_ha中建探测表：

```
CREATE TABLE cs_sys_heartbeat(
  hb_time TIMESTAMP
);
insert into cs_sys_heartbeat values(now());
```

#### 2.2.3 乘数Cluster for PostgreSQL软件包的安装

把安装包clupX.Y.Z.tar.gz和python3.6.tar.gz解压到/opt目录下即完成安装。

检查python3.6是否能正常工作，如果报如下错误：

```
[root@pg01 opt]# ./python3.6/bin/python3.6
./python3.6/bin/python3.6: /lib64/libcrypto.so.10: version `OPENSSL_1.0.2' not found (required by ./python3.6/bin/python3.6)
```

这是因为openssl的版本太旧，查看版本：

```
[root@pg01 opt]# rpm -qa |grep ssl
openssl-1.0.2k-8.el7.x86_64
openssl-libs-1.0.2k-8.el7.x86_64
openssl-devel-1.0.2k-8.el7.x86_64
```

openssl版本应该是1.0.2.


如果不是上面的版本，请运行：

```
yum update
yum install openssl-devel
```


#### 2.2.4 乘数Cluster for PostgreSQL的配置


首先修改配置文件/opt/clup/conf/clup.conf

此配置文件的示例如下：

```
#格式为 key = value

# 网络地址，本cluster软件的内部通信将运行在此网络中
network=192.168.0.0

#管理工具与服务器之间通信的密码
ha_rpc_pass = csha_cluster_pass

probe_db_name = cs_sys_ha
probe_user = postgres
probe_password = postgres

ha_db_user = postgres
ha_db_pass = postgres

db_repl_user = postgres
db_repl_pass = postgres


# 检查数据库是否正常的周期，单位为秒
probe_interval = 10

# 锁的ttl时间，单位为秒
lock_ttl = 30

# http服务的token
http_token = 540cd628-d74e-11e7-992e-60f81dd129c2

# cstlb load balance的token
cstlb_token = 8e722522-d733-11e7-93e8-60f81dd129c2
```

配置文件说明：

* network=192.168.0.0：网络，通常为内部元数据服务用的网络，与业务网段可相同。
* ha_rpc_pass = csha_cluster_pass：管理工具与服务器之间通信的密码。
* probe_db_name = cs_sys_ha：通过探测更新此数据库中的一张表来判定此节点是否正常工作。
* probe_user = postgres ：通过更新cs_sys_ha中表探测更新时使用的数据库用户名。
* probe_password = postgres ：通过探测更新时使用的数据库用户密码。
* ha_db_user = postgres：此程序获得一些信息时使用的数据库用户名
* ha_db_pass = postgres：此程序获得一些信息时使用的数据库用户密码
* db_repl_user = postgres：主备数据库之间流复制使用的数据库用户名
* db_repl_pass = postgres：主备数据库之间流复制使用的数据库用户密码
* probe_interval = 30：探测数据库是否工作正常的周期
* lock_ttl：做一些特别的操作时（如故障切换），系统会持有一把锁，持有这把锁的最长时间
* http_token：访问clup的http接口所需要token
* cstlb_token：负载均衡器cstbl的token，当需要从cstlb中增加、删除后端的服务器等管理操作时，需要提供这个token

在每台机器上配置好上面的/opt/clup/conf/clup.conf文件。

#### 2.2.5 初使化集群


先编辑init.json文件，其中的一个示例文件如下：

```
{
    "cluster01": {
        "write_vip": "192.168.56.40",
        "read_vip": "192.168.56.45",
        "cstlb_list": [
            "192.168.56.43:8082",
            "192.168.56.44:8082"
        ],
        "state": 0,
        "lock_time": 0,
        "read_vip_host": "192.168.56.41",
        "db_list": [
            {
                "id": 1,
                "state": 1,
                "os_user": "postgres",
                "pgdata": "/home/postgres/pgdata",
                "is_primary": 1,
                "repl_app_name": "stb41",
                "host": "192.168.56.41",
                "switch_host": "192.168.56.41",
                "port": 5432
            },
            {
                "id": 2,
                "state": 1,
                "os_user": "postgres",
                "pgdata": "/home/postgres/pgdata",
                "is_primary": 0,
                "repl_app_name": "stb42",
                "host": "192.168.56.42",
                "switch_host": "192.168.56.42",
                "port": 5432
            },
            {
                "id": 3,
                "state": 1,
                "os_user": "postgres",
                "pgdata": "/home/postgres/pgdata",
                "is_primary": 0,
                "repl_app_name": "stb43",
                "host": "192.168.56.43",
                "switch_host": "192.168.56.43",
                "port": 5432
            },
            {
                "id": 4,
                "state": 1,
                "os_user": "postgres",
                "pgdata": "/home/postgres/pgdata",
                "is_primary": 0,
                "repl_app_name": "stb44",
                "host": "192.168.56.44",
                "switch_host": "192.168.56.44",
                "port": 5432
            }
        ]
    }
}
```

上面的配置项中，可以配置多个高可用集群，每个集群包括一台主库和多个备库。上面的配置项中配置了一个集群“cluster01”。

而每个集群的各个配置项说明如下：
* write_vip: 写vip
* read_vip: 读vip
* cstlb_list：在一个集群当有多个只读备库，读请求会负载均衡的发到各个只读备库上。而负载均衡器本身也需要高可用，所以会启动两个以上的负载均衡器，这个列表是负载均衡器的列表，其中列表中的端口是负载均衡器的管理端口，如本例中“192.168.56.41:8082”，管理端口为8082。当一台备库坏的时候，clup会向管理端口发送请求，让负载均衡器把这个坏的备库从自身的后台主机列表中删除掉。
* db_list: 为各个数据库的列表

db_list的配置项如下：

```
    "db_list":
    [
        {
            "id": 1,
            "state": 1,
            "os_user": "postgres",
            "pgdata": "/home/postgres/pgdata",
            "is_primary": 1,
            "vip": "192.168.0.45",
            "repl_app_name": "stb41",
            "host": "192.168.0.41",
            "switch_host": "192.168.0.41",
            "port": 5432
        },
```

上面这一段，表明各台机器上的数据库配置：

* “"id": 1”： 这是每台机器的序列，从1开始顺序+1递增
* “"state": 1”： 其中1表示正常工作，初使化时，应该设置为1
* “"os_user":"postgres"”：数据库实例是装在哪个操作系统用户下的，通常是在postgres用户下。
* “"pgdata": "/home/postgres/pgdata"”：设置数据库的数据目录
* “"is_primary": 1,”： 1表示主库，0表示备库，只能有一台机器是1，即是主库。
* “"repl_app_name": "stb232"”: 这需要与recovery.conf文件中的application_name保持一致，对于主库也需要设置一个，因为有主库有可能会切换成备库，这时就需要这个名称。
* “"host": "192.168.0.41",”：这台机器的ip地址。
* “"switch_host": "192.168.0.41"”：配置时需要与“"host"”保持相同。当这台机器故障时，“switch_host”指向替换这台机器的新机器的IP地址。
* “"port": 5432”：数据库的端口


配置好上面的文件之后，用以下命令初使化集群：

```
/opt/clup/bin/clupadm init
```


#### 2.2.4 启动集群软件

本软件是安装在一台单独的机器上，在这台单独的机器上启动：

```
/opt/clup/bin/clupserver start
```

这个clupserver就是探测故障的服务，当探测到故障时，就会执行高可用的切换工作。

如果部署clup的机器坏了之后，只需要在另一台机器上重新部署即可。


查看状态：

```
/opt/clup/bin/clupadm show

```

实际运行的效果如下：

```
(pyenv) [root@clup bin]# python clup_adm.py show
Clup v1.0.0  Copyright (c) 2017 HangZhou CSTech.Ltd. All rights reserved.
                   cluster list
==================================================
cluster_name   state       write_vip          read_vip       read_vip_host                  cstlb_list               
------------ --------- ----------------- ----------------- ----------------- ----------------------------------------
cluster01       Normal 192.168.56.40     192.168.56.45     192.168.56.41     ['192.168.56.41:8082', '192.168.56.42:8082']

                   db list
==================================================
cluster_name id   state    primary        host       port     switch_to      os_user               pgdata            
------------ -- ---------- ------- ----------------- ---- ----------------- ---------- ------------------------------
cluster01     1 Normal           0 192.168.56.41     5432 192.168.56.41     postgres   /home/postgres/pgdata         
cluster01     2 Normal           1 192.168.56.42     5432 192.168.56.42     postgres   /home/postgres/pgdata         
cluster01     3 Normal           0 192.168.56.43     5432 192.168.56.43     postgres   /home/postgres/pgdata         
cluster01     4 Normal           0 192.168.56.44     5432 192.168.56.44     postgres   /home/postgres/pgdata  
```

在两个备库上启动负载均衡器cstlb：

在pg03机器上：
```
[root@pg03 cstlb]# cd /opt/cstlb
[root@pg03 cstlb]# export CSTLB_TOKEN=540cd628-d74e-11e7-992e-60f81dd129c2 
[root@pg03 cstlb]# nohup ./cstlb --clup=http://192.168.56.49:8080/cluster01/get_lb_host 2>&1 >cstlb.log &
```

在pg04机器上：
```
[root@pg04 cstlb]# cd /opt/cstlb
[root@pg04 cstlb]# export CSTLB_TOKEN=540cd628-d74e-11e7-992e-60f81dd129c2 
[root@pg04 cstlb]# nohup ./cstlb --clup=http://192.168.56.49:8080/cluster01/get_lb_host 2>&1 >cstlb.log &
```

## 3. 使用

### 3.1 命令的基本使用方法

#### 3.1.1 集群服务命令

/opt/clup/bin/clupserver是乘数CSCluster for PostgreSQL软件的主程序。

启动命令：

正常启动时，直接运行命令“/opt/clup/bin/clupserver start”即可。

如果要以调试的模式运行，可以加上以下几个参数：

* -f: 前台运行，不进入daemon模式
* -l debug: 打印debug日志信息


用/opt/clup/bin/clupserver status可以查看集群软件是否运行：

```
(pyenv) [root@clup lib]# clupserver status
2017-12-08 08:58:39,817 INFO Clup v1.0.0  Copyright (c) 2017 HangZhou CSTech.Ltd. All rights reserved.
2017-12-08 08:58:39,817 INFO Start loading configuration ...
2017-12-08 08:58:39,818 INFO Complete configuration loading.
Program(332) is running.

```

运行/opt/clup/bin/clupserver stop可以停止集群软件的运行：

```
(pyenv) [root@clup lib]# clupserver stop
2017-12-08 08:59:11,450 INFO Clup v1.0.0  Copyright (c) 2017 HangZhou CSTech.Ltd. All rights reserved.
2017-12-08 08:59:11,450 INFO Start loading configuration ...
2017-12-08 08:59:11,450 INFO Complete configuration loading.
Wait 20 second for program stopped...
Wait 20 second for program stopped...
Wait 20 second for program stopped...
Program stopped.

```


### 3.1.2 clupadm程序的使用

clupadm是主要的管理工具，主要功能可以见下：

```
(pyenv) [root@clup lib]# clupadm
Clup v1.0.0  Copyright (c) 2017 HangZhou CSTech.Ltd. All rights reserved.
usage: clup_adm.py <command> [options]
    command can be one of the following:
      init            :  initialize cluster
      show            : list all database.
      get_last_lsn    : get all database lsn.
      repl_delay      : show replication delay.
      log             : display log.
      froze           : froze the HA.
      repair          : repair fault node.
      unfroze         : unfroze the HA.
      switch          : switch primary database to another node
      change_meta     : change cluster meta data, it is dangerous, be careful!!!
      get_meta        : get cluster meta info.
      show_task       : show task information.
      task_log        : show task log.

```

* init: 主是要在第一次初使化集群里使用，见前面。
* show: 展示集群中的节点信息。
* get_last_lsn：显示每个结点的最后的LSN号。
* repl_delay：显示各个备库的WAL日志的延迟情况。
* log：显示本机中clupserver的日志。
* froze: “冻结”cluster，当cluster进入此状态后，不会再做相应的检查工作，就象cluster停止工作了一样。
* unfroze: 解冻cluster
* switch: 把主库切换到另一台机器上。 
* repair: 修复一台已离线的节点
* get_meta: 显示集群配置的元数据，在一些特殊情况下使用，一般不使用。
* change_meta: 修改集群的元数据，只在一些特殊情况下使用，一般不使用。
* show_task: 一些长时间的操作如repair、switch都会是后台任务执行的，即使clupadm异常结束，这些后台任务仍然会继续执行，通过这个命令可以查看这些后台执行的任务。
* task_log: 查看长时间操作的后台任务的日志信息。


clupadm的命令的的正常运行，需要clupserver先运行了。


如果没有启动clupserver，会出现如错误：

```
(pyenv) [root@clup lib]# python clup_adm.py show
Clup v1.0.0  Copyright (c) 2017 HangZhou CSTech.Ltd. All rights reserved.
Can not connect clupserver: [Errno 111] Connection refused
```

下面展示一些命令的运行情况：


clupadm get_last_lsn的运行情况：


```
pyenv) [root@clup bin]# clup_adm -c cluster01
Clup v1.0.0  Copyright (c) 2017 HangZhou CSTech.Ltd. All rights reserved.
                   db list
--------------------------------------------------
id        host       primary timeline       lsn       
-- ----------------- ------- -------- ----------------
 1 192.168.56.41           0        9        0/30E73D0
 2 192.168.56.42           1        9        0/30E73D0
 3 192.168.56.43           0        9        0/30E73D0
 4 192.168.56.44           0        9        0/30E73D0

```

在上面的结果中可以看到每个数据库的时间线(timeline)。


clupadm repl_delay的运行情况：

```
(pyenv) [root@clup bin]#clupadm repl_delay -c cluster01
Clup v1.0.0  Copyright (c) 2017 HangZhou CSTech.Ltd. All rights reserved.
       host       primary current_lsn  sent_delay  write_delay  flush_delay  replay_delay   is_sync       state    
----------------- ------- ----------- ------------ ------------ ------------ ------------ ------------ ------------
192.168.56.41     0         0/30E8038            0            0            0          152        async       normal
192.168.56.42     1               N/A          N/A          N/A          N/A          N/A          N/A          N/A
192.168.56.43     0         0/30E8038            0            0            0          152        async       normal
192.168.56.44     0         0/30E8038            0            0            0          152        async       normal

```

上面结果中，如果是主库，这一行显示的都是“N/A”。列is_sync表示这个备库的流复制是同步方式还是异步方式。

需要注意“state”列，如果不是“normal”,通常表示流复制没有正常传输，如当备库与主库延迟过大，它需要的WAL文件在主库中已经被被清除掉，这时就不会显示“normal”状态。


clupadm log命令是显示clupserver上的日志，程序内部是通过“tail -f ”的方式显示，如果要退出，请按“Ctrl+C”：

```
pyenv) [root@clup bin]# clupadm log
Clup v1.0.0  Copyright (c) 2017 HangZhou CSTech.Ltd. All rights reserved.
tail -f /opt/clup/logs/clupserver.log
2017-12-08 09:07:40,136 INFO Clup v1.0.0  Copyright (c) 2017 HangZhou CSTech.Ltd. All rights reserved.
2017-12-08 09:07:40,137 INFO Start loading configuration ...
2017-12-08 09:07:40,137 INFO Complete configuration loading.
2017-12-08 09:07:40,516 INFO ========== 乘数Cluster for PostgreSQL starting ==========
2017-12-08 09:07:40,522 INFO Start ha checking thread... 
2017-12-08 09:07:40,525 INFO Start health checking thread... 
2017-12-08 09:07:40,533 INFO Complete the startup of health checking thread.
2017-12-08 09:07:40,536 INFO Starting web server...
2017-12-08 09:07:40,542 INFO Complete the startup of web server.
2017-12-08 09:07:40,557 INFO Web Server at port 8080 ...
```



### 3.2 故障的模拟以及恢复方法

#### 3.2.1 数据库宕掉，但主机还正常的情况

这时集群软件会检查到这个数据库出现了问题，但因为主机还是正常运行的，集群软件会自动把数据库拉起来，这种故障不需要人工参与。

当我们把一台数据库停掉：

```
[postgres@pg04 ~]$ pg_ctl stop
waiting for server to shut down.... done
server stopped
```

在log中可以看到类似“INFO Host(192.168.0.44) is ok, only database(192.168.0.44:5432) failed, restart database ....”的信息：

```
[root@pg01 ~]# clupadm log
2017-12-08 09:07:40,136 INFO Clup v1.0.0  Copyright (c) 2017 HangZhou CSTech.Ltd. All rights reserved.
...
....
2017-12-08 09:12:16,525 INFO Find database(192.168.56.44:5432) failed, repair it ....
2017-12-08 09:12:16,707 INFO Host(192.168.56.44) is ok, only database(192.168.56.44:5432) failed, restart database ....
```


我们再看数据库时，发现数据库已经自动拉起来了：

```
[postgres@pg04 pgdata]$ ps -ef|grep postgres
root       282   241  0 08:49 pts/4    00:00:00 su - postgres
postgres   283   282  0 08:49 pts/4    00:00:00 -bash
postgres   455     1  0 09:12 ?        00:00:00 /usr/pgsql-9.6/bin/postgres -D /home/postgres/pgdata
postgres   456   455  0 09:12 ?        00:00:00 postgres: logger process   
postgres   457   455  0 09:12 ?        00:00:00 postgres: startup process   recovering 000000090000000000000003
postgres   458   455  0 09:12 ?        00:00:00 postgres: checkpointer process   
postgres   459   455  0 09:12 ?        00:00:00 postgres: writer process   
postgres   460   455  0 09:12 ?        00:00:00 postgres: stats collector process   
postgres   461   455  0 09:12 ?        00:00:00 postgres: wal receiver process   streaming 0/30EB138
postgres   484   283  0 09:12 pts/4    00:00:00 ps -ef
postgres   485   283  0 09:12 pts/4    00:00:00 grep --color=auto postgres
```

#### 3.2.2 备库主机宕掉

这时集群软件会检查到这个备数据库出现了问题，同时也会发现主机也出问题了。集群软件会自动把这个数据库从负载均衡器中去掉，然后把结点标记为坏。

我们把一台备库重启来模拟这个故障：

在重启之前，我们先看一下负载均衡器的配置：


```
osdba-mac:~ osdba$ curl http://192.168.56.41:8082/backend/list?token=8e722522-d733-11e7-93e8-60f81dd129c2
{"192.168.56.41:5432":{"State":0,"NextAddress":"192.168.56.43:5432","PreAddress":"192.168.56.44:5432"},"192.168.56.43:5432":{"State":0,"NextAddress":"192.168.56.44:5432","PreAddress":"192.168.56.41:5432"},"192.168.56.44:5432":{"State":0,"NextAddress":"192.168.56.41:5432","PreAddress":"192.168.56.43:5432"}}
```
从上面可以看到，每台备库的IP地址都有。等后面我们重新pg04之后，会看到“192.168.0.44”这台机器从“read_cluser”中移除掉。

我们把pg04主机关掉：

```
[root@pg04 ~]# poweroff
Connection to 192.168.56.44 closed by remote host.
Connection to 192.168.56.44 closed.
```

这时我们在日志中可以看到如下信息：

```
017-12-08 09:12:16,525 INFO Find database(192.168.56.44:5432) failed, repair it ....
2017-12-08 09:12:16,707 INFO Host(192.168.56.44) is ok, only database(192.168.56.44:5432) failed, restart database ....
2017-12-08 09:15:54,522 INFO Find database(192.168.56.44:5432) failed, repair it ....
2017-12-08 09:15:59,555 INFO Host(192.168.56.44) is not ok, switch database(192.168.56.44:5432)...
2017-12-08 09:15:59,556 INFO Failover database(192.168.56.44:5432): switch to host(192.168.56.41).
2017-12-08 09:15:59,557 INFO Failover database(192.168.56.44:5432): begin remove bad host(192.168.56.44:5432) from cstlb ...
2017-12-08 09:15:59,569 INFO Failover database(192.168.56.44:5432): remove bad host(192.168.56.44:5432) from cstlb finished.
2017-12-08 09:15:59,569 INFO Failover database(192.168.56.44:5432): save node state to meta server...
2017-12-08 09:15:59,576 INFO Failover database(192.168.56.44:5432): save node state to meta server completed.
2017-12-08 09:15:59,577 INFO Failover database(192.168.56.44:5432): all commpleted.
```

同时我们用命令clupadm show命令也可以看到这个结点的变成了“Fault”：

```
                   cluster list
==================================================
cluster_name   state       write_vip          read_vip       read_vip_host                  cstlb_list               
------------ --------- ----------------- ----------------- ----------------- ----------------------------------------
cluster01       Normal 192.168.56.40     192.168.56.45     192.168.56.41     ['192.168.56.41:8082', '192.168.56.42:8082']

                   db list
==================================================
cluster_name id   state    primary        host       port     switch_to      os_user               pgdata            
------------ -- ---------- ------- ----------------- ---- ----------------- ---------- ------------------------------
cluster01     1 Normal           0 192.168.56.41     5432 192.168.56.41     postgres   /home/postgres/pgdata         
cluster01     2 Normal           1 192.168.56.42     5432 192.168.56.42     postgres   /home/postgres/pgdata         
cluster01     3 Normal           0 192.168.56.43     5432 192.168.56.43     postgres   /home/postgres/pgdata         
cluster01     4 Fault            0 192.168.56.44     5432 192.168.56.44     postgres   /home/postgres/pgdata          
```

注意上面最后一行中“state”状态从“Normal”已变成了“Fault”。

这时我们再看负载均衡器cstlb中配置，发现“192.168.0.44”这台机器的配置不见了：

```
{"192.168.56.41:5432":{"State":0,"NextAddress":"192.168.56.43:5432","PreAddress":"192.168.56.43:5432"},"192.168.56.43:5432":{"State":0,"NextAddress":"192.168.56.41:5432","PreAddress":"192.168.56.41:5432"}}
```


当这台机器恢复后，clup不会自动把这台数据库加进来，我们需要手工把备库启动起来：


```
[postgres@pg04 ~]$ pg_ctl start
server starting
[postgres@pg04 ~]$ < 2017-12-08 09:19:49.953 UTC > LOG:  redirecting log output to logging collector process
< 2017-12-08 09:19:49.953 UTC > HINT:  Future log output will appear in directory "pg_log".
```

完成上面操作之后，我们就可以用clupadm repair命令把这个节点重新加入集群中：

```
(pyenv) [root@clup bin]# clupadm repair -c cluster01 -i 4
Clup v1.0.0  Copyright (c) 2017 HangZhou CSTech.Ltd. All rights reserved.
taskid=13, task_name=repair cluster01(dbid=4)
2017-12-08 09:20:37:INFO: Repair(cluster=cluster01, dbid=4): begin get cluster lock...
2017-12-08 09:20:37:INFO: Repair(cluster=cluster01, dbid=4): begin...
2017-12-08 09:20:37:INFO: Repair(cluster=cluster01, dbid=4): find primary database ...
2017-12-08 09:20:37:INFO: Repair(cluster=cluster01, dbid=4): primary database: {'id': 2, 'state': 1, 'os_user': 'postgres', 'pgdata': '/home/postgres/pgdata', 'is_primary': 1, 'repl_app_name': 'stb42', 'host': '192.168.56.42', 'switch_host': '192.168.56.42', 'port': 5432}
2017-12-08 09:20:37:INFO: Repair(cluster=cluster01, dbid=4): find fault database ...
2017-12-08 09:20:37:INFO: Repair: fault database: {'id': 4, 'state': 2, 'os_user': 'postgres', 'pgdata': '/home/postgres/pgdata', 'is_primary': 0, 'repl_app_name': 'stb44', 'host': '192.168.56.44', 'switch_host': '192.168.56.44', 'port': 5432}
2017-12-08 09:20:37:INFO: Repair(cluster=cluster01, host=192.168.56.44): checking repair database replication steaming is ok...
2017-12-08 09:20:37:INFO: Repair(cluster=cluster01, host=192.168.56.44): create recovery.conf for this database...
2017-12-08 09:20:38:INFO: Repair(cluster=cluster01, host=192.168.56.44): create recovery.conf for this database completed
2017-12-08 09:20:38:INFO: Repair(cluster=cluster01, host=192.168.56.44): change fault database node to normal ...
2017-12-08 09:20:38:INFO: Repair(cluster=cluster01, host=192.168.56.44): all completed.  
```

上面的最后的命令clupadm show中可以看到此节点的状态又从“Fault”变回了“Normal”。

到负载均衡器中，可以看到此节点重新加回来了：

```
osdba-mac:~ osdba$ curl http://192.168.56.41:8082/backend/list?token=8e722522-d733-11e7-93e8-60f81dd129c2
{"192.168.56.41:5432":{"State":0,"NextAddress":"192.168.56.43:5432","PreAddress":"192.168.56.44:5432"},"192.168.56.43:5432":{"State":0,"NextAddress":"192.168.56.44:5432","PreAddress":"192.168.56.41:5432"},"192.168.56.44:5432":{"State":0,"NextAddress":"192.168.56.41:5432","PreAddress":"192.168.56.43:5432"}}
```


#### 3.2.3 主库主机宕掉

这时集群软件会检查到这个主数据库出现了问题，同时也会发现主机也出问题了。集群软件会从备库中挑选一台机器做为新主库。原主库标记为坏：

目前是192.168.0.42是主库，我们把这台机器停掉：

```
[root@pg02 ~]# poweroff
Connection to 192.168.56.42 closed by remote host.
Connection to 192.168.56.42 closed.
```

然后我们用clupadm show查看状态：


```
(pyenv) [root@clup lib]# clupadm show
Clup v1.0.0  Copyright (c) 2017 HangZhou CSTech.Ltd. All rights reserved.
                   cluster list
==================================================
cluster_name   state       write_vip          read_vip       read_vip_host                  cstlb_list               
------------ --------- ----------------- ----------------- ----------------- ----------------------------------------
cluster01       Normal 192.168.56.40     192.168.56.45     192.168.56.41     ['192.168.56.41:8082', '192.168.56.42:8082']

                   db list
==================================================
cluster_name id   state    primary        host       port     switch_to      os_user               pgdata            
------------ -- ---------- ------- ----------------- ---- ----------------- ---------- ------------------------------
cluster01     1 Normal           0 192.168.56.41     5432 192.168.56.41     postgres   /home/postgres/pgdata         
cluster01     2 Normal           1 192.168.56.42     5432 192.168.56.42     postgres   /home/postgres/pgdata         
cluster01     3 Normal           0 192.168.56.43     5432 192.168.56.43     postgres   /home/postgres/pgdata         
cluster01     4 Normal           0 192.168.56.44     5432 192.168.56.44     postgres   /home/postgres/pgdata

(pyenv) [root@clup lib]# clupadm show
Clup v1.0.0  Copyright (c) 2017 HangZhou CSTech.Ltd. All rights reserved.
                   cluster list
==================================================
cluster_name   state       write_vip          read_vip       read_vip_host                  cstlb_list               
------------ --------- ----------------- ----------------- ----------------- ----------------------------------------
cluster01       Normal 192.168.56.40     192.168.56.45     192.168.56.41     ['192.168.56.41:8082', '192.168.56.42:8082']

                   db list
==================================================
cluster_name id   state    primary        host       port     switch_to      os_user               pgdata            
------------ -- ---------- ------- ----------------- ---- ----------------- ---------- ------------------------------
cluster01     1 Normal           1 192.168.56.41     5432 192.168.56.41     postgres   /home/postgres/pgdata         
cluster01     2 Fault            0 192.168.56.42     5432 192.168.56.42     postgres   /home/postgres/pgdata         
cluster01     3 Normal           0 192.168.56.43     5432 192.168.56.43     postgres   /home/postgres/pgdata         
cluster01     4 Normal           0 192.168.56.44     5432 192.168.56.44     postgres   /home/postgres/pgdata  
```

同时在日志中也可以看到如下信息：

```
2017-12-08 10:39:58,929 INFO Find database(192.168.56.42:5432) failed, repair it ....
2017-12-08 10:40:01,943 INFO Host(192.168.56.42) is not ok, switch database(192.168.56.42:5432)...
2017-12-08 10:40:01,947 INFO Switch primary database(192.168.56.42:5432): begin delete write vip(192.168.56.40) ...
2017-12-08 10:40:05,021 INFO Switch primary database(192.168.56.42:5432): delete write vip(192.168.56.40) completed.
2017-12-08 10:40:05,914 INFO Failover primary database(192.168.56.42:5432): switch to new host(192.168.56.41)...
2017-12-08 10:40:05,922 INFO Failover primary database(192.168.56.42:5432): save node state to meta server completed.
...
....
2017-12-08 10:40:08,023 INFO Failover primary database(192.168.56.42:5432): change all standby database upper level primary database to host(192.168.56.41)...
2017-12-08 10:40:20,778 INFO Failover primary database(192.168.56.42:5432): change all standby database upper level primary database to host(192.168.56.41) completed.
2017-12-08 10:40:20,786 INFO Failover primary database(192.168.56.42:5432): Promote standby database(192.168.56.41) to primary...
2017-12-08 10:40:22,176 INFO Failover primary database(192.168.56.42:5432): Promote standby database(192.168.56.41) to primary completed.
2017-12-08 10:40:22,181 INFO Failover primary database(192.168.56.42:5432): switch to new host(192.168.56.41) completed.
```


这时在192.168.0.41上可以看到，写vip(192.168.0.40)也切换到这台机器上了：

```
[root@pg01 ~]# ip addr
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN qlen 1
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
8: eth0@if9: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP qlen 1000
    link/ether 00:16:3e:34:a1:9d brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 192.168.56.41/24 brd 192.168.56.255 scope global eth0
       valid_lft forever preferred_lft forever
    inet 192.168.56.45/32 scope global eth0
       valid_lft forever preferred_lft forever
    inet 192.168.56.40/32 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::216:3eff:fe34:a19d/64 scope link 
       valid_lft forever preferred_lft forever
```

等192.168.0.42机器恢复之后，这台机器想加入集群，只能做为备库加入了，这时我们需要在这台机器上重新搭建备库，如果没有搭建好备库，我们运行repair命令会有如下结果：


```
(pyenv) [root@clup lib]# python clup_adm.py repair -c cluster01 -i 2
Clup v1.0.0  Copyright (c) 2017 HangZhou CSTech.Ltd. All rights reserved.
taskid=14, task_name=repair cluster01(dbid=2)
2017-12-08 10:46:06:INFO: Repair(cluster=cluster01, dbid=2): begin get cluster lock...
...
...
2017-12-08 10:46:07:INFO: Repair(cluster=cluster01, host=192.168.56.42):  请在坏的节点上搭建好备库后，再重试:

搭建备库的命令如下:
pg_basebackup -D /home/postgres/pgdata -Upostgres -h 192.168.56.41 -p 5432 -x

recovery.conf的内容如下：
standby_mode = 'on'
recovery_target_timeline = 'latest'
primary_conninfo = 'application_name=stb42 user=postgres host=192.168.56.41 port=5432 password=****** sslmode=disable sslcompression=1'

```

通常我们不能把这个数据库直接转成备库，因为旧的主库是异常宕机，有可能超前原先的备库，这时如果我们添加recovery.conf，启动这个原主库时，发现无法与新主库建立流复制，同时会在数据库日志上看到如下日志：

```
[postgres@pg02 pg_log]$ tail -f postgresql-Sun.log
< 2017-10-29 20:58:57.088 CST > DETAIL:  End of WAL reached on timeline 1 at 0/B49CF78.
< 2017-10-29 20:58:57.089 CST > LOG:  new timeline 2 forked off current database system timeline 1 before current recovery point 0/B49CFE8
< 2017-10-29 20:59:02.067 CST > LOG:  restarted WAL streaming at 0/B000000 on timeline 1
< 2017-10-29 20:59:02.094 CST > LOG:  replication terminated by primary server
< 2017-10-29 20:59:02.094 CST > DETAIL:  End of WAL reached on timeline 1 at 0/B49CF78.
< 2017-10-29 20:59:02.095 CST > LOG:  new timeline 2 forked off current database system timeline 1 before current recovery point 0/B49CFE8
< 2017-10-29 20:59:07.072 CST > LOG:  restarted WAL streaming at 0/B000000 on timeline 1
< 2017-10-29 20:59:07.098 CST > LOG:  replication terminated by primary server
< 2017-10-29 20:59:07.098 CST > DETAIL:  End of WAL reached on timeline 1 at 0/B49CF78.
< 2017-10-29 20:59:07.099 CST > LOG:  new timeline 2 forked off current database system timeline 1 before current recovery point 0/B49CFE8
< 2017-10-29 20:59:12.075 CST > LOG:  restarted WAL streaming at 0/B000000 on timeline 1
< 2017-10-29 20:59:12.099 CST > LOG:  replication terminated by primary server
< 2017-10-29 20:59:12.099 CST > DETAIL:  End of WAL reached on timeline 1 at 0/B49CF78.
< 2017-10-29 20:59:12.100 CST > LOG:  new timeline 2 forked off current database system timeline 1 before current recovery point 0/B49CFE8
```

上面的信息中“new timeline X forked off current database system timeline Y before current recovery point 0/XXXXXXX”这样的信息，就表明这个新主库与旧主库走到了不同的分支上，旧主库不能再做为新主库的备库使用了。

同时用clupadm repl_delay命令看到这个节点的流复制的状态始终是“startup”，不能变成正常状态“normal”:

```
Clup v1.1.0  Copyright (c) 2017 HangZhou CSTech.Ltd. All rights reserved.
       host       primary current_lsn  sent_delay  write_delay  flush_delay  replay_delay   is_sync       state    
----------------- ------- ----------- ------------ ------------ ------------ ------------ ------------ ------------
192.168.0.41      1               N/A          N/A          N/A          N/A          N/A          N/A          N/A
192.168.0.42      0        0/D6707ED0        87192        87192        87080        87080        async      startup
192.168.0.43      0        0/D6707ED0            0            0            0          128        async       normal
192.168.0.44      0        0/D6707ED0            0            0            0          128        async       normal
```

这时可以尝试用pg_rewind把此旧主库转成standby，如果pg_rewind不行，只能在此机器上重新搭建备库了。

运行pg_rewind，这台旧数据库上的数据库不能启动，使用pg_rewind的命令如下：

```
[postgres@pg02 pg_log]$ pg_rewind --target-pgdata $PGDATA --source-server='host=192.168.0.41 port=5432 user=postgres dbname=template1 password=postgres' -P
connected to server
servers diverged at WAL position 0/B49CF78 on timeline 1
rewinding from last common checkpoint at 0/B49A850 on timeline 1
reading source file list
reading target file list
reading WAL in target
need to copy 151 MB (total source directory size is 187 MB)
155617/155617 kB (100%) copied
creating backup label and updating control file
syncing target data directory
initdb: could not stat file "/home/postgres/pgdata/postmaster.pid": No such file or directory
Done!
```

当在192.168.0.42上面搭建后备库后，我们就可以用repair命令重新把节点加入集群中：

```
(pyenv) [root@clup bin]# clupadm repair -c cluster01 -i 2
Clup v1.0.0  Copyright (c) 2017 HangZhou CSTech.Ltd. All rights reserved.
taskid=15, task_name=repair cluster01(dbid=2)
2017-12-08 10:54:51:INFO: Repair(cluster=cluster01, dbid=2): begin get cluster lock...
2017-12-08 10:54:51:INFO: Repair(cluster=cluster01, dbid=2): begin...
2017-12-08 10:54:51:INFO: Repair(cluster=cluster01, dbid=2): find primary database ...
2017-12-08 10:54:51:INFO: Repair(cluster=cluster01, dbid=2): primary database: {'id': 1, 'state': 1, 'os_user': 'postgres', 'pgdata': '/home/postgres/pgdata', 'is_primary': 1, 'repl_app_name': 'stb41', 'host': '192.168.56.41', 'switch_host': '192.168.56.41', 'port': 5432}
2017-12-08 10:54:51:INFO: Repair(cluster=cluster01, dbid=2): find fault database ...
2017-12-08 10:54:51:INFO: Repair: fault database: {'id': 2, 'state': 2, 'os_user': 'postgres', 'pgdata': '/home/postgres/pgdata', 'is_primary': 0, 'repl_app_name': 'stb42', 'host': '192.168.56.42', 'switch_host': '192.168.56.42', 'port': 5432}
2017-12-08 10:54:51:INFO: Repair(cluster=cluster01, host=192.168.56.42): checking repair database replication steaming is ok...
2017-12-08 10:54:51:INFO: Repair(cluster=cluster01, host=192.168.56.42): create recovery.conf for this database...
2017-12-08 10:54:52:INFO: Repair(cluster=cluster01, host=192.168.56.42): create recovery.conf for this database completed
2017-12-08 10:54:52:INFO: Repair(cluster=cluster01, host=192.168.56.42): change fault database node to normal ...
2017-12-08 10:54:52:ERROR: Can not remove host(192.168.56.42:5432) from cstlb(192.168.56.42:8082): <urlopen error [Errno 111] Connection refused>
2017-12-08 10:54:52:INFO: Repair(cluster=cluster01, host=192.168.56.42): all completed.

```

然后再用命令clupadm show看到节点的状态就变成“Normal”了：

```
(pyenv) [root@clup bin]# clupadm show
Clup v1.0.0  Copyright (c) 2017 HangZhou CSTech.Ltd. All rights reserved.
                   cluster list
==================================================
cluster_name   state       write_vip          read_vip       read_vip_host                  cstlb_list               
------------ --------- ----------------- ----------------- ----------------- ----------------------------------------
cluster01       Normal 192.168.56.40     192.168.56.45     192.168.56.41     ['192.168.56.41:8082', '192.168.56.42:8082']

                   db list
==================================================
cluster_name id   state    primary        host       port     switch_to      os_user               pgdata            
------------ -- ---------- ------- ----------------- ---- ----------------- ---------- ------------------------------
cluster01     1 Normal           1 192.168.56.41     5432 192.168.56.41     postgres   /home/postgres/pgdata         
cluster01     2 Normal           0 192.168.56.42     5432 192.168.56.42     postgres   /home/postgres/pgdata         
cluster01     3 Normal           0 192.168.56.43     5432 192.168.56.43     postgres   /home/postgres/pgdata         
cluster01     4 Normal           0 192.168.56.44     5432 192.168.56.44     postgres   /home/postgres/pgdata    
```

这样集群就恢复成正常状态。只是现在主库变成了192.168.0.42。


#### 3.2.4 人工切换主库

有时我们需求把主库切换到另一台机器上，这时可以用switch命令，如下所示：

```
clupadm switch -c cluster01 -i 2
```

上面的把主库切换到结点2。


### 3.3 注意事项

#### 3.2.1 recovery.conf的注意事项

当发生切换时，原主库会转换成备库，会自动生成一个recovery.conf文件覆盖原先的recovery.conf文件。所以不能在recovery.conf中添加一些自定义的内容，因为在每次切换后这些内容会被覆盖掉。


#### 3.2.2 主备库之间WAL落后太多，导致备库失效的问题

通常主库发生一次checkpoint点这后，这个checkpoint点之前的WAL日志会被删除掉，但这些日志如果还没有来得及传到备库，会导致备库失效掉。这导致发生故障时无法让备库成为主库。

解决办法是在数据库的配置文件postgresql.conf中设置：

```
max_wal_size = 8GB
min_wal_size = 6GB
```

保证min_wal_size有一定的大小。
