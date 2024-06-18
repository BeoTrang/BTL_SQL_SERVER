-- Tạo cơ sở dữ liệu QLGX
CREATE DATABASE QLGX;

-- Tạo bảng SV
CREATE TABLE SV (
    SV_ID NVARCHAR(50) PRIMARY KEY, --Mã sinh viên 
    HoTen NVARCHAR(50) NOT NULL, --Tên sinh viên
    LoaiVe NVARCHAR(20) CHECK (LoaiVe IN ('Ngay', 'Thang')), --Loại vé mà sinh viên đăng ký
    NgayDangKy DATE --Thời gian đăng ký
);

-- Tạo bảng Xe
CREATE TABLE Xe (
    Xe_ID INT IDENTITY(1,1) PRIMARY KEY, --ID của xe
    BienSo NVARCHAR(20), --Lưu biển số
    LoaiXe NVARCHAR(50), --Loại xe như xe máy, ô tô,...
    SV_ID NVARCHAR(50), --Liên kết với bảng sinh viên để biết là ai đã đưa cái xe này vào gửi
    FOREIGN KEY (SV_ID) REFERENCES SV(SV_ID) --Tạo khoá ngoại kết nối với bảng SV
);

-- Tạo bảng GiaoDich để lưu những lượt ra, vào
CREATE TABLE GiaoDich (
    GD_ID INT IDENTITY(1,1) PRIMARY KEY, --ID Giao dịch
    Xe_ID INT, --Lưu ID của xe
    SV_ID NVARCHAR(50), --Lưu mã sinh viên
    TimeIn DATETIME, --Thời gian vào
    TimeOut DATETIME, --Thời gian ra
    Fee DECIMAL(10, 2), --Tiền gửi xe
    FOREIGN KEY (Xe_ID) REFERENCES Xe(Xe_ID), --Khoá ngoại liên kết với bảng Xe
    FOREIGN KEY (SV_ID) REFERENCES SV(SV_ID) --Khoá ngoại liên kết với bảng SV
);

-- Thủ tục nhập thông tin cho bảng Xe
CREATE PROCEDURE ThemXe
    @BienSo NVARCHAR(20),
    @LoaiXe NVARCHAR(50),
    @SV_ID NVARCHAR(50)
AS
BEGIN
    -- Bắt đầu khối try-catch để bắt lỗi
    BEGIN TRY
        -- Kiểm tra nếu sinh viên tồn tại trong bảng SV
        IF EXISTS (SELECT 1 FROM SV WHERE SV_ID = @SV_ID)
        BEGIN
            -- Chèn thông tin xe mới vào bảng Xe
            INSERT INTO Xe (BienSo, LoaiXe, SV_ID) VALUES (@BienSo, @LoaiXe, @SV_ID);
            PRINT 'Thêm thông tin xe thành công'; --Hiển thị nếu thêm xe thành công 
        END
        ELSE
        BEGIN
            PRINT 'Mã sinh viên không tồn tại';
        END
    END TRY
    BEGIN CATCH
        -- Bắt lỗi và in ra thông báo lỗi
        DECLARE @ErrorMessage NVARCHAR(4000);
        SELECT @ErrorMessage = ERROR_MESSAGE();
        PRINT 'Đã xảy ra lỗi: ' + @ErrorMessage;
    END CATCH
END;


-- Thủ tục quét xe vào
CREATE PROCEDURE QuetVao
    @Xe_ID INT, --Đầu vào ID Xe
    @SV_ID NVARCHAR(50) --Đầu vào mã sinh viên
AS
BEGIN
    INSERT INTO GiaoDich (Xe_ID, SV_ID, TimeIn) --Chọn thuộc tính để ghi dữ liệu
	--Dữ liệu được ghi vào là ID xe, mã sinh viên và lấy thời gian hiện tại vào
    VALUES (@Xe_ID, @SV_ID, GETDATE()); 
END;
-- Thủ tục quét xe ra và tính phí theo ngày hoặc tháng nếu hết hạn
CREATE PROCEDURE QuetRa
    @GD_ID INT
AS
BEGIN
    DECLARE @TimeIn DATETIME, @SV_ID NVARCHAR(50), @LoaiVe NVARCHAR(20), @NgayDangKy DATE, @Fee DECIMAL(10, 2),  @ConHan DECIMAL(10, 2);
    -- Khối try-catch để bắt lỗi
    BEGIN TRY
        -- Lấy thời gian vào và mã sinh viên từ bảng GiaoDich
        SELECT @TimeIn = TimeIn, @SV_ID = SV_ID
        FROM GiaoDich
        WHERE GD_ID = @GD_ID;
        -- Lấy loại vé và ngày đăng ký từ bảng SV
        SELECT @LoaiVe = LoaiVe, @NgayDangKy = NgayDangKy
        FROM SV
        WHERE SV_ID = @SV_ID;
        -- Tính phí nếu vé ngày hoặc vé tháng đã hết hạn
        IF @LoaiVe = 'Ngay' -- Nếu là loại vé ngày 
        BEGIN
            IF DATEDIFF(DAY, @NgayDangKy, GETDATE()) > 0
            BEGIN
				IF DATEDIFF(DAY, @TimeIn, @NgayDangKy) = 0 --Nếu đầu tiên gửi xe mà vẫn còn hạn
					SET @ConHan = 2000; --Tí lấy ra ở trừ số tiền ngày đầu tiên còn hạn
				ELSE SET @ConHan = 0;
                SET @Fee = (DATEDIFF(DAY, @TimeIn, GETDATE()) + 1) * 2000 - @ConHan; -- Ví dụ: 2000 VND mỗi ngày
                -- Tự động đăng ký vé ngày mới
                UPDATE SV
                SET NgayDangKy = GETDATE()
                WHERE SV_ID = @SV_ID;
            END
            ELSE SET @Fee = 0; -- Vé ngày còn hạn, không tính phí
        END
        ELSE IF @LoaiVe = 'Thang' -- Nếu là vé tháng 
        BEGIN
            IF DATEDIFF(MONTH, @NgayDangKy, GETDATE()) >= 1
            BEGIN
                SET @Fee = 50000; -- Ví dụ: 50000 VND cho vé tháng nếu đã hết hạn
                -- Tự động gia hạn vé tháng thêm một tháng
                UPDATE SV
                SET NgayDangKy = GETDATE()
                WHERE SV_ID = @SV_ID;
            END
            ELSE SET @Fee = 0; -- Vé tháng còn hạn, không tính phí
        END
        UPDATE GiaoDich -- Cập nhật thời gian ra và phí
        SET TimeOut = GETDATE(), Fee = @Fee
        WHERE GD_ID = @GD_ID;
        PRINT 'Quét xe ra thành công';
    END TRY
    BEGIN CATCH -- Bắt lỗi và in ra thông báo lỗi
        DECLARE @ErrorMessage NVARCHAR(4000);
        SELECT @ErrorMessage = ERROR_MESSAGE();
        PRINT 'Đã xảy ra lỗi: ' + @ErrorMessage;
    END CATCH
END;


CREATE PROCEDURE DangKyVe
    @SV_ID NVARCHAR(50),
    @LoaiVe NVARCHAR(20),
    @NgayDangKy DATE
AS
BEGIN
    -- Kiểm tra nếu loại vé là hợp lệ
    IF @LoaiVe IN ('Ngay', 'Thang')
    BEGIN
        -- Cập nhật thông tin loại vé và ngày đăng ký vé
        UPDATE SV
        SET LoaiVe = @LoaiVe, NgayDangKy = @NgayDangKy
        WHERE SV_ID = @SV_ID;

        PRINT N'Cập nhật thông tin vé thành công';
    END
    ELSE
    BEGIN
        PRINT N'Loại vé không hợp lệ. Vui lòng nhập "Ngay" hoặc "Thang".';
    END
END;

-- Hàm tìm kiếm tất cả các xe được gửi vào ngày nào đó
CREATE PROCEDURE DSX_TrongNgay
    @SearchDate DATE --Biến đầu vào
AS
BEGIN
	-- Hiển thị các cột sau:
    SELECT GiaoDich.GD_ID, GiaoDich.Xe_ID, Xe.BienSo, GiaoDich.TimeIn, GiaoDich.TimeOut, GiaoDich.Fee
    FROM GiaoDich
    JOIN Xe ON GiaoDich.Xe_ID = Xe.Xe_ID --Lấy thuộc tính ở bên bảng xe nên cần kết nối đến bảng Xe
    WHERE CAST(GiaoDich.TimeIn AS DATE) = @SearchDate; --Điều kiện là thời gian gửi trùng với thời gian tìm kiếm
END;

-- Thủ tục thông tin gửi xe
CREATE PROCEDURE XoaGiaoDich
    @XeID INT
AS
BEGIN
    -- Xóa giao dịch liên quan đến xe
    DELETE FROM GiaoDich
    WHERE Xe_ID = @XeID;
    -- Xóa xe
    DELETE FROM Xe
    WHERE Xe_ID = @XeID;
END;

-- Tạo thủ tục hiển thị danh sách xe đang gửi
CREATE PROCEDURE DSXDG
AS
BEGIN
    -- Hiển thị các cột sau
    SELECT 
        GiaoDich.GD_ID, 
        GiaoDich.Xe_ID, 
        Xe.BienSo, 
        Xe.LoaiXe, 
        SV.SV_ID, 
        SV.HoTen, 
        GiaoDich.TimeIn
    FROM GiaoDich
    JOIN Xe ON GiaoDich.Xe_ID = Xe.Xe_ID -- Kết nối với bảng Xe
    JOIN SV ON GiaoDich.SV_ID = SV.SV_ID -- Kết nối với bảng SV
    WHERE GiaoDich.TimeOut IS NULL; -- Điều kiện là Thời gian ra chưa có
END;

-- Tạo thủ tục tính doanh thu theo tháng
CREATE PROCEDURE DoanhThuThang
    @Year INT,
    @Month INT
AS
BEGIN
    SELECT 
        ISNULL(SUM(Fee), 0) AS TotalRevenue
    FROM 
        GiaoDich
    WHERE 
        YEAR(TimeOut) = @Year AND MONTH(TimeOut) = @Month;
END;

-- Thủ tục xuất hóa đơn tiền gửi xe
CREATE PROCEDURE XuatHoaDon
    @GD_ID INT
AS
BEGIN
    -- Bắt đầu khối try-catch để bắt lỗi
    BEGIN TRY
        -- Lấy thông tin chi tiết giao dịch
        SELECT 
            GiaoDich.GD_ID AS 'Mã Giao Dịch',
            SV.SV_ID AS 'Mã Sinh Viên',
            SV.HoTen AS 'Họ Tên Sinh Viên',
            Xe.BienSo AS 'Biển Số Xe',
            Xe.LoaiXe AS 'Loại Xe',
            GiaoDich.TimeIn AS 'Thời Gian Vào',
            GiaoDich.TimeOut AS 'Thời Gian Ra',
            GiaoDich.Fee AS 'Phí Gửi Xe'
        FROM GiaoDich
        JOIN SV ON GiaoDich.SV_ID = SV.SV_ID
        JOIN Xe ON GiaoDich.Xe_ID = Xe.Xe_ID
        WHERE 
            GiaoDich.GD_ID = @GD_ID;
        PRINT 'Hóa đơn đã được xuất thành công.';
    END TRY
    BEGIN CATCH
        -- Bắt lỗi và in ra thông báo lỗi
        DECLARE @ErrorMessage NVARCHAR(4000);
        SELECT @ErrorMessage = ERROR_MESSAGE();
        PRINT 'Đã xảy ra lỗi: ' + @ErrorMessage;
    END CATCH
END;

INSERT INTO SV (SV_ID, HoTen, LoaiVe, NgayDangKy)
VALUES 
    ('SV001', N'Phạm Quang Trường', 'Ngay', '2024-06-15'),
    ('SV002', N'Nguyễn Văn Tùng', 'Thang', '2024-02-15'),
    ('SV003', N'Hồ Tôn Huy', 'Ngay', '2024-03-20'),
	('SV004', N'Vũ Đức Chiến', 'Ngay', '2024-03-20');

-- Thêm dữ liệu vào bảng Xe
INSERT INTO Xe (BienSo, LoaiXe, SV_ID)
VALUES 
    ('29K1-12345', 'Xe may', 'SV001'),
    ('51C2-67890', 'Xe may', 'SV002'),
    ('34T3-45678', 'Xe may', 'SV003'),
	('12T3-23451', 'Xe may', 'SV004');

-- Ví dụ thêm một xe mới
-- Dữ liệu ở bảng sinh viên sẽ có sẵn nên sẽ không cần phần nhập
EXEC ThemXe @BienSo = '30H-12345', @LoaiXe = 'Xe May', @SV_ID = 'SV001';
--Đăng ký vé xe cho sinh viên
EXEC DangKyVe @SV_ID = 'SV004', @LoaiVe = 'Thang', @NgayDangKy = '2024-06-18';
--Quét xe vào
EXEC QuetVao @Xe_ID = 3, @SV_ID = 'SV003';
--Quét xe ra
EXEC QuetRa @GD_ID = 10;
--Hiện thị danh sách các xe đã được gửi trong ngày nào đó
EXEC DSX_TrongNgay @SearchDate = '2024-06-17';
--Danh sách xe đang gửi
EXEC DSXDG;
--Tính doanh thu theo tháng
EXEC DoanhThuThang @Year = 2024, @Month = 6;
--Xuất hoá đơn cho tính tiền cho sinh viên
EXEC XuatHoaDon @GD_ID = 10;