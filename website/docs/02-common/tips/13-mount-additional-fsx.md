---
title : "Mount additional FSx Filesystem"
weight : 53
---

Ok, so let's say you want to mount an additional FSx Lustre filesystem, to do this you'll need to modify your lifecycle scripts:  

1. Start by modifying the `lifecycle_script.py` to add your additional FSx filesystems. These can be mounted by adding in lines on [lifecycle_script.py#L153](https://github.com/aws-samples/awsome-distributed-training/blob/78d906651b1de4fb5c068cd157c6d60331c44ad8/1.architectures/5.sagemaker-hyperpod/LifecycleScripts/base-config/lifecycle_script.py#L153) like so. Note you may need to remove the original mount (`/fsx`) lines so your mount paths don't conflict.

```diff
-    fsx_dns_name, fsx_mountname = params.fsx_settings
-    if fsx_dns_name and fsx_mountname:
-        print(f"Mount fsx: {fsx_dns_name}. Mount point: {fsx_mountname}")
-        ExecuteBashScript("./mount_fsx.sh").run(fsx_dns_name, fsx_mountname, "/fsx")
+   ExecuteBashScript("./mount_fsx.sh").run("fs-05dac34e835f2c48f.fsx.us-west-2.amazonaws.com", "4owupbev", "/fsx/home")
+   ExecuteBashScript("./mount_fsx.sh").run("fs-0972ef1ec89bcc14c.fsx.us-west-2.amazonaws.com", "6eoi7bev", "/fsx/mount2")
+   ExecuteBashScript("./mount_fsx.sh").run("fs-0da5542b6a0808375.fsx.us-west-2.amazonaws.com", "yioi7bev", "/fsx/mount3")
```

2. (Optional) If you changed the `/fsx` mount, you'll need to modify `fsx_ubuntu.sh` to move the home directory from `/home/ubuntu` to `/fsx/home/ubuntu`:

```diff
#!/bin/bash

# move the ubuntu user to the shared /fsx filesystem
- if [ -d "/fsx/ubuntu" ]; then
-    sudo usermod -d /fsx/ubuntu ubuntu
- elif [ -d "/fsx" ]; then
-    sudo usermod -m -d /fsx/ubuntu ubuntu
- fi
+ if [ -d "/fsx/home/ubuntu" ]; then
+    sudo usermod -d /fsx/home/ubuntu ubuntu
+ elif [ -d "/fsx/home" ]; then
+    sudo usermod -m -d /fsx/home/ubuntu ubuntu
+ fi
```

3. Next upload these files and create your cluster. You should see the changes reflected in `df -h`. Voila!

```bash
$ df -h
...
10.1.103.128@tcp:/4owupbev  4.5T   85G  4.4T   2% /fsx/home
10.1.103.128@tcp:/6eoi7bev  1.2T   85G  1.2T   1% /fsx/mount2
10.1.103.128@tcp:/yioi7bev  1.2T   85G  1.2T   1% /fsx/mount3
```