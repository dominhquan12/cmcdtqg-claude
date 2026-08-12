# Phân tích chuyên sâu dự án — Phân tích nghiệp vụ & Kế hoạch triển khai

> Nguồn:
> - `.claude/tasks/phantichchuyensau/phantichchuyensau.docx` (mục 6.1–6.3 của tài liệu đặc tả nghiệp vụ/giao diện)
> - `.claude/tasks/phantichchuyensau/100 dòng bc.xlsx` (data mẫu thật của bảng báo cáo nguồn)
> - `.claude/tasks/phantichchuyensau/Mô tả logic công thức.xlsx` (spec công thức chi tiết theo từng mẫu báo cáo, **4 sheet** — cập nhật 2026-08-05, thêm sheet "Biến số khả dụng"; xem mục 3.3)
> - `.claude/tasks/phantichchuyensau/schema_fixed.sql` (**bản đề xuất DB** từ phía đối tác/khách hàng — không phải bản chốt, được phép điều chỉnh theo nghiệp vụ thực tế)
> - `.claude/tasks/phantichchuyensau/db_analysis_sample.sql` (dump thực tế của schema `schema_fixed.sql` đã load lên DB `test`, kèm data mẫu ~100 dự án — dùng để kiểm chứng schema đề xuất đối chiếu với data thật)
>
> **Phạm vi của file này: chỉ phần "Phân tích chuyên sâu"** (mục 6.1–6.3 của docx). Phần "Cảnh báo"
> (cấu hình ngưỡng thống kê, dashboard cảnh báo, chi tiết cảnh báo — phát hiện thêm ở
> `Mô tả logic công thức.xlsx` sheet 2) **nằm ngoài phạm vi**, xem mục 6.
>
> **RULE TẠM THỜI (2026-08-04)**: khi cần tham chiếu cấu trúc DB để code/thiết kế, dùng
> **`db_analysis_sample.sql`** làm nguồn tham chiếu chính (schema `schema_fixed.sql` + data mẫu để
> kiểm chứng thực tế). **CHƯA dùng `phan-tich-chuyen-sau-schema.dbml`** (bản v2 đề xuất sửa) — đối
> chiếu 2 file cho thấy dbml còn vài điểm chưa khớp với data mẫu thật, cần chốt trước khi chuyển
> sang dùng làm nguồn chính thức: enum `trang_thai_hoat_dong` thiếu giá trị `ended`/`suspended` xuất
> hiện trong data mẫu; bảng `cb_nhom_chi_tieu`/`cb_chi_tieu` mà dbml đề xuất FK tới đang **rỗng** (0
> dòng) trong DB thật; mã "chỉ tiêu" không nhất quán giữa `bc_du_bao.nhom_chi_tieu` (mã chỉ tiêu đơn
> lẻ, không phải nhóm) và `bc_chi_tieu_trung_binh.chi_tieu` (giữ suffix `_ky`/`_luy_ke_gcndt`); và
> `ai_insight.tab_nguon` trong data mẫu có giá trị `tuan_thu`, mâu thuẫn với quy tắc "Tuân thủ không
> có insight AI" ở mục 2.2. Sẽ cập nhật rule này khi các điểm trên được chốt với BA.

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

**Ngụ ý kỹ thuật**: cần một nguồn dữ liệu "dự án" — xem mục 3.2 (đã có gợi ý cấu trúc `dm_du_an`).

### 2.2. Chi tiết phân tích chuyên sâu 1 dự án (6.2)

> **Lưu ý**: công thức mô tả dưới đây lấy theo docx gốc, ở mức tổng quan. Khi code, dùng
> **mục 3.3** (spec công thức chi tiết từ `Mô tả logic công thức.xlsx`) làm nguồn chính thức —
> chi tiết hơn và có vài điểm khác so với docx (VD: chia điểm rủi ro tài chính theo số chỉ tiêu
> thực tế của từng mẫu, không phải hằng số).

#### a. Header cố định (sticky) + 5 KPI card

Thông tin chung của dự án + kỳ báo cáo hiện tại, ánh xạ tới **5 mẫu báo cáo định kỳ khác nhau**:

| Mẫu báo cáo | Loại kỳ | Field nguồn chính |
| --- | --- | --- |
| Mẫu 103 | Báo cáo quý | `tenDuAn`, `diaDiemThucHien`, `tenTCKT`, `quyBaoCao`/`namBaoCao`, `khoKhanVuongMac` |
| Mẫu 37 | Báo cáo năm (bản đầy đủ) | tương tự 103 + `loiNhuanSauThue`, `ChiPhiRD`, `ChiPhiMoiTruong` |
| Mẫu 116 | Báo cáo năm (bản rút gọn) | tương tự, field tên hơi khác (`chiPhiNghienCuuPhatTrien`, `ChiPhiXuLyBaoVeMoiTruong`) |
| Mẫu 114 | Báo cáo quý | tương tự 103 |
| Mẫu 89 | Đầu tư ra nước ngoài | cấu trúc lồng nhau khác hẳn: `thongTinDuAnNuocNgoai.*`, `moTaChiTiet.*`, `danhGia.*`, `ketQuaKinhDoanh.*` |

→ 5 schema JSON khác nhau cho cùng khái niệm "báo cáo định kỳ" — **đã xác nhận nguồn thật** ở mục 3.1.

5 KPI card: Tổng mức đầu tư, Tỷ lệ giải ngân (có công thức), Tiến độ thực hiện (suy luận fallback từ `khoKhanVuongMac`), Tuân thủ (%), Rủi ro (điểm/10 + phân loại theo ngưỡng).

#### b–k. Các tab con (mỗi tab tương ứng 1 trong 5 "nhóm chỉ tiêu" + các tab tổng hợp)

| Tab | Nội dung chính | Nguồn AI insight |
| --- | --- | --- |
| Tổng quan | 4 đoạn text mô tả (hoạt động, tài chính, tiến độ, khó khăn) + nguồn trích dẫn | rule-based hoặc LLM |
| Tài chính | Bar chart kỳ này/kỳ trước theo 8 chỉ tiêu, bảng chi tiết + % biến động + xu hướng | LLM (gọi ngoài) |
| Vốn & Giải ngân | Bar chart cơ cấu vốn theo kỳ (≤4 kỳ) + donut kỳ gần nhất + tiến độ giải ngân (công thức %) + bảng chi tiết góp vốn | LLM (gọi ngoài) |
| Tiến độ | Line chart 4 trạng thái tiến độ (≤5 kỳ) + bảng ma trận đánh dấu | rule-based hoặc LLM |
| Tuân thủ | Donut tổng thể + 3 card thống kê + bảng cây cha/con theo **5 nhóm tuân thủ cố định** | không có insight AI ở tab này |
| Rủi ro | Gauge 0–10 + 4 danh mục con + bảng + AI insight | LLM (gọi ngoài) x2 |
| So sánh (đa chỉ tiêu theo kỳ) | Toggle 1-trong-4 nhóm chỉ tiêu, chọn chỉ tiêu con, bar chart 4 kỳ + line overlay, bảng nhóm cha/con | LLM |
| So sánh (với trung bình ngành) | Radar chart 5 trục (dự án vs trung bình ngành cùng lĩnh vực/kỳ) + bảng chi tiết | LLM |
| Dự báo | Bar chart dự báo (giống So sánh nhưng disable ô chọn) + 5 card dự báo | LLM |
| Gợi ý | Card list phát hiện mức Cao/Nghiêm trọng, chỉ enable khi tab Rủi ro có ≥1 nhóm Cao/Nghiêm trọng | LLM |

**Quan sát quan trọng về nghiệp vụ**:
1. **5 nhóm chỉ tiêu cố định xuyên suốt**: Tài chính, Vốn & Giải ngân, Tiến độ, Tuân thủ, Rủi ro — khớp 1-1 với `CbNhomChiTieu` đã có trong module `ptcb`.
2. **AI insight xuất hiện ở 7/10 vùng** — luôn theo pattern "gọi API LLM ngoài, truyền context, nhận về text". Cần 1 service/client LLM dùng chung. **(Đã xác nhận với BA, 2026-08-06) Cơ chế sinh insight**: KHÔNG gọi LLM đồng bộ ngay trong request đọc tab — có 1 **job async chạy SAU KHI báo cáo đã lưu vào `bc_dinh_ky`**, job này sinh insight (ghi vào `ai_insight`) VÀ dự báo (ghi vào `bc_du_bao`) cho đúng báo cáo đó, gắn theo `report_id`. Vậy tầng đọc (các tab) **chỉ cần SELECT từ `ai_insight`/`bc_du_bao` theo `report_id` (+ `tab_nguon` cho `ai_insight`)**, không tự sinh nhận định — chỉ fallback rule-based khi job async chưa chạy tới (báo cáo vừa lưu, insight chưa kịp sinh) hoặc khi record đã hết hạn (`expired_at`). Đã áp dụng cho tab Tài chính (`TabTaiChinhServiceImpl.sinhNhanDinh`, dùng `AiInsightRepository.findFirstByReportIdAndTabNguonOrderByCreatedAtDesc`) — **các tab khác (Tổng quan, Vốn & Giải ngân, Tiến độ, và sau này Rủi ro/So sánh/Dự báo/Gợi ý) đang còn dùng rule-based thuần, cần áp dụng lại pattern này khi có thời gian** (không tự động áp dụng hết trong 1 lần vì mỗi tab cần xác nhận riêng `tab_nguon` tương ứng).
3. **Nhiều công thức tính rõ ràng, unit-test được** — tách thành pure calculator/service riêng theo từng nhóm chỉ tiêu.
4. **Tab Gợi ý phụ thuộc dữ liệu tab Rủi ro** — cần backend trả flag `hasCriticalOrHighRisk`.
5. Mọi bảng "kỳ trước/kỳ này/N kỳ gần nhất" phụ thuộc **loại báo cáo gần nhất là quý hay năm** — cần khái niệm "kỳ" trừu tượng xuyên suốt service layer. **1 dự án có song song 2 luồng báo cáo** (4 báo cáo quý/năm + 1 báo cáo năm) — "cùng kỳ" phải so quý-với-quý hoặc năm-với-năm theo đúng loại của báo cáo gần nhất, KHÔNG được lấy N bản ghi mới nhất theo ngày nộp rồi trộn lẫn 2 loại (**Phase 2/3 code lần đầu đã mắc lỗi này** — `findTop2/4/5ByProjectId...Desc` không lọc theo loại kỳ; đã sửa bằng `KyBaoCaoResolver` — xem Phase 2/3 status bên dưới).

### 2.3. Xuất báo cáo (6.3)

- Popup chọn tối thiểu 1 trong **9 tab** (checkbox), "Chọn tất cả" dạng toggle 2 chiều.
- Xuất ra **file zip**, mỗi tab đã chọn → 1 file PNG riêng, tên file `BaoCao_{MaDuAn}_{KyBaoCao}.zip`.
- Có validate, loading state, toast success/error (tự ẩn sau 3s).
- Cách render PNG (server-side hay FE tự capture) vẫn là điểm mở (mục 4).

## 3. Ngữ cảnh bổ sung từ dữ liệu mẫu & spec công thức chi tiết

### 3.1. Nguồn dữ liệu báo cáo thật đã tồn tại (`100 dòng bc.xlsx`)

File chứa data mẫu thật (5 dòng, mỗi dòng 1 mẫu báo cáo) của một bảng nguồn **đã tồn tại ở hệ thống/phân hệ khác** (không phải trong `ptcb`), với cấu trúc:

| Cột | Ý nghĩa |
| --- | --- |
| `Id` | Khoá chính |
| `MaBaoCao` | Mã báo cáo, VD `FDI_AIII1_548` (tiền tố loại dự án + mã mẫu + số thứ tự) |
| `LoaiBaoCaoId` | **= 103 / 37 / 116 / 114 / 89** — định danh mẫu báo cáo |
| `LoaiKy` | Loại kỳ — **rỗng/NULL trong toàn bộ data mẫu, không đáng tin cậy** |
| `NgayNop` | Ngày nộp báo cáo |
| `TrangThai` | Trạng thái báo cáo |
| `NoiDungChiTiet` | **JSON chứa toàn bộ field nghiệp vụ** (tenDuAn, tongVonDauTuDangKy, phanB.vonGop/vonVay/..., khoKhanVuongMac, hoặc với mẫu 89: thongTinDuAnNuocNgoai/danhGia/moTaChiTiet/bangSoLieu...) |
| `IdNguoiTao/NgayTao/IdNguoiSua/NgaySua/DaXoa` | Audit chuẩn |
| `BuocHienTai/MaQuyTrinh/BuocCaoNhat/DonViId` | Field workflow — gợi ý bảng này thuộc 1 hệ thống quản lý quy trình nộp báo cáo riêng |

**Kết luận**: đây chính là nguồn cho khái niệm "báo cáo định kỳ" (`bc_dinh_ky` ở mục 3.2). Module Phân tích chuyên sâu **chỉ cần đọc** dữ liệu này (qua DB chung, API, hoặc đồng bộ) — không tự sinh/nhập báo cáo. Cần xác nhận thêm (vẫn là open question #2 ở mục 4): cơ chế đọc là gì (share DB, Feign, hay Kafka sync).

### 3.2. `schema_fixed.sql` — bản đề xuất, không phải bản chốt

> Theo xác nhận của người dùng: **file SQL này là đề xuất từ phía đối tác/khách hàng, được phép
> điều chỉnh tự do** — DB thật cần thiết kế lại theo đúng nghiệp vụ + công thức (mục 3.3), không
> nhất thiết giữ nguyên tên bảng/cột/cấu trúc của bản đề xuất.

Nội dung đề xuất (schema Postgres `test`): `dm_nganh`, `dm_ky_bao_cao`, `dm_nghia_vu_tuan_thu`, `dm_du_an`, `bc_dinh_ky` (cột chuẩn hoá + `raw_json` JSONB), view `vw_bc_dinh_ky_dashboard`, `ai_insight`, `bc_rui_ro_chi_tiet`, `bc_tuan_thu_chi_tiet`, `bc_du_bao`, `bc_chi_tieu_trung_binh`.

Đối chiếu với spec công thức chi tiết (mục 3.3), các điểm **cần chỉnh so với bản đề xuất**:

1. **ETL từ `NoiDungChiTiet` → `bc_dinh_ky` phải viết riêng theo từng `LoaiBaoCaoId`**, không thể dùng 1 mapper chung — vì ý nghĩa cột "kỳ/lũy kế" trong JSON nguồn khác nhau giữa các mẫu (xem mục 3.4, điểm 4).
2. Bản đề xuất không có cột nào cho **"Vốn khác"** — đúng với thực tế (không mẫu nào có nguồn dữ liệu cho hạng mục này), nhưng UI (docx 2.2.d) lại hiển thị hạng mục này → cần quyết định nghiệp vụ trước khi map DB (mục 3.4, điểm 1).
3. Nên thêm 1 bảng/cấu hình "số chỉ tiêu tài chính có sẵn theo từng mẫu" (4/7/8 chỉ tiêu tuỳ mẫu) để phục vụ công thức điểm rủi ro nhóm Tài chính — bản đề xuất chưa có (mục 3.4, điểm 3).
4. `LoaiKy` không nên copy trực tiếp từ bảng nguồn — phải suy ra từ `LoaiBaoCaoId` + field trong JSON khi ETL (mục 3.4, điểm 5).
5. Về convention: nếu tiếp tục trong module `ptcb`, cần dịch tên bảng sang đúng style đang dùng (`BaseAudit`, tên entity Java PascalCase, ví dụ `DmDuAn`/`BcDinhKy`/`AiInsight`...) — bản đề xuất dùng `created_at/updated_at` kiểu tiếng Anh, khác với `BaseAudit` (`ngay_tao`, `ngay_sua`, `da_xoa`, `id_nguoi_tao`, `id_nguoi_sua`).

### 3.2bis. Vì sao KHÔNG gộp `dm_ky_bao_cao` vào `bc_dinh_ky` (2026-08-06)

> Câu hỏi hay gặp lại: 2 bảng này trông như thể trùng nhau (đều xoay quanh "kỳ") nên có người sẽ đề
> xuất gộp cho gọn. **Đừng gộp** — đây là quan hệ dimension (danh mục)/fact (giao dịch) kinh điển,
> và có 2 bằng chứng nghiệp vụ cụ thể (không chỉ lý thuyết chuẩn hoá suông) cho thấy "kỳ" phải tồn
> tại độc lập với "báo cáo":

1. **Nghĩa vụ tuân thủ "Nộp báo cáo định kỳ" cần phát hiện dự án CHƯA nộp báo cáo** (sheet 1 dòng
   31: check `NgayNop` với hạn nộp bc, "trước ngày 10 tháng đầu quý sau"). Muốn biết 1 kỳ đã quá
   hạn mà dự án chưa nộp báo cáo, kỳ đó phải tồn tại (biết `ngay_ket_thuc`, tính được hạn nộp) **kể
   cả khi chưa có dòng `bc_dinh_ky` nào tương ứng**. Nếu gộp 2 bảng, kỳ chỉ tồn tại khi có báo cáo
   → không thể biểu diễn trạng thái "quá hạn, chưa nộp" (mất khả năng phát hiện đúng loại vi phạm
   này).
2. **`bc_du_bao` (dự báo) tham chiếu thẳng `dm_ky_bao_cao.ky_key` qua cột `ky_key_du_bao`, KHÔNG có
   cột `report_id` nào** — vì dự báo luôn nhắm tới 1 kỳ **tương lai**, mà theo định nghĩa kỳ tương
   lai đó chưa thể có báo cáo thực tế. Nếu gộp 2 bảng, `bc_du_bao` sẽ không có gì để tham chiếu.

**Bằng chứng khác (không phải lý do chính, nhưng cùng hướng)**:
- Cardinality lệch nhau: `dm_ky_bao_cao` ~1 dòng/kỳ dùng chung toàn hệ thống; `bc_dinh_ky` ~1
  dòng/(dự án × kỳ). Gộp sẽ lặp lại `nam`/`quy`/`ngay_bat_dau`/`ngay_ket_thuc` ở mọi dòng báo cáo
  của mọi dự án — sai chuẩn 3NF, sửa 1 kỳ phải update hàng loạt dòng.
- `AiInsight`, `BcRuiRoChiTiet`, `BcTuanThuChiTiet` đều có cột `ky_key` tham chiếu `dm_ky_bao_cao`
  độc lập với `bc_dinh_ky` — bảng này là "từ vựng kỳ" dùng chung cho cả domain, không riêng gì báo
  cáo định kỳ.
- `dm_ky_bao_cao.thu_tu` tồn tại để sắp thứ tự kỳ theo trình tự thời gian THỰC của kỳ, tách biệt
  khỏi ngày nộp báo cáo thực tế (có thể nộp trễ/sớm) — 1 khái niệm chỉ có ý nghĩa khi kỳ là 1 bảng
  riêng.

**Gap phát hiện kèm theo (đáng sửa riêng, không liên quan trực tiếp câu hỏi gộp bảng)**: bản đề
xuất `db_analysis_sample.sql` có `UNIQUE(project_id, ky_key)` trên `bc_dinh_ky`
(`uq_bc_dinh_ky`), nhưng entity `BcDinhKy.java` **chưa khai báo lại** constraint này
(`@Table` không có `uniqueConstraints`). Vì app dùng `hibernate.ddl-auto: update` (sinh schema từ
entity, không chạy trực tiếp `db_analysis_sample.sql`), DB thật của app **hiện chưa enforce**
tính duy nhất `(project_id, ky_key)`. Ảnh hưởng cụ thể: `BcTuanThuChiTiet` không có cột
`report_id` (chỉ có `project_id`+`ky_key`) nên việc join ngược lại đúng 1 báo cáo phụ thuộc hoàn
toàn vào tính duy nhất này — nên thêm lại `uniqueConstraints` vào entity cho khớp bản tham chiếu.

### 3.2ter. Bug đã sửa (2026-08-12): `dm_ky_bao_cao.thu_tu` KHÔNG so sánh được xuyên suốt QUY/NAM

**Phát hiện khi nào**: khi build tính năng "Biến động so với kỳ trước" cho thẻ tổng hợp tab Tuân
thủ (mục 2.2, sheet 1 dòng 39/41/43), cần lấy lũy kế nghĩa vụ tính tới 1 kỳ TRƯỚC kỳ hiện tại — dùng
lại `BcTuanThuChiTietRepository.findByProjectIdUpToKy` với `kyHienTai` = kỳ báo cáo liền trước. Kiểm
tra chéo bằng SQL trực tiếp trên DB thật thì phát hiện method này (đã có từ Phase 3, 2026-08-11)
**đang trả sai số liệu** trong trường hợp phổ biến nhất.

**Nguyên nhân**: method gốc so sánh `k.thu_tu <= thu_tu(kyHienTai)` — đúng như Javadoc cũ của
`DmKyBaoCao.thuTu` gợi ý ("dùng ORDER BY để lấy N kỳ gần nhất"). Nhưng đối chiếu data thật
(`dm_ky_bao_cao`) thì `thu_tu` **không phải chuỗi thời gian toàn cục** — nó được sinh theo thứ tự:
toàn bộ 46 kỳ QUÝ (2015-Q1..2026-Q2) trước (`thu_tu` 1–46), rồi TOÀN BỘ 11 kỳ NĂM
(2015-NAM..2025-NAM) được chèn vào giữa (`thu_tu` 47–57), rồi các kỳ QUÝ tiếp theo (2026-Q3...) lại
nối tiếp sau đó (`thu_tu` 58+). Nghĩa là **so sánh `thu_tu` giữa 1 kỳ QUÝ và 1 kỳ NĂM luôn sai** —
VD kỳ "2019-NAM" (`thu_tu`=51) bị coi là "sau" kỳ "2026-Q2" (`thu_tu`=46), dù 2019 cách rất xa
trong quá khứ so với 2026.

**Hệ quả cụ thể**: vì "kỳ hiện tại" của 1 dự án (`bcDinhKyRepository.findFirstByProjectId...`, báo
cáo mới nhất theo ngày nộp, không phân biệt loại kỳ) trong đa số trường hợp là 1 báo cáo QUÝ (báo
cáo quý nộp 4 lần/năm, dễ là báo cáo mới nhất hơn báo cáo năm chỉ nộp 1 lần/năm) — bug này khiến
**TOÀN BỘ dữ liệu ở kỳ NĂM bị loại khỏi lũy kế tab Tuân thủ trong đa số trường hợp thực tế**, cụ
thể: nhóm "Tiến độ" (`Nghia vu tien do`, chỉ tính kỳ NĂM theo rule ở mục Phase 3 dưới) gần như LUÔN
rỗng, và phần nộp báo cáo NĂM của nhóm "Nộp báo cáo định kỳ" cũng bị bỏ sót. Bug này tồn tại từ khi
build Phase 3 (2026-08-11), không liên quan gì tới các thay đổi mới hôm 2026-08-12 — chỉ tình cờ bị
phát hiện khi build tính năng "biến động kỳ trước" (lần đầu cần gọi lại method này với 1 kỳ cutoff
KHÁC kỳ hiện tại, mới lộ ra sự bất nhất khi so sánh chéo loại kỳ).

**Đã sửa**: `findByProjectIdUpToKy` đổi sang so sánh `k.ngay_ket_thuc <= ngay_ket_thuc(kyHienTai)`
(LocalDate thật, so sánh đúng xuyên suốt mọi loại kỳ) thay vì `thu_tu`. Đã verify lại bằng SQL trực
tiếp trên DB (dự án 100059): trước khi sửa, lũy kế trả về 4 nghĩa vụ hợp lệ (thiếu nhóm Tiến độ);
sau khi sửa, trả đúng 5 (đủ cả nhóm Tiến độ). Cập nhật thêm cảnh báo vào Javadoc
`DmKyBaoCao.thuTu` — chỉ dùng `thu_tu` để so sánh/sắp xếp khi đã lọc cùng 1 `loaiKy` trước (đúng
cách `KyBaoCaoResolverImpl`/`BcDinhKyRepository.findByProjectIdAndLoaiKy` đang làm), dùng
`ngayKetThuc` khi cần so sánh xuyên suốt cả 2 loại kỳ.

### 3.3. Spec công thức chi tiết (`Mô tả logic công thức.xlsx`, 4 sheet) — nguồn tham chiếu chính khi code

> **Cập nhật 2026-08-05**: file được bổ sung thêm sheet thứ 4 "Biến số khả dụng" (trước đó chỉ có
> 3 sheet). Tên sheet thật trong file (theo thứ tự tab): "Phân tích chuyên sâu" (= sheet 1 dưới
> đây), "Cấu hình cảnh báo" (= sheet 2, ngoài phạm vi), "Nhóm chỉ tiêu - chỉ tiêu" (= sheet 3),
> "Biến số khả dụng" (= sheet 4, mới).

- **Sheet 1 – "Phân tích chuyên sâu"** (~110 dòng công thức): với mỗi thành phần UI, liệt kê công thức + mapping field chi tiết cho **cả 5 mẫu báo cáo** — chính xác và đầy đủ hơn hẳn phần mô tả trong docx. Khi 2 nguồn (docx vs sheet này) mâu thuẫn, **ưu tiên sheet này**.
- **Sheet 3 – "Nhóm chỉ tiêu - chỉ tiêu"** (data dictionary): ma trận **Nhóm chỉ tiêu × Chỉ tiêu × Mẫu báo cáo × (Kỳ báo cáo / Lũy kế GCNDT)** — dùng làm bảng tham chiếu field mapping duy nhất khi viết mapper/ETL.
- **Sheet 4 – "Biến số khả dụng"** (mới): danh sách tên hiển thị ↔ tên field snake_case cho toàn bộ cột chuẩn hoá của `bc_dinh_ky` (17 biến, VD "Tổng vốn đầu tư đăng ký" → `tong_von_dau_tu_dang_ky`, "Lợi nhuân kỳ báo cáo" → `loi_nhuan`...). Đây chính là **spec đặt tên cột chính thức cho `bc_dinh_ky`** — đối chiếu lại thì entity `BcDinhKy` (đã code ở Phase 0) **khớp 100%** với danh sách này, không cần sửa entity.
- Sheet 2 (cấu hình ngưỡng cảnh báo, dashboard, chi tiết cảnh báo) — thuộc phần "Cảnh báo", ngoài phạm vi (mục 6).

### 3.4. Rủi ro/gap nghiệp vụ mới phát hiện (ảnh hưởng trực tiếp tới UI đã đặc tả trong docx)

1. **"Vốn khác" không có nguồn dữ liệu ở bất kỳ mẫu nào** (sheet 3: dòng "Vốn khác" trống cho cả 5 mẫu), nhưng tab Vốn & Giải ngân (docx 2.2.d) mô tả bar/donut chart có đủ 4 hạng mục gồm cả "Vốn khác". → **Cần hỏi BA**: bỏ hạng mục này, luôn hiển thị 0/"-", hay có nguồn khác chưa được liệt kê trong spec?
2. **Trạng thái tiến độ: 4/5 mẫu chỉ suy luận được 2/4 trạng thái.** Mẫu 103/37/116/114 chỉ fallback ra "Đúng tiến độ" / "Gặp khó khăn" từ text tự do `khoKhanVuongMac`; **không thể** tự suy ra "Chậm tiến độ" hay "Không có khả năng triển khai" bằng rule. Chỉ mẫu 89 có đủ 4 cờ boolean thật (`danhGia.dungTienDo/chamTienDo/khoKhanVuongMac/khongCoKhaNangTrienKhai`). → Ảnh hưởng: line chart Tiến độ (docx 2.2.e) hứa 4 trạng thái nhưng phần lớn dự án trong nước thực tế chỉ có 2/4 khả dụng; công thức điểm rủi ro nhóm Tiến độ (đúng=2.5/chậm=5/khó khăn=7.5/không thể=10) cũng gần như không bao giờ ra 5 hoặc 10 với dữ liệu trong nước.
3. **Điểm rủi ro nhóm "Tài chính" chia theo số chỉ tiêu khác nhau theo từng mẫu** (chia 4, 7, hoặc 8 tuỳ mẫu, không phải hằng số cố định) — công thức: số chỉ tiêu có Xu hướng giảm × (10 / số chỉ tiêu khả dụng của mẫu đó). Cần bảng cấu hình hoặc tính động số chỉ tiêu có dữ liệu, không hard-code chia 8.
4. **Ý nghĩa cột `cotA`/`cotB`/`cotC` KHÔNG giống nhau giữa các mẫu**: mẫu 103/114 → cotA=kỳ, cotC=lũy kế GCNDT (cotB không dùng); mẫu 37/116 → cotA=kỳ, cotB=lũy kế (không có cotC). → Mapper/ETL phải viết riêng theo `LoaiBaoCaoId`.
5. **`LoaiKy` trên bảng nguồn không đáng tin cậy** (rỗng/NULL trong toàn bộ data mẫu) — kỳ báo cáo (quý/năm) phải tự suy ra từ `LoaiBaoCaoId` (103,114→quý; 37,116→năm; 89→năm theo `NgayNop`), không đọc trực tiếp cột `LoaiKy`.
6. **(mới, 2026-08-05) Mẫu 89 không có field nguồn cho "Tổng mức đầu tư"** — sheet 1 dòng "Tổng mức đầu tư" ghi rõ mẫu 89 "(không có trong NoiDungChiTiet, sẽ check trong dữ liệu Dự án)". Ảnh hưởng: 1/5 KPI card ở header (mục 2.2.a) không có nguồn cho dự án ODI — service tính KPI phải trả `null`/"-" thay vì lỗi, không giả định field luôn có giá trị.
7. **(mới, 2026-08-05) Công thức "Tỷ lệ giải ngân" của mẫu 89 bị cắt cụt ngay trong sheet 1** — nội dung cell chỉ có `[Σ(vonChuyenRa.(tien+mayMocThietBi+taiSanKhac).giaTri.luyKe) / ` (thiếu mẫu số, không phải lỗi khi đọc file — đã kiểm tra lại raw XML của xlsx để loại trừ khả năng cắt do công cụ đọc). Kết hợp với điểm 6 (không có "Tổng mức đầu tư" làm mẫu số hiển nhiên), công thức này **chưa đủ để code** — cần hỏi lại BA.
8. **(mới, 2026-08-05) Mẫu 89 không có field nguồn cho "Đơn vị quản lý"** — sheet 1 dòng "Đơn vị quản lý" ghi mẫu 89 "Không có trường tương ứng — Có thể lấy từ phân hệ Dự án theo mã dự án". Khớp với thiết kế hiện tại: `dm_du_an.ten_tckt` được cache sẵn ở bảng dự án (Phase 1), nên tab Header không cần lo field này thiếu ở `bc_dinh_ky` — chỉ cần đọc từ `DmDuAn`, không đọc từ báo cáo.
9. **(mới, 2026-08-05) Nội bộ sheet 1 có mâu thuẫn ở công thức điểm rủi ro Tài chính**: mô tả cho mẫu 116 vừa nói "tính theo 7 chỉ tiêu... 10/7" vừa kết luận "tổng điểm rủi ro = ... × 10/8" (7 vs 8); mẫu 89 vừa nói "tính theo 4 chỉ tiêu... 10/4" vừa kết luận "× 10/5" (4 vs 5). Không chặn thiết kế hiện tại (Phase 3 đã chọn hướng "đếm số chỉ tiêu tài chính có dữ liệu thật, không hard-code hằng số" — mục 3.4 điểm 3), nhưng cần **chốt số chính xác với BA** trước khi viết unit test cho risk-score Tài chính ở Phase 3.
10. **(mới, 2026-08-05) "Thuế và nộp ngân sách" không nằm trong 8 chỉ tiêu hiển thị ở tab Tài chính** — dù có cột chuẩn hoá riêng (`bc_dinh_ky.thue_va_nop_ngan_sach_ky`) và được sheet 1 dòng 19 liệt kê là field lấy cho mẫu 103/114/37/116, ảnh mock thật (`tai-chinh.png`) và mô tả "mặc định 8 chỉ tiêu" đầu dòng 19 đều không có nó. Cần hỏi BA field này hiển thị ở đâu (nếu có).
11. **(mới, 2026-08-05) `dm_du_an` chưa có field "thời hạn hoạt động" (số năm) của dự án** — cần cho công thức "Kế hoạch kỳ (tỷ)" ở tab Vốn & Giải ngân (sheet 1 dòng 61: `tổng mức đầu tư / (số năm hoạt động × 4) × số quý đã hoạt động`). Không phải `ngayCapGcndt` (ngày cấp, không phải thời hạn). Nhiều khả năng cùng nguồn với `linhVuc`/`diaBan`/`tenTckt` (phân hệ Dự án ngoài). Đang trả `null` cho `keHoachKy`/`chenhLech` ở tab này.

> **Ghi chú thiết kế đã chốt ngầm ở Phase 0 (chưa từng viết ra, bổ sung ở đây cho rõ)**: entity
> `BcDinhKy` không lưu trực tiếp `LoaiBaoCaoId` (103/37/116/114/89) — thay vào đó suy ra "mẫu nào"
> từ cặp `loaiDuAn` (DDI/FDI/ODI) × loại kỳ của `kyKey` (QUY/NAM), theo giả thuyết ánh xạ 1-1:
> DDI+QUY→103, DDI+NAM→37, FDI+QUY→114, FDI+NAM→116, ODI→89 (luôn NAM, suy từ `NgayNop` theo điểm
> 5 ở trên). **Đây là giả thuyết suy luận từ cấu trúc dữ liệu, CHƯA được BA xác nhận trực tiếp** —
> `ma_bao_cao` gốc (`FDI_AIII1_548`...) có thể mã hoá mẫu theo cách khác mà data mẫu hiện có không
> đủ để kiểm chứng dứt khoát. Dùng tạm cho Phase 2 (hiển thị "nguồn trích dẫn" ở tab Tổng quan), cần
> chốt lại với BA trước khi phụ thuộc nó cho logic quan trọng hơn (VD chọn công thức rủi ro Tài
> chính ở Phase 3).

## 4. Điểm cần làm rõ (cập nhật theo ngữ cảnh mới)

| # | Nội dung | Trạng thái |
| --- | --- | --- |
| 1 | Nguồn "dự án" (`dm_du_an`): đồng bộ từ phân hệ dự án hay bảng riêng? | Vẫn mở — nhưng field list đã rõ hơn nhờ schema đề xuất (mục 3.2) |
| 2 | Nguồn `bc_dinh_ky`: cơ chế đọc từ bảng `BaoCao` (share DB / API / Kafka)? | **Đã xác nhận nguồn** (mục 3.1); cơ chế đồng bộ vẫn cần chốt |
| 3 | "Trung bình ngành" tính real-time hay batch? | **Có gợi ý**: bảng `bc_chi_tieu_trung_binh` có `updated_at` → hướng batch; cần chốt job/schedule |
| 4 | Mô hình dự báo dùng thuật toán nào? | Vẫn mở — `bc_du_bao.model_meta_json` gợi ý có model thật nhưng chưa rõ thuật toán |
| 5 | LLM client dùng chung có sẵn không? | **Đã rõ hướng (2026-08-06)**: không cần LLM client trong app này — có job async riêng (ngoài phạm vi module `ptcb`) sinh insight/dự báo sau khi lưu báo cáo, ghi vào `ai_insight`/`bc_du_bao`; app chỉ cần đọc. Vẫn mở: ai/khi nào trigger job đó (Kafka event? scheduler?). |
| 6 | Export PNG/zip: server-render hay FE tự capture? | Vẫn mở |
| 7 | Ngưỡng cấu hình động (rủi ro, gợi ý...) | **Ra khỏi phạm vi** — thuộc mảng "Cảnh báo", xem mục 6 |
| 8 (mới) | "Vốn khác" không có nguồn dữ liệu — bỏ hay giữ UI? | Mở (mục 3.4.1) |
| 9 (mới) | Chấp nhận 2/4 trạng thái tiến độ cho báo cáo trong nước, hay cần nguồn dữ liệu khác? | Mở (mục 3.4.2) |
| 10 (mới 2026-08-05) | KPI "Tổng mức đầu tư" và công thức "Tỷ lệ giải ngân" của mẫu 89 (ODI) không có nguồn field rõ ràng | Mở (mục 3.4 điểm 6–7) — Phase 2 tạm trả `null`/"-" cho dự án ODI |
| 11 (mới 2026-08-05) | Số chỉ tiêu chia trong công thức điểm rủi ro Tài chính của mẫu 116 (7 hay 8) và mẫu 89 (4 hay 5) — sheet 1 tự mâu thuẫn | Mở (mục 3.4 điểm 9) — chặn unit test chính xác của Phase 3, không chặn Phase 2 |
| 12 (mới 2026-08-05) | Suy luận "mẫu nào" (103/37/116/114/89) từ `loaiDuAn`×loại kỳ có đúng 100% không, hay `ma_bao_cao` gốc mã hoá khác? | Mở (mục 3.4, ghi chú sau điểm 9) |
| 13 (mới 2026-08-05) | "Thuế và nộp ngân sách" có cột chuẩn hoá riêng nhưng không hiển thị ở tab Tài chính (theo ảnh mock) — hiển thị ở đâu khác, hay không dùng? | Mở (mục 3.4 điểm 10) |
| 14 (mới 2026-08-05) | `dm_du_an` chưa có field "thời hạn hoạt động dự án" (số năm theo giấy phép) — cần cho "Kế hoạch kỳ (tỷ)" ở tab Vốn & Giải ngân | Mở (mục 3.4 điểm 11) — tạm trả `null` cho `keHoachKy`/`chenhLech` |
| 15 (mới 2026-08-12) | Công thức điểm rủi ro Vốn & Giải ngân (sheet 1 dòng 84): "số kỳ hoạt động" định nghĩa thế nào (số kỳ theo lịch từ ngày cấp GCNDT, hay số kỳ đã CÓ báo cáo)? | Mở — Phase 3 tạm dùng tổng số báo cáo định kỳ dự án đã nộp (`BcDinhKyRepository.countByProjectId`), xem Javadoc `RuiRoCalculator#diemRuiRoVonGiaiNgan` |
| 16 (mới 2026-08-12) | Cùng công thức trên: `percentileRank` theo quy ước nào (tỷ lệ ≤ giá trị, hay `PERCENTRANK.INC` kiểu Excel `(hạng-1)/(n-1)`)? | Mở — Phase 3 tạm dùng "tỷ lệ phần tử ≤ giá trị đang xét". Không chặn bởi data mẫu: 100 dự án mẫu hiện có CÙNG giá trị `tong_von_dau_tu_dang_ky` nên percentile luôn ra 1.0, chưa test được biến thiên thật |

## 5. Đề xuất kế hoạch triển khai (theo `docs/clean_architecture_guide.md` & convention `com.ai.ptcb`)

Tiếp tục trong module `ptcb`, dùng `BaseAudit` + tên bảng/cột tiếng Việt, audit thủ công qua `UserContext.getTaiKhoanId()`.

### Phase 0 — Chốt open questions (mục 4) + thiết kế DB — **ĐÃ XONG**

- Dùng `schema_fixed.sql` làm **điểm khởi đầu tham khảo**, không copy nguyên — thiết kế lại entity theo 5 điều chỉnh ở mục 3.2 và điền `BaseAudit`.
- Entity đã code: `DmDuAn`, `BcDinhKy` (JSONB raw + cột chuẩn hoá — cột chuẩn hoá đã khớp 100% với sheet 4 "Biến số khả dụng", xem mục 3.3), `AiInsight`, `BcRuiRoChiTiet`, `BcTuanThuChiTiet` (+ `DmNghiaVuTuanThu`), `BcDuBao`, `BcChiTieuTrungBinh`, `DmNganh`, `DmKyBaoCao` — tất cả ở `com.ai.ptcb.domain.entity`, kèm repository (Spring Data JPA, chưa có query method riêng ngoài Phase 1/2). Seed data mẫu ở `PhanTichChuyenSauSeedInitializer` (đọc từ `db/seed/phan-tich-chuyen-sau-sample-data.sql`).
- ETL ghi từ `NoiDungChiTiet` (raw JSON) → cột chuẩn hoá của `bc_dinh_ky` theo từng `LoaiBaoCaoId` **chưa code** — đây là open question #2 (cơ chế đồng bộ từ bảng `BaoCao` nguồn), tách riêng khỏi Phase 2. Phase 2 đọc thẳng cột chuẩn hoá đã có sẵn trong `bc_dinh_ky` (qua seed data), không phụ thuộc ETL.
- Cấu hình "số chỉ tiêu tài chính theo mẫu" (mục 3.4.3) — chưa thêm, để dành cho Phase 3 (risk-score Tài chính).

### Phase 1 — Danh sách dự án (6.1) — **ĐÃ XONG**

- `DmDuAnController`/`DmDuAnService`/`DmDuAnRepository`: search (keyword + 4 filter optional) có phân trang, get-detail, và endpoint `GET /filter-options` (danh mục distinct cho 4 select box lọc nâng cao).

### Phase 2 — Header + KPI card + Tab Tổng quan (6.2.a, 6.2.b) — **đã code xong bản đầu, đối chiếu ảnh mock 2026-08-05**

- Mapper riêng theo từng `LoaiBaoCaoId` (103/37/116/114/89): **không cần** ở Phase 2 vì ETL (mục Phase 0) chưa code — Phase 2 đọc thẳng cột chuẩn hoá sẵn có trên `bc_dinh_ky`, vốn đã template-agnostic (ETL tương lai sẽ chịu trách nhiệm quy đổi cotA/cotB/cotC theo từng mẫu về đúng 1 cột chuẩn hoá).
- Calculator riêng cho từng KPI, pure function, dễ unit test — xem `com.ai.ptcb.application.service.calculator.KpiCalculator`.
- KPI "Tổng mức đầu tư"/"Tỷ lệ giải ngân" trả `null` cho dự án ODI (mẫu 89) — xem mục 3.4 điểm 6–7, mục 4 #10.
- Đối chiếu với `.claude/tasks/phantichchuyensau/images/chi-tiet-tong-quan.png` (2026-08-05): header ban đầu thiếu `diaBan`, thiếu `ngayNhanBcGanNhat` (ảnh cần 2 mốc ngày khác nhau: "Ngày nhận" vs "Thời điểm chốt số liệu" — cả 2 field đã có sẵn trên `bc_dinh_ky`), KPI Tuân thủ thiếu tổng số nghĩa vụ (`tongSoNghiaVuTuanThu`) — cả 3 đã bổ sung. "Nguồn trích dẫn" cũng đã làm giàu thêm (mã báo cáo + tên TCKT + kỳ), nhưng tên loại báo cáo chính thức vẫn cần field `ten_bao_cao` map từ bảng `LoaiBaoCaos` ngoài hệ thống (mục 3.2 điểm 1) — hiện tạm dùng tên mẫu suy luận thay thế.
- 2 điểm phát hiện thêm từ ảnh mock, **đã xác nhận với người dùng: chờ Phase 5 (LLM client) mới xử lý**, không sửa rule-based thêm ở Phase 2:
  - KPI "Tiến độ thực tế" trong ảnh hiển thị 1 kỳ (VD "Quý IV/2023") làm giá trị chính + nhãn trạng thái là dòng phụ — khác thiết kế hiện tại (chỉ trả nhãn trạng thái). Có thể do data giả trong mock, cần xác nhận lại khi có LLM/insight thật.
  - Đoạn "Tiến độ thực hiện" và "Khó khăn, vướng mắc" ở tab Tổng quan trong ảnh là 2 nội dung khác nhau, nhưng bản rule-based hiện tại lấy chung 1 nguồn `bc_dinh_ky.kho_khan_vuong_mac` cho cả 2 → trùng nội dung. Sẽ tách bằng LLM insight riêng cho "Tiến độ thực hiện" ở Phase 5.
- Tab Tổng quan: ghép 4 đoạn mô tả, rule-based (chưa gọi LLM — client dùng chung vẫn là open question #5, để dành Phase 5).
- **(sửa lỗi, 2026-08-05) "Kỳ này/kỳ trước" ban đầu KHÔNG lọc theo loại kỳ** — dùng `findTop2ByProjectIdOrderByNgayNopBaoCaoDescReportIdDesc` lấy 2 bản ghi mới nhất bất kể quý/năm, nên nếu dự án vừa nộp báo cáo năm ngay sau báo cáo quý IV thì "kỳ trước" sẽ lấy nhầm báo cáo quý thay vì báo cáo năm liền trước (hoặc ngược lại) — người dùng phát hiện qua nhận xét "1 dự án sẽ có 4 báo cáo quý và 1 báo cáo năm, cùng kỳ là so sánh cùng quý hoặc cùng năm". Đã sửa: thêm `KyBaoCaoResolver`/`KyBaoCaoResolverImpl` (`com.ai.ptcb.application.service`) — xác định loại kỳ (quý/năm) của báo cáo mới nhất, rồi chỉ lấy N báo cáo gần nhất **cùng loại kỳ đó** qua `BcDinhKyRepository.findByProjectIdAndLoaiKy` (JPQL, lọc qua subquery `dm_ky_bao_cao.loai_ky`). Áp dụng cho cả tab Tổng quan (Phase 2) lẫn Tài chính/Vốn & Giải ngân/Tiến độ (Phase 3) — xem các mục bên dưới.

### Phase 3 — Tab theo từng nhóm chỉ tiêu (Tài chính, Vốn & Giải ngân, Tiến độ, Tuân thủ, Rủi ro)

- Mỗi tab 1 service riêng; risk-score Tài chính dùng số chỉ tiêu động theo mẫu (mục 3.4.3), không hard-code.
- Tiến độ: xử lý rõ trường hợp chỉ 2/4 trạng thái khả dụng cho báo cáo trong nước (mục 3.4.2) — cần quyết định nghiệp vụ trước khi code UI cho 4 trạng thái.
- Vốn & Giải ngân: xử lý "Vốn khác" theo quyết định ở mục 3.4.1.
- Rủi ro: trả flag `hasCriticalOrHighRisk` cho tab Gợi ý.

#### Tab Tài chính — **đã code xong** (2026-08-05)

- `TabTaiChinhService`/`Impl` mới, cùng nhóm với `ChiTietDuAnController` (`GET .../chi-tiet/tai-chinh`). Lấy kỳ này/kỳ trước qua `KyBaoCaoResolver.layNBaoCaoGanNhatCungLoaiKy(projectId, 2)` — đã sửa để chỉ so cùng loại kỳ (quý/năm), xem ghi chú sửa lỗi ở Phase 2.
- 8 chỉ tiêu tài chính cố định — enum `ChiTieuTaiChinh` (`com.ai.ptcb.application.service.calculator`), mỗi giá trị gắn kèm hàm lấy field tương ứng trên `BcDinhKy` (Doanh thu, Lợi nhuận, Lợi nhuận sau thuế, Nguồn thu khác, Giá trị XK, Giá trị NK, Chi phí R&D, Chi phí môi trường). Chỉ tiêu không có dữ liệu ở CẢ 2 kỳ thì ẩn khỏi response (đúng rule "nếu báo cáo không có → không hiển thị" — sheet 1 dòng 19).
- Công thức % biến động + xu hướng (Tăng/Giảm) + nhận định rule-based (chỉ tiêu biến động mạnh nhất) — `TaiChinhCalculator`, pure function.
- **(mới, phát hiện khi đối chiếu `.claude/tasks/phantichchuyensau/images/tai-chinh.png`) "Thuế và nộp ngân sách" (`bc_dinh_ky.thue_va_nop_ngan_sach_ky`) KHÔNG nằm trong 8 chỉ tiêu hiển thị ở tab này** — dù sheet 3 (data dictionary) liệt kê nó là 1 chỉ tiêu tài chính hợp lệ có cột chuẩn hoá riêng, và cột mẫu-cụ-thể của sheet 1 dòng 19 (mẫu 103/114/37/116) lại liệt kê "thuế&ngân sách nhà nước" như 1 trong số field được lấy. Ảnh mock thật (8 dòng bar chart + bảng) khớp chính xác với mô tả "mặc định 8 chỉ tiêu" ở đầu dòng 19 (không có thuế&ngân sách), nên ưu tiên theo ảnh + mô tả mặc định, bỏ "Thuế và nộp ngân sách" khỏi tab này. **Cần hỏi lại BA**: field này hiển thị ở đâu khác, hay chỉ dùng nội bộ cho tab khác (VD Vốn & Giải ngân) không hiển thị trực tiếp?
- **Lưu ý về độ tin cậy của ảnh mock**: ảnh `tai-chinh.png` hiển thị đồng thời cả 8 chỉ tiêu có giá trị (kể cả "Lợi nhuận"/"Nguồn thu khác" — theo sheet 3 chỉ mẫu 89/ODI mới có — LẪN "Giá trị XK/NK"/"R&D"/"Môi trường" — theo sheet 3 chỉ mẫu trong nước 37/116 mới có), là tổ hợp **không thể xảy ra thật** với 1 báo cáo/mẫu cụ thể (không mẫu nào có đủ cả 8). Nội dung "Nhận định (AI Insights)" trong ảnh ("Chi phí tài chính tăng 28%...") cũng không khớp số liệu ở bảng phía trên cùng ảnh. Kết luận: ảnh mock chỉ đáng tin về **cấu trúc UI** (có đủ 8 slot, layout bar chart + bảng + insight), KHÔNG đáng tin về **tính nhất quán của số liệu mẫu** — code đã bám theo cấu trúc, không cố khớp số liệu/văn bản mẫu trong ảnh.

#### Tab Vốn & Giải ngân — **đã code xong** (2026-08-05)

- `TabVonGiaiNganService`/`Impl` mới (`GET .../chi-tiet/von-giai-ngan`). Dùng `KyBaoCaoResolver.layNBaoCaoGanNhatCungLoaiKy(projectId, 4)` cho biểu đồ "Cơ cấu nguồn vốn theo kỳ" (≤4 kỳ CÙNG loại kỳ, thứ tự tăng dần) — xem ghi chú sửa lỗi ở Phase 2.
- 3 hạng mục cố định của bảng "Chi tiết tình hình góp vốn" — enum `HangMucGopVon` (Vốn góp chủ sở hữu, Vốn vay, Lợi nhuận tái đầu tư — **không có** Vốn khác, đúng sheet 1 dòng 59 "fix cứng: vốn góp, vốn vay, lợi nhuận tái đầu tư").
- Công thức tổng cộng/tỷ trọng/chênh lệch/nhận định rule-based — `VonGiaiNganCalculator`, pure function. "Tỷ lệ đạt (%)" tái dùng nguyên `KpiCalculator.tyLeGiaiNgan` (cùng công thức với KPI card ở header — không viết lại).
- **"Vốn khác" (%) trả cứng = 0** trong `coCauTheoKy`/`coCauKyGanNhat` (biểu đồ theo kỳ + donut) vì không có nguồn dữ liệu ở bất kỳ mẫu nào (mục 3.4.1, mục 4 #8 — **vẫn mở với BA**, chưa tự quyết định bỏ hẳn field khỏi response).
- **(mới, 2026-08-05) Gap mới phát hiện khi code "Kế hoạch kỳ (tỷ)"**: công thức (sheet 1 dòng 61) = `tổng mức đầu tư / (số năm hoạt động × 4) × số quý đã hoạt động` — cần "số năm hoạt động" (thời hạn hoạt động dự án theo giấy phép, tính bằng năm) mà **`dm_du_an` hiện chưa có field này** (không phải `ngayCapGcndt`, mà là tổng thời hạn được phép hoạt động). → `TienDoGiaiNgan.keHoachKy`/`chenhLech` tạm trả `null`, chỉ `thucHien`/`tyLeDat`/`tongMucDauTu` tính được. Xem mục 4 #13 (open question mới) — nhiều khả năng field này cũng lấy từ phân hệ Dự án như `linhVuc`/`diaBan`/`tenTckt`.
- Đối chiếu `.claude/tasks/phantichchuyensau/images/von-giai-ngan.png`: số liệu ví dụ trong ảnh (Thực hiện 852.5 tỷ / Kế hoạch kỳ 937.5 tỷ → Chênh lệch hiển thị -6,8%) **không khớp** phép tính (Thực hiện−Kế hoạch)/Kế hoạch = -85/937.5 = -9,07%, không phải -6,8% — cùng kiểu số liệu mẫu không nhất quán đã thấy ở ảnh Tổng quan/Tài chính. Không cố khớp số theo ảnh, chỉ bám công thức ở sheet 1.

#### Tab Tiến độ — **đã code xong** (2026-08-05)

- `TabTienDoService`/`Impl` mới (`GET .../chi-tiet/tien-do`). Dùng `KyBaoCaoResolver.layNBaoCaoGanNhatCungLoaiKy(projectId, 5)` — ≤5 kỳ CÙNG loại kỳ, khớp "Bảng dữ liệu tiến độ chi tiết ... tối thiểu 5 kỳ báo cáo gần nhất" (sheet 1 dòng 30) — xem ghi chú sửa lỗi ở Phase 2.
- `dienBienTienDo` (line chart) trả theo thứ tự **tăng dần** thời gian; `bangChiTiet` (bảng ma trận ✓/✗/⚠/ⓘ) trả theo thứ tự **giảm dần** (kỳ gần nhất lên đầu, `hienTai=true`) — khớp đúng 2 hướng hiển thị khác nhau thấy trong ảnh mock (line chart trái→phải theo thời gian, bảng mới nhất ở trên).
- Tái dùng `KpiCalculator.nhanTienDo`/`nhanDinhTienDo` (đã tách ra từ Tab Tổng quan ở Phase 2, dùng chung cho cả 2 nơi thay vì viết lại).
- Nhắc lại gap đã biết (mục 3.4.2, mục 4 #9, **không phải phát hiện mới**): với báo cáo trong nước (mẫu 103/37/116/114), `tienDoTrangThai` chỉ có thể là `dungTienDo`/`khoKhanVuongMac` (rule-based fallback) — 2 cột "Chậm tiến độ"/"Không có khả năng triển khai" trong `bangChiTiet` sẽ luôn `false` với các dự án này. Ảnh mock `tien-do-thuc-hien.png` cho thấy dữ liệu có cả trạng thái "Chậm tiến độ" (dòng "Quý I/2024") — chỉ khả dụng thật với báo cáo có `danhGia.*` (mẫu 89/ODI) hoặc khi có nguồn dữ liệu tốt hơn free-text `khoKhanVuongMac`.

#### Tab Tuân thủ — **đã code xong** (2026-08-11, cập nhật 2026-08-12)

- `TabTuanThuService`/`Impl` mới (`GET .../chi-tiet/tuan-thu`). Số liệu LŨY KẾ từ trước tới kỳ báo cáo gần nhất (khác KPI "Tuân thủ (%)" ở header, Phase 2, chỉ đếm 1 kỳ) — lấy qua `BcTuanThuChiTietRepository.findByProjectIdUpToKy`. Tab này không có insight AI (mục 2.2).
- Bảng cây cha/con: cha = `tenNhomSnapshot`, con = từng nghĩa vụ đã ghi nhận; "đánh giá" của cha = `vi_pham` nếu có ≥1 con `vi_pham` (suy luận "worst-case", spec không có công thức rollup rõ ràng).
- **(xác nhận 2026-08-11, đối chiếu sheet "Nhóm chỉ tiêu - chỉ tiêu" dòng 28–29) 2/5 nhóm không có chỉ tiêu con**: "Thủ tục đăng ký cấp tài khoản báo cáo" và "Quy định pháp luật về môi trường, xây dựng và các quy định khác" — cột "Chỉ tiêu" trống trong sheet, công thức luôn là "mặc định tuân thủ" cho cả 5 mẫu báo cáo (khác nhóm Tài chính có 8 chỉ tiêu con, hay nhóm Tiến độ/Nộp báo cáo định kỳ có 1 chỉ tiêu con thật với field + công thức rõ ràng). Đã sửa `TabTuanThuServiceImpl.xayDungNhomTuanThu`: 2 nhóm này luôn trả `danhGia=tuan_thu` + `chiTiet=[]`, KHÔNG rollup từ `bc_tuan_thu_chi_tiet` thật dù có dữ liệu (seed data mẫu hiện có vài dòng `vi_pham` ngẫu nhiên cho nhóm "Thủ tục đăng ký..." — data mẫu chưa khớp rule này, không dùng làm nguồn tin cho 2 nhóm đó).
- ~~Chưa xử lý (biết nhưng chưa sửa...): `tongSoNghiaVu`/`tongSoTuanThu`/... vẫn tính trên TOÀN BỘ `luyKe` thật, kể cả 2 nhóm mặc định~~ — **ĐÃ CHỐT & SỬA (2026-08-12, xem mục ngay dưới)**: 2 nhóm mặc định giờ hoàn toàn KHÔNG dùng dữ liệu `bc_tuan_thu_chi_tiet` nữa (kể cả cho tổng số), nên gap "tổng lệch bảng cây" này không còn khả năng xảy ra — 2 nguồn giờ tách biệt hoàn toàn, không thể lệch nhau.
- **(chốt với người dùng 2026-08-12, thay thế hoàn toàn cách làm cũ ở trên) 2 nhóm "mặc định tuân thủ" không dùng `bc_tuan_thu_chi_tiet` nữa — tính từ SỐ BÁO CÁO ĐÃ NỘP**: lý do đổi — nếu 1 dự án tình cờ có 0 dòng `bc_tuan_thu_chi_tiet` cho 1 trong 2 nhóm này (xảy ra thật, VD dự án 100013 không có dòng "Quy dinh phap luat" nào), nhóm đó biến mất hoàn toàn khỏi bảng cây (bug — `xayDungNhomTuanThu` chỉ tạo entry cho nhóm có ≥1 dòng trong `luyKe`). Quy tắc mới: **mỗi báo cáo định kỳ (`bc_dinh_ky`, mọi loại kỳ) dự án đã nộp mặc định coi như đã thoả CẢ 2 nghĩa vụ này** — hoàn toàn không đọc `bc_tuan_thu_chi_tiet` cho 2 nhóm này nữa (loại khỏi `locNghiaVuHopLe` giống nhóm "Tài chính").
  - Số nghĩa vụ mặc định cộng vào `tongSoNghiaVu`/`tongSoTuanThu` = 2 × (tổng số báo cáo đã nộp lũy kế tới kỳ đang xét, `BcDinhKyRepository.countByProjectIdUpToKy` — mới thêm, so `ngay_ket_thuc` để đúng xuyên suốt QUY/NAM, xem mục 3.2ter). Luôn tuân thủ, không đóng góp vi phạm.
  - Bảng cây (`xayDungNhomTuanThu`) giờ APPEND CỨNG 2 entry này vào cuối danh sách (không phụ thuộc `luyKe` groupingBy nữa) — đảm bảo LUÔN xuất hiện với mọi dự án đã có ≥1 báo cáo, `chiTiet=[]`.
  - Áp dụng cho cả kỳ hiện tại lẫn kỳ trước (tính "biến động so với kỳ trước" — mục ngay trên) — dùng đúng số báo cáo lũy kế tại từng mốc cutoff tương ứng.
- **(xác nhận thêm 2026-08-11, cùng session) 3 rule khác theo nhóm, đã áp dụng ở `TabTuanThuServiceImpl.locNghiaVuHopLe` — lọc TRƯỚC khi tính bất cứ số liệu nào (khác với 2 nhóm ở trên, chỉ sửa ở bảng cây, chưa sửa tổng)**:
  - Nhóm "Tài chính" (`Nghia vu tai chinh`): chưa có công thức tuân thủ → **loại hoàn toàn** khỏi response, kể cả khỏi `tongSoNghiaVu`/tỷ lệ tổng thể (khác 2 nhóm "mặc định tuân thủ" ở trên — nhóm này không hiện cả trong bảng cây, không có node cha nào tên "Tài chính").
  - Nhóm "Tiến độ" (`Nghia vu tien do`): chỉ xác định tuân thủ theo báo cáo NĂM — bản ghi ở kỳ QUÝ của nhóm này bị loại khỏi mọi tính toán (tra `dm_ky_bao_cao.loai_ky` theo từng `ky_key`, không dựa trực tiếp `nghia_vu_id` vì đó chỉ là snapshot lịch sử tại thời điểm ghi nhận).
  - Nhóm "Nộp báo cáo định kỳ" (`Bao cao dinh ky`): NGƯỢC LẠI — lấy toàn bộ báo cáo đã nộp của dự án, không phân biệt quý/năm (hành vi mặc định, không cần lọc thêm — chỉ ghi lại để tránh nhầm đây cũng theo rule "chỉ NĂM" như nhóm Tiến độ).
- **(cập nhật 2026-08-12) Sheet công thức đổi số dòng + bổ sung công thức "Thực tế ghi nhận" cho 4/5 nhóm — đã code**:
  - File `Mô tả logic công thức.xlsx` xoá cột "Tên nghĩa vụ" (dòng 46 cũ) và đổi tên bảng thành **"Bảng chi tiết tuân thủ cam kết"**; sheet 1 giờ chỉ còn dòng 47 (Tên nhóm nghĩa vụ), 48 (Trạng thái), 49 (Thực tế ghi nhận). Dòng 49 nêu rõ công thức cho từng nhóm: "Quy định pháp luật..."/"Thủ tục đăng ký..." → mặc định `"Đạt yêu cầu theo quy định"`; "Tiến độ" → `bc_dinh_ky.tien_do_trang_thai + bc_dinh_ky.ky_key`; "Nộp báo cáo định kỳ" → tên báo cáo + thời gian nộp (công thức đánh giá Trạng thái của nhóm này tham chiếu tiếp sang sheet "Nhóm chỉ tiêu - chỉ tiêu" dòng 30: so `NgayNop` với hạn nộp bc — quý: trước 10 tháng đầu quý sau; năm: trước 31/3 năm sau).
  - Đối chiếu bằng script (parse seed SQL) thì **data mẫu KHÔNG khớp 2 công thức này**: 12/84 bản ghi "Nộp báo cáo định kỳ" và 25/91 bản ghi "Tiến độ" có `trang_thai`/`thuc_te_ghi_nhan` lưu sẵn trong `bc_tuan_thu_chi_tiet` sai lệch so với công thức tính từ field thật (`ngay_nop_bao_cao`/`tien_do_trang_thai` ở `bc_dinh_ky`) — seed gán 2 giá trị boilerplate độc lập, không theo công thức.
  - Đã sửa `TabTuanThuServiceImpl`: thêm bước `tinhLaiTrangThaiVaThucTe` — với nhóm "Tiến độ"/"Nộp báo cáo định kỳ", TÍNH LẠI cả `trangThai` và `thucTeGhiNhan` từ `bc_dinh_ky` (join theo `project_id`+`ky_key` qua `BcDinhKyRepository.findByProjectIdAndKyKeyIn`, mới thêm), KHÔNG dùng giá trị lưu sẵn nữa. Công thức hạn nộp + 2 hàm suy luận trạng thái tách thành pure function ở `TuanThuCalculator` (`hanNopBaoCao`, `trangThaiNopBaoCaoDinhKy`, `trangThaiTienDo`) — có unit test ở `TuanThuCalculatorTest`. "Thực tế ghi nhận" nhóm "Nộp báo cáo định kỳ" tái dùng `KpiCalculator.tenMauBaoCao` (suy luận mẫu từ `loaiDuAn`×loại kỳ, cùng nguồn dùng cho "nguồn trích dẫn" ở tab Tổng quan — kèm hạn chế đã biết: chưa có field `ten_bao_cao` chính thức, xem mục 3.2 điểm 1) + `maBaoCao` + `ngayNopBaoCao`.
  - 2 nhóm "mặc định tuân thủ" giữ nguyên hành vi cũ (không có công thức nào để tính lại) — nhưng bổ sung field `NhomTuanThuItem.thucTeGhiNhan` (cấp NHÓM, không phải cấp con — vì 2 nhóm này không có `chiTiet`) để mang giá trị mặc định `"Đạt yêu cầu theo quy định"` theo đúng dòng 49, thay vì bỏ trống hoàn toàn như trước.
  - **Mock `tuan-thu.png` đã được cập nhật lại (2026-08-12), giải quyết mâu thuẫn từng ghi nhận trước đó**: bản mock mới KHÔNG còn nhóm "Tài chính" (khớp đúng quyết định loại hoàn toàn nhóm này ở trên) và show rõ nội dung "Thực tế ghi nhận" đúng theo công thức mới (nhóm Tiến độ: 4 dòng con là các giá trị `tien_do_trang_thai` khác nhau kèm kỳ NĂM riêng; nhóm Nộp báo cáo định kỳ: tên báo cáo + thời gian nộp) — khớp với hướng code đã sửa ở trên.
- **(cập nhật thêm 2026-08-12, cùng ngày) Sheet 1 bổ sung 3 dòng "Biến động so với kỳ trước" (dòng 39/41/43) cho phần "Thẻ tổng hợp chỉ số"** — mỗi dòng gắn ngay sau 1 trong 3 chỉ số (Tổng số nghĩa vụ/Tổng số tuân thủ/Tổng số vi phạm), công thức: `Tăng/Giảm '(X kỳ này − X kỳ trước) / X kỳ trước'`. Khớp đúng badge "+2%/+10%/-2% so với kỳ trước" đã thấy ở ảnh mock từ trước (trước đó chưa có công thức tương ứng nên chưa code).
  - Đã thêm 3 field `bienDongTongSoNghiaVu`/`bienDongTongSoTuanThu`/`bienDongTongSoViPham` (BigDecimal %, dấu âm = giảm) vào `TabTuanThuResponse`, công thức pure function `TuanThuCalculator.bienDongPhanTram(long kyNay, long kyTruoc)` (có unit test).
  - **"Kỳ trước" hiểu là**: vì số liệu tab này vốn LŨY KẾ (không phải phát sinh riêng theo từng kỳ), "kỳ trước" = lũy kế tính TỚI kỳ báo cáo LIỀN TRƯỚC kỳ báo cáo hiện tại (cùng loại kỳ, qua `KyBaoCaoResolver` — nhất quán với rule "không trộn quý/năm" áp dụng xuyên suốt plan). `TabTuanThuServiceImpl.getTabTuanThu` giờ gọi `kyBaoCaoResolver.layNBaoCaoGanNhatCungLoaiKy(projectId, 2)` để lấy cả kỳ hiện tại lẫn kỳ trước, và gọi lại đúng logic lũy kế (`tinhLuyKe`, refactor từ code cũ) 2 lần với 2 mốc cutoff khác nhau. Đây là 1 diễn giải hợp lý nhưng KHÔNG được sheet nêu tường minh — nếu BA có ý khác (VD "kỳ trước" là kỳ liền trước theo lịch bất kể loại kỳ), cần chốt lại.
  - `null` nếu dự án chưa có kỳ báo cáo trước đó, hoặc tổng số kỳ trước = 0 (không có mẫu số để tính %).
  - **Phát hiện + sửa 1 bug nền tảng trong lúc build tính năng này** — xem mục 3.2ter (mới): `BcTuanThuChiTietRepository.findByProjectIdUpToKy` so sánh sai `thu_tu` xuyên suốt QUY/NAM, khiến nhóm "Tiến độ" gần như luôn rỗng với đa số dự án (bug có từ Phase 3 2026-08-11, không liên quan trực tiếp thay đổi hôm nay, chỉ tình cờ lộ ra khi cần gọi lại method này với 1 cutoff khác).

#### Tab Rủi ro — **đã code xong** (2026-08-11, cập nhật 2026-08-12)

- `TabRuiRoService`/`Impl` (`GET .../chi-tiet/rui-ro`). Gauge tổng quát (0–10, trung bình 4 danh mục — `KpiCalculator.diemRuiRoTongQuat`) + 4 danh mục con (Tài chính/Tiến độ/Vốn & Giải ngân/Tuân thủ, fix cứng theo enum `DanhMucRuiRo`) + bảng chi tiết + `hasCriticalOrHighRisk` cho tab Gợi ý.
- **(cập nhật 2026-08-12) Sheet "Phân tích chuyên sâu" dòng 84 đã bổ sung đầy đủ công thức điểm rủi ro cho cả 4 danh mục** (trước đó chỉ có công thức Tài chính, 3 danh mục còn lại chưa có formula) — đã sửa code để **tính lại** cả 4 điểm, không còn thiết kế cũ "chờ 1 job async ghi sẵn vào `bc_rui_ro_chi_tiet.gia_tri_diem`/`muc_do`" (thiết kế cũ đó chưa có job nào thật tồn tại — cùng tình trạng với tab Tuân thủ trước khi sửa hôm 2026-08-12, xem mục ngay trên). `bc_rui_ro_chi_tiet` giờ chỉ còn dùng để tra `insight_id` (AI insight "diễn giải nguyên nhân" — vẫn cần LLM thật, không phải công thức xác định).
- 4 công thức (pure function ở `RuiRoCalculator`, unit test ở `RuiRoCalculatorTest`):
  - **Tài chính**: số chỉ tiêu có Xu hướng "Giảm" × 10/x, x = số chỉ tiêu tài chính có dữ liệu (đúng rule hiển thị của tab Tài chính — tái dùng `ChiTieuTaiChinh`/`TaiChinhCalculator`, không viết lại logic biến động/xu hướng). x tự nhiên khác 4/7/8 theo từng mẫu báo cáo, không hard-code — khớp mục 3.4 điểm 3/9 (số chính xác 7 vs 8 cho mẫu 116, 4 vs 5 cho mẫu 89 vẫn là mâu thuẫn nội bộ trong sheet, chưa chốt với BA, nhưng không ảnh hưởng cách tính "x động theo dữ liệu thật" đã chọn).
  - **Tiến độ**: map trực tiếp `bc_dinh_ky.tien_do_trang_thai` của báo cáo gần nhất → đúng tiến độ=2.5/chậm tiến độ=5/gặp khó khăn=7.5/không có khả năng triển khai=10.
  - **Tuân thủ**: tái dùng `mucDoRuiRoHeThong` đã tính sẵn ở tab Tuân thủ (gọi `TabTuanThuService.getTabTuanThu` từ `TabRuiRoServiceImpl` — service gọi service qua interface, không tính lại tỷ lệ vi phạm ở đây) → thấp=2.5/trung bình=5/cao=7.5/nghiêm trọng=10.
  - **Vốn & Giải ngân**: `10 × tỷ_lệ_chưa_giải_ngân × [0,60 + 0,25×(1−e^(−ln2/3×số_kỳ_hoạt_động)) + 0,15×percentileRank(ln(1+tổng_vốn_đầu_tư_đăng_ký))]`. Đây là công thức phức tạp nhất, có **2 giả định chưa được BA xác nhận** (ghi trong Javadoc `RuiRoCalculator#diemRuiRoVonGiaiNgan`, cần chốt trước khi tin tưởng số liệu này cho quyết định thật):
    1. "Số kỳ hoạt động" hiểu là tổng số báo cáo định kỳ dự án đã nộp tới hiện tại (`BcDinhKyRepository.countByProjectId`, mọi loại kỳ) — sheet không định nghĩa rõ đây là số kỳ theo lịch (từ ngày cấp GCNDT) hay số kỳ đã CÓ báo cáo.
    2. `percentileRank` tính theo quy ước "tỷ lệ phần tử trong tập ≤ giá trị đang xét" (0–1), KHÔNG phải công thức `PERCENTRANK.INC` chuẩn của Excel (`(hạng−1)/(n−1)`) — sheet không nêu định nghĩa cụ thể.
    - Tập tham chiếu percentile lấy TOÀN BỘ danh mục dự án qua query mới `BcDinhKyRepository.layTongVonDauTuDangKyMoiNhatToanDanhMuc` (native SQL `DISTINCT ON`, 1 giá trị mới nhất/dự án) — **tính LIVE mỗi lần gọi API**, chấp nhận được ở quy mô ~100 dự án mẫu hiện tại nhưng cần đánh giá lại (cache/batch, giống hướng "trung bình ngành" ở mục 4 #3) nếu số dự án tăng lớn.
    - **Phát hiện khi kiểm chứng bằng data thật (query trực tiếp DB `cmcdtqg_db`)**: cả 100 dự án mẫu hiện có CÙNG giá trị `tong_von_dau_tu_dang_ky` mới nhất = 500.000.000 — nghĩa là với seed hiện tại, `percentileRank` (yếu tố quy mô vốn) luôn ra đúng `1.0000` cho mọi dự án (không có biến thiên thật để test yếu tố này) — 2 yếu tố còn lại (tỷ lệ chưa giải ngân, số kỳ hoạt động) vẫn biến động bình thường theo dự án. Không phải lỗi công thức, chỉ là hạn chế của data mẫu.
  - `mucDo` mỗi danh mục (Nghiêm trọng/Cao/Trung bình/Thấp) tái dùng chung 1 ngưỡng với "Mức độ rủi ro tổng quát" (`KpiCalculator.phanLoaiRuiRo`, [0-2.5)/[2.5-5)/[5-7.5)/[7.5-10] — sheet 1 dòng 82) — giả định ngưỡng này áp dụng luôn cho từng danh mục con, sheet chưa nêu riêng ngưỡng khác cho dòng 84.

### Phase 4 — So sánh, Dự báo, Gợi ý (6.2.g–k)

- So sánh trung bình ngành: dùng `bc_chi_tieu_trung_binh` (batch), cần job tính toán riêng (ngoài phạm vi phase này, xem Phase 0).
- Dự báo: cần chốt thuật toán (mục 4, #4) — có thể làm placeholder rule-based trước.
- Gợi ý: dùng lại flag `hasCriticalOrHighRisk` từ Phase 3.

### Phase 5 — LLM insight client dùng chung

- Xác nhận `AiServiceClient` có hỗ trợ prompt tự do; nếu không, thêm client mới theo pattern hiện có.
- 1 service `InsightGenerationService` nhận `(context, prompt template)` → LLM → text, fallback rule-based khi lỗi.

### Phase 6 — Xuất báo cáo (6.3)

- Phụ thuộc quyết định server-render vs FE-capture (mục 4, #6) — POC riêng trước khi cam kết nếu chọn server-render.

### Ghi chú ưu tiên

- Phase 0–2 là nền tảng bắt buộc, không thể song song.
- Phase 3 có thể chia nhỏ, làm song song theo từng nhóm chỉ tiêu — nhưng 2 điểm mở (Vốn khác, 2/4 trạng thái tiến độ) nên chốt với BA trước khi bắt đầu để tránh phải sửa lại UI/logic.
- Phase 4 rủi ro cao nhất về hiệu năng/độ chính xác — làm sau cùng, sau khi mục 4 đã chốt.
- Phase 6 làm cuối vì phụ thuộc toàn bộ data của các tab khác đã ổn định.

## 6. Ngoài phạm vi (đã xác nhận với người dùng)

Mảng **"Cảnh báo"** phát hiện thêm ở `Mô tả logic công thức.xlsx` sheet 2 — gồm:

- Cấu hình ngưỡng cảnh báo bằng phương pháp thống kê (Percentile / Z-score / IQR trên tập mẫu "so với kỳ trước" S1 và "so với trung bình ngành" S2).
- Dashboard thống kê cảnh báo phát sinh (bộ lọc, thẻ tổng hợp, biểu đồ xu hướng, top 5 dự án rủi ro).
- Xem chi tiết 1 cảnh báo (header, ngưỡng vs giá trị thực tế, biểu đồ xu hướng, AI insight).

Đây là 1 subsystem lớn, độc lập với "Phân tích chuyên sâu" — theo quyết định của người dùng, **không đưa vào plan này**. Ghi nhận lại để lập kế hoạch riêng khi cần.
