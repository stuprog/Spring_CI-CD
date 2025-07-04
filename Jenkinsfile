pipeline {
  agent any

  tools {
    jdk 'jdk17'         // Vérifie le nom exact configuré dans Jenkins
    maven 'maven3'      // Idem
  }

  environment {
    DOCKER_CRED = 'dockerhub'                    // 🔐 Identifiant Jenkins DockerHub
    SONAR_TOKEN = credentials('sonar-token')     // 🔐 Token SonarQube (Secret text)
    SONAR_URL   = 'http://13.39.80.147:9000'     // 🌍 Ton URL publique SonarQube
    NEXUS_URL   = 'http://13.39.80.147:8081/repository/maven-snapshots/'  // 🌍 URL Nexus
  }

  stages {

    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Build & Test') {
      steps {
        sh 'mvn clean package -B'
      }
    }

    stage('SonarQube Analysis') {
      steps {
        catchError(buildResult: 'UNSTABLE', stageResult: 'UNSTABLE') {
          withSonarQubeEnv('MySonar') {
            sh "mvn sonar:sonar -Dsonar.host.url=${SONAR_URL} -Dsonar.login=${SONAR_TOKEN}"
          }
        }
      }
    }

    stage('Quality Gate') {
      steps {
        catchError(buildResult: 'UNSTABLE', stageResult: 'UNSTABLE') {
          timeout(time: 2, unit: 'MINUTES') {
            script {
              def qg = waitForQualityGate()
              echo "Quality Gate: ${qg.status}"
              if (qg.status != 'OK') {
                currentBuild.result = 'UNSTABLE'
              }
            }
          }
        }
      }
    }

    stage('Docker Login, Build & Push') {
      steps {
        withCredentials([usernamePassword(
          credentialsId: "${DOCKER_CRED}",
          usernameVariable: 'DOCKER_USER',
          passwordVariable: 'DOCKER_PASS'
        )]) {
          sh '''
            echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin
            docker build -t $DOCKER_USER/demoapp:${GIT_COMMIT} .
            docker push $DOCKER_USER/demoapp:${GIT_COMMIT}
            docker tag $DOCKER_USER/demoapp:${GIT_COMMIT} $DOCKER_USER/demoapp:latest
            docker push $DOCKER_USER/demoapp:latest
          '''
        }
      }
    }

    stage('Trivy Scan') {
      steps {
        echo '🔍 Trivy scanning'
        catchError(buildResult: 'UNSTABLE', stageResult: 'UNSTABLE') {
          sh "trivy image --exit-code 1 --severity HIGH,CRITICAL $DOCKER_USER/demoapp:${GIT_COMMIT}"
        }
      }
    }

    stage('Deploy to Nexus') {
      steps {
        echo '📦 Déploiement du JAR vers Nexus'
        withCredentials([usernamePassword(
          credentialsId: 'nexus-credentials',
          usernameVariable: 'NEXUS_USER',
          passwordVariable: 'NEXUS_PASS'
        )]) {
          sh '''cat > settings.xml <<EOF
<settings>
  <servers>
    <server>
      <id>nexus</id>
      <username>$NEXUS_USER</username>
      <password>$NEXUS_PASS</password>
    </server>
  </servers>
</settings>
EOF'''
          sh 'mvn deploy -B -s settings.xml -DaltDeploymentRepository=nexus::default::http://13.39.80.147:8081/repository/maven-snapshots/'
        }
      }
    }

  }

  post {
    success  { echo '✅ Pipeline terminé avec succès' }
    unstable { echo '⚠️ Pipeline instable (voir Quality Gate, Trivy, etc.)' }
    failure  { echo '❌ Pipeline échoué' }
  }
}
