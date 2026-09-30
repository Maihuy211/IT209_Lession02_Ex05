#!/bin/bash
# Bài 5: Quản lý quyền sở hữu thư mục Web (Directory Permission Management)
# Chạy bằng user có sudo (lần đầu setup). Sau khi chạy xong, user devops
# có thể ghi file mà KHÔNG cần sudo, nginx (www-data) vẫn đọc được -> không 403.
set -e

WEB_ROOT="/var/www/ptit-web"
DEV_USER="devops"
WEB_GROUP="www-data"

echo "=== [1/6] Kiểm tra user và group ==="
id "$DEV_USER"
getent group "$WEB_GROUP"

echo ""
echo "=== [2/6] Hiện trạng trước khi fix (thuộc root) ==="
ls -la "$WEB_ROOT" || true
echo "--- owner hiện tại ---"
stat -c '%U:%G %a %n' "$WEB_ROOT" || true

echo ""
echo "=== [3/6] Đổi owner về devops và group về www-data (đệ quy) ==="
sudo chown -R "$DEV_USER":"$WEB_GROUP" "$WEB_ROOT"

echo ""
echo "=== [4/6] Phân quyền tối ưu cho web tĩnh ==="
echo "-- 4a. Thư mục: 750 (rwxr-x---) -> devops full, www-data rx để traverse, other none"
sudo find "$WEB_ROOT" -type d -exec chmod 750 {} \;
echo "-- 4b. File: 640 (rw-r-----) -> devops rw, www-data r để serve, other none"
sudo find "$WEB_ROOT" -type f -exec chmod 640 {} \;

# Nếu muốn cho phép "other read" (public) thì dùng 755 cho dir và 644 cho file:
#   sudo find "$WEB_ROOT" -type d -exec chmod 755 {} \;
#   sudo find "$WEB_ROOT" -type f -exec chmod 644 {} \;

echo ""
echo "=== [5/6] Đảm bảo Nginx đọc được (tránh 403) ==="
# Nginx cần +x trên mọi thư mục cha để traverse tới WEB_ROOT
# Nếu /var/www đang 750 root:root thì www-data vẫn bị chặn -> fix tối thiểu:
sudo chmod 755 /var/www || true
sudo chmod 755 /var 2>/dev/null || true
# Kiểm tra config và reload
sudo nginx -t
sudo systemctl reload nginx || sudo service nginx reload || sudo nginx -s reload || true

echo ""
echo "=== [6/6] Kết quả sau khi fix ==="
ls -la "$WEB_ROOT"
ls -la "$WEB_ROOT/html/"
stat -c '%U:%G %a %n' "$WEB_ROOT"/html/index.html
echo ""
echo "DONE. Chạy ./verify.sh để kiểm tra ghi file bằng user devops và truy cập web."
