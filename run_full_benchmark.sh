#!/bin/bash

# Full Benchmark Suite: Node.js vs Java
# Runs both MQTT payload processing and algorithmic benchmarks

set -e

echo "🚀 Full Benchmark Suite: Node.js vs Java"
echo "========================================"
echo ""

# Configuración
MQTT_RECORDS=1000000
ALGO_SENSORS=500        # More sensors
ALGO_ITERATIONS=100000  # More iterations per sensor
NODE_WORKERS=8
JAVA_WORKERS=8
JAVA_BATCH=10000
JAVA_DEVICES=1000

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Función para mostrar resultados
show_result() {
    local benchmark=$1
    local lang=$2
    local workers=$3
    local json=$4
    
    echo -e "${BLUE}📊 $benchmark - $lang (workers: $workers):${NC}"
    echo "$json" | jq '.' 2>/dev/null || echo "$json"
    echo ""
}

# Función para extraer métricas del JSON
extract_metric() {
    local json=$1
    local metric=$2
    echo "$json" | grep -o "\"$metric\":[0-9]*" | cut -d':' -f2
}

echo -e "${YELLOW}⚙️  Configuración del benchmark:${NC}"
echo "   📨 MQTT Benchmark:"
echo "      • Total registros: $MQTT_RECORDS"
echo "      • Workers: $NODE_WORKERS (Node.js) / $JAVA_WORKERS (Java)"
echo ""
echo "   🧮 Algorithmic Benchmark:"
echo "      • Sensores: $ALGO_SENSORS"
echo "      • Iteraciones por sensor: $ALGO_ITERATIONS"
echo "      • Workers: $NODE_WORKERS (Node.js) / $JAVA_WORKERS (Java)"
echo ""

# Verificar dependencias
echo -e "${YELLOW}🔍 Verificando dependencias...${NC}"

# Detectar runtime de Node.js
NODE_RUNTIME=""
if command -v bun &> /dev/null; then
    NODE_RUNTIME="bun"
    echo -e "${GREEN}✅ Bun detectado${NC}"
elif command -v node &> /dev/null; then
    NODE_RUNTIME="node"
    echo -e "${GREEN}✅ Node.js detectado${NC}"
else
    echo -e "${RED}❌ Ni Node.js ni Bun están instalados${NC}"
    exit 1
fi

if ! command -v java &> /dev/null; then
    echo -e "${RED}❌ Java no está instalado${NC}"
    exit 1
fi

if ! command -v mvn &> /dev/null; then
    echo -e "${RED}❌ Maven no está instalado${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Todas las dependencias están disponibles${NC}"
echo -e "${BLUE}📋 Runtime de Node.js: $NODE_RUNTIME${NC}"
echo ""

# Compilar Java si es necesario
if [ ! -f "bench_java/target/bench-java-mqtt-1.0.0.jar" ] || [ ! -f "bench_java/target/bench-java-algo-1.0.0.jar" ]; then
    echo -e "${YELLOW}🔨 Compilando proyectos Java...${NC}"
    cd bench_java
    mvn -DskipTests clean package -q
    cd ..
    echo -e "${GREEN}✅ Compilación Java completada${NC}"
    echo ""
fi

echo -e "${PURPLE}═══════════════════════════════════════════${NC}"
echo -e "${PURPLE}           🏁 BENCHMARK 1: MQTT PAYLOAD PROCESSING${NC}" 
echo -e "${PURPLE}═══════════════════════════════════════════${NC}"
echo ""

# MQTT Benchmark - Node.js single-thread
echo -e "${YELLOW}🏃 Ejecutando $NODE_RUNTIME MQTT (single-thread)...${NC}"
MQTT_NODE_SINGLE=$($NODE_RUNTIME bench_node.js)
show_result "MQTT" "$NODE_RUNTIME" "1" "$MQTT_NODE_SINGLE"

# MQTT Benchmark - Node.js multi-thread
echo -e "${YELLOW}🏃 Ejecutando $NODE_RUNTIME MQTT (multi-thread, $NODE_WORKERS workers)...${NC}"
MQTT_NODE_MULTI=$(WORKERS=$NODE_WORKERS $NODE_RUNTIME bench_node.js)
show_result "MQTT" "$NODE_RUNTIME" "$NODE_WORKERS" "$MQTT_NODE_MULTI"

# MQTT Benchmark - Java
echo -e "${YELLOW}🏃 Ejecutando Java MQTT ($JAVA_WORKERS workers)...${NC}"
MQTT_JAVA=$(cd bench_java && java -Xms2g -Xmx2g -XX:+UseG1GC \
    -Dtotal=$MQTT_RECORDS -Dworkers=$JAVA_WORKERS -Dbatch=$JAVA_BATCH -Ddevices=$JAVA_DEVICES \
    -jar target/bench-java-mqtt-1.0.0.jar)
show_result "MQTT" "Java" "$JAVA_WORKERS" "$MQTT_JAVA"

echo -e "${PURPLE}═══════════════════════════════════════════${NC}"
echo -e "${PURPLE}           🧮 BENCHMARK 2: ALGORITHMIC COMPUTATION${NC}"
echo -e "${PURPLE}═══════════════════════════════════════════${NC}"
echo ""

# Algorithmic Benchmark - Node.js single-thread
echo -e "${YELLOW}🏃 Ejecutando $NODE_RUNTIME Algoritmo (single-thread)...${NC}"
ALGO_NODE_SINGLE=$($NODE_RUNTIME bench_algo_node.js)
show_result "Algoritmo" "$NODE_RUNTIME" "1" "$ALGO_NODE_SINGLE"

# Algorithmic Benchmark - Node.js multi-thread
echo -e "${YELLOW}🏃 Ejecutando $NODE_RUNTIME Algoritmo (multi-thread, $NODE_WORKERS workers)...${NC}"
ALGO_NODE_MULTI=$(WORKERS=$NODE_WORKERS $NODE_RUNTIME bench_algo_node.js)
show_result "Algoritmo" "$NODE_RUNTIME" "$NODE_WORKERS" "$ALGO_NODE_MULTI"

# Algorithmic Benchmark - Java
echo -e "${YELLOW}🏃 Ejecutando Java Algoritmo ($JAVA_WORKERS workers)...${NC}"
ALGO_JAVA=$(cd bench_java && java -Xms4g -Xmx4g -XX:+UseG1GC \
    -XX:+UseStringDeduplication -XX:+OptimizeStringConcat \
    -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions \
    -XX:+UseJVMCICompiler -XX:+EnableJVMCI \
    -Dsensors=$ALGO_SENSORS -Diterations=$ALGO_ITERATIONS -Dworkers=$JAVA_WORKERS \
    -jar target/bench-java-algo-1.0.0.jar 2>/dev/null || \
    java -Xms4g -Xmx4g -XX:+UseG1GC -XX:+UseStringDeduplication \
    -Dsensors=$ALGO_SENSORS -Diterations=$ALGO_ITERATIONS -Dworkers=$JAVA_WORKERS \
    -jar target/bench-java-algo-1.0.0.jar)
show_result "Algoritmo" "Java" "$JAVA_WORKERS" "$ALGO_JAVA"

# Extraer métricas para comparación
MQTT_NODE_SINGLE_RPS=$(extract_metric "$MQTT_NODE_SINGLE" "rps")
MQTT_NODE_MULTI_RPS=$(extract_metric "$MQTT_NODE_MULTI" "rps")
MQTT_JAVA_RPS=$(extract_metric "$MQTT_JAVA" "rps")

ALGO_NODE_SINGLE_OPS=$(extract_metric "$ALGO_NODE_SINGLE" "ops_per_sec")
ALGO_NODE_MULTI_OPS=$(extract_metric "$ALGO_NODE_MULTI" "ops_per_sec")
ALGO_JAVA_OPS=$(extract_metric "$ALGO_JAVA" "ops_per_sec")

echo -e "${CYAN}📈 RESUMEN COMPARATIVO COMPLETO${NC}"
echo "=================================================="
echo ""
echo -e "${CYAN}🏆 BENCHMARK 1: MQTT Payload Processing${NC}"
printf "%-20s %-10s %-15s\n" "Lenguaje" "Workers" "RPS"
echo "--------------------------------------------------"
printf "%-20s %-10s %-15s\n" "$NODE_RUNTIME" "1" "$MQTT_NODE_SINGLE_RPS"
printf "%-20s %-10s %-15s\n" "$NODE_RUNTIME" "$NODE_WORKERS" "$MQTT_NODE_MULTI_RPS"
printf "%-20s %-10s %-15s\n" "Java" "$JAVA_WORKERS" "$MQTT_JAVA_RPS"
echo ""

echo -e "${CYAN}🧮 BENCHMARK 2: Algorithmic Computation${NC}"
printf "%-20s %-10s %-15s\n" "Lenguaje" "Workers" "Ops/Sec"
echo "--------------------------------------------------"
printf "%-20s %-10s %-15s\n" "$NODE_RUNTIME" "1" "$ALGO_NODE_SINGLE_OPS"
printf "%-20s %-10s %-15s\n" "$NODE_RUNTIME" "$NODE_WORKERS" "$ALGO_NODE_MULTI_OPS"
printf "%-20s %-10s %-15s\n" "Java" "$JAVA_WORKERS" "$ALGO_JAVA_OPS"
echo ""

# Determinar ganadores
echo -e "${GREEN}🏆 GANADORES POR BENCHMARK:${NC}"

# MQTT Winner
if [ "$MQTT_NODE_MULTI_RPS" -gt "$MQTT_JAVA_RPS" ]; then
    MQTT_IMPROVEMENT=$(( (MQTT_NODE_MULTI_RPS * 100) / MQTT_JAVA_RPS - 100 ))
    echo -e "${GREEN}📨 MQTT Processing: $NODE_RUNTIME (+$MQTT_IMPROVEMENT% vs Java)${NC}"
else
    MQTT_IMPROVEMENT=$(( (MQTT_JAVA_RPS * 100) / MQTT_NODE_MULTI_RPS - 100 ))
    echo -e "${BLUE}📨 MQTT Processing: Java (+$MQTT_IMPROVEMENT% vs $NODE_RUNTIME)${NC}"
fi

# Algo Winner
if [ "$ALGO_NODE_MULTI_OPS" -gt "$ALGO_JAVA_OPS" ]; then
    ALGO_IMPROVEMENT=$(( (ALGO_NODE_MULTI_OPS * 100) / ALGO_JAVA_OPS - 100 ))
    echo -e "${GREEN}🧮 Algorithmic: $NODE_RUNTIME (+$ALGO_IMPROVEMENT% vs Java)${NC}"
else
    ALGO_IMPROVEMENT=$(( (ALGO_JAVA_OPS * 100) / ALGO_NODE_MULTI_OPS - 100 ))
    echo -e "${BLUE}🧮 Algorithmic: Java (+$ALGO_IMPROVEMENT% vs $NODE_RUNTIME)${NC}"
fi

echo ""
echo -e "${CYAN}💡 ANÁLISIS:${NC}"
echo "• MQTT Processing favorece a JavaScript/Bun (JSON parsing, I/O)"
echo "• Algorithmic computation debería favorecer a Java (JIT, math)"
echo "• Los resultados muestran las fortalezas reales de cada runtime"

echo ""
echo -e "${GREEN}✅ Benchmark completo exitoso${NC}"
echo "💡 Cada lenguaje tiene sus fortalezas según el tipo de workload"
