#!/bin/bash

# Benchmark: Node.js vs Java - MQTT Payload Processing
# Script para ejecutar ambos benchmarks y comparar resultados

set -e

echo "🚀 Iniciando benchmark Node.js vs Java - MQTT Payload Processing"
echo "=================================================================="
echo ""

# Configuración
TOTAL_RECORDS=1000000
NODE_WORKERS=8
JAVA_WORKERS=4
JAVA_BATCH=10000
JAVA_DEVICES=1000

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Función para mostrar resultados
show_result() {
    local lang=$1
    local workers=$2
    local json=$3
    
    echo -e "${BLUE}📊 Resultado $lang (workers: $workers):${NC}"
    echo "$json" | jq '.' 2>/dev/null || echo "$json"
    echo ""
}

# Función para extraer RPS del JSON
extract_rps() {
    echo "$1" | grep -o '"rps":[0-9]*' | cut -d':' -f2
}

echo -e "${YELLOW}⚙️  Configuración del benchmark:${NC}"
echo "   • Total de registros: $TOTAL_RECORDS"
echo "   • Node.js workers: $NODE_WORKERS"
echo "   • Java workers: $JAVA_WORKERS"
echo "   • Java batch size: $JAVA_BATCH"
echo "   • Java devices: $JAVA_DEVICES"
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
if [ ! -f "bench_java/target/bench-java-1.0.0.jar" ]; then
    echo -e "${YELLOW}🔨 Compilando proyecto Java...${NC}"
    cd bench_java
    mvn -DskipTests package -q
    cd ..
    echo -e "${GREEN}✅ Compilación Java completada${NC}"
    echo ""
fi

# Benchmark Node.js single-thread
echo -e "${YELLOW}🏃 Ejecutando $NODE_RUNTIME (single-thread)...${NC}"
NODE_SINGLE=$($NODE_RUNTIME bench_node.js)
show_result "$NODE_RUNTIME" "1" "$NODE_SINGLE"

# Benchmark Node.js multi-thread
echo -e "${YELLOW}🏃 Ejecutando $NODE_RUNTIME (multi-thread, $NODE_WORKERS workers)...${NC}"
NODE_MULTI=$(WORKERS=$NODE_WORKERS $NODE_RUNTIME bench_node.js)
show_result "$NODE_RUNTIME" "$NODE_WORKERS" "$NODE_MULTI"

# Benchmark Java
echo -e "${YELLOW}🏃 Ejecutando Java ($JAVA_WORKERS workers)...${NC}"
JAVA_RESULT=$(cd bench_java && java -Xms2g -Xmx2g -XX:+UseG1GC \
    -Dtotal=$TOTAL_RECORDS -Dworkers=$JAVA_WORKERS -Dbatch=$JAVA_BATCH -Ddevices=$JAVA_DEVICES \
    -jar target/bench-java-1.0.0.jar)
show_result "Java" "$JAVA_WORKERS" "$JAVA_RESULT"

# Extraer RPS para comparación
NODE_SINGLE_RPS=$(extract_rps "$NODE_SINGLE")
NODE_MULTI_RPS=$(extract_rps "$NODE_MULTI")
JAVA_RPS=$(extract_rps "$JAVA_RESULT")

echo -e "${GREEN}📈 RESUMEN COMPARATIVO${NC}"
echo "================================="
printf "%-20s %-10s %-15s\n" "Lenguaje" "Workers" "RPS"
echo "---------------------------------"
printf "%-20s %-10s %-15s\n" "$NODE_RUNTIME" "1" "$NODE_SINGLE_RPS"
printf "%-20s %-10s %-15s\n" "$NODE_RUNTIME" "$NODE_WORKERS" "$NODE_MULTI_RPS"
printf "%-20s %-10s %-15s\n" "Java" "$JAVA_WORKERS" "$JAVA_RPS"
echo "---------------------------------"

# Determinar el ganador
if [ "$NODE_MULTI_RPS" -gt "$JAVA_RPS" ] && [ "$NODE_MULTI_RPS" -gt "$NODE_SINGLE_RPS" ]; then
    echo -e "${GREEN}🏆 Ganador: $NODE_RUNTIME con $NODE_WORKERS workers ($NODE_MULTI_RPS RPS)${NC}"
elif [ "$JAVA_RPS" -gt "$NODE_SINGLE_RPS" ]; then
    echo -e "${BLUE}🏆 Ganador: Java con $JAVA_WORKERS workers ($JAVA_RPS RPS)${NC}"
else
    echo -e "${YELLOW}🏆 Ganador: $NODE_RUNTIME single-thread ($NODE_SINGLE_RPS RPS)${NC}"
fi

# Calcular mejoras
NODE_IMPROVEMENT=$(( (NODE_MULTI_RPS * 100) / NODE_SINGLE_RPS - 100 ))
if [ "$NODE_MULTI_RPS" -gt "$JAVA_RPS" ]; then
    JAVA_VS_NODE=$(( (NODE_MULTI_RPS * 100) / JAVA_RPS - 100 ))
    echo -e "${GREEN}📊 $NODE_RUNTIME multi-thread es $JAVA_VS_NODE% más rápido que Java${NC}"
else
    NODE_VS_JAVA=$(( (JAVA_RPS * 100) / NODE_MULTI_RPS - 100 ))
    echo -e "${BLUE}📊 Java es $NODE_VS_JAVA% más rápido que $NODE_RUNTIME multi-thread${NC}"
fi

echo -e "${GREEN}📊 $NODE_RUNTIME multi-thread mejora $NODE_IMPROVEMENT% sobre single-thread${NC}"

echo ""
echo -e "${GREEN}✅ Benchmark completado exitosamente${NC}"
echo "💡 Para más detalles, consulta el README.md"
