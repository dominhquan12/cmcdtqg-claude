# Phân tích chuyên sâu dự án — Phân tích nghiệp vụ & Kế hoạch triển khai

> Nguồn: `.claude/tasks/phantichchuyensau.docx` (mục 6.1–6.3 của tài liệu đặc tả nghiệp vụ/giao diện).
> Tài liệu này tóm tắt nghiệp vụ và đề xuất kế hoạch triển khai backend cho module mới
> **"Phân tích & Cảnh báo" → Phân tích chuyên sâu dự án**, đối chiếu với trạng thái hiện tại của repo.

## 1. Tóm tắt tài liệu nguồn

Tài liệu mô tả 3 chức năng thuộc phân hệ **Phân tích & Cảnh báo**, actor duy nhất là **Cán bộ** đã đăng nhập:

| Mục | Chức năng | Màn hình |
| --- | --- | --- |
| 6.1 | Danh sách dự án | Danh sách dự án (search/filter/phân trang) |
| 6.2 | Xem chi tiết phân tích chuyên sâu 1 dự án | Chi tiết báo cáo dự án — 9 tab con |
| 6.3 | Xuất báo cáo | Popup xuất báo cáo (chọn tab → PNG → zip) |

Toàn bộ luồng đi qua cùng một breadcrumb: đăng nhập → phân hệ *Phân tích & Cảnh báo* → menu con *Phân tích chuyên sâu* → *Danh sách dự án* → mở 1 dự án → các tab chi tiết → (tuỳ chọn) xuất báo cáo.

## 2. Phân tích nghiệp vụ theo chức năng

### 2.1. Danh sách dự án (6.1)

- Danh sách mặc định lấy **20 bản ghi mới nhất**; hỗ trợ **phân trang**.
- Cột hiển thị: mã dự án, tên dự án, mô tả, lĩnh vực, địa điểm dự án, địa bàn, đơn vị quản lý — tất cả **lấy từ phân hệ dự án** (hệ thống ngoài/khác), không phải dữ liệu tự sinh trong module này.
- Tìm kiếm theo mã/tên dự án (không phân biệt hoa/thường) + bộ lọc nâng cao (lĩnh vực, địa điểm dự án, địa bàn, đơn vị quản lý) — tất cả optional, danh mục lọc cũng lấy từ phân hệ dự án.
- Empty state khi không có dữ liệu / không có kết quả tìm kiếm (2 thông điệp khác nhau).
- Action trên mỗi dòng: mở "Chi tiết phân tích chuyên sâu" cho dự án đó.

**Ngụ ý kỹ thuật**: cần một nguồn dữ liệu "dự án" — hoặc là bảng cache/replica cục bộ, hoặc gọi API sang phân hệ dự án (Feign client), tài liệu không nói rõ. Đây là **điểm cần làm rõ** (xem mục 4).

### 2.2. Chi tiết phân tích chuyên sâu 1 dự án (6.2)

#### a. Header cố định (sticky) + 5 KPI card

Thông tin chung của dự án + kỳ báo cáo hiện tại, ánh xạ tới **5 mẫu báo cáo định kỳ khác nhau** (đây là phần quan trọng nhất về mặt dữ liệu):

| Mẫu báo cáo | Loại kỳ | Field nguồn chính |
| --- | --- | --- |
| Mẫu 103 | Báo cáo quý | `tenDuAn`, `diaDiemThucHien`, `tenTCKT`, `quyBaoCao`/`namBaoCao`, `khoKhanVuongMac` |
| Mẫu 37 | Báo cáo năm (bản đầy đủ) | tương tự 103 + `loiNhuanSauThue`, `ChiPhiRD`, `ChiPhiMoiTruong` |
| Mẫu 116 | Báo cáo năm (bản rút gọn) | tương tự, field tên hơi khác (`chiPhiNghienCuuPhatTrien`, `ChiPhiXuLyBaoVeMoiTruong`) |
| Mẫu 114 | Báo cáo quý | tương tự 103 |
| Mẫu 89 | Đầu tư ra nước ngoài | cấu trúc lồng nhau khác hẳn: `thongTinDuAnNuocNgoai.*`, `moTaChiTiet.*`, `danhGia.*`, `ketQuaKinhDoanh.*` |

→ **Đây là 5 schema JSON khác nhau cho cùng khái niệm "báo cáo định kỳ"**, khớp với `mappingNguonCol` (JSON) đã có sẵn trên `CbChiTieu` — bảng nguồn `bc_dinh_ky` được nhắc trong Javadoc nhưng **chưa có entity**.

5 KPI card: Tổng mức đầu tư, Tỷ lệ giải ngân (có công thức), Tiến độ thực hiện (suy luận fallback từ `khoKhanVuongMac`), Tuân thủ (%), Rủi ro (điểm/10 + phân loại theo ngưỡng).

#### b–k. Các tab con (mỗi tab tương ứng 1 trong 5 "nhóm chỉ tiêu" + các tab tổng hợp)

| Tab | Nội dung chính | Nguồn AI insight |
| --- | --- | --- |
| Tổng quan | 4 đoạn text mô tả (hoạt động, tài chính, tiến độ, khó khăn) + nguồn trích dẫn | rule-based hoặc LLM |
| Tài chính | Bar chart kỳ này/kỳ trước theo 8 chỉ tiêu, bảng chi tiết + % biến động + xu hướng | LLM (gọi ngoài) |
| Vốn & Giải ngân | Bar chart cơ cấu vốn theo kỳ (≤4 kỳ) + donut kỳ gần nhất + tiến độ giải ngân (công thức %) + bảng chi tiết góp vốn | LLM (gọi ngoài) |
| Tiến độ | Line chart 4 trạng thái tiến độ (≤5 kỳ) + bảng ma trận đánh dấu | rule-based hoặc LLM |
| Tuân thủ | Donut tổng thể + 3 card thống kê + bảng cây cha/con theo **5 nhóm tuân thủ cố định** (Tài chính, Môi trường/Xây dựng/..., Tiến độ, Nộp báo cáo định kỳ, Thủ tục cấp tài khoản) | không có insight AI ở tab này |
| Rủi ro | Gauge 0–10 + 4 danh mục con (Tài chính/Tiến độ/Vốn&Giải ngân/Tuân thủ) + bảng + AI insight | LLM (gọi ngoài) x2 (khuyến nghị ngắn + diễn giải nguyên nhân theo danh mục + insight tổng) |
| So sánh (đa chỉ tiêu theo kỳ) | Toggle 1-trong-4 nhóm chỉ tiêu, chọn chỉ tiêu con, bar chart 4 kỳ + line overlay, bảng nhóm cha/con | LLM |
| So sánh (với trung bình ngành) | Radar chart 5 trục (dự án vs trung bình ngành cùng lĩnh vực/kỳ) + bảng chi tiết | LLM |
| Dự báo | Bar chart dự báo (giống So sánh nhưng disable ô chọn) + 5 card dự báo (mô hình dự báo trên chuỗi lịch sử) | LLM |
| Gợi ý | Card list phát hiện mức Cao/Nghiêm trọng, chỉ **enable khi tab Rủi ro có ≥1 nhóm Cao/Nghiêm trọng** | LLM (tiêu đề + nội dung diễn giải) |

**Quan sát quan trọng về nghiệp vụ**:
1. **5 nhóm chỉ tiêu cố định xuyên suốt**: Tài chính, Vốn & Giải ngân, Tiến độ, Tuân thủ, Rủi ro — khớp 1-1 với khái niệm `CbNhomChiTieu` đã có sẵn trong module `ptcb`. Đây gần như chắc chắn là lý do `CbChiTieu`/`CbNhomChiTieu` được tạo trước.
2. **AI insight xuất hiện ở 7/10 vùng** (Tổng quan, Tài chính, Vốn&Giải ngân, Tiến độ, Rủi ro x3, So sánh x2, Dự báo, Gợi ý) — luôn theo pattern: "gọi API LLM ngoài, truyền context liên quan làm input, nhận về đoạn text". Cần 1 service/client LLM dùng chung, không phải build riêng lẻ từng tab. `AiServiceClient` hiện có (RestTemplate + WS) là ứng viên tái sử dụng/mở rộng — cần xác nhận nó có endpoint "generate insight" hay chỉ có OCR/hybrid-search (xem mục 4).
3. **Nhiều công thức tính rõ ràng, có thể unit-test được** (tỷ lệ giải ngân, biến động %, tỷ lệ đạt/chênh lệch kế hoạch, điểm rủi ro theo ngưỡng, % tăng trưởng dự báo...) — nên tách thành các pure calculator/service riêng theo từng nhóm chỉ tiêu.
4. **Tab Gợi ý có điều kiện enable phụ thuộc dữ liệu của tab Rủi ro** — logic cross-tab, không chỉ là UI, cần backend trả về 1 flag (`hasCriticalOrHighRisk`) ở API tổng quan/header.
5. Tất cả bảng "kỳ trước/kỳ này", "4 kỳ gần nhất", "5 kỳ gần nhất", "4–8 kỳ tuỳ chọn" đều phụ thuộc vào **loại báo cáo gần nhất là quý hay năm** — kỳ báo cáo không cố định là quý, cần 1 khái niệm "kỳ" trừu tượng (quý hoặc năm) xuyên suốt toàn bộ tầng service.

### 2.3. Xuất báo cáo (6.3)

- Popup chọn tối thiểu 1 trong **9 tab** (checkbox), "Chọn tất cả" dạng toggle 2 chiều.
- Xuất ra **file zip**, mỗi tab đã chọn → 1 file PNG riêng (Header cố định + nội dung tab đó), tên file `BaoCao_{MaDuAn}_{KyBaoCao}.zip`.
- Có validate (chưa chọn tab nào), loading state, toast success/error (tự ẩn sau 3s).
- **Việc render "PNG của 1 tab dashboard"** thường được làm ở FE (screenshot canvas/html-to-image) hoặc bằng 1 headless-render service; đây là điểm cần làm rõ vì ảnh hưởng lớn tới scope backend (xem mục 4).

## 3. Điểm cần làm rõ trước khi thiết kế chi tiết (open questions)

1. **Nguồn "dự án" và "phân hệ dự án"**: là một service khác (Feign/API ngoài) hay bảng nội bộ đồng bộ qua Kafka (giống các `InboxProcessor` hiện có cho Investor/Legal/News/IndustrialZone)? Ảnh hưởng trực tiếp tới việc có cần entity `DuAn` nội bộ hay chỉ cache.
2. **Nguồn `bc_dinh_ky`** (báo cáo định kỳ, 5 mẫu 103/37/116/114/89): ingest từ đâu (Kafka, upload thủ công, hệ thống báo cáo khác)? `CbChiTieu.mappingNguonCol` giả định bảng này tồn tại nhưng chưa có entity/migration.
3. **"Trung bình ngành"** (tab So sánh): cần tính trung bình cộng của "toàn bộ dự án cùng lĩnh vực" — có bao nhiêu dự án trong hệ thống, tính real-time hay batch/cache định kỳ (ảnh hưởng hiệu năng nếu tính on-the-fly mỗi lần mở tab)?
4. **Mô hình dự báo** (tab Dự báo): "mô hình dự báo trên chuỗi lịch sử" — cần xác nhận đây là thuật toán đơn giản (linear regression/trung bình trượt) tự viết, hay gọi ra ngoài (AI service/LLM) như các tab khác.
5. **LLM client dùng chung**: `AiServiceClient` hiện tại có hỗ trợ prompt tự do "generate insight from context" không, hay cần thêm client/endpoint mới?
6. **Export PNG/zip**: server-side render (cần thư viện chart-to-image phía Java) hay chỉ backend cung cấp data, FE tự capture & zip? Quyết định này ảnh hưởng rất lớn tới độ phức tạp của use-case 6.3.
7. **Ngưỡng cấu hình** (mức rủi ro thấp/TB/cao/nghiêm trọng, ngưỡng gợi ý cao/nghiêm trọng...) — hard-code hay cấu hình được (bảng config, tương tự `AiKnowledgeAlertConfig`)?

→ Đề xuất: trước khi code, trao đổi lại với BA/PO các mục 1, 2, 4, 6 vì chúng quyết định kiến trúc (nguồn dữ liệu ngoài vs nội bộ, có cần thêm dependency mới không).

## 4. Đề xuất kế hoạch triển khai (theo `docs/clean_architecture_guide.md` & convention `com.ai.ptcb`)

Vì nghiệp vụ xoay quanh "chỉ tiêu"/"nhóm chỉ tiêu" đã có sẵn trong `com.ai.ptcb`, đề xuất **tiếp tục trong module `ptcb`**, dùng `BaseAudit` + tên bảng/cột tiếng Việt, audit thủ công qua `UserContext.getTaiKhoanId()` — theo đúng convention đã ghi trong CLAUDE.md, **không** copy convention của `com.ai.domain`.

### Phase 0 — Chốt open questions (mục 3) + thiết kế DB

- Entity `DuAn` (hoặc xác nhận chỉ là cache/proxy nếu dữ liệu đến từ service ngoài).
- Entity `BcDinhKy` (báo cáo định kỳ) lưu JSONB nội dung thô theo từng mẫu (103/37/116/114/89) — khớp với cách `CbChiTieu.mappingNguonCol` đã giả định, dùng `@JdbcTypeCode(SqlTypes.JSON)` như `CbChiTieu`.
- Entity cấu hình ngưỡng (rủi ro, gợi ý) nếu cần cấu hình động thay vì hard-code.

### Phase 1 — Danh sách dự án (6.1)

- Repository + service đọc `DuAn` (paginate, search theo mã/tên, filter lĩnh vực/địa điểm/địa bàn/đơn vị quản lý).
- DTO response theo `BaseResponseDTO` + `metaData` phân trang (convention đã có sẵn trong repo).
- Controller `GET /api/PhanTichChuyenSau/DuAn` với `@Permission`.

### Phase 2 — Header + KPI card + Tab Tổng quan (6.2.a, 6.2.b)

- Service map 5 mẫu báo cáo → 1 DTO chuẩn hoá chung (tenDuAn, diaDiemThucHien, kỳ báo cáo, đơn vị quản lý...) — nơi tập trung toàn bộ logic "theo mẫu nào thì lấy field nào" đã liệt kê ở mục 2.2.a.
- Calculator riêng cho từng KPI (tỷ lệ giải ngân, tiến độ fallback, tuân thủ %, điểm rủi ro + phân loại ngưỡng) — pure function, dễ unit test.
- Tab Tổng quan: ghép 4 đoạn mô tả + gọi LLM client (rule-based fallback nếu LLM lỗi/không cấu hình).

### Phase 3 — Tab theo từng nhóm chỉ tiêu (Tài chính, Vốn & Giải ngân, Tiến độ, Tuân thủ, Rủi ro)

- Mỗi tab 1 service riêng, tái sử dụng khái niệm "kỳ" (quý/năm) trừu tượng đã nêu ở mục 2.2 (4).
- Tuân thủ: model cây cha/con 5 nhóm cố định + rule "vi phạm nếu có ≥1 con vi phạm".
- Rủi ro: cần trả thêm flag `hasCriticalOrHighRisk` để tab Gợi ý (FE) biết enable/disable.
- Tích hợp LLM insight qua 1 client/service dùng chung (xem Phase 5), không lặp code gọi LLM ở từng tab.

### Phase 4 — So sánh, Dự báo, Gợi ý (6.2.g–k)

- So sánh theo kỳ: cần query N kỳ gần nhất hoặc theo danh sách kỳ tuỳ chọn.
- So sánh trung bình ngành: cần quyết định tính real-time hay cache (Phase 0, mục 3) trước khi implement.
- Dự báo: cần chốt thuật toán (Phase 0, mục 4) trước khi implement — có thể làm placeholder rule-based trước (VD: trung bình trượt) rồi thay bằng model thật sau.
- Gợi ý: chỉ trả dữ liệu khi tab Rủi ro có nhóm Cao/Nghiêm trọng — dùng lại flag ở Phase 3.

### Phase 5 — LLM insight client dùng chung

- Xác nhận `AiServiceClient` có hỗ trợ prompt tự do; nếu không, thêm method/endpoint mới (Feign hoặc RestTemplate) theo pattern hiện có trong `com.ai.infrastructure.external.ai`.
- 1 service `InsightGenerationService` nhận `(context data, prompt template)` → gọi LLM → trả text, có fallback rule-based khi lỗi/timeout (nhiều chỗ trong tài liệu ghi "rule-based hoặc LLM").

### Phase 6 — Xuất báo cáo (6.3)

- Sau khi chốt mục 3.6: nếu server-side render, cần thêm thư viện tạo ảnh từ chart (rủi ro kỹ thuật, nên POC riêng trước khi cam kết); nếu FE tự capture, backend chỉ cần API tổng hợp data theo tab đã chọn + endpoint đóng gói zip (MinIO tạm hoặc stream trực tiếp).
- Controller nhận danh sách tab đã chọn → validate ≥1 → build response/orchestrate export.

### Ghi chú ưu tiên

- Phase 0–2 là nền tảng bắt buộc, không thể song song.
- Phase 3 có thể chia nhỏ và làm song song theo từng nhóm chỉ tiêu (5 sub-team/PR độc lập) vì mỗi tab tương đối độc lập ngoài phần dùng chung ở Phase 0/5.
- Phase 4 (So sánh trung bình ngành, Dự báo) rủi ro cao nhất về hiệu năng/độ chính xác — nên làm sau cùng, sau khi Phase 0 mục 3–4 đã chốt.
- Phase 6 (xuất báo cáo) nên làm cuối vì phụ thuộc toàn bộ data của các tab khác đã ổn định.
