# 📱 Ubuntu Scripts

This repository contains a Bash script designed to streamline the setup of the **Ubuntu** environment for seamless **GitHub usage** on Linux Distro.  

It automates the configuration process, saving time and ensuring a smooth developer experience when working with GitHub via Ubuntu.

---

## 🚀 Getting Started

```bash
bash ubuntu_setup.sh
```

---

---

## Memory Tweaks

To clear buff/cache and swap:

```bash
sudo sh -c 'echo 3 >  /proc/sys/vm/drop_caches'
```

---

---
## Swap Tweaks

Create this configuration file:

```bash
sudo nano /etc/sysctl.d/99-swap-tweaks.conf
```

Add these lines:

```bash
vm.swappiness=50
vm.vfs_cache_pressure=50
vm.dirty_background_ratio=5
vm.dirty_ratio=10
```

Apply changes:

```bash
sudo sysctl --system
```

---
