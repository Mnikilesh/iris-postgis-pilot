-- Peatland vertical: parcels that intersect mapped peatland, with the
-- overlap area in square metres (geography cast for a metric result).
SELECT
    p.country_code, p.region_code, p.parcel_code, pt.peatland_code,
    round(ST_Area(ST_Intersection(p.geom, pt.geom)::geography)::numeric, 1) AS overlap_sq_m
FROM iris_core.parcel p
JOIN iris_core.peatland pt
    ON pt.country_code = p.country_code
   AND ST_Intersects(p.geom, pt.geom)
WHERE p.country_code = 'GB'
ORDER BY overlap_sq_m DESC;
