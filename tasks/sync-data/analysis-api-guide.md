# Tích hợp API Phân tích Dự án (Analysis) — ZMG Chat AI Logic Service

> Module Analysis đã được tích hợp vào **ZMG Chat AI Logic Service**, không còn chạy
> service độc lập port `8010` riêng nữa. Toàn bộ endpoint dưới đây nằm chung
> Swagger với các API khác của hệ thống chính.

**Base URL:** `http://103.74.122.196:8012`
**Swagger UI (xem + test trực tiếp):** http://103.74.122.196:8012/docs#/Analysis

## Thay đổi (service `analysis` độc lập)

| | Trước (service riêng, port 8010) | Hiện tại (tích hợp) |
|---|---|---|
| Path tạo run | `POST /v1/projects/{project_id}/analysis-runs` | `POST /api/v1/analysis/projects/{project_id}/run` |
| Path xem run | `GET /v1/analysis-runs/{run_id}` | `GET /api/v1/analysis/runs/{run_id}` |
| Xác thực | Header `X-Internal-API-Key` | Query param `api_key` |

Dev đã tích hợp theo tài liệu cũ cần cập nhật lại cả path lẫn cách gửi key.

## Xác thực

Không dùng header nữa — truyền key qua **query param `api_key`** trên mọi request:
```
?api_key=<key được cấp>
```

## 1. Tạo yêu cầu phân tích dự án (bất đồng bộ)

```
POST /api/v1/analysis/projects/{project_id}/run
```

| Tham số | Vị trí | Bắt buộc | Mô tả |
|---|---|---|---|
| project_id | path | có | ID dự án (integer) |
| ky_key | query | có | Kỳ báo cáo cần phân tích, dạng `2026-Q2` |
| api_key | query | có | API key được cấp |
| Idempotency-Key | header | không | Chuỗi bất kỳ — gọi lại với cùng giá trị này sẽ không tạo run trùng |

**Ví dụ:**
```bash
curl -X POST "http://103.74.122.196:8012/api/v1/analysis/projects/100030/run?ky_key=2026-Q2&api_key=<key>"
```

**Response 202 Accepted:**
```json
{
  "run_id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
  "project_id": 100030,
  "status": "pending",
  "report_ky_key": null,
  "insights_created": 0,
  "forecast_rows_created": 0,
  "detail": {},
  "created_at": "2026-08-18T09:40:33.398Z",
  "updated_at": "2026-08-18T09:40:33.398Z"
}
```
Lưu lại `run_id` để tra cứu kết quả ở bước 2. Request xử lý bất đồng bộ — trả về ngay `202`, chưa có insight/forecast tại thời điểm này (`insights_created`/`forecast_rows_created` = 0), cần poll bước 2 để lấy kết quả.

**422 Validation Error** — thiếu/sai kiểu tham số (ví dụ `project_id` không phải số, thiếu `ky_key`):
```json
{
  "detail": [
    { "loc": ["query", "ky_key"], "msg": "Field required", "type": "missing" }
  ]
}
```

## 2. Kiểm tra trạng thái / lấy kết quả

```
GET /api/v1/analysis/runs/{run_id}
```

| Tham số | Vị trí | Bắt buộc | Mô tả |
|---|---|---|---|
| run_id | path | có | UUID trả về từ bước 1 |
| api_key | query | có | API key được cấp |

**Ví dụ:**
```bash
curl "http://103.74.122.196:8012/api/v1/analysis/runs/3fa85f64-5717-4562-b3fc-2c963f66afa6?api_key=<key>"
```

**Response 200 khi đã xử lý xong:**
```json
{
  "run_id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
  "project_id": 100030,
  "status": "completed",
  "report_ky_key": "2026-Q2",
  "insights_created": 9,
  "forecast_rows_created": 5,
  "detail": {},
  "created_at": "2026-08-18T09:40:33.378Z",
  "updated_at": "2026-08-18T09:41:50.000Z"
}
```

**Các giá trị `status` có thể gặp:**
| status | Ý nghĩa |
|---|---|
| pending | Đã tạo, đang chờ worker xử lý |
| running | Worker đang xử lý |
| completed | Xong, có insight/forecast |
| partially_completed | Xong 1 phần (ví dụ insight thành công nhưng forecast lỗi) |
| failed | Lỗi, xem `detail.error` |

Nên gọi lại (poll) endpoint này định kỳ vài giây/lần cho tới khi `status` không còn là `pending`/`running`.

## Lưu ý khi tích hợp

- **Forecast dùng ARIMA** (không qua LLM) — cần tối thiểu 8 kỳ báo cáo lịch sử cho mỗi chỉ tiêu mới cho ra kết quả; nếu dự án chưa đủ dữ liệu, `forecast_rows_created` có thể bằng 0 dù `status: completed`, không phải lỗi.
- **Insight vẫn dùng LLM** — nếu hạ tầng LLM gặp sự cố, `status` sẽ trả về `failed` với `detail.error` mô tả lỗi kết nối, không làm crash request phía client.
- Không lưu `api_key` trong code/log commit lên git.
