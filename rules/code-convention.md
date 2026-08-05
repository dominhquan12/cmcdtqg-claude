# Code Convention

Quy ước code cụ thể, rút ra từ code thật trong repo (không phải lý thuyết chung của Java/Spring).
Bổ sung cho `.claude/rules/CLAUDE.md` (mô tả kiến trúc/layer) — file này tập trung vào **cách viết
code trong từng layer**. Khi 2 file mâu thuẫn, ưu tiên đọc code thật trước khi áp dụng.

## 1. Naming

- **Class**: `XController` / `XService` (interface) + `XServiceImpl` / `XRepository` (Spring Data JPA
  interface) / DTO hậu tố `Request` / `Response` / `DTO`.
- **Không dùng MapStruct dù có khai báo dependency trong `pom.xml`** — chưa có interface `@Mapper`
  nào trong code. Mapping entity → DTO hiện làm bằng static factory method trên response DTO, ví dụ
  `CbNhomChiTieuResponse.fromEntity(entity)`. Nếu thêm mapper mới, ưu tiên theo pattern này cho tới
  khi cả team quyết định chuyển sang MapStruct thật.
- **Package `com.ai.domain`** (module AI/knowledge-management cũ): entity/field tiếng Anh (`AiKnowledgeAlertConfig`,
  field `component`, `target`, `thresholdCount`...).
- **Package `com.ai.ptcb.domain`** (module "chỉ tiêu giám sát"): entity/field/DTO tiếng Việt
  (`CbNhomChiTieu`, `CbChiTieu`, field `ma`, `ten`, `moTa`, `trangThai`, `daXoa`, `idNguoiTao`,
  `ngayTao`...). Tên package (`api`/`application`/`domain`/`entity`) vẫn giữ tiếng Anh — chỉ tên
  entity/field/DTO đổi sang tiếng Việt. Xem thêm `CLAUDE.md` mục "Two entity conventions".
- **i18n message key**: dạng chấm, ví dụ `"nhomChiTieu.ma.duplicate"`, `"nhomChiTieu.create.success"`,
  `"alert.recipient.email.required"` — không dùng chuỗi literal trực tiếp cho `BusinessException`/`BaseResponseDTO`.
- **Test method**: đặt theo tiếng Việt kiểu `hanhDong_dieuKien_ketQua`, ví dụ
  `create_thanhCong_luuNhan`, `create_trungTen_nemLoi`, `update_doiTen_dongBoTagTrongRecord`.
  Không dùng pattern `should_X_when_Y` hay `testX`.

## 2. Cấu trúc class & Lombok

- **Dependency injection**: constructor injection qua `@RequiredArgsConstructor` + field `private final`
  là chuẩn cho Controller/Service/ServiceImpl. `@Autowired` field injection chỉ xuất hiện ở
  `BaseController` (field `protected` cho `HttpServletRequest`/`UserContext`) — không dùng cho code mới.
- **Entity**: `@Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor @EqualsAndHashCode(callSuper = true)`.
  (`BaseEntity` bản thân dùng `@Data`, nhưng entity con kế thừa nó thì dùng bộ annotation tách lẻ ở trên,
  không dùng `@Data` cho entity con để tránh `equals/hashCode` tự sinh sai khi có quan hệ JPA.)
- **DTO**: `@Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor` — **không** dùng `@Data`
  cho DTO (chỉ `BaseResponseDTO` dùng `@Data` vì không có quan hệ entity).
- **`@Builder.Default`**: bắt buộc khi field enum/boolean trên entity `@Builder` có giá trị mặc định,
  nếu không giá trị mặc định sẽ bị bỏ qua khi build qua Lombok builder.
- **Thứ tự method trong ServiceImpl**: các method của interface theo thứ tự CRUD
  (search → getDetail → create → update → delete), method `private` hỗ trợ gom ở cuối file dưới
  comment marker `// ===== Helpers =====`.

## 3. DTO & Validation

- Sub-object lồng trong DTO khai báo dạng `static class` bên trong DTO cha (ví dụ
  `AiKnowledgeAlertConfig.Recipient`), không tách file riêng nếu chỉ dùng nội bộ 1 DTO.
- Validation dùng Jakarta Validation (`@NotBlank`, `@Size`, `@Pattern`, `@Email`...), message luôn
  dạng key i18n trong dấu `{}`: `@NotBlank(message = "{nhomChiTieu.ma.required}")` — không viết message
  literal.
- Swagger: `@Schema(description = ..., example = ...)` trên field DTO để lên Swagger UI có mô tả/ví dụ,
  không chỉ dựa vào tên field.

## 4. Controller

- Base path: `/api/v1/<module>` (ví dụ `/api/v1/alert`, `/api/v1/ptcb/nhom-chi-tieu`).
- Swagger: `@Tag` ở class, `@Operation` ở mỗi method — bắt buộc cho controller mới.
- `@Permission(group = ..., code = ...)` là chuẩn bắt buộc theo `CLAUDE.md`, nhưng **hiện module
  `ptcb` (`CbNhomChiTieuController` và các controller `ptcb` khác ở giai đoạn đầu) CHƯA gắn** — có
  ghi rõ trong Javadoc "Chưa gắn `@Permission` ở giai đoạn này." Khi hoàn thiện phân quyền cho `ptcb`,
  phải bổ sung `@Permission` cho các controller này, không copy nguyên trạng "chưa gắn" sang code mới.
- **Không `try/catch`** trong Controller/Service — luôn để `GlobalExceptionHandler`
  (`@RestControllerAdvice`) xử lý tập trung.
- **Lưu ý inconsistency giữa module cũ và `ptcb`**: ở `com.ai.api` (module cũ), Controller tự build
  `BaseResponseDTO` từ data thô do Service trả về. Ở một số controller `ptcb`
  (`CbNhomChiTieuController`), Service trả về **đã là `BaseResponseDTO` được bọc sẵn**, Controller chỉ
  pass-through. Đây là 2 style khác nhau đang tồn tại song song — khi viết code mới, chọn 1 trong 2
  và **giữ nhất quán trong cùng 1 module/feature**, không trộn lẫn trong cùng 1 controller.

## 5. Service / ServiceImpl

- `@Transactional` cho method write, `@Transactional(readOnly = true)` cho method read — khai báo rõ
  ở từng method, không đặt `@Transactional` chung ở class rồi override ngầm.
- Logging: `@Slf4j` (Lombok) + SLF4J placeholder style, `log.warn("...: {}", var)` — không dùng
  string concatenation hay `String.format` trong log. Không phải ServiceImpl nào cũng có logger (một
  số service đơn giản không log gì) — thêm logger khi có nhánh lỗi/hành vi cần audit lại được, không
  cần thêm logger cho mọi service theo quán tính.
- Ném lỗi qua `BusinessException(messageKey, HttpStatus, args...)` — luôn kèm `HttpStatus` rõ ràng
  và message key, ví dụ `new BusinessException("nhomChiTieu.ma.duplicate", HttpStatus.CONFLICT)`.

## 6. Entity

Xem `CLAUDE.md` mục "Two entity conventions" để biết khi nào dùng `BaseEntity` (English, audit tự
động qua `@CreatedBy`/`@LastModifiedBy`) vs `BaseAudit` (Vietnamese, audit user-id set tay qua
`UserContext.getTaiKhoanId()`). Bổ sung convention code-level:

- `@Column(name = "...")` luôn snake_case khớp tên cột DB, field Java luôn camelCase — không đặt tên
  field Java trùng tên cột DB.
- Cột JSONB: `@JdbcTypeCode(SqlTypes.JSON)` + `columnDefinition = "jsonb"` trên field kiểu
  `Map`/custom object — không viết `UserType` Hibernate tay.
- `@Id @GeneratedValue(strategy = GenerationType.IDENTITY)` cho PK dạng surrogate id (trừ
  `CbChiTieu` dùng mã string làm PK, xem CLAUDE.md).
- **Comment 1 dòng trên field** khi field có hành vi khác với những gì tên/annotation gợi ý — ví dụ
  `BaseAudit.java:32`:
  ```java
  /** Set thủ công ở service layer bằng {@code UserContext.getTaiKhoanId()} lúc tạo mới. */
  @Column(name = "id_nguoi_tao", nullable = false, updatable = false)
  private Integer idNguoiTao;
  ```
  Field trông giống audit field tự động (đặt cạnh `@Column`, tên kiểu `id_nguoi_tao`) nhưng thực ra
  **không** có `@CreatedBy` — phải tự set trong service. Comment ở đây giải thích cái WHY/bất ngờ đó,
  không phải tả lại field làm gì. Áp dụng pattern này (Javadoc `{@code}` 1 dòng) cho field nào có
  hành vi ngầm tương tự, không viết Javadoc cho field mà tên đã tự nói hết ý nghĩa.

## 7. Test

- Không dùng `@Mock`/`@ExtendWith(MockitoExtension.class)`. Tạo mock thủ công bằng `mock(X.class)`
  trong `@BeforeEach`, rồi new trực tiếp class cần test với các mock đó qua constructor.
- Assertion: AssertJ, static import `assertThat`/`assertThatThrownBy`. Verify/capture: Mockito,
  static import `verify`, `ArgumentCaptor`.
- Không dùng comment `// given/when/then` — dùng comment tiếng Việt ngắn mô tả bước nếu cần
  (`// đã trim`), không bắt buộc phải comment mọi block.
- Tên test class: `<ClassCầnTest>Test` — không dùng hậu tố `Should*`/`*IT`.

## 8. Style chung

- Import: có nơi dùng wildcard (`import org.springframework.web.bind.annotation.*;`,
  `import lombok.*;`) ở Controller, có nơi import tường minh từng class. Chưa có convention bắt buộc
  1 trong 2 — **không tự động reformat/gộp import khi sửa file không liên quan** để tránh diff rác.
- Không có `checkstyle.xml` hay `.editorconfig` trong repo — không có auto-format rule enforce qua
  CI, dựa vào review tay là chính.
- Javadoc tiếng Việt, khá đầy đủ ở class/field/method quan trọng (đặc biệt entity/DTO), dùng
  `{@code}`/`{@link}` khi cross-reference field/class khác. Với code mới trong `ptcb`, giữ style này
  (Javadoc tiếng Việt) thay vì tiếng Anh.
- Hằng số: `ptcb` ưu tiên enum riêng theo từng khái niệm (`CbLoaiChiTieu`, `CbKieuGiaTri` trong
  `com.ai.ptcb.domain.enumeration`) thay vì `static final` rải trong class — khi có một tập giá trị
  cố định (closed set), tạo enum mới trong `domain.enumeration`, không hard-code string/int.

## Việc chưa nhất quán, cần biết khi code mới

Các điểm dưới đây là **inconsistency thật đang tồn tại trong code**, không phải convention nên theo
theo — ghi lại để không vô tình copy pattern sai khi thêm code mới:

1. MapStruct có trong `pom.xml` nhưng chưa được dùng thật ở đâu (mục 1).
2. `@Permission` thiếu ở các controller `ptcb` giai đoạn đầu (mục 4).
3. Controller ở module cũ tự build `BaseResponseDTO`, controller `ptcb` nhận `BaseResponseDTO` đã bọc
   sẵn từ Service — 2 style khác nhau (mục 4).
