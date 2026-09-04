-- Active: 1784643190439@@172.17.43.146@5432@metals@public
-- Metals database schema
-- Uses atomic_number as the natural primary key for elements.

DROP TABLE IF EXISTS alloy_elements;
DROP TABLE IF EXISTS coins;
DROP TABLE IF EXISTS alloys;
DROP TABLE IF EXISTS elements;
 
CREATE TABLE elements (

    atomic_number SMALLINT PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    symbol CHAR(3) NOT NULL UNIQUE,
    melting_point_f NUMERIC(8,2),
    boiling_point_f NUMERIC(8,2),
    color VARCHAR(50),
    density NUMERIC(8,2),
    category VARCHAR(40),
    state_at_room_temp VARCHAR(20),
    is_toxic BOOLEAN NOT NULL DEFAULT FALSE,
    is_magnetic BOOLEAN NOT NULL DEFAULT FALSE,
    common_uses TEXT,

    CONSTRAINT chk_atomic_number_positive CHECK (atomic_number > 0),
    CONSTRAINT chk_temp_order
        CHECK (boiling_point_f IS NULL OR melting_point_f IS NULL OR boiling_point_f > melting_point_f),
    CONSTRAINT chk_state_at_room_temp
        CHECK (state_at_room_temp IN ('SOLID', 'LIQUID', 'GAS'))
);

CREATE TABLE alloys (
    alloy_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    color VARCHAR(50),
    description TEXT
);

CREATE TABLE coins (
    coin_id SERIAL PRIMARY KEY,
    name VARCHAR(120) NOT NULL,
    country VARCHAR(80),
    mint VARCHAR(120),
    year_introduced SMALLINT,
    alloy_id INTEGER NOT NULL,
    gross_weight_g NUMERIC(10,4),
    face_value NUMERIC(12,2),
    face_value_currency_code CHAR(3),

    CONSTRAINT fk_coins_alloy
        FOREIGN KEY (alloy_id)
        REFERENCES alloys (alloy_id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_coins_year_introduced
        CHECK (year_introduced IS NULL OR year_introduced BETWEEN 500 AND 3000)
);

CREATE TABLE alloy_elements (
    alloy_id SMALLINT NOT NULL,
    atomic_number SMALLINT NOT NULL,
    percent_of_alloy NUMERIC(6,3) NOT NULL,

    CONSTRAINT pk_alloy_elements PRIMARY KEY (alloy_id, atomic_number),

    CONSTRAINT fk_alloy_elements_alloy
        FOREIGN KEY (alloy_id)
        REFERENCES alloys (alloy_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_alloy_elements_element
        FOREIGN KEY (atomic_number)
        REFERENCES elements (atomic_number)
        ON DELETE RESTRICT,

    CONSTRAINT chk_percent_of_alloy_range CHECK (percent_of_alloy > 0 AND percent_of_alloy <= 100)
);

CREATE INDEX idx_alloy_elements_atomic_number ON alloy_elements (atomic_number);

-- seed data 
INSERT INTO elements (
    atomic_number,
    name,
    symbol,
    melting_point_f,
    boiling_point_f,
    color,
    density,
    category,
    state_at_room_temp,
    is_toxic,
    is_magnetic,
    common_uses
)
VALUES
    -- (80, 'Mercury', 'Hg', -38, 674, 'silvery', 13.53, 'TRANSITION_METAL', 'LIQUID', TRUE, FALSE, 'thermometers'),
    -- (31, 'Gallium', 'Ga', 86, 3999, 'silvery', 5.91, 'POST_TRANSITION_METAL', 'SOLID', FALSE, FALSE, 'electronics'),
    -- (55, 'Cesium', 'Cs', 83, 1240, 'golden', 1.93, 'ALKALI_METAL', 'SOLID', TRUE, FALSE, 'atomic clocks'),
    (37, 'Rubidium', 'Rb', 103, 1274, 'silvery', 1.53, 'ALKALI_METAL', 'SOLID', TRUE, FALSE, 'research'),
    (19, 'Potassium', 'K', 146, 1382, 'silvery', 0.86, 'ALKALI_METAL', 'SOLID', TRUE, FALSE, 'fertilizer'),
    (11, 'Sodium', 'Na', 208, 1621, 'silvery', 0.97, 'ALKALI_METAL', 'SOLID', TRUE, FALSE, 'salt production'),
    (49, 'Indium', 'In', 314, 3762, 'silvery', 7.31, 'POST_TRANSITION_METAL', 'SOLID', FALSE, FALSE, 'touchscreens'),
    (50, 'Tin', 'Sn', 450, 4716, 'silvery', 7.29, 'POST_TRANSITION_METAL', 'SOLID', FALSE, FALSE, 'solder'),
    (83, 'Bismuth', 'Bi', 520, 2847, 'iridescent', 9.78, 'POST_TRANSITION_METAL', 'SOLID', FALSE, FALSE, 'alloys'),
    (82, 'Lead', 'Pb', 621, 3182, 'dull gray', 11.34, 'POST_TRANSITION_METAL', 'SOLID', TRUE, FALSE, 'batteries'),
    (30, 'Zinc', 'Zn', 787, 1665, 'bluish silver', 7.14, 'TRANSITION_METAL', 'SOLID', FALSE, FALSE, 'galvanizing'),
    (12, 'Magnesium', 'Mg', 1202, 1994, 'silvery', 1.74, 'ALKALINE_EARTH_METAL', 'SOLID', FALSE, FALSE, 'alloys'),
    (13, 'Aluminum', 'Al', 1221, 4473, 'silvery', 2.70, 'POST_TRANSITION_METAL', 'SOLID', FALSE, FALSE, 'cans'),
    (47, 'Silver', 'Ag', 1763, 3924, 'silver', 10.49, 'TRANSITION_METAL', 'SOLID', FALSE, FALSE, 'jewelry'),
    (79, 'Gold', 'Au', 1948, 5379, 'gold', 19.32, 'TRANSITION_METAL', 'SOLID', FALSE, FALSE, 'currency'),
    (29, 'Copper', 'Cu', 1984, 4652, 'reddish', 8.96, 'TRANSITION_METAL', 'SOLID', FALSE, FALSE, 'wiring'),
    (28, 'Nickel', 'Ni', 2651, 4915, 'silvery', 8.90, 'TRANSITION_METAL', 'SOLID', FALSE, TRUE, 'alloys'),
    (27, 'Cobalt', 'Co', 2723, 5301, 'bluish', 8.86, 'TRANSITION_METAL', 'SOLID', TRUE, TRUE, 'magnets'),
    (46, 'Palladium', 'Pd', 2831, 5360, 'silvery', 12.02, 'TRANSITION_METAL', 'SOLID', FALSE, FALSE, 'catalysts'),
    (22, 'Titanium', 'Ti', 3034, 5949, 'gray', 4.51, 'TRANSITION_METAL', 'SOLID', FALSE, FALSE, 'aerospace'),
    (78, 'Platinum', 'Pt', 3215, 6917, 'silvery', 21.45, 'TRANSITION_METAL', 'SOLID', FALSE, FALSE, 'jewelry'),
    (24, 'Chromium', 'Cr', 3465, 4840, 'steel gray', 7.19, 'TRANSITION_METAL', 'SOLID', TRUE, FALSE, 'plating'),
    (42, 'Molybdenum', 'Mo', 4753, 8382, 'gray', 10.28, 'TRANSITION_METAL', 'SOLID', FALSE, FALSE, 'steel alloys'),
    (74, 'Tungsten', 'W', 6192, 10031, 'gray', 19.25, 'TRANSITION_METAL', 'SOLID', FALSE, FALSE, 'filaments')
ON CONFLICT (atomic_number) DO NOTHING;

-- Additional reference elements needed by alloy seed formulas.
INSERT INTO elements (
    atomic_number,
    name,
    symbol,
    category,
    state_at_room_temp,
    is_toxic,
    is_magnetic,
    common_uses
)
VALUES
    (14, 'Silicon', 'Si', 'METALLOID', 'SOLID', FALSE, FALSE, 'electronics and alloying'),
    (15, 'Phosphorus', 'P', 'NONMETAL', 'SOLID', TRUE, FALSE, 'alloying additive'),
    (25, 'Manganese', 'Mn', 'TRANSITION_METAL', 'SOLID', FALSE, FALSE, 'steel and alloying'),
    (51, 'Antimony', 'Sb', 'METALLOID', 'SOLID', TRUE, FALSE, 'hardeners in pewter and lead alloys'),
    (77, 'Iridium', 'Ir', 'TRANSITION_METAL', 'SOLID', FALSE, FALSE, 'platinum hardening additive')
ON CONFLICT (atomic_number) DO NOTHING;

-- Alloy master rows.
INSERT INTO alloys (name, color, description)
VALUES
    ('Fine Gold 24K', 'gold', 'High-purity investment gold for bullion and premium coins.'),
    ('22K Gold Coin Alloy', 'rich gold', 'Durable coin gold with added strength compared to 24K.'),
    ('18K Yellow Gold', 'yellow gold', 'Jewelry alloy balancing color and wear resistance.'),
    ('18K Rose Gold', 'rose gold', 'Jewelry alloy with higher copper content for warm red tone.'),
    ('18K White Gold (Palladium)', 'white gold', 'Nickel-free white gold variant used in fine jewelry.'),
    ('Sterling Silver', 'bright silver', 'Standard jewelry and silverware alloy.'),
    ('Coin Silver', 'silver', 'Traditional coinage silver composition.'),
    ('Britannia Silver', 'bright silver', 'Higher-purity silver standard for premium silver goods.'),
    ('Platinum 950', 'silvery white', 'Fine jewelry platinum alloy with improved hardness.'),
    ('Yellow Brass', 'yellow', 'General-purpose brass for hardware, fittings, and decorative parts.'),
    ('Red Brass', 'reddish gold', 'Corrosion-resistant brass for plumbing fittings and valves.'),
    ('Naval Brass', 'yellow-gold', 'Brass designed for marine service and saltwater resistance.'),
    ('Leaded Free-Cutting Brass', 'yellow', 'Machinable brass for precision turned components.'),
    ('Gilding Metal', 'reddish yellow', 'Copper-rich brass used for cladding and decorative parts.'),
    ('Tin Bronze', 'bronze', 'General bronze for castings, bushings, and decorative work.'),
    ('Phosphor Bronze', 'bronze', 'Springy bronze for contacts, springs, and wear-resistant parts.'),
    ('Aluminum Bronze', 'golden bronze', 'Strong corrosion-resistant bronze for marine and industrial parts.'),
    ('Silicon Bronze', 'bronze', 'Corrosion-resistant bronze for fasteners and architectural hardware.'),
    ('Manganese Bronze', 'yellow bronze', 'High-strength bronze family used for propellers and shafts.'),
    ('Leaded Bronze', 'bronze', 'Bearing bronze with improved anti-friction behavior.'),
    ('Bell Metal', 'dark bronze', 'Resonant bronze for bells and musical castings.'),
    ('Traditional Lead Pewter', 'dull silver', 'Historical pewter for decorative artifacts (not food-safe).'),
    ('Lead-Free Pewter', 'bright silver', 'Modern pewter for decorative and giftware applications.'),
    ('Aluminum 3003', 'silver gray', 'Formable sheet alloy for cookware and general fabrication.'),
    ('Aluminum 5052', 'silver gray', 'Corrosion-resistant aluminum for marine and sheet applications.'),
    ('Aluminum 6061', 'silver gray', 'General-purpose structural aluminum for machining and fabrication.'),
    ('Aluminum 7075', 'silver gray', 'High-strength aluminum for aerospace and tooling.'),
    ('Aluminum 2024', 'silver gray', 'High-strength aluminum used in aircraft structures.'),
    ('A356 Cast Aluminum', 'silver gray', 'Cast aluminum alloy for wheels and complex cast parts.')
ON CONFLICT (name) DO NOTHING;

-- Alloy composition rows.
WITH alloy_component_data (alloy_name, element_symbol, pct) AS (
    VALUES
        ('Fine Gold 24K', 'Au', 99.990),
        ('Fine Gold 24K', 'Cu', 0.010),

        ('22K Gold Coin Alloy', 'Au', 91.670),
        ('22K Gold Coin Alloy', 'Ag', 5.000),
        ('22K Gold Coin Alloy', 'Cu', 3.330),

        ('18K Yellow Gold', 'Au', 75.000),
        ('18K Yellow Gold', 'Ag', 12.500),
        ('18K Yellow Gold', 'Cu', 12.500),

        ('18K Rose Gold', 'Au', 75.000),
        ('18K Rose Gold', 'Cu', 22.250),
        ('18K Rose Gold', 'Ag', 2.750),

        ('18K White Gold (Palladium)', 'Au', 75.000),
        ('18K White Gold (Palladium)', 'Pd', 15.000),
        ('18K White Gold (Palladium)', 'Ag', 10.000),

        ('Sterling Silver', 'Ag', 92.500),
        ('Sterling Silver', 'Cu', 7.500),

        ('Coin Silver', 'Ag', 90.000),
        ('Coin Silver', 'Cu', 10.000),

        ('Britannia Silver', 'Ag', 95.800),
        ('Britannia Silver', 'Cu', 4.200),

        ('Platinum 950', 'Pt', 95.000),
        ('Platinum 950', 'Ir', 5.000),

        ('Yellow Brass', 'Cu', 67.000),
        ('Yellow Brass', 'Zn', 33.000),

        ('Red Brass', 'Cu', 85.000),
        ('Red Brass', 'Zn', 15.000),

        ('Naval Brass', 'Cu', 60.000),
        ('Naval Brass', 'Zn', 39.000),
        ('Naval Brass', 'Sn', 1.000),

        ('Leaded Free-Cutting Brass', 'Cu', 61.500),
        ('Leaded Free-Cutting Brass', 'Zn', 35.500),
        ('Leaded Free-Cutting Brass', 'Pb', 3.000),

        ('Gilding Metal', 'Cu', 95.000),
        ('Gilding Metal', 'Zn', 5.000),

        ('Tin Bronze', 'Cu', 90.000),
        ('Tin Bronze', 'Sn', 10.000),

        ('Phosphor Bronze', 'Cu', 94.800),
        ('Phosphor Bronze', 'Sn', 5.000),
        ('Phosphor Bronze', 'P', 0.200),

        ('Aluminum Bronze', 'Cu', 90.000),
        ('Aluminum Bronze', 'Al', 10.000),

        ('Silicon Bronze', 'Cu', 96.000),
        ('Silicon Bronze', 'Si', 3.000),
        ('Silicon Bronze', 'Mn', 1.000),

        ('Manganese Bronze', 'Cu', 60.000),
        ('Manganese Bronze', 'Zn', 38.000),
        ('Manganese Bronze', 'Mn', 2.000),

        ('Leaded Bronze', 'Cu', 80.000),
        ('Leaded Bronze', 'Sn', 10.000),
        ('Leaded Bronze', 'Pb', 10.000),

        ('Bell Metal', 'Cu', 78.000),
        ('Bell Metal', 'Sn', 22.000),

        ('Traditional Lead Pewter', 'Sn', 70.000),
        ('Traditional Lead Pewter', 'Pb', 30.000),

        ('Lead-Free Pewter', 'Sn', 92.000),
        ('Lead-Free Pewter', 'Sb', 6.000),
        ('Lead-Free Pewter', 'Cu', 2.000),

        ('Aluminum 3003', 'Al', 98.600),
        ('Aluminum 3003', 'Mn', 1.200),
        ('Aluminum 3003', 'Cu', 0.200),

        ('Aluminum 5052', 'Al', 97.250),
        ('Aluminum 5052', 'Mg', 2.500),
        ('Aluminum 5052', 'Cr', 0.250),

        ('Aluminum 6061', 'Al', 97.900),
        ('Aluminum 6061', 'Mg', 1.000),
        ('Aluminum 6061', 'Si', 0.600),
        ('Aluminum 6061', 'Cu', 0.300),
        ('Aluminum 6061', 'Cr', 0.200),

        ('Aluminum 7075', 'Al', 90.000),
        ('Aluminum 7075', 'Zn', 5.600),
        ('Aluminum 7075', 'Mg', 2.500),
        ('Aluminum 7075', 'Cu', 1.600),
        ('Aluminum 7075', 'Cr', 0.300),

        ('Aluminum 2024', 'Al', 93.500),
        ('Aluminum 2024', 'Cu', 4.400),
        ('Aluminum 2024', 'Mg', 1.500),
        ('Aluminum 2024', 'Mn', 0.600),

        ('A356 Cast Aluminum', 'Al', 92.500),
        ('A356 Cast Aluminum', 'Si', 7.000),
        ('A356 Cast Aluminum', 'Mg', 0.500)
)
INSERT INTO alloy_elements (alloy_id, atomic_number, percent_of_alloy)
SELECT
    a.alloy_id,
    e.atomic_number,
    d.pct
FROM alloy_component_data d
INNER JOIN alloys a ON a.name = d.alloy_name
INNER JOIN elements e ON e.symbol = d.element_symbol
ON CONFLICT (alloy_id, atomic_number)
DO UPDATE SET percent_of_alloy = EXCLUDED.percent_of_alloy;

-- Common precious metal coins.
-- Uses alloy names already seeded above.
INSERT INTO coins (
    name,
    country,
    mint,
    year_introduced,
    alloy_id,
    gross_weight_g,
    face_value,
    face_value_currency_code
)
SELECT
    v.name,
    v.country,
    v.mint,
    v.year_introduced,
    a.alloy_id,
    v.gross_weight_g,
    v.face_value,
    v.face_value_currency_code
FROM (
    VALUES
        ('American Gold Eagle (1 oz)', 'United States', 'United States Mint', 1986, '22K Gold Coin Alloy', 33.9305, 50.00, 'USD'),
        ('Morgan Silver Dollar', 'United States', 'United States Mint', 1878, 'Coin Silver', 26.7300, 1.00, 'USD'),
        ('Peace Silver Dollar', 'United States', 'United States Mint', 1921, 'Coin Silver', 26.7300, 1.00, 'USD'),
        ('Franklin Half Dollar', 'United States', 'United States Mint', 1948, 'Coin Silver', 12.5000, 0.50, 'USD'),
        ('Krugerrand (1 oz)', 'South Africa', 'South African Mint', 1967, '22K Gold Coin Alloy', 33.9300, NULL, 'ZAR'),
        ('Gold Britannia (1 oz)', 'United Kingdom', 'The Royal Mint', 1987, '22K Gold Coin Alloy', 34.0500, 100.00, 'GBP'),
        ('Gold Maple Leaf (1 oz)', 'Canada', 'Royal Canadian Mint', 1979, 'Fine Gold 24K', 31.1035, 50.00, 'CAD')
) AS v(
    name,
    country,
    mint,
    year_introduced,
    alloy_name,
    gross_weight_g,
    face_value,
    face_value_currency_code
)
INNER JOIN alloys a ON a.name = v.alloy_name;
