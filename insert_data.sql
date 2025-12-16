-- Attach the old database and insert data into the new one
ATTACH DATABASE '/home/pxp9/Downloads/Telegram Desktop/trails.db' AS old_db;

-- Insert data from old database into new trails table
INSERT INTO trails (id, name, height, distance, velocity, extreme_temp, score, inserted_at, updated_at)
SELECT
    id_trail,
    name,
    height,
    distance,
    velocity,
    extreme_temp,
    score,
    COALESCE(date_tracked, CURRENT_TIMESTAMP),
    COALESCE(date_tracked, CURRENT_TIMESTAMP)
FROM old_db.trail;

-- Update sqlite_sequence for trails table
INSERT OR REPLACE INTO sqlite_sequence (name, seq)
SELECT 'trails', MAX(id) FROM trails;

-- Detach the old database
DETACH DATABASE old_db;
