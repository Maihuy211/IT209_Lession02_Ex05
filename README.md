# Bài 5: Quản lý quyền sở hữu thư mục Web (Directory Permission Management)

## 1. Mục tiêu

- Hiểu cơ chế `chown` (đổi owner/group) và `chmod` (đổi quyền rwx) trên Linux.
- Setup phân quyền tối ưu cho thư mục web tĩnh `/var/www/ptit-web/` sao cho:
  - User `devops` (owner) **đọc + ghi** được mã nguồn **không cần sudo/root**.
  - Service Nginx (chạy dưới user `www-data`, thuộc nhóm `www-data`) **đọc** được để serve web tĩnh.
  - User khác **không có quyền** (hoặc chỉ đọc) → an toàn, không lỗi `403 Forbidden`.

## 2. Bối cảnh / Hiện trạng ban đầu

Thư mục `/var/www/ptit-web/` đang thuộc `root:root`, user `devops` không sửa được file:

```bash
ls -la /var/www/ptit-web/
# Output mẫu TRƯỚC khi fix:
# total 12
# drwxr-xr-x 3 root root 4096 ... .
# drwxr-xr-x 3 root root 4096 ... ..
# drwxr-xr-x 2 root root 4096 ... html
# -rw-r--r-- 1 root root  123 ... html/index.html

id devops
# uid=1001(devops) gid=1001(devops) groups=1001(devops)

ps aux | grep nginx
# root ... nginx: master process
# www-data ... nginx: worker process   <- worker chạy bằng www-data

# Thử ghi bằng devops (THẤT BẠI):
sudo -u devops bash -c 'echo "Update" >> /var/www/ptit-web/html/index.html'
# bash: /var/www/ptit-web/html/index.html: Permission denied
```

## 3. Các bước thực hiện (làm trong folder `bai5`)

> 2 script đã làm sẵn: `fix-permissions.sh` (fix) và `verify.sh` (kiểm tra).

### Bước 0 — Chuẩn bị (chỉ làm 1 lần trên máy lab/VM Ubuntu)

```bash
# Tạo user devops nếu chưa có
sudo adduser devops
id devops

# Tạo cấu trúc web demo nếu chưa có
sudo mkdir -p /var/www/ptit-web/html
echo "<h1>PTIT Web - Hello</h1>" | sudo tee /var/www/ptit-web/html/index.html

# Cài + bật nginx nếu chưa có
sudo apt update && sudo apt install -y nginx
sudo systemctl enable --now nginx
```

### Bước 1 — Đổi owner về `devops`, group về `www-data` (đệ quy)

```bash
sudo chown -R devops:www-data /var/www/ptit-web/
```

Giải thích:
- `chown` = change owner. `-R` = đệ quy toàn bộ file + subfolder.
- `devops:www-data` = owner là `devops`, group là `www-data` (nhóm chạy của Nginx).
- Sau lệnh này, `devops` là chủ sở hữu, Nginx (member của `www-data`) được quyền group.

### Bước 2 — Phân quyền `chmod` tối ưu cho web tĩnh

Quy tắc:
- **File:** `640` = `rw-r-----` (owner `rw`, group `r`, other `---`)
- **Thư mục:** `750` = `rwxr-x---` (owner `rwx`, group `r-x`, other `---`)
- Lý do thư mục cần `x`: `x` trên directory = quyền traverse/`cd` vào. Nếu dir chỉ `r` mà không `x`, Nginx sẽ `403 Forbidden` dù file là `644`.

```bash
# Thư mục: 750
sudo find /var/www/ptit-web/ -type d -exec chmod 750 {} \;

# File: 640
sudo find /var/www/ptit-web/ -type f -exec chmod 640 {} \;
```

> Biến thể: nếu muốn public cho phép other đọc (ít bảo mật hơn nhưng phổ biến cho web tĩnh):
> - dir `755` (`rwxr-xr-x`), file `644` (`rw-r--r--`).
> - Lệnh: `sudo chmod -R 755 /var/www/ptit-web` rồi fix file về `644`.
> - Bài này chọn `750/640` vì đúng ràng buộc *"người dùng khác không có quyền hoặc chỉ được đọc"* + an toàn nhất mà Nginx vẫn đọc được qua group.

> Vì sao KHÔNG dùng `777` / `666`? Cho phép ghi public → ai cũng sửa web được, Nginx vẫn chạy nhưng mất an toàn hoàn toàn.

### Bước 3 — Chống lỗi 403 Forbidden của Nginx

Ngoài quyền trong `/var/www/ptit-web`, Nginx cần quyền `x` trên các thư mục cha để đi tới web root:

```bash
sudo chmod 755 /var/www
sudo nginx -t
sudo systemctl reload nginx
```

Kiểm tra worker đang chạy user nào:

```bash
ps aux | grep nginx
# phải thấy `www-data` ở worker process
```

## 4. Kiểm tra (theo yêu cầu đề bài)

### Check 1 — `ls -la /var/www/ptit-web/`

```bash
ls -la /var/www/ptit-web/
ls -l /var/www/ptit-web/html/index.html
```

**Kết quả đầu ra mẫu SAU khi fix (đạt yêu cầu):**

```text
total 12
drwxr-x--- 3 devops www-data 4096 ... .
drwxr-xr-x 3 root   root     4096 ... ..
drwxr-x--- 2 devops www-data 4096 ... html
-rw-r----- 1 devops www-data  123 ... html/index.html

$ stat -c '%U:%G %a %n' /var/www/ptit-web/html/index.html
devops:www-data 640 /var/www/ptit-web/html/index.html
```

Đọc bảng quyền:
- `d rwx r-x ---` = dir `750`: `devops` full, `www-data` đọc + traverse, other none.
- `- rw- r-- ---` = file `640`: `devops` đọc/ghi, `www-data` chỉ đọc, other none.

### Check 2 — Ghi file bằng user `devops` KHÔNG dùng sudo (phải thành công)

```bash
# Cách 1: đăng nhập trực tiếp bằng devops rồi chạy (không sudo):
su - devops
whoami  # -> devops
echo "Update" >> /var/www/ptit-web/html/index.html
echo $?  # -> 0 là thành công
tail -n 5 /var/www/ptit-web/html/index.html
# phải thấy dòng "Update" mới thêm ở cuối

# Cách 2: từ user khác, giả lập quyền devops (dùng để demo/chấm bài):
sudo -u devops bash -c 'echo "Update" >> /var/www/ptit-web/html/index.html && echo "GHI THANH CONG (khong can sudo)"'
tail -n 5 /var/www/ptit-web/html/index.html
```

Output mong đợi:

```text
GHI THANH CONG (khong can sudo)
<h1>PTIT Web - Hello</h1>
Update
```

### Check 3 — Web hiển thị bình thường, không 403

```bash
sudo nginx -t
# nginx: configuration file /etc/nginx/nginx.conf test is successful

curl -s -o /dev/null -w "HTTP code: %{http_code}\n" http://localhost/
# HTTP code: 200   <- 200 là OK, 403 là FAIL

curl -s http://localhost/ | tail -n 5
# phải thấy nội dung mới có chữ "Update"

sudo grep -i "forbidden\|denied" /var/log/nginx/error.log | tail -n 5
# không có dòng lỗi mới -> OK
```

Mở trình duyệt: `http://<IP-server>/` → thấy nội dung `index.html` mới, không báo `403 Forbidden`.

## 5. Chạy nhanh bằng script (1 lệnh)

```bash
cd bai5
chmod +x fix-permissions.sh verify.sh
./fix-permissions.sh
./verify.sh
```

`fix-permissions.sh` làm: `chown -R devops:www-data` → `find ... -type d chmod 750` → `find ... -type f chmod 640` → `nginx -t + reload` → `ls -la` kết quả.

`verify.sh` làm đúng 3 check trên: `ls -la` + `sudo -u devops echo Update >> index.html` + `curl check 200`.

## 6. Tổng kết nộp bài

| Yêu cầu | Lệnh | Kết quả đạt |
|---|---|---|
| Owner `devops`, group `www-data` đệ quy | `sudo chown -R devops:www-data /var/www/ptit-web/` | `ls -la` hiện `devops www-data` |
| Owner `rw`, group `r`, other none | `find ... -type d chmod 750` + `-type f chmod 640` | `stat` hiện `640/750` |
| `devops` ghi không `sudo` | `echo "Update" >> /var/www/ptit-web/html/index.html` (khi là `devops`) | Exit `0`, file có dòng `Update` |
| Nginx không `403` | `curl -w "%{http_code}" http://localhost/` | `200`, web hiện nội dung mới |

## 7. Cấu trúc folder `bai5`

```text
bai5/
  README.md            <- báo cáo này (để nộp)
  fix-permissions.sh   <- script phân quyền (chown + chmod + reload nginx)
  verify.sh            <- script kiểm tra (ls -la + ghi file devops + curl 200)
```
