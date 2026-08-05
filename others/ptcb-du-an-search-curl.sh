#!/bin/bash
# Curl mẫu test API "Danh sách dự án" (Phase 1, phan-tich-chuyen-sau-plan.md mục 2.1)
# Token JWT bên dưới tự ký bằng RSA_PRIVATE_KEY trong .env (chỉ để test cục bộ, không phải token thật)
# Hết hạn: iat=1785832748 (~2026-08-04 15:39 +07), exp = iat + 8h -> báo Claude ký lại nếu hết hạn

TOKEN="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxIiwidW5pcXVlX25hbWUiOiJ0ZXN0ZXIiLCJEb25WaUlkIjoiMSIsInJvbGUiOlsiU3lzX0FkbWluIl0sImlhdCI6MTc4NTgzMjc0OCwiZXhwIjoxNzg1ODYxNTQ4fQ.YbLbSKYKceGUnv7CmjSnrKGe1vTQkOIzlmHWuiYIVgVSsXPrmkxmgMRrw7fa1Pb04-x7OL1Jp-MY0Ya-igKqR9vuffTFjLSkE3kQIvNX_4F5IQO_P2qM4cDs0zdBMM1aNopj26pnp7R18ORR-WnabL-Nti0s7uR7qW3p2loTQWVDcMhn3qPfyIYYE_KZ6c4bJ0oO5EYEX5QCxU62uR9P7su6cJ6TBnzEwm6LKvEj2MtgKS6FHX2HqZuSZHR1nEVC-uWZgEld2aaGrpY7XIL8sNI5pvOdXIqpi8aCOggeOPsc2XTFKRIMcJj9wIfOuEN-QvMesmIxbD4EUOkYKI9z0w"

# Danh sách / tìm kiếm + phân trang
curl -X GET "http://localhost:8085/api/v1/ptcb/du-an/search?page=0&size=20&sortBy=createdAt&sortDir=desc" -H "Authorization: Bearer $TOKEN"

# Tìm theo mã/tên + lọc lĩnh vực
# curl -X GET "http://localhost:8085/api/v1/ptcb/du-an/search?keyword=DA-100010&linhVuc=hanh%20chinh&page=0&size=5" -H "Authorization: Bearer $TOKEN"

# Chi tiết 1 dự án
# curl -X GET "http://localhost:8085/api/v1/ptcb/du-an/100010" -H "Authorization: Bearer $TOKEN"
