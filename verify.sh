#!/bin/bash
# Kiểm tra Bài 5: devops ghi được không cần sudo, nginx không 403
set -e

WEB_ROOT="/var/www/ptit-web"
INDEX_FILE="$WEB_ROOT/html/index.html"

echo "=== [CHECK 1] Phân quyền hiện tại ==="
ls -la "$WEB_ROOT"
ls -l "$INDEX_FILE"
stat -c 'Owner=%U Group=%G Perm=%a File=%n' "$INDEX_FILE"

echo ""
echo "=== [CHECK 2] Ghi file bằng user devops KHÔNG dùng sudo (phải thành công) ==="
whoami
echo "Chạy: echo \"Update\" >> $INDEX_FILE dưới quyền devops"
sudo -u devops bash -c "echo 'Update' >> $INDEX_FILE && echo 'GHI THANH CONG (không cần sudo)'"
# Hoặc nếu đang đăng nhập trực tiếp bằng devops thì chỉ cần:
#   echo "Update" >> /var/www/ptit-web/html/index.html
echo "--- 3 dòng cuối của index.html ---"
tail -n 5 "$INDEX_FILE"

echo ""
echo "=== [CHECK 3] Nginx không lỗi 403 ==="
sudo nginx -t
echo "--- curl local ---"
curl -s -o /dev/null -w "HTTP code: %{http_code}\n" http://localhost/
echo "--- nginx error log (check 403/forbidden) ---"
sudo grep -i "forbidden\|denied\|403" /var/log/nginx/error.log | tail -n 5 || echo "(không có lỗi forbidden mới -> OK)"
echo "--- process nginx đang chạy user nào ---"
ps aux | grep -E "[n]ginx" || true

echo ""
echo "=== KẾT LUẬN ==="
echo "Nếu CHECK 2 ghi thành công và CHECK 3 trả về HTTP 200 (không 403) => ĐẠT."
