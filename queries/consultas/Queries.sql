-- Active: 1787956958115@@127.0.0.1@1433@Cafetear
-- 1) Mostrar por lote la cantidad de calibraciones, los gramos totales usados en 
--ellas y el puntaje promedio, 
--solo para los lotes con promedio menor a 3,5.


-- Nombre lote, cant calibraciones, gramos totales y puntaje promedio.

SELECT l.nombre, 
COUNT(c.IDCalibracion) AS CantidadCalibraciones, 
SUM(c.dosis) AS GramosTotalesUsados,
SUM(p.SumaPuntajes* 1.0)/ SUM(p.CantidadCalificaciones) AS PuntajePromedio
FROM Lote l
JOIN Calibracion c ON c.IDLote = l.IDLote
LEFT JOIN(
    SELECT IDCalibracion,
    SUM(puntaje) AS SumaPuntajes,
    COUNT(*) AS CantidadCalificaciones
    FROM Calificacion 
    GROUP BY IDCalibracion) p ON p.IDCalibracion = c.IDCalibracion
GROUP BY l.IDLote, l.nombre
HAVING SUM(p.SumaPuntajes* 1.0)/ SUM(p.CantidadCalificaciones) < 3.5;


/*

Mostrar el puntaje
promedio y la cantidad de
calificaciones de cada
mes.


MES CalificacionPromedio CantCalificaciones


*/
SELECT 
    CONCAT(MONTH(fecha), '/', YEAR(fecha)) AS MesAnio,
    AVG(puntaje)* 1.0 AS CalificacionPromedio,
    COUNT(*) AS CantidadCalificaciones
FROM
    Calificacion
GROUP BY MONTH(fecha), YEAR(fecha)
ORDER BY MONTH(fecha), YEAR(fecha)

/*
Mostrar Puntaje Promedio según las semanas transcurridas desde el tostado
*/

SELECT
    g.IDGrano,
    g.regionCosecha AS Grano,
    p.razonSocial AS Proveedor,
    DATEDIFF(DAY, l.fechaTostado, c.fechaCalibracion) / 7 AS SemanasDesdeTostado,
    AVG(cf.puntaje * 1.0) AS PuntajePromedio,
    COUNT(*) AS CantidadCalificaciones
FROM
    Grano g
JOIN Lote l ON l.IDGrano = g.IDGrano
JOIN Proveedor p ON p.IDProveedor = l.IDProveedor -- El mismo grano puede venir de distintos proveedores
JOIN Calibracion c ON c.IDLote = l.IDLote --Cada calibración usa un lote
JOIN Calificacion cf ON cf.IDCalibracion = c.IDCalibracion -- Cada calificacion evalua una calibracion

GROUP BY 
    g.IDGrano,
    g.regionCosecha,
    p.IDProveedor,
    p.razonSocial,
    DATEDIFF(DAY, l.fechaTostado, c.fechaCalibracion) / 7
ORDER BY g.IDGrano, p.razonSocial, SemanasDesdeTostado;

/*
Mostrar para cada grano y proveedor la calibración con mayor calificación promedio.
Se exigen al menos 3 calificaciones; si hay empate gana la que tiene más calificaciones y, si siguen empatadas, la más antigua.
Usa la vista vw_PuntajePorCalibracion (queries/objetos/02_vistas.sql), que ya trae el promedio y la cantidad por calibración.
*/

SELECT
    g.regionCosecha AS Grano,
    p.razonSocial AS Proveedor,
    v.IDCalibracion,
    v.dosis,
    v.tiempoExtraccion,
    v.rendimiento,
    v.puntajePromedio,
    v.calificaciones
FROM vw_PuntajePorCalibracion v
JOIN Lote l ON l.IDLote = v.IDLote
JOIN Grano g ON g.IDGrano = l.IDGrano
JOIN Proveedor p ON p.IDProveedor = l.IDProveedor
WHERE v.IDCalibracion = (
    SELECT TOP 1 v2.IDCalibracion
    FROM vw_PuntajePorCalibracion v2
    JOIN Lote l2 ON l2.IDLote = v2.IDLote
    WHERE l2.IDGrano = l.IDGrano
      AND l2.IDProveedor = l.IDProveedor      -- mismo grano y mismo proveedor
      AND v2.calificaciones >= 3
    ORDER BY v2.puntajePromedio DESC, v2.calificaciones DESC, v2.IDCalibracion
)
ORDER BY g.regionCosecha, p.razonSocial;


-- Proveedor con mejor cafe.
SELECT TOP 1 p.IDProveedor, p.razonSocial, ROUND(AVG(cf.puntaje*1.0),2) AS puntajePromedio FROM Proveedor p 
JOIN Lote l ON l.IDProveedor = p.IDProveedor
JOIN Calibracion cl ON  cl.IDLote = l.IDLote
JOIN Calificacion cf ON cf.IDCalibracion = cl.IDCalibracion
GROUP BY p.IDProveedor, p.razonSocial
HAVING COUNT(cf.IDCalificacion) > 5
ORDER BY AVG(cf.puntaje*1.0) DESC

-- clientes que calificaron alguna vez y no calificaron en los últimos 90 días

SELECT CONCAT(c.nombre, ' ', c.apellido) AS NombreCliente, c.DNI FROM Cliente c
JOIN Calificacion cal ON cal.IDCliente = c.IDCliente
GROUP BY c.IDCliente, c.nombre, c.apellido, c.DNI
HAVING COUNT(cal.IDCalificacion) > 1 AND
    DATEDIFF(day, MAX(cal.fecha), GETDATE()) > 90

-- Calidad por día de la semana

SELECT DATENAME(WEEKDAY, fecha) AS diaDeLaSemana, AVG(puntaje*1.0) AS calificacionPromedio FROM Calificacion
GROUP BY DATENAME(WEEKDAY, fecha), DATEPART(WEEKDAY, fecha)
ORDER BY DATEPART(WEEKDAY, fecha)


/*

Lotes cuya calificación promedio del último mes es menor al anterior

*/

SELECT
    l.IDLote,
    l.nombre               AS Lote,
    AVG(cf.puntaje * 1.0)  AS PromedioUltimoMes,
    (

        SELECT AVG(cf2.puntaje * 1.0)
        FROM Calibracion  c2
        JOIN Calificacion cf2 ON cf2.IDCalibracion = c2.IDCalibracion
        WHERE c2.IDLote = l.IDLote
          AND cf2.fecha >= DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) - 2, 0)
          AND cf2.fecha <  DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) - 1, 0)
    )                      AS PromedioMesAnterior,
    COUNT(*)               AS CalificacionesUltimoMes
FROM Lote l
JOIN Calibracion  c  ON c.IDLote         = l.IDLote
JOIN Calificacion cf ON cf.IDCalibracion = c.IDCalibracion
WHERE cf.fecha >= DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) - 1, 0)  
  AND cf.fecha <  DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()), 0)   
GROUP BY l.IDLote, l.nombre
HAVING AVG(cf.puntaje * 1.0) < (

    SELECT AVG(cf2.puntaje * 1.0)
    FROM Calibracion  c2
    JOIN Calificacion cf2 ON cf2.IDCalibracion = c2.IDCalibracion
    WHERE c2.IDLote = l.IDLote
      AND cf2.fecha >= DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) - 2, 0)
      AND cf2.fecha <  DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) - 1, 0)
)
ORDER BY PromedioUltimoMes;

/*
   Diferencia entre la mejor y la peor calificación de cada lote (Para evaluar consistencia)
*/
SELECT
    l.nombre                          AS Lote,
    p.razonSocial                     AS Proveedor,
    MIN(cf.puntaje)                   AS PeorPuntaje,
    MAX(cf.puntaje)                   AS MejorPuntaje,
    MAX(cf.puntaje) - MIN(cf.puntaje) AS Diferencia,
    AVG(cf.puntaje * 1.0)             AS PuntajePromedio,
    COUNT(*)                          AS CantidadCalificaciones
FROM Lote l
JOIN Proveedor    p  ON p.IDProveedor    = l.IDProveedor
JOIN Calibracion  c  ON c.IDLote         = l.IDLote
JOIN Calificacion cf ON cf.IDCalibracion = c.IDCalibracion
GROUP BY l.IDLote, l.nombre, p.razonSocial
HAVING COUNT(*) >= 3
ORDER BY Diferencia DESC;