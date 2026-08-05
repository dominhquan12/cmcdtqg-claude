# Chuyển từ Docker Desktop sang Docker Engine trong WSL2

Bối cảnh: máy đang chạy Docker Desktop tốn tài nguyên, muốn thay bằng Docker Engine chạy trực tiếp
trong WSL2 (nhẹ hơn, không có lớp GUI/VM riêng của Desktop). Máy là Windows 10 Pro, `wsl.exe` trên máy
là bản inbox cũ (không nhận `--version`, `--web-download`), và có dấu hiệu chính sách hệ thống hạn chế
Windows Update/Microsoft Store — nên các cách cài chuẩn qua Store đều thất bại, phải đi vòng.

## 1. Kiểm tra tình trạng WSL ban đầu

```powershell
wsl -l -v
```

Kết quả: chỉ có 2 distro nội bộ của Docker Desktop (`docker-desktop`, `docker-desktop-data`), chưa có
distro Linux thật nào để cài Docker Engine vào.

## 2. Thử cài Ubuntu qua `wsl --install` — thất bại (Store bị chặn)

```powershell
wsl --install -d Ubuntu
```

Lỗi:
```
An error occurred during installation. Distribution Name: 'Ubuntu' Error Code: 0x80070005
```

`0x80070005` = Access Denied. Kiểm tra thêm:

```powershell
wsl --status
```

Log báo: *"automatic updates cannot occur due to your system settings"* — dấu hiệu chính sách công ty/
Group Policy chặn Windows Update/Store, khiến việc cài distro qua Store bị từ chối quyền.

## 3. Thử bypass Store bằng `--web-download` — thất bại (wsl.exe quá cũ)

```powershell
wsl --install -d Ubuntu --web-download
```

Lỗi:
```
--install: unrecognized option: web-download
```

Xác nhận `wsl.exe` trên máy là bản inbox cũ, thiếu các flag mới (`--version` cũng báo "Invalid command
line option" tương tự). Không thể update qua `wsl --update` vì cùng lý do bị chặn Store.

## 4. Cài Ubuntu bằng cách import rootfs thủ công (không qua Store)

Tải trực tiếp rootfs Ubuntu 22.04 từ cloud-images.ubuntu.com (không qua Microsoft Store):

```powershell
Invoke-WebRequest -Uri "https://cloud-images.ubuntu.com/wsl/jammy/current/ubuntu-jammy-wsl-amd64-ubuntu22.04lts.rootfs.tar.gz" -OutFile "$env:USERPROFILE\ubuntu-rootfs.tar.gz"
```

> Lưu ý: tên file đúng là `...-ubuntu22.04lts.rootfs.tar.gz`, không phải `...-wsl.rootfs.tar.gz` như
> đoán ban đầu — phải kiểm tra listing thư mục `https://cloud-images.ubuntu.com/wsl/jammy/current/` để
> lấy tên chính xác.

Import thành distro WSL2 mới:

```powershell
mkdir "$env:USERPROFILE\WSL\Ubuntu"
wsl --import Ubuntu "$env:USERPROFILE\WSL\Ubuntu" "$env:USERPROFILE\ubuntu-rootfs.tar.gz" --version 2
wsl -d Ubuntu
```

Import thành công, vào được Ubuntu 22.04.5 LTS (kernel `5.10.16.3-microsoft-standard-WSL2`) nhưng ở
user `root` (import không tự tạo user thường).

## 5. Tạo user thường và đặt làm default

Trong shell Ubuntu (đang là root):

```bash
adduser quando
usermod -aG sudo quando
echo -e "[user]\ndefault=quando" | tee /etc/wsl.conf
exit
```

```powershell
wsl --terminate Ubuntu
wsl -d Ubuntu
```

Từ đây vào WSL sẽ là user `quando`, không phải root.

## 6. Cài Docker Engine

```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
```

## 7. Thử bật systemd để daemon tự start — không hỗ trợ

```bash
sudo bash -c 'printf "\n[boot]\nsystemd=true\n" >> /etc/wsl.conf'
```

```powershell
wsl --shutdown
wsl -d Ubuntu
```

```bash
sudo systemctl status docker --no-pager
```

Lỗi: `System has not been booted with systemd as init system (PID 1). Can't operate.` — bản WSL core
này quá cũ để hỗ trợ systemd làm init (khớp với việc `wsl.exe` thiếu các flag mới ở bước 3).

## 8. Thử cơ chế `[boot] command=` (không cần systemd) — cũng không tự chạy được

Xoá phần `[boot] systemd=true`, thay bằng:

```bash
sudo sed -i '/\[boot\]/,/systemd=true/d' /etc/wsl.conf
sudo bash -c 'printf "\n[boot]\ncommand = service docker start\n" >> /etc/wsl.conf'
```

```powershell
wsl --shutdown
wsl -d Ubuntu
```

```bash
sudo service docker status
# * Docker is not running
```

Cơ chế này cũng không tự chạy daemon được trên bản WSL này. Kết luận: phải start Docker bằng tay mỗi
lần mở WSL mới (`sudo service docker start`) — chấp nhận được, vẫn nhẹ hơn Docker Desktop nhiều.

## 9. Start Docker thủ công — daemon start rồi crash ngay

```bash
sudo service docker start
sudo service docker status
# * Docker is not running   (crash ngay sau khi start)
```

Xem log lỗi:

```bash
sudo dockerd
```

Lỗi:
```
failed to start daemon: Error initializing network controller: error obtaining controller instance:
failed to register "bridge" driver: failed to add jump rules to ipv4 NAT table: ...
iptables v1.8.7 (nf_tables): Couldn't load match `addrtype': No such file or directory
```

Nguyên nhân: kernel WSL2 tối giản thiếu module netfilter `xt_addrtype` mà `iptables` ở chế độ
`nf_tables` cần để tạo NAT rule cho Docker bridge network.

## 10. Fix: chuyển iptables sang chế độ legacy

```bash
sudo update-alternatives --set iptables /usr/sbin/iptables-legacy
sudo update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy
sudo service docker start
sudo service docker status
docker run hello-world
```

`iptables-legacy` không cần module `xt_addrtype` cho đường dẫn NAT này → Docker daemon chạy ổn định,
`docker run hello-world` chạy thành công.

## 11. Ghi chú vận hành từ nay

- Docker daemon **không tự start** khi mở WSL (do hạn chế của bản WSL core cũ này) — phải chạy tay:
  ```bash
  sudo service docker start
  ```
  mỗi khi mở terminal WSL mới sau khi máy tắt/`wsl --shutdown`. Có thể tự động hoá bằng cách thêm vào
  cuối `~/.bashrc`:
  ```bash
  echo 'sudo service docker status >/dev/null 2>&1 || sudo service docker start' >> ~/.bashrc
  ```
- Mọi lệnh `docker`/`docker compose` cho project này từ giờ chạy **trong shell Ubuntu WSL**, không phải
  PowerShell/Git Bash trên Windows.
- Repo trên ổ Windows (`E:\DAGORAS\...`) truy cập từ WSL qua mount:
  ```bash
  cd "/mnt/e/DAGORAS/cmcdtqg/project/cmcdtqg.km-ai.api-develop"
  docker compose up -d
  ```
  I/O qua `/mnt/e` chậm hơn filesystem native của WSL, chấp nhận được cho chạy container; nếu build
  image thường xuyên và thấy chậm, có thể xem xét clone repo vào filesystem native của WSL sau.
- Có thể cân nhắc tắt Docker Desktop autostart (hoặc gỡ hẳn) để giải phóng RAM, vì giờ không cần dùng
  Docker Desktop nữa.
