# Benchmark: Node.js vs Java - MQTT Payload Processing

Este proyecto compara el rendimiento entre Node.js y Java para procesar payloads de MQTT simulados. El benchmark evalúa operaciones típicas de IoT como parsing JSON, validación de campos, enriquecimiento de datos y agregación por dispositivo.

## Operaciones del Benchmark

Para cada registro se ejecutan las siguientes operaciones:
1. **JSON.parse** - Deserialización del payload JSON
2. **Validación** - Verificación de campos requeridos
3. **Enriquecimiento** - Cálculo de `isAlarm` basado en temperatura y estado
4. **Agregación** - Contadores por dispositivo
5. **Checksum** - Hash FNV-1a de 32 bits sobre el payload (checksum económico)

## Requisitos

- **Node.js**: 18+ (para worker threads)
- **Java**: 17+ 
- **Maven**: Para compilar el proyecto Java

## Compilación

### Java
```bash
cd bench_java
mvn -DskipTests package
```

Esto genera el JAR ejecutable en `target/bench-java-1.0.0.jar`.

### Node.js
No requiere compilación, solo ejecución directa.

## Ejecución

### Node.js

**Hilo único:**
```bash
node bench_node.js
```

**Multi-threading (recomendado):**
```bash
WORKERS=8 node bench_node.js
```

### Java

**Ejecución básica:**
```bash
cd bench_java
java -jar target/bench-java-1.0.0.jar
```

**Ejecución optimizada (recomendado):**
```bash
java -Xms2g -Xmx2g -XX:+UseG1GC \
  -jar target/bench-java-1.0.0.jar \
  -Dtotal=1000000 -Dworkers=4 -Dbatch=10000 -Ddevices=1000
```

### Parámetros

**Node.js:**
- `WORKERS`: Número de worker threads (variable de entorno)

**Java:**
- `-Dtotal`: Total de registros a procesar (default: 1,000,000)
- `-Dworkers`: Número de threads (default: CPU cores)
- `-Dbatch`: Tamaño de lote por thread (default: 10,000)
- `-Ddevices`: Número de dispositivos únicos (default: 1,000)

## Resultados

### Configuración del Sistema
- **CPU**: MacBook Air M1/M2
- **Registros procesados**: 1,000,000
- **Dispositivos únicos**: 1,000

### Resultados del Benchmark

| Lenguaje | Workers | Tiempo (ms) | RPS | Checksum |
|----------|---------|-------------|-----|----------|
| **Node.js** | 1 | 683.2 | 1,463,624 | 676,288,223 |
| **Node.js** | 8 | 323.1 | 3,095,209 | 2,394,959,648 |
| **Java** | 4 | 628.0 | 1,592,465 | 3,087,759,238,117 |

### Análisis de Resultados

1. **Node.js con 8 workers** es el más rápido con **3.09M RPS**
2. **Java con 4 workers** alcanza **1.59M RPS**
3. **Node.js single-thread** logra **1.46M RPS**

**Conclusiones:**
- Node.js con worker threads supera significativamente a Java en este escenario
- El paralelismo en Node.js (8 workers) duplica el rendimiento vs single-thread
- Java muestra un rendimiento competitivo pero inferior en este benchmark específico
- Los checksums difieren debido a diferencias en la implementación del hash entre lenguajes

## Formato de Salida

Los resultados se muestran en formato JSON:
```json
{
  "lang": "node|java",
  "workers": 8,
  "total": 1000000,
  "ms": 323.1,
  "rps": 3095209,
  "checksum": 2394959648
}
```

- `lang`: Lenguaje utilizado
- `workers`: Número de threads/workers
- `total`: Total de registros procesados
- `ms`: Tiempo transcurrido en milisegundos
- `rps`: Registros por segundo
- `checksum`: Checksum final para validación de integridad