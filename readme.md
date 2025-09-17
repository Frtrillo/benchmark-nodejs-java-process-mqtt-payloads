ftrillo@MacBook-Air-de-Francisco benchmark-nodejs-java-process-mqtt-payloads % bun bench_node.js
WORKERS=8 node bench_node.js
{"lang":"node","total":1000000,"ms":683.2,"rps":1463624,"checksum":676288223}
{"lang":"node","workers":8,"total":1000000,"ms":323.1,"rps":3095209,"checksum":2394959648}
ftrillo@MacBook-Air-de-Francisco benchmark-nodejs-java-process-mqtt-payloads % cd bench_java    
ftrillo@MacBook-Air-de-Francisco bench_java % mvn -DskipTests package      
ftrillo@MacBook-Air-de-Francisco bench_java % java -Xms2g -Xmx2g -XX:+UseG1GC \ 
  -jar target/bench-java-1.0.0.jar \
  -Dtotal=1000000 -Dworkers=4 -Dbatch=10000 -Ddevices=1000

{"lang":"java","workers":8,"total":1000000,"ms":628.0,"rps":1592465,"checksum":3087759238117}
ftrillo@MacBook-Air-de-Francisco bench_java % 