-- ICT371 PostgreSQL Scenario Assignment
-- Scenario 3: Student Hostel Room Allocation
-- File name format: scenario_3_student_number.sql

DROP TABLE IF EXISTS allocations;
DROP TABLE IF EXISTS hostel_rooms;

CREATE TABLE hostel_rooms (
    room_id SERIAL PRIMARY KEY,
    room_number VARCHAR(20) NOT NULL UNIQUE,
    total_bed_spaces INTEGER NOT NULL CHECK (total_bed_spaces > 0),
    available_bed_spaces INTEGER NOT NULL CHECK (available_bed_spaces >= 0)
);

CREATE TABLE allocations (
    allocation_id SERIAL PRIMARY KEY,
    student_number VARCHAR(30) NOT NULL,
    room_id INTEGER NOT NULL REFERENCES hostel_rooms(room_id),
    status VARCHAR(20) NOT NULL DEFAULT 'ALLOCATED'
        CHECK (status IN ('ALLOCATED', 'CHECKED_OUT'))
);

INSERT INTO hostel_rooms (room_number, total_bed_spaces, available_bed_spaces) VALUES
('A101', 4, 4),
('A102', 2, 1),
('B201', 3, 0);

-- 2. IF ELSIF ELSE
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN SELECT room_number, available_bed_spaces FROM hostel_rooms ORDER BY room_id LOOP
        IF r.available_bed_spaces = 0 THEN
            RAISE NOTICE 'Room %: FULL', r.room_number;
        ELSIF r.available_bed_spaces = 1 THEN
            RAISE NOTICE 'Room %: ONE SPACE LEFT', r.room_number;
        ELSE
            RAISE NOTICE 'Room %: SEVERAL SPACES', r.room_number;
        END IF;
    END LOOP;
END $$;

-- 3. WHILE and numeric FOR
DO $$
DECLARE
    i INTEGER := 1;
BEGIN
    WHILE i <= 3 LOOP
        RAISE NOTICE 'Hostel inspection day %', i;
        i := i + 1;
    END LOOP;

    FOR i IN 1..3 LOOP
        RAISE NOTICE 'Room check number %', i;
    END LOOP;
END $$;

-- 4. Allocate procedure
CREATE OR REPLACE PROCEDURE allocate_room(
    p_student_number VARCHAR,
    p_room_id INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_available INTEGER;
BEGIN
    IF p_student_number IS NULL OR btrim(p_student_number) = '' THEN
        RAISE EXCEPTION 'Student number cannot be blank';
    END IF;

    SELECT available_bed_spaces INTO v_available
    FROM hostel_rooms
    WHERE room_id = p_room_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Room ID % does not exist', p_room_id;
    END IF;

    IF v_available <= 0 THEN
        RAISE EXCEPTION 'Room % is full', p_room_id;
    END IF;

    UPDATE hostel_rooms
    SET available_bed_spaces = available_bed_spaces - 1
    WHERE room_id = p_room_id;

    INSERT INTO allocations (student_number, room_id, status)
    VALUES (p_student_number, p_room_id, 'ALLOCATED');

    RAISE NOTICE 'Student % allocated successfully.', p_student_number;
END;
$$;

-- 5. Two valid allocations and one full-room allocation
CALL allocate_room('STUDENT001', 1);
CALL allocate_room('STUDENT002', 2);

DO $$
BEGIN
    BEGIN
        CALL allocate_room('STUDENT003', 3);
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Expected failed allocation: %', SQLERRM;
    END;
END $$;

SELECT * FROM hostel_rooms ORDER BY room_id;
SELECT * FROM allocations ORDER BY allocation_id;

-- 6. Check-out procedure
CREATE OR REPLACE PROCEDURE check_out(p_allocation_id INTEGER)
LANGUAGE plpgsql
AS $$
DECLARE
    v_room_id INTEGER;
    v_status VARCHAR(20);
BEGIN
    SELECT room_id, status
    INTO v_room_id, v_status
    FROM allocations
    WHERE allocation_id = p_allocation_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Allocation ID % does not exist', p_allocation_id;
    END IF;

    IF v_status = 'CHECKED_OUT' THEN
        RAISE NOTICE 'Allocation % is already checked out. Bed space will not be released again.',
            p_allocation_id;
        RETURN;
    END IF;

    UPDATE hostel_rooms
    SET available_bed_spaces = available_bed_spaces + 1
    WHERE room_id = v_room_id;

    UPDATE allocations
    SET status = 'CHECKED_OUT'
    WHERE allocation_id = p_allocation_id;

    RAISE NOTICE 'Allocation % checked out successfully.', p_allocation_id;
END;
$$;

CALL check_out(1);
CALL check_out(1);

-- 7. Explicit cursor for full or nearly full rooms
DO $$
DECLARE
    room_cursor CURSOR FOR
        SELECT room_id, room_number, available_bed_spaces
        FROM hostel_rooms
        WHERE available_bed_spaces <= 1;
    rec RECORD;
BEGIN
    OPEN room_cursor;
    LOOP
        FETCH room_cursor INTO rec;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Full/nearly full: ID=%, Room=%, Available=%',
            rec.room_id, rec.room_number, rec.available_bed_spaces;
    END LOOP;
    CLOSE room_cursor;
END $$;

-- 8. Blank student number handled with EXCEPTION
DO $$
BEGIN
    BEGIN
        CALL allocate_room('   ', 1);
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Invalid student number handled: %', SQLERRM;
    END;
END $$;

-- 9. Final results
SELECT * FROM hostel_rooms ORDER BY room_id;
SELECT * FROM allocations ORDER BY allocation_id;
