-- ICT371 PostgreSQL Scenario Assignment
-- Scenario 4: Campus Clinic Medicine Dispensing
-- File name format: scenario_4_student_number.sql

DROP TABLE IF EXISTS dispensing_records;
DROP TABLE IF EXISTS medicines;

CREATE TABLE medicines (
    medicine_id SERIAL PRIMARY KEY,
    medicine_name VARCHAR(150) NOT NULL,
    stock_quantity INTEGER NOT NULL CHECK (stock_quantity >= 0)
);

CREATE TABLE dispensing_records (
    dispensing_id SERIAL PRIMARY KEY,
    medicine_id INTEGER NOT NULL REFERENCES medicines(medicine_id),
    student_number VARCHAR(30) NOT NULL,
    quantity INTEGER NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'DISPENSED'
        CHECK (status IN ('DISPENSED', 'REVERSED'))
);

INSERT INTO medicines (medicine_name, stock_quantity) VALUES
('Paracetamol', 100),
('Amoxicillin', 20),
('Ibuprofen', 0);

-- 2. IF ELSIF ELSE
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN SELECT medicine_name, stock_quantity FROM medicines ORDER BY medicine_id LOOP
        IF r.stock_quantity = 0 THEN
            RAISE NOTICE '%: OUT OF STOCK', r.medicine_name;
        ELSIF r.stock_quantity <= 20 THEN
            RAISE NOTICE '%: LOW ON STOCK', r.medicine_name;
        ELSE
            RAISE NOTICE '%: SUFFICIENTLY STOCKED', r.medicine_name;
        END IF;
    END LOOP;
END $$;

-- 3. WHILE and numeric FOR
DO $$
DECLARE
    i INTEGER := 1;
BEGIN
    WHILE i <= 3 LOOP
        RAISE NOTICE 'Stock review day %', i;
        i := i + 1;
    END LOOP;

    FOR i IN 1..3 LOOP
        RAISE NOTICE 'Shelf inspection number %', i;
    END LOOP;
END $$;

-- 4. Dispense procedure
CREATE OR REPLACE PROCEDURE dispense_medicine(
    p_medicine_id INTEGER,
    p_student_number VARCHAR,
    p_quantity INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_stock INTEGER;
BEGIN
    IF p_quantity <= 0 THEN
        RAISE EXCEPTION 'Invalid quantity: quantity must be greater than zero';
    END IF;

    SELECT stock_quantity INTO v_stock
    FROM medicines
    WHERE medicine_id = p_medicine_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Medicine ID % does not exist', p_medicine_id;
    END IF;

    IF v_stock < p_quantity THEN
        RAISE EXCEPTION 'Insufficient stock. Available: %, requested: %',
            v_stock, p_quantity;
    END IF;

    UPDATE medicines
    SET stock_quantity = stock_quantity - p_quantity
    WHERE medicine_id = p_medicine_id;

    INSERT INTO dispensing_records (medicine_id, student_number, quantity, status)
    VALUES (p_medicine_id, p_student_number, p_quantity, 'DISPENSED');

    RAISE NOTICE 'Medicine dispensed successfully.';
END;
$$;

-- 5. Two valid quantities and one exceeding stock
CALL dispense_medicine(1, 'STUDENT001', 10);
CALL dispense_medicine(2, 'STUDENT002', 5);

DO $$
BEGIN
    BEGIN
        CALL dispense_medicine(2, 'STUDENT003', 50);
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Expected failed dispensing: %', SQLERRM;
    END;
END $$;

SELECT * FROM medicines ORDER BY medicine_id;
SELECT * FROM dispensing_records ORDER BY dispensing_id;

-- 6. Reverse procedure
CREATE OR REPLACE PROCEDURE reverse_dispensing(p_dispensing_id INTEGER)
LANGUAGE plpgsql
AS $$
DECLARE
    v_medicine_id INTEGER;
    v_quantity INTEGER;
    v_status VARCHAR(20);
BEGIN
    SELECT medicine_id, quantity, status
    INTO v_medicine_id, v_quantity, v_status
    FROM dispensing_records
    WHERE dispensing_id = p_dispensing_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Dispensing record % does not exist', p_dispensing_id;
    END IF;

    IF v_status = 'REVERSED' THEN
        RAISE NOTICE 'Record % is already reversed. Stock will not be restored again.',
            p_dispensing_id;
        RETURN;
    END IF;

    UPDATE medicines
    SET stock_quantity = stock_quantity + v_quantity
    WHERE medicine_id = v_medicine_id;

    UPDATE dispensing_records
    SET status = 'REVERSED'
    WHERE dispensing_id = p_dispensing_id;

    RAISE NOTICE 'Dispensing record % reversed successfully.', p_dispensing_id;
END;
$$;

CALL reverse_dispensing(1);
CALL reverse_dispensing(1);

-- 7. Explicit cursor for medicines below low-stock threshold
DO $$
DECLARE
    medicine_cursor CURSOR FOR
        SELECT medicine_id, medicine_name, stock_quantity
        FROM medicines
        WHERE stock_quantity < 20;
    rec RECORD;
BEGIN
    OPEN medicine_cursor;
    LOOP
        FETCH medicine_cursor INTO rec;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Below low-stock threshold: ID=%, Medicine=%, Stock=%',
            rec.medicine_id, rec.medicine_name, rec.stock_quantity;
    END LOOP;
    CLOSE medicine_cursor;
END $$;

-- 8. Negative quantity handled with EXCEPTION
DO $$
BEGIN
    BEGIN
        CALL dispense_medicine(1, 'STUDENT004', -5);
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Invalid negative quantity handled: %', SQLERRM;
    END;
END $$;

-- 9. Final results
SELECT * FROM medicines ORDER BY medicine_id;
SELECT * FROM dispensing_records ORDER BY dispensing_id;
