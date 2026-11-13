-- Cafetear · Consultas del equipo

USE cafetear;
GO
-- ---------------------------------------- 1 ----------------------------------------

SELECT l.nombre,
       COUNT(c.idCalibracion) AS cantidadCalibraciones,
       SUM(c.dosis) AS gramosTotalesUsados,
       SUM(p.sumaPuntajes * 1.0) / SUM(p.cantidadCalificaciones) AS puntajePromedio
FROM Lote l
JOIN Calibracion c ON c.idLote = l.idLote
LEFT JOIN (SELECT idCalibracion,
                  SUM(puntaje) AS sumaPuntajes,
                  COUNT(*) AS cantidadCalificaciones
           FROM Calificacion
           GROUP BY idCalibracion) p ON p.idCalibracion = c.idCalibracion
GROUP BY l.idLote, l.nombre
HAVING SUM(p.sumaPuntajes * 1.0) / SUM(p.cantidadCalificaciones) < 3.5;

-- ---------------------------------------- 2 ----------------------------------------

SELECT CONCAT(MONTH(fecha), '/', YEAR(fecha)) AS mesAnio,
       AVG(puntaje * 1.0) AS calificacionPromedio,
       COUNT(*) AS cantidadCalificaciones
FROM Calificacion
GROUP BY MONTH(fecha), YEAR(fecha)
ORDER BY MONTH(fecha), YEAR(fecha);

-- ---------------------------------------- 3 ----------------------------------------

SELECT g.idGrano,
       g.regionCosecha AS grano,
       p.razonSocial AS proveedor,
       DATEDIFF(DAY, l.fechaTostado, c.fechaCalibracion) / 7 AS semanasDesdeTostado,
       AVG(cf.puntaje * 1.0) AS puntajePromedio,
       COUNT(*) AS cantidadCalificaciones
FROM Grano g
JOIN Lote l ON l.idGrano = g.idGrano
JOIN Proveedor p ON p.idProveedor = l.idProveedor
JOIN Calibracion c ON c.idLote = l.idLote
JOIN Calificacion cf ON cf.idCalibracion = c.idCalibracion
GROUP BY g.idGrano,
         g.regionCosecha,
         p.idProveedor,
         p.razonSocial,
         DATEDIFF(DAY, l.fechaTostado, c.fechaCalibracion) / 7
ORDER BY g.idGrano, p.razonSocial, semanasDesdeTostado;

-- ---------------------------------------- 4 ----------------------------------------

SELECT g.regionCosecha AS grano,
       p.razonSocial AS proveedor,
       v.idCalibracion,
       v.dosis,
       v.tiempoExtraccion,
       v.rendimiento,
       v.puntajePromedio,
       v.calificaciones
FROM vwPuntajePorCalibracion v
JOIN Lote l ON l.idLote = v.idLote
JOIN Grano g ON g.idGrano = l.idGrano
JOIN Proveedor p ON p.idProveedor = l.idProveedor
WHERE v.idCalibracion = (SELECT TOP 1 v2.idCalibracion
                         FROM vwPuntajePorCalibracion v2
                         JOIN Lote l2 ON l2.idLote = v2.idLote
                         WHERE l2.idGrano = l.idGrano
                           AND l2.idProveedor = l.idProveedor
                           AND v2.calificaciones >= 3
                         ORDER BY v2.puntajePromedio DESC, v2.calificaciones DESC, v2.idCalibracion)
ORDER BY g.regionCosecha, p.razonSocial;

-- ---------------------------------------- 5 ----------------------------------------

SELECT TOP 1 p.idProveedor,
             p.razonSocial,
             ROUND(AVG(cf.puntaje * 1.0), 2) AS puntajePromedio
FROM Proveedor p
JOIN Lote l ON l.idProveedor = p.idProveedor
JOIN Calibracion cl ON cl.idLote = l.idLote
JOIN Calificacion cf ON cf.idCalibracion = cl.idCalibracion
GROUP BY p.idProveedor, p.razonSocial
HAVING COUNT(cf.idCalificacion) > 5
ORDER BY AVG(cf.puntaje * 1.0) DESC;

-- ---------------------------------------- 6 ----------------------------------------

SELECT CONCAT(c.nombre, ' ', c.apellido) AS nombreCliente,
       c.dni
FROM Cliente c
JOIN Calificacion cal ON cal.idCliente = c.idCliente
GROUP BY c.idCliente, c.nombre, c.apellido, c.dni
HAVING DATEDIFF(DAY, MAX(cal.fecha), GETDATE()) > 90;

-- ---------------------------------------- 7 ----------------------------------------

SELECT DATENAME(WEEKDAY, fecha) AS diaDeLaSemana,
       AVG(puntaje * 1.0) AS calificacionPromedio
FROM Calificacion
GROUP BY DATENAME(WEEKDAY, fecha), DATEPART(WEEKDAY, fecha)
ORDER BY DATEPART(WEEKDAY, fecha);

-- ---------------------------------------- 8 ----------------------------------------

SELECT l.idLote,
       l.nombre AS lote,
       AVG(cf.puntaje * 1.0) AS promedioUltimoMes,
       (SELECT AVG(cf2.puntaje * 1.0)
        FROM Calibracion c2
        JOIN Calificacion cf2 ON cf2.idCalibracion = c2.idCalibracion
        WHERE c2.idLote = l.idLote
          AND cf2.fecha >= DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) - 2, 0)
          AND cf2.fecha <  DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) - 1, 0)) AS promedioMesAnterior,
       COUNT(*) AS calificacionesUltimoMes
FROM Lote l
JOIN Calibracion c ON c.idLote = l.idLote
JOIN Calificacion cf ON cf.idCalibracion = c.idCalibracion
WHERE cf.fecha >= DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) - 1, 0)
  AND cf.fecha <  DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()), 0)
GROUP BY l.idLote, l.nombre
HAVING AVG(cf.puntaje * 1.0) < (SELECT AVG(cf2.puntaje * 1.0)
                                FROM Calibracion c2
                                JOIN Calificacion cf2 ON cf2.idCalibracion = c2.idCalibracion
                                WHERE c2.idLote = l.idLote
                                  AND cf2.fecha >= DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) - 2, 0)
                                  AND cf2.fecha <  DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) - 1, 0))
ORDER BY promedioUltimoMes;

-- ---------------------------------------- 9 ----------------------------------------

SELECT l.nombre AS lote,
       p.razonSocial AS proveedor,
       MIN(cf.puntaje) AS peorPuntaje,
       MAX(cf.puntaje) AS mejorPuntaje,
       MAX(cf.puntaje) - MIN(cf.puntaje) AS diferencia,
       AVG(cf.puntaje * 1.0) AS puntajePromedio,
       COUNT(*) AS cantidadCalificaciones
FROM Lote l
JOIN Proveedor p ON p.idProveedor = l.idProveedor
JOIN Calibracion c ON c.idLote = l.idLote
JOIN Calificacion cf ON cf.idCalibracion = c.idCalibracion
GROUP BY l.idLote, l.nombre, p.razonSocial
HAVING COUNT(*) >= 3
ORDER BY diferencia DESC;

-- ---------------------------------------- 10 ----------------------------------------

SELECT TOP 5 c.tiempoExtraccion AS tiempoEnSegundos,
             AVG(cf.puntaje * 1.0) AS puntajePromedio,
             COUNT(*) AS cantidadCalificaciones,
             COUNT(DISTINCT c.idCalibracion) AS cantidadCalibraciones
FROM Calibracion c
JOIN Calificacion cf ON cf.idCalibracion = c.idCalibracion
GROUP BY c.tiempoExtraccion
HAVING COUNT(*) >= 5
ORDER BY puntajePromedio DESC, cantidadCalificaciones DESC;
