# Backhaul Installer

<br>
TCP Configuration > Enable<br>
TCP Multiplexing Configuration > Enable
<br><br>

<div align="right">
 - این پروژه جدید است و فعلا درحال گسترش و رفع باگ است (لطفا فعلا از این پروژه استفاده نکنید)
</div>
<div align="left">

## Automatic Installation

</div>
<div align="right">
<br>
 - کد زیر را در سرور اوبونتو خود Past کنید
<br><br>
</div>
<div align="left">

```
sudo wget -4 https://raw.githubusercontent.com/amirmbn/Backhaul-Installer/main/backhaul_install.sh && sudo chmod +x backhaul_install.sh && sudo ./backhaul_install.sh
```
</div>
<div align="right">
<br>
 - برای بررسی وضعیت سرویس از کد زیر استفاده کنید
<br><br>
</div>
<div align="left">

```
sudo systemctl status backhaul.service
```
</div>
<div align="right">
<br>
 - برای بررسی آخرین لاگ های backhaul از کد زیر استفاده کنید
<br><br>
</div>
<div align="left">

```
journalctl -u backhaul.service -e -f
```
</div>
<div align="right">
<br><br>
<a href="https://github.com/Musixal/Backhaul" target="_blank">سورس اصلی پروژه</a>
</div>
