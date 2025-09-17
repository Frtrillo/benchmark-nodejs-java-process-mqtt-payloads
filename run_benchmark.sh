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

if ! command -v node &> /dev/null; then
    echo -e "${RED}❌ Node.js no está instalado${NC}"
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
echo -e "${YELLOW}🏃 Ejecutando Node.js (single-thread)...${NC}"
NODE_SINGLE=$(node bench_node.js)
show_result "Node.js" "1" "$NODE_SINGLE"

# Benchmark Node.js multi-thread
echo -e "${YELLOW}🏃 Ejecutando Node.js (multi-thread, $NODE_WORKERS workers)...${NC}"
NODE_MULTI=$(WORKERS=$NODE_WORKERS node bench_node.js)
show_result "Node.js" "$NODE_WORKERS" "$NODE_MULTI"

# Benchmark Java
echo -e "${YELLOW}🏃 Ejecutando Java ($JAVA_WORKERS workers)...${NC}"
JAVA_RESULT=$(cd bench_java && java -Xms2g -Xmx2g -XX:+UseG1GC \
    -jar target/bench-java-1.0.0.jar \
    -Dtotal=$TOTAL_RECORDS -Dworkers=$JAVA_WORKERS -Dbatch=$JAVA_BATCH -Ddevices=$JAVA_DEVICES)
show_result "Java" "$JAVA_WORKERS" "$JAVA_RESULT"

# Extraer RPS para comparación
NODE_SINGLE_RPS=$(extract_rps "$NODE_SINGLE")
NODE_MULTI_RPS=$(extract_rps "$NODE_MULTI")
JAVA_RPS=$(extract_rps "$JAVA_RESULT")

echo -e "${GREEN}📈 RESUMEN COMPARATIVO${NC}"
echo "================================="
printf "%-20s %-10s %-15s\n" "Lenguaje" "Workers" "RPS"
echo "---------------------------------"
printf "%-20s %-10s %-15s\n" "Node.js" "1" "$NODE_SINGLE_RPS"
printf "%-20s %-10s %-15s\n" "Node.js" "$NODE_WORKERS" "$NODE_MULTI_RPS"
printf "%-20s %-10s %-15s\n" "Java" "$JAVA_WORKERS" "$JAVA_RPS"
echo "---------------------------------"

# Determinar el ganador
if [ "$NODE_MULTI_RPS" -gt "$JAVA_RPS" ] && [ "$NODE_MULTI_RPS" -gt "$NODE_SINGLE_RPS" ]; then
    echo -e "${GREEN}🏆 Ganador: Node.js con $NODE_WORKERS workers ($NODE_MULTI_RPS RPS)${NC}"
elif [ "$JAVA_RPS" -gt "$NODE_SINGLE_RPS" ]; then
    echo -e "${BLUE}🏆 Ganador: Java con $JAVA_WORKERS workers ($JAVA_RPS RPS)${NC}"
else
    echo -e "${YELLOW}🏆 Ganador: Node.js single-thread ($NODE_SINGLE_RPS RPS)${NC}"
fi

# Calcular mejoras
NODE_IMPROVEMENT=$(( (NODE_MULTI_RPS * 100) / NODE_SINGLE_RPS - 100 ))
if [ "$NODE_MULTI_RPS" -gt "$JAVA_RPS" ]; then
    JAVA_VS_NODE=$(( (NODE_MULTI_RPS * 100) / JAVA_RPS - 100 ))
    echo -e "${GREEN}📊 Node.js multi-thread es $JAVA_VS_NODE% más rápido que Java${NC}"
else
    NODE_VS_JAVA=$(( (JAVA_RPS * 100) / NODE_MULTI_RPS - 100 ))
    echo -e "${BLUE}📊 Java es $NODE_VS_JAVA% más rápido que Node.js multi-thread${NC}"
fi

echo -e "${GREEN}📊 Node.js multi-thread mejora $NODE_IMPROVEMENT% sobre single-thread${NC}"

echo ""
echo -e "${GREEN}✅ Benchmark completado exitosamente${NC}"
echo "💡 Para más detalles, consulta el README.md"
