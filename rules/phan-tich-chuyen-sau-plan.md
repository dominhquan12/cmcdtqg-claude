# Phân tích chuyên sâu dự án — Phân tích nghiệp vụ & Kế hoạch triển khai

> Nguồn:
> - `.claude/tasks/phantichchuyensau/phantichchuyensau.docx` (mục 6.1–6.3 của tài liệu đặc tả nghiệp vụ/giao diện — **cập nhật 2026-08-18**: bổ sung đoạn "Vùng AI insights" mô tả Like/Dislike, xem mục 2.2.l và Phase 4bis)
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

#### l. Like/Dislike cho vùng "AI insights" (bổ sung docx 2026-08-18)

`phantichchuyensau.docx` được cập nhật thêm 1 đoạn "Vùng AI insights" lặp lại giống nhau ở **đúng 8
vị trí** trong tài liệu — đối chiếu từng vị trí với header section thì khớp 1-1 với 8/10 vùng
"Nội dung nhận định (AI insights)" đã liệt kê ở bảng mục 2.2.b–k phía trên: **Tài chính, Vốn &
Giải ngân, Tiến độ, Rủi ro (chỉ gắn vào ĐÚNG 1 khối — nhận định tổng hợp cuối bảng chi tiết yếu tố
rủi ro, KHÔNG gắn vào "Dòng khuyến nghị" của gauge cũng KHÔNG gắn vào "Diễn giải nguyên nhân (AI)"
của từng danh mục con), So sánh đa chỉ tiêu theo kỳ, So sánh trung bình ngành, Dự báo, Gợi ý**.
**Tổng quan và Tuân thủ KHÔNG có đoạn này** (đã kiểm tra trực tiếp trong docx, không suy đoán) —
khớp đúng hiện trạng đã biết ("Tuân thủ không có insight AI ở tab này"; Tổng quan hiện chỉ có 4 đoạn
text mô tả, không có UI vùng AI insights riêng).

Quy tắc nghiệp vụ (nguyên văn docx, giống nhau ở cả 8 vị trí):
- Mỗi người dùng chỉ được chọn **1 trong 2 trạng thái (Like hoặc Dislike) tại 1 thời điểm** cho
  cùng 1 nhận định — không cho phép chọn đồng thời cả hai.
- Mỗi lượt đánh giá lại của cùng 1 người dùng trên cùng 1 nhận định **ghi đè lên bản ghi cũ** (cập
  nhật `updated_at`), **không tạo thêm bản ghi mới** — đảm bảo 1 người dùng luôn có tối đa 1 đánh
  giá hiệu lực trên 1 nhận định.
- Đánh giá của 1 người dùng **không hiển thị công khai** cho người dùng khác xem (chỉ hiển thị đúng
  trạng thái đánh giá của chính người đang xem).
- Hành vi nút bấm: bấm Like/Dislike lần đầu → bật; bấm lại đúng nút đang bật → tắt (về trạng thái
  chưa đánh giá); đang bật Like mà bấm Dislike (hoặc ngược lại) → chuyển đổi (tắt cái cũ, bật cái
  mới, gọi API cập nhật).

→ Thiết kế DB + API cho phần này xem **Phase 4bis** (sau Phase 4, trước Phase 5).

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
- **(sửa lỗi, 2026-08-13, đối chiếu sheet 1 dòng 12–13 cập nhật cùng ngày) KPI "Tuân thủ"/"Rủi ro" ở
  header trước đó KHÔNG tái dùng tab Tuân thủ/Rủi ro như spec yêu cầu** ("Tính từ tab Tuân thủ"/
  "Tính từ tab rủi ro") — code cũ tự tính riêng, lệch hẳn 2 tab đó:
  - `tyLeTuanThu`/`tongSoNghiaVuTuanThu`: đếm nghĩa vụ CHỈ ở đúng 1 `ky_key` hiện tại
    (`BcTuanThuChiTietRepository.countByProjectIdAndKyKey`), KHÔNG lũy kế và KHÔNG áp bất kỳ rule nào
    đã build ở tab Tuân thủ (loại nhóm "Tài chính", nhóm "Tiến độ" chỉ tính kỳ NĂM, 2 nhóm "mặc định
    tuân thủ" tính theo số báo cáo đã nộp...) — ra số khác hẳn KPI "Tuân thủ (%)" nếu so với tab.
  - `diemRuiRo`: đọc thẳng `bc_rui_ro_chi_tiet.gia_tri_diem` — cột này CHƯA TỪNG có job nào ghi giá
    trị thật (thiết kế cũ từ Phase 0, đã bỏ từ khi Phase 3 chuyển sang tính công thức trực tiếp ở
    `RuiRoCalculator`/`TabRuiRoServiceImpl`, 2026-08-12) — với data mẫu hiện tại giá trị này luôn hoặc
    sai hoặc rỗng.
  - **Đã sửa**: `ChiTietDuAnServiceImpl.tinhKpi` giờ gọi thẳng `TabTuanThuService#getTabTuanThu` +
    `TabRuiRoService#getTabRuiRo`, lấy `tyLeTuanThuTongThe`/`tongSoNghiaVu`/`diemTongQuat`/
    `mucDoTongQuat` trực tiếp từ 2 response đó — không tự tính lại. Hệ quả: `tyLeTuanThu`/
    `tongSoNghiaVuTuanThu` giờ là **LŨY KẾ** tính tới kỳ báo cáo gần nhất (khớp đúng bản chất "nghĩa
    vụ là cam kết trong giấy chứng nhận đầu tư, không reset theo kỳ"), không còn là số phát sinh riêng
    trong 1 kỳ như trước — đây là thay đổi hành vi CÓ CHỦ ĐÍCH theo đúng spec mới, không phải side
    effect ngoài ý muốn.
  - **Gap phát hiện thêm, chưa xử lý**: cột F dòng 13 mô tả ngưỡng phân loại mức độ rủi ro theo thang
    **0–100** (`[0-25) Thấp, [25-50) Trung bình, [50-75) Cao, [75-100] "Rất cao"`) — khác hẳn thang
    **0–10** mà `KpiCalculator.phanLoaiRuiRo`/`TabRuiRoResponse.mucDoTongQuat` đang dùng (ngưỡng
    2.5/5/7.5/10, nhãn "Nghiêm trọng" không phải "Rất cao"). Đã QUYẾT ĐỊNH bỏ qua công thức ngưỡng ở
    cột F này, ưu tiên tái dùng NGUYÊN VẸN `mucDoTongQuat` đã có (đúng nghĩa đen "Tính từ tab rủi ro"
    ở cột G-K — lấy giá trị từ tab, không tính lại theo 1 công thức khác) — nhưng chưa xác nhận với BA
    liệu cột F có phải copy nhầm từ ngưỡng "Mức độ rủi ro hệ thống" của tab Tuân thủ hay không
    (`TuanThuCalculator.mucDoRuiRoHeThong` dùng ĐÚNG 4 mốc 0/25/50/75/100 y hệt).
- Đối chiếu với `.claude/tasks/phantichchuyensau/images/chi-tiet-tong-quan.png` (2026-08-05): header ban đầu thiếu `diaBan`, thiếu `ngayNhanBcGanNhat` (ảnh cần 2 mốc ngày khác nhau: "Ngày nhận" vs "Thời điểm chốt số liệu" — cả 2 field đã có sẵn trên `bc_dinh_ky`), KPI Tuân thủ thiếu tổng số nghĩa vụ (`tongSoNghiaVuTuanThu`) — cả 3 đã bổ sung. "Nguồn trích dẫn" cũng đã làm giàu thêm (mã báo cáo + tên TCKT + kỳ) — phần tên loại báo cáo chính thức đã CHỐT, xem mục ngay dưới.
- **(chốt 2026-08-13, đối chiếu `Mô tả logic công thức.xlsx` sheet "Phân tích chuyên sâu" dòng 18 cập nhật cùng ngày) Tên loại báo cáo cho "Nguồn trích dẫn" — thêm cột raw `bc_dinh_ky.ten_bao_cao`**: sheet giờ ghi rõ field này là **raw**, do ETL nguồn (ngoài phạm vi module — open question #2) tự join `LoaiBaoCaoId` sang bảng `LoaiBaoCaos.TenLoaiBaoCao` của hệ thống ngoài rồi mới ghi kết quả vào `bc_dinh_ky` — module `ptcb` **chỉ đọc thẳng cột này**, không tự join/suy luận gì thêm. Đã thêm field `BcDinhKy.tenBaoCao` (nullable, chưa có ETL nào ghi giá trị nên `null` với data mẫu hiện tại) + sửa `ChiTietDuAnServiceImpl.xayDungNguonTrichDan` ưu tiên đọc field này, chỉ fallback về `KpiCalculator.tenMauBaoCao` (suy luận từ `loaiDuAn`×loại kỳ) khi còn trống — cùng pattern "ưu tiên nguồn thật, fallback rule-based" đã dùng cho `ai_insight` xuyên suốt plan. **Lưu ý**: việc này KHÔNG đóng open question #12 (mục 4) — #12 hỏi về độ chính xác của phép suy luận "mẫu nào" (103/37/116/114/89), vẫn cần cho các mục đích khác (VD công thức điểm rủi ro Tài chính); "Nguồn trích dẫn" giờ chỉ ưu tiên đọc tên thật khi có, còn suy luận vẫn là fallback khi ETL chưa build.
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
  - ~~Nhóm "Tiến độ" (`Nghia vu tien do`): chỉ xác định tuân thủ theo báo cáo NĂM — bản ghi ở kỳ QUÝ của nhóm này bị loại khỏi mọi tính toán (tra `dm_ky_bao_cao.loai_ky` theo từng `ky_key`, không dựa trực tiếp `nghia_vu_id` vì đó chỉ là snapshot lịch sử tại thời điểm ghi nhận).~~ — **ĐỔI LẠI (2026-08-18, theo yêu cầu nghiệp vụ mới của người dùng)**: nhóm "Tiến độ" giờ tính CẢ kỳ NĂM và kỳ QUÝ — bỏ hẳn nhánh lọc theo `loai_ky` trong `locNghiaVuHopLe` (constant đổi tên từ `NHOM_TIEN_DO_CHI_TINH_NAM` → `NHOM_TIEN_DO`). Chỉ áp dụng cho nhóm "Tiến độ" trong tab Tuân thủ này — KHÔNG đổi cơ chế `KyBaoCaoResolver.layNBaoCaoGanNhatCungLoaiKy` (vẫn "cùng loại kỳ với báo cáo gần nhất") dùng chung cho tab Tiến độ và các tab khác (Tổng quan, Tài chính, Vốn & Giải ngân, So sánh, Dự báo) — đã xác nhận rõ phạm vi với người dùng qua AskUserQuestion trước khi sửa.
  - Nhóm "Nộp báo cáo định kỳ" (`Bao cao dinh ky`): lấy toàn bộ báo cáo đã nộp của dự án, không phân biệt quý/năm (hành vi mặc định, không cần lọc thêm). Từ 2026-08-18, nhóm "Tiến độ" ở trên cũng xử lý giống vậy — trước đó khác nhau (nhóm "Tiến độ" chỉ tính NĂM).
- **(cập nhật 2026-08-12) Sheet công thức đổi số dòng + bổ sung công thức "Thực tế ghi nhận" cho 4/5 nhóm — đã code**:
  - File `Mô tả logic công thức.xlsx` xoá cột "Tên nghĩa vụ" (dòng 46 cũ) và đổi tên bảng thành **"Bảng chi tiết tuân thủ cam kết"**; sheet 1 giờ chỉ còn dòng 47 (Tên nhóm nghĩa vụ), 48 (Trạng thái), 49 (Thực tế ghi nhận). Dòng 49 nêu rõ công thức cho từng nhóm: "Quy định pháp luật..."/"Thủ tục đăng ký..." → mặc định `"Đạt yêu cầu theo quy định"`; "Tiến độ" → `bc_dinh_ky.tien_do_trang_thai + bc_dinh_ky.ky_key`; "Nộp báo cáo định kỳ" → tên báo cáo + thời gian nộp (công thức đánh giá Trạng thái của nhóm này tham chiếu tiếp sang sheet "Nhóm chỉ tiêu - chỉ tiêu" dòng 30: so `NgayNop` với hạn nộp bc — quý: trước 10 tháng đầu quý sau; năm: trước 31/3 năm sau).
  - Đối chiếu bằng script (parse seed SQL) thì **data mẫu KHÔNG khớp 2 công thức này**: 12/84 bản ghi "Nộp báo cáo định kỳ" và 25/91 bản ghi "Tiến độ" có `trang_thai`/`thuc_te_ghi_nhan` lưu sẵn trong `bc_tuan_thu_chi_tiet` sai lệch so với công thức tính từ field thật (`ngay_nop_bao_cao`/`tien_do_trang_thai` ở `bc_dinh_ky`) — seed gán 2 giá trị boilerplate độc lập, không theo công thức.
  - Đã sửa `TabTuanThuServiceImpl`: thêm bước `tinhLaiTrangThaiVaThucTe` — với nhóm "Tiến độ"/"Nộp báo cáo định kỳ", TÍNH LẠI cả `trangThai` và `thucTeGhiNhan` từ `bc_dinh_ky` (join theo `project_id`+`ky_key` qua `BcDinhKyRepository.findByProjectIdAndKyKeyIn`, mới thêm), KHÔNG dùng giá trị lưu sẵn nữa. Công thức hạn nộp + 2 hàm suy luận trạng thái tách thành pure function ở `TuanThuCalculator` (`hanNopBaoCao`, `trangThaiNopBaoCaoDinhKy`, `trangThaiTienDo`) — có unit test ở `TuanThuCalculatorTest`. "Thực tế ghi nhận" nhóm "Nộp báo cáo định kỳ" ghép tên báo cáo (từ 2026-08-13: ưu tiên đọc raw `bc_dinh_ky.ten_bao_cao`, fallback `KpiCalculator.tenMauBaoCao` — cùng cách xử lý với "nguồn trích dẫn" ở tab Tổng quan, xem mục Phase 2) + `maBaoCao` + `ngayNopBaoCao`.
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

### Phase 4 — So sánh, Dự báo, Gợi ý (6.2.g–k) — **đã code xong cả 4 tab con** (2026-08-12/13)

- So sánh trung bình ngành: dùng `bc_chi_tieu_trung_binh` (batch), cần job tính toán riêng (ngoài phạm vi phase này, xem Phase 0). **Đã code** — chi tiết ở mục "Tab con 'So sánh'" dưới đây.
- Dự báo: cần chốt thuật toán (mục 4, #4) — **đã code** với placeholder rule-based (naive/persistence forecast) khi `bc_du_bao` chưa có dữ liệu, đúng gợi ý ban đầu. Chi tiết ở mục "Tab 'Dự báo'" dưới đây.
- Gợi ý: dùng lại flag `hasCriticalOrHighRisk` từ Phase 3. **Đã code** — chi tiết ở mục "Tab 'Gợi ý'" dưới đây.

#### Tab con "So sánh" (2 sub-tab: đa chỉ tiêu theo kỳ + trung bình ngành) — **đã code xong** (2026-08-12)

- 2 endpoint mới trên `ChiTietDuAnController`: `GET .../chi-tiet/so-sanh/da-chi-tieu-theo-ky` (docx
  mục 2.2.g, sheet 1 dòng 71–79) và `GET .../chi-tiet/so-sanh/trung-binh-nganh` (docx mục 2.2.h,
  sheet 1 dòng 107–114), mỗi endpoint 1 service riêng (`SoSanhDaChiTieuService`/`SoSanhNganhService`).
- Enum mới `NhomChiTieuSoSanh` (Tài chính/Vốn & Giải ngân/Tuân thủ/Rủi ro — **không có Tiến độ**,
  khác `DanhMucRuiRo` của tab Rủi ro) + calculator mới `SoSanhCalculator` (quy đổi tiến độ sang
  thang "hiệu suất" 0–10, chuẩn hoá 1 trục radar theo quy tắc "mẫu số = lớn hơn giữa dự án/ngành",
  trung bình cộng bỏ qua `null`, đổi thang 0–10 ↔ 0–100) — pure function, unit test ở
  `SoSanhCalculatorTest`.

**So sánh đa chỉ tiêu theo kỳ**:
- Query param: `nhomChiTieu` (mặc định TAI_CHINH), `chiTieu` (mã enum con, bỏ qua nếu nhóm là
  TUAN_THU/RUI_RO), `soKy` (mặc định 4), `kyKeys` (danh sách kỳ cụ thể — "Tuỳ chọn khác", ưu tiên hơn
  `soKy` khi có). Chỉ 2 nhóm Tài chính/Vốn & Giải ngân có "ô chọn chỉ tiêu" — 2 nhóm còn lại (Tuân
  thủ/Rủi ro) không có lựa chọn, chart cột dùng cố định tỷ lệ vi phạm(%)/điểm rủi ro tổng quát quy
  đổi %; khi 1 nhóm KHÔNG active, cột của nó vẫn hiển thị nhưng dùng chỉ tiêu MẶC ĐỊNH (Tài chính →
  Doanh thu, Vốn & Giải ngân → Vốn góp) vì spec chỉ có 1 "ô chọn chỉ tiêu" chung, không có ô riêng
  cho từng nhóm không active (docx mục 2.2.g).
- Bảng dữ liệu so sánh chi tiết (`bangChiTiet`) có cấu trúc CỐ ĐỊNH — luôn đúng 6 dòng/3 nhóm (Doanh
  thu, Lợi nhuận | Tỷ lệ giải ngân, Trạng thái tiến độ | Số lỗi vi phạm, Mức độ rủi ro) — KHÔNG phụ
  thuộc `nhomChiTieu` đang chọn, khác biểu đồ.
- **Điểm rủi ro tổng quát tại 1 kỳ LỊCH SỬ bất kỳ** (không chỉ báo cáo gần nhất) — `TabRuiRoServiceImpl`
  (Phase 3) chỉ tính cho kỳ hiện tại nên phải orchestrate lại riêng trong
  `SoSanhDaChiTieuServiceImpl` (tái dùng nguyên các hàm thuần của `RuiRoCalculator`, không sửa
  `TabRuiRoServiceImpl` để tránh rủi ro ảnh hưởng ngược tab Rủi ro đang chạy). Đơn giản hoá có chủ
  đích: phần "quy mô vốn chuẩn hoá" (percentileRank) luôn so với snapshot MỚI NHẤT của toàn danh mục
  (không tính lại "toàn danh mục tại đúng thời điểm X trong quá khứ" — cần query lịch sử phức tạp
  hơn, ngoài phạm vi Phase 4). Cần repository method mới `BcDinhKyRepository.findKyNgayTruoc` (kỳ
  ngay trước 1 mốc X, cùng loại kỳ, so `ngay_ket_thuc` — đúng nguyên tắc đã áp dụng xuyên suốt plan,
  xem mục 3.2ter) và `TabTuanThuService.tinhThongKeTaiKy` mới (thu gọn từ helper nội bộ đã có sẵn
  của `TabTuanThuServiceImpl`, KHÔNG đổi hành vi `getTabTuanThu` hiện tại) để lấy tỷ lệ vi
  phạm/mức độ rủi ro hệ thống tại 1 kỳ lịch sử bất kỳ.
- AI insight: `ai_insight.tab_nguon = "so_sanh_ky"` (đã có sẵn trong danh sách tab_nguon liệt kê ở
  Javadoc `AiInsight`, chưa từng dùng tới trước Phase 4 này), fallback rule-based so sánh kỳ đầu/kỳ
  cuối trong danh sách đang so sánh.

**So sánh với trung bình ngành**:
- Không có query param — luôn so sánh tại kỳ báo cáo GẦN NHẤT của dự án (đúng docx, không có bộ chọn
  kỳ ở sub-tab này, khác sub-tab "đa chỉ tiêu theo kỳ").
- **Trục radar (thang 10) và bảng chi tiết (%) dùng 2 cách quy đổi KHÁC NHAU cho cùng khái niệm
  "Tài chính"/"Vốn & Giải ngân" — có chủ đích, không phải không nhất quán**: trục radar dùng GIÁ TRỊ
  THÔ (doanh thu kỳ báo cáo, vốn thực hiện lũy kế) chuẩn hoá theo `SoSanhCalculator.trucChuanHoa`
  (đúng nguyên văn sheet 1 dòng 107 "mức 10 ứng với ... của dự án hoặc tb ngành lấy cái lớn hơn");
  bảng chi tiết dùng "Doanh thu" = % TĂNG TRƯỞNG (kỳ này so kỳ trước, tái dùng
  `TaiChinhCalculator.bienDongPhanTram`) và "Giải ngân" = TỶ LỆ giải ngân (%,
  `KpiCalculator.tyLeGiaiNgan`) — khớp đúng ảnh mock (giá trị hiển thị dạng "18.5%"/"80%", vô lý nếu
  là số tiền thô).
- **Nguồn "trung bình ngành"**: đọc `bc_chi_tieu_trung_binh` theo `(kyKey, maNganh, chiTieu)` qua
  repository method mới `findByKyKeyAndMaNganhAndChiTieu`. Data mẫu hiện tại MỚI CHỈ có 2 mã chỉ tiêu
  thật (`doanh_thu_thuan_ky`, `von_dau_tu_thuc_hien_luy_ke_gcndt`) — 4 mã còn lại mà code kỳ vọng
  (`ty_le_giai_ngan`, `ty_le_tuan_thu`, `diem_rui_ro_tong_quat`, `diem_tien_do_thang_10`) **chưa tồn
  tại trong data mẫu**, trả `null` cho tới khi 1 job batch riêng (ngoài phạm vi Phase 4, xem mục 4
  #3) tính và ghi các mã này — đây là hành vi ĐÚNG dự kiến theo đúng quyết định đã chốt ở đầu Phase 4
  ("cần job tính toán riêng"), không phải lỗi/thiếu sót của Phase 4. Field `radar[].diemNganh`/
  `bangChiTiet[].giaTriNganh` vì vậy phần lớn sẽ `null` khi test với data mẫu hiện tại.
- "Tiến độ dự án" ở bảng chi tiết — trung bình ngành LUÔN `null` (không có quy ước hợp lý để quy đổi
  1 nhãn định tính từ điểm số trung bình; khác 4 chỉ tiêu còn lại vốn có sẵn dạng %/điểm).
- **Điểm tổng hợp = trung bình cộng NGUYÊN VĂN 5 điểm trục radar của dự án (sheet 1 dòng 109)** — kể
  cả khi điều này trộn lẫn cực tính (4/5 trục "cao = tốt", trục Rủi ro "cao = xấu"). Đã cân nhắc
  "sửa" cho hợp lý hơn (VD đảo dấu trục Rủi ro) nhưng quyết định giữ NGUYÊN VĂN công thức sheet, chỉ
  ghi chú lại sự bất thường này trong Javadoc — theo đúng nguyên tắc xuyên suốt plan là không tự
  suy diễn/sửa công thức khi chưa chốt lại với BA.
- AI insight: `ai_insight.tab_nguon = "so_sanh_nganh"`, fallback rule-based chỉ nêu điểm tổng hợp
  (chưa đủ ngữ cảnh để sinh văn phong "vị thế cạnh tranh" như mock — sheet 1 dòng 113 cần LLM thật).

**Open questions mới phát sinh** (bổ sung mục 4):
- Chưa xác nhận với BA: tỷ lệ vi phạm(%) có đúng là chỉ số hiển thị cho cột "Tuân thủ" ở biểu đồ so
  sánh đa chỉ tiêu theo kỳ hay không (docx chỉ nói "quy đổi giá trị của nhóm chỉ tiêu Tuân thủ... về
  thang 0–100%", không nêu rõ là tỷ lệ vi phạm hay tỷ lệ tuân thủ) — chọn tỷ lệ vi phạm vì bảng chi
  tiết cùng nhóm hiển thị "Số lỗi vi phạm" (hướng vi phạm), nhưng đây là 1 diễn giải hợp lý, chưa
  phải xác nhận trực tiếp.
- Quy đổi "hiệu suất" tiến độ sang thang 10 (`SoSanhCalculator.diemTienDoThang10`: đúng=10,
  chậm=6.67, khó khăn=3.33, không thể=0) là suy luận nghịch đảo tuyến tính từ thang RỦI RO
  (2.5/5/7.5/10) — sheet chỉ nói "tiến độ quy 4 mức về thang 10", không nêu công thức quy đổi
  "hiệu suất" cụ thể. Cần chốt lại với BA.
- 4 mã chỉ tiêu trung bình ngành mới (`ty_le_giai_ngan`, `ty_le_tuan_thu`, `diem_rui_ro_tong_quat`,
  `diem_tien_do_thang_10`) là ĐẶT TÊN của Phase 4 này — chưa được BA/job batch xác nhận, có thể job
  thật dùng tên mã khác. Cần đối chiếu lại khi job batch tính "trung bình ngành" (mục 4 #3) được
  triển khai.

#### Tab "Dự báo" — **đã code xong** (2026-08-13)

- `GET .../chi-tiet/du-bao` (docx mục 2.2.i, sheet 1 dòng 98–106). Biểu đồ (nhóm nút "Hiển thị xu
  hướng" + 4 cột + line overlay) TÁI DÙNG nguyên cơ chế của tab "So sánh đa chỉ tiêu theo kỳ" — khác
  biệt duy nhất: "ô chọn chỉ tiêu" LUÔN disable (docx), nên endpoint này KHÔNG có tham số `chiTieu`;
  mỗi cột luôn dùng đúng 1 chỉ tiêu mặc định cố định (Tài chính→Doanh thu, Vốn & Giải ngân→Vốn góp ở
  phần lịch sử). `nhomChiTieu` vẫn nhận (mặc định TAI_CHINH) nhưng chỉ ảnh hưởng cột nào được
  highlight ở FE, KHÔNG đổi giá trị cột nào.
- **Tách `DiemRuiRoTaiKyResolver` (interface + impl mới) khỏi `SoSanhDaChiTieuServiceImpl`** — trước
  đó (Phase 4, sub-tab So sánh) orchestration "điểm rủi ro tổng quát tại 1 kỳ lịch sử bất kỳ" là
  private method riêng của `SoSanhDaChiTieuServiceImpl`; tab Dự báo cũng cần chính xác logic này (vẽ
  biểu đồ lịch sử ≥8 kỳ) nên refactor thành service dùng chung (2 lần cần là ngưỡng chấp nhận được để
  tách, tránh copy-paste lần thứ 3) — đã refactor `SoSanhDaChiTieuServiceImpl` gọi qua interface mới,
  hành vi giữ nguyên (test cũ vẫn pass).
- **Nguồn dự báo thật rất hạn chế — chỉ 3/5 nhóm có dữ liệu trong `bc_du_bao`**: đối chiếu seed data
  thật, `bc_du_bao.nhom_chi_tieu` (thực chất là MÃ CHỈ TIÊU đơn lẻ, xem Javadoc entity) chỉ có 3 giá
  trị (`doanh_thu_thuan`, `loi_nhuan_sau_thue`, `von_thuc_hien`), của 90/100 dự án mẫu, luôn cho ĐÚNG
  1 kỳ tương lai (`2026-Q3`). KHÔNG có bản ghi nào cho Tuân thủ/Rủi ro/trạng thái Tiến độ. Xử lý: ưu
  tiên đọc `bc_du_bao` khi có (bản ghi này do 1 job time-series thật ngoài phạm vi module ghi — xem
  plan mục 2.2 điểm 2), **fallback "dự báo ngây thơ" (naive/persistence forecast — giữ nguyên giá
  trị/trạng thái kỳ hiện tại, % tăng trưởng = 0)** khi thiếu — đúng gợi ý ở đầu Phase 4 ("có thể làm
  placeholder rule-based trước" khi chưa chốt thuật toán, mục 4 #4). Mỗi card dự báo (`TheDuBaoItem`)
  có cờ `tuMoHinhThat` để FE/BA biết dòng nào là số thật từ model, dòng nào là placeholder.
- **"Vốn & Giải ngân" ở điểm dự báo (nét đứt) dùng "vốn thực hiện", KHÁC "Vốn góp" ở phần lịch sử
  của cùng biểu đồ** — vì `bc_du_bao` chỉ có mô hình cho "vốn thực hiện" (driver của tỷ lệ giải
  ngân), không có "vốn góp". Cả 2 đều là số tiền tỷ VNĐ (cùng đơn vị trục Y trái) nên chấp nhận dùng
  trực tiếp, chỉ ghi rõ khác biệt ý nghĩa trong Javadoc `TabDuBaoResponse.DiemDuBaoItem` — không tự
  suy diễn 1 công thức "vốn góp dự báo" nào khác khi spec không có.
- **5 card dự báo bám sát ĐÚNG mô tả DÒNG CHÍNH/DÒNG PHỤ chi tiết ở docx mục 2.2.i (ưu tiên hơn mô tả
  tổng quát 1 dòng ở sheet 1)** — VD sheet 1 dòng 102 tóm tắt card Vốn & Giải ngân là "Kỳ vọng giải
  ngân (%) & Target", nhưng docx chi tiết lại nói rõ dòng chính là "Số tiền giải ngân dự báo" (tỷ
  VNĐ, không phải %) + dòng phụ % tăng/giảm — đã bỏ luôn khái niệm "Target" (không có nguồn dữ liệu
  nào, không phải phần cấu hình ngưỡng nào tồn tại trong schema hiện có — cùng loại gap với "Vốn
  khác" mục 3.4.1).
- `kyTiepTheoLabel`: cần repository method mới `DmKyBaoCaoRepository.findKyTiepTheo` (kỳ NGAY SAU kỳ
  hiện tại, cùng loại kỳ, so `ngay_bat_dau`/`ngay_ket_thuc` — không dùng `thu_tu`, đúng nguyên tắc đã
  áp dụng xuyên suốt plan mục 3.2ter). `null` nếu kỳ đó chưa được tạo trong `dm_ky_bao_cao` (không
  chặn hiển thị 5 card — vẫn tính bằng naive fallback dựa trên kỳ hiện tại).
- AI insight: `ai_insight.tab_nguon = "du_bao"` (đã có sẵn trong danh sách liệt kê ở Javadoc
  `AiInsight`), fallback rule-based ghép dòng chính của cả 5 card.
- **3 điểm sửa sau khi đối chiếu ảnh mock `images/du-bao/du-bao-1.png`/`du-bao-2.png` (2026-08-13)**:
  1. Bổ sung field `chiTieuTen` (mới) trên response — mock cho thấy "ô chọn chỉ tiêu" (luôn disable)
     vẫn hiển thị giá trị (VD "Doanh thu", "Vốn góp") tuỳ nhóm đang bật, để trống khi Tuân thủ/Rủi ro
     — trước đó API không trả field nào cho FE biết hiển thị gì ở đó (FE sẽ phải tự hardcode mapping
     nhóm→tên, nay không cần nữa).
  2. Bổ sung `tienDoTrangThai` trên `DiemDuBaoItem` (điểm dự báo/nét đứt) — mock cho thấy Icon trạng
     thái tiến độ xuất hiện dưới MỌI mốc kỳ trên trục X, kể cả mốc dự báo cuối cùng, không chỉ các mốc
     lịch sử (trước đó field này bị bỏ trống ở điểm dự báo, chỉ có ở `DiemLichSuItem`).
  3. **Sửa lỗi thật**: fallback naive của `diemDuBao.vonGiaiNgan` (khi `bc_du_bao` chưa có dữ liệu)
     trước đó lấy nhầm `ky1.getVonGopKy()` (Vốn góp — chỉ tiêu dùng ở phần LỊCH SỬ) thay vì
     `ky1.getVonDauTuThucHienLuyKeGcndt()` (vốn thực hiện — đúng chỉ tiêu mà điểm dự báo đại diện,
     khớp với nhánh có model thật). Bug này khiến giá trị điểm dự báo nhảy đột ngột sang 1 chỉ tiêu
     khác hẳn khi không có `bc_du_bao` — đã sửa để fallback ĐÚNG chỉ tiêu, chỉ khác ở CÓ hay KHÔNG
     dữ liệu model, không đổi luôn cả ý nghĩa số liệu.
  4. Đổi wording dòng phụ 2 card Tài chính/Vốn & Giải ngân từ "so với kỳ hiện tại" → "so với kỳ
     trước" — khớp nguyên văn docx mục 2.2.i ("Mức độ tang giảm X% so với kỳ trước"), dù công thức
     thực chất so với "Kỳ hiện tại" (2 cách gọi cùng 1 khái niệm, xét từ góc nhìn kỳ ĐƯỢC dự báo).

#### Tab "Gợi ý" — **đã code xong** (2026-08-13, sửa lại sau khi đối chiếu ảnh mock cùng ngày)

- `GET .../chi-tiet/goi-y` (docx mục 2.2.k). Toàn bộ dữ liệu suy ra TRỰC TIẾP từ
  `TabRuiRoService#getTabRuiRo` (Phase 3) — KHÔNG có nguồn dữ liệu độc lập nào khác: mỗi danh mục
  rủi ro (Tài chính/Tiến độ/Vốn & Giải ngân/Tuân thủ) ở mức Cao/Nghiêm trọng → 1 card gợi ý. Zip theo
  INDEX giữa `TabRuiRoResponse.danhMucRuiRo` và `DanhMucRuiRo.values()` (đúng thứ tự
  `TabRuiRoServiceImpl` đã dùng để build danh sách đó) để lấy field mới `DanhMucRuiRo.maRoute` (slug
  route khớp path controller, VD `"von-giai-ngan"` — cố ý tách khỏi `DanhMucRuiRo.ma` vì mã DB có
  `"va"` còn path controller không có).
- **Sửa lỗi hiểu nhầm sau khi đối chiếu ảnh mock `images/goi-y/goi-y-1.png` (2026-08-13)**: "5 nhóm
  nguồn phát hiện" ở docx (Tài chính/Vốn & Giải ngân/Tuân thủ/Tiến độ/Rủi ro) BAN ĐẦU hiểu nhầm là chỉ
  cách gọi tên chung "5 nhóm chỉ tiêu", không phải 1 nguồn thật — SAI, mock cho thấy rõ CÓ 1 card thứ
  5 độc lập, label "Rủi ro". Đã sửa: thêm `TabGoiYServiceImpl#xayDungGoiYTongQuat` — card thứ 5 này
  lấy từ ĐIỂM RỦI RO TỔNG QUÁT (`mucDoTongQuat`/`nhanDinh` ở đầu tab Rủi ro, gauge 0-10), KHÁC 4 card
  kia (lấy từ điểm rủi ro từng DANH MỤC con). `maRoute="rui-ro"` (khớp path `GET .../chi-tiet/rui-ro`
  của tab Rủi ro tổng thể, không phải path 1 trong 4 danh mục con). Do đó `soLuongCanhBaoCao` (=
  `danhSachGoiY.size()`, tính SAU khi đã thêm card này) giờ có thể lên tới 5, khớp đúng ảnh mock
  (AI insight text ghi "05 nội dung", dù badge số riêng trong ảnh lại ghi "03" — chỉ đếm card mức
  "Cao", KHÔNG tính "Nghiêm trọng" — mâu thuẫn với công thức chính docx dòng 92 "Cao HOẶC Nghiêm
  trọng"; giữ theo công thức docx, không theo con số lệch của mock, cùng nguyên tắc "ảnh mock chỉ
  đáng tin về cấu trúc UI" đã áp dụng xuyên suốt plan. FE có thể tự đếm riêng số lượng "Cao" từ
  `danhSachGoiY[].mucDo` nếu cần khớp đúng badge đó, không cần thêm field mới).
- "Nội dung nhận định" (thẻ tổng hợp đầu tab) — spec ghi rõ "Rule-based" (không phải AI, khác hầu hết
  vùng nhận định khác trong toàn bộ plan) — implement CỐ ĐỊNH theo đúng công thức docx, không tra
  `ai_insight`.
- "Tiêu đề gợi ý" — CHƯA có client LLM (Phase 5 còn mở), dùng rule-based cố định thay thế, KHÔNG tra
  `ai_insight` (không có insight riêng cho tiêu đề ngắn, tách biệt khỏi "mô tả chi tiết" — 1 danh mục
  chỉ có 1 `insight_id` duy nhất). "Mô tả chi tiết" tái dùng `dienGiaiNguyenNhan` đã có sẵn ở tab Rủi
  ro (qua `bc_rui_ro_chi_tiet.insight_id`) — đây CHÍNH LÀ AI insight thật khi job async đã sinh,
  không phải rule-based riêng cho tab này.
- `hasCriticalOrHighRisk`/`soLuongCanhBaoCao` đồng bộ trực tiếp với tab Rủi ro — FE có thể dùng field
  này ngay trong response của tab Gợi ý để tự quyết định enable/disable tab, không buộc phải gọi
  riêng tab Rủi ro trước.

### Phase 4bis — Like/Dislike cho nhận định AI (bổ sung docx 2026-08-18) — **đã code DB/API + wiring 7/8 tab**

Xem nghiệp vụ ở mục 2.2.l. Phần này **độc lập với Phase 5** (LLM client thật) — hoạt động được ngay
với `ai_insight` đã có từ Phase 0, không phụ thuộc việc insight là rule-based fallback hay LLM thật
(về mặt kỹ thuật record `ai_insight` là 1 dòng cụ thể dù nội dung do rule-based hay LLM sinh ra).

**Thiết kế DB — bảng mới `ai_insight_phan_ung`** (entity `AiInsightPhanUng extends BaseAudit`, theo
đúng convention `ptcb`, KHÔNG sửa `ai_insight` gốc):

| Cột | Nguồn | Ghi chú |
| --- | --- | --- |
| `id` | PK identity | |
| `ai_insight_id` | FK → `ai_insight.id` | |
| `loai_phan_ung` | enum `LIKE`/`DISLIKE` (`LoaiPhanUngAiInsight`) | |
| `id_nguoi_tao` | `BaseAudit`, immutable | **đóng vai trò "người đã phản ứng"** — không thêm cột riêng vì 1 user chỉ tạo/sửa đúng phản ứng của chính họ (không có khái niệm phản ứng thay người khác) |
| `ngay_tao`/`id_nguoi_sua`/`nguoi_sua`/`ngay_sua` | `BaseAudit` | `ngay_sua` chính là `updated_at` mà docx yêu cầu ghi đè khi đánh giá lại |
| `da_xoa` | `BaseAudit` | **tái dùng làm cờ "đã tắt (toggle off)"** — không phải xoá theo nghĩa thường; bấm lại sau khi tắt sẽ "undelete" (update lại dòng cũ), không tạo dòng mới, đúng yêu cầu docx |

`UNIQUE(ai_insight_id, id_nguoi_tao)` (bất kể `da_xoa`) — đảm bảo tại mọi thời điểm 1 user có đúng
0 hoặc 1 dòng cho 1 insight, cho phép toggle bằng update-in-place thay vì native upsert (đúng pattern
find-existing → mutate → `repository.save()` đã dùng xuyên suốt module `ptcb`, xem `CbPhanHoi`/
`CbNhomChiTieu`ServiceImpl — không dùng raw SQL upsert).

**Đã code**: enum `com.ai.ptcb.domain.enumeration.LoaiPhanUngAiInsight` (LIKE/DISLIKE); entity
`AiInsightPhanUng`; `AiInsightPhanUngRepository` (`findByAiInsightIdAndIdNguoiTao` — bao gồm cả
`da_xoa=true` để phục vụ undelete; `findByAiInsightIdAndIdNguoiTaoAndDaXoaFalse` — chỉ phản ứng
hiệu lực); `AiInsightPhanUngService`/`Impl` (logic toggle/chuyển đổi/undelete theo đúng 4 quy tắc ở
mục 2.2.l, có unit test `AiInsightPhanUngServiceImplTest`); `AiInsightPhanUngController`
(`PUT /api/v1/ptcb/ai-insight/{insightId}/phan-ung`, body `{ loaiPhanUng: "LIKE"|"DISLIKE" }`, trả
`AiInsightPhanUngResponse{ aiInsightId, trangThai }` với `trangThai=null` nghĩa là vừa tắt). Chưa
gắn `@Permission` (đúng hiện trạng chung của các controller `ptcb` khác). i18n key mới:
`aiInsight.phanUng.loaiPhanUng.required`/`aiInsight.phanUng.insight.notFound`/
`aiInsight.phanUng.update.success` (đã thêm cả 3 file `messages{,_vi,_en}.properties`).

**Wiring vào 7 tab (2026-08-18, cùng ngày, sau khi người dùng chỉ ra response của các API
`chi-tiet/tai-chinh`...`chi-tiet/du-bao` chưa trả trạng thái Like/Dislike) — đã code xong**:
1. `AiInsightLookup.layNoiDung(reportId, tabNguon): Optional<String>` đổi thành
   **`layInsight(reportId, tabNguon): Optional<AiInsightNoiDung>`** (record mới, gồm `insightId` +
   `noiDung`) — đổi thẳng interface (breaking change nội bộ, không giữ overload cũ vì chỉ có 1 impl
   + không có test nào phụ thuộc chữ ký cũ).
2. DTO dùng chung mới `NhanDinhAiResponse` (`insightId`, `noiDung`, `phanUngCuaToi`) — thay cho field
   `String nhanDinh` cũ ở **7 response** (`TabTaiChinhResponse`, `TabVonGiaiNganResponse`,
   `TabTienDoResponse`, `TabRuiRoResponse`, `SoSanhDaChiTieuResponse`, `SoSanhNganhResponse`,
   `TabDuBaoResponse` — **không phải 8**, xem điểm 4 dưới). 2 static factory: `tuInsight(...)` (có
   `insightId` thật, kèm gọi `AiInsightPhanUngService.layTrangThaiHienTai(insightId)` để điền
   `phanUngCuaToi`) và `ruleBased(...)` (fallback, `insightId`/`phanUngCuaToi` = `null`). Mỗi
   `*ServiceImpl` tương ứng inject thêm `AiInsightPhanUngService`, `sinhNhanDinh(...)` đổi kiểu trả
   về từ `String` sang `NhanDinhAiResponse`. **Đây LÀ breaking change JSON** (`nhanDinh` từ string
   phẳng thành object `{noiDung, insightId, phanUngCuaToi}`) — chấp nhận được vì feature còn đang
   phát triển (docx like/unlike vừa thêm cùng ngày), FE chưa có bản chốt tích hợp cũ nào phải giữ
   tương thích.
3. `TabGoiYServiceImpl#xayDungGoiYTongQuat` (tái dùng `TabRuiRoResponse.getNhanDinh()` làm
   `moTaChiTiet` cho card "Rủi ro" tổng quát) sửa theo cho khớp kiểu mới
   (`ruiRo.getNhanDinh().getNoiDung()`).
4. **Tab Gợi ý (`TabGoiYResponse`) CHỦ ĐỘNG KHÔNG đổi** — "Nội dung nhận định" của tab này (thẻ tổng
   hợp đầu tab, đếm số gợi ý Cao/Nghiêm trọng) đã quyết định từ trước là **Rule-based thuần, không
   tra `ai_insight`** (xem mục "Tab 'Gợi ý'" ở Phase 4) — nghĩa là KHÔNG có `ai_insight.id` nào để
   gắn Like/Dislike, dù docx 2026-08-18 lại gắn UI Like/Dislike ngay tại đúng vị trí này (mục 2.2.l).
   Đây là **mâu thuẫn thiết kế chưa xử lý** — chưa đổi `TabGoiYResponse` field tương ứng, chưa hỏi
   BA. Hướng khả thi (chưa chọn): (a) đổi tab Gợi ý sang có 1 `ai_insight` thật (tab_nguon="goi_y",
   dù nội dung vẫn rule-based) chỉ để có id gắn phản ứng, hoặc (b) disable nút Like/Dislike ở đúng
   card này trên FE, giữ nguyên rule-based không insight.
5. **Case insight chưa tồn tại (đang fallback rule-based, job async Phase 5/mục 2.2 điểm 2 chưa chạy
   tới)**: `NhanDinhAiResponse.ruleBased(...)` trả `insightId=null` — FE nên disable nút Like/Dislike
   khi gặp `insightId == null` (docx không đề cập case này, đây là suy luận hợp lý, chưa chốt BA).
6. Khi job async sinh insight MỚI cho cùng `(report_id, tab_nguon)` (regenerate, VD do `expired_at`)
   → `ai_insight.id` mới → mọi phản ứng cũ (gắn theo `insight_id` cũ) không còn hiển thị cho bản ghi
   mới. Đây là hệ quả tự nhiên của thiết kế (phản ứng gắn với 1 nội dung nhận định CỤ THỂ, không
   phải với "khái niệm" tab+kỳ), không phải bug — ghi nhận lại để tránh hiểu nhầm là dữ liệu bị mất.

### Phase 5 — LLM insight client dùng chung

- Xác nhận `AiServiceClient` có hỗ trợ prompt tự do; nếu không, thêm client mới theo pattern hiện có.
- 1 service `InsightGenerationService` nhận `(context, prompt template)` → LLM → text, fallback rule-based khi lỗi.

### Phase 6 — Xuất báo cáo (6.3)

- Phụ thuộc quyết định server-render vs FE-capture (mục 4, #6) — POC riêng trước khi cam kết nếu chọn server-render.

### Ghi chú ưu tiên

- Phase 0–2 là nền tảng bắt buộc, không thể song song.
- Phase 3 có thể chia nhỏ, làm song song theo từng nhóm chỉ tiêu — nhưng 2 điểm mở (Vốn khác, 2/4 trạng thái tiến độ) nên chốt với BA trước khi bắt đầu để tránh phải sửa lại UI/logic.
- Phase 4 rủi ro cao nhất về hiệu năng/độ chính xác — làm sau cùng, sau khi mục 4 đã chốt.
- Phase 4bis độc lập với Phase 5 (không cần LLM client thật) — phần DB/API dùng chung đã xong, có
  thể làm việc wiring vào 8 tab bất cứ lúc nào, không cần chờ Phase 5.
- Phase 6 làm cuối vì phụ thuộc toàn bộ data của các tab khác đã ổn định.

## 6. Ngoài phạm vi (đã xác nhận với người dùng)

Mảng **"Cảnh báo"** phát hiện thêm ở `Mô tả logic công thức.xlsx` sheet 2 — gồm:

- Cấu hình ngưỡng cảnh báo bằng phương pháp thống kê (Percentile / Z-score / IQR trên tập mẫu "so với kỳ trước" S1 và "so với trung bình ngành" S2).
- Dashboard thống kê cảnh báo phát sinh (bộ lọc, thẻ tổng hợp, biểu đồ xu hướng, top 5 dự án rủi ro).
- Xem chi tiết 1 cảnh báo (header, ngưỡng vs giá trị thực tế, biểu đồ xu hướng, AI insight).

Đây là 1 subsystem lớn, độc lập với "Phân tích chuyên sâu" — theo quyết định của người dùng, **không đưa vào plan này**. Ghi nhận lại để lập kế hoạch riêng khi cần.
