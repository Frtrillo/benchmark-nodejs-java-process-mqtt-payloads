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

# Detectar runtimes disponibles
BUN_AVAILABLE=false
NODE_AVAILABLE=false

if command -v bun &> /dev/null; then
    BUN_AVAILABLE=true
    echo -e "${GREEN}✅ Bun detectado${NC}"
fi

if command -v node &> /dev/null; then
    NODE_AVAILABLE=true
    echo -e "${GREEN}✅ Node.js detectado${NC}"
fi

if [ "$BUN_AVAILABLE" = false ] && [ "$NODE_AVAILABLE" = false ]; then
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
echo -e "${BLUE}📋 Runtimes disponibles: $([ "$BUN_AVAILABLE" = true ] && echo -n "Bun ") $([ "$NODE_AVAILABLE" = true ] && echo -n "Node.js ")${NC}"
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

# MQTT Benchmarks - Run available runtimes
if [ "$BUN_AVAILABLE" = true ]; then
    echo -e "${YELLOW}🏃 Ejecutando Bun MQTT (single-thread)...${NC}"
    MQTT_BUN_SINGLE=$(bun bench_node.js)
    show_result "MQTT" "Bun" "1" "$MQTT_BUN_SINGLE"

    echo -e "${YELLOW}🏃 Ejecutando Bun MQTT (multi-thread, $NODE_WORKERS workers)...${NC}"
    MQTT_BUN_MULTI=$(WORKERS=$NODE_WORKERS bun bench_node.js)
    show_result "MQTT" "Bun" "$NODE_WORKERS" "$MQTT_BUN_MULTI"
fi

if [ "$NODE_AVAILABLE" = true ]; then
    echo -e "${YELLOW}🏃 Ejecutando Node.js MQTT (single-thread)...${NC}"
    MQTT_NODE_SINGLE=$(node bench_node.js)
    show_result "MQTT" "Node.js" "1" "$MQTT_NODE_SINGLE"

    echo -e "${YELLOW}🏃 Ejecutando Node.js MQTT (multi-thread, $NODE_WORKERS workers)...${NC}"
    MQTT_NODE_MULTI=$(WORKERS=$NODE_WORKERS node bench_node.js)
    show_result "MQTT" "Node.js" "$NODE_WORKERS" "$MQTT_NODE_MULTI"
fi

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

# Algorithmic Benchmarks - Run available runtimes
if [ "$BUN_AVAILABLE" = true ]; then
    echo -e "${YELLOW}🏃 Ejecutando Bun Algoritmo (single-thread)...${NC}"
    ALGO_BUN_SINGLE=$(bun bench_algo_node.js)
    show_result "Algoritmo" "Bun" "1" "$ALGO_BUN_SINGLE"

    echo -e "${YELLOW}🏃 Ejecutando Bun Algoritmo (multi-thread, $NODE_WORKERS workers)...${NC}"
    ALGO_BUN_MULTI=$(WORKERS=$NODE_WORKERS bun bench_algo_node.js)
    show_result "Algoritmo" "Bun" "$NODE_WORKERS" "$ALGO_BUN_MULTI"
fi

if [ "$NODE_AVAILABLE" = true ]; then
    echo -e "${YELLOW}🏃 Ejecutando Node.js Algoritmo (single-thread)...${NC}"
    ALGO_NODE_SINGLE=$(node bench_algo_node.js)
    show_result "Algoritmo" "Node.js" "1" "$ALGO_NODE_SINGLE"

    echo -e "${YELLOW}🏃 Ejecutando Node.js Algoritmo (multi-thread, $NODE_WORKERS workers)...${NC}"
    ALGO_NODE_MULTI=$(WORKERS=$NODE_WORKERS node bench_algo_node.js)
    show_result "Algoritmo" "Node.js" "$NODE_WORKERS" "$ALGO_NODE_MULTI"
fi

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
MQTT_JAVA_RPS=$(extract_metric "$MQTT_JAVA" "rps")
ALGO_JAVA_OPS=$(extract_metric "$ALGO_JAVA" "ops_per_sec")

# Extraer métricas de Bun si está disponible
if [ "$BUN_AVAILABLE" = true ]; then
    MQTT_BUN_SINGLE_RPS=$(extract_metric "$MQTT_BUN_SINGLE" "rps")
    MQTT_BUN_MULTI_RPS=$(extract_metric "$MQTT_BUN_MULTI" "rps")
    ALGO_BUN_SINGLE_OPS=$(extract_metric "$ALGO_BUN_SINGLE" "ops_per_sec")
    ALGO_BUN_MULTI_OPS=$(extract_metric "$ALGO_BUN_MULTI" "ops_per_sec")
fi

# Extraer métricas de Node.js si está disponible
if [ "$NODE_AVAILABLE" = true ]; then
    MQTT_NODE_SINGLE_RPS=$(extract_metric "$MQTT_NODE_SINGLE" "rps")
    MQTT_NODE_MULTI_RPS=$(extract_metric "$MQTT_NODE_MULTI" "rps")
    ALGO_NODE_SINGLE_OPS=$(extract_metric "$ALGO_NODE_SINGLE" "ops_per_sec")
    ALGO_NODE_MULTI_OPS=$(extract_metric "$ALGO_NODE_MULTI" "ops_per_sec")
fi

echo -e "${CYAN}📈 RESUMEN COMPARATIVO COMPLETO${NC}"
echo "=================================================="
echo ""
echo -e "${CYAN}🏆 BENCHMARK 1: MQTT Payload Processing${NC}"
printf "%-20s %-10s %-15s\n" "Lenguaje" "Workers" "RPS"
echo "--------------------------------------------------"
if [ "$BUN_AVAILABLE" = true ]; then
    printf "%-20s %-10s %-15s\n" "Bun" "1" "$MQTT_BUN_SINGLE_RPS"
    printf "%-20s %-10s %-15s\n" "Bun" "$NODE_WORKERS" "$MQTT_BUN_MULTI_RPS"
fi
if [ "$NODE_AVAILABLE" = true ]; then
    printf "%-20s %-10s %-15s\n" "Node.js" "1" "$MQTT_NODE_SINGLE_RPS"
    printf "%-20s %-10s %-15s\n" "Node.js" "$NODE_WORKERS" "$MQTT_NODE_MULTI_RPS"
fi
printf "%-20s %-10s %-15s\n" "Java" "$JAVA_WORKERS" "$MQTT_JAVA_RPS"
echo ""

echo -e "${CYAN}🧮 BENCHMARK 2: Algorithmic Computation${NC}"
printf "%-20s %-10s %-15s\n" "Lenguaje" "Workers" "Ops/Sec"
echo "--------------------------------------------------"
if [ "$BUN_AVAILABLE" = true ]; then
    printf "%-20s %-10s %-15s\n" "Bun" "1" "$ALGO_BUN_SINGLE_OPS"
    printf "%-20s %-10s %-15s\n" "Bun" "$NODE_WORKERS" "$ALGO_BUN_MULTI_OPS"
fi
if [ "$NODE_AVAILABLE" = true ]; then
    printf "%-20s %-10s %-15s\n" "Node.js" "1" "$ALGO_NODE_SINGLE_OPS"
    printf "%-20s %-10s %-15s\n" "Node.js" "$NODE_WORKERS" "$ALGO_NODE_MULTI_OPS"
fi
printf "%-20s %-10s %-15s\n" "Java" "$JAVA_WORKERS" "$ALGO_JAVA_OPS"
echo ""

# Determinar ganadores
echo -e "${GREEN}🏆 GANADORES POR BENCHMARK:${NC}"

# Función para encontrar el mejor resultado MQTT
find_mqtt_winner() {
    local best_rps=0
    local best_runtime=""
    
    if [ "$BUN_AVAILABLE" = true ] && [ "$MQTT_BUN_MULTI_RPS" -gt "$best_rps" ]; then
        best_rps=$MQTT_BUN_MULTI_RPS
        best_runtime="Bun"
    fi
    
    if [ "$NODE_AVAILABLE" = true ] && [ "$MQTT_NODE_MULTI_RPS" -gt "$best_rps" ]; then
        best_rps=$MQTT_NODE_MULTI_RPS
        best_runtime="Node.js"
    fi
    
    if [ "$MQTT_JAVA_RPS" -gt "$best_rps" ]; then
        best_rps=$MQTT_JAVA_RPS
        best_runtime="Java"
    fi
    
    local improvement=$(( (best_rps * 100) / MQTT_JAVA_RPS - 100 ))
    if [ "$best_runtime" = "Java" ]; then
        local js_best=0
        [ "$BUN_AVAILABLE" = true ] && [ "$MQTT_BUN_MULTI_RPS" -gt "$js_best" ] && js_best=$MQTT_BUN_MULTI_RPS
        [ "$NODE_AVAILABLE" = true ] && [ "$MQTT_NODE_MULTI_RPS" -gt "$js_best" ] && js_best=$MQTT_NODE_MULTI_RPS
        improvement=$(( (best_rps * 100) / js_best - 100 ))
        echo -e "${BLUE}📨 MQTT Processing: Java (+$improvement%)${NC}"
    else
        echo -e "${GREEN}📨 MQTT Processing: $best_runtime (+$improvement% vs Java)${NC}"
    fi
}

# Función para encontrar el mejor resultado Algorítmico
find_algo_winner() {
    local best_ops=0
    local best_runtime=""
    
    if [ "$BUN_AVAILABLE" = true ] && [ "$ALGO_BUN_MULTI_OPS" -gt "$best_ops" ]; then
        best_ops=$ALGO_BUN_MULTI_OPS
        best_runtime="Bun"
    fi
    
    if [ "$NODE_AVAILABLE" = true ] && [ "$ALGO_NODE_MULTI_OPS" -gt "$best_ops" ]; then
        best_ops=$ALGO_NODE_MULTI_OPS
        best_runtime="Node.js"
    fi
    
    if [ "$ALGO_JAVA_OPS" -gt "$best_ops" ]; then
        best_ops=$ALGO_JAVA_OPS
        best_runtime="Java"
    fi
    
    local improvement=$(( (best_ops * 100) / ALGO_JAVA_OPS - 100 ))
    if [ "$best_runtime" = "Java" ]; then
        local js_best=0
        [ "$BUN_AVAILABLE" = true ] && [ "$ALGO_BUN_MULTI_OPS" -gt "$js_best" ] && js_best=$ALGO_BUN_MULTI_OPS
        [ "$NODE_AVAILABLE" = true ] && [ "$ALGO_NODE_MULTI_OPS" -gt "$js_best" ] && js_best=$ALGO_NODE_MULTI_OPS
        improvement=$(( (best_ops * 100) / js_best - 100 ))
        echo -e "${BLUE}🧮 Algorithmic: Java (+$improvement%)${NC}"
    else
        echo -e "${GREEN}🧮 Algorithmic: $best_runtime (+$improvement% vs Java)${NC}"
    fi
}

find_mqtt_winner
find_algo_winner

echo ""
echo -e "${CYAN}💡 ANÁLISIS:${NC}"
if [ "$BUN_AVAILABLE" = true ] && [ "$NODE_AVAILABLE" = true ]; then
    echo "• Comparación completa: Bun vs Node.js vs Java"
    echo "• Bun generalmente supera a Node.js estándar"
    echo "• JavaScript moderno (V8/JavaScriptCore) es altamente competitivo"
elif [ "$BUN_AVAILABLE" = true ]; then
    echo "• Bun (JavaScriptCore) muestra rendimiento superior"
    echo "• Optimizaciones agresivas de JIT en tiempo real"
elif [ "$NODE_AVAILABLE" = true ]; then
    echo "• Node.js (V8) demuestra capacidades competitivas"
    echo "• Motor V8 altamente optimizado para estos workloads"
fi
echo "• Java sigue siendo válido para aplicaciones enterprise específicas"
echo "• El rendimiento depende fuertemente del tipo de workload"

echo ""
echo -e "${GREEN}✅ Benchmark completo exitoso${NC}"
if [ "$BUN_AVAILABLE" = true ] && [ "$NODE_AVAILABLE" = true ]; then
    echo "💡 Ejecutados todos los runtimes disponibles: Bun, Node.js y Java"
else
    echo "💡 Comparación exitosa entre los runtimes disponibles"
fi
