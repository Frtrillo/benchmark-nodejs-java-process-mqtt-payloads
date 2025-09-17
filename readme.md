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

- **Node.js**: 18+ (para worker threads) **o Bun** (runtime alternativo)
- **Java**: 17+ 
- **Maven**: Para compilar el proyecto Java

## Compilación

### Java
```bash
cd bench_java
mvn -DskipTests package
```

Esto genera el JAR ejecutable en `target/bench-java-1.0.0.jar`.

### Node.js/Bun
No requiere compilación, solo ejecución directa. El script detecta automáticamente si tienes Node.js o Bun instalado.

## Ejecución

### 🚀 Ejecución Automática (Recomendado)

**Script automatizado que ejecuta todos los benchmarks:**
```bash
./run_benchmark.sh
```

Este script:
- ✅ Verifica dependencias automáticamente (Node.js/Bun, Java, Maven)
- 🔍 Detecta automáticamente si usar Node.js o Bun
- 🔨 Compila Java si es necesario
- 🏃 Ejecuta todos los benchmarks
- 📊 Muestra resultados comparativos
- 🏆 Determina el ganador automáticamente

### Ejecución Manual

#### Node.js/Bun

**Hilo único:**
```bash
node bench_node.js
# o con Bun:
bun bench_node.js
```

**Multi-threading (recomendado):**
```bash
WORKERS=8 node bench_node.js
# o con Bun:
WORKERS=8 bun bench_node.js
```

#### Java

**Ejecución básica:**
```bash
cd bench_java
java -jar target/bench-java-1.0.0.jar
```

**Ejecución optimizada (recomendado):**
```bash
java -Xms2g -Xmx2g -XX:+UseG1GC \
  -Dtotal=1000000 -Dworkers=4 -Dbatch=10000 -Ddevices=1000 \
  -jar target/bench-java-1.0.0.jar
```

### Parámetros

**Node.js/Bun:**
- `WORKERS`: Número de worker threads (variable de entorno)

**Java:**
- `-Dtotal`: Total de registros a procesar (default: 1,000,000)
- `-Dworkers`: Número de threads (default: CPU cores)
- `-Dbatch`: Tamaño de lote por thread (default: 10,000)
- `-Ddevices`: Número de dispositivos únicos (default: 1,000)

> **Nota**: Los parámetros `-D` deben ir **antes** del `-jar` en Java, no después.

## Resultados

### Configuración del Sistema
- **CPU**: MacBook Air M1 (8 gb)
- **Registros procesados**: 1,000,000
- **Dispositivos únicos**: 1,000

### Resultados del Benchmark

| Lenguaje | Workers | Tiempo (ms) | RPS | Checksum |
|----------|---------|-------------|-----|----------|
| **Bun** | 1 | 713.6 | 1,401,299 | 2,729,861,900 |
| **Bun** | 8 | 386.3 | 2,588,703 | 2,636,246,112 |
| **Java** | 8 | 532.3 | 1,878,500 | 384,618,191,160 |

### Análisis de Resultados

1. **Bun con 8 workers** es el más rápido con **2.59M RPS**
2. **Java con 8 workers** alcanza **1.88M RPS**
3. **Bun single-thread** logra **1.40M RPS**

**Conclusiones:**
- Bun con worker threads supera a Java en este escenario por **37%**
- El paralelismo en Bun (8 workers) mejora **84%** sobre single-thread
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