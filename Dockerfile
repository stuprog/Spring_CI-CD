# 1. Build stage
FROM maven:3.8.8-eclipse-temurin-17 AS build
WORKDIR /app

# Copie le fichier de dépendances en premier pour profiter du cache Docker
COPY pom.xml . 
RUN mvn dependency:go-offline -B

# Copie le reste du code source
COPY src ./src

# Compilation (skip tests pendant le build)
RUN mvn clean package -DskipTests -B

# 2. Runtime stage
FROM eclipse-temurin:17-jdk-jammy
WORKDIR /app

# Copie du JAR compilé depuis l'étape précédente
COPY --from=build /app/target/*.jar app.jar

# Expose le port par défaut de ton app (Spring Boot = 8080 par défaut)
EXPOSE 8080

# Commande de lancement
ENTRYPOINT ["java", "-jar", "app.jar"]
