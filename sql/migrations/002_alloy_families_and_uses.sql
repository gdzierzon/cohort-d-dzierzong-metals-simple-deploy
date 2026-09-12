-- 002_alloy_families_and_uses.sql
--
-- Adds alloys.alloy_family and the alloy_uses junction table, backfills the 29
-- existing alloys, and seeds 35 new ones with their compositions and uses.
-- Nothing is dropped. Users, roles, coins and elements are not touched.
-- Safe to run more than once, but only before 003 has run. 003 adds
-- alloys.primary_metal as NOT NULL, and the alloys INSERT below cannot supply a
-- column that does not exist yet in this migration's timeline - so replaying 002
-- on a database that is already at 003 fails on that NOT NULL, rolls back, and
-- changes nothing. That is the normal rule for migrations, not a defect here: they
-- are applied once, in order, and real tooling keeps a version table precisely so
-- an earlier one is never re-run after a later one.
--
-- Run 001_full_periodic_table.sql FIRST. The new compositions reference Fe, C,
-- V, Nb, Be, S and Ru, none of which existed in the original element seed.
--
-- Skipping 001 does NOT produce an error, which is the dangerous part. The
-- composition INSERT below builds its rows with
--     INNER JOIN elements e ON e.symbol = d.element_symbol
-- so a component whose element is missing is dropped by the join before the
-- foreign key ever sees it. Measured on a database without 001: the migration
-- reported success while storing 1018 Mild Steel with no iron and no carbon,
-- totalling 0.77 percent, and left 20 alloys silently incomplete.
--
-- The assertion at the bottom of this file is what turns that into a failure.
--
-- The seed blocks below are copied verbatim from sql/metals-db.sql. Never run
-- metals-db.sql against a live database: it opens with DROP TABLE.

BEGIN;

-- Nullable to begin with: the 29 rows already in the table have no family yet,
-- so NOT NULL here would fail immediately. It is enforced at the bottom of the
-- file, once the upsert below has given every row a value.
ALTER TABLE alloys ADD COLUMN IF NOT EXISTS alloy_family VARCHAR(40);

CREATE TABLE IF NOT EXISTS alloy_uses (
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

CREATE INDEX IF NOT EXISTS idx_alloy_uses_use_code ON alloy_uses (use_code);

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
    ('AZ31B Magnesium', 'dull silver', 'MAGNESIUM', 'Wrought magnesium sheet and extrusion alloy.')
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
        ('AZ31B Magnesium', 'Zn', 1.000)
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
        ('AZ31B Magnesium', 'AEROSPACE')
)
INSERT INTO alloy_uses (alloy_id, use_code)
SELECT
    a.alloy_id,
    d.use_code
FROM alloy_use_data d
INNER JOIN alloys a ON a.name = d.alloy_name
ON CONFLICT (alloy_id, use_code) DO NOTHING;

-- Every alloy now has a family, so the column can carry its real constraints.
-- DROP ... IF EXISTS first keeps this file re-runnable: ADD CONSTRAINT on its
-- own would fail the second time with "constraint already exists".
ALTER TABLE alloys DROP CONSTRAINT IF EXISTS chk_alloy_family;
ALTER TABLE alloys ADD CONSTRAINT chk_alloy_family CHECK (alloy_family IN (
    'PRECIOUS',
    'COPPER',
    'ALUMINUM',
    'FERROUS',
    'NICKEL',
    'TITANIUM',
    'TIN',
    'ZINC',
    'MAGNESIUM'
));
ALTER TABLE alloys ALTER COLUMN alloy_family SET NOT NULL;

-- Post-condition. Catches any component silently dropped by the INNER JOIN
-- above - a missing element, or a mistyped symbol - because the arithmetic
-- stops adding up. Inside the transaction, so a failure here rolls the whole
-- migration back rather than leaving half-built alloys behind.
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
            'Alloy compositions must sum to 100 percent. Broken: %', offenders
            USING HINT = 'Run 001_full_periodic_table.sql first, then re-run this migration.';
    END IF;
END $$;

COMMIT;
