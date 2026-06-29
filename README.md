# vm-health-check
Health check for a virtual machine
The goal is to create a GitHub repository that contains a bash script. 
When the bash script is executed, the bash script confirms the health of a virtual machine by looking at parameters such:

**Metrics tracked:**

1. CPU
2. Disk space/usage
3. Memory
4. Load Average,
5. Uptime etc.

When someone runs "./health_check.sh", it should output for instance:

```
VM HEALTH STATUS
=========================

CPU Usage:        Healthy
Memory Usage:     Healthy
Disk Usage:       Warning
Load Average:     Healthy

Overall Status: WARNING
```

Please note that the bash script should also support a command-line argument named "explain". 
So that when passed, "explain" provides a detailed summary of the health status.

For example, when someone runs "./health_check.sh explain", it should output:

CPU Usage
---------
Current Usage: 18%

Memory
------
Total: 8GB
Used: 3GB
Free: 5GB

Disk
----
Filesystem: /
Used: 72%

Load Average
------------
0.42

Overall Status
--------------
The VM is healthy.
Disk utilization is above 70%.

