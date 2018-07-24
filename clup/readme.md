
### 1. 功能说明

乘数Cluster for PostgreSQL软件在PostgreSQL数据库集群中实现了一种读写分离及高可用的解决方案。

### 2. 编译及打包方法

此程序需要在python3.6下运行，所以需要先安装python3.6。在centos7.X下安装python3.6的方法如下：

1. 需要先安装依赖包：openssl-devel: ﻿yum -y install openssl-devel openssl-devel
2. 到https://www.python.org/ftp/python/3.6.3/下载相应的版本，如Python-3.6.3.tgz
3. 把压缩包Python-3.6.3.tgz解压到/usr/src目录下
4. 运行./configure --prefix=/opt/python3.6 --enable-optimizations
5. 支持make && make install

在做第4步之前，需要做以下操作，在python的源码目录中，修改vi Modules/Setup，把下面几行已注释掉的，把注释取消：

```
﻿_socket socketmodule.c timemodule.c
```

```
﻿_ssl _ssl.c \
-DUSE_SSL -I$(SSL)/include -I$(SSL)/include/openssl \
-L$(SSL)/lib -lssl -lcrypto
```

修改后的内容类似如下：

```
﻿# Socket module helper for socket(2)
_socket socketmodule.c timemodule.c
# Socket module helper for SSL support; you must comment out the other 
# socket line above, and possibly edit the SSL variable: 
#SSL=/usr/local/ssl
_ssl _ssl.c \
-DUSE_SSL -I$(SSL)/include -I$(SSL)/include/openssl \
-L$(SSL)/lib -lssl -lcrypto
```

否则后面用pip install依赖包时会报如下错误：

```
﻿[root@pg01 python3.6]# pip3 install psycopg2
pip is configured with locations that require TLS/SSL, however the ssl module in Python is not available.
Collecting psycopg2
  Could not fetch URL https://pypi.python.org/simple/psycopg2/: There was a problem confirming the ssl certificate: Can't connect to HTTPS URL because the SSL module is not available. - skipping
  Could not find a version that satisfies the requirement psycopg2 (from versions: )
No matching distribution found for psycopg2
```


做完上面的操作之后，就会把python3.6装到/opt目录下。

建立python虚拟环境：

```
mkdir -p /opt/clup/pyenv
/opt/python3.6/bin/python3.6 -m venv /opt/clup/pyenv
```

进入虚拟环境中，把相关依赖包安装到虚拟环境中：

```
source /opt/clup/pyenv/bin/activate
pip install -U pip
pip install psycopg2
```

实际的执行过程如下：

```
[root@pg01 opt]# source /opt/clup/pyenv/bin/activate
(pyenv) [root@pg01 opt]# pip install psycopg2 python-consul
Collecting psycopg2
  Using cached psycopg2-2.7.3.2-cp36-cp36m-manylinux1_x86_64.whl
Collecting python-consul
  Using cached python_consul-0.7.2-py2.py3-none-any.whl
Collecting six>=1.4 (from python-consul)
  Using cached six-1.11.0-py2.py3-none-any.whl
Collecting requests>=2.0 (from python-consul)
  Using cached requests-2.18.4-py2.py3-none-any.whl
Collecting idna<2.7,>=2.5 (from requests>=2.0->python-consul)
  Using cached idna-2.6-py2.py3-none-any.whl
Collecting urllib3<1.23,>=1.21.1 (from requests>=2.0->python-consul)
  Using cached urllib3-1.22-py2.py3-none-any.whl
Collecting certifi>=2017.4.17 (from requests>=2.0->python-consul)
  Using cached certifi-2017.7.27.1-py2.py3-none-any.whl
Collecting chardet<3.1.0,>=3.0.2 (from requests>=2.0->python-consul)
  Using cached chardet-3.0.4-py2.py3-none-any.whl
Installing collected packages: psycopg2, six, idna, urllib3, certifi, chardet, requests, python-consul
Successfully installed certifi-2017.7.27.1 chardet-3.0.4 idna-2.6 psycopg2-2.7.3.2 python-consul-0.7.2 requests-2.18.4 six-1.11.0 urllib3-1.22
```


安装乘数科技license依赖包，先把cs_checklic-1.0-py3.6.egg拷贝到一个目录下：

```
source /opt/clup/pyenv/bin/activate
easy_install cs_checklic-1.0-py3.6.egg
```


把我们的clup源代码也拷贝到/usr/src目录下，可以看到如下的文件目录情况：

```
(python3.6) [root@pg01 clup]# pwd
/usr/src/clup
(python3.6) [root@pg01 clup]# ls -l
total 8
-rwxr-xr-x 1 root root 1738 Oct 27 20:46 build.py
drwxr-xr-x 2 root root   50 Oct 27 20:46 doc
-rw-r--r-- 1 root root 1498 Oct 27 20:46 readme.md
drwxr-xr-x 8 root root  110 Oct 27 20:46 src
drwxr-xr-x 2 root root    6 Oct 27 20:46 target
```

然后在此目录下用python3.6运行源代码中的build.py，此操作会把.py文件编译成.pyc,然后放到target目录下：

```
cd /usr/src/clup
/opt/python3.6/bin/python3.6 build.py
```

实际运行的情况如下：

```
[root@pg01 ~]# cd /usr/src/clup
[root@pg01 clup]# /opt/python3.6/bin/python3.6 build.py
Delete all file and child directory in install...
Run: /bin/cp src/conf/* target/clup1.1.0/conf/.
Run: /bin/cp src/bin/* target/clup1.1.0/bin/.
```

这时在target目录下会生成类似clupX.Y.Z（其中的X.Y.Z是版本号，如1.1.0）的目录

把target目录下的clupX.Y.Z拷贝到/opt目录下：

```
cp -r /usr/src/clup/target/clup1.1.0 /opt/.
```

然后在/opt目录下建软链接clup到clupX.Y.Z：

```
cd /opt
ln -sf clup1.1.0 clup
```

把/opt目录下的包进行打包：

```
cd /opt
tar cvf clup1.1.0.tar clup1.1.0 clup
gzip -9 clup1.1.0.tar
```

把/opt目录下生成的clupX.Y.Z.tar.gz做为发布包即可。

同样把/opt目录下的python3.6打包成python3.6.tar.gz文件做为python3.6的发布包:


```
cd /opt
tar cvf python3.6.tar python3.6
gzip -9 python3.6.tar
```

### 3.安装

把安装包clupX.Y.Z.tar.gz和python3.6.tar.gz解压到/opt目录下即完成安装。

同时在操作系统下需要有arping命令，程序会用到。如果没有请安装。
在CentOS7.X下，arping命令在包iputils包中：
