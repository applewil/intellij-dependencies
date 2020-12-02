#!/usr/bin/env bash

set -euxo pipefail
# ======================================================= Setup ========================================================
shopt -s globstar
SUBSTITUTE_TOKEN=___-_-_-___
REPOSITORY_DIR=$(realpath dependencies)
rm -rf $REPOSITORY_DIR
# ================================================= Remove empty poms ==================================================
find -name "*.pom" -size 0 -print -delete
# ================================================= Add .gradle files ==================================================
for fileName in .gradle/caches/modules-2/files-2.1/**/*.{jar,zip}
do
  groupId=$(echo $fileName | awk -F '/' '{print $(NF-4)}')
  artifactId=$(echo $fileName | awk -F '/' '{print $(NF-3)}')
  version=$(echo $fileName | awk -F '/' '{print $(NF-2)}')
  packaging=$(echo $fileName | awk -F '.' '{print $NF}')
  pom=$(echo $fileName | cut -d'/' -f -7 | xargs -I {} find "{}" | grep .pom)
  classifier=$(echo $fileName | rev | cut -f -1 -d '/' | cut -f 2- -d '.' |rev | sed "s/$artifactId//g" | sed "s/$version//g" | sed "s/-//g")
  # artifactIdNoSpaces=${artifactId/ /$SUBSTITUTE_TOKEN}
  mvn install:install-file -DlocalRepositoryPath=$REPOSITORY_DIR \
                           -Dfile="$fileName" \
                           -DpomFile="$pom" \
                           -DgroupId=$groupId \
                           -DartifactId=$artifactId \
                           -Dversion=$version \
                           -Dclassifier=$classifier \
                           -Dpackaging=$packaging \
                           -DgeneratePom=false \
                           -DcreateChecksum=true
done
# ======================================== Replace substitute token with spaces ========================================
#find $REPOSITORY_DIR -type f -exec sed -i "s/$SUBSTITUTE_TOKEN/ /g" {} \;
#for fileName in $REPOSITORY_DIR/**/*$SUBSTITUTE_TOKEN*/; do mv $fileName "${fileName//$SUBSTITUTE_TOKEN/ }"; done
#for fileName in $REPOSITORY_DIR/**/*$SUBSTITUTE_TOKEN*; do mv "$fileName" "${fileName//$SUBSTITUTE_TOKEN/ }"; done
# ============================================== Add .gradle parent poms ===============================================
for fileName in .gradle/caches/modules-2/files-2.1/**/*.pom
do
  groupId=$(echo $fileName | awk -F '/' '{print $(NF-4)}')
  artifactId=$(echo $fileName | awk -F '/' '{print $(NF-3)}')
  version=$(echo $fileName | awk -F '/' '{print $(NF-2)}')
  packaging=$(echo $fileName | awk -F '.' '{print $NF}')
  artifactCount=$(echo $fileName | cut -d'/' -f -7 | xargs -I {} find "{}" | wc -l)
  test $artifactCount -eq 3 && mvn install:install-file -DlocalRepositoryPath=$REPOSITORY_DIR \
                           -Dfile="$fileName" \
                           -DgroupId=$groupId \
                           -DartifactId=$artifactId \
                           -Dversion=$version \
                           -Dpackaging=$SUBSTITUTE_TOKEN \
                           -DgeneratePom=false \
                           -DcreateChecksum=true \
                           || echo "pass"
done
# ========================================= Replace substitute token with pom ==========================================
for fileName in $REPOSITORY_DIR/**/*$SUBSTITUTE_TOKEN*; do mv "$fileName" "${fileName//$SUBSTITUTE_TOKEN/pom}"; done
# =================================================== Add .m2 files ====================================================
cd .m2/repository
for fileName in **/*.jar
do
  groupIdSlashes=$(echo $fileName | rev | cut -f 4- -d '/' | rev)
  groupId=${groupIdSlashes//\//.}
  version=$(echo $fileName | awk -F '/' '{print $(NF-1)}')
  artifactId=$(echo $fileName | awk -F '/' '{print $(NF-2)}')
  classifier=$(echo $fileName | rev | cut -f -1 -d '/' | cut -f 2- -d '.' |rev | sed "s/$artifactId//g" | sed "s/$version//g" | sed "s/-//g")
  pom=$(echo $fileName | rev | cut -f 2- -d '.' | rev).pom
  ls "$pom" &&  mvn install:install-file -DlocalRepositoryPath=$REPOSITORY_DIR \
                           -Dfile="$fileName" \
                           -DpomFile="$pom" \
                           -DgroupId=$groupId \
                           -DartifactId=$artifactId \
                           -Dversion=$version \
                           -Dpackaging=jar \
                           -Dclassifier=$classifier \
                           -DgeneratePom=false \
                           -DcreateChecksum=true \
                    || mvn install:install-file -DlocalRepositoryPath=$REPOSITORY_DIR \
                           -Dfile="$fileName" \
                           -DgroupId=$groupId \
                           -DartifactId=$artifactId \
                           -Dversion=$version \
                           -Dpackaging=jar \
                           -Dclassifier=$classifier \
                           -DgeneratePom=true \
                           -DcreateChecksum=true
done
cd ../..
# ================================================ Add .m2 parent poms =================================================
cd .m2/repository
for fileName in **/*.pom
do
  groupIdSlashes=$(echo $fileName | rev | cut -f 4- -d '/' | rev)
  groupId=${groupIdSlashes//\//.}
  version=$(echo $fileName | awk -F '/' '{print $(NF-1)}')
  artifactId=$(echo $fileName | awk -F '/' '{print $(NF-2)}')
  jar=$(echo $fileName | rev | cut -f 2- -d '.' | rev).jar
  ls "$jar" || mvn install:install-file -DlocalRepositoryPath=$REPOSITORY_DIR \
                           -Dfile="$fileName" \
                           -DgroupId=$groupId \
                           -DartifactId=$artifactId \
                           -Dversion=$version \
                           -Dpackaging=$SUBSTITUTE_TOKEN \
                           -DgeneratePom=false \
                           -DcreateChecksum=true
done
cd ../..
# ========================================= Replace substitute token with pom ==========================================
for fileName in $REPOSITORY_DIR/**/*$SUBSTITUTE_TOKEN*; do mv "$fileName" "${fileName//$SUBSTITUTE_TOKEN/pom}"; done
# ============================================ Rename maven-metadata files =============================================
for fileName in $REPOSITORY_DIR/**/maven-metadata-local.*
do mv "$fileName" "${fileName//maven-metadata-local/maven-metadata}"; done
# ================================================= Add .other files ===================================================
for fileName in .other/**/*.tar.gz
do cp $fileName $REPOSITORY_DIR; done
# ============================================ Add misc dependencies ===================================================
cd $REPOSITORY_DIR
mkdir -p org/apache/maven/resolver/maven-resolver-ant-tasks/1.2.1
curl -Lo org/apache/maven/resolver/maven-resolver-ant-tasks/1.2.1/maven-resolver-ant-tasks-1.2.1-uber.jar https://repo1.maven.org/maven2/org/apache/maven/resolver/maven-resolver-ant-tasks/1.2.1/maven-resolver-ant-tasks-1.2.1-uber.jar
curl -LO https://corretto.aws/downloads/latest/amazon-corretto-11-x64-linux-jdk.tar.gz
curl -LO https://downloads.apache.org/ant/binaries/apache-ant-1.10.9-bin.tar.gz
curl -LO https://services.gradle.org/distributions/gradle-5.5-all.zip
