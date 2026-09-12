-- Active: 1784643190439@@172.17.43.146@5432@metals@public
-- Metals database schema
-- Uses atomic_number as the natural primary key for elements.

DROP TABLE IF EXISTS user_roles;
DROP TABLE IF EXISTS roles;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS alloy_uses;
DROP TABLE IF EXISTS alloy_elements;
DROP TABLE IF EXISTS mint_product_components;
DROP TABLE IF EXISTS coins;
DROP TABLE IF EXISTS mint_products;
DROP TABLE IF EXISTS alloys;
DROP TABLE IF EXISTS elements;
 
CREATE TABLE elements (

    atomic_number SMALLINT PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    symbol CHAR(3) NOT NULL UNIQUE,
    melting_point_f NUMERIC(8,2),
    boiling_point_f NUMERIC(8,2),
    color VARCHAR(50),
    density NUMERIC(10,6),
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
    -- Classified by base metal: the element with the largest mass fraction.
    -- That rule is objective, so every alloy lands in exactly one family and
    -- nobody has to argue about it. What an alloy is USED for is a separate
    -- question with many answers per alloy, which is why it lives in
    -- alloy_uses rather than in a second column here.
    alloy_family VARCHAR(40) NOT NULL,
    -- The single metal this alloy is mostly made of - finer than alloy_family,
    -- which collapses gold, silver, platinum and palladium into PRECIOUS. This
    -- is what "a gold coin" or "a brass token" actually means, and coins read it
    -- through their alloy rather than storing their own copy.
    --
    -- Nullable here only because it is DERIVED: the seed fills it from the
    -- majority element in alloy_elements once compositions are loaded, then sets
    -- NOT NULL. Computing it beats typing it 75 times - there is no opportunity
    -- for the column and the composition to disagree.
    primary_metal VARCHAR(20),
    description TEXT,

    CONSTRAINT chk_alloy_primary_metal CHECK (primary_metal IN (
        'ALUMINUM',
        'COPPER',
        'GOLD',
        'IRON',
        'MAGNESIUM',
        'NICKEL',
        'PALLADIUM',
        'PLATINUM',
        'SILVER',
        'TIN',
        'TITANIUM',
        'ZINC'
    )),

    CONSTRAINT chk_alloy_family CHECK (alloy_family IN (
        'PRECIOUS',
        'COPPER',
        'ALUMINUM',
        'FERROUS',
        'NICKEL',
        'TITANIUM',
        'TIN',
        'ZINC',
        'MAGNESIUM'
    ))
);

CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(100) NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE roles (
    role_id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE user_roles (
    user_id INTEGER NOT NULL,
    role_id INTEGER NOT NULL,

    CONSTRAINT pk_user_roles PRIMARY KEY (user_id, role_id),

    CONSTRAINT fk_user_roles_user
        FOREIGN KEY (user_id)
        REFERENCES users (user_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_user_roles_role
        FOREIGN KEY (role_id)
        REFERENCES roles (role_id)
        ON DELETE RESTRICT
);

-- Anything struck or pressed from metal: coins, rounds, bars, ingots, medals,
-- tokens, and gold-foil notes. This is the supertype; what every one of them has
-- in common is a metal composition and a weight.
CREATE TABLE mint_products (
    mint_product_id SERIAL PRIMARY KEY,
    -- Unique so the seeds can upsert by name instead of inserting blindly, the
    -- same way alloys does. Without it, re-running a seed quietly doubles the
    -- catalog.
    name VARCHAR(120) NOT NULL UNIQUE,
    product_type VARCHAR(20) NOT NULL,
    -- A sovereign state for coins, a private mint for rounds and bars.
    issuer VARCHAR(80),
    mint VARCHAR(120),
    year_introduced SMALLINT,
    -- Everything the piece weighs, including any non-metal carrier.
    gross_weight_g NUMERIC(10,4),
    -- The actual metal in it. Usually gross_weight_g x fineness, but NOT for a
    -- goldback, where most of the weight is polymer and the gold is a thin foil
    -- layer - so it is recorded rather than derived.
    fine_metal_weight_g NUMERIC(10,4),
    -- The predominant alloy by weight. Multi-layer pieces list their layers in
    -- mint_product_components; this still points at the one that dominates.
    alloy_id INTEGER NOT NULL,

    CONSTRAINT fk_mint_products_alloy
        FOREIGN KEY (alloy_id)
        REFERENCES alloys (alloy_id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_mint_products_type CHECK (product_type IN (
        'COIN',
        'ROUND',
        'BAR',
        'INGOT',
        'MEDAL',
        'TOKEN',
        'NOTE'
    )),

    -- Widened from the original 500-3000: a Roman denarius predates 500 AD, and
    -- SMALLINT holds negative years for BC dates without complaint.
    CONSTRAINT chk_mint_products_year
        CHECK (year_introduced IS NULL OR year_introduced BETWEEN -3000 AND 3000),

    CONSTRAINT chk_mint_products_weights
        CHECK (fine_metal_weight_g IS NULL
               OR gross_weight_g IS NULL
               OR fine_metal_weight_g <= gross_weight_g),

    -- Redundant on its own - mint_product_id is already unique - but required so
    -- the coins subtype below can point a composite foreign key at it.
    CONSTRAINT uq_mint_products_type UNIQUE (mint_product_id, product_type)
);

-- The coin subtype: the things that are legal tender. Its existence is what says
-- "this is money", which is why there is no is_coin flag anywhere.
CREATE TABLE coins (
    -- Primary key and foreign key at once. That pairing is what makes this 1:1 -
    -- a product can have at most one coins row, and none at all if it is a bar.
    mint_product_id INTEGER PRIMARY KEY,
    -- Carried so the composite foreign key below can check it. Pinned to 'COIN'.
    product_type VARCHAR(20) NOT NULL DEFAULT 'COIN',
    -- Nullable for one real reason: a Krugerrand is legal tender with no
    -- denomination printed on it - its value is the gold price. That is a fact
    -- about the coin, not missing data.
    face_value NUMERIC(12,2),
    -- VARCHAR, not CHAR(3). Most codes here are three-letter ISO 4217 ones, but a
    -- historic abbreviation can be shorter - 'Kr' for the Austro-Hungarian krone,
    -- which ended in 1924 and so never received an ISO code. CHAR(3) would blank-pad
    -- that to 'Kr ': it compares equal to 'Kr' in SQL, and length() even reports 2,
    -- but the padding is real and shows up the moment the value leaves the database
    -- - to_json gives "Kr ", so the API would ship a trailing space and a strict
    -- equality check in the browser would fail on it.
    face_value_currency_code VARCHAR(3) NOT NULL,
    is_legal_tender BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT chk_coins_product_type CHECK (product_type = 'COIN'),

    -- 'XXX' is ISO 4217 for "no currency involved", so a face_value beside it
    -- would be a quantity of nothing - "1 XXX" reads as broken data, because it
    -- is. A ducat or a real has a denomination that simply has no ISO code, and
    -- the honest way to say that is a NULL amount.
    CONSTRAINT chk_coins_no_value_without_currency
        CHECK (face_value_currency_code <> 'XXX' OR face_value IS NULL),

    -- Points at the UNIQUE above, so a coins row can only ever attach to a
    -- product whose type is COIN. Changing that product to a BAR while this row
    -- exists is refused by the database - no trigger needed.
    CONSTRAINT fk_coins_mint_product
        FOREIGN KEY (mint_product_id, product_type)
        REFERENCES mint_products (mint_product_id, product_type)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

-- How a multi-layer piece is actually built: a clad quarter, a plated cent, a
-- bimetallic 2 euro. Solid pieces have no rows here at all - their alloy_id says
-- everything there is to say.
CREATE TABLE mint_product_components (
    mint_product_id INTEGER NOT NULL,
    alloy_id INTEGER NOT NULL,
    component_role VARCHAR(20) NOT NULL,
    -- Left NULL where the split between layers is not something we can state
    -- accurately. Better an honest gap than an invented number.
    percent_of_weight NUMERIC(6,3),

    CONSTRAINT pk_mint_product_components
        PRIMARY KEY (mint_product_id, alloy_id, component_role),

    CONSTRAINT fk_mint_product_components_product
        FOREIGN KEY (mint_product_id)
        REFERENCES mint_products (mint_product_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_mint_product_components_alloy
        FOREIGN KEY (alloy_id)
        REFERENCES alloys (alloy_id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_mint_product_component_role CHECK (component_role IN (
        'CORE',
        'CLADDING',
        'PLATING',
        'RING',
        'CENTER',
        'LEAF'
    )),

    CONSTRAINT chk_mint_product_component_percent
        CHECK (percent_of_weight IS NULL
               OR (percent_of_weight > 0 AND percent_of_weight <= 100))
);

CREATE INDEX idx_mint_products_alloy_id ON mint_products (alloy_id);
CREATE INDEX idx_mint_products_product_type ON mint_products (product_type);
CREATE INDEX idx_mint_product_components_alloy_id ON mint_product_components (alloy_id);

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

-- What each alloy is used for. Many-to-many on purpose: 6061 aluminum is
-- structural AND marine AND tooling, and forcing one label would make the
-- filter lie. Same shape as user_roles - a composite primary key over two
-- columns, which by itself stops the same use being attached twice.
CREATE TABLE alloy_uses (
    alloy_id SMALLINT NOT NULL,
    use_code VARCHAR(40) NOT NULL,

    CONSTRAINT pk_alloy_uses PRIMARY KEY (alloy_id, use_code),

    CONSTRAINT fk_alloy_uses_alloy
        FOREIGN KEY (alloy_id)
        REFERENCES alloys (alloy_id)
        ON DELETE CASCADE,

    CONSTRAINT chk_alloy_use_code CHECK (use_code IN (
        'AEROSPACE',
        'BEARING',
        'BULLION',
        'COINAGE',
        'COOKWARE',
        'DECORATIVE',
        'ELECTRICAL',
        'FASTENERS',
        'HIGH_TEMPERATURE',
        'INSTRUMENTATION',
        'JEWELRY',
        'MARINE',
        'MEDICAL',
        'MUSICAL',
        'SOLDERING',
        'STRUCTURAL',
        'TOOLING'
    ))
);

CREATE INDEX idx_alloy_uses_use_code ON alloy_uses (use_code);

-- seed data
INSERT INTO roles (name)
VALUES
    ('Customer'),
    ('Admin')
ON CONFLICT (name) DO NOTHING;

-- Development seed accounts. Both accounts use the password: password.
-- Passwords are represented below only by Argon2id hashes.
INSERT INTO users (username, password_hash)
VALUES
    ('admin', '$argon2id$v=19$m=65536,t=3,p=4$MCCFN8vfa3G9QWaCg1phwA$ypbN2kCHWoN1fELZJK6CYqxKvby4ObdJ4Etvd/uDcI8'),
    ('customer', '$argon2id$v=19$m=65536,t=3,p=4$RRkSYeL0kMb3KPUl9xzEEw$tN6o9Dgv8qhhrJpEPmh2Fj+oHeNb5ezBjpH3ZQJ1gI4')
ON CONFLICT (username) DO NOTHING;

INSERT INTO user_roles (user_id, role_id)
SELECT u.user_id, r.role_id
FROM (
    VALUES
        ('admin', 'Admin'),
        ('customer', 'Customer')
) AS assignments(username, role_name)
INNER JOIN users u ON u.username = assignments.username
INNER JOIN roles r ON r.name = assignments.role_name
ON CONFLICT (user_id, role_id) DO NOTHING;

-- Full periodic-table seed. Physical values are sourced from PubChem and stored in Fahrenheit and g/cm³.
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
    (1, 'Hydrogen', 'H', -434.81, -423.17, 'colorless', 0.00009, 'NONMETAL', 'GAS', FALSE, FALSE, 'fuel cells and chemicals'),
    (2, 'Helium', 'He', -457.96, -452.07, 'colorless', 0.000179, 'NOBLE_GAS', 'GAS', FALSE, FALSE, 'cryogenics and balloons'),
    (3, 'Lithium', 'Li', 356.9, 2447.33, 'silvery', 0.534, 'ALKALI_METAL', 'SOLID', FALSE, FALSE, 'batteries'),
    (4, 'Beryllium', 'Be', 2348.33, 4479.53, 'silvery', 1.85, 'ALKALINE_EARTH_METAL', 'SOLID', TRUE, FALSE, 'aerospace alloys'),
    (5, 'Boron', 'B', 3766.73, 7231.73, 'dark brown', 2.37, 'METALLOID', 'SOLID', FALSE, FALSE, 'glass and semiconductors'),
    (6, 'Carbon', 'C', 6421.73, 6916.73, 'black and colorless', 2.267, 'NONMETAL', 'SOLID', FALSE, FALSE, 'electrodes and advanced materials'),
    (7, 'Nitrogen', 'N', -346, -320.42, 'colorless', 0.001251, 'NONMETAL', 'GAS', FALSE, FALSE, 'fertilizer and chemicals'),
    (8, 'Oxygen', 'O', -361.82, -297.31, 'colorless', 0.001429, 'NONMETAL', 'GAS', FALSE, FALSE, 'medical oxygen and steelmaking'),
    (9, 'Fluorine', 'F', -363.32, -306.62, 'pale yellow', 0.001696, 'HALOGEN', 'GAS', TRUE, FALSE, 'fluorochemicals'),
    (10, 'Neon', 'Ne', -415.46, -410.94, 'colorless', 0.0009, 'NOBLE_GAS', 'GAS', FALSE, FALSE, 'lighting'),
    (11, 'Sodium', 'Na', 208.04, 1621.13, 'silvery', 0.97, 'ALKALI_METAL', 'SOLID', FALSE, FALSE, 'salt production'),
    (12, 'Magnesium', 'Mg', 1201.73, 1993.73, 'silvery', 1.74, 'ALKALINE_EARTH_METAL', 'SOLID', FALSE, FALSE, 'alloys'),
    (13, 'Aluminum', 'Al', 1220.52, 4565.93, 'silvery', 2.7, 'POST_TRANSITION_METAL', 'SOLID', FALSE, FALSE, 'cans and aerospace'),
    (14, 'Silicon', 'Si', 2576.93, 5908.73, 'dark gray', 2.3296, 'METALLOID', 'SOLID', FALSE, FALSE, 'electronics'),
    (15, 'Phosphorus', 'P', 111.47, 536.9, 'varies', 1.82, 'NONMETAL', 'SOLID', FALSE, FALSE, 'fertilizer and chemicals'),
    (16, 'Sulfur', 'S', 239.38, 832.28, 'yellow', 2.067, 'NONMETAL', 'SOLID', FALSE, FALSE, 'fertilizer and chemicals'),
    (17, 'Chlorine', 'Cl', -150.7, -29.27, 'yellow-green', 0.003214, 'HALOGEN', 'GAS', TRUE, FALSE, 'water treatment'),
    (18, 'Argon', 'Ar', -308.83, -302.53, 'colorless', 0.001784, 'NOBLE_GAS', 'GAS', FALSE, FALSE, 'shielding gas'),
    (19, 'Potassium', 'K', 146.08, 1397.93, 'silvery', 0.89, 'ALKALI_METAL', 'SOLID', FALSE, FALSE, 'fertilizer'),
    (20, 'Calcium', 'Ca', 1547.33, 2702.93, 'silvery', 1.54, 'ALKALINE_EARTH_METAL', 'SOLID', FALSE, FALSE, 'cement and alloys'),
    (21, 'Scandium', 'Sc', 2805.53, 5136.53, 'silvery', 2.99, 'TRANSITION_METAL', 'SOLID', FALSE, FALSE, 'alloys and industry'),
    (22, 'Titanium', 'Ti', 3034.13, 5948.33, 'silvery', 4.5, 'TRANSITION_METAL', 'SOLID', FALSE, FALSE, 'alloys and industry'),
    (23, 'Vanadium', 'V', 3469.73, 6164.33, 'silvery', 6, 'TRANSITION_METAL', 'SOLID', FALSE, FALSE, 'alloys and industry'),
    (24, 'Chromium', 'Cr', 3464.33, 4839.53, 'steel gray', 7.15, 'TRANSITION_METAL', 'SOLID', FALSE, TRUE, 'plating'),
    (25, 'Manganese', 'Mn', 2274.53, 3741.53, 'silvery', 7.3, 'TRANSITION_METAL', 'SOLID', FALSE, FALSE, 'steel and alloying'),
    (26, 'Iron', 'Fe', 2800.13, 5181.53, 'silvery', 7.874, 'TRANSITION_METAL', 'SOLID', FALSE, TRUE, 'construction and steel'),
    (27, 'Cobalt', 'Co', 2722.73, 5300.33, 'bluish silver', 8.86, 'TRANSITION_METAL', 'SOLID', FALSE, TRUE, 'magnets'),
    (28, 'Nickel', 'Ni', 2650.73, 5275.13, 'silvery', 8.912, 'TRANSITION_METAL', 'SOLID', FALSE, TRUE, 'alloys'),
    (29, 'Copper', 'Cu', 1984.32, 4643.33, 'reddish', 8.933, 'TRANSITION_METAL', 'SOLID', FALSE, FALSE, 'wiring'),
    (30, 'Zinc', 'Zn', 787.15, 1664.33, 'bluish silver', 7.134, 'TRANSITION_METAL', 'SOLID', FALSE, FALSE, 'galvanizing'),
    (31, 'Gallium', 'Ga', 85.57, 3998.93, 'silvery', 5.91, 'POST_TRANSITION_METAL', 'SOLID', FALSE, FALSE, 'electronics'),
    (32, 'Germanium', 'Ge', 1720.85, 5131.13, 'grayish white', 5.323, 'METALLOID', 'SOLID', FALSE, FALSE, 'semiconductors'),
    (33, 'Arsenic', 'As', NULL, 1136.93, 'steel gray', 5.776, 'METALLOID', 'SOLID', TRUE, FALSE, 'semiconductors'),
    (34, 'Selenium', 'Se', 428.9, 1264.73, 'deep red', 4.809, 'NONMETAL', 'SOLID', TRUE, FALSE, 'glass and electronics'),
    (35, 'Bromine', 'Br', 19.04, 137.84, 'reddish-brown', 3.11, 'HALOGEN', 'LIQUID', TRUE, FALSE, 'flame retardants'),
    (36, 'Krypton', 'Kr', -251.25, -243.8, 'colorless', 0.003733, 'NOBLE_GAS', 'GAS', FALSE, FALSE, 'lighting'),
    (37, 'Rubidium', 'Rb', 102.76, 1270.13, 'silvery with gold cast', 1.53, 'ALKALI_METAL', 'SOLID', FALSE, FALSE, 'research'),
    (38, 'Strontium', 'Sr', 1430.33, 2519.33, 'silvery', 2.64, 'ALKALINE_EARTH_METAL', 'SOLID', FALSE, FALSE, 'ceramics'),
    (39, 'Yttrium', 'Y', 2771.33, 6052.73, 'silvery', 4.47, 'TRANSITION_METAL', 'SOLID', FALSE, FALSE, 'phosphors'),
    (40, 'Zirconium', 'Zr', 3370.73, 7967.93, 'silvery', 6.52, 'TRANSITION_METAL', 'SOLID', FALSE, FALSE, 'nuclear materials'),
    (41, 'Niobium', 'Nb', 4490.33, 8570.93, 'silvery', 8.57, 'TRANSITION_METAL', 'SOLID', FALSE, FALSE, 'superconducting alloys'),
    (42, 'Molybdenum', 'Mo', 4753.13, 8381.93, 'silvery', 10.2, 'TRANSITION_METAL', 'SOLID', FALSE, FALSE, 'steel alloys'),
    (43, 'Technetium', 'Tc', 3914.33, 7708.73, 'silvery', 11, 'TRANSITION_METAL', 'SOLID', FALSE, FALSE, 'medical imaging'),
    (44, 'Ruthenium', 'Ru', 4232.93, 7501.73, 'silvery', 12.1, 'TRANSITION_METAL', 'SOLID', FALSE, FALSE, 'catalysts'),
    (45, 'Rhodium', 'Rh', 3566.93, 6682.73, 'silvery', 12.4, 'TRANSITION_METAL', 'SOLID', FALSE, FALSE, 'catalysts'),
    (46, 'Palladium', 'Pd', 2830.82, 5365.13, 'silvery', 12, 'TRANSITION_METAL', 'SOLID', FALSE, FALSE, 'catalysts'),
    (47, 'Silver', 'Ag', 1763.2, 3923.33, 'silvery', 10.501, 'TRANSITION_METAL', 'SOLID', FALSE, FALSE, 'jewelry'),
    (48, 'Cadmium', 'Cd', 609.93, 1412.33, 'silvery', 8.69, 'TRANSITION_METAL', 'SOLID', TRUE, FALSE, 'batteries'),
    (49, 'Indium', 'In', 313.88, 3761.33, 'silvery', 7.31, 'POST_TRANSITION_METAL', 'SOLID', FALSE, FALSE, 'touchscreens'),
    (50, 'Tin', 'Sn', 449.47, 4715.33, 'silvery', 7.287, 'POST_TRANSITION_METAL', 'SOLID', FALSE, FALSE, 'solder'),
    (51, 'Antimony', 'Sb', 1167.13, 2888.33, 'silvery', 6.685, 'METALLOID', 'SOLID', TRUE, FALSE, 'flame retardants'),
    (52, 'Tellurium', 'Te', 841.12, 1810.13, 'silvery', 6.232, 'METALLOID', 'SOLID', TRUE, FALSE, 'solar cells'),
    (53, 'Iodine', 'I', 236.66, 363.92, 'violet-black', 4.93, 'HALOGEN', 'SOLID', TRUE, FALSE, 'antiseptics and imaging'),
    (54, 'Xenon', 'Xe', -169.22, -162.62, 'colorless', 0.005887, 'NOBLE_GAS', 'GAS', FALSE, FALSE, 'lighting'),
    (55, 'Cesium', 'Cs', 83.19, 1239.53, 'pale gold', 1.93, 'ALKALI_METAL', 'SOLID', FALSE, FALSE, 'atomic clocks'),
    (56, 'Barium', 'Ba', 1340.33, 3446.33, 'silvery', 3.62, 'ALKALINE_EARTH_METAL', 'SOLID', FALSE, FALSE, 'medical imaging'),
    (57, 'Lanthanum', 'La', 1684.13, 6266.93, 'silvery', 6.15, 'LANTHANIDE', 'SOLID', FALSE, FALSE, 'optics and catalysts'),
    (58, 'Cerium', 'Ce', 1468.13, 6194.93, 'silvery', 6.77, 'LANTHANIDE', 'SOLID', FALSE, FALSE, 'catalysts and polishing'),
    (59, 'Praseodymium', 'Pr', 1707.53, 6367.73, 'silvery', 6.77, 'LANTHANIDE', 'SOLID', FALSE, FALSE, 'magnets and glass'),
    (60, 'Neodymium', 'Nd', 1869.53, 5564.93, 'silvery', 7.01, 'LANTHANIDE', 'SOLID', FALSE, FALSE, 'magnets'),
    (61, 'Promethium', 'Pm', 1907.33, 5431.73, 'silvery', 7.26, 'LANTHANIDE', 'SOLID', FALSE, FALSE, 'research'),
    (62, 'Samarium', 'Sm', 1964.93, 3260.93, 'silvery', 7.52, 'LANTHANIDE', 'SOLID', FALSE, FALSE, 'magnets'),
    (63, 'Europium', 'Eu', 1511.33, 2783.93, 'silvery', 5.24, 'LANTHANIDE', 'SOLID', FALSE, FALSE, 'phosphors'),
    (64, 'Gadolinium', 'Gd', 2395.13, 5923.13, 'silvery', 7.9, 'LANTHANIDE', 'SOLID', FALSE, TRUE, 'medical imaging'),
    (65, 'Terbium', 'Tb', 2472.53, 5845.73, 'silvery', 8.23, 'LANTHANIDE', 'SOLID', FALSE, FALSE, 'phosphors'),
    (66, 'Dysprosium', 'Dy', 2573.33, 4652.33, 'silvery', 8.55, 'LANTHANIDE', 'SOLID', FALSE, FALSE, 'magnets'),
    (67, 'Holmium', 'Ho', 2684.93, 4891.73, 'silvery', 8.8, 'LANTHANIDE', 'SOLID', FALSE, FALSE, 'lasers'),
    (68, 'Erbium', 'Er', 2783.93, 5194.13, 'silvery', 9.07, 'LANTHANIDE', 'SOLID', FALSE, FALSE, 'fiber optics'),
    (69, 'Thulium', 'Tm', 2812.73, 3541.73, 'silvery', 9.32, 'LANTHANIDE', 'SOLID', FALSE, FALSE, 'lasers'),
    (70, 'Ytterbium', 'Yb', 1505.93, 2184.53, 'silvery', 6.9, 'LANTHANIDE', 'SOLID', FALSE, FALSE, 'lasers'),
    (71, 'Lutetium', 'Lu', 3025.13, 6155.33, 'silvery', 9.84, 'LANTHANIDE', 'SOLID', FALSE, FALSE, 'catalysts'),
    (72, 'Hafnium', 'Hf', 4051.13, 8317.13, 'silvery', 13.3, 'TRANSITION_METAL', 'SOLID', FALSE, FALSE, 'nuclear control rods'),
    (73, 'Tantalum', 'Ta', 5462.33, 9856.13, 'silvery', 16.4, 'TRANSITION_METAL', 'SOLID', FALSE, FALSE, 'electronics'),
    (74, 'Tungsten', 'W', 6191.33, 10030.73, 'silvery', 19.3, 'TRANSITION_METAL', 'SOLID', FALSE, FALSE, 'filaments'),
    (75, 'Rhenium', 'Re', 5766.53, 10104.53, 'silvery', 20.8, 'TRANSITION_METAL', 'SOLID', FALSE, FALSE, 'superalloys'),
    (76, 'Osmium', 'Os', 5491.13, 9053.33, 'silvery', 22.57, 'TRANSITION_METAL', 'SOLID', FALSE, FALSE, 'alloys'),
    (77, 'Iridium', 'Ir', 4434.53, 8002.13, 'silvery', 22.42, 'TRANSITION_METAL', 'SOLID', FALSE, FALSE, 'platinum hardening additive'),
    (78, 'Platinum', 'Pt', 3215.12, 6916.73, 'silvery', 21.46, 'TRANSITION_METAL', 'SOLID', FALSE, FALSE, 'jewelry'),
    (79, 'Gold', 'Au', 1947.52, 5172.53, 'gold', 19.282, 'TRANSITION_METAL', 'SOLID', FALSE, FALSE, 'alloys and industry'),
    (80, 'Mercury', 'Hg', -37.89, 674.11, 'silvery', 13.5336, 'TRANSITION_METAL', 'LIQUID', TRUE, FALSE, 'scientific instruments'),
    (81, 'Thallium', 'Tl', 578.93, 2683.13, 'gray', 11.8, 'POST_TRANSITION_METAL', 'SOLID', TRUE, FALSE, 'electronics'),
    (82, 'Lead', 'Pb', 621.43, 3179.93, 'dull gray', 11.342, 'POST_TRANSITION_METAL', 'SOLID', TRUE, FALSE, 'batteries'),
    (83, 'Bismuth', 'Bi', 520.52, 2846.93, 'iridescent', 9.807, 'POST_TRANSITION_METAL', 'SOLID', FALSE, FALSE, 'alloys'),
    (84, 'Polonium', 'Po', 488.93, 1763.33, 'silvery', 9.32, 'METALLOID', 'SOLID', TRUE, FALSE, 'research'),
    (85, 'Astatine', 'At', 575.33, NULL, 'dark', 7, 'HALOGEN', 'SOLID', TRUE, FALSE, 'chemicals and research'),
    (86, 'Radon', 'Rn', -96.07, -79.06, 'colorless', 0.00973, 'NOBLE_GAS', 'GAS', TRUE, FALSE, 'lighting, cryogenics, and research'),
    (87, 'Francium', 'Fr', 80.33, NULL, 'silvery', NULL, 'ALKALI_METAL', 'SOLID', TRUE, FALSE, 'research and specialized applications'),
    (88, 'Radium', 'Ra', 1291.73, 2083.73, 'silvery', 5, 'ALKALINE_EARTH_METAL', 'SOLID', TRUE, FALSE, 'research'),
    (89, 'Actinium', 'Ac', 1923.53, 5788.13, 'silvery', 10.07, 'ACTINIDE', 'SOLID', TRUE, FALSE, 'research'),
    (90, 'Thorium', 'Th', 3181.73, 8650.13, 'silvery', 11.72, 'ACTINIDE', 'SOLID', TRUE, FALSE, 'nuclear science'),
    (91, 'Protactinium', 'Pa', 2861.33, NULL, 'silvery', 15.37, 'ACTINIDE', 'SOLID', TRUE, FALSE, 'research'),
    (92, 'Uranium', 'U', 2074.73, 7467.53, 'silvery', 18.95, 'ACTINIDE', 'SOLID', TRUE, FALSE, 'nuclear fuel'),
    (93, 'Neptunium', 'Np', 1190.93, 7055.33, 'silvery', 20.25, 'ACTINIDE', 'SOLID', TRUE, FALSE, 'research'),
    (94, 'Plutonium', 'Pu', 1183.73, 5842.13, 'silvery', 19.84, 'ACTINIDE', 'SOLID', TRUE, FALSE, 'nuclear science'),
    (95, 'Americium', 'Am', 2148.53, 3651.53, 'silvery', 13.69, 'ACTINIDE', 'SOLID', TRUE, FALSE, 'smoke detectors'),
    (96, 'Curium', 'Cm', 2452.73, 5660.33, 'silvery', 13.51, 'ACTINIDE', 'SOLID', TRUE, FALSE, 'research'),
    (97, 'Berkelium', 'Bk', 1921.73, NULL, 'silvery', 14, 'ACTINIDE', 'SOLID', TRUE, FALSE, 'research'),
    (98, 'Californium', 'Cf', 1651.73, NULL, 'silvery', NULL, 'ACTINIDE', 'SOLID', TRUE, FALSE, 'neutron sources'),
    (99, 'Einsteinium', 'Es', 1579.73, NULL, 'silvery', NULL, 'ACTINIDE', 'SOLID', TRUE, FALSE, 'research'),
    (100, 'Fermium', 'Fm', 2780.33, NULL, 'silvery', NULL, 'ACTINIDE', 'SOLID', TRUE, FALSE, 'research'),
    (101, 'Mendelevium', 'Md', 1520.33, NULL, 'silvery', NULL, 'ACTINIDE', 'SOLID', TRUE, FALSE, 'research'),
    (102, 'Nobelium', 'No', 1520.33, NULL, 'silvery', NULL, 'ACTINIDE', 'SOLID', TRUE, FALSE, 'research'),
    (103, 'Lawrencium', 'Lr', 2960.33, NULL, 'silvery', NULL, 'ACTINIDE', 'SOLID', TRUE, FALSE, 'research'),
    (104, 'Rutherfordium', 'Rf', NULL, NULL, 'silvery', NULL, 'TRANSITION_METAL', 'SOLID', TRUE, FALSE, 'alloys and industry'),
    (105, 'Dubnium', 'Db', NULL, NULL, 'silvery', NULL, 'TRANSITION_METAL', 'SOLID', TRUE, FALSE, 'alloys and industry'),
    (106, 'Seaborgium', 'Sg', NULL, NULL, 'silvery', NULL, 'TRANSITION_METAL', 'SOLID', TRUE, FALSE, 'alloys and industry'),
    (107, 'Bohrium', 'Bh', NULL, NULL, 'silvery', NULL, 'TRANSITION_METAL', 'SOLID', TRUE, FALSE, 'alloys and industry'),
    (108, 'Hassium', 'Hs', NULL, NULL, 'silvery', NULL, 'TRANSITION_METAL', 'SOLID', TRUE, FALSE, 'alloys and industry'),
    (109, 'Meitnerium', 'Mt', NULL, NULL, 'silvery', NULL, 'TRANSITION_METAL', 'SOLID', TRUE, FALSE, 'alloys and industry'),
    (110, 'Darmstadtium', 'Ds', NULL, NULL, 'silvery', NULL, 'TRANSITION_METAL', 'SOLID', TRUE, FALSE, 'alloys and industry'),
    (111, 'Roentgenium', 'Rg', NULL, NULL, 'silvery', NULL, 'TRANSITION_METAL', 'SOLID', TRUE, FALSE, 'alloys and industry'),
    (112, 'Copernicium', 'Cn', NULL, NULL, 'silvery', NULL, 'TRANSITION_METAL', 'SOLID', TRUE, FALSE, 'alloys and industry'),
    (113, 'Nihonium', 'Nh', NULL, NULL, 'silvery', NULL, 'POST_TRANSITION_METAL', 'SOLID', TRUE, FALSE, 'alloys and electronics'),
    (114, 'Flerovium', 'Fl', NULL, NULL, 'silvery', NULL, 'POST_TRANSITION_METAL', 'SOLID', TRUE, FALSE, 'alloys and electronics'),
    (115, 'Moscovium', 'Mc', NULL, NULL, 'silvery', NULL, 'POST_TRANSITION_METAL', 'SOLID', TRUE, FALSE, 'alloys and electronics'),
    (116, 'Livermorium', 'Lv', NULL, NULL, 'silvery', NULL, 'POST_TRANSITION_METAL', 'SOLID', TRUE, FALSE, 'alloys and electronics'),
    (117, 'Tennessine', 'Ts', NULL, NULL, 'varies', NULL, 'HALOGEN', 'SOLID', TRUE, FALSE, 'chemicals and research'),
    (118, 'Oganesson', 'Og', NULL, NULL, 'colorless', NULL, 'NOBLE_GAS', 'GAS', TRUE, FALSE, 'lighting, cryogenics, and research')
ON CONFLICT (atomic_number) DO UPDATE SET
    name = EXCLUDED.name,
    symbol = EXCLUDED.symbol,
    melting_point_f = EXCLUDED.melting_point_f,
    boiling_point_f = EXCLUDED.boiling_point_f,
    color = EXCLUDED.color,
    density = EXCLUDED.density,
    category = EXCLUDED.category,
    state_at_room_temp = EXCLUDED.state_at_room_temp,
    is_toxic = EXCLUDED.is_toxic,
    is_magnetic = EXCLUDED.is_magnetic,
    common_uses = EXCLUDED.common_uses;

-- Alloy master rows. alloy_family is the base metal by mass fraction, so a few
-- entries land somewhere their name does not suggest: Nickel Silver is COPPER
-- and contains no silver at all, Invar 36 is FERROUS despite being known as a
-- nickel alloy, and Shakudo is COPPER with only a few percent gold.
INSERT INTO alloys (name, color, alloy_family, description)
VALUES
    ('Fine Gold 24K', 'gold', 'PRECIOUS', 'High-purity investment gold for bullion and premium coins.'),
    ('22K Gold Coin Alloy', 'rich gold', 'PRECIOUS', 'Durable coin gold with added strength compared to 24K.'),
    ('18K Yellow Gold', 'yellow gold', 'PRECIOUS', 'Jewelry alloy balancing color and wear resistance.'),
    ('18K Rose Gold', 'rose gold', 'PRECIOUS', 'Jewelry alloy with higher copper content for warm red tone.'),
    ('18K White Gold (Palladium)', 'white gold', 'PRECIOUS', 'Nickel-free white gold variant used in fine jewelry.'),
    ('14K Yellow Gold', 'yellow gold', 'PRECIOUS', 'Hard-wearing everyday jewelry gold at 58.5 percent purity.'),
    ('10K Yellow Gold', 'pale gold', 'PRECIOUS', 'Budget jewelry gold with high durability and low gold content.'),
    ('Electrum', 'pale gold', 'PRECIOUS', 'Naturally occurring gold-silver alloy used in the earliest coinage.'),
    ('Sterling Silver', 'bright silver', 'PRECIOUS', 'Standard jewelry and silverware alloy.'),
    ('Coin Silver', 'silver', 'PRECIOUS', 'Traditional coinage silver composition.'),
    ('Britannia Silver', 'bright silver', 'PRECIOUS', 'Higher-purity silver standard for premium silver goods.'),
    ('Platinum 950', 'silvery white', 'PRECIOUS', 'Fine jewelry platinum alloy with improved hardness.'),
    ('Palladium 950', 'silvery white', 'PRECIOUS', 'Light, hypoallergenic white metal for wedding bands.'),
    ('Yellow Brass', 'yellow', 'COPPER', 'General-purpose brass for hardware, fittings, and decorative parts.'),
    ('Red Brass', 'reddish gold', 'COPPER', 'Corrosion-resistant brass for plumbing fittings and valves.'),
    ('Naval Brass', 'yellow-gold', 'COPPER', 'Brass designed for marine service and saltwater resistance.'),
    ('Leaded Free-Cutting Brass', 'yellow', 'COPPER', 'Machinable brass for precision turned components.'),
    ('Gilding Metal', 'reddish yellow', 'COPPER', 'Copper-rich brass used for cladding and decorative parts.'),
    ('Tin Bronze', 'bronze', 'COPPER', 'General bronze for castings, bushings, and decorative work.'),
    ('Phosphor Bronze', 'bronze', 'COPPER', 'Springy bronze for contacts, springs, and wear-resistant parts.'),
    ('Aluminum Bronze', 'golden bronze', 'COPPER', 'Strong corrosion-resistant bronze for marine and industrial parts.'),
    ('Silicon Bronze', 'bronze', 'COPPER', 'Corrosion-resistant bronze for fasteners and architectural hardware.'),
    ('Manganese Bronze', 'yellow bronze', 'COPPER', 'High-strength bronze family used for propellers and shafts.'),
    ('Leaded Bronze', 'bronze', 'COPPER', 'Bearing bronze with improved anti-friction behavior.'),
    ('Bell Metal', 'dark bronze', 'COPPER', 'Resonant bronze for bells and musical castings.'),
    ('Cupronickel 90/10', 'silvery', 'COPPER', 'Seawater-resistant copper-nickel for condenser and marine piping.'),
    ('Cupronickel 70/30', 'silvery', 'COPPER', 'Higher-nickel cupronickel for demanding marine heat exchangers.'),
    ('Nickel Silver', 'silvery', 'COPPER', 'Silver-looking copper alloy with no silver in it; flatware and instruments.'),
    ('Beryllium Copper', 'reddish gold', 'COPPER', 'Hardenable copper for springs, connectors, and non-sparking tools.'),
    ('Chromium Copper', 'reddish', 'COPPER', 'Strong, highly conductive copper for resistance welding electrodes.'),
    ('Shakudo', 'dark purple-brown', 'COPPER', 'Japanese copper alloy with a little gold that patinates to deep purple.'),
    ('Traditional Lead Pewter', 'dull silver', 'TIN', 'Historical pewter for decorative artifacts (not food-safe).'),
    ('Lead-Free Pewter', 'bright silver', 'TIN', 'Modern pewter for decorative and giftware applications.'),
    ('Sn63/Pb37 Eutectic Solder', 'dull silver', 'TIN', 'Classic electronics solder with a single sharp melting point.'),
    ('SAC305 Lead-Free Solder', 'dull silver', 'TIN', 'Tin-silver-copper solder that replaced leaded solder in electronics.'),
    ('Aluminum 3003', 'silver gray', 'ALUMINUM', 'Formable sheet alloy for cookware and general fabrication.'),
    ('Aluminum 5052', 'silver gray', 'ALUMINUM', 'Corrosion-resistant aluminum for marine and sheet applications.'),
    ('Aluminum 6061', 'silver gray', 'ALUMINUM', 'General-purpose structural aluminum for machining and fabrication.'),
    ('Aluminum 7075', 'silver gray', 'ALUMINUM', 'High-strength aluminum for aerospace and tooling.'),
    ('Aluminum 2024', 'silver gray', 'ALUMINUM', 'High-strength aluminum used in aircraft structures.'),
    ('A356 Cast Aluminum', 'silver gray', 'ALUMINUM', 'Cast aluminum alloy for wheels and complex cast parts.'),
    ('1018 Mild Steel', 'dark gray', 'FERROUS', 'Low-carbon workhorse steel for shafts, brackets, and weldments.'),
    ('1045 Medium Carbon Steel', 'dark gray', 'FERROUS', 'Medium-carbon steel for gears, axles, and heat-treated parts.'),
    ('4140 Chromoly Steel', 'dark gray', 'FERROUS', 'Tough alloy steel for tooling, shafts, and roll cages.'),
    ('304 Stainless Steel', 'bright silver', 'FERROUS', 'The common austenitic stainless for kitchens and architecture.'),
    ('316 Stainless Steel', 'bright silver', 'FERROUS', 'Molybdenum-bearing stainless with better chloride resistance.'),
    ('430 Stainless Steel', 'silver', 'FERROUS', 'Magnetic ferritic stainless for trim and appliance panels.'),
    ('17-4 PH Stainless Steel', 'silver', 'FERROUS', 'Precipitation-hardening stainless for high-strength shafts and valves.'),
    ('M2 High-Speed Steel', 'dark gray', 'FERROUS', 'Tool steel that keeps its edge hot; drills, taps, and milling cutters.'),
    ('Gray Cast Iron', 'dull gray', 'FERROUS', 'Graphite-flake iron for engine blocks, cookware, and machine bases.'),
    ('Ductile Cast Iron', 'dull gray', 'FERROUS', 'Magnesium-treated iron with spheroidal graphite and real toughness.'),
    ('Weathering Steel', 'rust brown', 'FERROUS', 'Corten-type steel that forms a stable rust layer instead of needing paint.'),
    ('Invar 36', 'silver gray', 'FERROUS', 'Iron-nickel alloy that barely expands when heated; precision instruments.'),
    ('Inconel 718', 'silver gray', 'NICKEL', 'Age-hardened superalloy for turbine discs and rocket hardware.'),
    ('Hastelloy C-276', 'silver gray', 'NICKEL', 'Nickel-molybdenum alloy for aggressive chemical service.'),
    ('Monel 400', 'silver gray', 'NICKEL', 'Nickel-copper alloy prized for seawater and acid resistance.'),
    ('Nichrome 80/20', 'silver gray', 'NICKEL', 'Resistance heating wire for toasters, kilns, and hot-wire cutters.'),
    ('Nitinol', 'silver gray', 'NICKEL', 'Shape-memory alloy that springs back to form when warmed.'),
    ('Ti-6Al-4V', 'dark silver', 'TITANIUM', 'The workhorse titanium alloy: aerospace structure and implants.'),
    ('CP Titanium Grade 2', 'dark silver', 'TITANIUM', 'Commercially pure titanium for chemical vessels and medical parts.'),
    ('Zamak 3', 'silver gray', 'ZINC', 'The default zinc die-casting alloy for housings and hardware.'),
    ('Zamak 5', 'silver gray', 'ZINC', 'Copper-bearing zinc die-cast alloy with higher strength.'),
    ('AZ91D Magnesium', 'dull silver', 'MAGNESIUM', 'Common magnesium die-casting alloy for light housings.'),
    ('AZ31B Magnesium', 'dull silver', 'MAGNESIUM', 'Wrought magnesium sheet and extrusion alloy.'),
    -- Coinage and bullion alloys. Circulating coins are mostly base metal, and
    -- clad coins need the plating and the core as separate alloys.
    ('Commercial Pure Copper', 'reddish', 'COPPER', 'Unalloyed copper used for coin cores, plating, and bullion rounds.'),
    ('Cupronickel 75/25', 'silvery', 'COPPER', 'The US five cent alloy, also the cladding on US dimes and quarters.'),
    ('Nickel Brass', 'pale gold', 'COPPER', 'Hard brass for circulating coins such as the euro ring and old UK threepence.'),
    ('Nordic Gold', 'golden', 'COPPER', 'Tarnish-resistant gold-colored coinage alloy used for euro cent coins.'),
    ('Manganese Brass', 'golden', 'COPPER', 'Golden dollar cladding, chosen to match an older coin on vending sensors.'),
    ('Coinage Zinc Core', 'bluish silver', 'ZINC', 'The zinc core inside a modern copper-plated US cent.'),
    ('Coinage Steel Core', 'dark gray', 'FERROUS', 'Low-carbon steel core used under plating in low-value circulating coins.'),
    ('Coinage Aluminum', 'silver gray', 'ALUMINUM', 'Near-pure aluminum for very low denomination circulating coins.'),
    ('Fine Silver 999', 'bright silver', 'PRECIOUS', 'Investment-grade silver for rounds and bars.'),
    ('Fine Platinum 9995', 'silvery white', 'PRECIOUS', 'Investment-grade platinum for bars and coins.'),
    ('Fine Palladium 9995', 'silvery white', 'PRECIOUS', 'Investment-grade palladium for bars and coins.'),
    -- Three more coinage standards, each added because a real piece needed it and
    -- nothing above was close enough. Rounding a coin to the nearest alloy already
    -- in the table would quietly misstate how much metal is in it.
    ('Fine Silver 9999', 'bright silver', 'PRECIOUS', 'Four-nines silver, the Perth Mint standard for its bullion coins.'),
    ('Coin Gold 900', 'rich gold', 'PRECIOUS', 'The 90 percent standard behind most pre-1933 European and US gold coins.'),
    ('Ducat Gold 986', 'rich gold', 'PRECIOUS', 'The 98.6 percent ducat standard, still struck for Austrian restrikes.')
ON CONFLICT (name) DO UPDATE SET
    color = EXCLUDED.color,
    alloy_family = EXCLUDED.alloy_family,
    description = EXCLUDED.description;

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
        ('A356 Cast Aluminum', 'Mg', 0.500),

        -- Precious additions.
        ('14K Yellow Gold', 'Au', 58.500),
        ('14K Yellow Gold', 'Ag', 25.000),
        ('14K Yellow Gold', 'Cu', 16.500),
        ('10K Yellow Gold', 'Au', 41.700),
        ('10K Yellow Gold', 'Ag', 20.000),
        ('10K Yellow Gold', 'Cu', 38.300),
        ('Electrum', 'Au', 55.000),
        ('Electrum', 'Ag', 44.000),
        ('Electrum', 'Cu', 1.000),
        ('Palladium 950', 'Pd', 95.000),
        ('Palladium 950', 'Ru', 5.000),

        -- Copper additions. Nickel Silver is the teaching case: no silver.
        ('Cupronickel 90/10', 'Cu', 88.600),
        ('Cupronickel 90/10', 'Ni', 10.000),
        ('Cupronickel 90/10', 'Fe', 1.400),
        ('Cupronickel 70/30', 'Cu', 69.500),
        ('Cupronickel 70/30', 'Ni', 30.000),
        ('Cupronickel 70/30', 'Mn', 0.500),
        ('Nickel Silver', 'Cu', 60.000),
        ('Nickel Silver', 'Zn', 20.000),
        ('Nickel Silver', 'Ni', 20.000),
        ('Beryllium Copper', 'Cu', 97.900),
        ('Beryllium Copper', 'Be', 1.900),
        ('Beryllium Copper', 'Co', 0.200),
        ('Chromium Copper', 'Cu', 99.100),
        ('Chromium Copper', 'Cr', 0.900),
        ('Shakudo', 'Cu', 96.000),
        ('Shakudo', 'Au', 4.000),

        -- Solders.
        ('Sn63/Pb37 Eutectic Solder', 'Sn', 63.000),
        ('Sn63/Pb37 Eutectic Solder', 'Pb', 37.000),
        ('SAC305 Lead-Free Solder', 'Sn', 96.500),
        ('SAC305 Lead-Free Solder', 'Ag', 3.000),
        ('SAC305 Lead-Free Solder', 'Cu', 0.500),

        -- Steels and cast irons. Only possible now that Fe, C and V are seeded.
        ('1018 Mild Steel', 'Fe', 99.030),
        ('1018 Mild Steel', 'C', 0.180),
        ('1018 Mild Steel', 'Mn', 0.750),
        ('1018 Mild Steel', 'P', 0.020),
        ('1018 Mild Steel', 'S', 0.020),
        ('1045 Medium Carbon Steel', 'Fe', 98.760),
        ('1045 Medium Carbon Steel', 'C', 0.450),
        ('1045 Medium Carbon Steel', 'Mn', 0.750),
        ('1045 Medium Carbon Steel', 'P', 0.020),
        ('1045 Medium Carbon Steel', 'S', 0.020),
        ('4140 Chromoly Steel', 'Fe', 97.320),
        ('4140 Chromoly Steel', 'C', 0.400),
        ('4140 Chromoly Steel', 'Si', 0.250),
        ('4140 Chromoly Steel', 'Mn', 0.880),
        ('4140 Chromoly Steel', 'Cr', 0.950),
        ('4140 Chromoly Steel', 'Mo', 0.200),
        ('304 Stainless Steel', 'Fe', 71.180),
        ('304 Stainless Steel', 'Cr', 18.000),
        ('304 Stainless Steel', 'Ni', 8.000),
        ('304 Stainless Steel', 'Mn', 2.000),
        ('304 Stainless Steel', 'Si', 0.750),
        ('304 Stainless Steel', 'C', 0.070),
        ('316 Stainless Steel', 'Fe', 68.680),
        ('316 Stainless Steel', 'Cr', 16.500),
        ('316 Stainless Steel', 'Ni', 10.000),
        ('316 Stainless Steel', 'Mo', 2.000),
        ('316 Stainless Steel', 'Mn', 2.000),
        ('316 Stainless Steel', 'Si', 0.750),
        ('316 Stainless Steel', 'C', 0.070),
        ('430 Stainless Steel', 'Fe', 81.150),
        ('430 Stainless Steel', 'Cr', 17.000),
        ('430 Stainless Steel', 'Mn', 1.000),
        ('430 Stainless Steel', 'Si', 0.750),
        ('430 Stainless Steel', 'C', 0.100),
        ('17-4 PH Stainless Steel', 'Fe', 73.630),
        ('17-4 PH Stainless Steel', 'Cr', 16.000),
        ('17-4 PH Stainless Steel', 'Ni', 4.000),
        ('17-4 PH Stainless Steel', 'Cu', 4.000),
        ('17-4 PH Stainless Steel', 'Mn', 1.000),
        ('17-4 PH Stainless Steel', 'Si', 1.000),
        ('17-4 PH Stainless Steel', 'Nb', 0.300),
        ('17-4 PH Stainless Steel', 'C', 0.070),
        ('M2 High-Speed Steel', 'Fe', 82.150),
        ('M2 High-Speed Steel', 'W', 6.000),
        ('M2 High-Speed Steel', 'Mo', 5.000),
        ('M2 High-Speed Steel', 'Cr', 4.000),
        ('M2 High-Speed Steel', 'V', 2.000),
        ('M2 High-Speed Steel', 'C', 0.850),
        ('Gray Cast Iron', 'Fe', 93.800),
        ('Gray Cast Iron', 'C', 3.400),
        ('Gray Cast Iron', 'Si', 2.200),
        ('Gray Cast Iron', 'Mn', 0.600),
        ('Ductile Cast Iron', 'Fe', 93.560),
        ('Ductile Cast Iron', 'C', 3.600),
        ('Ductile Cast Iron', 'Si', 2.500),
        ('Ductile Cast Iron', 'Mn', 0.300),
        ('Ductile Cast Iron', 'Mg', 0.040),
        ('Weathering Steel', 'Fe', 97.700),
        ('Weathering Steel', 'Cr', 0.650),
        ('Weathering Steel', 'Si', 0.400),
        ('Weathering Steel', 'Mn', 0.400),
        ('Weathering Steel', 'Cu', 0.350),
        ('Weathering Steel', 'Ni', 0.300),
        ('Weathering Steel', 'C', 0.100),
        ('Weathering Steel', 'P', 0.100),
        ('Invar 36', 'Fe', 63.800),
        ('Invar 36', 'Ni', 36.000),
        ('Invar 36', 'Mn', 0.200),

        -- Nickel alloys and superalloys.
        ('Inconel 718', 'Ni', 53.000),
        ('Inconel 718', 'Cr', 19.000),
        ('Inconel 718', 'Fe', 18.500),
        ('Inconel 718', 'Nb', 5.100),
        ('Inconel 718', 'Mo', 3.000),
        ('Inconel 718', 'Ti', 0.900),
        ('Inconel 718', 'Al', 0.500),
        ('Hastelloy C-276', 'Ni', 57.000),
        ('Hastelloy C-276', 'Mo', 16.000),
        ('Hastelloy C-276', 'Cr', 15.500),
        ('Hastelloy C-276', 'Fe', 5.500),
        ('Hastelloy C-276', 'W', 3.500),
        ('Hastelloy C-276', 'Co', 2.500),
        ('Monel 400', 'Ni', 66.500),
        ('Monel 400', 'Cu', 31.500),
        ('Monel 400', 'Fe', 1.500),
        ('Monel 400', 'Mn', 0.500),
        ('Nichrome 80/20', 'Ni', 80.000),
        ('Nichrome 80/20', 'Cr', 20.000),
        ('Nitinol', 'Ni', 55.000),
        ('Nitinol', 'Ti', 45.000),

        -- Titanium.
        ('Ti-6Al-4V', 'Ti', 90.000),
        ('Ti-6Al-4V', 'Al', 6.000),
        ('Ti-6Al-4V', 'V', 4.000),
        ('CP Titanium Grade 2', 'Ti', 99.600),
        ('CP Titanium Grade 2', 'Fe', 0.300),
        ('CP Titanium Grade 2', 'C', 0.100),

        -- Zinc and magnesium die-casting alloys.
        ('Zamak 3', 'Zn', 95.900),
        ('Zamak 3', 'Al', 4.000),
        ('Zamak 3', 'Cu', 0.060),
        ('Zamak 3', 'Mg', 0.040),
        ('Zamak 5', 'Zn', 94.950),
        ('Zamak 5', 'Al', 4.000),
        ('Zamak 5', 'Cu', 1.000),
        ('Zamak 5', 'Mg', 0.050),
        ('AZ91D Magnesium', 'Mg', 90.000),
        ('AZ91D Magnesium', 'Al', 9.000),
        ('AZ91D Magnesium', 'Zn', 0.700),
        ('AZ91D Magnesium', 'Mn', 0.300),
        ('AZ31B Magnesium', 'Mg', 96.000),
        ('AZ31B Magnesium', 'Al', 3.000),
        ('AZ31B Magnesium', 'Zn', 1.000),

        -- Coinage and bullion alloys.
        ('Commercial Pure Copper', 'Cu', 99.950),
        ('Commercial Pure Copper', 'O', 0.050),
        ('Cupronickel 75/25', 'Cu', 75.000),
        ('Cupronickel 75/25', 'Ni', 25.000),
        ('Nickel Brass', 'Cu', 75.000),
        ('Nickel Brass', 'Zn', 20.000),
        ('Nickel Brass', 'Ni', 5.000),
        ('Nordic Gold', 'Cu', 89.000),
        ('Nordic Gold', 'Al', 5.000),
        ('Nordic Gold', 'Zn', 5.000),
        ('Nordic Gold', 'Sn', 1.000),
        ('Manganese Brass', 'Cu', 77.000),
        ('Manganese Brass', 'Zn', 12.000),
        ('Manganese Brass', 'Mn', 7.000),
        ('Manganese Brass', 'Ni', 4.000),
        ('Coinage Zinc Core', 'Zn', 99.200),
        ('Coinage Zinc Core', 'Cu', 0.800),
        ('Coinage Steel Core', 'Fe', 99.600),
        ('Coinage Steel Core', 'Mn', 0.320),
        ('Coinage Steel Core', 'C', 0.080),
        ('Coinage Aluminum', 'Al', 99.500),
        ('Coinage Aluminum', 'Fe', 0.300),
        ('Coinage Aluminum', 'Si', 0.200),
        ('Fine Silver 999', 'Ag', 99.900),
        ('Fine Silver 999', 'Cu', 0.100),
        ('Fine Platinum 9995', 'Pt', 99.950),
        ('Fine Platinum 9995', 'Ir', 0.050),
        ('Fine Palladium 9995', 'Pd', 99.950),
        ('Fine Palladium 9995', 'Ru', 0.050),

        ('Fine Silver 9999', 'Ag', 99.990),
        ('Fine Silver 9999', 'Cu', 0.010),

        -- Both of these are gold with the balance in copper, which is what makes
        -- them hard enough to circulate. Coin Gold 900 is the same 90/10 split as
        -- Coin Silver, one row above - the standard is about durability, not which
        -- precious metal is being hardened.
        ('Coin Gold 900', 'Au', 90.000),
        ('Coin Gold 900', 'Cu', 10.000),

        ('Ducat Gold 986', 'Au', 98.600),
        ('Ducat Gold 986', 'Cu', 1.400)
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

-- Guard rail. The INSERT above joins the component list to elements by symbol,
-- so a symbol that does not exist is dropped by the join instead of raising a
-- foreign key error: the seed would "succeed" while quietly storing an alloy
-- with missing metal. Checking that every composition still sums to 100 turns
-- that silence into a failure.
DO $$
DECLARE
    offenders text;
BEGIN
    SELECT string_agg(name || ' (' || total || '%)', ', ' ORDER BY name)
    INTO offenders
    FROM (
        SELECT a.name, coalesce(sum(ae.percent_of_alloy), 0) AS total
        FROM alloys a
        LEFT JOIN alloy_elements ae ON ae.alloy_id = a.alloy_id
        GROUP BY a.name
        HAVING coalesce(sum(ae.percent_of_alloy), 0) <> 100
    ) AS broken;

    IF offenders IS NOT NULL THEN
        RAISE EXCEPTION
            'Alloy compositions must sum to 100 percent. Broken: %', offenders;
    END IF;
END $$;

-- Derive primary_metal from the composition rather than repeating it by hand.
-- DISTINCT ON with the ORDER BY below picks the single element with the largest
-- mass fraction for each alloy.
UPDATE alloys a
SET primary_metal = upper(majority.metal_name)
FROM (
    SELECT DISTINCT ON (ae.alloy_id)
           ae.alloy_id,
           e.name AS metal_name
    FROM alloy_elements ae
    INNER JOIN elements e ON e.atomic_number = ae.atomic_number
    ORDER BY ae.alloy_id, ae.percent_of_alloy DESC, e.atomic_number
) AS majority
WHERE majority.alloy_id = a.alloy_id;

-- Now that it is populated, make it mandatory. Anything added later has to pass
-- the CHECK and cannot be left empty.
ALTER TABLE alloys ALTER COLUMN primary_metal SET NOT NULL;

-- The families were typed by hand, so confirm each one still agrees with the
-- metal just computed. This is the assertion that keeps "COPPER family" and
-- "mostly copper" from drifting apart - and it is what catches a brass being
-- filed under PRECIOUS by accident.
DO $$
DECLARE
    mismatches text;
BEGIN
    SELECT string_agg(name || ' (' || alloy_family || ' / ' || primary_metal || ')', ', ' ORDER BY name)
    INTO mismatches
    FROM alloys
    WHERE (alloy_family, primary_metal) NOT IN (
        ('ALUMINUM', 'ALUMINUM'),
        ('COPPER', 'COPPER'),
        ('FERROUS', 'IRON'),
        ('MAGNESIUM', 'MAGNESIUM'),
        ('NICKEL', 'NICKEL'),
        ('TIN', 'TIN'),
        ('TITANIUM', 'TITANIUM'),
        ('ZINC', 'ZINC'),
        -- PRECIOUS is the one family that spans several metals.
        ('PRECIOUS', 'GOLD'),
        ('PRECIOUS', 'SILVER'),
        ('PRECIOUS', 'PLATINUM'),
        ('PRECIOUS', 'PALLADIUM')
    );

    IF mismatches IS NOT NULL THEN
        RAISE EXCEPTION
            'alloy_family disagrees with the majority element. Offenders: %', mismatches;
    END IF;
END $$;

-- What each alloy is used for. Several alloys carry three or four uses, which
-- is the whole reason this is a table and not a column.
WITH alloy_use_data (alloy_name, use_code) AS (
    VALUES
        ('Fine Gold 24K', 'BULLION'),
        ('Fine Gold 24K', 'COINAGE'),
        ('22K Gold Coin Alloy', 'COINAGE'),
        ('22K Gold Coin Alloy', 'JEWELRY'),
        ('18K Yellow Gold', 'JEWELRY'),
        ('18K Rose Gold', 'JEWELRY'),
        ('18K White Gold (Palladium)', 'JEWELRY'),
        ('14K Yellow Gold', 'JEWELRY'),
        ('10K Yellow Gold', 'JEWELRY'),
        ('Electrum', 'COINAGE'),
        ('Electrum', 'DECORATIVE'),
        ('Sterling Silver', 'JEWELRY'),
        ('Sterling Silver', 'DECORATIVE'),
        ('Coin Silver', 'COINAGE'),
        ('Britannia Silver', 'DECORATIVE'),
        ('Britannia Silver', 'JEWELRY'),
        ('Platinum 950', 'JEWELRY'),
        ('Palladium 950', 'JEWELRY'),

        ('Yellow Brass', 'FASTENERS'),
        ('Yellow Brass', 'DECORATIVE'),
        ('Red Brass', 'MARINE'),
        ('Red Brass', 'DECORATIVE'),
        ('Naval Brass', 'MARINE'),
        ('Leaded Free-Cutting Brass', 'FASTENERS'),
        ('Leaded Free-Cutting Brass', 'TOOLING'),
        ('Gilding Metal', 'DECORATIVE'),
        ('Tin Bronze', 'BEARING'),
        ('Tin Bronze', 'DECORATIVE'),
        ('Phosphor Bronze', 'ELECTRICAL'),
        ('Phosphor Bronze', 'BEARING'),
        ('Aluminum Bronze', 'MARINE'),
        ('Aluminum Bronze', 'BEARING'),
        ('Silicon Bronze', 'FASTENERS'),
        ('Silicon Bronze', 'MARINE'),
        ('Manganese Bronze', 'MARINE'),
        ('Manganese Bronze', 'STRUCTURAL'),
        ('Leaded Bronze', 'BEARING'),
        ('Bell Metal', 'MUSICAL'),
        ('Bell Metal', 'DECORATIVE'),
        ('Cupronickel 90/10', 'MARINE'),
        ('Cupronickel 70/30', 'MARINE'),
        ('Nickel Silver', 'MUSICAL'),
        ('Nickel Silver', 'DECORATIVE'),
        ('Nickel Silver', 'INSTRUMENTATION'),
        ('Beryllium Copper', 'ELECTRICAL'),
        ('Beryllium Copper', 'TOOLING'),
        ('Chromium Copper', 'ELECTRICAL'),
        ('Chromium Copper', 'TOOLING'),
        ('Shakudo', 'DECORATIVE'),
        ('Shakudo', 'JEWELRY'),

        ('Traditional Lead Pewter', 'DECORATIVE'),
        ('Lead-Free Pewter', 'DECORATIVE'),
        ('Sn63/Pb37 Eutectic Solder', 'SOLDERING'),
        ('Sn63/Pb37 Eutectic Solder', 'ELECTRICAL'),
        ('SAC305 Lead-Free Solder', 'SOLDERING'),
        ('SAC305 Lead-Free Solder', 'ELECTRICAL'),

        ('Aluminum 3003', 'COOKWARE'),
        ('Aluminum 3003', 'STRUCTURAL'),
        ('Aluminum 5052', 'MARINE'),
        ('Aluminum 5052', 'STRUCTURAL'),
        ('Aluminum 6061', 'STRUCTURAL'),
        ('Aluminum 6061', 'MARINE'),
        ('Aluminum 6061', 'TOOLING'),
        ('Aluminum 7075', 'AEROSPACE'),
        ('Aluminum 7075', 'TOOLING'),
        ('Aluminum 2024', 'AEROSPACE'),
        ('Aluminum 2024', 'STRUCTURAL'),
        ('A356 Cast Aluminum', 'STRUCTURAL'),
        ('A356 Cast Aluminum', 'AEROSPACE'),

        ('1018 Mild Steel', 'STRUCTURAL'),
        ('1018 Mild Steel', 'FASTENERS'),
        ('1045 Medium Carbon Steel', 'STRUCTURAL'),
        ('1045 Medium Carbon Steel', 'TOOLING'),
        ('4140 Chromoly Steel', 'STRUCTURAL'),
        ('4140 Chromoly Steel', 'TOOLING'),
        ('4140 Chromoly Steel', 'AEROSPACE'),
        ('304 Stainless Steel', 'STRUCTURAL'),
        ('304 Stainless Steel', 'COOKWARE'),
        ('304 Stainless Steel', 'MEDICAL'),
        ('316 Stainless Steel', 'MARINE'),
        ('316 Stainless Steel', 'MEDICAL'),
        ('316 Stainless Steel', 'STRUCTURAL'),
        ('430 Stainless Steel', 'DECORATIVE'),
        ('430 Stainless Steel', 'COOKWARE'),
        ('17-4 PH Stainless Steel', 'AEROSPACE'),
        ('17-4 PH Stainless Steel', 'STRUCTURAL'),
        ('17-4 PH Stainless Steel', 'MARINE'),
        ('M2 High-Speed Steel', 'TOOLING'),
        ('Gray Cast Iron', 'STRUCTURAL'),
        ('Gray Cast Iron', 'COOKWARE'),
        ('Ductile Cast Iron', 'STRUCTURAL'),
        ('Weathering Steel', 'STRUCTURAL'),
        ('Weathering Steel', 'DECORATIVE'),
        ('Invar 36', 'INSTRUMENTATION'),

        ('Inconel 718', 'HIGH_TEMPERATURE'),
        ('Inconel 718', 'AEROSPACE'),
        ('Hastelloy C-276', 'HIGH_TEMPERATURE'),
        ('Hastelloy C-276', 'MARINE'),
        ('Monel 400', 'MARINE'),
        ('Monel 400', 'HIGH_TEMPERATURE'),
        ('Nichrome 80/20', 'ELECTRICAL'),
        ('Nichrome 80/20', 'HIGH_TEMPERATURE'),
        ('Nitinol', 'MEDICAL'),
        ('Nitinol', 'INSTRUMENTATION'),

        ('Ti-6Al-4V', 'AEROSPACE'),
        ('Ti-6Al-4V', 'MEDICAL'),
        ('Ti-6Al-4V', 'STRUCTURAL'),
        ('CP Titanium Grade 2', 'MEDICAL'),
        ('CP Titanium Grade 2', 'MARINE'),

        ('Zamak 3', 'DECORATIVE'),
        ('Zamak 3', 'STRUCTURAL'),
        ('Zamak 5', 'STRUCTURAL'),
        ('Zamak 5', 'DECORATIVE'),
        ('AZ91D Magnesium', 'STRUCTURAL'),
        ('AZ91D Magnesium', 'AEROSPACE'),
        ('AZ31B Magnesium', 'STRUCTURAL'),
        ('AZ31B Magnesium', 'AEROSPACE'),

        -- The coinage and bullion alloys. COINAGE is for metal meant to circulate
        -- as money; BULLION is for metal held for what it weighs. A few alloys are
        -- both, which is exactly the case a junction table exists to express - a
        -- Gold Eagle is legal tender that nobody spends.
        ('Commercial Pure Copper', 'COINAGE'),
        ('Commercial Pure Copper', 'BULLION'),
        ('Commercial Pure Copper', 'ELECTRICAL'),
        ('Cupronickel 75/25', 'COINAGE'),
        ('Cupronickel 75/25', 'MARINE'),
        ('Nickel Brass', 'COINAGE'),
        ('Nordic Gold', 'COINAGE'),
        ('Manganese Brass', 'COINAGE'),
        ('Coinage Zinc Core', 'COINAGE'),
        ('Coinage Steel Core', 'COINAGE'),
        ('Coinage Aluminum', 'COINAGE'),
        ('Fine Silver 999', 'BULLION'),
        ('Fine Silver 999', 'COINAGE'),
        ('Fine Platinum 9995', 'BULLION'),
        ('Fine Platinum 9995', 'COINAGE'),
        ('Fine Palladium 9995', 'BULLION'),
        ('Fine Palladium 9995', 'COINAGE'),
        ('Fine Silver 9999', 'BULLION'),
        ('Fine Silver 9999', 'COINAGE'),
        -- Coin Gold 900 and Ducat Gold 986 only ever existed to be struck into
        -- money, so neither carries JEWELRY the way 22K does.
        ('Coin Gold 900', 'COINAGE'),
        ('Ducat Gold 986', 'COINAGE'),
        ('Ducat Gold 986', 'BULLION')
)
INSERT INTO alloy_uses (alloy_id, use_code)
SELECT
    a.alloy_id,
    d.use_code
FROM alloy_use_data d
INNER JOIN alloys a ON a.name = d.alloy_name
ON CONFLICT (alloy_id, use_code) DO NOTHING;

-- Mint products: coins, rounds, bars, ingots, medals, tokens, and goldbacks.
-- Uses alloy names already seeded above.
--
-- alloy_id is the predominant alloy BY WEIGHT, which is occasionally not the one
-- you see: a clad US quarter is mostly its pure copper core, not the cupronickel
-- on the outside. Layers are recorded in mint_product_components below.
--
-- fine_metal_weight_g is filled in only where it means something - bullion and
-- precious coins. For a circulating base-metal coin nobody asks how much copper
-- is in it, so it stays NULL rather than carrying a number no one wants.
INSERT INTO mint_products (
    name,
    product_type,
    issuer,
    mint,
    year_introduced,
    gross_weight_g,
    fine_metal_weight_g,
    alloy_id
)
SELECT
    v.name,
    v.product_type,
    v.issuer,
    v.mint,
    v.year_introduced,
    v.gross_weight_g,
    v.fine_metal_weight_g,
    a.alloy_id
FROM (
    VALUES
        -- Precious bullion coins.
        ('American Gold Eagle (1 oz)', 'COIN', 'United States', 'United States Mint', 1986, 33.9305, 31.1035, '22K Gold Coin Alloy'),
        ('American Silver Eagle (1 oz)', 'COIN', 'United States', 'United States Mint', 1986, 31.1035, 31.1035, 'Fine Silver 999'),
        ('American Platinum Eagle (1 oz)', 'COIN', 'United States', 'United States Mint', 1997, 31.1035, 31.1035, 'Fine Platinum 9995'),
        ('Krugerrand (1 oz)', 'COIN', 'South Africa', 'South African Mint', 1967, 33.9300, 31.1035, '22K Gold Coin Alloy'),
        ('Gold Britannia (1 oz)', 'COIN', 'United Kingdom', 'The Royal Mint', 1987, 34.0500, 31.1035, '22K Gold Coin Alloy'),
        ('Gold Maple Leaf (1 oz)', 'COIN', 'Canada', 'Royal Canadian Mint', 1979, 31.1035, 31.1035, 'Fine Gold 24K'),
        ('Silver Maple Leaf (1 oz)', 'COIN', 'Canada', 'Royal Canadian Mint', 1988, 31.1035, 31.1035, 'Fine Silver 999'),

        -- Modern world bullion coins. year_introduced is the year this particular
        -- dated issue was struck, not when the series began - for an annual issue
        -- like the Lunar or the Philharmonic, the 2026 coin is its own product with
        -- its own design, so that is the year recorded.
        ('2027 Gold Lunar Goat (1 oz)', 'COIN', 'Australia', 'The Perth Mint', 2027, 31.1035, 31.1035, 'Fine Gold 24K'),
        ('2026 Silver Kookaburra (1 oz)', 'COIN', 'Australia', 'The Perth Mint', 2026, 31.1035, 31.1035, 'Fine Silver 9999'),
        ('2025 Silver Lunar Snake, Dragon Privy (1 oz)', 'COIN', 'Australia', 'The Perth Mint', 2025, 31.1035, 31.1035, 'Fine Silver 9999'),
        ('2026 Silver Vienna Philharmonic (1 oz)', 'COIN', 'Austria', 'Austrian Mint', 2026, 31.1035, 31.1035, 'Fine Silver 999'),

        -- Historic European gold, still sold as bullion. Neither is pure: both are
        -- hardened with copper so they could survive circulation, which is why the
        -- gross weight is noticeably higher than the gold in it.
        ('Austrian 1 Ducat (1915 Restrike)', 'COIN', 'Austria', 'Austrian Mint', 1915, 3.4909, 3.4420, 'Ducat Gold 986'),
        ('20 Franc Swiss Vreneli', 'COIN', 'Switzerland', 'Swissmint', 1897, 6.4516, 5.8065, 'Coin Gold 900'),

        -- Historic US silver.
        ('Morgan Silver Dollar', 'COIN', 'United States', 'United States Mint', 1878, 26.7300, 24.0570, 'Coin Silver'),
        ('Peace Silver Dollar', 'COIN', 'United States', 'United States Mint', 1921, 26.7300, 24.0570, 'Coin Silver'),
        ('Franklin Half Dollar', 'COIN', 'United States', 'United States Mint', 1948, 12.5000, 11.2500, 'Coin Silver'),

        -- Circulating US base metal. The cent and the clad coins are layered.
        ('Lincoln Cent (Copper-Plated Zinc)', 'COIN', 'United States', 'United States Mint', 1982, 2.5000, NULL, 'Coinage Zinc Core'),
        ('Jefferson Nickel', 'COIN', 'United States', 'United States Mint', 1938, 5.0000, NULL, 'Cupronickel 75/25'),
        ('Roosevelt Dime (Clad)', 'COIN', 'United States', 'United States Mint', 1965, 2.2680, NULL, 'Commercial Pure Copper'),
        ('Washington Quarter (Clad)', 'COIN', 'United States', 'United States Mint', 1965, 5.6700, NULL, 'Commercial Pure Copper'),
        ('Sacagawea Dollar', 'COIN', 'United States', 'United States Mint', 2000, 8.1000, NULL, 'Manganese Brass'),

        -- Circulating Europe, including two bimetallic coins.
        ('2 Euro', 'COIN', 'Euro area', 'Various national mints', 2002, 8.5000, NULL, 'Nickel Brass'),
        ('1 Euro', 'COIN', 'Euro area', 'Various national mints', 2002, 7.5000, NULL, 'Cupronickel 75/25'),
        ('20 Euro Cent', 'COIN', 'Euro area', 'Various national mints', 2002, 5.7400, NULL, 'Nordic Gold'),
        ('1 Euro Cent', 'COIN', 'Euro area', 'Various national mints', 2002, 2.3000, NULL, 'Coinage Steel Core'),
        ('Two Pounds', 'COIN', 'United Kingdom', 'The Royal Mint', 1998, 12.0000, NULL, 'Nickel Brass'),
        ('Brass Threepence', 'COIN', 'United Kingdom', 'The Royal Mint', 1937, 6.8000, NULL, 'Nickel Brass'),
        ('1 Lira', 'COIN', 'Italy', 'Istituto Poligrafico e Zecca dello Stato', 1946, 0.6250, NULL, 'Coinage Aluminum'),

        -- Ancient and colonial. Both predate ISO currency codes.
        ('Roman Denarius', 'COIN', 'Roman Republic', 'Rome', -211, 3.9000, 3.7378, 'Britannia Silver'),
        ('8 Reales', 'COIN', 'Spanish Empire', 'Mexico City Mint', 1732, 27.0700, 24.3630, 'Coin Silver'),

        -- Privately minted rounds. Coin-shaped, but not money.
        ('1 oz Silver Round', 'ROUND', NULL, 'Private mint', NULL, 31.1035, 31.1035, 'Fine Silver 999'),
        ('1 oz Copper Round', 'ROUND', NULL, 'Private mint', NULL, 31.1035, 31.1035, 'Commercial Pure Copper'),
        -- Named rounds. Same metal as the coins above and often the same weight,
        -- but no issuer and no coins row, because nobody declared them money.
        ('Tara Tree of Life Silver Round (1 oz)', 'ROUND', NULL, 'Private mint', NULL, 31.1035, 31.1035, 'Fine Silver 999'),
        ('Tara Tree of Life Gold Round (1 oz)', 'ROUND', NULL, 'Private mint', NULL, 31.1035, 31.1035, 'Fine Gold 24K'),
        ('Year of the Snake Silver Round (1 oz)', 'ROUND', NULL, 'Private mint', NULL, 31.1035, 31.1035, 'Fine Silver 999'),
        ('Aztec Calendar Copper Round (5 oz)', 'ROUND', NULL, 'Private mint', NULL, 155.5175, 155.5175, 'Commercial Pure Copper'),

        -- Bars.
        ('1 oz Gold Bar', 'BAR', NULL, 'Private mint', NULL, 31.1035, 31.1035, 'Fine Gold 24K'),
        ('10 oz Silver Bar', 'BAR', NULL, 'Private mint', NULL, 311.0350, 311.0350, 'Fine Silver 999'),
        ('1 kg Silver Bar', 'BAR', NULL, 'Private mint', NULL, 1000.0000, 1000.0000, 'Fine Silver 999'),
        ('1 oz Platinum Bar', 'BAR', NULL, 'Private mint', NULL, 31.1035, 31.1035, 'Fine Platinum 9995'),
        ('100 g Palladium Bar', 'BAR', NULL, 'Private mint', NULL, 100.0000, 100.0000, 'Fine Palladium 9995'),
        ('Copper Ingot (5 lb)', 'INGOT', NULL, 'Private refiner', NULL, 2267.9600, 2267.9600, 'Commercial Pure Copper'),

        -- Not currency, not bullion.
        ('Bronze Commemorative Medal', 'MEDAL', NULL, 'Private mint', NULL, 45.0000, NULL, 'Tin Bronze'),
        -- A state mint striking investment-grade silver that is still not money.
        -- KOMSCO is South Korea's official mint, but Korean law does not authorise
        -- these as legal tender, so KOMSCO issues them as medals - which is why
        -- this is a MEDAL with a fine weight and no coins row. product_type here
        -- records legal status, not shape: this is as round as the rounds above.
        ('2022 South Korean Silver Phoenix (1 oz)', 'MEDAL', NULL, 'KOMSCO', 2022, 31.1035, 31.1035, 'Fine Silver 999'),
        ('Brass Arcade Token', 'TOKEN', NULL, 'Private mint', NULL, 4.5000, NULL, 'Yellow Brass'),

        -- Goldbacks: polymer notes carrying a measured gold leaf. Gross weight is
        -- mostly polymer, so fine_metal_weight_g is the only figure that matters -
        -- one "goldback" is 1/1000 troy ounce of 24K gold.
        ('Utah Goldback 1', 'NOTE', 'Utah', 'Goldback Inc.', 2019, NULL, 0.0311, 'Fine Gold 24K'),
        ('Utah Goldback 50', 'NOTE', 'Utah', 'Goldback Inc.', 2019, NULL, 1.5552, 'Fine Gold 24K'),
        ('Nevada Goldback 5', 'NOTE', 'Nevada', 'Goldback Inc.', 2020, NULL, 0.1555, 'Fine Gold 24K')
) AS v(
    name,
    product_type,
    issuer,
    mint,
    year_introduced,
    gross_weight_g,
    fine_metal_weight_g,
    alloy_name
)
INNER JOIN alloys a ON a.name = v.alloy_name
ON CONFLICT (name) DO UPDATE SET
    product_type = EXCLUDED.product_type,
    issuer = EXCLUDED.issuer,
    mint = EXCLUDED.mint,
    year_introduced = EXCLUDED.year_introduced,
    gross_weight_g = EXCLUDED.gross_weight_g,
    fine_metal_weight_g = EXCLUDED.fine_metal_weight_g,
    alloy_id = EXCLUDED.alloy_id;

-- The coin subtype. Only the legal tender pieces get a row here; rounds, bars,
-- medals, tokens and goldbacks deliberately have none.
--
-- face_value_currency_code is an ISO 4217 code wherever one exists. Where the
-- currency predates the standard there are two cases, and they are different:
--
--   * the unit is known and has a usual abbreviation - 'Kr' for the
--     Austro-Hungarian krone - so that is recorded, and a face value with it.
--   * the unit is not identifiable as a currency at all, which is what 'XXX',
--     the ISO code for "no currency", records. A Roman denarius and a Spanish
--     8 reales are counted in units that were never currencies in the modern
--     sense, so face_value stays NULL for them, and
--     chk_coins_no_value_without_currency above enforces that pairing: a number
--     is only meaningful once there is a currency to count it in.
--
-- is_legal_tender records whether the piece would still be accepted as money
-- today - historic US coins technically would, a Roman denarius would not.
INSERT INTO coins (mint_product_id, face_value, face_value_currency_code, is_legal_tender)
SELECT
    p.mint_product_id,
    v.face_value,
    v.face_value_currency_code,
    v.is_legal_tender
FROM (
    VALUES
        ('American Gold Eagle (1 oz)', 50.00, 'USD', TRUE),
        ('American Silver Eagle (1 oz)', 1.00, 'USD', TRUE),
        ('American Platinum Eagle (1 oz)', 100.00, 'USD', TRUE),
        -- No denomination is struck on a Krugerrand; its value is the gold price.
        ('Krugerrand (1 oz)', NULL, 'ZAR', TRUE),
        ('Gold Britannia (1 oz)', 100.00, 'GBP', TRUE),
        ('Gold Maple Leaf (1 oz)', 50.00, 'CAD', TRUE),
        ('Silver Maple Leaf (1 oz)', 5.00, 'CAD', TRUE),
        ('2027 Gold Lunar Goat (1 oz)', 100.00, 'AUD', TRUE),
        ('2026 Silver Kookaburra (1 oz)', 1.00, 'AUD', TRUE),
        ('2025 Silver Lunar Snake, Dragon Privy (1 oz)', 1.00, 'AUD', TRUE),
        ('2026 Silver Vienna Philharmonic (1 oz)', 1.50, 'EUR', TRUE),
        -- Swiss gold francs were never demonetised, so a Vreneli struck in 1897 is
        -- still worth 20 francs at a Swiss counter - roughly one five-hundredth of
        -- the gold in it.
        ('20 Franc Swiss Vreneli', 20.00, 'CHF', TRUE),
        -- Denominated in the Austro-Hungarian krone, the currency in circulation in
        -- 1915, the year these restrikes are dated. The krone was replaced by the
        -- schilling in 1925 and never received an ISO 4217 code, so it is recorded
        -- by its historic abbreviation 'Kr' - which is why the column above is
        -- VARCHAR(3) rather than CHAR(3). is_legal_tender is FALSE because the krone
        -- has not been money for a century.
        ('Austrian 1 Ducat (1915 Restrike)', 1.00, 'Kr', FALSE),
        ('Morgan Silver Dollar', 1.00, 'USD', TRUE),
        ('Peace Silver Dollar', 1.00, 'USD', TRUE),
        ('Franklin Half Dollar', 0.50, 'USD', TRUE),
        ('Lincoln Cent (Copper-Plated Zinc)', 0.01, 'USD', TRUE),
        ('Jefferson Nickel', 0.05, 'USD', TRUE),
        ('Roosevelt Dime (Clad)', 0.10, 'USD', TRUE),
        ('Washington Quarter (Clad)', 0.25, 'USD', TRUE),
        ('Sacagawea Dollar', 1.00, 'USD', TRUE),
        ('2 Euro', 2.00, 'EUR', TRUE),
        ('1 Euro', 1.00, 'EUR', TRUE),
        ('20 Euro Cent', 0.20, 'EUR', TRUE),
        ('1 Euro Cent', 0.01, 'EUR', TRUE),
        ('Two Pounds', 2.00, 'GBP', TRUE),
        -- Pre-decimal threepence, expressed in decimal pounds.
        ('Brass Threepence', 0.0125, 'GBP', FALSE),
        ('1 Lira', 1.00, 'ITL', FALSE),
        ('Roman Denarius', NULL, 'XXX', FALSE),
        ('8 Reales', NULL, 'XXX', FALSE)
) AS v(name, face_value, face_value_currency_code, is_legal_tender)
INNER JOIN mint_products p ON p.name = v.name
ON CONFLICT (mint_product_id) DO UPDATE SET
    face_value = EXCLUDED.face_value,
    face_value_currency_code = EXCLUDED.face_value_currency_code,
    is_legal_tender = EXCLUDED.is_legal_tender;

-- How the layered pieces are built. Percentages are derived from each coin's
-- published overall composition: for the clad quarter, cupronickel cladding is
-- 25 percent nickel and the coin is 8.33 percent nickel overall, so the cladding
-- must be 8.33 / 25 = one third of the weight. Where no such figure can be
-- worked out - the bimetallic ring-to-centre split - the percentage is left NULL
-- rather than guessed.
WITH component_data (product_name, alloy_name, component_role, percent_of_weight) AS (
    VALUES
        -- 97.5% Zn overall, core is 99.2% Zn: 97.5 / 99.2 = 98.286% core.
        ('Lincoln Cent (Copper-Plated Zinc)', 'Coinage Zinc Core', 'CORE', 98.286),
        ('Lincoln Cent (Copper-Plated Zinc)', 'Commercial Pure Copper', 'PLATING', 1.714),

        -- 8.33% Ni overall, cladding is 25% Ni: one third cladding, two thirds core.
        ('Roosevelt Dime (Clad)', 'Cupronickel 75/25', 'CLADDING', 33.333),
        ('Roosevelt Dime (Clad)', 'Commercial Pure Copper', 'CORE', 66.667),
        ('Washington Quarter (Clad)', 'Cupronickel 75/25', 'CLADDING', 33.333),
        ('Washington Quarter (Clad)', 'Commercial Pure Copper', 'CORE', 66.667),

        -- 2% Ni overall, manganese brass is 4% Ni: an even split. The two halves
        -- weigh the same, so "predominant alloy" is a coin toss here - alloy_id
        -- names the brass because that is the part you can see.
        ('Sacagawea Dollar', 'Manganese Brass', 'CLADDING', 50.000),
        ('Sacagawea Dollar', 'Commercial Pure Copper', 'CORE', 50.000),

        -- Bimetallic. Ring and centre swap alloys between the 1 and 2 euro.
        ('2 Euro', 'Nickel Brass', 'RING', NULL),
        ('2 Euro', 'Cupronickel 75/25', 'CENTER', NULL),
        ('1 Euro', 'Cupronickel 75/25', 'RING', NULL),
        ('1 Euro', 'Nickel Brass', 'CENTER', NULL),
        ('Two Pounds', 'Nickel Brass', 'RING', NULL),
        ('Two Pounds', 'Cupronickel 75/25', 'CENTER', NULL),

        -- Copper-plated steel.
        ('1 Euro Cent', 'Coinage Steel Core', 'CORE', NULL),
        ('1 Euro Cent', 'Commercial Pure Copper', 'PLATING', NULL)
)
INSERT INTO mint_product_components (mint_product_id, alloy_id, component_role, percent_of_weight)
SELECT
    p.mint_product_id,
    a.alloy_id,
    d.component_role,
    d.percent_of_weight
FROM component_data d
INNER JOIN mint_products p ON p.name = d.product_name
INNER JOIN alloys a ON a.name = d.alloy_name
ON CONFLICT (mint_product_id, alloy_id, component_role)
DO UPDATE SET percent_of_weight = EXCLUDED.percent_of_weight;

-- Same guard as the alloy compositions, for the same reason: both joins above
-- would silently drop a row whose product or alloy name is misspelled. Layer
-- weights only have to add up where they were stated at all.
DO $$
DECLARE
    offenders text;
BEGIN
    SELECT string_agg(name || ' (' || total || '%)', ', ' ORDER BY name)
    INTO offenders
    FROM (
        SELECT p.name, sum(c.percent_of_weight) AS total
        FROM mint_products p
        INNER JOIN mint_product_components c ON c.mint_product_id = p.mint_product_id
        GROUP BY p.name
        HAVING count(*) FILTER (WHERE c.percent_of_weight IS NULL) = 0
           AND sum(c.percent_of_weight) <> 100
    ) AS broken;

    IF offenders IS NOT NULL THEN
        RAISE EXCEPTION
            'Stated component weights must sum to 100 percent. Broken: %', offenders;
    END IF;
END $$;
