# Phân tích chuyên sâu dự án — Phân tích nghiệp vụ & Kế hoạch triển khai

> Nguồn:
> - `.claude/tasks/phantichchuyensau.docx` (mục 6.1–6.3 của tài liệu đặc tả nghiệp vụ/giao diện)
> - `.claude/tasks/100 dòng bc.xlsx` (data mẫu thật của bảng báo cáo nguồn)
> - `.claude/tasks/Mô tả logic công thức.xlsx` (spec công thức chi tiết theo từng mẫu báo cáo, 3 sheet)
> - `.claude/tasks/schema_fixed.sql` (**bản đề xuất DB** từ phía đối tác/khách hàng — không phải bản chốt, được phép điều chỉnh theo nghiệp vụ thực tế)
> - `.claude/tasks/db_analysis_sample.sql` (dump thực tế của schema `schema_fixed.sql` đã load lên DB `test`, kèm data mẫu ~100 dự án — dùng để kiểm chứng schema đề xuất đối chiếu với data thật)
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
2. **AI insight xuất hiện ở 7/10 vùng** — luôn theo pattern "gọi API LLM ngoài, truyền context, nhận về text". Cần 1 service/client LLM dùng chung.
3. **Nhiều công thức tính rõ ràng, unit-test được** — tách thành pure calculator/service riêng theo từng nhóm chỉ tiêu.
4. **Tab Gợi ý phụ thuộc dữ liệu tab Rủi ro** — cần backend trả flag `hasCriticalOrHighRisk`.
5. Mọi bảng "kỳ trước/kỳ này/N kỳ gần nhất" phụ thuộc **loại báo cáo gần nhất là quý hay năm** — cần khái niệm "kỳ" trừu tượng xuyên suốt service layer.

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

### 3.3. Spec công thức chi tiết (`Mô tả logic công thức.xlsx`, sheet 1 & 3) — nguồn tham chiếu chính khi code

- **Sheet 1** (~110 dòng công thức): với mỗi thành phần UI, liệt kê công thức + mapping field chi tiết cho **cả 5 mẫu báo cáo** — chính xác và đầy đủ hơn hẳn phần mô tả trong docx. Khi 2 nguồn (docx vs sheet này) mâu thuẫn, **ưu tiên sheet này**.
- **Sheet 3** (data dictionary): ma trận **Nhóm chỉ tiêu × Chỉ tiêu × Mẫu báo cáo × (Kỳ báo cáo / Lũy kế GCNDT)** — dùng làm bảng tham chiếu field mapping duy nhất khi viết mapper/ETL.
- Sheet 2 (cấu hình ngưỡng cảnh báo, dashboard, chi tiết cảnh báo) — thuộc phần "Cảnh báo", ngoài phạm vi (mục 6).

### 3.4. Rủi ro/gap nghiệp vụ mới phát hiện (ảnh hưởng trực tiếp tới UI đã đặc tả trong docx)

1. **"Vốn khác" không có nguồn dữ liệu ở bất kỳ mẫu nào** (sheet 3: dòng "Vốn khác" trống cho cả 5 mẫu), nhưng tab Vốn & Giải ngân (docx 2.2.d) mô tả bar/donut chart có đủ 4 hạng mục gồm cả "Vốn khác". → **Cần hỏi BA**: bỏ hạng mục này, luôn hiển thị 0/"-", hay có nguồn khác chưa được liệt kê trong spec?
2. **Trạng thái tiến độ: 4/5 mẫu chỉ suy luận được 2/4 trạng thái.** Mẫu 103/37/116/114 chỉ fallback ra "Đúng tiến độ" / "Gặp khó khăn" từ text tự do `khoKhanVuongMac`; **không thể** tự suy ra "Chậm tiến độ" hay "Không có khả năng triển khai" bằng rule. Chỉ mẫu 89 có đủ 4 cờ boolean thật (`danhGia.dungTienDo/chamTienDo/khoKhanVuongMac/khongCoKhaNangTrienKhai`). → Ảnh hưởng: line chart Tiến độ (docx 2.2.e) hứa 4 trạng thái nhưng phần lớn dự án trong nước thực tế chỉ có 2/4 khả dụng; công thức điểm rủi ro nhóm Tiến độ (đúng=2.5/chậm=5/khó khăn=7.5/không thể=10) cũng gần như không bao giờ ra 5 hoặc 10 với dữ liệu trong nước.
3. **Điểm rủi ro nhóm "Tài chính" chia theo số chỉ tiêu khác nhau theo từng mẫu** (chia 4, 7, hoặc 8 tuỳ mẫu, không phải hằng số cố định) — công thức: số chỉ tiêu có Xu hướng giảm × (10 / số chỉ tiêu khả dụng của mẫu đó). Cần bảng cấu hình hoặc tính động số chỉ tiêu có dữ liệu, không hard-code chia 8.
4. **Ý nghĩa cột `cotA`/`cotB`/`cotC` KHÔNG giống nhau giữa các mẫu**: mẫu 103/114 → cotA=kỳ, cotC=lũy kế GCNDT (cotB không dùng); mẫu 37/116 → cotA=kỳ, cotB=lũy kế (không có cotC). → Mapper/ETL phải viết riêng theo `LoaiBaoCaoId`.
5. **`LoaiKy` trên bảng nguồn không đáng tin cậy** (rỗng/NULL trong toàn bộ data mẫu) — kỳ báo cáo (quý/năm) phải tự suy ra từ `LoaiBaoCaoId` (103,114→quý; 37,116→năm; 89→năm theo `NgayNop`), không đọc trực tiếp cột `LoaiKy`.

## 4. Điểm cần làm rõ (cập nhật theo ngữ cảnh mới)

| # | Nội dung | Trạng thái |
| --- | --- | --- |
| 1 | Nguồn "dự án" (`dm_du_an`): đồng bộ từ phân hệ dự án hay bảng riêng? | Vẫn mở — nhưng field list đã rõ hơn nhờ schema đề xuất (mục 3.2) |
| 2 | Nguồn `bc_dinh_ky`: cơ chế đọc từ bảng `BaoCao` (share DB / API / Kafka)? | **Đã xác nhận nguồn** (mục 3.1); cơ chế đồng bộ vẫn cần chốt |
| 3 | "Trung bình ngành" tính real-time hay batch? | **Có gợi ý**: bảng `bc_chi_tieu_trung_binh` có `updated_at` → hướng batch; cần chốt job/schedule |
| 4 | Mô hình dự báo dùng thuật toán nào? | Vẫn mở — `bc_du_bao.model_meta_json` gợi ý có model thật nhưng chưa rõ thuật toán |
| 5 | LLM client dùng chung có sẵn không? | Vẫn mở |
| 6 | Export PNG/zip: server-render hay FE tự capture? | Vẫn mở |
| 7 | Ngưỡng cấu hình động (rủi ro, gợi ý...) | **Ra khỏi phạm vi** — thuộc mảng "Cảnh báo", xem mục 6 |
| 8 (mới) | "Vốn khác" không có nguồn dữ liệu — bỏ hay giữ UI? | Mở (mục 3.4.1) |
| 9 (mới) | Chấp nhận 2/4 trạng thái tiến độ cho báo cáo trong nước, hay cần nguồn dữ liệu khác? | Mở (mục 3.4.2) |

## 5. Đề xuất kế hoạch triển khai (theo `docs/clean_architecture_guide.md` & convention `com.ai.ptcb`)

Tiếp tục trong module `ptcb`, dùng `BaseAudit` + tên bảng/cột tiếng Việt, audit thủ công qua `UserContext.getTaiKhoanId()`.

### Phase 0 — Chốt open questions (mục 4) + thiết kế DB

- Dùng `schema_fixed.sql` làm **điểm khởi đầu tham khảo**, không copy nguyên — thiết kế lại entity theo 5 điều chỉnh ở mục 3.2 và điền `BaseAudit`.
- Entity dự kiến: `DuAn`, `BcDinhKy` (JSONB raw + cột chuẩn hoá, ETL riêng theo `LoaiBaoCaoId`), `AiInsight`, `BcRuiRoChiTiet`, `BcTuanThuChiTiet` (+ `NghiaVuTuanThu`), `BcDuBao`, `BcChiTieuTrungBinh`, `DmNganh`, `DmKyBaoCao`.
- Thêm cấu hình "số chỉ tiêu tài chính theo mẫu" (mục 3.4.3) nếu không muốn hard-code trong service.

### Phase 1 — Danh sách dự án (6.1)

- Repository + service đọc `DuAn` (paginate, search, filter).
- Controller `GET /api/PhanTichChuyenSau/DuAn` với `@Permission`.

### Phase 2 — Header + KPI card + Tab Tổng quan (6.2.a, 6.2.b)

- Mapper riêng theo từng `LoaiBaoCaoId` (103/37/116/114/89) — bám sát mục 3.3 (sheet 1+3), **không dùng docx làm nguồn công thức**.
- Calculator riêng cho từng KPI, pure function, dễ unit test.
- Tab Tổng quan: ghép 4 đoạn mô tả + gọi LLM client (rule-based fallback).

### Phase 3 — Tab theo từng nhóm chỉ tiêu (Tài chính, Vốn & Giải ngân, Tiến độ, Tuân thủ, Rủi ro)

- Mỗi tab 1 service riêng; risk-score Tài chính dùng số chỉ tiêu động theo mẫu (mục 3.4.3), không hard-code.
- Tiến độ: xử lý rõ trường hợp chỉ 2/4 trạng thái khả dụng cho báo cáo trong nước (mục 3.4.2) — cần quyết định nghiệp vụ trước khi code UI cho 4 trạng thái.
- Vốn & Giải ngân: xử lý "Vốn khác" theo quyết định ở mục 3.4.1.
- Rủi ro: trả flag `hasCriticalOrHighRisk` cho tab Gợi ý.

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
