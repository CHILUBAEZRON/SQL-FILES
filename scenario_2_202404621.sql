-- ICT371 PostgreSQL Scenario Assignment
-- Scenario 2: Computer Laboratory Reservations
-- File name format: scenario_2_student_number.sql

DROP TABLE IF EXISTS reservations;
DROP TABLE IF EXISTS lab_sessions;

CREATE TABLE lab_sessions (
    session_id SERIAL PRIMARY KEY,
    session_name VARCHAR(150) NOT NULL,
    total_workstations INTEGER NOT NULL CHECK (total_workstations > 0),
    available_workstations INTEGER NOT NULL CHECK (available_workstations >= 0)
);

CREATE TABLE reservations (
    reservation_id SERIAL PRIMARY KEY,
    session_id INTEGER NOT NULL REFERENCES lab_sessions(session_id),
    lecturer VARCHAR(100) NOT NULL,
    workstations INTEGER NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'RESERVED'
        CHECK (status IN ('RESERVED', 'CANCELLED'))
);

INSERT INTO lab_sessions (session_name, total_workstations, available_workstations) VALUES
('Database Practical', 30, 30),
('Networking Practical', 20, 5),
('Programming Practical', 25, 0);

-- 2. IF ELSIF ELSE
DO $$
DECLARE
    v_available INTEGER;
    v_total INTEGER;
BEGIN
    SELECT available_workstations, total_workstations
    INTO v_available, v_total
    FROM lab_sessions WHERE session_id = 1;

    IF v_available = 0 THEN
        RAISE NOTICE 'Database Practical: FULL';
    ELSIF v_available <= v_total * 0.25 THEN
        RAISE NOTICE 'Database Practical: NEARLY FULL';
    ELSE
        RAISE NOTICE 'Database Practical: ENOUGH WORKSTATIONS';
    END IF;

    SELECT available_workstations, total_workstations
    INTO v_available, v_total
    FROM lab_sessions WHERE session_id = 2;

    IF v_available = 0 THEN
        RAISE NOTICE 'Networking Practical: FULL';
    ELSIF v_available <= v_total * 0.25 THEN
        RAISE NOTICE 'Networking Practical: NEARLY FULL';
    ELSE
        RAISE NOTICE 'Networking Practical: ENOUGH WORKSTATIONS';
    END IF;

    SELECT available_workstations, total_workstations
    INTO v_available, v_total
    FROM lab_sessions WHERE session_id = 3;

    IF v_available = 0 THEN
        RAISE NOTICE 'Programming Practical: FULL';
    ELSIF v_available <= v_total * 0.25 THEN
        RAISE NOTICE 'Programming Practical: NEARLY FULL';
    ELSE
        RAISE NOTICE 'Programming Practical: ENOUGH WORKSTATIONS';
    END IF;
END $$;

-- 3. WHILE and numeric FOR
DO $$
DECLARE
    i INTEGER := 1;
BEGIN
    WHILE i <= 3 LOOP
        RAISE NOTICE 'Session preparation reminder %', i;
        i := i + 1;
    END LOOP;

    FOR i IN 1..3 LOOP
        RAISE NOTICE 'Workstation check number %', i;
    END LOOP;
END $$;

-- 4. Reserve procedure
CREATE OR REPLACE PROCEDURE reserve_workstations(
    p_session_id INTEGER,
    p_lecturer VARCHAR,
    p_workstations INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_available INTEGER;
BEGIN
    IF p_workstations <= 0 THEN
        RAISE EXCEPTION 'Invalid number of workstations: must be greater than zero';
    END IF;

    SELECT available_workstations INTO v_available
    FROM lab_sessions
    WHERE session_id = p_session_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Session ID % does not exist', p_session_id;
    END IF;

    IF v_available < p_workstations THEN
        RAISE EXCEPTION 'Not enough workstations. Available: %, requested: %',
            v_available, p_workstations;
    END IF;

    UPDATE lab_sessions
    SET available_workstations = available_workstations - p_workstations
    WHERE session_id = p_session_id;

    INSERT INTO reservations (session_id, lecturer, workstations, status)
    VALUES (p_session_id, p_lecturer, p_workstations, 'RESERVED');

    RAISE NOTICE 'Reservation recorded successfully.';
END;
$$;

-- 5. Two valid reservations and one exceeding capacity
CALL reserve_workstations(1, 'Dr. Banda', 10);
CALL reserve_workstations(2, 'Dr. Phiri', 3);

DO $$
BEGIN
    BEGIN
        CALL reserve_workstations(2, 'Dr. Tembo', 10);
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Expected failed reservation: %', SQLERRM;
    END;
END $$;

SELECT * FROM lab_sessions ORDER BY session_id;
SELECT * FROM reservations ORDER BY reservation_id;

-- 6. Cancel procedure
CREATE OR REPLACE PROCEDURE cancel_reservation(p_reservation_id INTEGER)
LANGUAGE plpgsql
AS $$
DECLARE
    v_session_id INTEGER;
    v_workstations INTEGER;
    v_status VARCHAR(20);
BEGIN
    SELECT session_id, workstations, status
    INTO v_session_id, v_workstations, v_status
    FROM reservations
    WHERE reservation_id = p_reservation_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Reservation ID % does not exist', p_reservation_id;
    END IF;

    IF v_status = 'CANCELLED' THEN
        RAISE NOTICE 'Reservation % is already cancelled. Workstations will not be released again.',
            p_reservation_id;
        RETURN;
    END IF;

    UPDATE lab_sessions
    SET available_workstations = available_workstations + v_workstations
    WHERE session_id = v_session_id;

    UPDATE reservations
    SET status = 'CANCELLED'
    WHERE reservation_id = p_reservation_id;

    RAISE NOTICE 'Reservation % cancelled successfully.', p_reservation_id;
END;
$$;

CALL cancel_reservation(1);
CALL cancel_reservation(1);

-- 7. Explicit cursor for sessions with few workstations remaining
DO $$
DECLARE
    session_cursor CURSOR FOR
        SELECT session_id, session_name, available_workstations
        FROM lab_sessions
        WHERE available_workstations <= 5;
    rec RECORD;
BEGIN
    OPEN session_cursor;
    LOOP
        FETCH session_cursor INTO rec;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Few workstations: ID=%, Session=%, Available=%',
            rec.session_id, rec.session_name, rec.available_workstations;
    END LOOP;
    CLOSE session_cursor;
END $$;

-- 8. Zero workstation request handled with EXCEPTION
DO $$
BEGIN
    BEGIN
        CALL reserve_workstations(1, 'Dr. Invalid', 0);
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Invalid quantity handled: %', SQLERRM;
    END;
END $$;

-- 9. Final results
SELECT * FROM lab_sessions ORDER BY session_id;
SELECT * FROM reservations ORDER BY reservation_id;
