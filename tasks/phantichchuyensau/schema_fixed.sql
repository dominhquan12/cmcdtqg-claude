CREATE SCHEMA IF NOT EXISTS test;
SET search_path TO test;

CREATE TABLE dm_nganh (
    ma_nganh   VARCHAR(10)  PRIMARY KEY,
    ten_nganh  VARCHAR(255) NOT NULL
);

CREATE TABLE dm_ky_bao_cao (
    ky_key         VARCHAR(10) PRIMARY KEY,
    nam            SMALLINT NOT NULL,
    quy            SMALLINT,
    loai_ky        VARCHAR(4) NOT NULL CHECK (loai_ky IN ('QUY','NAM')),
    ngay_bat_dau   DATE NOT NULL,
    ngay_ket_thuc  DATE NOT NULL,
    thu_tu         INTEGER NOT NULL UNIQUE
);

CREATE TABLE dm_nghia_vu_tuan_thu (
    nghia_vu_id         BIGSERIAL PRIMARY KEY,
    ten_nhom_nghia_vu   VARCHAR(100) NOT NULL,
    ten_nghia_vu        VARCHAR(255) NOT NULL,
    ap_dung_loai_du_an  VARCHAR(20)[] NOT NULL,
    tan_suat            VARCHAR(4) NOT NULL CHECK (tan_suat IN ('QUY','NAM'))
);

CREATE TABLE dm_du_an (
    project_id               BIGINT PRIMARY KEY,
    ma_du_an                 VARCHAR(50)  NOT NULL UNIQUE,
    ten_du_an                VARCHAR(500) NOT NULL,
    loai_du_an               VARCHAR(4)   NOT NULL CHECK (loai_du_an IN ('DDI','FDI','ODI')),
    ma_nganh                 VARCHAR(10)  REFERENCES dm_nganh(ma_nganh),
    linh_vuc                 VARCHAR(255) NOT NULL,
    dia_ban                  VARCHAR(255) NOT NULL,
    dia_diem_thuc_hien       VARCHAR(500),
    ngay_cap_gcndt           DATE NOT NULL,
    ma_so_doanh_nghiep       VARCHAR(50),
    ten_tckt                 VARCHAR(500),
    ngay_cap_dkkd            DATE,
    co_quan_cap_dkkd         VARCHAR(500),
    dia_chi_lien_he          VARCHAR(500),
    so_dien_thoai            VARCHAR(500),
    email                    VARCHAR(500),
    trang_thai_hoat_dong     VARCHAR(20) NOT NULL DEFAULT 'active',
    ky_bao_cao_gan_nhat_key  VARCHAR(10) REFERENCES dm_ky_bao_cao(ky_key),
    ngay_nop_bc_gan_nhat     DATE,
    snapshot_dashboard_json  JSONB,
    created_at               TIMESTAMP NOT NULL DEFAULT now(),
    updated_at               TIMESTAMP NOT NULL DEFAULT now()
);
CREATE INDEX idx_du_an_ma_nganh ON dm_du_an (ma_nganh);
CREATE INDEX idx_du_an_ky_bao_cao_gan_nhat ON dm_du_an (ky_bao_cao_gan_nhat_key);
CREATE INDEX idx_du_an_loai_linh_vuc ON dm_du_an (loai_du_an, linh_vuc);

CREATE TABLE bc_dinh_ky (
    report_id             BIGSERIAL PRIMARY KEY,
    project_id            BIGINT NOT NULL REFERENCES dm_du_an(project_id),
    loai_du_an            VARCHAR(4) NOT NULL,
    ky_key                VARCHAR(10) NOT NULL REFERENCES dm_ky_bao_cao(ky_key),
    ngay_nop_bao_cao      DATE,
    trang_thai            VARCHAR(20) NOT NULL DEFAULT 'duyet',
    ma_bao_cao            VARCHAR(50),
    raw_json              JSONB,
    kafka_event_id        VARCHAR(100) UNIQUE,
    ngay_nhan             TIMESTAMP,
    nguoi_lap_bao_cao     VARCHAR(255),
    tong_von_dau_tu_dang_ky            NUMERIC(20,2),
    von_dau_tu_thuc_hien_luy_ke_gcndt   NUMERIC(20,2),
    von_gop_ky                          NUMERIC(20,2),
    von_gop_luy_ke_gcndt                NUMERIC(20,2),
    von_vay_ky                          NUMERIC(20,2),
    von_vay_luy_ke_gcndt                NUMERIC(20,2),
    loi_nhuan_tai_dau_tu_ky             NUMERIC(20,2),
    loi_nhuan_tai_dau_tu_luy_ke_gcndt   NUMERIC(20,2),
    doanh_thu_thuan_ky                  NUMERIC(20,2),
    gia_tri_xuat_khau_ky                NUMERIC(20,2),
    gia_tri_nhap_khau_ky                NUMERIC(20,2),
    thue_va_nop_ngan_sach_ky            NUMERIC(20,2),
    loi_nhuan_sau_thue_ky               NUMERIC(20,2),
    chi_phi_rd_ky                       NUMERIC(20,2),
    chi_phi_moi_truong_ky               NUMERIC(20,2),
    nguon_thu_khac_ky                   NUMERIC(20,2),
    loi_nhuan                           NUMERIC(20,2),
    tien_do_trang_thai      VARCHAR(30) CHECK (tien_do_trang_thai IN ('dungTienDo','chamTienDo','khoKhanVuongMac','khongCoKhaNangTrienKhai')),
    kho_khan_vuong_mac      TEXT,
    chi_tieu_tai_chinh_json JSONB,
    co_cau_von_json         JSONB,
    created_at  TIMESTAMP NOT NULL DEFAULT now(),
    updated_at  TIMESTAMP NOT NULL DEFAULT now(),
    CONSTRAINT uq_bc_dinh_ky UNIQUE (project_id, ky_key)
);
CREATE INDEX idx_bc_dinh_ky_project_ky      ON bc_dinh_ky (project_id, ky_key);
CREATE INDEX idx_bc_dinh_ky_ky_key          ON bc_dinh_ky (ky_key);

CREATE VIEW vw_bc_dinh_ky_dashboard AS
SELECT b.*,
       ROUND(b.von_dau_tu_thuc_hien_luy_ke_gcndt / NULLIF(b.tong_von_dau_tu_dang_ky,0) * 100, 2) AS ty_le_giai_ngan
FROM bc_dinh_ky b;

CREATE TABLE ai_insight (
    id                  BIGSERIAL PRIMARY KEY,
    project_id          BIGINT NOT NULL REFERENCES dm_du_an(project_id),
    report_id           BIGINT REFERENCES bc_dinh_ky(report_id),
    ky_key              VARCHAR(10) REFERENCES dm_ky_bao_cao,
    tab_nguon           VARCHAR(30) NOT NULL,
    loai_insight        VARCHAR(30) NOT NULL,
    tieu_de             VARCHAR(255),
    noi_dung            TEXT NOT NULL,
    source_fields       JSONB,
    created_at          TIMESTAMP NOT NULL DEFAULT now(),
    expired_at          TIMESTAMP
);
CREATE INDEX idx_ai_insight_report  ON ai_insight (report_id);
CREATE INDEX idx_ai_insight_project ON ai_insight (project_id, tab_nguon, ky_key);

CREATE TABLE bc_rui_ro_chi_tiet (
    id                    BIGSERIAL PRIMARY KEY,
    report_id             BIGINT NOT NULL REFERENCES bc_dinh_ky(report_id),
    project_id            BIGINT NOT NULL REFERENCES dm_du_an(project_id),
    ky_key                VARCHAR(10) NOT NULL REFERENCES dm_ky_bao_cao(ky_key),
    danh_muc              VARCHAR(30) NOT NULL,
    muc_do                VARCHAR(20) NOT NULL,
    gia_tri_diem          NUMERIC(5,2) CHECK (gia_tri_diem BETWEEN 0 AND 10),
    insight_id BIGINT     REFERENCES ai_insight(id)
);
CREATE INDEX idx_rui_ro_report     ON bc_rui_ro_chi_tiet (report_id);
CREATE INDEX idx_rui_ro_project_ky ON bc_rui_ro_chi_tiet (project_id, ky_key);

CREATE TABLE bc_tuan_thu_chi_tiet (
    id                    BIGSERIAL PRIMARY KEY,
    project_id            BIGINT NOT NULL REFERENCES dm_du_an(project_id),
    nghia_vu_id           BIGINT REFERENCES dm_nghia_vu_tuan_thu(nghia_vu_id),
    ky_key                VARCHAR(10) NOT NULL REFERENCES dm_ky_bao_cao(ky_key),
    ten_nhom_snapshot     VARCHAR(100) NOT NULL,
    ten_nghia_vu_snapshot VARCHAR(255) NOT NULL,
    trang_thai            VARCHAR(20) NOT NULL CHECK (trang_thai IN ('tuan_thu','vi_pham')),
    thuc_te_ghi_nhan      TEXT
);
CREATE INDEX idx_tuan_thu_project_ky ON bc_tuan_thu_chi_tiet (project_id, ky_key);
CREATE INDEX idx_tuan_thu_nghia_vu   ON bc_tuan_thu_chi_tiet (nghia_vu_id);
CREATE INDEX idx_tuan_thu_trang_thai ON bc_tuan_thu_chi_tiet (trang_thai);

CREATE TABLE bc_du_bao (
    id                BIGSERIAL PRIMARY KEY,
    project_id        BIGINT NOT NULL REFERENCES dm_du_an(project_id),
    ky_key_du_bao     VARCHAR(10) NOT NULL REFERENCES dm_ky_bao_cao,
    nhom_chi_tieu     VARCHAR(30) NOT NULL,
    gia_tri_du_bao    NUMERIC(20,2),
    growth_pct        NUMERIC(6,2),
    model_meta_json   JSONB,
    generated_at      TIMESTAMP NOT NULL DEFAULT now(),
    UNIQUE (project_id, ky_key_du_bao, nhom_chi_tieu)
);
CREATE INDEX idx_du_bao_project ON bc_du_bao (project_id);


CREATE TABLE bc_chi_tieu_trung_binh (
    avg_id              BIGSERIAL PRIMARY KEY,
    ky_key              VARCHAR(10) NOT NULL  REFERENCES dm_ky_bao_cao(ky_key),
    ma_nganh            VARCHAR(10)  REFERENCES dm_nganh(ma_nganh),
    chi_tieu            VARCHAR(100) NOT NULL,
    gia_tri_trung_binh  NUMERIC(20,2) NOT NULL CHECK (gia_tri_trung_binh >= 0),
    so_mau              INTEGER NOT NULL,
    updated_at          TIMESTAMP NOT NULL DEFAULT now(),
    CONSTRAINT uq_bc_chi_tieu_trung_binh
        UNIQUE (ky_key, ma_nganh, chi_tieu)
);
