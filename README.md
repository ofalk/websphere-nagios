WAS Agent
=========

A network tool for WebSphere Application Server monitoring, that provides performance statistics in a suitable format for [Nagios][nagios].

* [Features](#features)
* [Concepts](#concepts)
* [Prerequisites](#prerequisites)
    * [General settings](#general-settings)
    * [PMI settings](#pmi-settings)
* [Installing WAS Agent](#installing-was-agent)
    * [Build](#build)
    * [Installation](#installation)
    * [Configuration](#configuration)
* [Using WAS Agent](#using-was-agent)
    * [Starting the agent](#starting-the-agent)
    * [First test] (#first-test)
    * [Running queries](#running-queries)
    * [Options](#options)

Features
--------

Current features are:

 * JVM heap monitoring
 * Server thread pools monitoring
 * Transactions monitoring
 * JDBC datasources monitoring
 * JMS connection factories monitoring
 * SIB queues depth monitoring
 * HTTP sessions monitoring
 * Servlets service time monitoring
 * Clustering support

Concepts
--------

WAS Agent relies on the use of WebSphere Performance Monitoring infrastructure (PMI), as well as the regular JMX API. The agent embedds a small Jetty container, and the monitoring itself is made through simple HTTP requests. This approach allows short response times for monitoring queries, and a very low resource consumption.

Prerequisites
-------------

### General settings

You just need to install an IBM 1.6 JRE on each host you plan to run the agent.

### PMI settings

For each JVM you want to monitor, you have to enable the following statistics:

    JVM Runtime.HeapSize
    JVM Runtime.ProcessCpuUsage
    JVM Runtime.UsedMemory
    Thread Pools.ActiveCount
    Thread Pools.PoolSize
    Transaction Manager.ActiveCount
    JDBC Connection Pools.FreePoolSize
    JDBC Connection Pools.PoolSize
    JDBC Connection Pools.WaitingThreadCount
    JCA Connection Pools.FreePoolSize
    JCA Connection Pools.PoolSize
    JCA Connection Pools.WaitingThreadCount
    Servlet Session Manager.LiveCount
    Web Applications.ServiceTime

For WAS 7.0 and WAS 8.x only, you can also enable this one:

    Thread Pools.ConcurrentHungThreadCount

You can find below a sample Jython script to set the appropriate configuration with wsadmin. It works with WAS 6.1, 7.0 and 8.x:

```python
# wasagent PMI settings script

# Change these values
node_name = 'hydre2'
server_name = 'h2srv1'

# PMI statistics values
stats = { 'jvmRuntimeModule': '1,3,5',
          'threadPoolModule': '3,4,8',
          'transactionModule': '4',
          'connectionPoolModule': '5,6,7',
          'j2cModule': '5,6,7',
          'servletSessionsModule': '7',
          'webAppModule': '13' }

# Recursive function to configure the whole PMI subtree
def set_pmimodules(module, value):
    AdminConfig.modify(module, [['enable', value]])
    pmimodules = AdminConfig.showAttribute(module, 'pmimodules')
    if pmimodules != '[]':
        pmimodules = pmimodules[1:-1]
        pmimodules = pmimodules.split(' ')
        for pmimodule in pmimodules:
            set_pmimodules(pmimodule, value)

# Script starts here
import string

cell_name = AdminControl.getCell()
node_id = AdminConfig.getid('/Cell:%s/Node:%s' % (cell_name, node_name))
server_id = AdminConfig.getid('/Cell:%s/Node:%s/Server:%s' % (cell_name, node_name, server_name))

if len(node_id) == 0:
    raise Exception('invalid node name \'%s\'' % node_name)
if len(server_id) == 0:
    raise Exception('invalid server name \'%s\'' % server_name)

pmi_service = AdminConfig.list('PMIService', server_id)
pmi_module =  AdminConfig.list('PMIModule', server_id)

print '\nSetting custom statistic set level...'
params = [['enable', 'true'], ['statisticSet', 'custom']]
AdminConfig.modify(pmi_service, params)
print 'ok.'

modules = AdminConfig.showAttribute(pmi_module, 'pmimodules')
modules = modules[1:-1]
modules = modules.split(' ')

print '\nEnabling specific PMI counters...'
for key in stats.keys():
    for module in modules:
        if AdminConfig.showAttribute(module, 'moduleName') == key:
           print string.ljust(' . %s:' % key, 25), string.ljust(stats[key], 0)
           set_pmimodules(module, stats[key])
print 'ok.'

print '\nSaving changes...'
AdminConfig.save()
print 'ok.'
```

If you want to make runtime tests, you can use the following snippets:

```python
# wasagent PMI settings script
# Use only with WAS 8.x and 7.0 versions

# Change these values
node_name = 'hydre2'
server_name = 'h2srv1'

# Script starts here
perf_name = AdminControl.completeObjectName('type=Perf,node=%s,process=%s,*' % (node_name, server_name))
signature  = ['java.lang.String', 'java.lang.Boolean']

# JVM settings
params = ['jvmRuntimeModule=1,3,5', java.lang.Boolean('true')]
AdminControl.invoke(perf_name, 'setCustomSetString', params, signature)

# Thread pools settings
params = ['threadPoolModule=3,4,8', java.lang.Boolean('true')]
AdminControl.invoke(perf_name, 'setCustomSetString', params, signature)

# Transactions settings
params = ['transactionModule=4', java.lang.Boolean('true')]
AdminControl.invoke(perf_name, 'setCustomSetString', params, signature)

# JDBC connection pools setting
params = ['connectionPoolModule=5,6,7', java.lang.Boolean('true')]
AdminControl.invoke(perf_name, 'setCustomSetString', params, signature)

# JMS connection factories settings
params = ['j2cModule=5,6,7', java.lang.Boolean('true')]
AdminControl.invoke(perf_name, 'setCustomSetString', params, signature)

# HTTP sessions settings
params = ['servletSessionsModule=7', java.lang.Boolean('true')]
AdminControl.invoke(perf_name, 'setCustomSetString', params, signature)

# Servlets settings
params = ['webAppModule=13', java.lang.Boolean('true')]
AdminControl.invoke(perf_name, 'setCustomSetString', params, signature)

# Uncomment to persist changes
#
#AdminControl.invoke(perf_name, 'savePMIConfiguration')
```

```python
# wasagent PMI settings script
# Use only with WAS 6.1 version

# Change these values
node_name = 'hydre2'
server_name = 'h2srv1'

# Script starts here
perf_name = AdminControl.completeObjectName('type=Perf,node=%s,process=%s,*' % (node_name, server_name))
perf_mbean = AdminControl.makeObjectName(perf_name)

signature  = ['java.lang.String', 'java.lang.Boolean']

# JVM settings
params = ['jvmRuntimeModule=1,3,5', java.lang.Boolean('true')]
AdminControl.invoke_jmx(perf_mbean, 'setCustomSetString', params, signature)

# Thread pools settings
params = ['threadPoolModule=3,4', java.lang.Boolean('true')]
AdminControl.invoke_jmx(perf_mbean, 'setCustomSetString', params, signature)

# Transactions settings
params = ['transactionModule=4', java.lang.Boolean('true')]
AdminControl.invoke_jmx(perf_mbean, 'setCustomSetString', params, signature)

# JDBC connection pools setting
params = ['connectionPoolModule=5,6,7', java.lang.Boolean('true')]
AdminControl.invoke_jmx(perf_mbean, 'setCustomSetString', params, signature)

# JMS connection factories settings
params = ['j2cModule=5,6,7', java.lang.Boolean('true')]
AdminControl.invoke_jmx(perf_mbean, 'setCustomSetString', params, signature)

# HTTP sessions settings
params = ['servletSessionsModule=7', java.lang.Boolean('true')]
AdminControl.invoke_jmx(perf_mbean, 'setCustomSetString', params, signature)

# Servlets settings
params = ['webAppModule=13', java.lang.Boolean('true')]
AdminControl.invoke_jmx(perf_mbean, 'setCustomSetString', params, signature)

# Uncomment to persist changes
#
#AdminControl.invoke(perf_name, 'savePMIConfiguration')
```

Installing WAS Agent
--------------------

### Build

Clone the project repository:

    git clone https://github.com/yannlambret/websphere-nagios.git

The two directories we are interested in are 'src' and 'lib'. Copy the WebSphere admin client jar in the lib directory. You can find the required file in the 'runtimes' directory of your product installation.

WAS 8.0:

`${WAS_INSTALL_ROOT}/runtimes/com.ibm.ws.admin.client_8.0.0.jar`

WAS 7.0:

`${WAS_INSTALL_ROOT}/runtimes/com.ibm.ws.admin.client_7.0.0.jar`

WAS 6.1:

`${WAS_INSTALL_ROOT}/runtimes/com.ibm.ws.admin.client_6.1.0.jar`

You can use Apache Ant and the provided 'build.xml' file to build the plugin.

### Installation

For WAS 7.0 and WAS 8.x, you need one instance of the agent per cell, which you will typically deploy on the dmgr host. For WAS 6.1, you need one instance of the agent per node.

Assuming you are using a root directory named 'wasagent', the layout will be as follows:

    wasagent
    |-- lib
    |   |-- com.ibm.ws.admin.client_X.X.X.jar
    |   |-- jetty-servlet-7.6.2.v20120308.jar
    |   `-- servlet-api-2.5.jar
    |-- run.sh
    |-- wasagent.jar
    `-- websphere.properties

Just copy appropriate files and directories from the repository into the 'wasagent' directory.

### Configuration

The 'websphere.properties' file contains the basic informations used to connect to a WebSphere Application Server. You have to set the contents of this file according to your environment.

```bash
# WAS Agent properties file
#
# These credentials are used to connect to each
# target WAS instance of the cell. The user has
# to be mapped to the 'monitor' role, no need to
# use an administrative account.
#
username=
password=

# These keystores are used to establish a secured connection beetween
# the agent and the target WAS instance. "${USER_INSTALL_ROOT}" should
# be replaced by the dmgr profile path of the cell for WAS 7.0 and 8.x,
# or by the nodeagent profile path of the node for WAS 6.1.
#
# PKCS12 keystores sample config
#
javax.net.ssl.trustStore=${USER_INSTALL_ROOT}/etc/trust.p12
javax.net.ssl.trustStorePassword=WebAS
javax.net.ssl.trustStoreType=PKCS12
javax.net.ssl.keyStore=${USER_INSTALL_ROOT}/etc/key.p12
javax.net.ssl.keyStorePassword=WebAS
javax.net.ssl.keyStoreType=PKCS12
#
# JKS keystores sample config (default keystore type is JKS)
#
#javax.net.ssl.trustStore=${USER_INSTALL_ROOT}/etc/DummyClientTrustFile.jks
#javax.net.ssl.trustStorePassword=WebAS
#javax.net.ssl.keyStore=${USER_INSTALL_ROOT}/etc/DummyClientKeyFile.jks
#javax.net.ssl.keyStorePassword=WebAS
```

Using WAS Agent
---------------

### Starting the agent

Amend the 'run.sh' script to set the path of your JRE installation, and type:

    ./run.sh

This script is provided for testing purpose only, so you will have to write your own init script.

### First test

Assuming that you want to monitor a WAS instance running on a host called 'hydre2' and listening on its default SOAP connector (8880), run the provided script as follows:

    ./wasagent.sh 'hostname=hydre2&port=8880&jvm=heapUsed,90,95'

You should get something like:

    h2srv1: status OK|jvm-heapSize=278MB;;;0;512 jvm-heapUsed=133MB;;;0;512 jvm-cpu=0%;;;0;100

If the plugin is not able to connect to the target server, you can kill the plugin process, then add the following jars to the lib directory:

WAS 8.0:

    ${WAS_INSTALL_ROOT}/runtimes/com.ibm.ws.webservices.thinclient_8.0.0.jar
    ${WAS_INSTALL_ROOT}/plugins/com.ibm.ws.security.crypto.jar

WAS 7.0:

    ${WAS_INSTALL_ROOT}/runtimes/com.ibm.ws.webservices.thinclient_7.0.0.jar
    ${WAS_INSTALL_ROOT}/plugins/com.ibm.ws.security.crypto.jar

WAS 6.1:

    ${WAS_INSTALL_ROOT}/runtimes/com.ibm.ws.webservices.thinclient_6.1.0.jar
    ${WAS_INSTALL_ROOT}/plugins/com.ibm.ws.security.crypto_6.1.0.jar

### Running queries

Once the plugin is running, you can invoke it for instance with wget. In the example below, we send a monitoring request to a WebSphere instance running on 'hydre2' host, with a SOAP connector listening on port 18047:

```
wget -q -O - 'http://localhost:9090/wasagent/WASAgent?hostname=hydre2&port=18047'
```

The above command produces the following output:

```
0|h2srv1: status OK|
```

The first character (0) is the Nagios check return code. The section after the '|' gives the WebSphere instance name, and the global status of the instance based on the performance tests. In this case, no test has been made so the status is 'OK' (return code 0).

Let's try to get information about the JVM heap usage by adding jvm=heapUsed,80,90 to the request parameters. From now on, we will be using POST requests:

```
wget -q -O - 'http://localhost:9090/wasagent/WASAgent' --post-data='hostname=hydre2&port=18047&jvm=heapUsed,90,95'
```

The two numerical values at the end are the warning and critical thresholds for the memory usage, we will get back on this later.

The command output is:

```
0|h2srv1: status OK|jvm-heapSize=279MB;;;0;512 jvm-heapUsed=96MB;;;0;512 jvm-cpu=0%;;;0;100
```

As you can see, we get the current heap size, the maximum heap size, the amount of memory currently used by the server and the JVM CPU usage.

Let's try to change the warning threshold value to '10':

```
wget -q -O - 'http://localhost:9090/wasagent/WASAgent' --post-data='hostname=hydre2&port=18047&jvm=heapUsed,10,95'
```

We get this:

```
1|h2srv1: status WARNING - memory used (100/512)|jvm-heapSize=279MB;;;0;512 jvm-heapUsed=100MB;;;0;512 jvm-cpu=0%;;;0;100
```

A warning alert is raised by the test, as the ratio used memory / maximum memory is superior to 10% (our warning threshold).

You can group as many options as you want in the same request:

```
wget -q -O - 'http://localhost:9090/wasagent/WASAgent' --post-data='hostname=hydre2&port=18047&jvm=heapUsed,10,90&thread-pool=Default,90,95|ORB.thread.pool,90,95'
```

This way you get different metrics with a single test only:

```
1|h2srv1: status WARNING - memory used (106/512)|jvm-heapSize=279MB;;;0;512 jvm-heapUsed=106MB;;;0;512 jvm-cpu=0%;;;0;100 pool-Default-size=7;;;0;20 pool-Default-activeCount=3;;;0;20 pool-ORB.thread.pool-size=0;;;0;50 pool-ORB.thread.pool-activeCount=0;;;0;50
```

If you also change the warning threshold to '10' for the Default thread pool, the message output will change to this:

```
1|h2srv1: status WARNING - memory used (94/512) - thread pool active count: Default (3/20)|jvm-heapSize=279MB;;;0;512 jvm-heapUsed=94MB;;;0;512 jvm-cpu=0%;;;0;100 pool-Default-size=7;;;0;20 pool-Default-activeCount=3;;;0;20 pool-ORB.thread.pool-size=0;;;0;50 pool-ORB.thread.pool-activeCount=0;;;0;50
```

### Options

Here is a summary of the available options:

#### hostname (mandatory)

The hostname of the WAS instance you want to monitor.

#### port (mandatory)

The SOAP connector of the WAS instance you want to monitor.

#### jvm (optional)

* Invocation

```
jvm=heapUsed,90,95
```

90 is the warning threshold for the JVM heap usage.
95 is the critical threshold for the JVM heap usage.

These values are compared to the ratio used memory / max memory, i.e. the currently amount of memory used by the application server divided by the JVM heap max size (see below).

* Output

```
jvm-heapSize=256MB;;;0;512 jvm-heapUsed=184MB;;;0;512 jvm-cpu=1%;;;0;100
```

The first part of the output gives the current JVM heap size (256MB in the example above). So it will be greater than or equal to the JVM Xms option value. The heap min size is always set to 0, even if the Xms option is set. The heap max size is equal to the Xmx option value.

The second part of the ouput gives the amount of memory currently used by the application server (184MB in the example above). The min value is always set to 0, and the max value is equal to the Xmx option value.

The third part of the output gives the JVM CPU usage, expressed as a percentage.

#### thread-pool (optional)

* Invocation

```
thread-pool=<pool 1>,w,c|<pool 2>,w,c|...|<pool N>,w,c
```

In this generic example, 'pool 1' ... 'pool N' would be pool names, and 'w' and 'c' would be warning and critical thresholds, expressed as percentages.

So you could have for instance:

```
thread-pool=WebContainer,80,90|ORB.thread.pool,90,95
```

For each pool, the ratio active thread count / max thread count is compared to the specified thresholds.

You can also call the thread-pool test with a wildcard:

```
thread-pool=*,90,95
```

Note that the 'warning' and 'critical' thresholds will be the same for all thread pools though.

* Output

```
pool-WebContainer-size=4;;;0;50 pool-WebContainer-activeCount=1;;;0;50 pool-ORB.thread.pool-size=2;;;0;50 pool-ORB.thread.pool-activeCount=1;;;0;50
```

For each pool, the first part of the output gives the current pool size. The min value is always set to 0, the max value is the max pool size value.

The second part of the ouput gives the current active thread count for the given pool. The min value is always set to 0, the max value is the max pool size value.

If hung thread detection is enabled in PMI and there are some hung threads in the monitored pool, the plugin will raise a warning alert if the number of hung threads exceeds 10% of the total pool capacity, and a critical alert if this number exceeds 20% of the total pool capacity. There will also be an additional metric to graph the hung thread count. You could have for instance:

```
h2srv1: status WARNING - 'WebContainer' thread pool hung count (5/50)|pool-WebContainer-size=7;;;0;50 pool-WebContainer-activeCount=7;;;0;50 pool-WebContainer-hungCount=5;;;0;50
```

#### jta (optional)

* Invocation

```
jta=activeCount,15,30
```

15 is the warning threshold for the transaction active count. 30 is the critical threshold for the transaction active count.

These values are arbitrary values that are compared to the active transaction count of your application server.

* Output

```
jta-activeCount=3
```

The output gives the current active transaction count of your application server.

#### jdbc (optional)

* Invocation

```
jdbc=<datasource 1>,w,c|<datasource 2>,w,c|...|<datasource N>,w,c
```

In this generic example, 'datasource 1' ... 'datasource N' would be jdbc datasource names, and 'w' and 'c' would be warning and critical thresholds.

So you could have for instance:

```
jdbc=jdbc/h2srv1_ds,90,95
```

For each datasource, the active thread count / max thread count ratio is compared to the specified thresholds.

You can also call the jdbc test with a wildcard:

```
jdbc=*,90,95
```

Note that the 'warning' and 'critical' thresholds will be the same for all datasources though.

* Output

```
jdbc-jdbc/h2srv1_ds-size=5;;;0;10 jdbc-jdbc/h2srv1_ds-activeCount=2;;;0;10 jdbc-jdbc/h2srv1_ds-waitingThreadCount=0
```

For each datasource, the first part of the output gives the current connection pool size. The min value is always set to 0, the max value is the max connection pool size value.

The second part of the ouput gives the current active jdbc connection count for the given datasource. The min value is always set to 0, the max value is the max connection pool size value.

The third part of the output gives the current count of threads waiting for a connection to the database.
    
#### jms (optional)

* Invocation

```
jms=<connection factory 1>,w,c|<connection factory 2>,w,c|...|<connection factory N>,w,c
```

In this generic example, 'connection factory 1' ... 'connection factory N' would be connection factories JNDI names, so you could have for instance:

```
jms=jms/h2srv1_qcf,90,95
```

For each connection factory, the active thread count / max thread count ratio is compared to the specified thresholds.

You can also call the jms test with a wildcard:

```
jms=*,90,95
```

Note that the 'warning' and 'critical' thresholds will be the same for all factories though.

* Output

```
jms-jms/h2srv1_qcf-size=0;;;0;150 jms-jms/h2srv1_qcf-activeCount=0;;;0;150 jms-jms/h2srv1_qcf-waitingThreadCount=0
```

For each factory, the first part of the output gives the current pool size. The min value is always set to 0, the max value is the max pool size value.

The second part of the ouput gives the current active thread count for the given factory. The min value is always set to 0, the max value is the max pool size value.

If you are using JMS 1.0 listeners, the plugin will raise an warning alert if some of them are stopped. The output would look like this :

```
h2srv1: status WARNING - stopped listeners: 3|jms-jms/h2srv1_qcf-size=0;;;0;150 jms-jms/h2srv1_qcf-activeCount=0;;;0;150 jms-jms/h2srv1_qcf-waitingThreadCount=0
```

#### sib-queue (optional)

* Invocation

```
sib-queue=<queue 1>,w,c|<queue 2>,w,c|...|<queue N>,w,c
```

In this generic example, 'queue 1' ... 'queue N' would be queue identifiers, and 'w' and 'c' would be warning and critical thresholds. The queue name is the WebSphere identifier (don't use JNDI name).

For each queue, the current queue depth is compared to the specified thresholds.

You can also call the sib-queue test with a wildcard:

```
sib-queue=*,10,20
```

Notice the 'warning' and 'critical' thresholds will be the same for all queues though.

* Output

```
sib-queue-testQueue=2
```

The output gives the current depth for each queue specified by the user.

#### application (optional)

* Invocation

```
application=<app 1>,w,c|<app 2>,w,c|...|<app N>,w,c
```

In this generic example, 'app 1' ... 'app N' would be web application names, and 'w' and 'c' would be warning and critical thresholds. The web application name is based on the logical application name on one hand, and on the web module name on the other hand:

```
<logical application name>#<web module name>
```

So you could have for instance:

```
application=app1#app1.war,200,250
```

For each application, the current active HTTP session count is compared to the specified thresholds.

You can also call the application test with a wildcard character:

```
application=*,150,200
```

Note that the 'warning' and 'critical' thresholds will be the same for all applications though.

* Output

```
app-app1#app1.war=11
```

The output gives the current active HTTP session count for each application specified by the user.

KNOWN ISSUE:

If you're getting a runtime exception about the missing symbol 'WSSessionManagementStats.NAME', it's because of a bug in the IBM admin client jar (see [here](http://www-01.ibm.com/support/docview.wss?uid=swg1PK99283) for reference).

You can solve this issue by using a more recent version of the client (even if it doesn't match the target application server version), or you can checkout the source and modify the ApplicationTest class (line 85) by replacing the constant by its actual value:

```
WSStats stats = proxy.getStats("servletSessionsModule");
```

#### servlet (optional)

* Invocation

```
servlet=<servlet 1>,w,c|<servlet 2>,w,c|...|<servlet N>,w,c
```

In this generic example, 'servlet 1' ... 'servlet N' would be servlet names, and 'w' and 'c' would be warning and critical thresholds. The servlet name is based on the logical application name, the web module name and the servlet name:

```
<logical application name>#<web module name>.<servlet name>
```

So you could have for instance:

```
servlet=app1#app1.war.servlet1,50,100
```

For each application, the servlet service time (in milliseconds) is compared to the specified thresholds.

You can also call the servlet test with a wildcard character:

```
servlet=*,50,100
```

Note that the 'warning' and 'critical' thresholds will be the same for all servlets though.

* Output

```
app-app1#app1.war.servlet1=4
```

The output gives the average response time (in milliseconds) of the servlet.

[nagios]: http://www.nagios.org/
