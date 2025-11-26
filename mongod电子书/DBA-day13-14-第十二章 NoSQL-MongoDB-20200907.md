NoSQL-Mongodb核心技术(运维篇)

## 第一章：逻辑结构

Mongodb 逻辑结构             			 MySQL逻辑结构
库database									库
集合（collection）					   表
文档（document）					   数据行

选择之所以叫选择,肯定是痛苦的!

------->oldguo 

## 第二章：安装部署

### 1、系统准备

（1）redhat或cnetos6.2以上系统
（2）系统开发包完整
（3）ip地址和hosts文件解析正常
（4）iptables防火墙&SElinux关闭
（5）关闭大页内存机制
########################################################################
root用户下
在vi /etc/rc.local最后添加如下代码

```bash
if test -f /sys/kernel/mm/transparent_hugepage/enabled; then
  echo never > /sys/kernel/mm/transparent_hugepage/enabled
fi
if test -f /sys/kernel/mm/transparent_hugepage/defrag; then
   echo never > /sys/kernel/mm/transparent_hugepage/defrag
fi
		
echo never > /sys/kernel/mm/transparent_hugepage/enabled		
echo never > /sys/kernel/mm/transparent_hugepage/defrag	
```

其他系统关闭参照官方文档：

https://docs.mongodb.com/manual/tutorial/transparent-huge-pages/

为什么要关闭？
Transparent Huge Pages (THP) is a Linux memory management system 
that reduces the overhead of Translation Lookaside Buffer (TLB) 
lookups on machines with large amounts of memory by using larger memory pages.
However, database workloads often perform poorly with THP, 
because they tend to have sparse rather than contiguous memory access patterns. 
You should disable THP on Linux machines to ensure best performance with MongoDB.
############################################################################	

```bash
#修改配置文件
vim /etc/security/limits.conf

-- #*               -       nofile          65535
```



### 2、mongodb安装

（1）创建所需用户和组
useradd mongod
passwd mongod
（2）创建mongodb所需目录结构
	mkdir -p /mongodb/conf
	mkdir -p /mongodb/log
	mkdir -p /mongodb/data

（3）上传并解压软件到指定位置

上传到：
cd   /server/tools/
解压：
tar xf mongodb-linux-x86_64-rhel70-3.2.16.tgz

拷贝目录下bin程序到/mongodb/bin
cp -a /server/tools/mongodb-linux-x86_64-rhel70-3.2.16/bin/* /mongodb/bin

（4）设置目录结构权限

chown -R mongod:mongod /mongodb

（5）设置用户环境变量

```bash
su - mongod
vi .bash_profile
export PATH=/mongodb/bin:$PATH
source .bash_profile
```

（6）启动mongodb

```bash
su - mongod 
mongod --dbpath=/mongodb/data --logpath=/mongodb/log/mongodb.log --port=27017 --logappend --fork 
```

（7）登录mongodb
[mongod@server2 ~]$ mongo

注：连接之后会有warning，需要修改(使用root用户)

```bash
vim /etc/security/limits.conf 
#*       -       nofile       65535 
```

reboot重启生效

（8）使用配置文件

```bash
vim /mongodb/conf/mongodb.conf

logpath=/mongodb/log/mongodb.log
dbpath=/mongodb/data 
port=27017
logappend=true
fork=true
```




+++++++++++++++++++
关闭mongodb

```bash
mongod -f /mongodb/conf/mongodb.conf --shutdown
```

使用配置文件启动mongodb

```bash
mongod -f /mongodb/conf/mongodb.conf
```



### 3.mongod 配置文件

```yaml
（YAML模式：）

NOTE：
YAML does not support tab characters for indentation: use spaces instead.

--系统日志有关  

systemLog:
   destination: file        
   path: "/mongodb/log/mongodb.log"    --日志位置
   logAppend: true					   --日志以追加模式记录

--数据存储有关   
storage:
   journal:
      enabled: true
   dbPath: "/mongodb/data"            --数据路径的位置

-- 进程控制  
processManagement:
   fork: true                         --后台守护进程
   pidFilePath: <string>			  --pid文件的位置，一般不用配置，可以去掉这行，自动生成到data中
    
--网络配置有关   
net:			
--   bindIp: <ip>                       -- 监听地址，如果不配置这行是监听在0.0.0.0
   port: <port>						  -- 端口号,默认不配置端口号，是27017

-- 安全验证有关配置      
security:
  authorization: enabled              --是否打开用户名密码验证

------------------以下是复制集与分片集群有关----------------------  
replication:
 oplogSizeMB: <NUM>
 replSetName: "<REPSETNAME>"
 secondaryIndexPrefetch: "all"

sharding:
   clusterRole: <string>
   archiveMovedChunks: <boolean>
      
---for mongos only
replication:
   localPingThresholdMs: <int>

sharding:

####    configDB: <string>

.........
```


++++++++++++++++++++++
YAML例子

```yaml
cat > /mongodb/conf/mongo.conf <<EOF
systemLog:
   destination: file
   path: "/mongodb/log/mongodb.log"
   logAppend: true
storage:
   journal:
      enabled: true
   dbPath: "/mongodb/data/"
processManagement:
   fork: true
net:
   port: 27017
   bindIp: 10.0.0.51,127.0.0.1
EOF


mongod -f  /home/leju_zengwei2/mongdb_data/mongo.conf --shutdown
mongod -f /home/leju_zengwei2/mongdb_data/mongo.conf   
```



++++++++++++++++++++++

（9）mongodb的关闭方式

```bash
mongod -f mongodb.conf  --shutdown
```

(10) systemd 管理(root)

[root@db01 ~]# cat > /etc/systemd/system/mongod.service <<EOF
[Unit]
Description=mongodb 
After=network.target remote-fs.target nss-lookup.target
[Service]
User=leju_zengwei2
Type=forking
ExecStart=/home/leju_zengwei2/tools/mongodb4.2.9/bin/mongod --config /home/leju_zengwei2/mongdb_data/mongo.conf
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/home/leju_zengwei2/tools/mongodb4.2.9/bin/mongod --config /home/leju_zengwei2/mongdb_data/mongo.conf --shutdown
PrivateTmp=true  
[Install]
WantedBy=multi-user.target
EOF

[root@db01 ~]# systemctl restart mongod
[root@db01 ~]# systemctl stop mongod
[root@db01 ~]# systemctl start mongod

---------------------------------------

## 第三章常用基本操作

### 3.1基础命令

3.0  mongodb 默认存在的库

> show databases;
admin   0.000GB
config  0.000GB
local   0.000GB

3.1 命令种类

数据库对象(库(database),表(collection),行(document))

db.命令:
DB级别命令
db        当前在的库
db.[TAB]  类似于linux中的tab功能
db.help() db级别的命令使用帮助


collection级别操作:
db.Collection_name.xxx

document级别操作:
db.t1.insert()


复制集有关(replication set):
rs.

分片集群(sharding cluster)
sh.


3.2、帮助
help
KEYWORDS.help()
KEYWORDS.[TAB]

show 
use 
db.help()
db.a.help()
rs.help()
sh.help()

mongodb层面常用操作

--查看当前db版本
test> db.version()

--显示当前数据库

test> db
test
或
> db.getName()
test

--查询所有数据库
test> show dbs

– 切换数据库
> use local
switched to db local

- 查看所有的collection
show  tables;

– 显示当前数据库状态
test> use local
switched to db local

local> db.stats()

– 查看当前数据库的连接机器地址
> db.getMongo()
connection to 127.0.0.1
指定数据库进行连接
默认连接本机test数据库

------------------------------------------------
3.4、mongodb对象操作：

mongo         mysql
库    ----->  库
集合  ----->  表
文档  ----->  数据行


4.1 库的操作：

– 创建数据库：
当use的时候，系统就会自动创建一个数据库。
如果use之后没有创建任何集合。
系统就会删除这个数据库。

– 删除数据库
如果没有选择任何数据库，会删除默认的test数据库
//删除test数据库

test> show dbs
local 0.000GB
test 0.000GB

test> use test
switched to db test

test> db.dropDatabase()   
{ "dropped" : "test", "ok" : 1 }

集合的操作：
 创建集合
方法1
admin> use app
switched to db app
app> db.createCollection('a')
{ "ok" : 1 }
app> db.createCollection('b')
{ "ok" : 1 }

> show collections //查看当前数据下的所有集合
a b 或
> db.getCollectionNames()
[ "a", "b" ]


方法2：当插入一个文档的时候，一个集合就会自动创建。

{id : "101" ,name : "zhangsan" ,age : "18" ,gender : "male"}

use oldboy
db.aa.insert({id : "1021" ,name : "zhssn" ,age : "22" ,gender : "female",address : "sz"})

> db.oldguo.find({id:"101"})
{ "_id" : ObjectId("5d36b8b6e62adeeaf0de00dc"), "id" : "101", "name" : "zhangsan", "age" : "18", "gender" : "male" }


查询数据:
> db.oldguo.find({id:"101"}).pretty()
{
	"_id" : ObjectId("5d36b8b6e62adeeaf0de00dc"),
	"id" : "101",
	"name" : "zhangsan",
	"age" : "18",
	"gender" : "male"
}
> db.oldguo.find().pretty()
{
	"_id" : ObjectId("5d36b8b6e62adeeaf0de00dc"),
	"id" : "101",
	"name" : "zhangsan",
	"age" : "18",
	"gender" : "male"
}
{
	"_id" : ObjectId("5d36b8eae62adeeaf0de00dd"),
	"id" : "1021",
	"name" : "zhssn",
	"age" : "22",
	"gender" : "female",
	"address" : "sz"
}
{
	"_id" : ObjectId("5d36b913e62adeeaf0de00de"),
	"name" : "ls",
	"address" : "bj",
	"telnum" : "110"
}

删除集合
app> use app
switched to db app
app> db.log.drop() //删除集合

– 重命名集合
//把log改名为log1
app> db.log.renameCollection("log1")
{ "ok" : 1 }
app> show collections
a b c
log1
app

批量插入数据

for(i=0;i<100;i++){db.aa.insert({"uid":i,"name":"mongodb","age":6,"date":new
Date()})}


Mongodb数据查询语句:

– 查询集合中的记录数
app> db.log.find() //查询所有记录

注：默认每页显示20条记录，当显示不下的的情况下，可以用it迭代命令查询下一页数据。
设置每页显示数据的大小：

> DBQuery.shellBatchSize=50; //每页显示50条记录

app> db.log.findOne() //查看第1条记录
app> db.log.count() //查询总的记录数

– 删除集合中的记录数
app> db.log.remove({}) //删除集合中所有记录
> db.log.distinct("name") //查询去掉当前集合中某列的重复数据

– 查看集合存储信息
app> db.log.stats()
app> db.log.dataSize() //集合中数据的原始大小
app> db.log.totalIndexSize() //集合中索引数据的原始大小
app> db.log.totalSize() //集合中索引+数据压缩存储之后的大小    *****
app> db.log.storageSize() //集合中数据压缩存储的大小

### 3.2.用户管理 *****

注意：
验证库，建立用户时use到的库，在使用用户时，要加上验证库才能登陆。
对于管理员用户,必须在admin下创建.

1. 建用户时,use到的库,就是此用户的验证库
2. 登录时,必须明确指定验证库才能登录
3. 通常,管理员用的验证库是admin,普通用户的验证库一般是所管理的库设置为验证库
4. 如果直接登录到数据库,不进行use,默认的验证库是test,不是我们生产建议的.

use admin 
mongo 10.0.0.51/admin

db.createUser
{
    user: "<name>",
    pwd: "<cleartext password>",
    roles: [
       { role: "<role>",
     db: "<database>" } | "<role>",
    ...
    ]
}


基本语法说明：
user:用户名
pwd:密码
roles:
    role:角色名
    db:作用对象	
role：root, readWrite,read   

验证数据库：
mongo -u oldboy -p 123 10.0.0.51/oldboy

-------------
用户管理例子：

-- 1. 创建超级管理员：管理所有数据库（必须use admin再去创建） *****
$ mongo
use admin
db.createUser(
{   user: "root",
    pwd: "root123",
    roles: [ { role: "root", db: "admin" } ]
}
)

db.createUser(
{   user: "zengwei",
    pwd: "zengwei123",
    roles: [ { role: "root", db: "admin" } ]
}
)

验证用户
db.auth('root','root123')


配置文件中，加入以下配置
security:
  authorization: enabled

重启mongodb
mongod -f /home/leju_zengwei2/mongdb_data/mongo.conf --shutdown 
mongod -f /home/leju_zengwei2/mongdb_datamongo.conf 

登录验证
mongo -uroot -proot123  admin
mongo -uroot -proot123  10.208.0.125/admin

或者
mongo
use admin
db.auth('root','root123')

查看用户:
use admin
db.system.users.find().pretty()

==================
-- 2、创建库管理用户
mongo -uroot -proot123  admin

use app

db.createUser(
{
user: "admin",
pwd: "admin",
roles: [ { role: "dbAdmin", db: "app" } ]
}
)

db.auth('admin','admin')

登录测试
mongo -uadmin -padmin 10.0.0.51/app


-- 3、创建对app数据库，读、写权限的用户app01 *****

（1）超级管理员用户登陆
mongo -uroot -proot123 admin

（2）选择一个验证库
use app

(3)创建用户
db.createUser(
	{
		user: "app01",
		pwd: "app01",
		roles: [ { role: "readWrite" , db: "app" } ]
	}
)

mongo  -uapp01 -papp01 10.0.0.51/app

-- 4、创建app数据库读写权限的用户并对test数据库具有读权限：
mongo -uroot -proot123 10.0.0.51/admin
use app
db.createUser(
{
user: "app03",
pwd: "app03",
roles: [ { role: "readWrite", db: "app" },
{ role: "read", db: "test" }]})

-- 5、查询mongodb中的用户信息
mongo -uroot -proot123 10.0.0.51/admin
db.system.users.find().pretty()
{
	"_id" : "admin.root",
	"user" : "root",
	"db" : "admin",
	"credentials" : {
		"SCRAM-SHA-1" : {
			"iterationCount" : 10000,
			"salt" : "HsSHIKBQyMnFEzA/PSURYA==",
			"storedKey" : "dbOoQserGa/fB+JQyLqr1yXQZBM=",
			"serverKey" : "h+b/vARfWp6cmDquUN6bJo4whdc="
		}
	},
	"roles" : [
		{
			"role" : "root",
			"db" : "admin"
		}
	]
}


-- 6、删除用户（root身份登录，use到验证库）

删除用户

mongo -uroot -proot123 10.0.0.51/admin

use app
db.dropUser("app01")

---------------------------------
## 第四章：RS复制集

4.ongoDB复制集RS（ReplicationSet）******

### 4.1 基本原理

基本构成是1主2从的结构，自带互相监控投票机制（Raft（MongoDB）  Paxos（mysql MGR 用的是变种））
如果发生主库宕机，复制集内部会进行投票选举，选择一个新的主库替代原有主库对外提供服务。同时复制集会自动通知
客户端程序，主库已经发生切换了。应用就会连接到新的主库。

### 4.2简单的复制配置实例

4.2 Replication Set配置过程详解
4.2.1 规划
三个以上的mongodb节点（或多实例）
4.2.2 环境准备
多个端口：
28017、28018、28019、28020
多套目录：
su - mongod 
mkdir -p /mongodb/28017/conf /mongodb/28017/data /mongodb/28017/log
mkdir -p /mongodb/28018/conf /mongodb/28018/data /mongodb/28018/log
mkdir -p /mongodb/28019/conf /mongodb/28019/data /mongodb/28019/log
mkdir -p /mongodb/28020/conf /mongodb/28020/data /mongodb/28020/log

多套配置文件
/mongodb/28017/conf/mongod.conf
/mongodb/28018/conf/mongod.conf
/mongodb/28019/conf/mongod.conf
/mongodb/28020/conf/mongod.conf
配置文件内容:
cat > /mongodb/28017/conf/mongod.conf <<EOF
systemLog:
  destination: file
  path: /mongodb/28017/log/mongodb.log
  logAppend: true
storage:
  journal:
    enabled: true
  dbPath: /mongodb/28017/data
  directoryPerDB: true
  #engine: wiredTiger
  wiredTiger:
    engineConfig:
      cacheSizeGB: 1
      directoryForIndexes: true
    collectionConfig:
      blockCompressor: zlib
    indexConfig:
      prefixCompression: true
processManagement:
  fork: true
net:
  bindIp: 10.0.0.51,127.0.0.1
  port: 28017
replication:
  oplogSizeMB: 2048
  replSetName: my_repl
EOF
        
\cp  /mongodb/28017/conf/mongod.conf  /mongodb/28018/conf/
\cp  /mongodb/28017/conf/mongod.conf  /mongodb/28019/conf/
\cp  /mongodb/28017/conf/mongod.conf  /mongodb/28020/conf/

sed 's#28017#28018#g' /mongodb/28018/conf/mongod.conf -i
sed 's#28017#28019#g' /mongodb/28019/conf/mongod.conf -i
sed 's#28017#28020#g' /mongodb/28020/conf/mongod.conf -i

启动多个实例备用:
mongod -f /mongodb/28017/conf/mongod.conf
mongod -f /mongodb/28018/conf/mongod.conf
mongod -f /mongodb/28019/conf/mongod.conf
mongod -f /mongodb/28020/conf/mongod.conf

netstat -lnp|grep 280

### 4.3 带有特殊节点的复制集：

1主2从，从库普通从库

mongo --port 28017 admin
config = {_id: 'my_repl', members: [
                          {_id: 0, host: '10.0.0.51:28017'},
                          {_id: 1, host: '10.0.0.51:28018'},
                          {_id: 2, host: '10.0.0.51:28019'}]
          }    
		  
rs.initiate(config) 


查询复制集状态
rs.status();



4.4 1主1从1个arbiter

mongo -port 28017 admin
config = {_id: 'my_repl', members: [
                          {_id: 0, host: '10.0.0.51:28017'},
                          {_id: 1, host: '10.0.0.51:28018'},
                          {_id: 2, host: '10.0.0.51:28019',"arbiterOnly":true}]
          }                
rs.initiate(config) 

### 4.4 复制集管理操作

4.4.1 查看复制集状态
rs.status();    //查看整体复制集状态
rs.isMaster(); // 查看当前是否是主节点
rs.conf()；   //查看复制集配置信息

4.4.2 添加删除节点
rs.remove("ip:port"); // 删除一个节点
rs.add("ip:port"); // 新增从节点
rs.addArb("ip:port"); // 新增仲裁节点

例子：
添加 arbiter节点
1、连接到主节点
[mongod@db03 ~]$ mongo --port 28018 admin
2、添加仲裁节点
my_repl:PRIMARY> rs.addArb("10.0.0.53:28020")
3、查看节点状态
my_repl:PRIMARY> rs.isMaster()
{
    "hosts" : [
        "10.0.0.53:28017",
        "10.0.0.53:28018",
        "10.0.0.53:28019"
    ],
    "arbiters" : [
        "10.0.0.53:28020"
    ],

rs.remove("ip:port"); // 删除一个节点
例子：
my_repl:PRIMARY> rs.remove("10.0.0.53:28019");
{ "ok" : 1 }
my_repl:PRIMARY> rs.isMaster()
rs.add("ip:port"); // 新增从节点
例子：
my_repl:PRIMARY> rs.add("10.0.0.53:28019")
{ "ok" : 1 }
my_repl:PRIMARY> rs.isMaster()

#### 4.4.3 特殊从节点

介绍：
arbiter节点：主要负责选主过程中的投票，但是不存储任何数据，也不提供任何服务
hidden节点：隐藏节点，不参与选主，也不对外提供服务。
delay节点：延时节点，数据落后于主库一段时间，因为数据是延时的，也不应该提供服务或参与选主，所以通常会配合hidden（隐藏）
一般情况下会将delay+hidden一起配置使用
配置延时节点（一般延时节点也配置成hidden）
cfg=rs.conf() 
cfg.members[2].priority=0
cfg.members[2].hidden=true
cfg.members[2].slaveDelay=120
rs.reconfig(cfg)    

取消以上配置
cfg=rs.conf() 
cfg.members[2].priority=1
cfg.members[2].hidden=false
cfg.members[2].slaveDelay=0
rs.reconfig(cfg)    


配置成功后，通过以下命令查询配置后的属性
rs.conf(); 

6.5.4 副本集其他操作命令
查看副本集的配置信息
admin> rs.conf()
查看副本集各成员的状态
admin> rs.status()



### 复制集维护命令

```js
MongoDB副本集的常用操作及原理
https://www.yisu.com/zixun/6236.html
http://blog.itpub.net/29096438/viewspace-2155885/
https://www.huaweicloud.com/articles/d05605579b801aa91c560af399f0263e.html #日常维护命令


修改节点状态
主要包括：

将Primary节点降级为Secondary节点
冻结Secondary节点
强制Secondary节点进入维护模式
2. 修改副本集的配置

添加节点
删除节点
将Secondary节点设置为延迟备份节点
将Secondary节点设置为隐藏节点
替换当前的副本集成员
设置副本集节点的优先级
阻止Secondary节点升级为Primary节点
如何设置没有投票权的Secondary节点
禁用chainingAllowed
为Secondary节点显式指定复制源
禁止Secondary节点创建索引

首先查看MongoDB副本集支持的所有操作

rs.help()
rs.status() { replSetGetStatus : 1 } checks repl set status
rs.initiate() { replSetInitiate : null } initiates set with default settings
rs.initiate(cfg) { replSetInitiate : cfg } initiates set with configuration cfg
rs.conf() get the current configuration object from local.system.replset
rs.reconfig(cfg) updates the configuration of a running replica set with cfg (disconnects)
rs.add(hostportstr) add a new member to the set with default attributes (disconnects)
rs.add(membercfgobj) add a new member to the set with extra attributes (disconnects)
rs.addArb(hostportstr) add a new member which is arbiterOnly:true (disconnects)
rs.stepDown([stepdownSecs, catchUpSecs]) step down as primary (disconnects)
rs.syncFrom(hostportstr) make a secondary sync from the given member
rs.freeze(secs) make a node ineligible to become primary for the time specified
rs.remove(hostportstr) remove a host from the replica set (disconnects)
rs.slaveOk() allow queries on secondary nodes

rs.printReplicationInfo() check oplog size and time range
rs.printSlaveReplicationInfo() check replica set members and replication lag
db.isMaster() check who is primary

reconfiguration helpers disconnect from the database so the shell will display
an error, even if the command succeeds.
修改节点状态

将Primary节点降级为Secondary节点

share:PRIMARY> rs.stepDown()
这个命令会让primary降级为Secondary节点，并维持60s，如果这段时间内没有新的primary被选举出来，这个节点可以要求重新进行选举。
也可手动指定时间

share:PRIMARY> rs.stepDown(30)
在执行完该命令后，原Secondary node3:27017升级为Primary。
原Primary node3:27018降低为Secondary
冻结Secondary节点
如果需要对Primary做一下维护，但是不希望在维护的这段时间内将其它Secondary节点选举为Primary节点，可以在每次Secondary节点上执行freeze命令，强制使它们始终处于Secondary节点状态。

share:SECONDARY> rs.freeze(100)
注：只能在Secondary节点上执行

share:PRIMARY> rs.freeze(100)
{
"ok" : 0,
"errmsg" : "cannot freeze node when primary or running for election. state: Primary",
"code" : 95,
"codeName" : "NotSecondary"
}

如果要解冻Secondary节点，只需执行
share:SECONDARY> rs.freeze()
强制Secondary节点进入维护模式
当Secondary节点进入到维护模式后，它的状态即转化为“RECOVERING”，在这个状态的节点，客户端不会发送读请求给它，同时它也不能作为复制源。
进入维护模式有两种触发方式：
自动触发
譬如Secondary上执行压缩
手动触发
share:SECONDARY> db.adminCommand({"replSetMaintenance":true})
修改副本集的配置
添加节点
share:PRIMARY> rs.add("node3:27017")
share:PRIMARY> rs.add({_id: 3, host: "node3:27017", priority: 0, hidden: true})
也可通过配置文件的方式

cfg={
"_id" : 3,
"host" : "node3:27017",
"arbiterOnly" : false,
"buildIndexes" : true,
"hidden" : true,
"priority" : 0,
"tags" : {
},
"slaveDelay" : NumberLong(0),
"votes" : 1
}

rs.add(cfg)

删除节点

第一种方式

share:PRIMARY> rs.remove("node3:27017")
第二种方式

share:PRIMARY> cfg = rs.conf()
share:PRIMARY> cfg.members.splice(2,1)
share:PRIMARY> rs.reconfig(cfg)
注：执行rs.reconfig并不必然带来副本集的重新选举，加force参数同样如此。

The rs.reconfig() shell method can trigger the current primary to step down in some situations.

修改节点的配置

将Secondary节点设置为延迟备份节点

cfg = rs.conf()
cfg.members[1].priority = 0
cfg.members[1].hidden = true
cfg.members[1].slaveDelay = 3600
rs.reconfig(cfg)

将Secondary节点设置为隐藏节点

cfg = rs.conf()
cfg.members[0].priority = 0
cfg.members[0].hidden = true
rs.reconfig(cfg)

替换当前的副本集成员

cfg = rs.conf()
cfg.members[0].host = "mongo2.example.net"
rs.reconfig(cfg)

设置副本集节点的优先级

cfg = rs.conf()
cfg.members[0].priority = 0.5
cfg.members[1].priority = 2
cfg.members[2].priority = 2
rs.reconfig(cfg)
优先级的有效取值是0~1000，可为小数，默认为1

从MongoDB 3.2开始

Non-voting members must have priority of 0.
Members with priority greater than 0 cannot have 0 votes.
注：如果将当前Secondary节点的优先级设置的大于Primary节点的优先级，会导致当前Primary节点的退位。
阻止Secondary节点升级为Primary节点
只需将priority设置为0

fg = rs.conf()
cfg.members[2].priority = 0
rs.reconfig(cfg)

如何设置没有投票权的Secondary节点
MongoDB限制一个副本集最多只能拥有50个成员节点，其中，最多只有7个成员节点拥有投票权。
之所以作此限制，主要是考虑到心跳请求导致的网络流量，毕竟每个成员都要向其它所有成员发送心跳请求，和选举花费的时间。
从MongoDB 3.2开始，任何priority大于0的节点都不可将votes设置为0
所以，对于没有投票权的Secondary节点，votes和priority必须同时设置为0

cfg = rs.conf()
cfg.members[3].votes = 0
cfg.members[3].priority = 0
cfg.members[4].votes = 0
cfg.members[4].priority = 0
rs.reconfig(cfg)

禁用chainingAllowed
默认情况下，允许级联复制。
即备份集中如果新添加了一个节点，这个节点很可能是从其中一个Secondary节点处进行复制，而不是从Primary节点处复制。
MongoDB根据ping时间选择同步源，一个节点向另一个节点发送心跳请求，就可以得知心跳请求所耗费的时间。MongoDB维护着不同节点间心跳请求的平均花费时间，选择同步源时，会选择一个离自己比较近而且数据比自己新的节点。
如何判断节点是从哪个节点处进行复制的呢？
share:PRIMARY> rs.status().members[1].syncingTo
node3:27018
当然，级联复制也有显而易见的缺点：复制链越长，将写操作复制到所有Secondary节点所花费的时间就越长。

可通过如下方式禁用

cfg=rs.conf()
cfg.settings.chainingAllowed=false
rs.reconfig(cfg)
将chainingAllowed设置为false后，所有Secondary节点都会从Primary节点复制数据。
为Secondary节点显式指定复制源
rs.syncFrom("node3:27019")
禁止Secondary节点创建索引
有时，并不需要Secondary节点拥有和Primary节点相同的索引，譬如这个节点只是用来处理数据备份或者离线的批量任务。这个时候，就可以阻止Secondary节点创建索引。
在MongoDB 3.4版本中，不允许直接修改，只能在添加节点时显式指定
share:PRIMARY> cfg=rs.conf()
share:PRIMARY> cfg.members[2].buildIndexes=false
false
share:PRIMARY> rs.reconfig(cfg)
{
"ok" : 0,
"errmsg" : "priority must be 0 when buildIndexes=false",
"code" : 103,
"codeName" : "NewReplicaSetConfigurationIncompatible"
}
share:PRIMARY> cfg.members[2].buildIndexes=false
false
share:PRIMARY> cfg.members[2].priority=0
0
share:PRIMARY> rs.reconfig(cfg)
{
"ok" : 0,
"errmsg" : "New and old configurations differ in the setting of the buildIndexes field for member node3:27017; to make this c
hange, remove then re-add the member", "code" : 103,
"codeName" : "NewReplicaSetConfigurationIncompatible"
}
share:PRIMARY> rs.remove("node3:27017")
{ "ok" : 1 }
share:PRIMARY> rs.add({_id: 2, host: "node3:27017", priority: 0, buildIndexes:false})
{ "ok" : 1 }

从上述测试中可以看出，如果要将节点的buildIndexes设置为false，必须同时将priority设置为0。
```



++++++++++++++++++++++++++++++++++++++++++++++++

--副本集角色切换（不要人为随便操作）
admin> rs.stepDown()
注：
admin> rs.freeze(300) //锁定从，使其不会转变成主库
freeze()和stepDown单位都是秒。

+++++++++++++++++++++++++++++++++++++++++++++
设置副本节点可读：在副本节点执行
admin> rs.slaveOk()
eg：
admin> use app
switched to db app
app> db.createCollection('a')
{ "ok" : 0, "errmsg" : "not master", "code" : 10107 }

查看副本节点（监控主从延时）
admin> rs.printSlaveReplicationInfo()
source: 192.168.1.22:27017
    syncedTo: Thu May 26 2016 10:28:56 GMT+0800 (CST)
    0 secs (0 hrs) behind the primary

OPlog日志（备份恢复章节）

-----------------------
## 第五章.Sharding Cluster 分片

### 5.1 规划：

10个实例：38017-38026

（1）configserver:
3台构成的复制集（1主两从，不支持arbiter）38018-38020（复制集名字configsvr）

（2）shard节点：

sh1：38021-23    （1主两从，其中一个节点为arbiter，复制集名字sh1）
sh2：38024-26    （1主两从，其中一个节点为arbiter，复制集名字sh2）

### 5.2 分片配置过程

​			
shard复制集配置：

2.1目录创建：
mkdir -p /mongodb/38021/conf  /mongodb/38021/log  /mongodb/38021/data
mkdir -p /mongodb/38022/conf  /mongodb/38022/log  /mongodb/38022/data
mkdir -p /mongodb/38023/conf  /mongodb/38023/log  /mongodb/38023/data
mkdir -p /mongodb/38024/conf  /mongodb/38024/log  /mongodb/38024/data
mkdir -p /mongodb/38025/conf  /mongodb/38025/log  /mongodb/38025/data
mkdir -p /mongodb/38026/conf  /mongodb/38026/log  /mongodb/38026/data


2.2修改配置文件：

sh1:

cat > /mongodb/38021/conf/mongodb.conf<<EOF 
systemLog:
  destination: file
  path: /mongodb/38021/log/mongodb.log   
  logAppend: true
storage:
  journal:
    enabled: true
  dbPath: /mongodb/38021/data
  directoryPerDB: true
  #engine: wiredTiger
  wiredTiger:
    engineConfig:
      cacheSizeGB: 1
      directoryForIndexes: true
    collectionConfig:
      blockCompressor: zlib
    indexConfig:
      prefixCompression: true
net:
  bindIp: 10.0.0.51,127.0.0.1
  port: 38021
replication:
  oplogSizeMB: 2048
  replSetName: sh1
sharding:
  clusterRole: shardsvr
processManagement: 
  fork: true
EOF
cp  /mongodb/38021/conf/mongodb.conf  /mongodb/38022/conf/
cp  /mongodb/38021/conf/mongodb.conf  /mongodb/38023/conf/
sed 's#38021#38022#g' /mongodb/38022/conf/mongodb.conf -i
sed 's#38021#38023#g' /mongodb/38023/conf/mongodb.conf -i


sh2:
cat > /mongodb/38024/conf/mongodb.conf<<EOF 
systemLog:
  destination: file
  path: /mongodb/38024/log/mongodb.log   
  logAppend: true
storage:
  journal:
    enabled: true
  dbPath: /mongodb/38024/data
  directoryPerDB: true
  wiredTiger:
    engineConfig:
      cacheSizeGB: 1
      directoryForIndexes: true
    collectionConfig:
      blockCompressor: zlib
    indexConfig:
      prefixCompression: true
net:
  bindIp: 10.0.0.51,127.0.0.1
  port: 38024
replication:
  oplogSizeMB: 2048
  replSetName: sh2
sharding:
  clusterRole: shardsvr
processManagement: 
  fork: true
EOF

cp  /mongodb/38024/conf/mongodb.conf  /mongodb/38025/conf/
cp  /mongodb/38024/conf/mongodb.conf  /mongodb/38026/conf/
sed 's#38024#38025#g' /mongodb/38025/conf/mongodb.conf -i
sed 's#38024#38026#g' /mongodb/38026/conf/mongodb.conf -i


2.3启动所有节点，并搭建复制集：

mongod -f  /mongodb/38021/conf/mongodb.conf 
mongod -f  /mongodb/38022/conf/mongodb.conf 
mongod -f  /mongodb/38023/conf/mongodb.conf 
mongod -f  /mongodb/38024/conf/mongodb.conf 
mongod -f  /mongodb/38025/conf/mongodb.conf 
mongod -f  /mongodb/38026/conf/mongodb.conf  



mongo --port 38021 admin

config = {_id: 'sh1', members: [
                          {_id: 0, host: '10.0.0.51:38021'},
                          {_id: 1, host: '10.0.0.51:38022'},
                          {_id: 2, host: '10.0.0.51:38023',"arbiterOnly":true}]
           }

rs.initiate(config)


mongo --port 38024  admin
config = {_id: 'sh2', members: [
                          {_id: 0, host: '10.0.0.51:38024'},
                          {_id: 1, host: '10.0.0.51:38025'},
                          {_id: 2, host: '10.0.0.51:38026',"arbiterOnly":true}]
           }

rs.initiate(config)

=-=----=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
3、config节点配置：
3.1目录创建：
mkdir -p /mongodb/38018/conf  /mongodb/38018/log  /mongodb/38018/data
mkdir -p /mongodb/38019/conf  /mongodb/38019/log  /mongodb/38019/data
mkdir -p /mongodb/38020/conf  /mongodb/38020/log  /mongodb/38020/data

3.2修改配置文件：
cat > /mongodb/38018/conf/mongodb.conf <<EOF
systemLog:
  destination: file
  path: /mongodb/38018/log/mongodb.conf
  logAppend: true
storage:
  journal:
    enabled: true
  dbPath: /mongodb/38018/data
  directoryPerDB: true
  #engine: wiredTiger
  wiredTiger:
    engineConfig:
      cacheSizeGB: 1
      directoryForIndexes: true
    collectionConfig:
      blockCompressor: zlib
    indexConfig:
      prefixCompression: true
net:
  bindIp: 10.0.0.51,127.0.0.1
  port: 38018
replication:
  oplogSizeMB: 2048
  replSetName: configReplSet
sharding:
  clusterRole: configsvr
processManagement: 
  fork: true
EOF

cp /mongodb/38018/conf/mongodb.conf /mongodb/38019/conf/
cp /mongodb/38018/conf/mongodb.conf /mongodb/38020/conf/
sed 's#38018#38019#g' /mongodb/38019/conf/mongodb.conf -i
sed 's#38018#38020#g' /mongodb/38020/conf/mongodb.conf -i


3.3启动节点，并配置复制集

mongod -f /mongodb/38018/conf/mongodb.conf 
mongod -f /mongodb/38019/conf/mongodb.conf 
mongod -f /mongodb/38020/conf/mongodb.conf 

mongo --port 38018 admin
config = {_id: 'configReplSet', members: [
                          {_id: 0, host: '10.0.0.51:38018'},
                          {_id: 1, host: '10.0.0.51:38019'},
                          {_id: 2, host: '10.0.0.51:38020'}]
           }
rs.initiate(config)  


注：configserver 可以是一个节点，官方建议复制集。configserver不能有arbiter。
新版本中，要求必须是复制集。

注：mongodb 3.4之后，虽然要求config server为replica set，但是不支持arbiter

4、mongos节点配置：
4.1创建目录：
mkdir -p /mongodb/38017/conf  /mongodb/38017/log 

4.2配置文件：
cat >/mongodb/38017/conf/mongos.conf<<EOF
systemLog:
  destination: file
  path: /mongodb/38017/log/mongos.log
  logAppend: true
net:
  bindIp: 10.0.0.51,127.0.0.1
  port: 38017
sharding:
  configDB: configReplSet/10.0.0.51:38018,10.0.0.51:38019,10.0.0.51:38020
processManagement: 
  fork: true
EOF         
4.3启动mongos
mongos -f /mongodb/38017/conf/mongos.conf 


 5、分片集群操作：

连接到其中一个mongos（10.0.0.51），做以下配置
（1）连接到mongs的admin数据库

su - mongod

$ mongo 10.0.0.51:38017/admin
（2）添加分片
db.runCommand( { addshard : "sh1/10.0.0.51:38021,10.0.0.51:38022,10.0.0.51:38023",name:"shard1"} )
db.runCommand( { addshard : "sh2/10.0.0.51:38024,10.0.0.51:38025,10.0.0.51:38026",name:"shard2"} )

（3）列出分片
mongos> db.runCommand( { listshards : 1 } )

（4）整体状态查看
mongos> sh.status();

=================================

### 5.3使用分片集群

RANGE分片配置及测试

test库下的vast大表进行手工分片

1、激活数据库分片功能
mongo --port 38017 admin
admin>  ( { enablesharding : "数据库名称" } )

eg：
admin> db.runCommand( { enablesharding : "test" } )

2、指定分片建对集合分片
eg：范围片键
--创建索引
use test
> db.vast.ensureIndex( { id: 1 } )

--开启分片
use admin
> db.runCommand( { shardcollection : "test.vast",key : {id: 1} } )

3、集合分片验证
admin> use test
test> for(i=1;i<1000000;i++){ db.vast.insert({"id":i,"name":"shenzheng","age":70,"date":new Date()}); }
test> db.vast.stats()

4、分片结果测试

shard1:
mongo --port 38021
db.vast.count();

shard2:
mongo --port 38024
db.vast.count();

----------------------------------------------------
4、Hash分片例子：
对oldboy库下的vast大表进行hash
创建哈希索引
（1）对于oldboy开启分片功能
mongo --port 38017 admin
use admin
admin> db.runCommand( { enablesharding : "oldboy" } )

（2）对于oldboy库下的vast表建立hash索引
use oldboy
oldboy> db.vast.ensureIndex( { id: "hashed" } )


（3）开启分片 
use admin
admin > sh.shardCollection( "oldboy.vast", { id: "hashed" } )

（4）录入10w行数据测试
use oldboy
for(i=1;i<100000;i++){ db.vast.insert({"id":i,"name":"shenzheng","age":70,"date":new Date()}); }

（5）hash分片结果测试
mongo --port 38021
use oldboy
db.vast.count();

mongo --port 38024
use oldboy

db.vast.count();

5、判断是否Shard集群
admin> db.runCommand({ isdbgrid : 1})

6、列出所有分片信息
admin> db.runCommand({ listshards : 1})

7、列出开启分片的数据库
admin> use config

config> db.databases.find( { "partitioned": true } )
或者：
config> db.databases.find() //列出所有数据库分片情况

8、查看分片的片键
config> db.collections.find().pretty()
{
	"_id" : "test.vast",
	"lastmodEpoch" : ObjectId("58a599f19c898bbfb818b63c"),
	"lastmod" : ISODate("1970-02-19T17:02:47.296Z"),
	"dropped" : false,
	"key" : {
		"id" : 1
	},
	"unique" : false
}

9、查看分片的详细信息
admin> db.printShardingStatus()
或
admin> sh.status()   *****

10、删除分片节点（谨慎）
（1）确认blance是否在工作
sh.getBalancerState()
（2）删除shard2节点(谨慎)
mongos> db.runCommand( { removeShard: "shard2" } )
注意：删除操作一定会立即触发blancer。


11、balancer操作 *****

介绍：
mongos的一个重要功能，自动巡查所有shard节点上的chunk的情况，自动做chunk迁移。

什么时候工作？
1、自动运行，会检测系统不繁忙的时候做迁移
2、在做节点删除的时候，立即开始迁移工作
3、balancer只能在预设定的时间窗口内运行 *****

有需要时可以关闭和开启blancer（备份的时候）
mongos> sh.stopBalancer()
mongos> sh.startBalancer()

12、自定义 自动平衡进行的时间段
https://docs.mongodb.com/manual/tutorial/manage-sharded-cluster-balancer/#schedule-the-balancing-window
// connect to mongos

 mongo --port 38017 admin
use config
sh.setBalancerState( true )
db.settings.update({ _id : "balancer" }, { $set : { activeWindow : { start : "3:00", stop : "5:00" } } }, true )

sh.getBalancerWindow()
sh.status()

关于集合的balancer（了解下）
关闭某个集合的balance
sh.disableBalancing("students.grades")
打开某个集合的balancer
sh.enableBalancing("students.grades")
确定某个集合的balance是开启或者关闭

db.getSiblingDB("config").collections.findOne({_id : "students.grades"}).noBalance;

## 第六章：备份恢复 

### 6.1 备份工具介绍

1、备份恢复工具介绍：
（1）**   mongoexport/mongoimport
（2）***** mongodump/mongorestore

2、备份工具区别在哪里？
2.1.	
mongoexport/mongoimport  导入/导出的是JSON格式或者CSV格式
mongodump/mongorestore   导入/导出的是BSON格式。
		
2.2. JSON可读性强但体积较大，BSON则是二进制文件，体积小但对人类几乎没有可读性。

2.3.	在一些mongodb版本之间，BSON格式可能会随版本不同而有所不同，所以不同版本之间用mongodump/mongorestore可能不会成功，具体要看版本之间的兼容性。当无法使用BSON进行跨版本的数据迁移的时候，
使用JSON格式即mongoexport/mongoimport是一个可选项。
跨版本的mongodump/mongorestore个人并不推荐，实在要做请先检查文档看两个版本是否兼容（大部分时候是的）	
2.4.	JSON虽然具有较好的跨版本通用性，但其只保留了数据部分，不保留索引，账户等其他基础信息。使用时应该注意。


应用场景总结:
mongoexport/mongoimport:json csv 
1、异构平台迁移  mysql  <---> mongodb
2、同平台，跨大版本：mongodb 2  ----> mongodb 3

mongodump/mongorestore
日常备份恢复时使用.



### 6.2 导出工具mongoexport

Mongodb中的mongoexport工具可以把一个collection导出成JSON格式或CSV格式的文件。
可以通过参数指定导出的数据项，也可以根据指定的条件导出数据。
（1）版本差异较大
（2）异构平台数据迁移

mongoexport具体用法如下所示：

$ mongoexport --help  
参数说明：
-h:指明数据库宿主机的IP
-u:指明数据库的用户名
-p:指明数据库的密码
-d:指明数据库的名字
-c:指明collection的名字
-f:指明要导出那些列
-o:指明到要导出的文件名
-q:指明导出数据的过滤条件
--authenticationDatabase admin


1.单表备份至json格式
mongoexport -uroot -proot123 --port 27017 --authenticationDatabase admin -d oldboy -c log -o /mongodb/log.json

注：备份文件的名字可以自定义，默认导出了JSON格式的数据。

2. 单表备份至csv格式
如果我们需要导出CSV格式的数据，则需要使用----type=csv参数：

 mongoexport -uroot -proot123 --port 27017 --authenticationDatabase admin -d oldboy -c log --type=csv -f uid,name,age,date  -o /mongodb/log.csv

 

### 6.3 导入工具mongoimport

Mongodb中的mongoimport工具可以把一个特定格式文件中的内容导入到指定的collection中。该工具可以导入JSON格式数据，也可以导入CSV格式数据。具体使用如下所示：
$ mongoimport --help
参数说明：
-h:指明数据库宿主机的IP
-u:指明数据库的用户名
-p:指明数据库的密码
-d:指明数据库的名字
-c:指明collection的名字
-f:指明要导入那些列
-j, --numInsertionWorkers=<number>  number of insert operations to run concurrently                                                  (defaults to 1)
//并行

### 6.4 数据恢复:

1.恢复json格式表数据到log1

mongoimport -uroot -proot123 --port 27017 --authenticationDatabase admin -d oldboy -c log1 /mongodb/log.json


2.恢复csv格式的文件到log2
上面演示的是导入JSON格式的文件中的内容，如果要导入CSV格式文件中的内容，则需要通过--type参数指定导入格式，具体如下所示：
错误的恢复

注意：
（1）csv格式的文件头行，有列名字
mongoimport   -uroot -proot123 --port 27017 --authenticationDatabase admin   -d oldboy -c log2 --type=csv --headerline --file  /mongodb/log.csv

（2）csv格式的文件头行，没有列名字
mongoimport   -uroot -proot123 --port 27017 --authenticationDatabase admin   -d oldboy -c log3 --type=csv -f id,name,age,date --file  /mongodb/log1.csv

--headerline:指明第一行是列名，不需要导入。


-----异构平台迁移案例
mysql   -----> mongodb  
world数据库下city表进行导出，导入到mongodb

（1）mysql开启安全路径

vim /etc/my.cnf   --->添加以下配置
secure-file-priv=/tmp

--重启数据库生效
/etc/init.d/mysqld restart

（2）导出mysql的city表数据
source /root/world.sql

select * from world.city into outfile '/tmp/city1.csv' fields terminated by ',';

（3）处理备份文件
desc world.city
  ID          | int(11)  | NO   | PRI | NULL    | auto_increment |
| Name        | char(35) | NO   |     |         |                |
| CountryCode | char(3)  | NO   | MUL |         |                |
| District    | char(20) | NO   |     |         |                |
| Population

vim /tmp/city.csv   ----> 添加第一行列名信息

ID,Name,CountryCode,District,Population

(4)在mongodb中导入备份
mongoimport -uroot -proot123 --port 27017 --authenticationDatabase admin -d world  -c city --type=csv -f ID,Name,CountryCode,District,Population --file  /tmp/city1.csv

use world
db.city.find({CountryCode:"CHN"});

-------------
world共100张表，全部迁移到mongodb

select * from world.city into outfile '/tmp/world_city.csv' fields terminated by ',';

select concat("select * from ",table_schema,".",table_name ," into outfile '/tmp/",table_schema,"_",table_name,".csv' fields terminated by ',';")
from information_schema.tables where table_schema ='world';

导入：
    提示，使用infomation_schema.columns + information_schema.tables

------------

mysql导出csv：
select * from test_info   
into outfile '/tmp/test.csv'   
fields terminated by ','　　　 ------字段间以,号分隔
optionally enclosed by '"'　　 ------字段用"号括起
escaped by '"'   　　　　　　  ------字段中使用的转义符为"
lines terminated by '\r\n';　　------行以\r\n结束


mysql导入csv：
load data infile '/tmp/test.csv'   

into table test_info    

fields terminated by ','  

optionally enclosed by '"' 

escaped by '"'   

lines terminated by '\r\n'; 


----------------------------------
6. 3 mongodump和mongorestore介绍

mongodump能够在Mongodb运行时进行备份，它的工作原理是对运行的Mongodb做查询，然后将所有查到的文档写入磁盘。但是存在的问题时使用mongodump产生的备份不一定是数据库的实时快照，如果我们在备份时对数据库进行了写入操作，则备份出来的文件可能不完全和Mongodb实时数据相等。另外在备份时可能会对其它客户端性能产生不利的影响。

##### 6.4.2 mongodump用法

$ mongodump --help
参数说明：
-h:指明数据库宿主机的IP
-u:指明数据库的用户名
-p:指明数据库的密码
-d:指明数据库的名字
-c:指明collection的名字
-o:指明到要导出的文件名
-q:指明导出数据的过滤条件
-j, --numParallelCollections=  number of collections to dump in parallel (4 by default)
--oplog  备份的同时备份oplog

6.5、mongodump和mongorestore基本使用
5.0 全库备份

mkdir /mongodb/backup
mongodump  -uroot -proot123 --port 27017 --authenticationDatabase admin -o /mongodb/backup

5.1--备份world库
$ mongodump   -uroot -proot123 --port 27017 --authenticationDatabase admin -d world -o /mongodb/backup/

5.2--备份oldboy库下的log集合
$ mongodump   -uroot -proot123 --port 27017 --authenticationDatabase admin -d oldboy -c log -o /mongodb/backup/

5.3 --压缩备份
$ mongodump   -uroot -proot123 --port 27017 --authenticationDatabase admin -d oldguo -o /mongodb/backup/ --gzip
 mongodump   -uroot -proot123 --port 27017 --authenticationDatabase admin -o /mongodb/backup/ --gzip
$ mongodump   -uroot -proot123 --port 27017 --authenticationDatabase admin -d app -c vast -o /mongodb/backup/ --gzip

5.4--恢复world库
$ mongorestore   -uroot -proot123 --port 27017 --authenticationDatabase admin -d world1  /mongodb/backup/world

5.5--恢复oldguo库下的t1集合
[mongod@db03 oldboy]$ mongorestore   -uroot -proot123 --port 27017 --authenticationDatabase admin -d world -c t1  --gzip  /mongodb/backup.bak/oldboy/log1.bson.gz 

5.6 --drop表示恢复的时候把之前的集合drop掉(危险)
$ mongorestore  -uroot -proot123 --port 27017 --authenticationDatabase admin -d oldboy --drop  /mongodb/backup/oldboy

*****6、mongodump和mongorestore高级企业应用（--oplog）

注意：这是replica set或者master/slave模式专用

--oplog
 use oplog for taking a point-in-time snapshot

6.1 oplog介绍

在replica set中oplog是一个定容集合（capped collection），它的默认大小是磁盘空间的5%（可以通过--oplogSizeMB参数修改）.

位于local库的db.oplog.rs，有兴趣可以看看里面到底有些什么内容。
其中记录的是整个mongod实例一段时间内数据库的所有变更（插入/更新/删除）操作。
当空间用完时新记录自动覆盖最老的记录。
其覆盖范围被称作oplog时间窗口。需要注意的是，因为oplog是一个定容集合，
所以时间窗口能覆盖的范围会因为你单位时间内的更新次数不同而变化。
想要查看当前的oplog时间窗口预计值，可以使用以下命令：


 mongod -f /mongodb/28017/conf/mongod.conf 
 mongod -f /mongodb/28018/conf/mongod.conf 
 mongod -f /mongodb/28019/conf/mongod.conf 
 mongod -f /mongodb/28020/conf/mongod.conf 


 use local 
 db.oplog.rs.find().pretty()

 	"ts" : Timestamp(1553597844, 1),
 	"op" : "n"
 	"o"  :
 	
 	"i": insert
 	"u": update
 	"d": delete
 	"c": db cmd

------------
test:PRIMARY> rs.printReplicationInfo()
configured oplog size:   1561.5615234375MB <--集合大小
log length start to end: 423849secs (117.74hrs) <--预计窗口覆盖时间
oplog first event time:  Wed Sep 09 2015 17:39:50 GMT+0800 (CST)
oplog last event time:   Mon Sep 14 2015 15:23:59 GMT+0800 (CST)
now:                     Mon Sep 14 2015 16:37:30 GMT+0800 (CST)


------------
### 6.5 oplog 应用

6.2、oplog企业级应用
（1）实现热备，在备份时使用--oplog选项
注：为了演示效果我们在备份过程，模拟数据插入
（2）准备测试数据
use oldboy
for(var i = 1 ;i < 100; i++) {
    db.foo.insert({a:i});
}

my_repl:PRIMARY> db.oplog.rs.find({"op":"i"}).pretty()

oplog 配合mongodump实现热备
mongodump --port 28017 --oplog -o /mongodb/backup
作用介绍：--oplog 会记录备份过程中的数据变化。会以oplog.bson保存下来

恢复
mongorestore  --port 28017 --oplogReplay /mongodb/backup



!!!!!!!!!!oplog高级应用  ==========binlog应用

背景：每天0点全备，oplog恢复窗口为48小时
某天，上午10点world.city 业务表被误删除。

恢复思路：
	0、停应用
	2、找测试库
	3、恢复昨天晚上全备
	4、截取全备之后到world.city误删除时间点的oplog，并恢复到测试库
	5、将误删除表导出，恢复到生产库


--------------
恢复步骤：
模拟故障环境：


1、全备数据库

模拟原始数据

mongo --port 28017
use wo
for(var i = 1 ;i < 20; i++) {
    db.ci.insert({a: i});
}

全备:


rm -rf /mongodb/backup/*

mongodump --port 28017 --oplog -o /mongodb/backup

--oplog功能:在备份同时,将备份过程中产生的日志进行备份

文件必须存放在/mongodb/backup下,自动命令为oplog.bson

再次模拟数据

db.ci1.insert({id:1})
db.ci2.insert({id:2})


2、上午10点：删除wo库下的ci表
10:00时刻,误删除

db.ci.drop()
show tables;

3、备份现有的oplog.rs表
mongodump --port 28017 -d local -c oplog.rs  -o /mongodb/backup

4、截取oplog并恢复到drop之前的位置
更合理的方法：登陆到原数据库
[mongod@db03 local]$ mongo --port 28017
my_repl:PRIMARY> use local
db.oplog.rs.find({op:"c"}).pretty();

{
	"ts" : Timestamp(1553659908, 1),
	"t" : NumberLong(2),
	"h" : NumberLong("-7439981700218302504"),
	"v" : 2,
	"op" : "c",
	"ns" : "wo.$cmd",
	"ui" : UUID("db70fa45-edde-4945-ade3-747224745725"),
	"wall" : ISODate("2019-03-27T04:11:48.890Z"),
	"o" : {
		"drop" : "ci"
	}
}

"ts" : Timestamp(1563958129, 1),

获取到oplog误删除时间点位置:
"ts" : Timestamp(1553659908, 1)
	
 5、恢复备份+应用oplog
[mongod@db03 backup]$ cd /mongodb/backup/local/
[mongod@db03 local]$ ls
oplog.rs.bson  oplog.rs.metadata.json
[mongod@db03 local]$ cp oplog.rs.bson ../oplog.bson 
rm -rf /mongodb/backup/local/
mongorestore --port 28018  --oplogReplay --oplogLimit "1563958129:1"  --drop   /mongodb/backup/


-----------------------------------------
### 6.6 集群分配备份

**分片集群的备份思路（了解）

1、你要备份什么？
config server
shard 节点

单独进行备份
2、备份有什么困难和问题
（1）chunk迁移的问题
	人为控制在备份的时候，避开迁移的时间窗口
（2）shard节点之间的数据不在同一时间点。
	选业务量较少的时候		
		
Ops Manager 






​	

# 第七章监控

### 一、复制集状态查看



![](https://img-blog.csdn.net/20160827144532966)



**复制集状态查询命令**
 ①.复制集状态查询：rs.status()
 ②.查看oplog状态： rs.printReplicationInfo()
 ③.查看复制延迟： rs.printSlaveReplicationInfo()
 ④.查看服务状态详情:  db.serverStatus()

1).rs.status()
 self:只会出现在执行rs.status()命令的成员里
 uptime:从本节点 网络可达到当前所经历的时间
 lastHeartbeat：当前服务器最后一次收到其心中的时间
 Optime & optimeDate:命令发出时oplog所记录的操作时间戳
 pingMs: 网络延迟
 syncingTo: 复制源
 stateStr:
  可提供服务的状态：primary, secondary, arbiter
  即将提供服务的状态：startup, startup2, recovering
  不可提供服务状态：down,unknow,removed,rollback,fatal

2).rs.printReplicationInfo()
 log length start to end: 当oplog写满时可以理解为时间窗口
 oplog last event time: 最后一个操作发生的时间

3).rs.printSlaveReplicationInfo()
 复制进度：synedTo
 落后主库的时间：X secs(X hrs)behind the primary

4).db.serverStatus()
 可以使用如下命令查找需要用到的信息
 db.serverStatus.opcounterRepl
 db.serverStatus.repl

**5).常用监控项目：**
 QPS: 每秒查询数量
 I/O: 读写性能
 Memory: 内存使用
 Connections: 连接数
 Page Faults: 缺页中断
 Index hit: 索引命中率
 Bakground flush: 后台刷新
 Queue: 队列

### 二、复制集常用监控工具

**1).mongostat**
 -h, --host  主机名或 主机名：端口
 --port   端口号
 -u ,--uername 用户名（验证）
 -p ,--password  密码（验证）
 --authenticationDatabase  从哪个库进行验证
 --discover  发现集群某个其他节点



```sql
changwen@ubuntu:~$ mongostat -h 192.168.23.129:28001
changwen@ubuntu:~$ mongostat -h 192.168.23.129:28001  --discover
```

![img](https://img-blog.csdn.net/20160901214116276)
**mongostat重点关注的字段**
 getmore 大量的排序操作在进行
 faults  需要的数据不在内存中
 locked db 锁比例最高的库
 index miss 索引未命中
 qr|qw  读写产生队列，供求失衡
**2).mongostop：与mongostat基本一样**
 -h, --host  主机名或 主机名：端口
 --port   端口号
 -u ,--uername 用户名（验证）
 -p ,--password  密码（验证）
 --authenticationDatabase  从哪个库进行验证
**3).mongosniff--复制集有抓包工具**



```sql
changwen@ubuntu:/usr/local/mongoDB/bin$ sudo ./mongosniff --help
 
```

4).ZABBIX--抓包工具





# mongod权威指南笔记

## 第二章



### 基础操作

创建db

use db 之后在这个db下创建表就是创建db了，没有创建表就会自动删除这个空db

创建表

 db.createCollection('t1'); #表名需要引号

删除表

db.tablename.drop()

删除数据

db.ablename.reme(quie,)



### 特殊的库

mongod自带三个库，也是系统库

admin库  #管理员库，只有在此库下创建的用户才是管理员

local 库 #本地库oplog存放地，不会被复制到别的库是哪个，只存放与本地库，system开头

config 库 # 存放分片配置信息的库。



集合：就是mysql里面的表，但是他的集合是没有固定列的，可以随时添加列。



集合的特点--无模式

意思就是集合是没有表头的，但是mysql表必须是有表头，相同的表头，结合可以一行数据和另外一行数据列数都不一样。



固定集合capped

也就是固定这个集合的大小，如果数据到达指定大小，插入数据时候会删除旧的数据，写入新的数据。



capped属性特点

1、对固定结婚插入数度极快。

2、按照插入顺序的查询输出速速极快。

3、能够在插入最新数据时候，淘汰最早的数据。

4、可以插入和更新，但是更新量不能超过固定的大小。

5、不能删除数据，但是可以对整个集合进行dorp

6、固定集合大小在32为机器上是482.5M，64位机器上大小受物理机器限制。



capped应用场景

1、存储日志信息

2 、缓存一些少量的文档



文档的特点

每个文档都有一个特殊的建 _id

文档中的键值对是有序的，前后位置不同就是不同的文档。

文档的键值对区分大小写。

文档的键值对不能用重复的键。



### mongod的数据类型

![image-20210508144422259](https://cdn.jsdelivr.net/gh/zengqingwei/img/20210508144431.png)





![image-20210508144518152](https://cdn.jsdelivr.net/gh/zengqingwei/img/20210508144522.png)







![image-20210508144635479](https://cdn.jsdelivr.net/gh/zengqingwei/img/20210508144638.png)







数值类型：

如果通过mongod的shell存入DB的都是64为浮点型。

如果通过java等语言存入数值到mongod db数值可以是32或者64位的整型或者浮点型。



mongod存储的基本单位是bson文档对象，字段值可以是二进制类型，也就是说mongod可以存储图片，视频，文件资料，到那时有一个限制，因为bson对象目前位置最大不能超过16mb随意只能存储小文件。



### 索引



索引可以是单列索引，也可以是多列索引，可以创建普通索引，也可以创建唯一索引。



地理空间索引



gridfs   为了解决只能存储16m大小文件的限制退出gridfs技术。



GridFs是将一种大型文件存储在MongoDB数据库中的文件规范，所以MongoDB官方支持的语言java，php等驱动均实现了gridfs规范，都可以实现将大型文件保存到MongoDB中。



GridFS原理：将大文件按照规范来分割成多个的bson小文件，也就是分割成16mb带下的文件。



![image-20210508151754642](https://cdn.jsdelivr.net/gh/zengqingwei/img/20210508151759.png)



### 复制集

理论上复制集可以有无数个从节点，但是多个从节点访问主节点，性能会受到影响，12个从库是一个临界点。

主节点只会输出数据，不会去从从节点拿数据。



为了解决主从复制不能自动切换选举的缺点，副本集才出现，他是优化的主从复制，可以自动进行主库故障后自动选举新主，其余从库切换到新主上面形成一个高可用集群。



MongoDB的投票需要超过半数的节点数投票给他，才能成为新的主库。



副本集的特点：

![image-20210508153207701](https://cdn.jsdelivr.net/gh/zengqingwei/img/20210508153959.png)



副本集实现是通过oplog 操作日志完成。

因为只有主节点能写入，从节点只要监控oplog就可以了。



oplog默认大小，32位系统是50M ，64位操作系统是剩余磁盘的5%。



每个oplog都有时间戳，



阻塞复制：

就是从节点应用oplog速度太慢，无法跟上主节点时候，主节点等待从节点应用过程就是阻塞，也可以让从节点从新全量同步一次，如果数据量大，全量同步需要很长时间，所以要把oplog设置尽量大点。



心跳机制，从节点每2秒ping一次其他所有成员。



避免脑裂：

如果一个复制集中，一下失去多个从几点，那么主节点必须降级为从节点，这个时候集群只能读不能写，因为没有主节点，这样设计是位了避免集群时区主节点后，其余的从节点选举了新的主节点，等网络恢复后，这样复制集就有两个主库了，就形成了脑裂了，所以主节点时区多个从节点时候，要降级，这样，从节点重新加入复制集要么只有一个主节点，要么从新选举主节点。



几点选举机制：

会根据节点的优先级和bully算法（判断谁的数据最新）选举出主节点。在选举主节点之前，整个集群只能是只读。



![image-20210508154707573](https://cdn.jsdelivr.net/gh/zengqingwei/img/20210508154711.png)



选举过程：

![image-20210508154758963](https://cdn.jsdelivr.net/gh/zengqingwei/img/20210508154759.png)



优先级如果影响选举



![image-20210508155010432](https://cdn.jsdelivr.net/gh/zengqingwei/img/20210508161015.png)



数据回滚：

![image-20210508161002050](https://cdn.jsdelivr.net/gh/zengqingwei/img/20210508161002.png)





mongod分片



支持三种：



区间分片

哈希分片

标签分片：给数据打不同的标签，根据标签进行分片。



![](https://cdn.jsdelivr.net/gh/zengqingwei/img/20210508161908.png)



## mongod安装



早期版本有32位系统的版本mongod后来3.2版本后就只有64位版本的mongod安装包了。



![image-20210508162420721](https://cdn.jsdelivr.net/gh/zengqingwei/img/20210508162421.png)





启动方式 mongod --dbpath=/mongod/data --fork 

--fork表示后台daemon方式运行。



## mongod启动参数



```bash
一、Mongodb启动命令参数说明
   Mongodb的启动命令可以使用  mongod –help查看所有选项
   mongod的主要参数有：

  1.基本参数

--quiet

# 安静输出

--port arg

# 指定服务端口号，默认端口27017

--bind_ip arg

# 绑定服务IP，若绑定127.0.0.1，则只能本机访问，不指定默认本地所有IP

--logpath arg

# 指定MongoDB日志文件，注意是指定文件不是目录

--logappend

# 使用追加的方式写日志

--pidfilepath arg

# PID File 的完整路径，如果没有设置，则没有PID文件

--keyFile arg

# 集群的私钥的完整路径，只对于Replica Set 架构有效

--unixSocketPrefix arg

# UNIX域套接字替代目录,(默认为 /tmp)

--fork

# 以守护进程的方式运行MongoDB，创建服务器进程

--auth

# 启用验证

--cpu

# 定期显示CPU的CPU利用率和iowait

--dbpath arg

# 指定数据库路径

--diaglog arg

# diaglog选项 0=off 1=W 2=R 3=both 7=W+some reads

--directoryperdb

# 设置每个数据库将被保存在一个单独的目录

--journal

# 启用日志选项，MongoDB的数据操作将会写入到journal文件夹的文件里

--journalOptions arg

# 启用日志诊断选项

--ipv6

# 启用IPv6选项

--jsonp

# 允许JSONP形式通过HTTP访问（有安全影响）

--maxConns arg

# 最大同时连接数 默认2000

--noauth

# 不启用验证

--nohttpinterface

# 关闭http接口，默认关闭27018端口访问

--noprealloc

# 禁用数据文件预分配(往往影响性能)

--noscripting

# 禁用脚本引擎

--notablescan

# 不允许表扫描

--nounixsocket

# 禁用Unix套接字监听

--nssize arg (=16)

# 设置信数据库.ns文件大小(MB)

--objcheck

# 在收到客户数据,检查的有效性，

--profile arg

# 档案参数 0=off 1=slow, 2=all

--quota

# 限制每个数据库的文件数，设置默认为8

--quotaFiles arg

# number of files allower per db, requires --quota

--rest

# 开启简单的rest API

--repair

# 修复所有数据库run repair on all dbs

--repairpath arg

# 修复库生成的文件的目录,默认为目录名称dbpath

--slowms arg (=100)

# value of slow for profile and console log

--smallfiles

# 使用较小的默认文件

--syncdelay arg (=60)

# 数据写入磁盘的时间秒数(0=never,不推荐)

--sysinfo

# 打印一些诊断系统信息

--upgrade

# 如果需要升级数据库


2.Replicaton

--fastsync

# 从一个dbpath里启用从库复制服务，该dbpath的数据库是主库的快照，可用于快速启用同步

--autoresync

# 如果从库与主库同步数据差得多，自动重新同步，

--oplogSize arg

# 设置oplog的大小(MB)


3.主/从参数

--master

# 主库模式

--slave

# 从库模式

--source arg

# 从库 端口号

--only arg

# 指定单一的数据库复制

--slavedelay arg

# 设置从库同步主库的延迟时间


4.Replica set(副本集)选项

--replSet arg

# 设置副本集名称


5.Sharding(分片)选项

--configsvr

# 声明这是一个集群的config服务,默认端口27019，默认目录/data/configdb

--shardsvr

# 声明这是一个集群的分片,默认端口27018

--noMoveParanoia

# 关闭偏执为moveChunk数据保存


ps上述参数都可以写入 mongod.conf 配置文档里例如：
dbpath = /data/mongodb
logpath = /data/mongodb/mongodb.log
logappend = true
port = 27017
fork = true
auth = true

 

 

二、启动
   
mongod --dbpath  /home/user1/mongodb/data  --logpath  /home/user1/mongodb/log/logs  --fork
     mongo服务启动必须要指定文件存放的目录dbpath,--fork以守护进程运行，如果带—fork参数则必须要指定—logpath即日志存放的位置（指定文件不是文件夹）

     当然也可以加其他的参数，比如--auth，也是非常常用的

 
三、停止Mongodb服务
   方法一：查看进程并kill           

ps aux|grep mongod      
kill -9 pid
   方法二：在客户端中使用shutdown命令
 

use admin      
db.shutdownServer()

参考：https://www.cnblogs.com/wyt007/p/8627805.html
原文链接：https://blog.csdn.net/skh2015java/article/details/83545609
```

mongod 指定配置文件启动

mongod -f /etc/mongod.cnf 或者mongod --config



## 关闭mongod服务器

方法1.

进入mongod 后

use admin;  

db.shutdownServer();



方法2 

kill -2 pid

2表示处理完最后一个事物关闭。



方法3

mongod -f /etc/mongd.f --shutdown  和方法2类似。



## mongod非正常关机





非正常关机有个mongod.lock文件，首先要删除该文件才能启动mongodb。这个文件会记录异常信息



删除lock文件后，如果有损坏的文件需要使用命令进行修复下

```sql
mongod --repair命令。	
```

修复过程是：将所有文档导出后，马上导入，忽略无效的文档，完成后会重建索引。



## mongod常用命令

### 日常操作命令

```js
//查看命令提示
db.help();

show dbs;

db.dropdatabase() //删除当前数据库

//从指定主机上克隆数据库,如果当前是text库，就会克隆11.10的text库。
db.cloneDatabase("10.204.11.10")

//从10.2的mydb复制数据到本机的temp库下,复制DB数据
db.copyDatabase("mydb","temp","192.168.10.2")

//修复当前数据库,需要临时磁盘空间，会回收整理碎片，
//会有锁表情况，线上很少用，都是关闭应用后才使用。
db.repairdatabase();

db.getName()；或 db  //查看当前db

db.stats(); //显示当前db状态

db.version() //当前db版本

my_repl:PRIMARY> db.getMongo()  //查看当前链接到那个MongoDB
connection to 127.0.0.1:28018

db.getPrevError() //查看之前的错误信息。

db.resetError() //清除错误记录。

db.createCollection("tablename") //创建一个新结合

db.createCollection("log",{size:20,capped:true,max:100});
//创建一个表，固定大小，的表 size表示空间，默认无限制，max表示数据条数。
//上面size的优先级比max高，先到了就限制。

//显示当前的集合,下面两个都可以。
my_repl:PRIMARY> show collections;
my_repl:PRIMARY> db.getCollectionNames()

db.mycoll或者db.getCollection("mycoll")
//使用集合,如果集合名称全是数字，必须使用第二种，第一种会报错。

//查看集合级别的帮助文档
db.mycoll.help()

//查看表的行数
db.mycoll.count();

//查看集合数据大小,只能看表的，db级别在show dbs时候就显示了。
//显示的是字节，需要转换成kb要除以1024.
db.mycoll.dataSize()

//查看集合索引大小
db.mycoll.totalIndexSize();

//查看为集合分配的空间大小，包括未使用的 mycoll是表名
db.mycoll.storageSize()

//显示集合总大小，包括岁以后和数据的大小
db.mycoll.totalSize();

//显示当前集合所在的db
db.mycoll.getDB();

//显示当前集合的状态
db.mycoll.stats();

//集合的分配版本信息
db.mycoll.getShardVersion();

//集合重命名,把mycoll重命名为users
db.mycoll.renameCollection("users")
//重命名语法2，如果表名是纯数字只能用这种方法
db.getCollection("mycoll").renameCollection("users");

//显示当前db所有集合的状态信息
db.printCollectionStats()

//删除表
db.mycoll.drop();

//表写入
db.user.insert({"name":"joe"}); //插入user表中，写入name是joe的值
db.suer.save({"name":"joe"}); //也是表写入数据方式，如果表不存在自动创建。
//save和insert区别在于save有写入功能也有更新功能，如果存在相同键就会更新成存入的值，
//insert只会插入数据。相同的数据就会报错。

my_repl:PRIMARY> db.t2.save({"name":"zw","age":30});
WriteResult({ "nInserted" : 1 })
my_repl:PRIMARY> db.t2.find()
{ "_id" : ObjectId("60965d1a09851c37f9250506"), "name" : "zw", "age" : 30 }
my_repl:PRIMARY>

//查看文档
db.t1.find();

//更新文档方法
save() //通过传入的文档更新现有的，如果没有就新增
update() //用于更新已存在的文档。语法见见图：

update() 方法用于更新已存在的文档。语法格式如下：

db.collection.update(
   <query>,
   <update>,
   {
     upsert: <boolean>,
     multi: <boolean>,
     writeConcern: <document>
   }
)
参数说明：

query : update的查询条件，类似sql update查询内where后面的。
update : update的对象和一些更新的操作符（如$,$inc...）等，也可以理解为sql update查询内set后面的
upsert : 可选，这个参数的意思是，如果不存在update的记录，是否插入objNew,true为插入，默认是false，不插入。
multi : 可选，mongodb 默认是false,只更新找到的第一条记录，如果这个参数为true,就把按条件查出来多条记录全部更新。
writeConcern :可选，抛出异常的级别。

db.col.update({'title':'MongoDB 教程'},{$set:{'title':'MongoDB'}}) //把title字段为mongodb 教程更新为mongdb


//删除文档
db.collection.remove(查询条件，justone boolean,writeConcern:异常信息等级)
//justone 默认是fose查询到第一个后是否继续下去，默认是fose
//案例 db.t1.remove({"myname":"joe",1})
//删除案例。
my_repl:PRIMARY> db.t2.find()
{ "_id" : ObjectId("60965d1a09851c37f9250506"), "name" : "zw", "age" : 30 }
{ "_id" : ObjectId("609660d209851c37f9250507"), "name" : "zw1", "age" : 31 }
{ "_id" : ObjectId("609660df09851c37f9250508"), "name" : "zw2", "age" : 33 }
my_repl:PRIMARY> db.t2.remove({"name":"zw2"},1)
WriteResult({ "nRemoved" : 1 })
my_repl:PRIMARY> db.t2.find()
{ "_id" : ObjectId("60965d1a09851c37f9250506"), "name" : "zw", "age" : 30 }
{ "_id" : ObjectId("609660d209851c37f9250507"), "name" : "zw1", "age" : 31 }
my_repl:PRIMARY>


//更新文档并返回文档，和上面的update函数多了个返回文档
findAndModify
findAndModify //执行分为find和update两步，属于get-and-set式的 操作，它的功能强大之处在于可以保证操作的原子性。
findAndModify //对于操作查询以及执行其它需要取值和赋值风格的原子 性操作是十分方便的，使用它可以实现一些简单的类事务操作。
//此函数有7个参数，功能很强大。
//原文链接：https://www.runoob.com/mongodb/mongodb-atomic-operations.html


//// 索引先关命令
//创建索引
db.user.ensureIndex({age:1}); //后面1表示正序索引，0是倒序索引
db.test.ensureIndex({"userid":1},{"background":true}) //创建索引，并放到后台执行，不阻塞数据库的其他操作
db.test.ensureIndex({"userid":1},{"unique":true}) //创建列userid的唯一索引
//创建唯一索引时候如果有重复数据，可以使用下面命令进行删除
db.test.ensureIndex({"userid":1},{"unique":true,"dropDups":true})
//唯一索引的空值只能有一个，如果多个空值，想要正常创建唯一索引需要设置成稀松索引
db.test.ensureIndex({"userid":1},{"unique":true,"sparse":true}) 
//sparse等于true表示userid为空或者userid不存在时候不进入索引，也就是索引不记录这行userid为空的值

//查看集合所有索引
db.user.getIndexes();

//查看集合总索引记录大小
db.user.totalIndexSize();

//读取当前集合的所有index信息
db.user.reIndex();

//删除指定索引
db.user.dropIndex("myName")

//删除集合所有索引
db.user.dropIndexes();
```

### 游标

用于占时存放find执行的结果。而放入游标中的数据无论是单条还是多条的结果集，每次只能提取一条数据。

游标一般用于便利数据集，通过hasNext()判断是否有下一条数据，netx()方法获取下一条数据。

例如：

```js
my_repl:PRIMARY> var cursor=db.t1.find()  //#定义一个游标，他等于t1表的查询结果
my_repl:PRIMARY> while(cursor.hasNext()){
... var temp=cursor.next()
... print(temp.name)  //#name是t1表中的字段名称
... }
t1
t2
[unknown type]
my_repl:PRIMARY> db.t1.find()
{ "_id" : ObjectId("60989e5791836e5dfb953b8b"), "name" : "t1", "age" : 19 }
{ "_id" : ObjectId("60989e5f91836e5dfb953b8c"), "name" : "t2", "age" : 30 }
{ "_id" : ObjectId("60989e7e91836e5dfb953b8d"), "job" : "it", "age" : 30 } //#第三行没有name字段所以上面结果是unknown
my_repl:PRIMARY>
```

### 条件查询

```js
my_repl:PRIMARY> db.t1.find({"name":"t1"}) ;
{ "_id" : ObjectId("60989e5791836e5dfb953b8b"), "name" : "t1", "age" : 19 }

my_repl:PRIMARY> db.t1.find({"name":"t1"},{"age":19}) ;  //这个和下面的写法意思不一样，2个花括号不时and关系
{ "_id" : ObjectId("60989e5791836e5dfb953b8b"), "age" : 19 }
my_repl:PRIMARY> db.t1.find({"name":"t1","age":19}) ; //在同一个花括号内的条件是and关系
{ "_id" : ObjectId("60989e5791836e5dfb953b8b"), "name" : "t1", "age" : 19 }
my_repl:PRIMARY> //新增一条数据运行或关系查询
my_repl:PRIMARY> db.t1.save({"name":"t3","age":18})
WriteResult({ "nInserted" : 1 })
my_repl:PRIMARY> db.t1.find();
{ "_id" : ObjectId("60989e5791836e5dfb953b8b"), "name" : "t1", "age" : 19 }
{ "_id" : ObjectId("60989e5f91836e5dfb953b8c"), "name" : "t2", "age" : 30 }
{ "_id" : ObjectId("60989e7e91836e5dfb953b8d"), "job" : "it", "age" : 30 }
{ "_id" : ObjectId("609b8ee41c244871016d35ff"), "name" : "t3", "age" : 18 }
my_repl:PRIMARY>
my_repl:PRIMARY> db.t1.find({$or:[{age:18},{age:19}]}) //#前面or表示，两个花括号调解是or关系
{ "_id" : ObjectId("60989e5791836e5dfb953b8b"), "name" : "t1", "age" : 19 }
{ "_id" : ObjectId("609b8ee41c244871016d35ff"), "name" : "t3", "age" : 18 }
my_repl:PRIMARY>//#演示条件是大于的意思
my_repl:PRIMARY> db.t1.find({age:{$gt:20}}) //#字段age 大于20的数据
{ "_id" : ObjectId("60989e5f91836e5dfb953b8c"), "name" : "t2", "age" : 30 }
{ "_id" : ObjectId("60989e7e91836e5dfb953b8d"), "job" : "it", "age" : 30 }
my_repl:PRIMARY>//#小于
my_repl:PRIMARY>  db.t1.find({age:{$lt:20}})
{ "_id" : ObjectId("60989e5791836e5dfb953b8b"), "name" : "t1", "age" : 19 }
{ "_id" : ObjectId("609b8ee41c244871016d35ff"), "name" : "t3", "age" : 18 }
my_repl:PRIMARY>//# 大于等于 $gte,  小于等于 $lte ,就是在大于和小于后面加个e
my_repl:PRIMARY> db.t1.find({age:{$lte:20}}) //#小于等于20
{ "_id" : ObjectId("60989e5791836e5dfb953b8b"), "name" : "t1", "age" : 19 }
{ "_id" : ObjectId("609b8ee41c244871016d35ff"), "name" : "t3", "age" : 18 }
{ "_id" : ObjectId("609b96831c244871016d3600"), "name" : "t4", "age" : 20 }
my_repl:PRIMARY>
my_repl:PRIMARY> db.t1.find({age:{$gte:20}}) // 大于等于20
{ "_id" : ObjectId("60989e5f91836e5dfb953b8c"), "name" : "t2", "age" : 30 }
{ "_id" : ObjectId("60989e7e91836e5dfb953b8d"), "job" : "it", "age" : 30 }
{ "_id" : ObjectId("609b96831c244871016d3600"), "name" : "t4", "age" : 20 }



```

### 类型查询$type

$type操作符用来查询文档中字段与指定类型匹配的数据，并返回结果

指定的类型有如下几种：在使用时候使用number列代表类型。

官网参考：https://docs.mongodb.com/manual/reference/operator/query/type/index.html

|                         |        |                       |                     |
| :---------------------- | :----- | :-------------------- | :------------------ |
| Type                    | Number | Alias                 | Notes               |
| Double                  | 1      | “double”              |                     |
| String                  | 2      | “string”              |                     |
| Object                  | 3      | “object”              |                     |
| Array                   | 4      | “array”               |                     |
| Binary data             | 5      | “binData”             |                     |
| Undefined               | 6      | “undefined”           | Deprecated.         |
| ObjectId                | 7      | “objectId”            |                     |
| Boolean                 | 8      | “bool”                |                     |
| Date                    | 9      | “date”                |                     |
| Null                    | 10     | “null”                |                     |
| Regular Expression      | 11     | “regex”               |                     |
| DBPointer               | 12     | “dbPointer”           | Deprecated.         |
| JavaScript              | 13     | “javascript”          |                     |
| Symbol                  | 14     | “symbol”              | Deprecated.         |
| JavaScript (with scope) | 15     | “javascriptWithScope” |                     |
| 32-bit integer          | 16     | “int”                 |                     |
| Timestamp               | 17     | “timestamp”           |                     |
| 64-bit integer          | 18     | “long”                |                     |
| Decimal128              | 19     | “decimal”             | New in version 3.4. |
| Min key                 | -1     | “minKey”              |                     |
| Max key                 | 127    | “maxKey”              |                     |



查询案例：

```js
db.集合名.find({$type:类型值});    //这里的类型值能使用Number也能使用alias
db.person.find({address:{$type:2}});         //查询address字段数据类型为字符串
db.person.find({address:{$type:"string"}});  //查询address字段数据类型为字符串

再举个有点特殊的查询,关于null 查询的例子:

db.person.find({address:null});             //注意,这样查询会将没有 address 列的数据一并查询出来
db.person.find({address:{$exists:true, $eq:null}}); //这样查询的是 address 列值为null 的数据
db.person.find({address:{$type:10}});      //这样查询的是 address 列值为null 的数据，10就是上面列表中null的序号

```

是否存在 $exists

```js
db.t1.find({"age":{$exists:true}}) //查询age字段存在的文档
my_repl:PRIMARY> db.t1.find({"job":{$exists:true}})
{ "_id" : ObjectId("60989e7e91836e5dfb953b8d"), "job" : "it", "age" : 30 }
my_repl:PRIMARY> db.t1.find({"name":{$exists:true}})
{ "_id" : ObjectId("60989e5791836e5dfb953b8b"), "name" : "t1", "age" : 19 }
{ "_id" : ObjectId("60989e5f91836e5dfb953b8c"), "name" : "t2", "age" : 30 }
{ "_id" : ObjectId("609b8ee41c244871016d35ff"), "name" : "t3", "age" : 18 }
{ "_id" : ObjectId("609b96831c244871016d3600"), "name" : "t4", "age" : 20 }
my_repl:PRIMARY>
    
// 取模运行$mod
 my_repl:PRIMARY> db.t1.find()
{ "_id" : ObjectId("60989e5791836e5dfb953b8b"), "name" : "t1", "age" : 19 }
{ "_id" : ObjectId("60989e5f91836e5dfb953b8c"), "name" : "t2", "age" : 30 }
{ "_id" : ObjectId("60989e7e91836e5dfb953b8d"), "job" : "it", "age" : 30 }
{ "_id" : ObjectId("609b8ee41c244871016d35ff"), "name" : "t3", "age" : 18 }
{ "_id" : ObjectId("609b96831c244871016d3600"), "name" : "t4", "age" : 20 }
my_repl:PRIMARY> db.t1.find({"age":{$mod:[10,0]}}) //取模10 等于0 的数据
{ "_id" : ObjectId("60989e5f91836e5dfb953b8c"), "name" : "t2", "age" : 30 }
{ "_id" : ObjectId("60989e7e91836e5dfb953b8d"), "job" : "it", "age" : 30 }
{ "_id" : ObjectId("609b96831c244871016d3600"), "name" : "t4", "age" : 20 }
my_repl:PRIMARY>
  //不等于 $ne
my_repl:PRIMARY>db.t1.find({"age":{$ne:30}}) // age不等于30的数据
{ "_id" : ObjectId("60989e5791836e5dfb953b8b"), "name" : "t1", "age" : 19 }
{ "_id" : ObjectId("609b8ee41c244871016d35ff"), "name" : "t3", "age" : 18 }
{ "_id" : ObjectId("609b96831c244871016d3600"), "name" : "t4", "age" : 20 }

//包含 $in
my_repl:PRIMARY> db.t1.find({"age":{$in:[20,30]}})
{ "_id" : ObjectId("60989e5f91836e5dfb953b8c"), "name" : "t2", "age" : 30 }
{ "_id" : ObjectId("60989e7e91836e5dfb953b8d"), "job" : "it", "age" : 30 }
{ "_id" : ObjectId("609b96831c244871016d3600"), "name" : "t4", "age" : 20 }
my_repl:PRIMARY> db.t1.find({"name":{$in:["t1","t2"]}})
{ "_id" : ObjectId("60989e5791836e5dfb953b8b"), "name" : "t1", "age" : 19 }
{ "_id" : ObjectId("60989e5f91836e5dfb953b8c"), "name" : "t2", "age" : 30 }

// 不包含 $nin
my_repl:PRIMARY> db.t1.find({"name":{$nin:["t1","t2"]}}) 
{ "_id" : ObjectId("60989e7e91836e5dfb953b8d"), "job" : "it", "age" : 30 }
{ "_id" : ObjectId("609b8ee41c244871016d35ff"), "name" : "t3", "age" : 18 }
{ "_id" : ObjectId("609b96831c244871016d3600"), "name" : "t4", "age" : 20 }
my_repl:PRIMARY> db.t1.find({"age":{$nin:[20,30]}}) //age字段不包含20和30的数据。
{ "_id" : ObjectId("60989e5791836e5dfb953b8b"), "name" : "t1", "age" : 19 }
{ "_id" : ObjectId("609b8ee41c244871016d35ff"), "name" : "t3", "age" : 18 }
my_repl:PRIMARY>
// $not 反向选择 也就是not in就是取反
my_repl:PRIMARY> db.t1.find({"age":{$not:{$in:[20,30]}}}) //本身是in取20和30的数据，外面在包含一层not就是取反变成not in的效果
{ "_id" : ObjectId("60989e5791836e5dfb953b8b"), "name" : "t1", "age" : 19 }
{ "_id" : ObjectId("609b8ee41c244871016d35ff"), "name" : "t3", "age" : 18 }
my_repl:PRIMARY>
   
```

特定类型查询

```js
// null 的选择。
db.t1.find({"name":null}) //查询t1表字段是name的值是null的数据
db.t1.find({"name":{$nin:[null]}) //查询name字段不时null的数据。
```

### 正则查询（模糊查询）

正则表达式，又称为规则表达式，通常用于检索和验证字符



```js
常用的元字符的使用
.  匹配除换行符意外的任意一个字符
\w 匹配字母，数字，下划线，汉字
\s 匹配任意的空白符
\d 匹配数字
\b 匹配单次的开始或结束
^ 匹配字符串的开始
$ 匹配字符串的结束

常用的限定符的代码
* 重复零次或更多次
+ 重复一次或多次
？ 重复零次或一次
{n} 重复n次
{n,} 重复n次或更多次，也就是重复最少n次
{n,m} 重复n到m次，也就是重复次数在n到m之间

常用的反义代码语法及说明
\W 匹配任意不是字母，数字，下划线，汉字的字符
\S 匹配任意不是空白符的字符
\D 匹配任意非数字的字符
\B 匹配不时单词开头或结束的位置
[^x] 匹配除了x以外的任意字符
[^abc] 匹配除了abc以外的任意字符
```



### 复制集维护命令

```js
// 关闭实例，一般用于维护命令
db.shutdownServer()
rs.status()
rs.stepDown(300);//降级为从库，时间300秒之后
// 修改权重指定节点为主节点,权重数从1--1000可以是小数。
cfg = rs.conf()
cfg.members[0].priority = 0.5
cfg.members[1].priority = 0.5
cfg.members[2].priority = 1
rs.reconfig(cfg)

rs.config()是rs.conf()的别名。
rs.conf()返回包含当前replica set配置的文档。该方法包装replSetGetConfig命令。
rs.reconfig(配置文件名次,force*） 重新应用覆盖配置复制配置文件，必须在主库运行。
//rs.reconfig() shell 方法可以在某些情况下触发当前的主数据库降级。当主服务器降级时，
//它将强制关闭所有 Client 端连接。主降压触发election选择新的primary。

cfg=rs.conf()
{
	"_id" : "my_repl",
	"version" : 13,
	"protocolVersion" : NumberLong(1),
	"members" : [
		{
			"_id" : 0,
			"host" : "10.208.0.125:28017",
			"arbiterOnly" : false,    //arbiter 选举节点
			"buildIndexes" : true,   // 
			"hidden" : false,   //是否隐藏
			"priority" : 1,  //权重值
			"tags" : {

			},
			"slaveDelay" : NumberLong(0),
			"votes" : 1
		},
		{
			"_id" : 1,
			"host" : "10.208.0.125:28018",
			"arbiterOnly" : false,
			"buildIndexes" : true,
			"hidden" : false,
			"priority" : 1,
			"tags" : {

			},
			"slaveDelay" : NumberLong(0),
			"votes" : 1
		},
		{
			"_id" : 2,
			"host" : "10.208.0.125:28019",
			"arbiterOnly" : false,
			"buildIndexes" : true,
			"hidden" : false,
			"priority" : 1,
			"tags" : {

			},
			"slaveDelay" : NumberLong(0), // 延迟复制
			"votes" : 1
		},
		{
			"_id" : 3,
			"host" : "10.208.0.125:28020",
			"arbiterOnly" : true,  //arbiter 选举节点
			"buildIndexes" : true,
			"hidden" : false,
			"priority" : 0,
			"tags" : {

			},
			"slaveDelay" : NumberLong(0),
			"votes" : 1
		}
	],
	"settings" : {
		"chainingAllowed" : true,
		"heartbeatIntervalMillis" : 2000,
		"heartbeatTimeoutSecs" : 10,
		"electionTimeoutMillis" : 10000,
		"catchUpTimeoutMillis" : -1,
		"catchUpTakeoverDelayMillis" : 30000,
		"getLastErrorModes" : {

		},
		"getLastErrorDefaults" : {
			"w" : 1,
			"wtimeout" : 0
		},
		"replicaSetId" : ObjectId("5f3c8f30586bc473fc27b43e")
	}
}

db.adminCommand({replSetStepDown: 86400, force: 1}) //强制下线多久
rs.freeze() //冻结节点多长时间，不参与选举，括号内写秒数。不能在主节点上运行，只能运行在从节点。

db.printSlaveReplicationInfo()    //可以查看slave延迟情况。

//进入维护模式2种方式，1.自动触发：在secondary上执行压缩，第二种手动触发，执行下面的语句就会进入维护模式，不会提供读写服务
db.adminCommand({"replSetMaintenance":true}) // 进入维护模式
//之后提示符会显示recovering>
//退出维护模式
db.adminCommand({"replSetMaintenance":false})
//之后提示符会显示:SECONDARY>



添加仲裁节点
// 添加仲裁节点
$ rs.addArb("192.68.199.163:27020")

//隐藏节点，一般用于备份
把27019节点删除，重启。再添加让其为hidden节点：
$ rs.add({"_id":2,"host":"192.168.199.164:27019","priority":0,"hidden":true})

// 隐藏延迟节点
$ rs.add({"_id":2,"host":"192.168.199.164:27019","priority":0,"hidden":true,"slaveDelay":60})    // 单位 s

Secondary-Only:不能成为primary节点，只能作为secondary副本节点，防止一些性能不高的节点成为主节点。
Non-Voting：没有选举权的secondary节点，纯粹的备份数据节点。
```



最新进度  MongoDB游记之轻松入门到进阶 ：125也开头。

# mongod权威指南

## 9.复制



```js
mongo --nodb  //先进入命令行之后输入命令
replicatset=new ReplSettest({"nodes":3}) //创建一个包含3个服务器的副本集。但是不会启动mongod
replicatset.startSet() //启动3个mongod进程
replicatset.initiate() //配置复制功能

//插入100条数据给ee表
my_repl:PRIMARY> for (i=0;i<100;i++) {db.ee.insert({count:i})}
WriteResult({ "nInserted" : 1 })

// 配置信息重要信息主要有两部分：Replica Set的 id 值 和 member 数组。
{
_id: "replica set name",
members: [
    {
      _id: <int>,
      host: "host:port",
      arbiterOnly: <boolean>,
      buildIndexes: <boolean>,
      hidden: <boolean>,
      priority: <number>,
      slaveDelay: <int>,
      votes: <number>
    },
    ...
  ],
...
}

// 添加一个节点命令
rs.add( { _id:4, host: "host:port", priority: 0, hidden:true, slaveDelay:3600, votes:0, 
    buildIndexes:true, arbiterOnly:false } )
 
// 节点状态解释
priority：表示一个成员被选举为Primary节点的优先级，默认值是1，取值范围是从0到100，
将priority设置为0有特殊含义：Priority为0的成员永远不能成为Primary 节点。Replica Set中，Priority最高的成员，
会优先被选举为Primary 节点，只要其满足条件。

hidden：将成员配置为隐藏成员，要求Priority 为0。Client不会向隐藏成员发送请求，因此隐藏成员不会收到Client的Request。

slaveDelay：单位是秒，将Secondary 成员配置为延迟备份节点，要求Priority 为0，表示该成员比Primary 成员滞后指定的时间，
才能将Primary上进行的写操作同步到本地。为了数据读取的一致性，应将延迟备份节点的hidden设置为true，避免用户读取到明显滞后的数据。

votes：有效值是0或1，默认值是1，如果votes是1，表示该成员（voting member）有权限选举Primary 成员。
在一个Replica Set中，最多有7个成员，其votes 属性的值是1。

arbiterOnly：表示该成员是仲裁者，arbiter的唯一作用是就是参与选举，其votes属性是1，arbiter不保存数据，也不会为client提供服务。

buildIndexes：表示实在在成员上创建Index，该属性不能修改，只能在增加成员时设置该属性。如果一个成员仅仅作为备份，不接收Client的请求，
将该成员设置为不创建index，能够提高数据同步的效率。

    
2.重新配置Replica Set

对Replica Set重新配置，必须连接到Primary 节点；如果Replica Set中没有一个节点被选举为Primary，那么，可以使用
force option（rs.reconfig(config,{force:true})），在Secondary 节点上强制对Replica Set进行重新配置。
```

### 副本状态解释

```js
// 配置信息重要信息主要有两部分：Replica Set的 id 值 和 member 数组。
my_repl:PRIMARY> var cfg=rs.conf()
my_repl:PRIMARY> cfg
{
	"_id" : "my_repl",  // 复制集名次
	"version" : 18,      // 配置文件版本，修改一次版本加一。
	"protocolVersion" : NumberLong(1),  //是协议版本。
	"members" : [       // 数组，里面是 复制集成员信息。
		{
			"_id" : 0,   //成员编号，唯一的，可能根据增加和删除成员会变化，可以定位到成员
			"host" : "10.208.0.125:28017",    //成员ip和端口
			"arbiterOnly" : false,     //arbiter成语没有数据只有选举权，这是这个成员不是，所以是false
			"buildIndexes" : true,    //是否创建索引 true是创建索引，如果是备份隐藏节点可以不用创建索引，修改后不可逆。
			"hidden" : false,    // 是否是隐藏节点
			"priority" : 10,  // 节点优先级 从0--1000，越大优先级越高，如果是0表示永远不作为primary
			"tags" : {     // 节点标签和注释，非必填

			},
			"slaveDelay" : NumberLong(0),    // 延迟复制秒数。
			"votes" : 1    // 是否有选举权，1是有，0是没有
		},
		{
			"_id" : 1,
			"host" : "10.208.0.125:28018",
			"arbiterOnly" : false,
			"buildIndexes" : true,
			"hidden" : false,
			"priority" : 10,
			"tags" : {

			},
			"slaveDelay" : NumberLong(0),
			"votes" : 1
		},
		{
			"_id" : 2,
			"host" : "10.208.0.125:28019",
			"arbiterOnly" : false,
			"buildIndexes" : true,
			"hidden" : false,
			"priority" : 5,
			"tags" : {

			},
			"slaveDelay" : NumberLong(0),
			"votes" : 1
		},
		{
			"_id" : 3,
			"host" : "10.208.0.125:28020",
			"arbiterOnly" : true,
			"buildIndexes" : true,
			"hidden" : false,
			"priority" : 0,
			"tags" : {

			},
			"slaveDelay" : NumberLong(0),
			"votes" : 1
		}
	],
	"settings" : {					// 集群的一些配置信息
		"chainingAllowed" : true,  //表示是否允许链式复制,即某个secondary可以作为其它的secondary的源,默认是true. fsyncfrom()
		"heartbeatIntervalMillis" : 2000, //示heartbeat的间隔时间,默认是每隔两秒钟发送一个hearbeat包
		"heartbeatTimeoutSecs" : 10, //表示心跳检测超时时间,默认是10秒.
		"electionTimeoutMillis" : 10000, //表示选举超时时间,默认是10秒.
		"catchUpTimeoutMillis" : -1,
		"catchUpTakeoverDelayMillis" : 30000,
		"getLastErrorModes" : {

		},
		"getLastErrorDefaults" : {
			"w" : 1,
			"wtimeout" : 0
		},
		"replicaSetId" : ObjectId("5f3c8f30586bc473fc27b43e")
	}
}
```

> priority：表示一个成员被选举为Primary节点的优先级，默认值是1，取值范围是从0到100，
> 将priority设置为0有特殊含义：Priority为0的成员永远不能成为Primary 节点。Replica Set中，Priority最高的成员，
> 会优先被选举为Primary 节点，只要其满足条件。
>
> hidden：将成员配置为隐藏成员，要求Priority 为0。Client不会向隐藏成员发送请求，因此隐藏成员不会收到Client的Request。
>
> slaveDelay：单位是秒，将Secondary 成员配置为延迟备份节点，要求Priority 为0，表示该成员比Primary 成员滞后指定的时间，才能将Primary上进行的写操作同步到本地。为了数据读取的一致性，应将延迟备份节点的hidden设置为true，避免用户读取到明显滞后的数据。
>
> votes：有效值是0或1，默认值是1，如果votes是1，表示该成员（voting member）有权限选举Primary 成员。
> 在一个Replica Set中，最多有7个成员，其votes 属性的值是1。
>
> arbiterOnly：表示该成员是仲裁者，arbiter的唯一作用是就是参与选举，其votes属性是1，arbiter不保存数据，也不会为client提供服务。
>
> buildIndexes：表示实在在成员上创建Index，该属性不能修改，只能在增加成员时设置该属性。如果一个成员仅仅作为备份，不接收Client的请求，将该成员设置为不创建index，能够提高数据同步的效率。
>
> 
>
> \\ \_id:是用来标识复制集,参数内容和数据库启动的时候设置的rplSet参数一致
> version:用来表示config参数的新旧,每次修改了config然后使用rs.reconfig重新配置的时候version的值会自动加1
> protocolversion:是协议版本
> members:是一个数组,数组成员表示每个节点的信息.下面结束members的主要内容._id:用来标识节点号,唯一
>
> host:表示节点的地址和端口信息
> arbiterOnly:这是一个bool型,默认为false,用来表示这个节点是否是arbiter节点,只是用来投票
> buildIndexes:这也是一个bool型,默认为true.用来表示同步的时候是否同步索引.一般设置为true.如果要设置为false,则必须将priority设置为0
> hidden:这也是bool型,默认问false,用来表示这个节点是否为隐藏节点,如果是隐藏节点将不对外服务,只是单纯的同步信息,而且如果设置为了隐藏节点,使用rs.isMaster()方法将无法查看到隐藏节点的信息,但是可以使用rs.status()查看.设置隐藏节点必须首先将节点的priority设置为0
> priority:表示权重,默认为1,如果将priority设置为0那么这个节点将永远无法成为primary节点,现在新的版本可以设置为超过1的数
> slaveDelay:复制延迟,这个是整数,单位为秒,用来设置复制的延时.一般用来防止误操作,延迟节点必须优先级设置为0,hidden设置为true,然后设置slaveDelay值,
> votes:表示这个节点是否有权利进行投票.
> tags:表示标记,例如可以标记这个节点的作用等
> settings是一些配置信息
> chainingAllowed:表示是否允许链式复制,即某个secondary可以作为其它的secondary的源,默认是true.
> heartbeatIntervalMillis:表示heartbeat的间隔时间,默认是没个两秒钟发送一个hearbeat包.
> heartbeatTimeoutSecs:表示心跳检测超时时间,默认是10秒.
> electionTimeoutMillis:表示选举超时时间,默认是10秒.
>
>  



### 修改配置文件

```js
var cfg=config()
cfg //显示配置内容

// 之后进行内容修改

// 修改后重新应用配置文件
my_repl:PRIMARY> rs.reconfig(cfg) //cfg是定义变量的名称，这个变量是一个字符串

// 例如修改成员2的优先级。
rsconfig.members[2].priority = 0.5

//添加节点
rs0:PRIMARY> rs.add({"host":"mongodb3:27017","priority":0,"hidden":true})

rs.remove("mongodb3:27017")
rs0:PRIMARY> rs.addArb("mongodb3:27017") // 添加选举节点。

rs.printSlaveReplicationInfo() // 查看复制延迟



```











> 2.重新配置Replica Set
>
> 对Replica Set重新配置，必须连接到Primary 节点；如果Replica Set中没有一个节点被选举为Primary，那么，可以使用
> force option（rs.reconfig(config,{force:true})），在Secondary 节点上强制对Replica Set进行重新配置。

### 读写分离

```
MongoDB副本集对读写分离的支持是通过Read Preferences特性进行支持的，这个特性非常复杂和灵活。设置读写分离需要先在从节点
SECONDARY 设置 setSlaveOk  应用程序驱动通过read reference来设定如何对副本集进行读取操作，默认的,客户端驱动所有的读
操作都是直接访问primary节点的，从而保证了数据的严格一致性。
有如下几种模式：
```

### 修改oplog大小





oplog的大小

oplog集合是一个固定集合，其大小是固定的，在第一次开始Replica Set的成员时，MongoDB创建默认大小的oplog。在MongoDB 3.2.9 版本中，MongoDB 默认的存储引擎是WiredTiger，一般情况下，oplog的默认大小是数据文件所在disk 空闲空间（disk free space）的5%，最小不会低于990 MB，最大不会超过50 GB。

3，修改oplog的大小

修改的过程主要分为三步：

- 以单机模式重启mongod
- 启动之后，重新创建oplog，并保留最后一个记录作为种子
- 以复制集方式重启mongod

详细过程是：

step1：以单机模式重启mongod

对于Primary成员，首先调用stepDown函数，强制Primary成员转变为Secondary成员

```
rs.stepDown()
```

对于secondary成员，调用shutdownServer()函数，关闭mongod

```
use admin 
db.shutdownServer()
```

启动mongod实例，不要使用replset参数

```
mongod --port 37017 --dbpath /srv/mongodb
```

step2：创建新的oplog

有备无患，备份oplog文件

```
mongodump --db local --collection 'oplog.rs' --port 37017
```

将oplog中最后一条有效记录保存到temp 集合中，作为新oplog的seed

```js
use local
db.temp.drop()
db.temp.save( db.oplog.rs.find( { }, { ts: 1, h: 1 } ).sort( {$natural : -1} ).limit(1).next() )
db.oplog.rs.drop()

```

重建新的oplog集合，并将temp集合中一条记录保存到oplog中，size的单位是Byte

```js
db.runCommand( { create: "oplog.rs", capped: true, size: (2 * 1024 * 1024 * 1024) } )
db.oplog.rs.save( db.temp.findOne() )
```

step3：以复制集模式启动 mongod，replset参数必须制定正确的Replica Set的名字

```js
db.shutdownServer()
mongod --replSet rs0 --dbpath /srv/mongodb
```

三，查看mongod 的开机日志

在local.startup_log 集合中，存储mongod 每次启动时的开机日志



### 复制集成员



| 式                 | 描述                                                         |
| :----------------- | :----------------------------------------------------------- |
| primary            | 主节点，默认模式，读操作只在主节点，如果主节点不可用，报错或者抛出异常。 |
| primaryPreferred   | 首选主节点，大多情况下读操作在主节点，如果主节点不可用，如故障转移，读操作在从节点。 |
| secondary          | 从节点，读操作只在从节点， 如果从节点不可用，报错或者抛出异常。 |
| secondaryPreferred | 首选从节点，大多情况下读操作在从节点，特殊情况（如单主节点架构）读操作在主节点。 |
| nearest            | 最邻近节点，读操作在最邻近的成员，可能是主节点或者从节点，关于最邻近的成员请参考官网[nearest](https://docs.mongodb.com/manual/reference/read-preference/#nearest) |



| 名称       | 描述                                                         |
| :--------- | :----------------------------------------------------------- |
| STARTUP    | 没有任何活跃的节点，所有节点在这种状态下启动，解析副本集配置 |
| PRIMARY    | 副本集的主节点                                               |
| SECONDARY  | 副本集从节点，可以读数据                                     |
| RECOVERING | 可以投票，成员执行启动自检,或完成回滚或重新同步。            |
| STARTUP2   | 节点加入，并运行初始同步                                     |
| UNKNOWN    | 从其它节点看来，该节点未知                                   |
| ARBITER    | 仲裁者，不复制数据，供投票                                   |
| DOWN       | 在其它节点看来，该节点不可达                                 |
| ROLLBACK   | 该节点正在执行回滚，不能读取数据                             |
| REMOVED    | 该节点被删除                                                 |



### 复制相关方法

| 方法名                             | 描述                                                         |
| :--------------------------------- | :----------------------------------------------------------- |
| rs.add()                           | 添加节点到副本集                                             |
| rs.addArb()                        | 添加仲裁节点到副本集                                         |
| rs.conf()                          | 获取副本集的配置文档                                         |
| rs.freeze()                        | 指定一段时间内，当前节点不能竞选主节点Primary                |
| rs.help()                          | 获取副本集的基本方法                                         |
| rs.initiate()                      | 初始化一个新的副本集                                         |
| rs.printReplicationInfo()          | 从主数据库的角度打印副本集状态的格式化报告。                 |
| rs.printSecondaryReplicationInfo() | 从第二副本的角度打印副本集状态的格式化报告。                 |
| rs.printSlaveReplicationInfo()     | 从4.4.1版开始不推荐使用：rs.printSecondaryReplicationInfo()改为使用 |
| rs.reconfig()                      | 重新配置副本集                                               |
| rs.remove()                        | 删除一个节点                                                 |
| rs.slaveOk()                       | 设置当前连接可读，使用readPref() 和 MongosetReadPref()去设置读偏好 |
| rs.status()                        | 返回副本集状态信息的文档                                     |
| rs.stepDown()                      | 强制当前主节点Primary成为从节点Secondary，并触发投票选举     |
| rs.syncFrom()                      | 设置新的同步目标，覆盖默认的同步目标， 以[hostname]:[port]的形式指定要复制的成员的名称。 |

复制 数据库的命令

| 名称               | 描述                                                     |
| :----------------- | :------------------------------------------------------- |
| replSetFreeze      | 阻止当前节点竞争当主节点Primary一段时间                  |
| replSetGetStatus   | 返回副本集状态信息的文档                                 |
| replSetInitiate    | 初始化一个新的副本集                                     |
| replSetMaintenance | 启用或禁用维护模式，使从节点Secondary进入恢复状态        |
| replSetReconfig    | 重新配置副本集                                           |
| replSetStepDown    | 强制当前主节点Primary成为从节点Secondary，并触发投票选举 |
| replSetSyncFrom    | 设置新的同步目标，覆盖默认的同步目标                     |
| resync             | 强制重新同步，仅在主从同步有效                           |
| applyOps           | 内部命令，应用oplog到当前的数据集                        |
| isMaster           | 显示该节点否是主节点和其它的相关信息                     |
| replSetGetConfig   | 返回副本集的配置对象                                     |



## mongod 备份恢复



| 区别     | mongodump/mongorestore                    | mongoexport/mongoimport          |
| -------- | ----------------------------------------- | -------------------------------- |
| 主要用途 | 数据备份小规模或部分或测试期间的数据/恢复 | 备份/恢复小型的MongoDB数据库     |
| 导出格式 | JSON/CSV                                  | BSON                             |
| 指定导出 | 不支持导出单个db的所有collection          | 支持导出单个db的所有collection   |
| 注意事项 | 不要用于生产环境的备份                    | 不适合备份/恢复大型MongoDB数据库 |



https://www.jianshu.com/p/d65190e16afe

### mongoexport

```
mongoexport
mongoexport工具可以collection导出成JSON格式或者CSV格式文件。

mongoimport 导入工具
```

导出表操作

```bash
导出collection为starbucks的数据

主要参数：
-d：要导出的库
-c：要导出的表
-o：导出的文件名
-q：查询条件
-f：导出哪几列

[root@gz-tencent ~]# mongoexport -d test -c starbucks -f name,street,city  --type=csv -q '{_id:{$in:["839","817"]}}' -o starbucks.csv --limit=1
2019-01-20T17:30:37.171+0800    connected to: localhost
2019-01-20T17:30:37.172+0800    exported 1 record
[root@gz-tencent ~]# cat starbucks.csv 
name,street,city
1st Avenue & 75th St.,1445 First Avenue,New York
```



### mongoimport

mongoimport可以把特定格式文件（JSON、CVS）中的内容导出到collection中。

```
mongoimport主要参数：
 -f：导出哪几列
 --headerline：将第一行作为表头（只支持CSV和TSV格式）
 --fields 和 --headerline 不兼容。
 
[root@gz-tencent ~]# mongoimport -d test -c starbucks  --type=csv --headerline --file=starbucks.csv
2019-01-20T18:04:54.983+0800    connected to: localhost
2019-01-20T18:04:55.052+0800    imported 1 document

```

mongodump和mongorestore。



```
mongodump/mongorestore
操作步骤：
mongodump:
/data/PRG/mongodb/bin/mongodump --host 192.168.1.2:27017 -d dbname -uuername -ppasswd -o /data/mongodb-linux-x86_64-1.8.1/data/ --directoryperdb
mongorestore:
/data/mongodb-linux-x86_64-1.8.1/bin/mongorestore --dbpath /data/mongodb-linux-x86_64-1.8.1/data/ --directoryperdb /data/dbname/
chown -R mongodb:mongodb /data/mongodb-linux-x86_64-1.8.1/data/

原文链接：https://blog.csdn.net/majinggogogo/article/details/48913787
```





### mongoddump



```
mysqldump命令使用。

1 .锁库后准备备份
使用fsync命令强制MongoDB服务器同步所有内存数据，然后对数据库加锁防止写入操作

> use admin
switched to db admin
> db.runCommand({"fsync":1,"lock":1});
{
    "info" : "now locked against writes, use db.fsyncUnlock() to unlock",  // 显示已经是只读，使用 db.fsyncUnlock解锁
    "lockCount" : NumberLong(1),
    "seeAlso" : "http://dochub.mongodb.org/core/fsynccommand",
    "ok" : 1
}



use db.fsyncUnlock() to unlock // 进行解锁


2. 进行数据备份操作。默认保存到 ./dump 目录下

mysqlddump主要参数：
-d：要导出的库
-c：要导出的表
-o：导出的文件名
-q：查询条件


mongodump -h 127.0.0.1:27017 -o /data/mongodb/27017/all/  #备份所有

[root@gz-tencent ~]# mongodump -d test -c starbucks

2019-01-20T21:42:10.869+0800    writing test.starbucks to 
2019-01-20T21:42:10.870+0800    done dumping test.starbucks (1 document)
[root@gz-tencent ~]# ll dump/test
total 8
-rw-r--r-- 1 root root 103 Jan 20 21:42 starbucks.bson
-rw-r--r-- 1 root root 128 Jan 20 21:42 starbucks.metadata.json

3、对数据解锁，允许数据写入。

> db.fsyncUnlock();
{ "info" : "fsyncUnlock completed", "lockCount" : NumberLong(0), "ok" : 1 }
> db.currentOp();
{
    "inprog" : [
        ...
    ],
    "ok" : 1
}
```

### mongorestore



恢复备份数据，使用mongorestore工具。



```
1.模拟实验，丢失表，这里先删除一个表

[root@gz-tencent ~]# mongo 
...
> use test
switched to db test
> db.starbucks.drop()
true
> show collections
123


2、恢复刚刚备份的starbucks表

主要参数：
-d：要备份的库
-c：要备份的表
--drop：恢复备份前删除

[root@gz-tencent ~]# mongorestore -d test -c starbucks --drop  ./dump/test/starbucks.bson 
2019-01-20T22:01:41.557+0800    checking for collection data in dump/test/starbucks.bson
2019-01-20T22:01:41.587+0800    reading metadata for test.starbucks from dump/test/starbucks.metadata.json
2019-01-20T22:01:41.648+0800    restoring test.starbucks from dump/test/starbucks.bson
2019-01-20T22:01:41.709+0800    no indexes to restore
2019-01-20T22:01:41.709+0800    finished restoring test.starbucks (1 document)
2019-01-20T22:01:41.709+0800    done



```

### 克隆collection

克隆技术可以将数据从一个数据源拷贝到多个数据源，将一份数据发布到多个存储服务器上。



```
1、 远程克隆

使用cloneCollection命令实现从远程复制数据到本地（此处，从localhost:27017拷贝到localhost:27018）

[root@gz-tencent mongo]# mongo localhost:27018
> db.runCommand({cloneCollection:"test.starbucks",from:"xxx.x.x.x:27017"});
{ "ok" : 1 }
> show collections
starbucks

2、本地克隆

MongoDB没有提供本地克隆collection的命令，可以写一个循环插入完成本地克隆。
[root@gz-tencent mongo]# mongo localhost:27018
> use test
switched to db test
> show collections
starbucks
> db.starbucks.find().forEach(function(x){db.backup.insert(x)});
> show collections
backup
starbucks
> db.backup.find();
{ "_id" : ObjectId("5c4447c604673a654a364f09"), "name" : "1st Avenue & 75th St.", "street" : "1445 First Avenue", "city" : "New York" }



```



### 复制数据库

复制数据库在mongod4.0已经废弃。3.X版本还可以用，MongoDB 4.0以后已经过时不能用啦。

使用copyDatabase命令实现数据库复制，可以再几秒内创建数据库副本

```
[root@gz-tencent mongo]# mongo localhost:27018
> db.copyDatabase("backup","backup","xxx.x.x.x:27017");
WARNING: db.copyDatabase is deprecated. See http://dochub.mongodb.org/core/copydb-clone-deprecation
{
    "note" : "Support for the copydb command has been deprecated. See http://dochub.mongodb.org/core/copydb-clone-deprecation",
    "ok" : 1
}
```

官方说明

```
copydb和clone命令
MongoDB 4.0不赞成使用copydb 和clone命令以及它们的 mongo shell帮助器 db.copyDatabase（）和 db.cloneDatabase（）。

作为替代方案，用户可以使用mongodump和 mongorestore（通过mongorestore选项 --nsFrom和--nsTo）或使用驱动程序编写脚本。

例如，要将test数据库从在默认端口27017上运行的本地实例复制到examples同一实例上的数据库，您可以：

用于mongodump将test数据库转储到归档文件mongodump-test-db：

mongodump --archive="mongodump-test-db" --db=test

mongorestore与--nsFrom和--nsTo一起使用以从存档中恢复（更改数据库名称）：

mongorestore --archive="mongodump-test-db" --nsFrom='test.*' --nsTo='examples.*'

根据需要包括其他选项，例如指定uri或主机，用户名，密码和身份验证数据库。

另外，也可以不使用存档文件，而可以 mongodump将test数据库连接到标准输出流，并通过管道传递到mongorestore：

mongodump --archive --db=test | mongorestore --archive  --nsFrom='test.*' --nsTo='examples.*'


```



### 恢复误删数据

**方法一：通过 oplog 恢复**

如果部署的是 MongoDB 复制集，这时还有一线希望，可以通过 oplog 来尽可能的恢复数据；MongoDB 复制集的每一条修改操作都会记录一条 oplog，所以当数据库被误删后，可以通过重放现有的oplog来「尽可能的恢复数据」。前不久遇到的一个用户，运气非常好，数据库是最近才创建的，所有的操作都还保留在oplog里，所以用户通过oplog把所有误删的数据都找回了。

通过 oplog 恢复数据的流程非常简单，只需要把oplog集合通过mongodump导出，然后通过mongorestore 的 oplogReplay 模式重放一下。

**Step1: 导出 oplog 集合**

```
mongodump -d local -c oplog.rs -d -o backupdir
```

**Step2: 拷贝oplog集合的数据**

```
mkdir new_backupdir
cp backupdir/local/oplog.rs.bson new_backupdir/oplog.bson
```

**Step3: 重放oplog**

```
mongorestore --oplogReplay new_backupdir
```

**方法二：通过备份集恢复**

如果对 MongoDB 做了全量备份 + 增量备份，那么可以通过备份集及来恢复数据。备份可以是多种形式，比如:

- 通过 mongodump 等工具，对数据库产生的逻辑备份
- 拷贝 dbpath 目录产生的物理备份
- 文件系统、卷管理等产生的快照等

从这里其实也可以看出一个问题，就是「部署了多节点的复制集，为什么还需要做数据备份？」；遇到误删数据库这种问题，dropDatabase 命令也会同步到所有的备节点，导致所有节点的数据都被删除。

**总结**

以上所述是小编给大家介绍的Mongodb数据库误删后的恢复方法，希望对大家有所帮助，如果大家有任何疑问请给我留言，小编会及时回复大家的。在此也非常感谢大家对我们网站的支持！





### Percona  mongod备份工具

Percona Backup for MongoDB文档



https://www.percona.com/doc/percona-backup-mongodb/index.html



Percona Backup for MongoDB是一种分布式，低影响的解决方案，用于实现MongoDB分片群集和副本集的一致备份。

启用[MongoDB复制的](https://docs.mongodb.com/manual/replication/)Percona Backup for MongoDB支持[Percona Server for MongoDB](https://www.percona.com/software/mongo-database/percona-server-for-mongodb) 和MongoDB Community v3.6或更高版本。

限制：

Percona Backup for MongoDB在独立的MongoDB实例上不起作用。这是因为Percona Backup for MongoDB需要一个操作[日志](https://www.percona.com/doc/percona-backup-mongodb/glossary.html#term-oplog)来保证备份的一致性。Oplog在启用复制的节点上可用。只能在副本集以及分片集群上进行备份。



MongoDB文档：将独立版本转换为副本集

https://docs.mongodb.com/manual/tutorial/convert-standalone-to-replica-set/



```
http://www.dbapub.cn/2019/11/20/Percona%20for%20MongoDB%E4%B8%8A%E6%89%8B/

Hot Backup
Percona MongoDB 3.2开始默认支持WiredTiger引擎在线热备份，需要管理员权限在admin数据库下执行createBackup，并指定备份目录

备份恢复原理
备份原理：

首先启动一个后台检测的进程，实时检测MongoDB Oplog的变化，将新产生的日志写入到日志文件WiredTiger.backup中
复制MongoDB dbpath目录到指定的备份目录中
恢复原理：

将WiredTiger.backup日志进行回放，将操作日志应用到WiredTiger引擎里，最终得到一致性快照恢复
把备份目录里的数据文件直接拷贝到dbpath下，然后启动MongoDB
```



















